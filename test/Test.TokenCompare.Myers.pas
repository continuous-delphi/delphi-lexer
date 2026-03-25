unit Test.TokenCompare.Myers;

// Unit-level algorithm correctness tests for BuildDiffList / Myers diff.
//
// Tests call BuildDiffList directly with hand-crafted token lists so that
// the algorithm can be verified independently of file I/O and CLI parsing.
// Only TToken.Kind and TToken.Text participate in comparison; position
// fields (Line, Col, StartOffset, Length) are left at their zero defaults.

interface

uses
  DUnitX.TestFramework,
  System.Generics.Collections,
  DelphiLexer.Token,
  DelphiLexer.Diff;

type

  [TestFixture]
  TMeyersDiffTests = class
  private
    // Build a single TToken with the given Kind and Text; position fields unused.
    function T(Kind: TTokenKind; const Text: string): TToken;
    // Build a TList<TToken> from an open array. Caller owns the result.
    function L(const Toks: array of TToken): TList<TToken>;
    // Call BuildDiffList with no truncation and return the diff list.
    // TotalDiffs and UsedFallback are available via the out parameters.
    function Diff(A, B: TList<TToken>;
                  out TotalDiffs: Integer;
                  out UsedFallback: Boolean): TList<TDiffEntry>;
  public

    // --- Plan test cases ---

    [Test] procedure Equal_NoDiffs;
    [Test] procedure SingleInsert_MissingInA;
    [Test] procedure SingleDelete_MissingInB;
    [Test] procedure SingleSubstitution_PairAtSameIndex;
    [Test] procedure PrependInB_MissingInA_AtZero;
    [Test] procedure AppendInA_MissingInB_AtEnd;
    [Test] procedure CompletelyDifferent_FourEntries;
    [Test] procedure EmptyA_SingleMissingInA;
    [Test] procedure EmptyB_SingleMissingInB;
    [Test] procedure BothEmpty_NoDiffs;
    [Test] procedure EofPreserved_MatchedNotInDiffs;
    [Test] procedure EofMismatch_DiffAtEofPosition;
    [Test] procedure AbortedTooManyDiffs_ReturnsFlag;
    [Test] procedure MaxDiffs_TruncatesListButPreservesTotalCount;
  end;


implementation


function TMeyersDiffTests.T(Kind: TTokenKind; const Text: string): TToken;
begin
  Result      := Default(TToken);
  Result.Kind := Kind;
  Result.Text := Text;
end;


function TMeyersDiffTests.L(const Toks: array of TToken): TList<TToken>;
var
  I: Integer;
begin
  Result := TList<TToken>.Create;
  for I := Low(Toks) to High(Toks) do
    Result.Add(Toks[I]);
end;


function TMeyersDiffTests.Diff(A, B: TList<TToken>;
  out TotalDiffs: Integer; out UsedFallback: Boolean): TList<TDiffEntry>;
var
  Aborted: Boolean;
begin
  Result := BuildDiffList(A, B, MaxInt, False, TotalDiffs, UsedFallback, Aborted);
end;


// ---------------------------------------------------------------------------
// Test cases from LCS_Plan.md  Unit-level (algorithm correctness)
// ---------------------------------------------------------------------------

procedure TMeyersDiffTests.Equal_NoDiffs;
// Equal | [x, y, z] | [x, y, z] | 0 diffs
var
  A, B    : TList<TToken>;
  Diffs   : TList<TDiffEntry>;
  Total   : Integer;
  Fallback: Boolean;
begin
  A := L([T(tkIdentifier, 'x'), T(tkIdentifier, 'y'), T(tkIdentifier, 'z')]);
  B := L([T(tkIdentifier, 'x'), T(tkIdentifier, 'y'), T(tkIdentifier, 'z')]);
  try
    Diffs := Diff(A, B, Total, Fallback);
    try
      Assert.AreEqual(0, Total,       'TotalDiffs should be 0');
      Assert.AreEqual(NativeInt(0), Diffs.Count, 'Diffs.Count should be 0');
    finally
      Diffs.Free;
    end;
  finally
    A.Free; B.Free;
  end;
end;


