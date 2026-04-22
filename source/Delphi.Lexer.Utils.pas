unit Delphi.Lexer.Utils;

interface
uses
  System.SysUtils,
  GpCommandLineParser,
  Delphi.Token,
  Delphi.Token.List;

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

    class function RoundTripCheck(const ATokens: TTokenList; const ASource: string):Boolean;
  end;

  TOutputFormat = (ofText, ofJson);



  // For GpCommandLineParser: base set of command-line options for delphi-lexer utilities
  TFileTokenizerCLOptions = class
  private
    FInputFile: string;
    FEncoding: string;
    FFormat: string;
    FHelp: Boolean;
    FVersion: Boolean;
    FSkipAnsiFallback: Boolean;
    FLexAsm:Boolean;
  public
    [CLPPosition(1), CLPLongName('file'), CLPDescription('Delphi source file to tokenize')]
    property InputFile: string read FInputFile write FInputFile;

    [CLPLongNameAttribute('encoding'), CLPDescription('Source file encoding (utf-8, utf-16, utf-16be, ansi, ascii, default)', 'name'), CLPDefault('utf-8')]
    property Encoding: string read FEncoding write FEncoding;

    [CLPLongNameAttribute('no-ansi-fallback'), CLPName('a'), CLPDescription('Skip automatic ANSI fallback for encoding errors on file reads')]
    property SkipAnsiFallback: Boolean read FSkipAnsiFallback write FSkipAnsiFallback;

    [CLPLongNameAttribute('format'), CLPDescription('Output format: text or json', 'name'), CLPDefault('text')]
    property Format: string read FFormat write FFormat;

    [CLPLongNameAttribute('help'), CLPName('?'), CLPDescription('Show this help and exit')]
    property Help: Boolean read FHelp write FHelp;

    [CLPLongNameAttribute('version'), CLPName('v'), CLPDescription('Show tool version and exit')]
    property Version: Boolean read FVersion write FVersion;

    [CLPLongNameAttribute('lexasm'), CLPName('x'), CLPDescription('Flag only used for include files that are included within an asm block')]
    property LexAsm: Boolean read FLexAsm write FLexAsm;

  end;

  TConditionalFileTokenizerCLOptions = class(TFileTokenizerCLOptions)
  private
    FJsonContextFile:string;
  public
    [CLPPosition(2), CLPLongName('jsonContext', 'json'), CLPDescription('Context defined in json config file')]
    property JsonContextFile: string read FJsonContextFile write FJsonContextFile;
  end;


  TFileComparerCLOptions = class(TFileTokenizerCLOptions)
  private
    FSecondFile: string;
    FIgnoreWhitespaceEOL: Boolean;
    FIgnoreWhitespace: Boolean;
    FIgnoreEOL: Boolean;
    FIgnoreComments: Boolean;
    FStopAfterFirstDiff: Boolean;
    FMaxDiffs: Integer;
  public
    [CLPPosition(2), CLPLongName('file2'), CLPDescription('Second source file to tokenize')]
    property SecondFile: string read FSecondFile write FSecondFile;


    [CLPLongNameAttribute('ignore-whitespace-eol'), CLPName('t'), CLPDescription('Ignore whitespace and EOL tokens')]
    property IgnoreWhitespaceEOL: Boolean read FIgnoreWhitespaceEOL write FIgnoreWhitespaceEOL;

    [CLPLongNameAttribute('ignore-whitespace'), CLPName('w'), CLPDescription('Ignore Whitespace tokens')]
    property IgnoreWhitespace: Boolean read FIgnoreWhitespace write FIgnoreWhitespace;

    [CLPLongNameAttribute('ignore-eol'), CLPName('e'), CLPDescription('Ignore EOL tokens')]
    property IgnoreEOL: Boolean read FIgnoreEOL write FIgnoreEOL;

    [CLPLongNameAttribute('ignore-comments'), CLPName('c'), CLPDescription('Ignore Comment tokens')]
    property IgnoreComments: Boolean read FIgnoreComments write FIgnoreComments;

    [CLPLongNameAttribute('stop-after-first-diff'), CLPName('x'), CLPDescription('Stop after the first difference is found')]
    property StopAfterFirstDiff: Boolean read FStopAfterFirstDiff write FStopAfterFirstDiff;

    [CLPLongNameAttribute('max-diffs'), CLPDescription('Limit reported differences to N (0 = unlimited)'), CLPDefault('0')]
    property MaxDiffs: Integer read FMaxDiffs write FMaxDiffs;
  end;

  TTokenStatsCLOptions = class(TFileTokenizerCLOptions)
  private
    FRecursive: Boolean;
  public
    [CLPLongName('recursive'), CLPName('r'), CLPDescription('Search subdirectories recursively')]
    property Recursive: Boolean read FRecursive write FRecursive;
  end;


  TConfigOptions = record
    AbortProgram: Boolean;
    ExitCode: Integer;
    FileName: string;
    FileContents: string;
    Encoding: TEncoding;
    OutputFormat: TOutputFormat;
    SkipAnsiFallback: Boolean;
    LexAsm:Boolean;
  end;

  TFileCompareConfigOptions = record
    BaseOptions: TConfigOptions;
    SecondFile: string;
    SecondContents: string;
    IgnoreWhitespace: Boolean;
    IgnoreEOL: Boolean;
    IgnoreComments: Boolean;
    MaxDiffs: Integer;
    StopAfterFirstDiff: Boolean;
  end;

  TConditionalConfig = record
    Common: TConfigOptions;
    JSonContextFile: string;
  end;

  TStatsConfig = record
    Common: TConfigOptions;
    Recursive: Boolean;
  end;

  TCommandLineParser = class
  protected
    class function ParseSharedOptions(const Opts:TFileTokenizerCLOptions; const HelpLine1, HelpLine2:string):TConfigOptions;
  public
    class function ParseSingleFile(const HelpLine1, HelpLine2:string):TConfigOptions;
    class function ParseFileCompare(const HelpLine1, HelpLine2:string):TFileCompareConfigOptions;
    class function ParseStats(const HelpLine1, HelpLine2: string): TStatsConfig;

    class function ParseConditionalSingleFile(const HelpLine1, HelpLine2:string):TConditionalConfig;

    class function ReadAllText(const FileName: string; const Encoding:TEncoding; const SkipAnsiFallback:Boolean): string;
  end;


