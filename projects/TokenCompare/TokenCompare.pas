unit TokenCompare;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  DelphiLexer.Utils,
  DelphiLexer.Token;

type
  TTokenCompare = record
  private const
    AppName = 'DelphiLexer.TokenCompare';
    ExitCode_Success = 0;
    ExitCode_OpFailure = 1;
    ExitCode_Difference = 10;
  private
    // Derive the comparison mode name from the active ignore flags for display in output.
    class function ComparisonModeName(const Config:TFileCompareConfigOptions): string; static;
    // Return a new list containing only the tokens that survive the active
    // ignore flags. The returned list is owned by the caller.
    class function FilterTokens(const Config:TFileCompareConfigOptions; Tokens: TList<TToken>): TList<TToken>; static;
    // Return a single-line display string for a token in diff output.
    // Control characters are replaced with <TAG> codes.
    class function TokenLabel(const Tok: TToken): string; static;
    class function WriteTextOutput(const Config:TFileCompareConfigOptions; RawA, RawB: TList<TToken>): Integer; static;
    class function WriteJsonOutput(const Config:TFileCompareConfigOptions; RawA, RawB: TList<TToken>): Integer; static;
  public
    class function Run: Integer; static;
  end;

implementation

uses
  System.JSON,
  DelphiLexer.Lexer;

type
  // Myers diff produces only two operations: a token present in A but not B
  // (dkMissingInB, i.e. deleted from A), and a token present in B but not A
  // (dkMissingInA, i.e. inserted into B).  A substitution appears naturally
  // as a consecutive dkMissingInB + dkMissingInA pair in the edit script.
  TDiffKind = (dkMissingInA, dkMissingInB);

  TDiffEntry = record
    Kind:   TDiffKind;
    IndexA: Integer;  // index in FilteredA; -1 for dkMissingInA
    IndexB: Integer;  // index in FilteredB; -1 for dkMissingInB
    Tok:    TToken;   // the token that is missing (from A for dkMissingInB, from B for dkMissingInA)
  end;

const
  // Inputs larger than this fall back to the sequential algorithm.
  // Keeps Myers trace memory bounded for typical source files.
  MAX_MYERS_TOKENS = 200000;


// Myers diff -- forward pass.
//
// Fills Trace with one snapshot of the V array per d-step, where each
// snapshot captures V before that d-step's k-loop.  The backtrack pass
// uses these snapshots to reconstruct the edit script.
//
// V is indexed by diagonal k = x - y, stored at V[k + Offset] to keep
// indices non-negative.  Offset = max(N + M, 1) so the array is always
// large enough and the both-empty case does not go out of bounds.
//
// Returns the edit distance (>= 0) on success.
// Returns -1 if either input exceeds MAX_MYERS_TOKENS; Trace is set to nil.
function MyersForward(
  A, B      : TList<TToken>;
  out Trace : TArray<TArray<Integer>>): Integer;
var
  N, M   : Integer;
  Offset : Integer;
  VSize  : Integer;
  V      : TArray<Integer>;
  D, K   : Integer;
  X, Y   : Integer;
begin
  N := A.Count;
  M := B.Count;

  if (N > MAX_MYERS_TOKENS) or (M > MAX_MYERS_TOKENS) then
  begin
    Trace := nil;
    Exit(-1);
  end;

  // Offset maps diagonal k to a zero-based index: index = k + Offset.
  // Minimum 1 ensures V[1 + Offset] is in bounds for the both-empty case.
  Offset := N + M;
  if Offset = 0 then Offset := 1;
  VSize  := 2 * Offset + 1;

  SetLength(V, VSize);

  // Sentinel: V[1 + Offset] = 0 lets the d=0 k=0 pass start at (x=0, y=0)
  // via the "move down from diagonal k+1" branch.
  V[1 + Offset] := 0;

  SetLength(Trace, 0);

  for D := 0 to N + M do
  begin
    // Save snapshot of V before this d-step's k-loop.
    // The backtrack pass reads Trace[d] to reproduce the predecessor choice
    // made for each diagonal during d.  V[k-1] and V[k+1] for any k in
    // d's loop always have opposite parity to k, so they are never modified
    // during d's own k-loop; the snapshot is therefore an accurate record.
    SetLength(Trace, D + 1);
    Trace[D] := Copy(V, 0, VSize);

    K := -D;
    while K <= D do
    begin
      // Decide which predecessor diagonal to extend.
      //   k = -D  ->  left boundary, must come from k+1 (insert from B).
      //   k =  D  ->  right boundary, must come from k-1 (delete from A).
      //   otherwise  ->  prefer whichever predecessor reached further.
      if (K = -D) or ((K <> D) and (V[K - 1 + Offset] < V[K + 1 + Offset])) then
        X := V[K + 1 + Offset]       // insert: x unchanged, y advances
      else
        X := V[K - 1 + Offset] + 1;  // delete: x advances by one

      Y := X - K;

      // Extend along the diagonal while tokens match (free moves).
      while (X < N) and (Y < M)
        and (A[X].Kind = B[Y].Kind) and (A[X].Text = B[Y].Text) do
      begin
        Inc(X);
        Inc(Y);
      end;

      V[K + Offset] := X;

      if (X >= N) and (Y >= M) then
      begin
        Result := D;
        Exit;
      end;

      Inc(K, 2);
    end;
  end;

  // Unreachable for valid finite inputs; edit distance <= N + M always.
  Result := N + M;
