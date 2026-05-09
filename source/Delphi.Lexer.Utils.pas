(*

  delphi-lexer
  https://github.com/continuous-delphi/delphi-lexer

  A lightweight, lossless lexer for Delphi source code.
  Includes TokenDump, TokenStats, and TokenCompare utilities
  plus a syntax highlighter for SynEdit.

  License: MIT
  Copyright (c) 2026 Darian Miller

*)

unit Delphi.Lexer.Utils;

interface
uses
  System.SysUtils,
  Delphi.Token,
  Delphi.Token.List;

type

  TAppServices = class
    class function GetAppVersion:string;
  end;

  {$IFDEF MSWINDOWS}
  TWinUtils = class
    class function GetModuleVersion(const AIncludeBuild:Boolean=False):string;
  end;
  {$ENDIF}

  TLexerUtils = class
    // Return a printable, single-line representation of S.
    // Control characters are replaced with <TAG> codes.
    // Truncated at 48 visible characters with '...' suffix.
    class function SafeText(const S: string): string;
    // Map a case-insensitive encoding name to a TEncoding singleton.
    // Returns nil if the name is not recognised.
    class function ResolveEncoding(const AName: string): TEncoding;
    class function TryReadOptionValue(const Arg, Name: string; out Value: string): Boolean;
    class function ReadAllText(const FileName: string; const Encoding:TEncoding; const SkipAnsiFallback:Boolean): string;

    class function RoundTripCheck(const ATokens: TTokenList; const ASource: string):Boolean;
  end;

  TOutputFormat = (ofText, ofJson);


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


implementation
uses
  System.Classes,
  System.IOUtils,
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  {$ENDIF}
  FMX.Platform;


class function TAppServices.GetAppVersion:string;
var
  AppService:IFMXApplicationService;
begin
  Result := '';
  if TPlatformServices.Current.SupportsPlatformService(IFMXApplicationService, IInterface(AppService)) then
    Result := AppService.AppVersion
  {$IFDEF MSWINDOWS}
  else
    Result := TWinUtils.GetModuleVersion;
  {$ENDIF}
end;

{$IFDEF MSWINDOWS}
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
{$ENDIF}

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

class function TLexerUtils.TryReadOptionValue(const Arg, Name: string; out Value: string): Boolean;
var
  Prefix: string;
begin
  Prefix := Name + ':';
  if SameText(Copy(Arg, 1, Length(Prefix)), Prefix) then
  begin
    Value := Copy(Arg, Length(Prefix) + 1, MaxInt);
    Exit(True);
  end;

  Prefix := Name + '=';
  if SameText(Copy(Arg, 1, Length(Prefix)), Prefix) then
  begin
    Value := Copy(Arg, Length(Prefix) + 1, MaxInt);
    Exit(True);
  end;

  Result := False;
end;

class function TLexerUtils.ReadAllText(const FileName: string; const Encoding:TEncoding; const SkipAnsiFallback:Boolean): string;
var
  Win1252:TEncoding;
begin
  try
    Result := TFile.ReadAllText(FileName, Encoding);
  except
    on E:EEncodingError do
      begin
        if SkipAnsiFallback then
        begin
          raise;
        end
        else
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
