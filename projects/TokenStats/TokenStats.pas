unit TokenStats;

interface

uses
  System.Generics.Collections,
  DelphiLexer.Utils,
  DelphiLexer.Token;

type

  TTokenKinds = array[TTokenKind] of Integer;

  TTokenSummary = class
  private const
    MAX_INVALID_TOKENS = 10000;  // toconsider: add param for unlimited
  private
    FRoundTripOK: Boolean;
    FInvalidCount: Integer;
    FInvalidTokens: TList<TPair<string, TToken>>;
    FTotalLines: Integer;
    FFileCount: Integer;
    FTotalTokens: Integer;
    FStrictPairs: TList<TPair<string, Integer>>;
    FContextPairs: TList<TPair<string, Integer>>;
    FSymbolPairs: TList<TPair<string, Integer>>;
    FCountsByKind: TTokenKinds;
    FStrictKeywordCounts: TDictionary<string, Integer>;
    FContextKeywordCounts: TDictionary<string, Integer>;
    FSymbolCounts: TDictionary<string, Integer>;
  protected
    class function CollectSorted(Dict: TDictionary<string, Integer>): TList<TPair<string, Integer>>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Reset;
    procedure Accumulate(const AFileName: string; const ATokens: TList<TToken>; const AFileContents: string; const CollectInvalidTokens: Boolean);
    procedure BuildSortedPairs;
    property RoundTripOK: Boolean read FRoundTripOK;
    property InvalidCount: Integer read FInvalidCount;
    property InvalidTokens: TList<TPair<string, TToken>> read FInvalidTokens;
    property TotalLines: Integer read FTotalLines;
    property FileCount: Integer read FFileCount;
    property TotalTokens: Integer read FTotalTokens;
    property StrictPairs: TList<TPair<string, Integer>> read FStrictPairs;
    property ContextPairs: TList<TPair<string, Integer>> read FContextPairs;
    property SymbolPairs: TList<TPair<string, Integer>> read FSymbolPairs;
    property CountsByKind: TTokenKinds read FCountsByKind;
  end;


  TTokenStats = record
  private const
    AppName = 'DelphiLexer.TokenStats';
    ExitCode_Success = 0;
    ExitCode_InvalidTokens = 2;
    ExitCode_RoundTripFailed = 3; //tokenization failure
  private
    class function ExpandPathSpec(const PathSpec: string; Recursive: Boolean): TArray<string>; static;
    class function WriteTextOutput(const Config: TStatsConfig; const Rep: TTokenSummary): Integer; static;
    class function WriteJsonOutput(const Config: TStatsConfig; const Rep: TTokenSummary): Integer; static;
  public
    class function Run: Integer; static;
  end;


implementation

uses
  System.SysUtils,
  System.IOUtils,
  System.JSON,
  System.Generics.Defaults,
  Winapi.Windows,
  DelphiLexer.Lexer;


class function TTokenStats.Run: Integer;
var
  Config: TStatsConfig;
  Files: TArray<string>;
  Summary: TTokenSummary;
  Lexer: TDelphiLexer;
  Tokens: TList<TToken>;
  FileName: string;
  Contents: string;
  CollectInvalid: Boolean;
begin

  {$IFDEF DEBUG}
  ReportMemoryLeaksOnShutdown := True;
  {$ENDIF}

  Config := TCommandLineParser.ParseStats(AppName, 'Provides token-level statistics and metrics of Object Pascal source code');
  if Config.Common.AbortProgram then Exit(Config.Common.ExitCode);

  Files := ExpandPathSpec(Config.Common.FileName, Config.Recursive);
  if Length(Files) = 0 then
  begin
    WriteLn('error: no files matched: ', Config.Common.FileName);
    Exit(1);
  end;

  CollectInvalid := (Config.Common.OutputFormat = TOutputFormat.ofJson);

  Result := ExitCode_Success;
  Summary := TTokenSummary.Create;
  Lexer := TDelphiLexer.Create;
  Tokens := nil;
  try
    for FileName in Files do
    begin
      try
        Contents := TFile.ReadAllText(FileName, Config.Common.Encoding);
      except
        on E: Exception do
        begin
          if Config.Common.Encoding <> TEncoding.ANSI then
          begin
            try
              Contents := TFile.ReadAllText(FileName, TEncoding.ANSI);
            except
              on E2: Exception do
              begin
                WriteLn('warning: could not read: ', FileName, ': ', E.Message);
                Continue;
              end;
            end;
          end
          else
          begin
            WriteLn('warning: could not read: ', FileName, ': ', E.Message);
            Continue;
          end;
        end;
      end;
      Tokens := Lexer.Tokenize(Contents);
      try
        Summary.Accumulate(FileName, Tokens, Contents, CollectInvalid);
      finally
        FreeAndNil(Tokens);
      end;
    end;

    Summary.BuildSortedPairs;

    case Config.Common.OutputFormat of
      TOutputFormat.ofText: Result := WriteTextOutput(Config, Summary);
      TOutputFormat.ofJson: Result := WriteJsonOutput(Config, Summary);
    else
      Assert(False, 'Invalid output format');
    end;
  finally
    Tokens.Free;
    Lexer.Free;
    Summary.Free;
  end;