procedure TMeyersDiffTests.SingleInsert_MissingInA;
// Single insert | [x, z] | [x, y, z] | dkMissingInA at B[1]
var
  A, B    : TList<TToken>;
  Diffs   : TList<TDiffEntry>;
  Total   : Integer;
  Fallback: Boolean;
begin
  A := L([T(tkIdentifier, 'x'), T(tkIdentifier, 'z')]);
  B := L([T(tkIdentifier, 'x'), T(tkIdentifier, 'y'), T(tkIdentifier, 'z')]);
  try
    Diffs := Diff(A, B, Total, Fallback);
    try
      Assert.AreEqual(1, Total,       'TotalDiffs should be 1');
      Assert.AreEqual(NativeInt(1), Diffs.Count, 'Should have 1 diff entry');
      Assert.AreEqual(TDiffKind.dkMissingInA, Diffs[0].Kind, 'Kind should be dkMissingInA');
      Assert.AreEqual(-1,              Diffs[0].IndexA,      'IndexA should be -1');
      Assert.AreEqual(1,               Diffs[0].IndexB,      'IndexB should be 1');
      Assert.AreEqual('y',             Diffs[0].Tok.Text,    'Token text should be y');
    finally
      Diffs.Free;
    end;
  finally
    A.Free; B.Free;
  end;
end;


procedure TMeyersDiffTests.SingleDelete_MissingInB;
// Single delete | [x, y, z] | [x, z] | dkMissingInB at A[1]
var
  A, B    : TList<TToken>;
  Diffs   : TList<TDiffEntry>;
  Total   : Integer;
  Fallback: Boolean;
begin
  A := L([T(tkIdentifier, 'x'), T(tkIdentifier, 'y'), T(tkIdentifier, 'z')]);
  B := L([T(tkIdentifier, 'x'), T(tkIdentifier, 'z')]);
  try
    Diffs := Diff(A, B, Total, Fallback);
    try
      Assert.AreEqual(1, Total,       'TotalDiffs should be 1');
      Assert.AreEqual(NativeInt(1), Diffs.Count, 'Should have 1 diff entry');
      Assert.AreEqual(TDiffKind.dkMissingInB, Diffs[0].Kind, 'Kind should be dkMissingInB');
      Assert.AreEqual(1,  Diffs[0].IndexA, 'IndexA should be 1');
      Assert.AreEqual(-1, Diffs[0].IndexB, 'IndexB should be -1');
      Assert.AreEqual('y', Diffs[0].Tok.Text, 'Token text should be y');
    finally
      Diffs.Free;
    end;
  finally
    A.Free; B.Free;
  end;
end;


procedure TMeyersDiffTests.SingleSubstitution_PairAtSameIndex;
// Single substitution | [x, y, z] | [x, w, z] | dkMissingInB A[1] + dkMissingInA B[1]
var
  A, B    : TList<TToken>;
  Diffs   : TList<TDiffEntry>;
  Total   : Integer;
  Fallback: Boolean;
begin
  A := L([T(tkIdentifier, 'x'), T(tkIdentifier, 'y'), T(tkIdentifier, 'z')]);
  B := L([T(tkIdentifier, 'x'), T(tkIdentifier, 'w'), T(tkIdentifier, 'z')]);
  try
    Diffs := Diff(A, B, Total, Fallback);
    try
      Assert.AreEqual(2, Total,       'TotalDiffs should be 2 (delete + insert)');
      Assert.AreEqual(NativeInt(2), Diffs.Count, 'Should have 2 diff entries');

      Assert.AreEqual(TDiffKind.dkMissingInB, Diffs[0].Kind, 'Entry 0: dkMissingInB');
      Assert.AreEqual(1,   Diffs[0].IndexA, 'Entry 0: IndexA = 1');
      Assert.AreEqual(-1,  Diffs[0].IndexB, 'Entry 0: IndexB = -1');
      Assert.AreEqual('y', Diffs[0].Tok.Text, 'Entry 0: token is y');

      Assert.AreEqual(TDiffKind.dkMissingInA, Diffs[1].Kind, 'Entry 1: dkMissingInA');
      Assert.AreEqual(-1,  Diffs[1].IndexA, 'Entry 1: IndexA = -1');
      Assert.AreEqual(1,   Diffs[1].IndexB, 'Entry 1: IndexB = 1');
      Assert.AreEqual('w', Diffs[1].Tok.Text, 'Entry 1: token is w');
    finally
      Diffs.Free;
    end;
  finally
    A.Free; B.Free;
  end;
