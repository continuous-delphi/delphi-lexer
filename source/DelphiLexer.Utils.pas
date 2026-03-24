unit DelphiLexer.Utils;

interface
uses
  System.SysUtils,
  System.Generics.Collections,
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


implementation
uses
  System.Classes,
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


end.
