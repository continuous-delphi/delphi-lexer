unit Test.DelphiLexer.InvalidTokens;

// Explicit coverage for tkInvalid production and unterminated constructs.
//
// Sections:
//   1. Bare prefixes -- characters that require specific following characters
//      to form a valid token but appear without them.
//   2. Stray characters -- characters with no syntactic role in Delphi.
//   3. Malformed binary literals -- % not followed by 0 or 1.
//   4. Malformed octal literals -- & followed by digits outside 0..7.
//   5. Unterminated constructs -- read helpers reach EOF without a closing
//      delimiter; produce the expected token kind (not tkInvalid) but with
//      no closing delimiter in the text. Round-trip is preserved in all cases.
//
// In every tkInvalid case the token text is exactly the offending character(s),
// nothing more -- the lexer does not absorb adjacent characters into the
// invalid token.

interface

uses
  DUnitX.TestFramework,
  System.Generics.Collections,
  DelphiLexer.Token,
  DelphiLexer.Lexer;

type

  [TestFixture]
  TInvalidTokenTests = class
  private
    FLexer: TDelphiLexer;
    function Tok(const S: string): TList<TToken>;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // --- Bare prefixes ---

    // '$' with no following hex digit is not a valid hex literal.
    [Test] procedure Bare_Dollar_IsInvalid;

    // '#' with no following digit or '$hex' is not a valid char literal.
    [Test] procedure Bare_Hash_IsInvalid;

    // '#$' with no following hex digits: both '#' and '$' are invalid.
    [Test] procedure Bare_HashDollar_IsInvalid;

    // '&' not followed by an ident char or octal digit is not valid.
    [Test] procedure Bare_Ampersand_IsInvalid;

    // '%' not followed by '0' or '1' is not a valid binary literal.
    [Test] procedure Bare_Percent_IsInvalid;

    // --- Stray characters ---

    // '}' has no opening role and is not in the symbol whitelist.
    [Test] procedure Stray_ClosingBrace_IsInvalid;

    // '?' is not a Delphi operator or punctuation.
    [Test] procedure Stray_QuestionMark_IsInvalid;

    // NUL character (#0) is not valid source text.
    [Test] procedure Stray_NullChar_IsInvalid;

    // --- Malformed binary literals ---

    // '%' followed by a decimal digit (not 0 or 1): invalid prefix, then number.
    [Test] procedure MalformedBinary_NonBinaryDigit_IsInvalid;

    // '%' followed by a letter: invalid prefix, then identifier.
    [Test] procedure MalformedBinary_Letter_IsInvalid;

    // --- Malformed octal literals ---

    // '&' followed by '8': 8 is outside the octal range 0..7.
    [Test] procedure MalformedOctal_Digit8_IsInvalid;

    // '&' followed by '9': 9 is outside the octal range 0..7.
    [Test] procedure MalformedOctal_Digit9_IsInvalid;

    // --- Unterminated constructs ---
    // These produce the expected token kind (not tkInvalid). The lexer reads
    // to EOF and returns all consumed characters as the token text, preserving
    // round-trip fidelity. For directives the kind is tkDirective, not tkComment.

    // Unterminated single-quoted string with no EOL: tkString, text = everything from ' to EOF.
    [Test] procedure Unterminated_String_NoEOL_IstkString;

    // Unterminated single-quoted string followed by EOL: string stops at the
    // EOL; the EOL is a separate tkEOL, not swallowed into the string token.
    [Test] procedure Unterminated_String_StopsAtEOL;

    // Unterminated brace comment: tkComment, text = everything from { to EOF.
    [Test] procedure Unterminated_BraceComment_IstkComment;

    // Unterminated paren-star comment: tkComment, text = everything from (* to EOF.
    [Test] procedure Unterminated_ParenStarComment_IstkComment;

    // Unterminated brace directive: tkDirective (not tkComment, not tkInvalid),
    // text = everything from {$ to EOF.
    [Test] procedure Unterminated_BraceDirective_IstkDirective;

    // Unterminated paren-star directive: tkDirective (not tkComment, not tkInvalid),
    // text = everything from (*$ to EOF.
    [Test] procedure Unterminated_ParenStarDirective_IstkDirective;
  end;

implementation


procedure TInvalidTokenTests.Setup;
begin
  FLexer := TDelphiLexer.Create;
