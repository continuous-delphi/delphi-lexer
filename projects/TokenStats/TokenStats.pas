unit TokenStats;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  DelphiLexer.Utils,
  DelphiLexer.Token;

type

  TTokenStats = record
  public const
    AppName = 'DelphiLexer.TokenStats';
    ExitCode_Success = 0;
    ExitCode_InvalidTokens = 2;
    ExitCode_RoundTripFailed = 3; //tokenization failure
  private
    class function CollectSorted(Dict: TDictionary<string, Integer>): TList<TPair<string, Integer>>; static;
    class function WriteTextOutput(const Config: TConfigOptions; const Tokens: TList<TToken>): Integer; static;
    class function WriteJsonOutput(const Config: TConfigOptions; const Tokens: TList<TToken>): Integer; static;
  public
    class function Run: Integer; static;
  end;


implementation

uses
  System.JSON,
  System.Generics.Defaults,
  DelphiLexer.Lexer;


class function TTokenStats.Run: Integer;
var
  Options: TConfigOptions;
  Lexer: TDelphiLexer;
  Tokens: TList<TToken>;
begin

  {$IFDEF DEBUG}
  ReportMemoryLeaksOnShutdown := True;
  {$ENDIF}

  Options := TCommandLineParser.Parse(AppName, 'Provides token-level statistics and metrics of Object Pascal source code');
  if Options.AbortProgram then Exit(Options.ExitCode);

  Result := 0;

  Lexer  := TDelphiLexer.Create;
  Tokens := nil;
  try
    Tokens := Lexer.Tokenize(Options.FileContents);
    case Options.OutputFormat of
      TOutputFormat.ofText: Result := WriteTextOutput(Options, Tokens);
      TOutputFormat.ofJson: Result := WriteJsonOutput(Options, Tokens);
    else
      Assert(False, 'Invalid output format');
    end;
  finally
    Tokens.Free;
    Lexer.Free;
  end;

end;



// Collect all entries from Dict into a new list sorted by count descending,
// then alphabetically ascending on ties. Caller owns the returned list.
class function TTokenStats.CollectSorted(Dict: TDictionary<string, Integer>): TList<TPair<string, Integer>>;
var
  Pair: TPair<string, Integer>;
begin
  Result := TList<TPair<string, Integer>>.Create;
  for Pair in Dict do
    Result.Add(Pair);
  Result.Sort(TComparer<TPair<string, Integer>>.Construct(
    function(const A, B: TPair<string, Integer>): Integer
    begin
      Result := B.Value - A.Value;
      if Result = 0 then
        Result := CompareStr(A.Key, B.Key);
    end));
end;


class function TTokenStats.WriteTextOutput(const Config: TConfigOptions; const Tokens: TList<TToken>): Integer;
const
  TOP_N = 10;
var
  CountsByKind: array[TTokenKind] of Integer;
  KeywordCounts: TDictionary<string, Integer>;
  SymbolCounts: TDictionary<string, Integer>;
  InvalidCount: Integer;
  MaxLine: Integer;
  RoundTripOK: Boolean;
  I: Integer;
  Tok: TToken;
  K: TTokenKind;
  Lower: string;
  Existing: Integer;
  Pairs: TList<TPair<string, Integer>>;
  N: Integer;
