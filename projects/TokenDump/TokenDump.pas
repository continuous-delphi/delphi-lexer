unit TokenDump;

interface

uses
  System.SysUtils,
  DelphiLexer.Token;

type
  TTokenDumper = record
  private
    class function SafeText(const S: string): string; static;
    class function ResolveEncoding(const AName: string): TEncoding; static;
  public
    class function Run: Integer; static;
  end;

implementation

uses
  System.IOUtils,
  System.Generics.Collections,
  DelphiLexer.Lexer;


// Return a printable, single-line representation of S.
// Control characters are replaced with <TAG> codes.
// Truncated at 48 visible characters with '...' suffix.
class function TTokenDumper.SafeText(const S: string): string;
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


// Map a case-insensitive encoding name to a TEncoding singleton.
// Returns nil if the name is not recognised.
class function TTokenDumper.ResolveEncoding(const AName: string): TEncoding;
var
  Requested: string;
begin
  Requested := LowerCase(Trim(AName));

  if (Requested = 'utf-8') or (Requested = 'utf8') then
    Result := TEncoding.UTF8
  else if (Requested = 'utf-16') or (Requested = 'utf16') or (Requested = 'unicode') then
    Result := TEncoding.Unicode
  else if (Requested = 'utf-16be') or (Requested = 'utf16be') then
    Result := TEncoding.BigEndianUnicode
  else if Requested = 'ansi' then
    Result := TEncoding.ANSI
  else if Requested = 'ascii' then
    Result := TEncoding.ASCII
  else if Requested = 'default' then
    Result := TEncoding.Default
  else
    Result := nil;
end;


class function TTokenDumper.Run: Integer;
var
  FileName:     string;
  EncodingName: string;
  Encoding:     TEncoding;
  Source:       string;
  Lexer:        TDelphiLexer;
  Tokens:       TList<TToken>;
  Tok:          TToken;
  I:            Integer;
  InvalidCount: Integer;
  LC:           string;
  SB:           TStringBuilder;
  RoundTripOK:  Boolean;
begin
  Result       := 0;
  FileName     := '';
  EncodingName := 'utf-8';

  // Parse arguments.
  I := 1;
  while I <= ParamCount do
  begin
    if (ParamStr(I) = '--help') or (ParamStr(I) = '-h') then
    begin
      WriteLn('Usage: DelphiLexer.TokenDump <file.pas> [--encoding <name>]');
      WriteLn;
      WriteLn('Tokenizes a Delphi source file and writes the token stream to stdout.');
      WriteLn('Columns: Idx  Kind  L:C  Offset  Len  Text');
      WriteLn;
      WriteLn('Options:');
      WriteLn('  --encoding <name>   Source file encoding (default: utf-8)');
      WriteLn('                      Supported: utf-8, utf-16, utf-16be, ansi, ascii, default');
      Exit(1);
    end
    else if ParamStr(I) = '--encoding' then
    begin
      Inc(I);
      if I > ParamCount then
      begin
        WriteLn('error: --encoding requires a value');
        Exit(1);
      end;
      EncodingName := ParamStr(I);
    end
    else if (System.Length(ParamStr(I)) > 0) and (ParamStr(I)[1] <> '-') then
    begin
      if FileName <> '' then
      begin
        WriteLn('error: unexpected argument: ', ParamStr(I));
        Exit(1);
      end;
      FileName := ParamStr(I);
    end
    else
    begin
      WriteLn('error: unknown option: ', ParamStr(I));
      Exit(1);
    end;
    Inc(I);
  end;

  if FileName = '' then
  begin
    WriteLn('Usage: DelphiLexer.TokenDump <file.pas> [--encoding <name>]');
    Exit(1);
  end;

  Encoding := ResolveEncoding(EncodingName);
  if Encoding = nil then
  begin
    WriteLn('error: unknown encoding: ', EncodingName);
    WriteLn('Supported: utf-8, utf-16, utf-16be, ansi, ascii, default');
    Exit(1);
  end;

  if not TFile.Exists(FileName) then
  begin
    WriteLn('error: file not found: ', FileName);
    Exit(1);
  end;

  try
    Source := TFile.ReadAllText(FileName, Encoding);
  except
    on E: Exception do
    begin
      WriteLn('error: could not read file: ', E.Message);
      Exit(1);
    end;
  end;

  Lexer  := TDelphiLexer.Create;
  Tokens := nil;
  try
    Tokens := Lexer.Tokenize(Source);

    // Header.
    WriteLn(Format('  %5s  %-17s  %-7s  %6s  %5s  %s',
      ['Idx', 'Kind', 'L:C', 'Offset', 'Len', 'Text']));
    WriteLn('  ', StringOfChar('-', 5), '  ',
                  StringOfChar('-', 17), '  ',
                  StringOfChar('-', 7), '  ',
                  StringOfChar('-', 6), '  ',
                  StringOfChar('-', 5), '  ',
                  StringOfChar('-', 24));

    // One row per token.
    InvalidCount := 0;
    for I := 0 to Tokens.Count - 1 do
    begin
      Tok := Tokens[I];
      if Tok.Kind = tkInvalid then
        Inc(InvalidCount);
      LC := IntToStr(Tok.Line) + ':' + IntToStr(Tok.Col);
      WriteLn(Format('  %5d  %-17s  %7s  %6d  %5d  %s',
        [I, TokenKindName(Tok.Kind), LC, Tok.StartOffset, Tok.Length,
         SafeText(Tok.Text)]));
    end;

    // Round-trip check.
    SB := TStringBuilder.Create(System.Length(Source));
    try
      for I := 0 to Tokens.Count - 1 do
        SB.Append(Tokens[I].Text);
      RoundTripOK := (SB.ToString = Source);
    finally
      SB.Free;
    end;

    // Summary.
    WriteLn;
    Write(Format('Tokens: %d  Source: %d chars',
      [Tokens.Count, System.Length(Source)]));
    if InvalidCount > 0 then
      Write(Format('  Invalid: %d ***', [InvalidCount]))
    else
      Write('  Invalid: 0');
    if RoundTripOK then
      WriteLn('  Round-trip: OK')
    else
      WriteLn('  Round-trip: FAIL ***');

    if InvalidCount > 0 then
      Result := 2;

  finally
    Tokens.Free;
    Lexer.Free;
  end;
end;

end.
