unit TokenDump;

interface

uses
  DelphiLexer.Token;

type
  TTokenDumper = record
  private
    class function KindName(K: TTokenKind): string; static;
    class function SafeText(const S: string): string; static;
  public
    class function Run: Integer; static;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  System.Generics.Collections,
  DelphiLexer.Lexer;

class function TTokenDumper.KindName(K: TTokenKind): string;
begin
  case K of
    tkIdentifier:  Result := 'tkIdentifier';
    tkKeyword:     Result := 'tkKeyword';
    tkNumber:      Result := 'tkNumber';
    tkString:      Result := 'tkString';
    tkCharLiteral: Result := 'tkCharLiteral';
    tkComment:     Result := 'tkComment';
    tkDirective:   Result := 'tkDirective';
    tkSymbol:      Result := 'tkSymbol';
    tkWhitespace:  Result := 'tkWhitespace';
    tkEOL:         Result := 'tkEOL';
    tkEOF:         Result := 'tkEOF';
    tkInvalid:     Result := 'tkInvalid';
  else
    Result := '(unknown)';
  end;
end;


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


class function TTokenDumper.Run: Integer;
var
  FileName:     string;
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
  Result := 0;

  if (ParamCount <> 1) or (ParamStr(1) = '--help') or (ParamStr(1) = '-h') then
  begin
    WriteLn('Usage: DelphiLexer.TokenDump <file.pas>');
    WriteLn;
    WriteLn('Tokenizes a Delphi source file and writes the token stream to stdout.');
    WriteLn('Columns: Idx  Kind  L:C  Offset  Len  Text');
    Exit(1);
  end;

  FileName := ParamStr(1);
  if not TFile.Exists(FileName) then
  begin
    WriteLn('error: file not found: ', FileName);
    Exit(1);
  end;

  try
    //todo: Need to pass an encoding parameter.  If not provided, assume UTF8
    Source := TFile.ReadAllText(FileName, TEncoding.UTF8);
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
        [I, KindName(Tok.Kind), LC, Tok.StartOffset, Tok.Length,
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