end;


class function TTokenStats.ExpandPathSpec(const PathSpec: string; Recursive: Boolean): TArray<string>;
var
  Dir: string;
  Mask: string;
  Opt: TSearchOption;
begin
  Dir  := ExtractFilePath(PathSpec);
  Mask := ExtractFileName(PathSpec);
  if Dir = '' then
    Dir := TDirectory.GetCurrentDirectory;
  if Recursive then
    Opt := TSearchOption.soAllDirectories
  else
    Opt := TSearchOption.soTopDirectoryOnly;
  try
    Result := TDirectory.GetFiles(Dir, Mask, Opt);
  except
    on E: Exception do
    begin
      WriteLn('error: ', E.Message);
      Result := [];
    end;
  end;
end;


class function TTokenStats.WriteTextOutput(const Config: TStatsConfig; const Rep: TTokenSummary): Integer;
const
  TOP_N = 10;
var
  I: Integer;
  K: TTokenKind;
  N: Integer;
begin

  // Header.
  WriteLn(AppName);
  WriteLn('inputPath: ', Config.Common.FileName);
  WriteLn('formatVersion: ', '1.2.0'); // Bump if TEXT output structure (or logic) changes
  WriteLn('');
  WriteLn(Format('%-18s : %s', ['PathSpec', Config.Common.FileName]));
  WriteLn(Format('%-18s : %s', ['Recursive', BoolToStr(Config.Recursive, True)]));
  WriteLn(Format('%-18s : %d', ['Files', Rep.FileCount]));
  WriteLn(Format('%-18s : %d', ['Tokens', Rep.TotalTokens]));
  WriteLn(Format('%-18s : %d', ['Lines', Rep.TotalLines]));
  WriteLn(Format('%-18s : %d', ['Invalid', Rep.InvalidCount]));
  if Rep.RoundTripOK then
    WriteLn(Format('%-18s : %s', ['RoundTrip', 'PASS']))
  else
    WriteLn(Format('%-18s : %s', ['RoundTrip', 'FAIL ***']));

  WriteLn;
  WriteLn('By Kind:');
  for K := Low(TTokenKind) to High(TTokenKind) do
    WriteLn(Format('  %-16s : %d', [TokenKindName(K), Rep.CountsByKind[K]]));

  WriteLn;
  WriteLn('Top Strict Keywords:');
  if Rep.StrictPairs.Count = 0 then
    WriteLn('  (none)')
  else
  begin
    N := Rep.StrictPairs.Count;
    if N > TOP_N then N := TOP_N;
    for I := 0 to N - 1 do
      WriteLn(Format('  %-16s : %d', [Rep.StrictPairs[I].Key, Rep.StrictPairs[I].Value]));
  end;

  WriteLn;
  WriteLn('Top Contextual Keywords:');
  if Rep.ContextPairs.Count = 0 then
    WriteLn('  (none)')
  else
  begin
    N := Rep.ContextPairs.Count;
    if N > TOP_N then N := TOP_N;
    for I := 0 to N - 1 do
      WriteLn(Format('  %-16s : %d', [Rep.ContextPairs[I].Key, Rep.ContextPairs[I].Value]));
  end;

  WriteLn;
  WriteLn('Top Symbols:');
  if Rep.SymbolPairs.Count = 0 then
    WriteLn('  (none)')
  else
  begin
    N := Rep.SymbolPairs.Count;
    if N > TOP_N then N := TOP_N;
    for I := 0 to N - 1 do
      WriteLn(Format('  %-16s : %d', [Rep.SymbolPairs[I].Key, Rep.SymbolPairs[I].Value]));
  end;

  if not Rep.RoundTripOK then
    Result := ExitCode_RoundTripFailed
  else if Rep.InvalidCount > 0 then
    Result := ExitCode_InvalidTokens
  else
    Result := ExitCode_Success;

  WriteLn('');
  WriteLn('Exit Code: ', Result);