implementation
uses
  System.Classes,
  System.IOUtils,
  Winapi.Windows;


class function TWinUtils.GetModuleVersion(const AIncludeBuild:Boolean=False):string;
const
  ROOT_BLOCK = '\';
var
  VersionInfoBlock: TMemoryStream;
  AppResource: TResourceStream;
  FixedFileInfo: PVSFixedFileInfo;
  puLen: UINT;
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

class function TLexerUtils.RoundTripCheck(const ATokens: TTokenList; const ASource: string): Boolean;
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


class function TCommandLineParser.ParseConditionalSingleFile(const HelpLine1, HelpLine2:string):TConditionalConfig;
var
  Opts: TConditionalFileTokenizerCLOptions;
begin
  Result := Default(TConditionalConfig);

  Opts := TConditionalFileTokenizerCLOptions.Create;
  try
    //TokenDump+TokenStats+TokenCompare share a handful of options
    Result.Common := ParseSharedOptions(Opts, HelpLine1, HelpLine2);
    if Result.Common.AbortProgram then Exit(Result);

    if not TFile.Exists(Result.Common.FileName) then
    begin
      WriteLn('error: file not found: ', Result.Common.FileName);
      Result.Common.ExitCode := 1;
      Result.Common.AbortProgram := True;
      Exit(Result);
    end;
    try
      Result.Common.FileContents := ReadAllText(Result.Common.FileName, Result.Common.Encoding, Result.Common.SkipAnsiFallback);
    except
      on E: Exception do
      begin
        WriteLn('error: could not read source file: ', E.Message);
        Result.Common.ExitCode := 1;
        Result.Common.AbortProgram := True;
        Exit(Result);
      end;
    end;



    Result.JSonContextFile := Opts.JsonContextFile;

    if (not Result.JsonContextFile.IsEmpty) and (not TFile.Exists(Result.JsonContextFile)) then
    begin
      WriteLn('error: json config file not found: ', Result.JsonContextFile);
      Result.Common.ExitCode := 1;
      Result.Common.AbortProgram := True;
      Exit(Result);
    end;

  finally
    Opts.Free;
  end;