end;


procedure TInvalidTokenTests.TearDown;
begin
  FLexer.Free;
end;


function TInvalidTokenTests.Tok(const S: string): TList<TToken>;
begin
  Result := FLexer.Tokenize(S);
end;


// ---------------------------------------------------------------------------
// Bare prefixes
// ---------------------------------------------------------------------------

procedure TInvalidTokenTests.Bare_Dollar_IsInvalid;
var
  T: TList<TToken>;
begin
  T := Tok('$');
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count');
    Assert.AreEqual(Ord(tkInvalid), Ord(T[0].Kind), '[0] kind');
    Assert.AreEqual('$', T[0].Text, '[0] text');
  finally
    T.Free;
  end;
end;


procedure TInvalidTokenTests.Bare_Hash_IsInvalid;
var
  T: TList<TToken>;
begin
  T := Tok('#');
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count');
    Assert.AreEqual(Ord(tkInvalid), Ord(T[0].Kind), '[0] kind');
    Assert.AreEqual('#', T[0].Text, '[0] text');
  finally
    T.Free;
  end;
end;


procedure TInvalidTokenTests.Bare_HashDollar_IsInvalid;
var
  T: TList<TToken>;
begin
  // '#$' with no hex digits: '#' cannot start a char literal (requires digit
  // or '$' with a following hex digit), and '$' cannot start a hex literal
  // (requires a following hex digit). Both are emitted as separate tkInvalid.
  T := Tok('#$');
  try
    Assert.AreEqual(NativeInt(3), T.Count, 'count');
    Assert.AreEqual(Ord(tkInvalid), Ord(T[0].Kind), '[0] kind');
    Assert.AreEqual('#', T[0].Text, '[0] text');
    Assert.AreEqual(Ord(tkInvalid), Ord(T[1].Kind), '[1] kind');
    Assert.AreEqual('$', T[1].Text, '[1] text');
  finally
    T.Free;
  end;
end;


procedure TInvalidTokenTests.Bare_Ampersand_IsInvalid;
var
  T: TList<TToken>;
begin
  // '&' alone: not followed by an ident-start char (escaped identifier path)
  // or an octal digit (octal literal path), so it falls to tkInvalid.
  T := Tok('&');
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count');
    Assert.AreEqual(Ord(tkInvalid), Ord(T[0].Kind), '[0] kind');
    Assert.AreEqual('&', T[0].Text, '[0] text');
  finally
    T.Free;
  end;
end;


procedure TInvalidTokenTests.Bare_Percent_IsInvalid;
var
  T: TList<TToken>;
begin
  // '%' alone: binary literal requires '0' or '1' immediately after '%'.
  T := Tok('%');
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count');
    Assert.AreEqual(Ord(tkInvalid), Ord(T[0].Kind), '[0] kind');
    Assert.AreEqual('%', T[0].Text, '[0] text');
  finally
    T.Free;
  end;
end;


// ---------------------------------------------------------------------------
// Stray characters
// ---------------------------------------------------------------------------

procedure TInvalidTokenTests.Stray_ClosingBrace_IsInvalid;
var
  T: TList<TToken>;
begin
  // '}' is only valid inside a '{...}' comment which the lexer has already
  // consumed. A stray '}' in source is not in the symbol whitelist.
  T := Tok('}');
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count');
    Assert.AreEqual(Ord(tkInvalid), Ord(T[0].Kind), '[0] kind');
    Assert.AreEqual('}', T[0].Text, '[0] text');
  finally
    T.Free;
  end;
end;


procedure TInvalidTokenTests.Stray_QuestionMark_IsInvalid;
var
  T: TList<TToken>;
begin
  T := Tok('?');
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count');
    Assert.AreEqual(Ord(tkInvalid), Ord(T[0].Kind), '[0] kind');
    Assert.AreEqual('?', T[0].Text, '[0] text');
  finally
    T.Free;
  end;
end;


procedure TInvalidTokenTests.Stray_NullChar_IsInvalid;
var
  T: TList<TToken>;