end;


procedure TMeyersDiffTests.PrependInB_MissingInA_AtZero;
// Prepend in B | [x] | [y, x] | dkMissingInA at B[0]
var
  A, B    : TList<TToken>;
  Diffs   : TList<TDiffEntry>;
  Total   : Integer;
  Fallback: Boolean;
begin
  A := L([T(tkIdentifier, 'x')]);
  B := L([T(tkIdentifier, 'y'), T(tkIdentifier, 'x')]);
  try
    Diffs := Diff(A, B, Total, Fallback);
    try
      Assert.AreEqual(1, Total,       'TotalDiffs should be 1');
      Assert.AreEqual(NativeInt(1), Diffs.Count, 'Should have 1 diff entry');
      Assert.AreEqual(TDiffKind.dkMissingInA, Diffs[0].Kind, 'Kind should be dkMissingInA');
      Assert.AreEqual(-1, Diffs[0].IndexA, 'IndexA should be -1');
      Assert.AreEqual(0,  Diffs[0].IndexB, 'IndexB should be 0');
      Assert.AreEqual('y', Diffs[0].Tok.Text, 'Token text should be y');
    finally
      Diffs.Free;
    end;
  finally
    A.Free; B.Free;
  end;
end;


procedure TMeyersDiffTests.AppendInA_MissingInB_AtEnd;
// Append in A | [x, y] | [x] | dkMissingInB at A[1]
var
  A, B    : TList<TToken>;
  Diffs   : TList<TDiffEntry>;
  Total   : Integer;
  Fallback: Boolean;
begin
  A := L([T(tkIdentifier, 'x'), T(tkIdentifier, 'y')]);
  B := L([T(tkIdentifier, 'x')]);
  try
    Diffs := Diff(A, B, Total, Fallback);
    try
      Assert.AreEqual(1, Total,       'TotalDiffs should be 1');
      Assert.AreEqual(NativeInt(1), Diffs.Count, 'Should have 1 diff entry');
      Assert.AreEqual(TDiffKind.dkMissingInB, Diffs[0].Kind, 'Kind should be dkMissingInB');
      Assert.AreEqual(1,  Diffs[0].IndexA, 'IndexA should be 1');
      Assert.AreEqual(-1, Diffs[0].IndexB, 'IndexB should be -1');
      Assert.AreEqual('y', Diffs[0].Tok.Text, 'Token text should be y');
    finally
      Diffs.Free;
    end;
  finally
    A.Free; B.Free;
  end;
end;


procedure TMeyersDiffTests.CompletelyDifferent_FourEntries;
// Completely different | [a, b] | [c, d] | 4 entries
// Myers produces: delete a, delete b, insert c, insert d (edit distance = 4).
var
  A, B    : TList<TToken>;
  Diffs   : TList<TDiffEntry>;
  Total   : Integer;
  Fallback: Boolean;
begin
  A := L([T(tkIdentifier, 'a'), T(tkIdentifier, 'b')]);
  B := L([T(tkIdentifier, 'c'), T(tkIdentifier, 'd')]);
  try
    Diffs := Diff(A, B, Total, Fallback);
    try
      Assert.AreEqual(4, Total,       'TotalDiffs should be 4');
      Assert.AreEqual(NativeInt(4), Diffs.Count, 'Should have 4 diff entries');

      Assert.AreEqual(TDiffKind.dkMissingInB, Diffs[0].Kind, 'Entry 0: dkMissingInB');
      Assert.AreEqual('a', Diffs[0].Tok.Text, 'Entry 0: token a');

      Assert.AreEqual(TDiffKind.dkMissingInB, Diffs[1].Kind, 'Entry 1: dkMissingInB');
      Assert.AreEqual('b', Diffs[1].Tok.Text, 'Entry 1: token b');

      Assert.AreEqual(TDiffKind.dkMissingInA, Diffs[2].Kind, 'Entry 2: dkMissingInA');
      Assert.AreEqual('c', Diffs[2].Tok.Text, 'Entry 2: token c');

      Assert.AreEqual(TDiffKind.dkMissingInA, Diffs[3].Kind, 'Entry 3: dkMissingInA');
      Assert.AreEqual('d', Diffs[3].Tok.Text, 'Entry 3: token d');
    finally
      Diffs.Free;
    end;
  finally
    A.Free; B.Free;
  end;
