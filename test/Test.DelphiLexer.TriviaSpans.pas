unit Test.DelphiLexer.TriviaSpans;

// Tests for Phase: Trivia Attachment
//   Step 2: IsTrivia classification
//   Step 2: ApplyTriviaSpans grouping rules (leading / trailing ownership)
//   Step 2: Invariants I-14, I-15, I-16

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Generics.Collections,
  DelphiLexer.Token,
  DelphiLexer.Lexer;

type

  [TestFixture]
  TTriviaSpanTests = class
  private
    FLexer: TDelphiLexer;
    function Lex(const S: string): TList<TToken>;
    // Verifies I-14 (each trivia token owned exactly once, no semantic token in any span)
    // and I-15 (trivia tokens have empty spans).  Calls Assert internally.
    procedure AssertOwnershipInvariant(Tokens: TList<TToken>);
  public
    [Setup]    procedure Setup;
    [TearDown] procedure TearDown;

    // ---- IsTrivia classification ----
    [Test] procedure IsTrivia_Whitespace_ReturnsTrue;
    [Test] procedure IsTrivia_EOL_ReturnsTrue;
    [Test] procedure IsTrivia_Comment_ReturnsTrue;
    [Test] procedure IsTrivia_Directive_ReturnsTrue;
    [Test] procedure IsTrivia_Identifier_ReturnsFalse;
    [Test] procedure IsTrivia_EOF_ReturnsFalse;

    // ---- Grouping rules ----
    [Test] procedure NoTrivia_BothSpansEmpty;
    [Test] procedure LeadingWhitespace_IsLeadingOfNextToken;
    [Test] procedure InlineCommentAndEOL_AreTrailingOfPreceding;
    [Test] procedure EOL_EndsTrailingSpan;
    [Test] procedure BlankLine_IsLeadingOfNextToken;
    [Test] procedure IntralineWS_IsTrailingOfFirst_NotLeadingOfSecond;
    [Test] procedure Directive_SameLine_IsTrailing;
    [Test] procedure Directive_OwnLine_IsLeadingOfNext;
    [Test] procedure CommentAtEOF_NoFollowingEOL_IsLeadingOfEOF;
    [Test] procedure MultipleBlankLines_AllInLeadingOfNextToken;

    // ---- Edge cases ----
    [Test] procedure EmptySource_EOFHasEmptySpans;
    [Test] procedure OnlyTrivia_AllInEOFLeadingSpan;
    [Test] procedure CRLF_TreatedAsSingleEOL_InTrailingSpan;
    [Test] procedure AdjacentSemanticTokens_BothSpansEmpty;

    // ---- Invariants I-14, I-15, I-16 ----
    [Test] procedure I14_EachTriviaTokenOwnedExactlyOnce;
    [Test] procedure I14_SumOfSpanCountsEqualsTriviaTokenCount;
    [Test] procedure I15_TriviaTokensHaveEmptySpans;
    [Test] procedure I16_EOF_OwnsTrailingFileTrivia;
  end;


implementation


procedure TTriviaSpanTests.Setup;
begin
  FLexer := TDelphiLexer.Create;
end;


procedure TTriviaSpanTests.TearDown;
begin
  FLexer.Free;
end;


function TTriviaSpanTests.Lex(const S: string): TList<TToken>;
begin
  Result := FLexer.Tokenize(S);
end;


procedure TTriviaSpanTests.AssertOwnershipInvariant(Tokens: TList<TToken>);
// Builds a coverage array: for every index in a leading or trailing span,
// increment a counter.  Then verifies:
//   - every trivia token has counter = 1  (I-14: owned exactly once)
//   - every semantic token has counter = 0 (I-14: not in any span)
//   - every trivia token has IsEmpty spans  (I-15)
var
  I, J: Integer;
  Owned: TArray<Integer>;
  Span: TTriviaSpan;
