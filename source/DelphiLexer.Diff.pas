unit DelphiLexer.Diff;

// Myers diff algorithm over TToken sequences.
//
// This unit is the only dependency needed to call BuildDiffList directly,
// making it straightforward to unit-test the algorithm in isolation.
// TokenCompare.pas uses this unit; no other project infrastructure is required.

interface

uses
  System.Generics.Collections,
  DelphiLexer.Token;

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
    Tok:    TToken;   // the token that is missing
  end;

const
  // Per-file token limit for the Myers algorithm.
  // Inputs larger than this fall back to the sequential algorithm.
  // See LCS_Limit.md for the memory analysis behind this value.
  MAX_MYERS_TOKENS = 200000;

  // If the Myers edit distance grows beyond this percentage of (N + M),
  // the comparison is aborted and BuildDiffList sets AbortedTooManyDiffs.
  // At 30%, files that differ by more than a third are almost certainly
  // unrelated (wrong files compared by accident).  The abort protects
  // against runaway computation: for two completely different 100K-token
  // files the forward pass would otherwise require ~10^10 inner-loop steps.
  MAX_MYERS_EDIT_DISTANCE_PCT = 30;

  // Minimum threshold applied when MAX_MYERS_EDIT_DISTANCE_PCT yields a
  // value smaller than this.  Prevents spurious aborts on tiny inputs where
  // performance is irrelevant and the loop terminates at N + M anyway.
  MAX_MYERS_EDIT_DISTANCE_FLOOR = 100;

// Compare two pre-filtered token lists using the Myers diff algorithm.
//
// Falls back to sequential comparison when either list exceeds
// MAX_MYERS_TOKENS tokens; UsedFallback is set to True in that case.
//
// Sets AbortedTooManyDiffs to True and returns an empty list when the Myers
// edit distance exceeds MAX_MYERS_EDIT_DISTANCE_PCT% of (N + M).  TotalDiffs
// is set to -1 (unknown) in this case.
//
// MaxDiffs caps the number of entries collected (pass MaxInt for unlimited).
// StopAfterFirstDiff stops collection after the first entry.
//
// Returns a new TList<TDiffEntry> owned by the caller.
// TotalDiffs receives the complete edit distance (Myers) or equivalent count
// (fallback); it may exceed Result.Count when MaxDiffs truncation is active.
function BuildDiffList(
  FilteredA, FilteredB   : TList<TToken>;
  MaxDiffs               : Integer;
  StopAfterFirstDiff     : Boolean;
  out TotalDiffs         : Integer;
  out UsedFallback       : Boolean;
  out AbortedTooManyDiffs: Boolean): TList<TDiffEntry>;


implementation

uses
  System.SysUtils,
  System.Math;


// ---------------------------------------------------------------------------
// Myers forward pass
// ---------------------------------------------------------------------------
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
// Returns -2 if edit distance exceeds the threshold; Trace is set to nil.
function MyersForward(
  A, B      : TList<TToken>;
  out Trace : TArray<TArray<Integer>>): Integer;
var
  N, M            : Integer;
  Offset          : Integer;
  VSize           : Integer;
  V               : TArray<Integer>;
  D, K            : Integer;
  X, Y            : Integer;
  MaxEditDistance : Integer;
begin
  N := A.Count;
  M := B.Count;

  if (N > MAX_MYERS_TOKENS) or (M > MAX_MYERS_TOKENS) then
  begin
    Trace := nil;
    Exit(-1);
  end;

  // Compute the edit distance threshold.  If the forward pass reaches this
  // many steps without finding a solution, the files are too different to
  // be useful to compare and the pass aborts.
  MaxEditDistance := (N + M) * MAX_MYERS_EDIT_DISTANCE_PCT div 100;
  if MaxEditDistance < MAX_MYERS_EDIT_DISTANCE_FLOOR then
    MaxEditDistance := MAX_MYERS_EDIT_DISTANCE_FLOOR;

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

    // This d-step found no solution.  If the edit distance has grown past
    // the threshold the files are almost certainly unrelated; abort the
    // forward pass rather than spending potentially billions of iterations.
    if D >= MaxEditDistance then
    begin
      Trace := nil;
      Exit(-2);
    end;
  end;

  // Unreachable for valid finite inputs; edit distance <= N + M always.
  Result := N + M;
end;


// ---------------------------------------------------------------------------
// Myers backtrack pass
// ---------------------------------------------------------------------------
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
  N, M, Offset         : Integer;
  EditDist             : Integer;
  X, Y, K              : Integer;
  D                    : Integer;
  PrevK, PrevX, PrevY  : Integer;
  Entry                : TDiffEntry;
  Reversed             : TList<TDiffEntry>;
  I                    : Integer;
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


// ---------------------------------------------------------------------------
// BuildDiffList
// ---------------------------------------------------------------------------

function BuildDiffList(
  FilteredA, FilteredB   : TList<TToken>;
  MaxDiffs               : Integer;
  StopAfterFirstDiff     : Boolean;
  out TotalDiffs         : Integer;
  out UsedFallback       : Boolean;
  out AbortedTooManyDiffs: Boolean): TList<TDiffEntry>;
var
  Trace     : TArray<TArray<Integer>>;
  EditDist  : Integer;
  MaxI, I   : Integer;
  HasA, HasB: Boolean;
  TokA, TokB: TToken;
  Entry     : TDiffEntry;
begin
  Result              := TList<TDiffEntry>.Create;
  TotalDiffs          := 0;
  UsedFallback        := False;
  AbortedTooManyDiffs := False;

  EditDist := MyersForward(FilteredA, FilteredB, Trace);

  if EditDist = -2 then
  begin
    // Edit distance exceeded MAX_MYERS_EDIT_DISTANCE_PCT% of (N + M).
    // The files are almost certainly unrelated; return empty with abort flag.
    AbortedTooManyDiffs := True;
    TotalDiffs          := -1;  // unknown: forward pass did not complete
    Exit;
  end;

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
          if Result.Count < MaxDiffs then
          begin
            Entry        := Default(TDiffEntry);
            Entry.Kind   := dkMissingInB;
            Entry.IndexA := I;
            Entry.IndexB := -1;
            Entry.Tok    := TokA;
            Result.Add(Entry);
          end;
          if StopAfterFirstDiff then Break;

          // Insert from B.
          Inc(TotalDiffs);
          if Result.Count < MaxDiffs then
          begin
            Entry        := Default(TDiffEntry);
            Entry.Kind   := dkMissingInA;
            Entry.IndexA := -1;
            Entry.IndexB := I;
            Entry.Tok    := TokB;
            Result.Add(Entry);
          end;
          if StopAfterFirstDiff then Break;
        end;
      end
      else if HasA then
      begin
        Inc(TotalDiffs);
        if Result.Count < MaxDiffs then
        begin
          Entry        := Default(TDiffEntry);
          Entry.Kind   := dkMissingInB;
          Entry.IndexA := I;
          Entry.IndexB := -1;
          Entry.Tok    := FilteredA[I];
          Result.Add(Entry);
        end;
        if StopAfterFirstDiff then Break;
      end
      else
      begin
        Inc(TotalDiffs);
        if Result.Count < MaxDiffs then
        begin
          Entry        := Default(TDiffEntry);
          Entry.Kind   := dkMissingInA;
          Entry.IndexA := -1;
          Entry.IndexB := I;
          Entry.Tok    := FilteredB[I];
          Result.Add(Entry);
        end;
        if StopAfterFirstDiff then Break;
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
  MyersBacktrack(FilteredA, FilteredB, Trace, MaxDiffs, Result);
end;


end.