end;


// Myers diff -- backtrack pass.
//
// Walks Trace from d = EditDist down to d = 1, reconstructing the edit
// script.  Each d-step contributes exactly one edit (insert or delete).
// Entries are collected in reverse order and reversed at the end so they
// are returned in forward (A-index ascending) order.
//
// Appends at most MaxDiffs entries to Diffs.  Caller owns Diffs.
procedure MyersBacktrack(
  A, B       : TList<TToken>;
  const Trace: TArray<TArray<Integer>>;
  MaxDiffs   : Integer;
  Diffs      : TList<TDiffEntry>);
var
  N, M, Offset : Integer;
  EditDist     : Integer;
  X, Y, K      : Integer;
  D            : Integer;
  PrevK, PrevX, PrevY : Integer;
  Entry        : TDiffEntry;
  Reversed     : TList<TDiffEntry>;
  I            : Integer;
begin
  N := A.Count;
  M := B.Count;

  // Offset must match the value used in MyersForward.
  Offset   := N + M;
  if Offset = 0 then Offset := 1;

  // Trace holds entries [0..EditDist], so EditDist = Length - 1.
  EditDist := Length(Trace) - 1;

  // Start backtrack at the end of both sequences.
  X := N;
  Y := M;

  Reversed := TList<TDiffEntry>.Create;
  try
    for D := EditDist downto 1 do
    begin
      K := X - Y;

      // Reproduce the predecessor choice that was made during d's k-loop for
      // diagonal K.  Trace[D] is the snapshot of V before d's loop, so
      // Trace[D][k+/-1 + Offset] are the values from which the choice was made.
      if (K = -D) or ((K <> D) and (Trace[D][K - 1 + Offset] < Trace[D][K + 1 + Offset])) then
      begin
        // Came from diagonal K+1 (insert from B).
        // The insert consumed B[PrevY]; it is present in B but absent from A.
        PrevK        := K + 1;
        PrevX        := Trace[D][K + 1 + Offset];
        PrevY        := PrevX - PrevK;
        Entry        := Default(TDiffEntry);
        Entry.Kind   := dkMissingInA;
        Entry.IndexA := -1;
        Entry.IndexB := PrevY;
        Entry.Tok    := B[PrevY];
      end
      else
      begin
        // Came from diagonal K-1 (delete from A).
        // The delete consumed A[PrevX]; it is present in A but absent from B.
        PrevK        := K - 1;
        PrevX        := Trace[D][K - 1 + Offset];
        PrevY        := PrevX - PrevK;
        Entry        := Default(TDiffEntry);
        Entry.Kind   := dkMissingInB;
        Entry.IndexA := PrevX;
        Entry.IndexB := -1;
        Entry.Tok    := A[PrevX];
      end;

      Reversed.Add(Entry);
      X := PrevX;
      Y := PrevY;
    end;

    // Entries were collected end-to-start; iterate in reverse to append them
    // to Diffs in forward order.  Stop early if MaxDiffs is reached.
    for I := Reversed.Count - 1 downto 0 do
    begin
      if Diffs.Count >= MaxDiffs then Break;
      Diffs.Add(Reversed[I]);
    end;
  finally
    Reversed.Free;
  end;
end;


