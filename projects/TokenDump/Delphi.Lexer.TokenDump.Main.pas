unit Delphi.Lexer.TokenDump.Main;

interface

uses
  Delphi.Token,
  Delphi.Token.List,
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
    class function ParseCommandLine: TConfigOptions; static;
    class procedure ShowUsage; static;
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
  System.IOUtils,
  System.SysUtils,
  System.JSON,
  Delphi.Token.Kind,
  Delphi.Lexer;


class function TTokenDump.AppDescription: String;
begin
  Result := DefaultAppDescription;
end;

class function TTokenDump.AppName: String;
begin
  Result := DefaultAppName;
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

class procedure TTokenDump.ShowUsage;
begin
  WriteLn(AppName);
  WriteLn(AppDescription);
  WriteLn('A command-line utility for delphi-lexer from Continuous-Delphi');
  WriteLn('https://github.com/continuous-delphi/delphi-lexer');
  WriteLn('MIT Licensed. Copyright (C) 2026, Darian Miller');
  WriteLn;
  WriteLn('Usage:');
  WriteLn('  ', ExtractFileName(ParamStr(0)), ' <file> [options]');
  WriteLn;
  WriteLn('Options:');
  WriteLn('  --encoding:<name>       Source encoding: utf-8, utf-16, utf-16be, ansi, ascii, default');
  WriteLn('  --format:<name>         Output format: text or json');
  WriteLn('  -a, --no-ansi-fallback  Do not retry file reads with ANSI/Windows-1252');
  WriteLn('  -?, --help              Show this help and exit');
end;

class function TTokenDump.ParseCommandLine: TConfigOptions;
var
  I: Integer;
  Arg: string;
  Value: string;
  EncodingName: string;
  FormatName: string;
begin
  Result := Default(TConfigOptions);
  Result.AbortProgram := True;

  EncodingName := 'utf-8';
  FormatName := 'text';

  for I := 1 to ParamCount do
  begin
    Arg := ParamStr(I);

    if SameText(Arg, '-?') or SameText(Arg, '--help') then
    begin
      ShowUsage;
      Result.ExitCode := 0;
      Exit;
    end
    else if SameText(Arg, '-a') or SameText(Arg, '--no-ansi-fallback') then
      Result.SkipAnsiFallback := True
    else if TLexerUtils.TryReadOptionValue(Arg, '--encoding', Value) then
      EncodingName := Value
    else if TLexerUtils.TryReadOptionValue(Arg, '--format', Value) then
      FormatName := Value
    else if (Arg <> '') and (Arg[1] = '-') then
    begin
      WriteLn('error: unknown option: ', Arg);
      Result.ExitCode := ExitCode_Fatal;
      Exit;
    end
    else if Result.FileName = '' then
      Result.FileName := Arg
    else
    begin
      WriteLn('error: too many input files');
      Result.ExitCode := ExitCode_Fatal;
      Exit;
    end;
  end;

  if Result.FileName = '' then
  begin
    ShowUsage;
    Result.ExitCode := ExitCode_Fatal;
    Exit;
  end;

  Result.Encoding := TLexerUtils.ResolveEncoding(EncodingName);
  if not Assigned(Result.Encoding) then
  begin
    WriteLn('error: unknown encoding: ', EncodingName);
    WriteLn('Supported: utf-8, utf-16, utf-16be, ansi, ascii, default');
    Result.ExitCode := ExitCode_Fatal;
    Exit;
  end;

  if SameText(FormatName, 'json') then
    Result.OutputFormat := TOutputFormat.ofJson
  else if SameText(FormatName, 'text') then
    Result.OutputFormat := TOutputFormat.ofText
  else
  begin
    WriteLn('error: unknown format: ', FormatName);
    WriteLn('Supported formats: text, json');
    Result.ExitCode := ExitCode_Fatal;
    Exit;
  end;

  if not TFile.Exists(Result.FileName) then
  begin
    WriteLn('error: file not found: ', Result.FileName);
    Result.ExitCode := ExitCode_Fatal;
    Exit;
  end;

  try
    Result.FileContents := TLexerUtils.ReadAllText(Result.FileName, Result.Encoding, Result.SkipAnsiFallback);
  except
    on E: Exception do
    begin
      WriteLn('error: could not read file: ', E.Message);
      Result.ExitCode := ExitCode_Fatal;
      Exit;
    end;
  end;

  Result.AbortProgram := False;
end;

class function TTokenDump.WriteOutput(const Config: TConfigOptions; const Tokens: TTokenList):Integer;
begin
  case Config.OutputFormat of
    TOutputFormat.ofText: Result := WriteTextOutput(Config, Tokens);
    TOutputFormat.ofJson: Result := WriteJsonOutput(Config, Tokens);
  else
    Assert(False, 'Invalid output format');
    Result := ExitCode_Fatal;
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

  Config := ParseCommandLine;
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

  //toconsider: add KeywordKind enum to output if not kwNone (like kwBegin)
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
      //toconsider: add keywordKind enum to output if not kwNone (like kwBegin)
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
