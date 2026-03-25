unit TokenStats;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  DelphiLexer.Utils,
  DelphiLexer.Token;

type

  TTokenStats = record
  private const
    AppName = 'DelphiLexer.TokenStats';
    ExitCode_Success = 0;
    ExitCode_InvalidTokens = 2;
    ExitCode_RoundTripFailed = 3; //tokenization failure
  private
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

type

  TTokenKinds = Array[TTokenKind] of Integer;

  TTokenSummary = Class
  private const
    MAX_INVALID_TOKENS = 10000;  // toconsider: add param for unlimited
  private
    FRoundTripOK: Boolean;
    FInvalidCount: Integer;
    FInvalidTokens: TList<TToken>;
    FMaxLine: Integer;
    FStrictPairs: TList<TPair<string, Integer>>;
    FContextPairs: TList<TPair<string, Integer>>;
    FSymbolPairs: TList<TPair<string, Integer>>;
    FCountsByKind: TTokenKinds;
  protected
    class function CollectSorted(Dict: TDictionary<string, Integer>): TList<TPair<string, Integer>>;
  public
    constructor Create;
    destructor Destroy; override;

    procedure OnePass(const Config: TConfigOptions; const Tokens: TList<TToken>; const CollectInvalidTokens:Boolean);

    property RoundTripOK: Boolean read FRoundTripOK;
    property InvalidCount: Integer read FInvalidCount;
    property InvalidTokens: TList<TToken> read FInvalidTokens;
    property MaxLine: Integer read FMaxLine;
    property StrictPairs: TList<TPair<string, Integer>> read FStrictPairs;
    property ContextPairs: TList<TPair<string, Integer>> read FContextPairs;
    property SymbolPairs: TList<TPair<string, Integer>> read FSymbolPairs;
    property CountsByKind:TTokenKinds read FCountsByKind;
  End;

class function TTokenStats.Run: Integer;
var
  Options: TConfigOptions;
  Lexer: TDelphiLexer;
  Tokens: TList<TToken>;
begin

  {$IFDEF DEBUG}
  ReportMemoryLeaksOnShutdown := True;
  {$ENDIF}

  Options := TCommandLineParser.ParseSingleFile(AppName, 'Provides token-level statistics and metrics of Object Pascal source code');
  if Options.AbortProgram then Exit(Options.ExitCode);

  Result := ExitCode_Success;

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


class function TTokenStats.WriteTextOutput(const Config: TConfigOptions; const Tokens: TList<TToken>): Integer;
const
  TOP_N = 10;
var
  Rep: TTokenSummary;
  I: Integer;
  K: TTokenKind;
  N: Integer;
begin
  Rep := TTokenSummary.Create;
  try
    Rep.OnePass(Config, Tokens, {CollectInvalidTokens=} False);

    // Header.
    WriteLn(AppName);
    WriteLn('inputFile: ', Config.FileName);
    WriteLn('formatVersion: ', '1.1.0'); // Bump if TEXT output structure (or logic) changes
    WriteLn('');
    WriteLn(Format('%-18s : %s', ['File', Config.FileName]));
    WriteLn(Format('%-18s : %d', ['Tokens', Tokens.Count]));
    WriteLn(Format('%-18s : %d', ['Lines', rep.MaxLine]));
    WriteLn(Format('%-18s : %d', ['Invalid', rep.InvalidCount]));
    if rep.RoundTripOK then
      WriteLn(Format('%-18s : %s', ['RoundTrip', 'PASS']))
    else
      WriteLn(Format('%-18s : %s', ['RoundTrip', 'FAIL ***']));

    WriteLn;
    WriteLn('By Kind:');
    for K := Low(TTokenKind) to High(TTokenKind) do
      WriteLn(Format('  %-16s : %d', [TokenKindName(K), rep.CountsByKind[K]]));

    WriteLn;
    WriteLn('Top Strict Keywords:');

    if rep.StrictPairs.Count = 0 then
      WriteLn('  (none)')
    else
    begin
      N := rep.StrictPairs.Count;
      if N > TOP_N then N := TOP_N;
      for I := 0 to N - 1 do
        WriteLn(Format('  %-16s : %d', [rep.StrictPairs[I].Key, rep.StrictPairs[I].Value]));
    end;

    WriteLn;
    WriteLn('Top Contextual Keywords:');
    if rep.ContextPairs.Count = 0 then
      WriteLn('  (none)')
    else
    begin
      N := rep.ContextPairs.Count;
      if N > TOP_N then N := TOP_N;
      for I := 0 to N - 1 do
        WriteLn(Format('  %-16s : %d', [rep.ContextPairs[I].Key, rep.ContextPairs[I].Value]));
    end;

    WriteLn;
    WriteLn('Top Symbols:');
    if rep.SymbolPairs.Count = 0 then
      WriteLn('  (none)')
    else
    begin
      N := rep.SymbolPairs.Count;
      if N > TOP_N then N := TOP_N;
      for I := 0 to N - 1 do
        WriteLn(Format('  %-16s : %d', [rep.SymbolPairs[I].Key, rep.SymbolPairs[I].Value]));
    end;

    if not rep.RoundTripOk then
      Result := ExitCode_RoundTripFailed
    else if rep.InvalidCount > 0 then
      Result := ExitCode_InvalidTokens
    else
      Result := ExitCode_Success;
  finally
    Rep.Free;
  end;

  WriteLn('');
  WriteLn('Exit Code: ', Result);