// Run the comparison over pre-filtered token lists using Myers diff.
// Falls back to the sequential algorithm when either list exceeds
// MAX_MYERS_TOKENS tokens; UsedFallback is set to True in that case.
// The sequential fallback represents each positional mismatch as a
// dkMissingInB + dkMissingInA pair, consistent with the Myers edit model.
// Returns a new TList<TDiffEntry> owned by the caller.
// TotalDiffs receives the edit distance (Myers) or the equivalent count
// (fallback).  It may exceed Result.Count when MaxDiffs truncation is active.
function BuildDiffList(FilteredA, FilteredB: TList<TToken>; const Config: TFileCompareConfigOptions; out TotalDiffs: Integer; out UsedFallback: Boolean): TList<TDiffEntry>;
var
  Trace    : TArray<TArray<Integer>>;
  EditDist : Integer;
  MaxI, I  : Integer;
  HasA, HasB: Boolean;
  TokA, TokB: TToken;
  Entry    : TDiffEntry;
begin
  Result       := TList<TDiffEntry>.Create;
  TotalDiffs   := 0;
  UsedFallback := False;

  EditDist := MyersForward(FilteredA, FilteredB, Trace);

  if EditDist = -1 then
  begin
    // Input exceeds MAX_MYERS_TOKENS; fall back to sequential comparison.
    // Each positional mismatch emits a dkMissingInB + dkMissingInA pair so
    // the output methods can render it as a substitution.
    UsedFallback := True;
    MaxI := FilteredA.Count;
    if FilteredB.Count > MaxI then MaxI := FilteredB.Count;

    for I := 0 to MaxI - 1 do
    begin
      HasA := I < FilteredA.Count;
      HasB := I < FilteredB.Count;

      if HasA and HasB then
      begin
        TokA := FilteredA[I];
        TokB := FilteredB[I];
        if (TokA.Kind <> TokB.Kind) or (TokA.Text <> TokB.Text) then
        begin
          // Delete from A.
          Inc(TotalDiffs);
          if Result.Count < Config.MaxDiffs then
          begin
            Entry        := Default(TDiffEntry);
            Entry.Kind   := dkMissingInB;
            Entry.IndexA := I;
            Entry.IndexB := -1;
            Entry.Tok    := TokA;
            Result.Add(Entry);
          end;
          if Config.StopAfterFirstDiff then Break;

          // Insert from B.
          Inc(TotalDiffs);
          if Result.Count < Config.MaxDiffs then
          begin
            Entry        := Default(TDiffEntry);
            Entry.Kind   := dkMissingInA;
            Entry.IndexA := -1;
            Entry.IndexB := I;
            Entry.Tok    := TokB;
            Result.Add(Entry);
          end;
          if Config.StopAfterFirstDiff then Break;
        end;
      end
      else if HasA then
      begin
        Inc(TotalDiffs);
        if Result.Count < Config.MaxDiffs then
        begin
          Entry        := Default(TDiffEntry);
          Entry.Kind   := dkMissingInB;
          Entry.IndexA := I;
          Entry.IndexB := -1;
          Entry.Tok    := FilteredA[I];
          Result.Add(Entry);
        end;
        if Config.StopAfterFirstDiff then Break;
      end
      else
      begin
        Inc(TotalDiffs);
        if Result.Count < Config.MaxDiffs then
        begin
          Entry        := Default(TDiffEntry);
          Entry.Kind   := dkMissingInA;
          Entry.IndexA := -1;
          Entry.IndexB := I;
          Entry.Tok    := FilteredB[I];
          Result.Add(Entry);
        end;
        if Config.StopAfterFirstDiff then Break;
      end;
    end;

    Exit;
  end;

  // Myers path: d=0 means the files are identical.
  if EditDist = 0 then
  begin
    TotalDiffs := 0;
    Exit;
  end;

  // Reconstruct the edit script via backtracking.
  TotalDiffs := EditDist;
  MyersBacktrack(FilteredA, FilteredB, Trace, Config.MaxDiffs, Result);
end;


class function TTokenCompare.Run: Integer;
var
  Options: TFileCompareConfigOptions;
  Lexer: TDelphiLexer;
  TokensA, TokensB: TList<TToken>;
begin
  {$IFDEF DEBUG}
  ReportMemoryLeaksOnShutdown := True;
  {$ENDIF}

  Options := TCommandLineParser.ParseFileCompare(AppName, 'Compares the token streams of two Object Pascal source files');
  if Options.BaseOptions.AbortProgram then Exit(Options.BaseOptions.ExitCode);

  Result := ExitCode_Success;

  Lexer   := TDelphiLexer.Create;
  TokensA := nil;
  TokensB := nil;
  try
    TokensA := Lexer.Tokenize(Options.BaseOptions.FileContents);
    TokensB := Lexer.Tokenize(Options.SecondContents);
    case Options.BaseOptions.OutputFormat of
      TOutputFormat.ofText: Result := WriteTextOutput(Options, TokensA, TokensB);
      TOutputFormat.ofJson: Result := WriteJsonOutput(Options, TokensA, TokensB);
    else
      Assert(False, 'Invalid output format');
    end;
  finally
    TokensB.Free;
    TokensA.Free;
    Lexer.Free;
  end;