end;

class function TCommandLineParser.ParseSingleFile(const HelpLine1, HelpLine2:string):TConfigOptions;
var
  Opts: TFileTokenizerCLOptions;
begin
  Opts := TFileTokenizerCLOptions.Create;
  try
    Result := ParseSharedOptions(Opts, HelpLine1, HelpLine2);
    if Result.AbortProgram then Exit;

    if not TFile.Exists(Result.FileName) then
    begin
      WriteLn('error: file not found: ', Result.FileName);
      Result.ExitCode := 1;
      Result.AbortProgram := True;
      Exit;
    end;
    try
      Result.FileContents := ReadAllText(Result.FileName, Result.Encoding, Opts.SkipAnsiFallback);
    except
      on E: Exception do
      begin
        WriteLn('error: could not read file: ', E.Message);
        Result.ExitCode := 1;
        Result.AbortProgram := True;
      end;
    end;
  finally
    Opts.Free;
  end;
end;

class function TCommandLineParser.ParseSharedOptions(const Opts:TFileTokenizerCLOptions; const HelpLine1, HelpLine2:string):TConfigOptions;
var
  Parser: IGpCommandLineParser;
  Line: string;
begin
  Result := Default(TConfigOptions);
  Result.AbortProgram := True;

  Parser := CreateCommandLineParser;
  Parser.Options := [opAllowInherited];

  if not Parser.Parse(Opts) then
  begin
    WriteLn('error: ', Parser.ErrorInfo.Text);
    Result.ExitCode := 1;
    Exit;
  end;

  if Opts.Version then
  begin
    WriteLn(TWinUtils.GetModuleVersion);
    Exit;
  end;

  if Opts.Help or (Opts.InputFile = '') then  // inputfile is the one required parameter
  begin
    WriteLn(HelpLine1);
    WriteLn(HelpLine2);
    WriteLn('A command-line utility for delphi-lexer from Continuous-Delphi');
    WriteLn('https://github.com/continuous-delphi/delphi-lexer');
    WriteLn('MIT Licensed.  Copyright (C) 2026, Darian Miller');
    WriteLn('Version: ', TWinUtils.GetModuleVersion);
    WriteLn;
    for Line in Parser.Usage do
    begin
      WriteLn(Line);
    end;
    WriteLn;
    if Opts.InputFile = ''  then Result.ExitCode := 1;
    Exit;
  end;

  Result.FileName := Opts.InputFile;
  Result.SkipAnsiFallback := Opts.SkipAnsiFallback;
  Result.LexAsm := Opts.LexAsm;

  Result.Encoding := TLexerUtils.ResolveEncoding(Opts.Encoding);
  if not Assigned(Result.Encoding) then
  begin
    WriteLn('error: unknown encoding: ', Opts.Encoding);
    WriteLn('Supported: utf-8, utf-16, utf-16be, ansi, ascii, default');
    Result.ExitCode := 1;
    Exit;
  end;

  if SameText(Opts.Format, 'json') then
  begin
    Result.OutputFormat := TOutputFormat.ofJson;
  end
  else if SameText(Opts.Format, 'text') then
  begin
    Result.OutputFormat := TOutputFormat.ofText;
  end
  else
  begin
    WriteLn('error: unknown format: ', Opts.Format);
    WriteLn('Supported formats: text, json');
    Result.ExitCode := 1;
    Exit;
  end;


  Result.AbortProgram := False;
end;

class function TCommandLineParser.ParseFileCompare(const HelpLine1, HelpLine2:string):TFileCompareConfigOptions;
var
  Opts: TFileComparerCLOptions;
