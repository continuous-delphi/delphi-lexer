unit DelphiLexer.Utils;

interface
uses
  System.SysUtils,
  System.Generics.Collections,
  GpCommandLineParser,
  DelphiLexer.Token;

type

  TWinUtils = class
    class function GetModuleVersion(const AIncludeBuild:Boolean=False):string;
  end;

  TLexerUtils = class
    // Return a printable, single-line representation of S.
    // Control characters are replaced with <TAG> codes.
    // Truncated at 48 visible characters with '...' suffix.
    class function SafeText(const S: string): string;
    // Map a case-insensitive encoding name to a TEncoding singleton.
    // Returns nil if the name is not recognised.
    class function ResolveEncoding(const AName: string): TEncoding;

    class function RoundTripCheck(const ATokens: TList<TToken>; const ASource: string):Boolean;
  end;

  TOutputFormat = (ofText, ofJson);



  // For GpCommandLineParser: base set of command-line options for delphi-lexer utilities
  TFileTokenizerCLI = class
  private
    FInputFile: string;
    FEncoding:  string;
    FFormat:    string;
    FHelp:      Boolean;
    FVersion:   Boolean;
  public
    [CLPPosition(1), CLPLongName('file'), CLPDescription('Delphi source file to tokenize')]
    property InputFile: string read FInputFile write FInputFile;

    [CLPLongNameAttribute('encoding'), CLPDescription('Source file encoding (utf-8, utf-16, utf-16be, ansi, ascii, default)', 'name'), CLPDefault('utf-8')]
    property Encoding: string read FEncoding write FEncoding;

    [CLPLongNameAttribute('format'), CLPDescription('Output format: text or json', 'name'), CLPDefault('text')]
    property Format: string read FFormat write FFormat;

    [CLPLongNameAttribute('help'), CLPName('?'), CLPDescription('Show this help and exit')]
    property Help: Boolean read FHelp write FHelp;

    [CLPLongNameAttribute('version'), CLPName('v'), CLPDescription('Show tool version and exit')]
    property Version: Boolean read FVersion write FVersion;
  end;


  TConfigOptions = record
    AbortProgram: Boolean;
    ExitCode: Integer;
    FileName: string;
    FileContents: string;
    Encoding: TEncoding;
    OutputFormat: TOutputFormat;
  end;

  TCommandLineParser = class
  public
    class function Parse(const Line1, Line2:string):TConfigOptions;
  end;


implementation
uses
  System.Classes,
  System.IOUtils,
  WinAPI.Windows;


class function TWinUtils.GetModuleVersion(const AIncludeBuild:Boolean=False):string;
const
  ROOT_BLOCK = '\';
var
  VersionInfoBlock: TMemoryStream;
  AppResource: TResourceStream;
  FixedFileInfo: PVSFIXEDFILEINFO;
  puLen: UInt;
begin
  Result := '';

  try

    VersionInfoBlock := TMemoryStream.Create;
    try

      AppResource := TResourceStream.CreateFromID(SysInit.HInstance, VS_VERSION_INFO, RT_VERSION);
      try
        VersionInfoBlock.CopyFrom(AppResource, AppResource.Size);
      finally
        AppResource.Free;
      end;

      VersionInfoBlock.Position := 0;
      //https://learn.microsoft.com/en-us/windows/win32/api/winver/nf-winver-verqueryvaluew
      if VerQueryValue(VersionInfoBlock.Memory, ROOT_BLOCK, Pointer(FixedFileInfo), puLen) then
      begin
        Result := Format('%d.%d.%d', [FixedFileInfo.dwFileVersionMS shr 16,
                                      FixedFileInfo.dwFileVersionMS and $FFFF,
                                      FixedFileInfo.dwFileVersionLS shr 16]);
        if AIncludeBuild then
          Result := Format('%s.%d', [Result, FixedFileInfo.dwFileVersionLS and $FFFF]);
      end;
    finally
      VersionInfoBlock.Free;
    end;

  except on E: Exception do
    // Do you have version info enabled in your project?
    Result := 'Version Info Not Available';
  end;

end;

class function TLexerUtils.RoundTripCheck(const ATokens: TList<TToken>; const ASource: string): Boolean;
var
  SB: TStringBuilder;
  I: Integer;
begin
  SB := TStringBuilder.Create(System.Length(ASource));
  try
    for I := 0 to ATokens.Count - 1 do
      SB.Append(ATokens[I].Text);
    Result := (SB.ToString = ASource);
  finally
    SB.Free;
  end;
end;