end;


class function TTokenCompare.ComparisonModeName(const Config:TFileCompareConfigOptions): string;
begin
  if not Config.IgnoreWhitespace and not Config.IgnoreEOL and not Config.IgnoreComments then
    Result := 'exact'
  else
  begin
    Result := '';
    if Config.IgnoreWhitespace then Result := Result + 'ignore-whitespace;';
    if Config.IgnoreEOL then Result := Result + 'ignore-eol;';
    if Config.IgnoreComments then Result := Result + 'ignore-comments;';

    If Result.EndsWith(';') then Result := Copy(Result, 1, Length(Result)-1);
  end;
end;


class function TTokenCompare.FilterTokens(const Config:TFileCompareConfigOptions; Tokens: TList<TToken>): TList<TToken>;
var
  Tok: TToken;
begin
  Result := TList<TToken>.Create;
  for Tok in Tokens do
  begin
    if Config.IgnoreWhitespace and (Tok.Kind = tkWhitespace) then Continue;
    if Config.IgnoreEOL and (Tok.Kind = tkEOL) then Continue;
    if Config.IgnoreComments and (Tok.Kind = tkComment) then Continue;

    Result.Add(Tok);
  end;
end;


class function TTokenCompare.TokenLabel(const Tok: TToken): string;
var
  S: string;