begin
  Result := Default(TFileCompareConfigOptions);

  Opts := TFileComparerCLOptions.Create;
  try
    //TokenDump+TokenStats+TokenCompare share a handful of options
    Result.BaseOptions := ParseSharedOptions(Opts, HelpLine1, HelpLine2);
    if Result.BaseOptions.AbortProgram then Exit(Result);

    if not TFile.Exists(Result.BaseOptions.FileName) then
    begin
      WriteLn('error: file not found: ', Result.BaseOptions.FileName);
      Result.BaseOptions.ExitCode := 1;
      Result.BaseOptions.AbortProgram := True;
      Exit(Result);
    end;
    try
      Result.BaseOptions.FileContents := ReadAllText(Result.BaseOptions.FileName, Result.BaseOptions.Encoding, Result.BaseOptions.SkipAnsiFallback);
    except
      on E: Exception do
      begin
        WriteLn('error: could not read file: ', E.Message);
        Result.BaseOptions.ExitCode := 1;
        Result.BaseOptions.AbortProgram := True;
        Exit(Result);
      end;
    end;

    //TokenCompare offers additional options:

    if Opts.IgnoreWhitespaceEOL then
    begin
      Result.IgnoreWhitespace := True;
      Result.IgnoreEOL := True;
    end
    else
    begin
      Result.IgnoreWhitespace := Opts.IgnoreWhitespace;
      Result.IgnoreEOL := Opts.IgnoreEOL;
    end;
    Result.IgnoreComments := Opts.IgnoreComments;
    Result.StopAfterFirstDiff := Opts.StopAfterFirstDiff;
    if Result.StopAfterFirstDiff then
    begin
      Result.MaxDiffs := 1; //effective max diffs is 1, regardless of setting
    end
    else
    begin
      Result.MaxDiffs := Opts.MaxDiffs;
      if Result.MaxDiffs <= 0 then
      begin
        Result.MaxDiffs := MaxInt;
      end;
    end;

    Result.SecondFile := Opts.SecondFile;
    if Result.SecondFile.IsEmpty then
    begin
      WriteLn('error: second file not specified');
      Result.BaseOptions.ExitCode := 1;
      Result.BaseOptions.AbortProgram := True;
      Exit;
    end;
    if not TFile.Exists(Result.SecondFile) then
    begin
      WriteLn('error: file not found: ', Result.SecondFile);
      Result.BaseOptions.ExitCode := 1;
      Result.BaseOptions.AbortProgram := True;
      Exit;
    end;

    try
      Result.SecondContents := ReadAllText(Result.SecondFile, Result.BaseOptions.Encoding, Result.BaseOptions.SkipAnsiFallback);
    except
      on E: Exception do
      begin
        WriteLn('error: could not read file: ', E.Message);
        Result.BaseOptions.ExitCode := 1;
        Result.BaseOptions.AbortProgram := True;
      end;
    end;
  finally
    Opts.Free;
  end;
end;


class function TCommandLineParser.ParseStats(const HelpLine1, HelpLine2: string): TStatsConfig;
var
  Opts: TTokenStatsCLOptions;
begin
  Result := Default(TStatsConfig);
  Opts := TTokenStatsCLOptions.Create;
  try
    Result.Common := ParseSharedOptions(Opts, HelpLine1, HelpLine2);
    if Result.Common.AbortProgram then Exit;
    Result.Recursive := Opts.Recursive;
  finally
    Opts.Free;
  end;
end;


class function TCommandLineParser.ReadAllText(const FileName: string; const Encoding:TEncoding; const SkipAnsiFallback:Boolean): string;
var
  Win1252:TEncoding;
begin
  try
    Result := TFile.ReadAllText(FileName, Encoding);
  except
    on E:EEncodingError do
      begin
        // Original assumption is that most code files are UTF-8 today, but that can lead to trouble
        // Prime example is the RTL file in Delphi 13: source\data\cloud\Data.Cloud.AzureAPI.pas
        // This has a special right quote character saved as ANSI (Win1252 codepage)
        // Byte 0x92 (Decimal 146) is invalid with UTF-8
        if SkipAnsiFallback then
        begin
          raise;
        end
        else //automatically try again with 1252
        begin
          Win1252 :=  TMBCSEncoding.Create(1252, {UseBOM=}False);
          try
            Result := TFile.ReadAllText(FileName, Win1252);
          finally
            Win1252.Free;
          end;
        end;
      end;
    else
    begin
      raise;
    end;
  end;
end;

end.