end;


procedure TMeyersDiffTests.EmptyA_SingleMissingInA;
// Empty A | [] | [x] | dkMissingInA
var
  A, B    : TList<TToken>;
  Diffs   : TList<TDiffEntry>;
  Total   : Integer;
  Fallback: Boolean;
begin
  A := TList<TToken>.Create;
  B := L([T(tkIdentifier, 'x')]);
  try
    Diffs := Diff(A, B, Total, Fallback);
    try
      Assert.AreEqual(1, Total,       'TotalDiffs should be 1');
      Assert.AreEqual(NativeInt(1), Diffs.Count, 'Should have 1 diff entry');
      Assert.AreEqual(TDiffKind.dkMissingInA, Diffs[0].Kind, 'Kind should be dkMissingInA');
      Assert.AreEqual(0, Diffs[0].IndexB, 'IndexB should be 0');
      Assert.AreEqual('x', Diffs[0].Tok.Text, 'Token text should be x');
    finally
      Diffs.Free;
    end;
  finally
    A.Free; B.Free;
  end;
end;


procedure TMeyersDiffTests.EmptyB_SingleMissingInB;
// Empty B | [x] | [] | dkMissingInB
var
  A, B    : TList<TToken>;
  Diffs   : TList<TDiffEntry>;
  Total   : Integer;
  Fallback: Boolean;
begin
  A := L([T(tkIdentifier, 'x')]);
  B := TList<TToken>.Create;
  try
    Diffs := Diff(A, B, Total, Fallback);
    try
      Assert.AreEqual(1, Total,       'TotalDiffs should be 1');
      Assert.AreEqual(NativeInt(1), Diffs.Count, 'Should have 1 diff entry');
      Assert.AreEqual(TDiffKind.dkMissingInB, Diffs[0].Kind, 'Kind should be dkMissingInB');
      Assert.AreEqual(0, Diffs[0].IndexA, 'IndexA should be 0');
      Assert.AreEqual('x', Diffs[0].Tok.Text, 'Token text should be x');
    finally
      Diffs.Free;
    end;
  finally
    A.Free; B.Free;
  end;
end;


procedure TMeyersDiffTests.BothEmpty_NoDiffs;
// Both empty | [] | [] | 0 diffs
var
  A, B    : TList<TToken>;
  Diffs   : TList<TDiffEntry>;
  Total   : Integer;
  Fallback: Boolean;
begin
  A := TList<TToken>.Create;
  B := TList<TToken>.Create;
  try
    Diffs := Diff(A, B, Total, Fallback);
    try
      Assert.AreEqual(0, Total,       'TotalDiffs should be 0');
      Assert.AreEqual(NativeInt(0), Diffs.Count, 'Diffs.Count should be 0');
    finally
      Diffs.Free;
    end;
  finally
    A.Free; B.Free;
  end;
end;


procedure TMeyersDiffTests.EofPreserved_MatchedNotInDiffs;
// tkEOF preserved | [..., tkEOF] | [..., tkEOF] | tkEOF matched, not in diffs
var
  A, B    : TList<TToken>;
  Diffs   : TList<TDiffEntry>;
  Total   : Integer;
  Fallback: Boolean;
begin
  A := L([T(tkIdentifier, 'x'), T(tkEOF, '')]);
  B := L([T(tkIdentifier, 'x'), T(tkEOF, '')]);
  try
    Diffs := Diff(A, B, Total, Fallback);
    try
      Assert.AreEqual(0, Total,       'TotalDiffs should be 0: tkEOF tokens match');
      Assert.AreEqual(NativeInt(0), Diffs.Count, 'Diffs.Count should be 0');
    finally
      Diffs.Free;
    end;
  finally
    A.Free; B.Free;
  end;
end;