begin
  S := Tok.Text;
  // Todo: use TLexerUtils.SafeText
  S := StringReplace(S, #13#10, '<CRLF>', [rfReplaceAll]);
  S := StringReplace(S, #13,    '<CR>',   [rfReplaceAll]);
  S := StringReplace(S, #10,    '<LF>',   [rfReplaceAll]);
  S := StringReplace(S, #9,     '<TAB>',  [rfReplaceAll]);
  Result := TokenKindName(Tok.Kind) + ' "' + S + '"';
end;


class function TTokenCompare.WriteTextOutput(const Config:TFileCompareConfigOptions; RawA, RawB: TList<TToken>): Integer;
var
  FilteredA, FilteredB: TList<TToken>;
  Diffs:       TList<TDiffEntry>;
  TotalDiffs:  Integer;
  UsedFallback: Boolean;
  I:           Integer;
  DisplayIdx:  Integer;
  Entry, Next: TDiffEntry;
  Equal:       Boolean;
begin
  FilteredA := FilterTokens(Config, RawA);
  FilteredB := FilterTokens(Config, RawB);
  Diffs     := BuildDiffList(FilteredA, FilteredB, Config, TotalDiffs, UsedFallback);
  try
    Equal := TotalDiffs = 0;

    // Header.
    WriteLn('');
    WriteLn(AppName);
    WriteLn('formatVersion: ', '2.0.0'); // Bump if TEXT output structure changes
    WriteLn(Format('%-18s : %s', ['File A', Config.BaseOptions.FileName]));
    WriteLn(Format('%-18s : %s', ['File B', Config.SecondFile]));
    WriteLn(Format('%-18s : %s', ['Mode',   ComparisonModeName(Config)]));
    WriteLn(Format('%-18s : %s', ['Equal', if Equal then 'yes' else 'no']));
    if FilteredA.Count = FilteredB.Count then
      WriteLn(Format('%-18s : %d',     ['Compared Tokens', FilteredA.Count]))
    else
      WriteLn(Format('%-18s : %d / %d', ['Compared Tokens', FilteredA.Count, FilteredB.Count]));
    WriteLn(Format('%-18s : %d', ['Diff Count', TotalDiffs]));

    if UsedFallback then
      WriteLn('(warning: input too large for Myers diff; sequential algorithm used)');
    if Config.StopAfterFirstDiff and (TotalDiffs >= 1) then
      WriteLn('(stopped after first difference)');
    if (not Config.StopAfterFirstDiff) and (TotalDiffs > Diffs.Count) then
      WriteLn(Format('(showing first %d of %d differences)', [Diffs.Count, TotalDiffs]));

    // Diff entries.
    if Diffs.Count > 0 then
    begin
      WriteLn;
      WriteLn('Differences:');
      I          := 0;
      DisplayIdx := 1;
      while I < Diffs.Count do
      begin
        Entry := Diffs[I];
        WriteLn;

        // Adjacent dkMissingInB + dkMissingInA -> display as substitution.
        if (Entry.Kind = dkMissingInB)
          and (I + 1 < Diffs.Count)
          and (Diffs[I + 1].Kind = dkMissingInA) then
        begin
          Next := Diffs[I + 1];
          WriteLn(Format('  [%d]  substitution', [DisplayIdx]));
          WriteLn(Format('    %-14s : %d', ['Index A', Entry.IndexA]));
          WriteLn(Format('    %-14s : %d', ['Index B', Next.IndexB]));
          WriteLn(Format('    %-14s : %s', ['A', TokenLabel(Entry.Tok)]));
          WriteLn(Format('    %-14s : %s', ['B', TokenLabel(Next.Tok)]));
          Inc(I, 2);
        end
        else
        begin
          WriteLn(Format('  [%d]', [DisplayIdx]));
          case Entry.Kind of
            dkMissingInB:
            begin
              WriteLn(Format('    %-14s : %s', ['Type',    'missing-token-in-b']));
              WriteLn(Format('    %-14s : %d', ['Index A', Entry.IndexA]));
              WriteLn(Format('    %-14s : %s', ['A',       TokenLabel(Entry.Tok)]));
            end;
            dkMissingInA:
            begin
              WriteLn(Format('    %-14s : %s', ['Type',    'missing-token-in-a']));
              WriteLn(Format('    %-14s : %d', ['Index B', Entry.IndexB]));
              WriteLn(Format('    %-14s : %s', ['B',       TokenLabel(Entry.Tok)]));
            end;
          end;
          Inc(I);
        end;

        Inc(DisplayIdx);
      end;
    end;

  finally
    FilteredA.Free;
    FilteredB.Free;
    Diffs.Free;
  end;

  if Equal then Result := ExitCode_Success else Result := ExitCode_Difference;

  WriteLn('');
  WriteLn('Exit Code: ', Result);
end;


class function TTokenCompare.WriteJsonOutput(const Config:TFileCompareConfigOptions; RawA, RawB: TList<TToken>): Integer;
var
  FilteredA, FilteredB: TList<TToken>;
  Diffs:       TList<TDiffEntry>;
  TotalDiffs:  Integer;
  UsedFallback: Boolean;
  I:           Integer;
  Entry, Next: TDiffEntry;
  Equal:       Boolean;
  Root:        TJSONObject;
  Options:     TJSONObject;
  Summary:     TJSONObject;
  DiffsArr:    TJSONArray;
  DiffObj:     TJSONObject;
  TokObj:      TJSONObject;
begin
  FilteredA := FilterTokens(Config, RawA);
  FilteredB := FilterTokens(Config, RawB);
  Diffs     := BuildDiffList(FilteredA, FilteredB, Config, TotalDiffs, UsedFallback);
  try
    Equal := TotalDiffs = 0;

    Root := TJSONObject.Create;
    try

      Root.AddPair('toolName', AppName);
      Root.AddPair('formatVersion', '2.0.0');  // Bump if JSON output structure changes
      Root.AddPair('fileA', Config.BaseOptions.FileName);
      Root.AddPair('fileB', Config.SecondFile);

      Options := TJSONObject.Create;
      Options.AddPair('encoding',           Config.BaseOptions.Encoding.EncodingName);
      Options.AddPair('ignoreWhitespace',   TJSONBool.Create(Config.IgnoreWhitespace));
      Options.AddPair('ignoreEOL',          TJSONBool.Create(Config.IgnoreEOL));
      Options.AddPair('ignoreComments',     TJSONBool.Create(Config.IgnoreComments));
      Options.AddPair('stopAfterFirstDiff', TJSONBool.Create(Config.StopAfterFirstDiff));
      Options.AddPair('maxDiffs',           TJSONNumber.Create(Config.MaxDiffs));
      Options.AddPair('usedFallback',       TJSONBool.Create(UsedFallback));
      Root.AddPair('options', Options);

      Summary := TJSONObject.Create;
      Summary.AddPair('equal',               TJSONBool.Create(Equal));
      Summary.AddPair('comparisonMode',      ComparisonModeName(Config));
      Summary.AddPair('rawTokenCountA',      TJSONNumber.Create(RawA.Count));
      Summary.AddPair('rawTokenCountB',      TJSONNumber.Create(RawB.Count));
      Summary.AddPair('comparedTokenCountA', TJSONNumber.Create(FilteredA.Count));
      Summary.AddPair('comparedTokenCountB', TJSONNumber.Create(FilteredB.Count));
      Summary.AddPair('diffCount',           TJSONNumber.Create(TotalDiffs));
      Root.AddPair('summary', Summary);

      DiffsArr := TJSONArray.Create;
      I := 0;
      while I < Diffs.Count do
      begin
        Entry   := Diffs[I];
        DiffObj := TJSONObject.Create;

        // Adjacent dkMissingInB + dkMissingInA -> emit as substitution object.
        if (Entry.Kind = dkMissingInB)
          and (I + 1 < Diffs.Count)
          and (Diffs[I + 1].Kind = dkMissingInA) then
        begin
          Next := Diffs[I + 1];
          DiffObj.AddPair('diffType', 'substitution');
          DiffObj.AddPair('indexA',   TJSONNumber.Create(Entry.IndexA));
          DiffObj.AddPair('indexB',   TJSONNumber.Create(Next.IndexB));

          TokObj := TJSONObject.Create;
          TokObj.AddPair('kind',        TokenKindName(Entry.Tok.Kind));
          TokObj.AddPair('text',        Entry.Tok.Text);
          TokObj.AddPair('line',        TJSONNumber.Create(Entry.Tok.Line));
          TokObj.AddPair('col',         TJSONNumber.Create(Entry.Tok.Col));
          TokObj.AddPair('startOffset', TJSONNumber.Create(Entry.Tok.StartOffset));
          TokObj.AddPair('length',      TJSONNumber.Create(Entry.Tok.Length));
          DiffObj.AddPair('tokenA', TokObj);

          TokObj := TJSONObject.Create;
          TokObj.AddPair('kind',        TokenKindName(Next.Tok.Kind));
          TokObj.AddPair('text',        Next.Tok.Text);
          TokObj.AddPair('line',        TJSONNumber.Create(Next.Tok.Line));
          TokObj.AddPair('col',         TJSONNumber.Create(Next.Tok.Col));
          TokObj.AddPair('startOffset', TJSONNumber.Create(Next.Tok.StartOffset));
          TokObj.AddPair('length',      TJSONNumber.Create(Next.Tok.Length));
          DiffObj.AddPair('tokenB', TokObj);

          Inc(I, 2);
        end
        else
        begin
          case Entry.Kind of
            dkMissingInB:
            begin
              DiffObj.AddPair('diffType', 'missing-token-in-b');
              DiffObj.AddPair('indexA',   TJSONNumber.Create(Entry.IndexA));

              TokObj := TJSONObject.Create;
              TokObj.AddPair('kind',        TokenKindName(Entry.Tok.Kind));
              TokObj.AddPair('text',        Entry.Tok.Text);
              TokObj.AddPair('line',        TJSONNumber.Create(Entry.Tok.Line));
              TokObj.AddPair('col',         TJSONNumber.Create(Entry.Tok.Col));
              TokObj.AddPair('startOffset', TJSONNumber.Create(Entry.Tok.StartOffset));
              TokObj.AddPair('length',      TJSONNumber.Create(Entry.Tok.Length));
              DiffObj.AddPair('tokenA', TokObj);
            end;

            dkMissingInA:
            begin
              DiffObj.AddPair('diffType', 'missing-token-in-a');
              DiffObj.AddPair('indexB',   TJSONNumber.Create(Entry.IndexB));

              TokObj := TJSONObject.Create;
              TokObj.AddPair('kind',        TokenKindName(Entry.Tok.Kind));
              TokObj.AddPair('text',        Entry.Tok.Text);
              TokObj.AddPair('line',        TJSONNumber.Create(Entry.Tok.Line));
              TokObj.AddPair('col',         TJSONNumber.Create(Entry.Tok.Col));
              TokObj.AddPair('startOffset', TJSONNumber.Create(Entry.Tok.StartOffset));
              TokObj.AddPair('length',      TJSONNumber.Create(Entry.Tok.Length));
              DiffObj.AddPair('tokenB', TokObj);
            end;
          end;

          Inc(I);
        end;

        DiffsArr.Add(DiffObj);
      end;
      Root.AddPair('diffs', DiffsArr);

      WriteLn(Root.Format(2));
    finally
      Root.Free;
    end;

  finally
    FilteredA.Free;
    FilteredB.Free;
    Diffs.Free;
  end;

  if Equal then Result := ExitCode_Success else Result := ExitCode_Difference;
end;

end.