class function TLexerUtils.SafeText(const S: string): string;
const
  MAX_VISIBLE = 48;
var
  I:       Integer;
  Visible: Integer;
  Ch:      Char;
  R:       string;
  Tag:     string;
begin
  R       := '';
  Visible := 0;
  I       := 1;
  while (I <= System.Length(S)) and (Visible < MAX_VISIBLE) do
  begin
    Ch := S[I];
    if (Ch = #13) and (I < System.Length(S)) and (S[I + 1] = #10) then
    begin
      Tag := '<CRLF>';
      Inc(I);
    end
    else if Ch = #13 then
      Tag := '<CR>'
    else if Ch = #10 then
      Tag := '<LF>'
    else if Ch = #9 then
      Tag := '<TAB>'
    else
    begin
      R := R + Ch;
      Inc(Visible);
      Inc(I);
      Continue;
    end;
    R       := R + Tag;
    Visible := Visible + System.Length(Tag);
    Inc(I);
  end;
  if I <= System.Length(S) then
    R := R + '...';
  Result := R;
end;


class function TLexerUtils.ResolveEncoding(const AName: string): TEncoding;
var
  Lower: string;
begin
  Lower := LowerCase(AName);
  if (Lower = 'utf-8') or (Lower = 'utf8') then
    Result := TEncoding.UTF8
  else if (Lower = 'utf-16') or (Lower = 'utf16') or (Lower = 'unicode') then
    Result := TEncoding.Unicode
  else if (Lower = 'utf-16be') or (Lower = 'utf16be') then
    Result := TEncoding.BigEndianUnicode
  else if Lower = 'ansi' then
    Result := TEncoding.ANSI
  else if Lower = 'ascii' then
    Result := TEncoding.ASCII
  else if Lower = 'default' then
    Result := TEncoding.Default
  else
    Result := nil;
end;


class function TCommandLineParser.Parse(const Line1, Line2:string):TConfigOptions;
var
  Opts: TFileTokenizerCLI;
  Parser: IGpCommandLineParser;
  Line: string;
begin
  Result := Default(TConfigOptions);
  Result.AbortProgram := True;

  Opts := TFileTokenizerCLI.Create;
  try
    Parser := CreateCommandLineParser;
    Parser.Options := [opAllowInherited];

    if not Parser.Parse(Opts) then
    begin
      WriteLn('error: ', Parser.ErrorInfo.Text);
      Result.ExitCode := 1;
      Exit;
    end;

    if Opts.Help or (Opts.InputFile = '') then  // inputfile is the one required parameter
    begin
      WriteLn(Line1);
      WriteLn(Line2);
      WriteLn('A command-line utility for delphi-lexer from Continuous-Delphi');
      WriteLn('https://github.com/continuous-delphi/delphi-lexer');
      WriteLn('MIT Licensed.  Copyright (C) 2026, Darian Miller');
      WriteLn('Version: ', TWinUtils.GetModuleVersion);
      WriteLn;
      for Line in Parser.Usage do
        WriteLn(Line);
      WriteLn;
      if Opts.InputFile = ''  then Result.ExitCode := 1;
      Exit;
    end;

    if Opts.Version then
    begin
      WriteLn(TWinUtils.GetModuleVersion);
      Exit;
    end;

    Result.FileName := Opts.InputFile;
    if not TFile.Exists(Result.FileName) then
    begin
      WriteLn('error: file not found: ', Result.FileName);
      Result.ExitCode := 1;
      Exit;
    end;

    Result.Encoding := TLexerUtils.ResolveEncoding(Opts.Encoding);
    if Result.Encoding = nil then
    begin
      WriteLn('error: unknown encoding: ', Opts.Encoding);
      WriteLn('Supported: utf-8, utf-16, utf-16be, ansi, ascii, default');
      Result.ExitCode := 1;
      Exit;
    end;

    if SameText(Opts.Format, 'json') then
      Result.OutputFormat := TOutputFormat.ofJson
    else if SameText(Opts.Format, 'text') then
      Result.OutputFormat := TOutputFormat.ofText
    else
    begin
      WriteLn('error: unknown format: ', Opts.Format);
      WriteLn('Supported formats: text, json');
      Result.ExitCode := 1;
      Exit;
    end;


    try
      Result.FileContents := TFile.ReadAllText(Result.FileName, Result.Encoding);
    except
      on E: Exception do
      begin
        WriteLn('error: could not read file: ', E.Message);
        Result.ExitCode := 1;
        Exit;
      end;
    end;

  finally
    Opts.Free;
  end;

  Result.AbortProgram := False;
end;


end.
