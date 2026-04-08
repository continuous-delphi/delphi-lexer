unit Test.Delphi.Lexer.AsmBody;

// Tests for tkAsmBody tokenization.
//
// An asm...end block is emitted as three tokens:
//   tkStrictKeyword('asm')
//   tkAsmBody(<all source text between asm and end, inclusive of whitespace>)
//   tkStrictKeyword('end')
//
// The interior of the body is opaque: it is not tokenised as individual
// Delphi or assembly tokens. Comments, directives, and quoted strings inside
// the body are still recognised structurally so that an 'end' appearing
// inside them is not mistaken for the block terminator.
//
// Sections:
//   1. Token shape -- kind, count, and body-text fidelity.
//   2. Opaqueness -- keywords and comments inside body are not separate tokens.
//   3. Terminator detection -- 'end' is found at the correct boundary.
//   4. Round-trip and offset invariants.
//   5. Unterminated asm block.
//   6. Trivia span behaviour.

interface

uses
  DUnitX.TestFramework,
  Delphi.Token,
  Delphi.TokenList,
  Delphi.Lexer;

type

  [TestFixture]
  TAsmBodyTests = class
  private
    FLexer: TDelphiLexer;
    function Tok(const S: string): TTokenList;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // --- Token shape ---
    [Test] procedure BasicShape_EmitsFourTokens;
    [Test] procedure BodyText_IsExact;
    [Test] procedure EmptyBlock_BodyIsSpace;

    // --- Opaqueness ---
    [Test] procedure KeywordsInsideBody_AreOpaque;
    [Test] procedure CommentsInsideBody_AreOpaque;

    // --- Terminator detection ---
    [Test] procedure EndInsideLineComment_NotTerminator;
    [Test] procedure EndInsideBlockComment_NotTerminator;
    [Test] procedure EndInsideParenStarComment_NotTerminator;
    [Test] procedure EndInsideString_NotTerminator;
    [Test] procedure Endian_TrailingBoundary_NotTerminator;
    [Test] procedure Vendor_LeadingBoundary_NotTerminator;
    [Test] procedure CaseInsensitiveEnd_Terminates;

    // --- Round-trip and offset invariants ---
    [Test] procedure RoundTrip_ExactReconstruction;
    [Test] procedure OffsetAndLength_AllTokens;

    // --- Unterminated asm block ---
    [Test] procedure Unterminated_BodyRunsToEOF;
    [Test] procedure Unterminated_NoEndTokenEmitted;

    // --- Trivia span behaviour ---
    [Test] procedure IsNotTrivia;
    [Test] procedure TriviaSpans_NoInternalTriviaTokens;
  end;


implementation

uses
  System.SysUtils,
  Delphi.TokenKind;

procedure TAsmBodyTests.Setup;
begin
  FLexer := TDelphiLexer.Create;
end;


procedure TAsmBodyTests.TearDown;
begin
  FLexer.Free;
end;


function TAsmBodyTests.Tok(const S: string): TTokenList;
begin
  Result := FLexer.Tokenize(S);
end;


// ---------------------------------------------------------------------------
// Token shape
// ---------------------------------------------------------------------------

procedure TAsmBodyTests.BasicShape_EmitsFourTokens;
var
  T: TTokenList;