end;


class function TTokenStats.WriteJsonOutput(const Config: TStatsConfig; const Rep: TTokenSummary): Integer;
var
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
  InvEntry: TPair<string, TToken>;
  TotalExclEOF: Integer;
  TotalExclTrivia: Integer;
begin

  if not Rep.RoundTripOK then
    Result := ExitCode_RoundTripFailed
  else if Rep.InvalidCount > 0 then
    Result := ExitCode_InvalidTokens
  else
    Result := ExitCode_Success;

  TotalExclEOF    := Rep.TotalTokens - Rep.CountsByKind[tkEOF];
  TotalExclTrivia := Rep.TotalTokens - Rep.CountsByKind[tkWhitespace]
                                     - Rep.CountsByKind[tkEOL]
                                     - Rep.CountsByKind[tkEOF];

  Root := TJSONObject.Create;
  try
    Root.AddPair('toolName', AppName);
    Root.AddPair('inputPath', Config.Common.FileName);
    Root.AddPair('recursive', TJSONBool.Create(Config.Recursive));
    Root.AddPair('fileCount', TJSONNumber.Create(Rep.FileCount));
    Root.AddPair('formatVersion', '1.2.0');  // Bump if JSON output structure (or logic) changes

    Options := TJSONObject.Create;
    Options.AddPair('encoding', Config.Common.Encoding.EncodingName);
    Root.AddPair('options', Options);

    Summary := TJSONObject.Create;
    Summary.AddPair('totalTokens',              TJSONNumber.Create(Rep.TotalTokens));
    Summary.AddPair('totalTokensExcludingEOF',  TJSONNumber.Create(TotalExclEOF));
    Summary.AddPair('totalTokensExcludingTrivia', TJSONNumber.Create(TotalExclTrivia));
    Summary.AddPair('invalidTokenCount',        TJSONNumber.Create(Rep.InvalidCount));
    Summary.AddPair('eofTokenCount',            TJSONNumber.Create(Rep.CountsByKind[tkEOF]));
    Summary.AddPair('roundTripMatches',         TJSONBool.Create(Rep.RoundTripOK));
    Summary.AddPair('lineCountEstimate',        TJSONNumber.Create(Rep.TotalLines));
    Summary.AddPair('exitCode',  TJSONNumber.Create(Result));
    Root.AddPair('summary', Summary);

    CountsObj := TJSONObject.Create;
    for K := Low(TTokenKind) to High(TTokenKind) do
      CountsObj.AddPair(TokenKindName(K), TJSONNumber.Create(Rep.CountsByKind[K]));
    Root.AddPair('countsByKind', CountsObj);

    // Strict keywordCounts -- all keywords sorted by count desc.
    StrictKwArr := TJSONArray.Create;
    for Pair in Rep.StrictPairs do
    begin
      EntryObj := TJSONObject.Create;
      EntryObj.AddPair('keyword', Pair.Key);
      EntryObj.AddPair('count',   TJSONNumber.Create(Pair.Value));
      StrictKwArr.Add(EntryObj);
    end;
    Root.AddPair('strictKeywordCounts', StrictKwArr);

    ContextualKwArr := TJSONArray.Create;
    for Pair in Rep.ContextPairs do
    begin
      EntryObj := TJSONObject.Create;
      EntryObj.AddPair('keyword', Pair.Key);
      EntryObj.AddPair('count',   TJSONNumber.Create(Pair.Value));
      ContextualKwArr.Add(EntryObj);
    end;
    Root.AddPair('contextualKeywordCounts', ContextualKwArr);

    // symbolCounts -- all symbols sorted by count desc.
    SymArr := TJSONArray.Create;
    for Pair in Rep.SymbolPairs do
    begin
      EntryObj := TJSONObject.Create;
      EntryObj.AddPair('symbol', Pair.Key);
      EntryObj.AddPair('count',  TJSONNumber.Create(Pair.Value));
      SymArr.Add(EntryObj);
    end;
    Root.AddPair('symbolCounts', SymArr);

    // invalidTokens -- details for each tkInvalid token, with source file.
    InvArr := TJSONArray.Create;
    for InvEntry in Rep.InvalidTokens do
    begin
      EntryObj := TJSONObject.Create;
      EntryObj.AddPair('file',        InvEntry.Key);
      EntryObj.AddPair('text',        InvEntry.Value.Text);
      EntryObj.AddPair('line',        TJSONNumber.Create(InvEntry.Value.Line));
      EntryObj.AddPair('col',         TJSONNumber.Create(InvEntry.Value.Col));
      EntryObj.AddPair('startOffset', TJSONNumber.Create(InvEntry.Value.StartOffset));
      EntryObj.AddPair('length',      TJSONNumber.Create(InvEntry.Value.Length));
      InvArr.Add(EntryObj);
    end;
    Root.AddPair('invalidTokens', InvArr);

    WriteLn(Root.Format({Indention=} 2));
  finally
    Root.Free;
  end;

