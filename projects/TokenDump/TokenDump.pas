unit TokenDump;

interface

uses
  System.Generics.Collections,
  DelphiLexer.Token;

type

  TTokenDump = record
  private
    class function WriteTextOutput(Tokens: TList<TToken>; const ASource: string): Integer; static;
    class function WriteJsonOutput(const AFileName, AEncodingName: string; Tokens: TList<TToken>; const ASource: string): Integer; static;
  public
    class function Run: Integer; static;
  end;


implementation

uses
  System.SysUtils,
  System.IOUtils,
  System.JSON,
  DelphiLexer.Utils,
  DelphiLexer.Lexer;


class function TTokenDump.WriteTextOutput(Tokens: TList<TToken>; const ASource: string): Integer;
var
  Tok:          TToken;
  I:            Integer;
  InvalidCount: Integer;
  LC:           string;
  SB:           TStringBuilder;
  RoundTripOK:  Boolean;
begin

  // Header
  WriteLn('');
  WriteLn('DelphiLexer.TokenDump');
  WriteLn('formatVersion: ', '1.0.0');
  WriteLn('');

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
       TLexerUtils.SafeText(Tok.Text)]));
  end;

  // Round-trip check.
  SB := TStringBuilder.Create(System.Length(ASource));
  try
    for I := 0 to Tokens.Count - 1 do
      SB.Append(Tokens[I].Text);
    RoundTripOK := (SB.ToString = ASource);
  finally
    SB.Free;
  end;

  // Summary.
  WriteLn;
  Write(Format('Tokens: %d; Source: %d chars;',
    [Tokens.Count, System.Length(ASource)]));
  if InvalidCount > 0 then
    Write(Format('  Invalid: %d ***;', [InvalidCount]))
  else
    Write('  Invalid: 0;');
  if RoundTripOK then
    WriteLn('  Round-trip: OK')
  else
    WriteLn('  Round-trip: FAIL ***');

  if InvalidCount > 0 then
    Result := 2
  else
    Result := 0;

end;


class function TTokenDump.WriteJsonOutput(const AFileName, AEncodingName: string; Tokens: TList<TToken>; const ASource: string): Integer;
var
  I:            Integer;
  InvalidCount: Integer;
  SB:           TStringBuilder;
  RoundTripOK:  Boolean;
  Root:         TJSONObject;
  Options:      TJSONObject;
  Summary:      TJSONObject;
  TokensArr:    TJSONArray;
  TokenObj:     TJSONObject;
  Tok:          TToken;
begin
  // Count invalids.
  InvalidCount := 0;
  for I := 0 to Tokens.Count - 1 do
    if Tokens[I].Kind = tkInvalid then
      Inc(InvalidCount);

  // Round-trip check.
  SB := TStringBuilder.Create(System.Length(ASource));
  try
    for I := 0 to Tokens.Count - 1 do
      SB.Append(Tokens[I].Text);
    RoundTripOK := (SB.ToString = ASource);
  finally
    SB.Free;
  end;

  Root := TJSONObject.Create;
  try
    Root.AddPair('tool', 'DelphiLexer.TokenDump');
    Root.AddPair('formatVersion', '1.0.0');
    Root.AddPair('sourceFile', AFileName);

    Options := TJSONObject.Create;
    Options.AddPair('encoding', AEncodingName);
    Root.AddPair('options', Options);

    Summary := TJSONObject.Create;
    Summary.AddPair('totalTokens',      TJSONNumber.Create(Tokens.Count));
    Summary.AddPair('sourceLength',     TJSONNumber.Create(System.Length(ASource)));
    Summary.AddPair('invalidTokenCount', TJSONNumber.Create(InvalidCount));
    Summary.AddPair('roundTripMatches',  TJSONBool.Create(RoundTripOK));
    Root.AddPair('summary', Summary);

    TokensArr := TJSONArray.Create;
    for I := 0 to Tokens.Count - 1 do
    begin
      Tok := Tokens[I];
      TokenObj := TJSONObject.Create;
      TokenObj.AddPair('index',  TJSONNumber.Create(I));
      TokenObj.AddPair('kind',   TokenKindName(Tok.Kind));
      TokenObj.AddPair('line',   TJSONNumber.Create(Tok.Line));
      TokenObj.AddPair('col',    TJSONNumber.Create(Tok.Col));
      TokenObj.AddPair('offset', TJSONNumber.Create(Tok.StartOffset));
      TokenObj.AddPair('length', TJSONNumber.Create(Tok.Length));
      TokenObj.AddPair('text',   Tok.Text);
      TokensArr.Add(TokenObj);
    end;
    Root.AddPair('tokens', TokensArr);

    WriteLn(Root.Format(2));
  finally
    Root.Free;
  end;

  if InvalidCount > 0 then
    Result := 2
  else
    Result := 0;
end;


class function TTokenDump.Run: Integer;
var
  FileName:     string;
  EncodingName: string;
  FormatName:   string;
  OutputFmt:    TOutputFormat;
  Encoding:     TEncoding;
  Source:       string;
  Lexer:        TDelphiLexer;
  Tokens:       TList<TToken>;
  I:            Integer;
begin
  Result       := 0;
  FileName     := '';
  EncodingName := 'utf-8';
  FormatName   := 'text';

  // Parse arguments.
  I := 1;
  while I <= ParamCount do
  begin
    if (ParamStr(I) = '--help') or (ParamStr(I) = '-h') or (ParamStr(I) = '-?') then
    begin
      WriteLn;
      WriteLn;
      WriteLn('Usage: DelphiLexer.TokenDump <file.pas> [--encoding <name>] [--format <name>]');
      WriteLn;
      WriteLn('A command-line utility for inspecting the token stream produced by delphi-lexer,');
      WriteLn('providing a lossless, position-accurate view of the source.');
      WriteLn;
      WriteLn('Options:');
      WriteLn('  --encoding <name>   Source file encoding (default: utf-8)');
      WriteLn('                      Supported: utf-8, utf-16, utf-16be, ansi, ascii, default');
      WriteLn('  --format <name>     Output format (default: text)');
      WriteLn('                      Supported: text, json');
      WriteLn('');
      WriteLn('DelphiLexer.TokenDump ', TWinUtils.GetModuleVersion);
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
    else if ParamStr(I) = '--format' then
    begin
      Inc(I);
      if I > ParamCount then
      begin
        WriteLn('error: --format requires a value');
        Exit(1);
      end;
      FormatName := ParamStr(I);
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
    WriteLn('Usage: DelphiLexer.TokenDump <file.pas> [--encoding <name>] [--format <name>]');
    Exit(1);
  end;

  Encoding := TLexerUtils.ResolveEncoding(EncodingName);
  if Encoding = nil then
  begin
    WriteLn('error: unknown encoding: ', EncodingName);
    WriteLn('Supported: utf-8, utf-16, utf-16be, ansi, ascii, default');
    Exit(1);
  end;

  if LowerCase(FormatName) = 'json' then
    OutputFmt := ofJson
  else if LowerCase(FormatName) = 'text' then
    OutputFmt := ofText
  else
  begin
    WriteLn('error: unknown format: ', FormatName);
    WriteLn('Supported formats: text, json');
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
    case OutputFmt of
      ofText: Result := WriteTextOutput(Tokens, Source);
      ofJson: Result := WriteJsonOutput(FileName, EncodingName, Tokens, Source);
    end;
  finally
    Tokens.Free;
    Lexer.Free;
  end;
end;

end.