begin
  // A NUL character embedded in source is not a valid token start.
  T := Tok(#0);
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count');
    Assert.AreEqual(Ord(tkInvalid), Ord(T[0].Kind), '[0] kind');
    Assert.AreEqual(#0, T[0].Text, '[0] text');
    Assert.AreEqual(1, T[0].Length, '[0] length');
  finally
    T.Free;
  end;
end;


// ---------------------------------------------------------------------------
// Malformed binary literals
// ---------------------------------------------------------------------------

procedure TInvalidTokenTests.MalformedBinary_NonBinaryDigit_IsInvalid;
var
  T: TList<TToken>;
begin
  // '%2': '%' requires '0' or '1' -- '2' is not binary. The '%' becomes
  // tkInvalid and '2' is tokenized independently as tkNumber.
  T := Tok('%2');
  try
    Assert.AreEqual(NativeInt(3), T.Count, 'count');
    Assert.AreEqual(Ord(tkInvalid), Ord(T[0].Kind), '[0] kind');
    Assert.AreEqual('%', T[0].Text, '[0] text');
    Assert.AreEqual(Ord(tkNumber), Ord(T[1].Kind), '[1] kind');
    Assert.AreEqual('2', T[1].Text, '[1] text');
  finally
    T.Free;
  end;
end;


procedure TInvalidTokenTests.MalformedBinary_Letter_IsInvalid;
var
  T: TList<TToken>;
begin
  // '%A': '%' requires '0' or '1' -- 'A' is not binary. The '%' becomes
  // tkInvalid and 'A' is tokenized independently as tkIdentifier.
  T := Tok('%A');
  try
    Assert.AreEqual(NativeInt(3), T.Count, 'count');
    Assert.AreEqual(Ord(tkInvalid), Ord(T[0].Kind), '[0] kind');
    Assert.AreEqual('%', T[0].Text, '[0] text');
    Assert.AreEqual(Ord(tkIdentifier), Ord(T[1].Kind), '[1] kind');
    Assert.AreEqual('A', T[1].Text, '[1] text');
  finally
    T.Free;
  end;
end;


// ---------------------------------------------------------------------------
// Malformed octal literals
// ---------------------------------------------------------------------------

procedure TInvalidTokenTests.MalformedOctal_Digit8_IsInvalid;
var
  T: TList<TToken>;
begin
  // '&8': octal requires a digit in 0..7 after '&'. '8' is out of range,
  // so '&' is not dispatched to the octal path and becomes tkInvalid.
  // '8' is then tokenized independently as tkNumber.
  T := Tok('&8');
  try
    Assert.AreEqual(NativeInt(3), T.Count, 'count');
    Assert.AreEqual(Ord(tkInvalid), Ord(T[0].Kind), '[0] kind');
    Assert.AreEqual('&', T[0].Text, '[0] text');
    Assert.AreEqual(Ord(tkNumber), Ord(T[1].Kind), '[1] kind');
    Assert.AreEqual('8', T[1].Text, '[1] text');
  finally
    T.Free;
  end;
end;


procedure TInvalidTokenTests.MalformedOctal_Digit9_IsInvalid;
var
  T: TList<TToken>;
begin
  T := Tok('&9');
  try
    Assert.AreEqual(NativeInt(3), T.Count, 'count');
    Assert.AreEqual(Ord(tkInvalid), Ord(T[0].Kind), '[0] kind');
    Assert.AreEqual('&', T[0].Text, '[0] text');
    Assert.AreEqual(Ord(tkNumber), Ord(T[1].Kind), '[1] kind');
    Assert.AreEqual('9', T[1].Text, '[1] text');
  finally
    T.Free;
  end;
end;


// ---------------------------------------------------------------------------
// Unterminated constructs
// ---------------------------------------------------------------------------

procedure TInvalidTokenTests.Unterminated_String_NoEOL_IstkString;
var
  Src: string;
  T:   TList<TToken>;
  RoundTrip: string;
  I:   Integer;
begin
  // Source ends immediately after the string content with no EOL.
  // The string token consumes everything to EOF.
  Src := '''hello';
  T := Tok(Src);
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count');
    Assert.AreEqual(Ord(tkString), Ord(T[0].Kind), '[0] kind');
    Assert.AreEqual(Src, T[0].Text, '[0] text = entire source');
    RoundTrip := '';
    for I := 0 to T.Count - 1 do
      RoundTrip := RoundTrip + T[I].Text;
    Assert.AreEqual(Src, RoundTrip, 'round-trip');
  finally
    T.Free;
  end;
end;


procedure TInvalidTokenTests.Unterminated_String_StopsAtEOL;
var
  Src: string;
  T:   TList<TToken>;
  RoundTrip: string;
  I:   Integer;
begin
  // Source: 'hello followed by CRLF -- no closing quote on the line.
  // The string token stops at the CRLF; the CRLF becomes a separate tkEOL.
  // This prevents the EOL and any subsequent tokens from being swallowed.
  Src := '''hello' + #13#10;
  T := Tok(Src);
  try
    Assert.AreEqual(NativeInt(3), T.Count, 'count: tkString + tkEOL + tkEOF');
    Assert.AreEqual(Ord(tkString), Ord(T[0].Kind), '[0] kind');
    Assert.AreEqual('''hello', T[0].Text, '[0] text');
    Assert.AreEqual(Ord(tkEOL), Ord(T[1].Kind), '[1] kind');
    Assert.AreEqual(#13#10, T[1].Text, '[1] text');
    RoundTrip := '';
    for I := 0 to T.Count - 1 do
      RoundTrip := RoundTrip + T[I].Text;
    Assert.AreEqual(Src, RoundTrip, 'round-trip');
  finally
    T.Free;
  end;
end;


procedure TInvalidTokenTests.Unterminated_BraceComment_IstkComment;
var
  Src: string;
  T:   TList<TToken>;
  RoundTrip: string;
  I:   Integer;
begin
  Src := '{hello';
  T := Tok(Src);
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count');
    Assert.AreEqual(Ord(tkComment), Ord(T[0].Kind), '[0] kind');
    Assert.AreEqual(Src, T[0].Text, '[0] text = entire source');
    RoundTrip := '';
    for I := 0 to T.Count - 1 do
      RoundTrip := RoundTrip + T[I].Text;
    Assert.AreEqual(Src, RoundTrip, 'round-trip');
  finally
    T.Free;
  end;
end;


procedure TInvalidTokenTests.Unterminated_ParenStarComment_IstkComment;
var
  Src: string;
  T:   TList<TToken>;
  RoundTrip: string;
  I:   Integer;
begin
  Src := '(*hello';
  T := Tok(Src);
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count');
    Assert.AreEqual(Ord(tkComment), Ord(T[0].Kind), '[0] kind');
    Assert.AreEqual(Src, T[0].Text, '[0] text = entire source');
    RoundTrip := '';
    for I := 0 to T.Count - 1 do
      RoundTrip := RoundTrip + T[I].Text;
    Assert.AreEqual(Src, RoundTrip, 'round-trip');
  finally
    T.Free;
  end;
end;


procedure TInvalidTokenTests.Unterminated_BraceDirective_IstkDirective;
var
  Src: string;
  T:   TList<TToken>;
  RoundTrip: string;
  I:   Integer;
begin
  // {$ with no closing }: the lexer reads to EOF. The token kind must be
  // tkDirective (not tkComment and not tkInvalid), matching the terminated form.
  Src := '{$IFDEF DEBUG';
  T := Tok(Src);
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count');
    Assert.AreEqual(Ord(tkDirective), Ord(T[0].Kind), '[0] kind');
    Assert.AreEqual(Src, T[0].Text, '[0] text = entire source');
    RoundTrip := '';
    for I := 0 to T.Count - 1 do
      RoundTrip := RoundTrip + T[I].Text;
    Assert.AreEqual(Src, RoundTrip, 'round-trip');
  finally
    T.Free;
  end;
end;


procedure TInvalidTokenTests.Unterminated_ParenStarDirective_IstkDirective;
var
  Src: string;
  T:   TList<TToken>;
  RoundTrip: string;
  I:   Integer;
begin
  // (*$ with no closing *): the lexer reads to EOF. The token kind must be
  // tkDirective (not tkComment and not tkInvalid), matching the terminated form.
  Src := '(*$R+';
  T := Tok(Src);
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count');
    Assert.AreEqual(Ord(tkDirective), Ord(T[0].Kind), '[0] kind');
    Assert.AreEqual(Src, T[0].Text, '[0] text = entire source');
    RoundTrip := '';
    for I := 0 to T.Count - 1 do
      RoundTrip := RoundTrip + T[I].Text;
    Assert.AreEqual(Src, RoundTrip, 'round-trip');
  finally
    T.Free;
  end;
end;


initialization

TDUnitX.RegisterTestFixture(TInvalidTokenTests);

end.