begin
  // asm\r\n  mov eax, ebx\r\nend  ->  asm + body + end + EOF
  T := Tok('asm' + #13#10 + '  mov eax, ebx' + #13#10 + 'end');
  try
    Assert.AreEqual(NativeInt(4), T.Count, 'count');
    Assert.AreEqual(Ord(tkStrictKeyword), Ord(T[0].Kind), '[0] kind');
    Assert.AreEqual('asm',                T[0].Text,      '[0] text');
    Assert.AreEqual(Ord(tkAsmBody),       Ord(T[1].Kind), '[1] kind');
    Assert.AreEqual(Ord(tkStrictKeyword), Ord(T[2].Kind), '[2] kind');
    Assert.AreEqual('end',                T[2].Text,      '[2] text');
    Assert.AreEqual(Ord(tkEOF),           Ord(T[3].Kind), '[3] kind');
  finally
    T.Free;
  end;
end;


procedure TAsmBodyTests.BodyText_IsExact;
var
  T: TTokenList;
begin
  // The body token must contain the exact characters between 'asm' and 'end'.
  T := Tok('asm' + #13#10 + '  mov eax, ebx' + #13#10 + 'end');
  try
    Assert.AreEqual(#13#10 + '  mov eax, ebx' + #13#10, T[1].Text, 'body text');
  finally
    T.Free;
  end;
end;


procedure TAsmBodyTests.EmptyBlock_BodyIsSpace;
var
  T: TTokenList;
begin
  // 'asm end': only a space between 'asm' and 'end'.
  // The body captures that space; tkAsmBody is always emitted, even for a
  // near-empty block.
  T := Tok('asm end');
  try
    Assert.AreEqual(NativeInt(4), T.Count, 'count');
    Assert.AreEqual(Ord(tkAsmBody), Ord(T[1].Kind), '[1] kind');
    Assert.AreEqual(' ',            T[1].Text,      '[1] body text');
  finally
    T.Free;
  end;
end;


// ---------------------------------------------------------------------------
// Opaqueness
// ---------------------------------------------------------------------------

procedure TAsmBodyTests.KeywordsInsideBody_AreOpaque;
var
  T: TTokenList;
begin
  // 'and', 'or', 'shl' inside an asm block must not produce separate
  // tkStrictKeyword tokens -- they are part of the opaque body text.
  T := Tok('asm' + #13#10 +
           '  and eax, 1' + #13#10 +
           '  or eax, ebx' + #13#10 +
           '  shl eax, 1' + #13#10 +
           'end');
  try
    Assert.AreEqual(NativeInt(4), T.Count, 'token count: only asm + body + end + EOF');
    Assert.AreEqual(Ord(tkAsmBody), Ord(T[1].Kind), '[1] kind');
  finally
    T.Free;
  end;
end;


procedure TAsmBodyTests.CommentsInsideBody_AreOpaque;
var
  T:    TTokenList;
  Body: string;
begin
  // Comments inside asm body must not produce separate tkComment tokens.
  // Their text appears verbatim inside the single tkAsmBody token.
  T := Tok('asm' + #13#10 +
           '  mov eax, ebx // line comment' + #13#10 +
           '  { block comment }' + #13#10 +
           'end');
  try
    Assert.AreEqual(NativeInt(4), T.Count, 'token count: only asm + body + end + EOF');
    Assert.AreEqual(Ord(tkAsmBody), Ord(T[1].Kind), '[1] kind');
    Body := T[1].Text;
    Assert.IsTrue(Pos('// line comment', Body) > 0, 'line comment in body text');
    Assert.IsTrue(Pos('{ block comment }', Body) > 0, 'block comment in body text');
  finally
    T.Free;
  end;
end;


// ---------------------------------------------------------------------------
// Terminator detection
// ---------------------------------------------------------------------------

procedure TAsmBodyTests.EndInsideLineComment_NotTerminator;
var
  T: TTokenList;
begin
  // 'end' inside a // comment must not terminate the asm block.
  T := Tok('asm' + #13#10 +
           '  nop // move to end of buffer' + #13#10 +
           'end');
  try
    Assert.AreEqual(NativeInt(4), T.Count, 'count');
    Assert.AreEqual(Ord(tkAsmBody), Ord(T[1].Kind), '[1] kind');
    Assert.AreEqual('end', T[2].Text, '[2] is the real end');
  finally
    T.Free;
  end;
end;


procedure TAsmBodyTests.EndInsideBlockComment_NotTerminator;
var
  T: TTokenList;
begin
  // 'end' inside a { } comment must not terminate the asm block.
  T := Tok('asm' + #13#10 +
           '  { this is the end of it }' + #13#10 +
           '  nop' + #13#10 +
           'end');
  try
    Assert.AreEqual(NativeInt(4), T.Count, 'count');
    Assert.AreEqual(Ord(tkAsmBody), Ord(T[1].Kind), '[1] kind');
    Assert.AreEqual('end', T[2].Text, '[2] is the real end');
  finally
    T.Free;
  end;
end;


procedure TAsmBodyTests.EndInsideParenStarComment_NotTerminator;
var
  T: TTokenList;
begin
  // 'end' inside a (* *) comment or directive must not terminate the asm block.
  T := Tok('asm' + #13#10 +
           '  (* marks the end of the loop *)' + #13#10 +
           '  nop' + #13#10 +
           'end');
  try
    Assert.AreEqual(NativeInt(4), T.Count, 'count');
    Assert.AreEqual(Ord(tkAsmBody), Ord(T[1].Kind), '[1] kind');
    Assert.AreEqual('end', T[2].Text, '[2] is the real end');
  finally
    T.Free;
  end;
end;


procedure TAsmBodyTests.EndInsideString_NotTerminator;
var
  T: TTokenList;
begin
  // 'end' inside a quoted string literal must not terminate the asm block.
  T := Tok('asm' + #13#10 +
           '  lea eax, ''some end here''' + #13#10 +
           'end');
  try
    Assert.AreEqual(NativeInt(4), T.Count, 'count');
    Assert.AreEqual(Ord(tkAsmBody), Ord(T[1].Kind), '[1] kind');
    Assert.AreEqual('end', T[2].Text, '[2] is the real end');
  finally
    T.Free;
  end;
end;


procedure TAsmBodyTests.Endian_TrailingBoundary_NotTerminator;
var
  T: TTokenList;
begin
  // 'endian' starts with 'end' but the trailing boundary check ('i' follows)
  // must prevent it from being treated as a block terminator.
  T := Tok('asm' + #13#10 +
           '  mov endian, eax' + #13#10 +
           'end');
  try
    Assert.AreEqual(NativeInt(4), T.Count, 'count');
    Assert.AreEqual(Ord(tkAsmBody), Ord(T[1].Kind), '[1] kind');
    Assert.IsTrue(Pos('endian', T[1].Text) > 0, 'endian is inside the body');
    Assert.AreEqual('end', T[2].Text, '[2] is the real end');
  finally
    T.Free;
  end;
end;


procedure TAsmBodyTests.Vendor_LeadingBoundary_NotTerminator;
var
  T: TTokenList;
begin
  // 'vendor' contains 'end' as a substring but it is not at a word boundary.
  // The leading boundary check ('v' precedes 'e') must prevent a false match.
  T := Tok('asm' + #13#10 +
           '  mov vendor, eax' + #13#10 +
           'end');
  try
    Assert.AreEqual(NativeInt(4), T.Count, 'count');
    Assert.AreEqual(Ord(tkAsmBody), Ord(T[1].Kind), '[1] kind');
    Assert.IsTrue(Pos('vendor', T[1].Text) > 0, 'vendor is inside the body');
    Assert.AreEqual('end', T[2].Text, '[2] is the real end');
  finally
    T.Free;
  end;
end;


procedure TAsmBodyTests.CaseInsensitiveEnd_Terminates;
var
  T: TTokenList;
begin
  // 'END' (upper case) must terminate the asm block just as 'end' does.
  T := Tok('asm' + #13#10 + '  nop' + #13#10 + 'END');
  try
    Assert.AreEqual(NativeInt(4), T.Count, 'count');
    Assert.AreEqual(Ord(tkStrictKeyword), Ord(T[2].Kind), '[2] kind');
    Assert.AreEqual('END',                T[2].Text,      '[2] text');
  finally
    T.Free;
  end;
end;


// ---------------------------------------------------------------------------
// Round-trip and offset invariants
// ---------------------------------------------------------------------------

procedure TAsmBodyTests.RoundTrip_ExactReconstruction;
var
  Src:      string;
  T:        TTokenList;
  RoundTrip: string;
  I:        Integer;
begin
  Src := 'asm' + #13#10 + '  mov eax, ebx' + #13#10 + 'end';
  T := Tok(Src);
  try
    RoundTrip := '';
    for I := 0 to T.Count - 1 do
      RoundTrip := RoundTrip + T[I].Text;
    Assert.AreEqual(Src, RoundTrip, 'round-trip');
  finally
    T.Free;
  end;
end;


procedure TAsmBodyTests.OffsetAndLength_AllTokens;
var
  T:              TTokenList;
  ExpectedOffset: Integer;
  I:              Integer;
begin
  // 'asm' = 3 chars, body = #13#10 + '  nop' + #13#10 = 9 chars, 'end' = 3 chars.
  T := Tok('asm' + #13#10 + '  nop' + #13#10 + 'end');
  try
    ExpectedOffset := 0;
    for I := 0 to T.Count - 1 do
    begin
      Assert.AreEqual(ExpectedOffset, T[I].StartOffset,
        'StartOffset[' + IntToStr(I) + ']');
      Assert.AreEqual(System.Length(T[I].Text), T[I].Length,
        'Length[' + IntToStr(I) + ']');
      Inc(ExpectedOffset, T[I].Length);
    end;
  finally
    T.Free;
  end;
end;


// ---------------------------------------------------------------------------
// Unterminated asm block
// ---------------------------------------------------------------------------

procedure TAsmBodyTests.Unterminated_BodyRunsToEOF;
var
  Src:      string;
  T:        TTokenList;
  RoundTrip: string;
  I:        Integer;
begin
  // Source ends inside an asm block with no closing 'end'.
  // The body must consume all remaining source; no 'end' token is fabricated.
  Src := 'asm' + #13#10 + '  mov eax, 1';
  T := Tok(Src);
  try
    Assert.AreEqual(NativeInt(3), T.Count, 'count: asm + body + EOF only');
    Assert.AreEqual(Ord(tkStrictKeyword), Ord(T[0].Kind), '[0] kind');
    Assert.AreEqual(Ord(tkAsmBody),       Ord(T[1].Kind), '[1] kind');
    Assert.AreEqual(Ord(tkEOF),           Ord(T[2].Kind), '[2] kind');
    RoundTrip := '';
    for I := 0 to T.Count - 1 do
      RoundTrip := RoundTrip + T[I].Text;
    Assert.AreEqual(Src, RoundTrip, 'round-trip');
  finally
    T.Free;
  end;
end;


procedure TAsmBodyTests.Unterminated_NoEndTokenEmitted;
var
  T: TTokenList;
begin
  // Verify that the token immediately after tkAsmBody in an unterminated block
  // is tkEOF, not tkStrictKeyword('end').
  T := Tok('asm' + #13#10 + '  nop');
  try
    Assert.AreEqual(NativeInt(3), T.Count, 'count');
    Assert.AreEqual(Ord(tkEOF), Ord(T[2].Kind), '[2] is tkEOF, not a fabricated end');
  finally
    T.Free;
  end;
end;


// ---------------------------------------------------------------------------
// Trivia span behaviour
// ---------------------------------------------------------------------------

procedure TAsmBodyTests.IsNotTrivia;
begin
  // tkAsmBody is a semantic token, not trivia. The trivia pass must not
  // assign it as leading or trailing trivia on any surrounding token.
  Assert.IsFalse(IsLexicalTrivia(tkAsmBody), 'IsLexicalTrivia(tkAsmBody)');
end;


procedure TAsmBodyTests.TriviaSpans_NoInternalTriviaTokens;
var
  T: TTokenList;
begin
  // The whitespace and EOLs between 'asm' and 'end' are absorbed into the
  // tkAsmBody text. No separate trivia tokens exist between the three semantic
  // tokens, so all trivia spans on 'asm', the body, and 'end' are empty.
  T := Tok('asm' + #13#10 + '  mov eax, 1' + #13#10 + 'end');
  try
    // 'asm': no trailing trivia (tkAsmBody immediately follows as semantic token)
    Assert.IsTrue(T[0].TrailingTrivia.IsEmpty, 'asm TrailingTrivia empty');
    // body: no leading trivia, no trailing trivia
    Assert.IsTrue(T[1].LeadingTrivia.IsEmpty,  'body LeadingTrivia empty');
    Assert.IsTrue(T[1].TrailingTrivia.IsEmpty, 'body TrailingTrivia empty');
    // 'end': no leading trivia (body immediately precedes as semantic token)
    Assert.IsTrue(T[2].LeadingTrivia.IsEmpty,  'end LeadingTrivia empty');
  finally
    T.Free;
  end;
end;


initialization

TDUnitX.RegisterTestFixture(TAsmBodyTests);

end.