end;


class function TTokenStats.WriteJsonOutput(const Config: TConfigOptions; const Tokens: TList<TToken>): Integer;
var
  Rep:TTokenSummary;
  Tok: TToken;
  K: TTokenKind;
  Root: TJSONObject;
  Options: TJSONObject;
  Summary: TJSONObject;
  CountsObj: TJSONObject;
  StrictKwArr: TJSONArray;
  ContextualKwArr: TJSONArray;
  SymArr: TJSONArray;
  InvArr: TJSONArray;
  EntryObj: TJSONObject;
  Pair: TPair<string, Integer>;
  TotalExclEOF: Integer;
  TotalExclTrivia: Integer;
begin

  Rep := TTokenSummary.Create;
  try
    Rep.OnePass(Config, Tokens, {CollectInvalidTokens=} True);

    if not rep.RoundTripOK then
      Result := ExitCode_RoundTripFailed
    else if rep.InvalidCount > 0 then
      Result := ExitCode_InvalidTokens
    else
      Result := ExitCode_Success;

    TotalExclEOF    := Tokens.Count - rep.CountsByKind[tkEOF];
    TotalExclTrivia := Tokens.Count - rep.CountsByKind[tkWhitespace]
                                    - rep.CountsByKind[tkEOL]
                                    - rep.CountsByKind[tkEOF];

    Root := TJSONObject.Create;
    try
      Root.AddPair('toolName', AppName);
      Root.AddPair('inputFile', Config.FileName);
      Root.AddPair('formatVersion', '1.1.0');  // Bump if JSON output structure (or logic) changes

      Options := TJSONObject.Create;
      Options.AddPair('encoding', Config.Encoding.EncodingName);
      Root.AddPair('options', Options);

      Summary := TJSONObject.Create;
      Summary.AddPair('totalTokens',              TJSONNumber.Create(Tokens.Count));
      Summary.AddPair('totalTokensExcludingEOF',  TJSONNumber.Create(TotalExclEOF));
      Summary.AddPair('totalTokensExcludingTrivia', TJSONNumber.Create(TotalExclTrivia));
      Summary.AddPair('invalidTokenCount',        TJSONNumber.Create(rep.InvalidCount));
      Summary.AddPair('eofTokenCount',            TJSONNumber.Create(rep.CountsByKind[tkEOF]));
      Summary.AddPair('roundTripMatches',         TJSONBool.Create(rep.RoundTripOK));
      Summary.AddPair('lineCountEstimate',        TJSONNumber.Create(rep.MaxLine));
      Summary.AddPair('exitCode',  TJSONNumber.Create(Result));
      Root.AddPair('summary', Summary);

      CountsObj := TJSONObject.Create;
      for K := Low(TTokenKind) to High(TTokenKind) do
        CountsObj.AddPair(TokenKindName(K), TJSONNumber.Create(rep.CountsByKind[K]));
      Root.AddPair('countsByKind', CountsObj);

      // Strict keywordCounts -- all keywords sorted by count desc.
      StrictKwArr := TJSONArray.Create;
      for Pair in rep.StrictPairs do
      begin
        EntryObj := TJSONObject.Create;
        EntryObj.AddPair('keyword', Pair.Key);
        EntryObj.AddPair('count',   TJSONNumber.Create(Pair.Value));
        StrictKwArr.Add(EntryObj);
      end;
      Root.AddPair('strictKeywordCounts', StrictKwArr);

      ContextualKwArr := TJSONArray.Create;
      for Pair in rep.ContextPairs do
      begin
        EntryObj := TJSONObject.Create;
        EntryObj.AddPair('keyword', Pair.Key);
        EntryObj.AddPair('count',   TJSONNumber.Create(Pair.Value));
        ContextualKwArr.Add(EntryObj);
      end;
      Root.AddPair('contextualKeywordCounts', ContextualKwArr);

      // symbolCounts -- all symbols sorted by count desc.
      SymArr := TJSONArray.Create;
      for Pair in rep.SymbolPairs do
      begin
        EntryObj := TJSONObject.Create;
        EntryObj.AddPair('symbol', Pair.Key);
        EntryObj.AddPair('count',  TJSONNumber.Create(Pair.Value));
        SymArr.Add(EntryObj);
      end;
      Root.AddPair('symbolCounts', SymArr);

      // invalidTokens -- details for each tkInvalid token.
      InvArr := TJSONArray.Create;
      for Tok in rep.InvalidTokens do
      begin
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
    Rep.Free;
  end;