begin

  InvalidCount := 0;
  MaxLine := 0;
  for K := Low(TTokenKind) to High(TTokenKind) do
    CountsByKind[K] := 0;

  KeywordCounts := TDictionary<string, Integer>.Create;
  SymbolCounts := nil;
  try
    SymbolCounts  := TDictionary<string, Integer>.Create;

    // One pass over tokens.
    for I := 0 to Tokens.Count - 1 do
    begin
      Tok := Tokens[I];
      Inc(CountsByKind[Tok.Kind]);
      if (Tok.Kind <> tkEOF) and (Tok.Line > MaxLine) then
        MaxLine := Tok.Line;
      case Tok.Kind of
        tkKeyword:
        begin
          Lower := LowerCase(Tok.Text);
          if not KeywordCounts.TryGetValue(Lower, Existing) then Existing := 0;
          KeywordCounts.AddOrSetValue(Lower, Existing + 1);
        end;
        tkSymbol:
        begin
          if not SymbolCounts.TryGetValue(Tok.Text, Existing) then Existing := 0;
          SymbolCounts.AddOrSetValue(Tok.Text, Existing + 1);
        end;
        tkInvalid: Inc(InvalidCount);
      end;
    end;

    RoundTripOK := TLexerUtils.RoundTripCheck(Tokens, Config.FileContents);

    // Header.
    WriteLn('');
    WriteLn(AppName);
    WriteLn('inputFile: ', Config.FileName);
    WriteLn('formatVersion: ', '1.0.0'); // Bump if TEXT output structure changes
    WriteLn('');
    WriteLn(Format('%-18s : %s', ['File', Config.FileName]));
    WriteLn(Format('%-18s : %d', ['Tokens', Tokens.Count]));
    WriteLn(Format('%-18s : %d', ['Lines', MaxLine]));
    WriteLn(Format('%-18s : %d', ['Invalid', InvalidCount]));
    if RoundTripOK then
      WriteLn(Format('%-18s : %s', ['RoundTrip', 'PASS']))
    else
      WriteLn(Format('%-18s : %s', ['RoundTrip', 'FAIL ***']));

    WriteLn;
    WriteLn('By Kind:');
    for K := Low(TTokenKind) to High(TTokenKind) do
      WriteLn(Format('  %-16s : %d', [TokenKindName(K), CountsByKind[K]]));

    WriteLn;
    WriteLn('Top Keywords:');
    Pairs := CollectSorted(KeywordCounts);
    try
      if Pairs.Count = 0 then
        WriteLn('  (none)')
      else
      begin
        N := Pairs.Count;
        if N > TOP_N then N := TOP_N;
        for I := 0 to N - 1 do
          WriteLn(Format('  %-16s : %d', [Pairs[I].Key, Pairs[I].Value]));
      end;
    finally
      Pairs.Free;
    end;

    WriteLn;
    WriteLn('Top Symbols:');
    Pairs := CollectSorted(SymbolCounts);
    try
      if Pairs.Count = 0 then
        WriteLn('  (none)')
      else
      begin
        N := Pairs.Count;
        if N > TOP_N then N := TOP_N;
        for I := 0 to N - 1 do
          WriteLn(Format('  %-16s : %d', [Pairs[I].Key, Pairs[I].Value]));
      end;
    finally
      Pairs.Free;
    end;

  finally
    KeywordCounts.Free;
    SymbolCounts.Free;
  end;

  if not RoundTripOk then
    Result := ExitCode_RoundTripFailed
  else if InvalidCount > 0 then
    Result := ExitCode_InvalidTokens
  else
    Result := ExitCode_Success;

  WriteLn('');
  WriteLn('Exit Code: ', Result);

end;


class function TTokenStats.WriteJsonOutput(const Config: TConfigOptions; const Tokens: TList<TToken>): Integer;
var
  CountsByKind: array[TTokenKind] of Integer;
  KeywordCounts: TDictionary<string, Integer>;
  SymbolCounts: TDictionary<string, Integer>;
  InvalidTokens: TList<TToken>;
  InvalidCount: Integer;
  MaxLine: Integer;
  RoundTripOK: Boolean;
  I: Integer;
  Tok: TToken;
  K: TTokenKind;
  Lower: string;
  Existing: Integer;
  Root: TJSONObject;
  Options: TJSONObject;
  Summary: TJSONObject;
  CountsObj: TJSONObject;
  KwArr: TJSONArray;
  SymArr: TJSONArray;
  InvArr: TJSONArray;
  EntryObj: TJSONObject;
  Pairs: TList<TPair<string, Integer>>;
  Pair: TPair<string, Integer>;
  TotalExclEOF: Integer;
  TotalExclTrivia: Integer;