begin
  SetLength(Owned, Tokens.Count);
  // SetLength zero-initialises.

  for I := 0 to Tokens.Count - 1 do
  begin
    if IsTrivia(Tokens[I].Kind) then
      Continue;
    Span := Tokens[I].LeadingTrivia;
    if not Span.IsEmpty then
      for J := Span.FirstTokenIndex to Span.LastTokenIndex do
        Inc(Owned[J]);
    Span := Tokens[I].TrailingTrivia;
    if not Span.IsEmpty then
      for J := Span.FirstTokenIndex to Span.LastTokenIndex do
        Inc(Owned[J]);
  end;

  for I := 0 to Tokens.Count - 1 do
  begin
    if IsTrivia(Tokens[I].Kind) then
    begin
      Assert.AreEqual(1, Owned[I],
        Format('Trivia token at index %d owned %d times (expected 1)', [I, Owned[I]]));
      Assert.IsTrue(Tokens[I].LeadingTrivia.IsEmpty,
        Format('Trivia token at index %d must have empty LeadingTrivia (I-15)', [I]));
      Assert.IsTrue(Tokens[I].TrailingTrivia.IsEmpty,
        Format('Trivia token at index %d must have empty TrailingTrivia (I-15)', [I]));
    end
    else
      Assert.AreEqual(0, Owned[I],
        Format('Semantic token at index %d appears in a span (expected 0)', [I]));
  end;
end;


// ---------------------------------------------------------------------------
// IsTrivia classification
// ---------------------------------------------------------------------------

procedure TTriviaSpanTests.IsTrivia_Whitespace_ReturnsTrue;
begin
  Assert.IsTrue(IsTrivia(tkWhitespace));
end;

procedure TTriviaSpanTests.IsTrivia_EOL_ReturnsTrue;
begin
  Assert.IsTrue(IsTrivia(tkEOL));
end;

procedure TTriviaSpanTests.IsTrivia_Comment_ReturnsTrue;
begin
  Assert.IsTrue(IsTrivia(tkComment));
end;

procedure TTriviaSpanTests.IsTrivia_Directive_ReturnsTrue;
begin
  Assert.IsTrue(IsTrivia(tkDirective));
end;

procedure TTriviaSpanTests.IsTrivia_Identifier_ReturnsFalse;
begin
  Assert.IsFalse(IsTrivia(tkIdentifier));
end;

procedure TTriviaSpanTests.IsTrivia_EOF_ReturnsFalse;
begin
  Assert.IsFalse(IsTrivia(tkEOF));
end;


// ---------------------------------------------------------------------------
// Grouping rules
// ---------------------------------------------------------------------------

procedure TTriviaSpanTests.NoTrivia_BothSpansEmpty;
// 'Foo' -- single identifier, no surrounding trivia.
// Tokens: Foo(0), EOF(1)
var
  T: TList<TToken>;
begin
  T := Lex('Foo');
  try
    Assert.IsTrue(T[0].LeadingTrivia.IsEmpty,  'Foo leading must be empty');
    Assert.IsTrue(T[0].TrailingTrivia.IsEmpty, 'Foo trailing must be empty');
  finally
    T.Free;
  end;
end;


procedure TTriviaSpanTests.LeadingWhitespace_IsLeadingOfNextToken;
// '  Foo' -- two spaces (one tkWhitespace run) before identifier.
// Tokens: ws(0), Foo(1), EOF(2)
// Foo.LeadingTrivia = [0..0]; Foo.TrailingTrivia = empty.
var
  T: TList<TToken>;
begin
  T := Lex('  Foo');
  try
    Assert.IsFalse(T[1].LeadingTrivia.IsEmpty,  'Foo must have leading trivia');
    Assert.AreEqual(0, T[1].LeadingTrivia.FirstTokenIndex, 'Leading starts at ws (idx 0)');
    Assert.AreEqual(0, T[1].LeadingTrivia.LastTokenIndex,  'Leading ends at ws (idx 0)');
    Assert.AreEqual(tkWhitespace, T[0].Kind, 'Token at idx 0 must be tkWhitespace');
    Assert.IsTrue(T[1].TrailingTrivia.IsEmpty, 'Foo trailing must be empty');
  finally
    T.Free;
  end;