end;


constructor TTokenSummary.Create;
begin
  inherited;
  FStrictPairs := nil;
  FContextPairs := nil;
  FSymbolPairs := nil;
  FInvalidTokens := TList<TToken>.Create;
end;

destructor TTokenSummary.Destroy;
begin
  FInvalidTokens.Free;
  FStrictPairs.Free;
  FContextPairs.Free;
  FSymbolPairs.Free;
  inherited;
end;

// Collect all entries from Dict into a new list sorted by count descending,
// then alphabetically ascending on ties. Caller owns the returned list.
class function TTokenSummary.CollectSorted(Dict: TDictionary<string, Integer>): TList<TPair<string, Integer>>;
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

procedure TTokenSummary.OnePass(const Config: TConfigOptions; const Tokens: TList<TToken>; const CollectInvalidTokens:Boolean);
var
  K: TTokenKind;
  StrictKeywordCounts: TDictionary<string, Integer>;
  ContextKeywordCounts: TDictionary<string, Integer>;
  SymbolCounts: TDictionary<string, Integer>;
  Tok: TToken;
  I: Integer;
  Lower: string;
  Existing: Integer;
begin

  FInvalidCount := 0;
  FMaxLine := 0;

  for K := Low(TTokenKind) to High(TTokenKind) do
    FCountsByKind[K] := 0;

  StrictKeywordCounts := TDictionary<string, Integer>.Create;
  ContextKeywordCounts := nil;
  SymbolCounts := nil;
  try
    ContextKeywordCounts := TDictionary<string, Integer>.Create;
    SymbolCounts := TDictionary<string, Integer>.Create;

    // One pass over tokens.
    for I := 0 to Tokens.Count - 1 do
    begin
      Tok := Tokens[I];
      Inc(FCountsByKind[Tok.Kind]);
      if (Tok.Kind <> tkEOF) and (Tok.Line > FMaxLine) then
        FMaxLine := Tok.Line;
      case Tok.Kind of
        tkStrictKeyword:
        begin
          Lower := LowerCase(Tok.Text);
          if not StrictKeywordCounts.TryGetValue(Lower, Existing) then Existing := 0;
          StrictKeywordCounts.AddOrSetValue(Lower, Existing + 1);
        end;
        tkContextKeyword:
        begin
          Lower := LowerCase(Tok.Text);
          if not ContextKeywordCounts.TryGetValue(Lower, Existing) then Existing := 0;
          ContextKeywordCounts.AddOrSetValue(Lower, Existing + 1);
        end;
        tkSymbol:
        begin
          if not SymbolCounts.TryGetValue(Tok.Text, Existing) then Existing := 0;
          SymbolCounts.AddOrSetValue(Tok.Text, Existing + 1);
        end;
        tkInvalid:
        begin
          Inc(FInvalidCount);
          if CollectInvalidTokens and (FInvalidTokens.Count < MAX_INVALID_TOKENS) then
            FInvalidTokens.Add(Tok);
        end;
      end;
    end;

    FStrictPairs := CollectSorted(StrictKeywordCounts);
    FContextPairs := CollectSorted(ContextKeywordCounts);
    FSymbolPairs := CollectSorted(SymbolCounts);

  finally
    SymbolCounts.Free;
    ContextKeywordCounts.Free;
    StrictKeywordCounts.Free;
  end;

  FRoundTripOK := TLexerUtils.RoundTripCheck(Tokens, Config.FileContents);
end;

end.