begin

  for K := Low(TTokenKind) to High(TTokenKind) do
    CountsByKind[K] := 0;
  KeywordCounts := TDictionary<string, Integer>.Create;
  SymbolCounts  := TDictionary<string, Integer>.Create;
  InvalidTokens := TList<TToken>.Create;
  InvalidCount  := 0;
  MaxLine       := 0;
  try
    // One pass over tokens.
    for I := 0 to Tokens.Count - 1 do
    begin
      Tok := Tokens[I];
      Inc(CountsByKind[Tok.Kind]);
      if (Tok.Kind <> tkEOF) and (Tok.Line > MaxLine) then
        MaxLine := Tok.Line;
      case Tok.Kind of
        tkKeyword:
        begin
          Lower := LowerCase(Tok.Text);
          if not KeywordCounts.TryGetValue(Lower, Existing) then Existing := 0;
          KeywordCounts.AddOrSetValue(Lower, Existing + 1);
        end;
        tkSymbol:
        begin
          if not SymbolCounts.TryGetValue(Tok.Text, Existing) then Existing := 0;
          SymbolCounts.AddOrSetValue(Tok.Text, Existing + 1);
        end;
        tkInvalid:
        begin
          Inc(InvalidCount);
          InvalidTokens.Add(Tok);
        end;
      end;
    end;

    RoundTripOK := TLexerUtils.RoundTripCheck(Tokens, Config.FileContents);
    TotalExclEOF    := Tokens.Count - CountsByKind[tkEOF];
    TotalExclTrivia := Tokens.Count - CountsByKind[tkWhitespace]
                                    - CountsByKind[tkEOL]
                                    - CountsByKind[tkEOF];
    if not RoundTripOK then
      Result := ExitCode_RoundTripFailed
    else if InvalidCount > 0 then
      Result := ExitCode_InvalidTokens
    else
      Result := ExitCode_Success;


    // Build JSON.
    Root := TJSONObject.Create;
    try
      Root.AddPair('toolName', AppName);
      Root.AddPair('inputFile', Config.FileName);
      Root.AddPair('formatVersion', '1.0.0');  // Bump if JSON output structure changes

      Options := TJSONObject.Create;
      Options.AddPair('encoding', Config.Encoding.EncodingName);
      Root.AddPair('options', Options);

      Summary := TJSONObject.Create;
      Summary.AddPair('totalTokens',              TJSONNumber.Create(Tokens.Count));
      Summary.AddPair('totalTokensExcludingEOF',  TJSONNumber.Create(TotalExclEOF));
      Summary.AddPair('totalTokensExcludingTrivia', TJSONNumber.Create(TotalExclTrivia));
      Summary.AddPair('invalidTokenCount',        TJSONNumber.Create(InvalidCount));
      Summary.AddPair('eofTokenCount',            TJSONNumber.Create(CountsByKind[tkEOF]));
      Summary.AddPair('roundTripMatches',         TJSONBool.Create(RoundTripOK));
      Summary.AddPair('lineCountEstimate',        TJSONNumber.Create(MaxLine));
      Summary.AddPair('exitCode',  TJSONNumber.Create(Result));
      Root.AddPair('summary', Summary);

      CountsObj := TJSONObject.Create;
      for K := Low(TTokenKind) to High(TTokenKind) do
        CountsObj.AddPair(TokenKindName(K), TJSONNumber.Create(CountsByKind[K]));
      Root.AddPair('countsByKind', CountsObj);

      // keywordCounts -- all keywords sorted by count desc.
      KwArr := TJSONArray.Create;
      Pairs := CollectSorted(KeywordCounts);
      try
        for Pair in Pairs do
        begin
          EntryObj := TJSONObject.Create;
          EntryObj.AddPair('keyword', Pair.Key);
          EntryObj.AddPair('count',   TJSONNumber.Create(Pair.Value));
          KwArr.Add(EntryObj);
        end;
      finally
        Pairs.Free;
      end;
      Root.AddPair('keywordCounts', KwArr);

      // symbolCounts -- all symbols sorted by count desc.
      SymArr := TJSONArray.Create;
      Pairs := CollectSorted(SymbolCounts);
      try
        for Pair in Pairs do
        begin
          EntryObj := TJSONObject.Create;
          EntryObj.AddPair('symbol', Pair.Key);
          EntryObj.AddPair('count',  TJSONNumber.Create(Pair.Value));
          SymArr.Add(EntryObj);
        end;
      finally
        Pairs.Free;
      end;
      Root.AddPair('symbolCounts', SymArr);

      // invalidTokens -- details for each tkInvalid token.
      InvArr := TJSONArray.Create;
      for I := 0 to InvalidTokens.Count - 1 do
      begin
        Tok := InvalidTokens[I];
        EntryObj := TJSONObject.Create;
        EntryObj.AddPair('text',        Tok.Text);
        EntryObj.AddPair('line',        TJSONNumber.Create(Tok.Line));
        EntryObj.AddPair('col',         TJSONNumber.Create(Tok.Col));
        EntryObj.AddPair('startOffset', TJSONNumber.Create(Tok.StartOffset));
        EntryObj.AddPair('length',      TJSONNumber.Create(Tok.Length));
        InvArr.Add(EntryObj);
      end;
      Root.AddPair('invalidTokens', InvArr);

      WriteLn(Root.Format({Indention=} 2));
    finally
      Root.Free;
    end;

  finally
    KeywordCounts.Free;
    SymbolCounts.Free;
    InvalidTokens.Free;
  end;

end;

end.
