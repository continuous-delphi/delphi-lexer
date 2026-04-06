unit Delphi.Lexer.TokenDump.Main;

interface

uses
  Delphi.Token,
  Delphi.TokenList,
  Delphi.Lexer.Utils;

type

  TTokenDump = class
  private const
    DefaultAppName = 'Delphi.Lexer.TokenDump';
    DefaultAppDescription = 'Provides a lossless, position-accurate view of Object Pascal source code';
    ExitCode_Success = 0;
    ExitCode_Fatal = 1;
    ExitCode_InvalidTokens = 2;
    ExitCode_RoundTripFailed = 3; //tokenization failure
  private
    class function WriteTextOutput(const Config: TConfigOptions; const Tokens: TTokenList): Integer; static;
    class function WriteJsonOutput(const Config: TConfigOptions; const Tokens: TTokenList): Integer; static;
  protected
    class function AppName:String; virtual;
    class function AppDescription:String; virtual;
    class function Tokenize(const SourceCode:string):TTokenList; virtual;
    class function WriteOutput(const Config: TConfigOptions; const Tokens: TTokenList):Integer;
  public
    class function Run: Integer; static;
  end;


implementation

uses
  System.SysUtils,
  System.JSON,
  Delphi.TokenKind,
  Delphi.Lexer;


class function TTokenDump.AppDescription: String;
begin
  Result := DefaultAppName;
end;

class function TTokenDump.AppName: String;
begin
  Result := DefaultAppDescription;
end;

class function TTokenDump.Tokenize(const SourceCode:string):TTokenList;
var
  Lexer: TDelphiLexer;
begin
  Lexer  := TDelphiLexer.Create;
  try
    Result := Lexer.Tokenize(SourceCode);
  finally
    Lexer.Free;
  end;
end;

class function TTokenDump.WriteOutput(const Config: TConfigOptions; const Tokens: TTokenList):Integer;
begin
  case Config.OutputFormat of
    TOutputFormat.ofText: Result := WriteTextOutput(Config, Tokens);
    TOutputFormat.ofJson: Result := WriteJsonOutput(Config, Tokens);
  else
    Assert(False, 'Invalid output format');
  end;
end;

class function TTokenDump.Run: Integer;
var
  Config: TConfigOptions;
  Tokens: TTokenList;
begin

  {$IFDEF DEBUG}
  ReportMemoryLeaksOnShutdown := True;
  {$ENDIF}

  Config := TCommandLineParser.ParseSingleFile(AppName, AppDescription);
  if Config.AbortProgram then Exit(Config.ExitCode);

  Tokens := Tokenize(Config.FileContents);
  try
    Result := WriteOutput(Config, Tokens);
  finally
    Tokens.Free;
  end;
end;


class function TTokenDump.WriteTextOutput(const Config: TConfigOptions; const Tokens: TTokenList): Integer;
var
  Tok: TToken;
  I: Integer;
  RoundTripOK: Boolean;
  InvalidCount: Integer;
  LC: string;
begin

  RoundTripOK := TLexerUtils.RoundTripCheck(Tokens, Config.FileContents);

  // Header
  WriteLn('');
  WriteLn(AppName);
  WriteLn('inputFile: ', Config.FileName);
  WriteLn('formatVersion: ', '1.1.0'); // Bump if TEXT output structure (or logic) changes
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

  // Summary.
  WriteLn;
  Write(Format('Tokens: %d; Source: %d chars;',
    [Tokens.Count, System.Length(Config.FileContents)]));
  if InvalidCount > 0 then
    Write(Format(' Invalid: %d ***;', [InvalidCount]))
  else
    Write(' Invalid: 0;');

  if RoundTripOK then
  begin
    WriteLn(' Round-trip: OK');
    if InvalidCount > 0 then
      Result := ExitCode_InvalidTokens
    else
      Result := ExitCode_Success;
  end
  else
  begin
    WriteLn(' Round-trip: FAIL ***');
    Result := ExitCode_RoundTripFailed;
  end;

  WriteLn('Exit Code: ', Result);
end;



class function TTokenDump.WriteJsonOutput(const Config: TConfigOptions; const Tokens: TTokenList): Integer;
var
  I: Integer;
  InvalidCount: Integer;
  RoundTripOK: Boolean;
  Root: TJSONObject;
  Options: TJSONObject;
  Summary: TJSONObject;
  TokensArr: TJSONArray;
  TokenObj: TJSONObject;
  Tok: TToken;
begin

  InvalidCount := 0;
  RoundTripOK := TLexerUtils.RoundTripCheck(Tokens, Config.FileContents);

  Root := TJSONObject.Create;
  try
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
      TokenObj.AddPair('leadingTrivia', TJSONNumber.Create(Tok.LeadingTrivia.Count));
      TokenObj.AddPair('trailingTrivia', TJSONNumber.Create(Tok.TrailingTrivia.Count));
      TokenObj.AddPair('text',   Tok.Text);
      TokensArr.Add(TokenObj);

      if Tokens[I].Kind = tkInvalid then
        Inc(InvalidCount);
    end;

    if not RoundTripOK then
      Result := ExitCode_RoundTripFailed
    else if InvalidCount > 0 then
      Result := ExitCode_InvalidTokens
    else
      Result := ExitCode_Success;


    Root.AddPair('toolName', AppName);
    Root.AddPair('inputFile', Config.FileName);
    Root.AddPair('formatVersion', '1.2.0');  // Bump if JSON output structure (or logic) changes

    Options := TJSONObject.Create;
    Options.AddPair('encoding', Config.Encoding.EncodingName);
    Root.AddPair('options', Options);

    Summary := TJSONObject.Create;
    Summary.AddPair('totalTokens',      TJSONNumber.Create(Tokens.Count));
    Summary.AddPair('sourceLength',     TJSONNumber.Create(System.Length(Config.FileContents)));
    Summary.AddPair('invalidTokenCount', TJSONNumber.Create(InvalidCount));
    Summary.AddPair('roundTripMatches',  TJSONBool.Create(RoundTripOK));
    Summary.AddPair('exitCode',  TJSONNumber.Create(Result));
    Root.AddPair('summary', Summary);

    Root.AddPair('tokens', TokensArr);

    WriteLn(Root.Format({Indentation=} 2));
  finally
    Root.Free;
  end;

end;


end.