procedure TMeyersDiffTests.EofMismatch_DiffAtEofPosition;
// tkEOF mismatch | [..., tkEOF ''] | [..., tkEOF 'x'] | diff at EOF position
// tkEOF participates in comparison; differing text means a substitution pair.
var
  A, B    : TList<TToken>;
  Diffs   : TList<TDiffEntry>;
  Total   : Integer;
  Fallback: Boolean;
begin
  A := L([T(tkIdentifier, 'x'), T(tkEOF, '')]);
  B := L([T(tkIdentifier, 'x'), T(tkEOF, 'different')]);
  try
    Diffs := Diff(A, B, Total, Fallback);
    try
      Assert.AreEqual(2, Total,       'TotalDiffs should be 2 (delete + insert at EOF position)');
      Assert.AreEqual(NativeInt(2), Diffs.Count, 'Should have 2 diff entries');
      Assert.AreEqual(TDiffKind.dkMissingInB, Diffs[0].Kind, 'Entry 0: dkMissingInB (A EOF deleted)');
      Assert.AreEqual(TDiffKind.dkMissingInA, Diffs[1].Kind, 'Entry 1: dkMissingInA (B EOF inserted)');
      Assert.AreEqual(tkEOF, Diffs[0].Tok.Kind, 'Entry 0: token kind is tkEOF');
      Assert.AreEqual(tkEOF, Diffs[1].Tok.Kind, 'Entry 1: token kind is tkEOF');
    finally
      Diffs.Free;
    end;
  finally
    A.Free; B.Free;
  end;
end;


procedure TMeyersDiffTests.AbortedTooManyDiffs_ReturnsFlag;
// N=M=60, all tokens differ -> edit distance = 120.
// Threshold = max(120*30 div 100, 100) = 100.  Abort fires at d=100.
var
  A, B     : TList<TToken>;
  Diffs    : TList<TDiffEntry>;
  Total    : Integer;
  Fallback : Boolean;
  Aborted  : Boolean;
  I        : Integer;
begin
  A := TList<TToken>.Create;
  B := TList<TToken>.Create;
  try
    for I := 0 to 59 do
      A.Add(T(tkIdentifier, 'a' + IntToStr(I)));  // a0..a59
    for I := 0 to 59 do
      B.Add(T(tkIdentifier, 'b' + IntToStr(I)));  // b0..b59, none match A

    Diffs := BuildDiffList(A, B, MaxInt, False, Total, Fallback, Aborted);
    try
      Assert.IsTrue(Aborted,           'AbortedTooManyDiffs should be True');
      Assert.AreEqual(-1, Total,       'TotalDiffs should be -1 (unknown)');
      Assert.AreEqual(NativeInt(0), Diffs.Count, 'Diffs list should be empty');
      Assert.IsFalse(Fallback,         'UsedFallback should be False');
    finally
      Diffs.Free;
    end;
  finally
    A.Free; B.Free;
  end;
end;


procedure TMeyersDiffTests.MaxDiffs_TruncatesListButPreservesTotalCount;
// [a, b] vs [c, d] -> edit distance = 4.
// Passing MaxDiffs=2 must return Diffs.Count=2 while TotalDiffs remains 4.
var
  A, B     : TList<TToken>;
  Diffs    : TList<TDiffEntry>;
  Total    : Integer;
  Fallback : Boolean;
  Aborted  : Boolean;
begin
  A := L([T(tkIdentifier, 'a'), T(tkIdentifier, 'b')]);
  B := L([T(tkIdentifier, 'c'), T(tkIdentifier, 'd')]);
  try
    Diffs := BuildDiffList(A, B, {MaxDiffs=}2, False, Total, Fallback, Aborted);
    try
      Assert.AreEqual(4, Total,            'TotalDiffs should be full edit distance (4)');
      Assert.AreEqual(NativeInt(2), Diffs.Count, 'Diffs.Count should be capped at MaxDiffs (2)');
      Assert.IsFalse(Aborted,              'AbortedTooManyDiffs should be False');
      Assert.IsFalse(Fallback,             'UsedFallback should be False');
    finally
      Diffs.Free;
    end;
  finally
    A.Free; B.Free;
  end;
end;


end.