end;


constructor TTokenSummary.Create;
begin
  inherited;
  FInvalidTokens := TList<TPair<string, TToken>>.Create;
  FStrictKeywordCounts  := TDictionary<string, Integer>.Create;
  FContextKeywordCounts := TDictionary<string, Integer>.Create;
  FSymbolCounts         := TDictionary<string, Integer>.Create;
  Reset;
end;

destructor TTokenSummary.Destroy;
begin
  FSymbolCounts.Free;
  FContextKeywordCounts.Free;
  FStrictKeywordCounts.Free;
  FInvalidTokens.Free;
  FStrictPairs.Free;
  FContextPairs.Free;
  FSymbolPairs.Free;
  inherited;
end;

procedure TTokenSummary.Reset;
var
  K: TTokenKind;
begin
  FRoundTripOK  := True;
  FInvalidCount := 0;
  FTotalLines   := 0;
  FFileCount    := 0;
  FTotalTokens  := 0;
  for K := Low(TTokenKind) to High(TTokenKind) do
    FCountsByKind[K] := 0;
  FInvalidTokens.Clear;
  FStrictKeywordCounts.Clear;
  FContextKeywordCounts.Clear;
  FSymbolCounts.Clear;
  FreeAndNil(FStrictPairs);
  FreeAndNil(FContextPairs);
  FreeAndNil(FSymbolPairs);
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

procedure TTokenSummary.Accumulate(const AFileName: string; const ATokens: TList<TToken>; const AFileContents: string; const CollectInvalidTokens: Boolean);
var
  Tok: TToken;
  I: Integer;
  Lower: string;
  Existing: Integer;
  MaxLine: Integer;
begin
  Inc(FFileCount);
  Inc(FTotalTokens, ATokens.Count);
  MaxLine := 0;

  for I := 0 to ATokens.Count - 1 do
  begin
    Tok := ATokens[I];
    Inc(FCountsByKind[Tok.Kind]);
    if (Tok.Kind <> tkEOF) and (Tok.Line > MaxLine) then
      MaxLine := Tok.Line;
    case Tok.Kind of
      tkStrictKeyword:
      begin
        Lower := LowerCase(Tok.Text);
        if not FStrictKeywordCounts.TryGetValue(Lower, Existing) then Existing := 0;
        FStrictKeywordCounts.AddOrSetValue(Lower, Existing + 1);
      end;
      tkContextKeyword:
      begin
        Lower := LowerCase(Tok.Text);
        if not FContextKeywordCounts.TryGetValue(Lower, Existing) then Existing := 0;
        FContextKeywordCounts.AddOrSetValue(Lower, Existing + 1);
      end;
      tkSymbol:
      begin
        if not FSymbolCounts.TryGetValue(Tok.Text, Existing) then Existing := 0;
        FSymbolCounts.AddOrSetValue(Tok.Text, Existing + 1);
      end;
      tkInvalid:
      begin
        Inc(FInvalidCount);
        if CollectInvalidTokens and (FInvalidTokens.Count < MAX_INVALID_TOKENS) then
          FInvalidTokens.Add(TPair<string, TToken>.Create(AFileName, Tok));
      end;
    end;
  end;

  Inc(FTotalLines, MaxLine);

  if not TLexerUtils.RoundTripCheck(ATokens, AFileContents) then
    FRoundTripOK := False;
end;

procedure TTokenSummary.BuildSortedPairs;
begin
  FreeAndNil(FStrictPairs);
  FreeAndNil(FContextPairs);
  FreeAndNil(FSymbolPairs);
  FStrictPairs  := CollectSorted(FStrictKeywordCounts);
  FContextPairs := CollectSorted(FContextKeywordCounts);
  FSymbolPairs  := CollectSorted(FSymbolCounts);
end;

end.