end;


procedure TTriviaSpanTests.InlineCommentAndEOL_AreTrailingOfPreceding;
// 'Foo // comment'#10
// Tokens: Foo(0), ws(1), // comment(2), EOL(3), EOF(4)
// Foo.TrailingTrivia = [1..3]; EOF.LeadingTrivia = empty.
var
  T: TList<TToken>;
begin
  T := Lex('Foo // comment'#10);
  try
    Assert.IsFalse(T[0].TrailingTrivia.IsEmpty, 'Foo must have trailing trivia');
    Assert.AreEqual(1, T[0].TrailingTrivia.FirstTokenIndex, 'Trailing starts at ws (idx 1)');
    Assert.AreEqual(3, T[0].TrailingTrivia.LastTokenIndex,  'Trailing ends at EOL (idx 3)');
    Assert.AreEqual(tkEOL, T[3].Kind, 'Last trivia token must be tkEOL');
    Assert.IsTrue(T[4].LeadingTrivia.IsEmpty,
      'EOF leading must be empty -- all trivia owned by Foo trailing');
  finally
    T.Free;
  end;
end;


procedure TTriviaSpanTests.EOL_EndsTrailingSpan;
// 'A;'#10'B'
// Tokens: A(0), ;(1), EOL(2), B(3), EOF(4)
// ;.TrailingTrivia = [2..2] (just the EOL); B.LeadingTrivia = empty.
var
  T: TList<TToken>;
begin
  T := Lex('A;'#10'B');
  try
    Assert.IsFalse(T[1].TrailingTrivia.IsEmpty, '; must have trailing trivia');
    Assert.AreEqual(2, T[1].TrailingTrivia.FirstTokenIndex, '; trailing starts at EOL (idx 2)');
    Assert.AreEqual(2, T[1].TrailingTrivia.LastTokenIndex,  '; trailing ends at EOL (idx 2)');
    Assert.AreEqual(tkEOL, T[2].Kind, 'Token at idx 2 must be tkEOL');
    Assert.IsTrue(T[3].LeadingTrivia.IsEmpty, 'B leading must be empty (EOL owned by ;)');
  finally
    T.Free;
  end;
end;


procedure TTriviaSpanTests.BlankLine_IsLeadingOfNextToken;
// 'A;'#10#10'B'
// Tokens: A(0), ;(1), EOL(2), EOL(3), B(4), EOF(5)
// ;.TrailingTrivia = [2..2]; B.LeadingTrivia = [3..3] (blank-line EOL).
var
  T: TList<TToken>;
begin
  T := Lex('A;'#10#10'B');
  try
    Assert.AreEqual(2, T[1].TrailingTrivia.FirstTokenIndex, '; trailing starts at first EOL');
    Assert.AreEqual(2, T[1].TrailingTrivia.LastTokenIndex,  '; trailing ends at first EOL');
    Assert.IsFalse(T[4].LeadingTrivia.IsEmpty, 'B must have leading trivia (blank line)');
    Assert.AreEqual(3, T[4].LeadingTrivia.FirstTokenIndex, 'B leading starts at blank-line EOL');
    Assert.AreEqual(3, T[4].LeadingTrivia.LastTokenIndex,  'B leading ends at blank-line EOL');
  finally
    T.Free;
  end;
end;


procedure TTriviaSpanTests.IntralineWS_IsTrailingOfFirst_NotLeadingOfSecond;
// 'A B' -- space between two identifiers on the same line.
// Tokens: A(0), ws(1), B(2), EOF(3)
// A.TrailingTrivia = [1..1]; B.LeadingTrivia = empty.
// The trailing scan runs until it hits the next semantic token (B), consuming
// the whitespace -- so it belongs to A's trailing side, not B's leading side.
var
  T: TList<TToken>;
begin
  T := Lex('A B');
  try
    Assert.IsFalse(T[0].TrailingTrivia.IsEmpty,
      'A trailing must hold the space');
    Assert.AreEqual(1, T[0].TrailingTrivia.FirstTokenIndex, 'Trailing starts at ws (idx 1)');
    Assert.AreEqual(1, T[0].TrailingTrivia.LastTokenIndex,  'Trailing ends at ws (idx 1)');
    Assert.IsTrue(T[2].LeadingTrivia.IsEmpty,
      'B leading must be empty -- space is trailing of A, not leading of B');
  finally
    T.Free;
  end;
end;


procedure TTriviaSpanTests.Directive_SameLine_IsTrailing;
// 'Foo; {$X}'#10
// Tokens: Foo(0), ;(1), ws(2), {$X}(3), EOL(4), EOF(5)
// ;.TrailingTrivia = [2..4] (ws + directive + EOL).
var
  T: TList<TToken>;
begin
  T := Lex('Foo; {$X}'#10);
  try
    Assert.IsFalse(T[1].TrailingTrivia.IsEmpty, '; must have trailing trivia');
    Assert.AreEqual(2, T[1].TrailingTrivia.FirstTokenIndex, 'Trailing starts at ws (idx 2)');
    Assert.AreEqual(4, T[1].TrailingTrivia.LastTokenIndex,  'Trailing ends at EOL (idx 4)');
    Assert.AreEqual(tkDirective, T[3].Kind,
      'Directive on same line must appear inside trailing span of preceding ;');
  finally
    T.Free;
  end;
end;


procedure TTriviaSpanTests.Directive_OwnLine_IsLeadingOfNext;
// 'Foo;'#10'{$X}'#10'Bar'
// Tokens: Foo(0), ;(1), EOL(2), {$X}(3), EOL(4), Bar(5), EOF(6)
// ;.TrailingTrivia = [2..2]; Bar.LeadingTrivia = [3..4] (directive + its EOL).
var
  T: TList<TToken>;
begin
  T := Lex('Foo;'#10'{$X}'#10'Bar');
  try
    Assert.AreEqual(2, T[1].TrailingTrivia.FirstTokenIndex, '; trailing is only the first EOL');
    Assert.AreEqual(2, T[1].TrailingTrivia.LastTokenIndex);
    Assert.IsFalse(T[5].LeadingTrivia.IsEmpty,
      'Bar must have leading trivia (directive on own line)');
    Assert.AreEqual(3, T[5].LeadingTrivia.FirstTokenIndex,
      'Bar leading starts at directive (idx 3)');
    Assert.AreEqual(4, T[5].LeadingTrivia.LastTokenIndex,
      'Bar leading ends at EOL after directive (idx 4)');
    Assert.AreEqual(tkDirective, T[3].Kind, 'Token at idx 3 must be tkDirective');
  finally
    T.Free;
  end;
end;


procedure TTriviaSpanTests.CommentAtEOF_NoFollowingEOL_IsLeadingOfEOF;
// 'Foo;'#10'// tail'   (no EOL after the comment)
// Tokens: Foo(0), ;(1), EOL(2), // tail(3), EOF(4)
// ;.TrailingTrivia = [2..2]; EOF.LeadingTrivia = [3..3].
var
  T: TList<TToken>;
  EOFIdx: Integer;
begin
  T := Lex('Foo;'#10'// tail');
  try
    EOFIdx := T.Count - 1;
    Assert.AreEqual(tkEOF, T[EOFIdx].Kind, 'Last token must be EOF');
    Assert.IsFalse(T[EOFIdx].LeadingTrivia.IsEmpty,
      'EOF must own the trailing-file comment as leading trivia');
    Assert.AreEqual(tkComment, T[T[EOFIdx].LeadingTrivia.FirstTokenIndex].Kind,
      'EOF leading trivia must start with the trailing-file comment');
  finally
    T.Free;
  end;
end;


procedure TTriviaSpanTests.MultipleBlankLines_AllInLeadingOfNextToken;
// 'A;'#10#10#10'B'
// Tokens: A(0), ;(1), EOL(2), EOL(3), EOL(4), B(5), EOF(6)
// ;.TrailingTrivia = [2..2] (one EOL); B.LeadingTrivia = [3..4] (two blank-line EOLs).
var
  T: TList<TToken>;
begin
  T := Lex('A;'#10#10#10'B');
  try
    Assert.AreEqual(1, T[1].TrailingTrivia.Count,
      '; trailing must contain exactly one EOL (the line-ending EOL)');
    Assert.AreEqual(2, T[5].LeadingTrivia.Count,
      'B leading must contain the two blank-line EOLs');
  finally
    T.Free;
  end;
end;


// ---------------------------------------------------------------------------
// Edge cases
// ---------------------------------------------------------------------------

procedure TTriviaSpanTests.EmptySource_EOFHasEmptySpans;
// '' -- empty source produces only the EOF sentinel.
var
  T: TList<TToken>;
begin
  T := Lex('');
  try
    Assert.AreEqual(NativeInt(1), T.Count, 'Empty source must produce exactly one token (EOF)');
    Assert.AreEqual(tkEOF, T[0].Kind);
    Assert.IsTrue(T[0].LeadingTrivia.IsEmpty,  'EOF leading must be empty for empty source');
    Assert.IsTrue(T[0].TrailingTrivia.IsEmpty, 'EOF trailing must be empty for empty source');
  finally
    T.Free;
  end;
end;


procedure TTriviaSpanTests.OnlyTrivia_AllInEOFLeadingSpan;
// '// comment'#10 -- no semantic tokens at all.
// Tokens: // comment(0), EOL(1), EOF(2)
// EOF.LeadingTrivia = [0..1].
var
  T: TList<TToken>;
  EOFIdx: Integer;
begin
  T := Lex('// comment'#10);
  try
    EOFIdx := T.Count - 1;
    Assert.AreEqual(tkEOF, T[EOFIdx].Kind);
    Assert.IsFalse(T[EOFIdx].LeadingTrivia.IsEmpty,
      'EOF must own all trivia as leading when source has no semantic tokens');
    Assert.AreEqual(0, T[EOFIdx].LeadingTrivia.FirstTokenIndex,
      'EOF leading span must start at index 0');
    Assert.IsTrue(T[EOFIdx].LeadingTrivia.LastTokenIndex = EOFIdx - 1,
      'EOF leading span must end at the token just before EOF');
  finally
    T.Free;
  end;
end;


procedure TTriviaSpanTests.CRLF_TreatedAsSingleEOL_InTrailingSpan;
// 'A'#13#10'B' -- CRLF is a single tkEOL token, not two separate tokens.
// Tokens: A(0), CRLF(1), B(2), EOF(3)
// A.TrailingTrivia = [1..1]; B.LeadingTrivia = empty.
var
  T: TList<TToken>;
begin
  T := Lex('A'#13#10'B');
  try
    Assert.AreEqual(tkEOL, T[1].Kind, 'CRLF must produce a single tkEOL token');
    Assert.AreEqual(1, T[0].TrailingTrivia.Count,
      'A trailing must contain exactly the CRLF (one token)');
    Assert.AreEqual(1, T[0].TrailingTrivia.FirstTokenIndex,
      'CRLF must be at index 1 inside the trailing span');
    Assert.IsTrue(T[2].LeadingTrivia.IsEmpty, 'B leading must be empty');
  finally
    T.Free;
  end;
end;


procedure TTriviaSpanTests.AdjacentSemanticTokens_BothSpansEmpty;
// 'A;B' -- semicolon and B are adjacent with no trivia between them.
// Tokens: A(0), ;(1), B(2), EOF(3)
// ;.TrailingTrivia = empty; B.LeadingTrivia = empty.
var
  T: TList<TToken>;
begin
  T := Lex('A;B');
  try
    Assert.IsTrue(T[1].TrailingTrivia.IsEmpty,
      '; trailing must be empty when B follows with no trivia');
    Assert.IsTrue(T[2].LeadingTrivia.IsEmpty,
      'B leading must be empty when ; precedes with no trivia');
  finally
    T.Free;
  end;
end;


// ---------------------------------------------------------------------------
// Invariants I-14, I-15, I-16
// ---------------------------------------------------------------------------

procedure TTriviaSpanTests.I14_EachTriviaTokenOwnedExactlyOnce;
// Mixed source: leading comment, directive, inline trailing comment, blank line.
// AssertOwnershipInvariant verifies I-14 and I-15 together.
var
  T: TList<TToken>;
begin
  T := Lex(
    '// header'#10 +
    '{$IFDEF X}'#10 +
    'procedure Foo; // inline'#10 +
    'begin'#10 +
    #10 +
    '  A := 1;'#10 +
    'end;'#10
  );
  try
    AssertOwnershipInvariant(T);
  finally
    T.Free;
  end;
end;


procedure TTriviaSpanTests.I14_SumOfSpanCountsEqualsTriviaTokenCount;
// The total number of trivia tokens must equal the sum of all leading and
// trailing span counts across all semantic tokens (including EOF).
var
  T: TList<TToken>;
  I, TriviaCount, SpanTotal: Integer;
begin
  T := Lex(
    '// comment'#10 +
    'Foo := 1; // trailing'#10 +
    #10 +
    'Bar;'#10
  );
  try
    TriviaCount := 0;
    SpanTotal   := 0;
    for I := 0 to T.Count - 1 do
    begin
      if IsTrivia(T[I].Kind) then
        Inc(TriviaCount)
      else
      begin
        Inc(SpanTotal, T[I].LeadingTrivia.Count);
        Inc(SpanTotal, T[I].TrailingTrivia.Count);
      end;
    end;
    Assert.AreEqual(TriviaCount, SpanTotal,
      'Sum of all span counts must equal the total number of trivia tokens');
  finally
    T.Free;
  end;
end;


procedure TTriviaSpanTests.I15_TriviaTokensHaveEmptySpans;
// Every trivia token in the list must have IsEmpty = True on both spans.
// MakeToken initialises them to (-1,-1); the grouping pass skips trivia tokens.
var
  T: TList<TToken>;
  I: Integer;
begin
  T := Lex('// comment'#10'Foo := 1;'#10);
  try
    for I := 0 to T.Count - 1 do
      if IsTrivia(T[I].Kind) then
      begin
        Assert.IsTrue(T[I].LeadingTrivia.IsEmpty,
          Format('Trivia token at index %d must have empty LeadingTrivia (I-15)', [I]));
        Assert.IsTrue(T[I].TrailingTrivia.IsEmpty,
          Format('Trivia token at index %d must have empty TrailingTrivia (I-15)', [I]));
      end;
  finally
    T.Free;
  end;
end;


procedure TTriviaSpanTests.I16_EOF_OwnsTrailingFileTrivia;
// Any trivia after the last semantic token must be owned as leading trivia
// of the tkEOF sentinel.  The EOF trailing span must always be empty.
// 'Foo;'#10'// tail' -- comment at end of file with no following EOL.
var
  T: TList<TToken>;
  EOFIdx: Integer;
begin
  T := Lex('Foo;'#10'// tail');
  try
    EOFIdx := T.Count - 1;
    Assert.AreEqual(tkEOF, T[EOFIdx].Kind, 'Last token must be EOF');
    Assert.IsTrue(T[EOFIdx].TrailingTrivia.IsEmpty,
      'EOF trailing must always be empty (I-16)');
    Assert.IsFalse(T[EOFIdx].LeadingTrivia.IsEmpty,
      'EOF must own the trailing-file comment as leading trivia (I-16)');
    Assert.AreEqual(tkComment, T[T[EOFIdx].LeadingTrivia.FirstTokenIndex].Kind,
      'First item in EOF leading trivia must be the trailing-file comment');
  finally
    T.Free;
  end;
end;


initialization

TDUnitX.RegisterTestFixture(TTriviaSpanTests);

end.
