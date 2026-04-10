unit Test.Delphi.Lexer.Symbols;

// Explicit coverage for tkSymbol production (invariant I-13).
//
// Multi-character operators must be emitted as a single token, not split into
// their constituent characters. Each multi-char operator is tested directly:
// the token list must contain exactly one tkSymbol with the full text, not two
// separate single-char tokens. This would silently regress if the longest-match
// check in ReadSymbol were removed or reordered.
//
// Single-character symbols are spot-checked to confirm they are unaffected.

interface

uses
  DUnitX.TestFramework,
  Delphi.Token,
  Delphi.TokenList,
  Delphi.Lexer;

type

  [TestFixture]
  TSymbolTests = class
  private
    FLexer: TDelphiLexer;
    function Tok(const S: string): TTokenList;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // --- Multi-char operators: emitted as a single token ---

    // ':=' must be one tkSymbol, not tkSymbol(':') + tkSymbol('=').
    [Test] procedure ColonEquals_IsSingleSymbol;

    // '<>' must be one tkSymbol, not tkSymbol('<') + tkSymbol('>').
    [Test] procedure LessGreater_IsSingleSymbol;

    // '<=' must be one tkSymbol, not tkSymbol('<') + tkSymbol('=').
    [Test] procedure LessEquals_IsSingleSymbol;

    // '>=' must be one tkSymbol, not tkSymbol('>') + tkSymbol('=').
    [Test] procedure GreaterEquals_IsSingleSymbol;

    // '..' must be one tkSymbol, not tkSymbol('.') + tkSymbol('.').
    [Test] procedure DotDot_IsSingleSymbol;

    // '<<' must be one tkSymbol, not tkSymbol('<') + tkSymbol('<').
    [Test] procedure DoubleLess_IsSingleSymbol;

    // '>>' must be one tkSymbol, not tkSymbol('>') + tkSymbol('>').
    [Test] procedure DoubleGreater_IsSingleSymbol;

    // --- Single-char symbols: unaffected by longest-match ---

    // ':' not followed by '=' is a single-char symbol.
    [Test] procedure Colon_Alone_IsSingleChar;

    // '<' not followed by '>', '=', or '<' is a single-char symbol.
    [Test] procedure Less_Alone_IsSingleChar;

    // '>' not followed by '=' or '>' is a single-char symbol.
    [Test] procedure Greater_Alone_IsSingleChar;

    // '.' not followed by '.' is a single-char symbol.
    [Test] procedure Dot_Alone_IsSingleChar;

    // '^' not followed by any non-whitespace char is a single-char symbol (pointer deref).
    [Test] procedure Caret_Alone_IsSingleSymbol;
    [Test] procedure Caret_FollowedBySpace_IsSingleSymbol;
    [Test] procedure Caret_AtEOF_IsSingleSymbol;

    // --- Hat-notation control char literals ---

    // ^X for any non-whitespace X produces tkCharLiteral.
    [Test] procedure HatChar_UppercaseLetter_IsCharLiteral;
    [Test] procedure HatChar_LowercaseLetter_IsCharLiteral;
    [Test] procedure HatChar_Digit_IsCharLiteral;
    [Test] procedure HatChar_DoubleCaret_IsCharLiteral;
    [Test] procedure HatChar_Asterisk_IsCharLiteral;
    [Test] procedure HatChar_TextIsPreserved;
    [Test] procedure HatChar_MultipleInSet_ThreeTokens;
    [Test] procedure HatChar_SpaceBetweenCaretAndLetter_IsNotCharLiteral;
  end;


implementation

uses
  Delphi.TokenKind;


procedure TSymbolTests.Setup;
begin
  FLexer := TDelphiLexer.Create;
end;


procedure TSymbolTests.TearDown;
begin
  FLexer.Free;
end;


function TSymbolTests.Tok(const S: string): TTokenList;
begin
  Result := FLexer.Tokenize(S);
end;


// ---------------------------------------------------------------------------
// Multi-char operators
// ---------------------------------------------------------------------------

procedure TSymbolTests.ColonEquals_IsSingleSymbol;
var
  T: TTokenList;
begin
  T := Tok(':=');
  try
    // tkSymbol(':=') + tkEOF
    Assert.AreEqual(NativeInt(2), T.Count, 'count');
    Assert.AreEqual(Ord(tkSymbol), Ord(T[0].Kind), 'kind');
    Assert.AreEqual(':=', T[0].Text, 'text');
  finally
    T.Free;
  end;
end;


procedure TSymbolTests.LessGreater_IsSingleSymbol;
var
  T: TTokenList;
begin
  T := Tok('<>');
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count');
    Assert.AreEqual(Ord(tkSymbol), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('<>', T[0].Text, 'text');
  finally
    T.Free;
  end;
end;


procedure TSymbolTests.LessEquals_IsSingleSymbol;
var
  T: TTokenList;
begin
  T := Tok('<=');
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count');
    Assert.AreEqual(Ord(tkSymbol), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('<=', T[0].Text, 'text');
  finally
    T.Free;
  end;
end;


procedure TSymbolTests.GreaterEquals_IsSingleSymbol;
var
  T: TTokenList;
begin
  T := Tok('>=');
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count');
    Assert.AreEqual(Ord(tkSymbol), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('>=', T[0].Text, 'text');
  finally
    T.Free;
  end;
end;


procedure TSymbolTests.DotDot_IsSingleSymbol;
var
  T: TTokenList;
begin
  T := Tok('..');
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count');
    Assert.AreEqual(Ord(tkSymbol), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('..', T[0].Text, 'text');
  finally
    T.Free;
  end;
end;


procedure TSymbolTests.DoubleLess_IsSingleSymbol;
var
  T: TTokenList;
begin
  T := Tok('<<');
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count');
    Assert.AreEqual(Ord(tkSymbol), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('<<', T[0].Text, 'text');
  finally
    T.Free;
  end;
end;


procedure TSymbolTests.DoubleGreater_IsSingleSymbol;
var
  T: TTokenList;
begin
  T := Tok('>>');
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count');
    Assert.AreEqual(Ord(tkSymbol), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('>>', T[0].Text, 'text');
  finally
    T.Free;
  end;
end;


// ---------------------------------------------------------------------------
// Single-char symbols (regression: longest-match must not consume too much)
// ---------------------------------------------------------------------------

procedure TSymbolTests.Colon_Alone_IsSingleChar;
var
  T: TTokenList;
begin
  // ':' followed by a non-'=' character: must not be consumed as part of ':='.
  T := Tok(':X');
  try
    // tkSymbol(':') + tkIdentifier('X') + tkEOF
    Assert.AreEqual(NativeInt(3), T.Count, 'count');
    Assert.AreEqual(Ord(tkSymbol), Ord(T[0].Kind), 'kind');
    Assert.AreEqual(':', T[0].Text, 'text');
  finally
    T.Free;
  end;
end;


procedure TSymbolTests.Less_Alone_IsSingleChar;
var
  T: TTokenList;
begin
  // '<' followed by something other than '>', '=', or '<': emitted as single char.
  T := Tok('<X');
  try
    Assert.AreEqual(NativeInt(3), T.Count, 'count');
    Assert.AreEqual(Ord(tkSymbol), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('<', T[0].Text, 'text');
  finally
    T.Free;
  end;
end;


procedure TSymbolTests.Greater_Alone_IsSingleChar;
var
  T: TTokenList;
begin
  T := Tok('>X');
  try
    Assert.AreEqual(NativeInt(3), T.Count, 'count');
    Assert.AreEqual(Ord(tkSymbol), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('>', T[0].Text, 'text');
  finally
    T.Free;
  end;
end;


procedure TSymbolTests.Dot_Alone_IsSingleChar;
var
  T: TTokenList;
begin
  // '.' followed by a non-'.' character: emitted as single char.
  T := Tok('.X');
  try
    Assert.AreEqual(NativeInt(3), T.Count, 'count');
    Assert.AreEqual(Ord(tkSymbol), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('.', T[0].Text, 'text');
  finally
    T.Free;
  end;
end;


// ---------------------------------------------------------------------------
// Caret alone (pointer deref): not a hat char literal
// ---------------------------------------------------------------------------

procedure TSymbolTests.Caret_Alone_IsSingleSymbol;
var
  T: TTokenList;
begin
  // '^' at end of input: still a symbol (deref), not a char literal.
  T := Tok('^');
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count');
    Assert.AreEqual(Ord(tkSymbol), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('^', T[0].Text, 'text');
  finally
    T.Free;
  end;
end;


procedure TSymbolTests.Caret_FollowedBySpace_IsSingleSymbol;
var
  T: TTokenList;
begin
  // '^' followed by a space: whitespace breaks hat-char, caret is tkSymbol.
  T := Tok('^ X');
  try
    Assert.AreEqual(NativeInt(4), T.Count, 'count');
    Assert.AreEqual(Ord(tkSymbol), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('^', T[0].Text, 'text');
  finally
    T.Free;
  end;
end;


procedure TSymbolTests.Caret_AtEOF_IsSingleSymbol;
var
  T: TTokenList;
begin
  // Same as Caret_Alone -- belt-and-suspenders: Peek past end returns #0.
  T := Tok('^');
  try
    Assert.AreEqual(Ord(tkSymbol), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('^', T[0].Text, 'text');
  finally
    T.Free;
  end;
end;


// ---------------------------------------------------------------------------
// Hat-notation control char literals
// ---------------------------------------------------------------------------

procedure TSymbolTests.HatChar_UppercaseLetter_IsCharLiteral;
var
  T: TTokenList;
begin
  // ^V (Ctrl+V, Chr(22)) must be a single tkCharLiteral, not tkSymbol + tkIdentifier.
  T := Tok('^V');
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count');
    Assert.AreEqual(Ord(tkCharLiteral), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('^V', T[0].Text, 'text');
  finally
    T.Free;
  end;
end;


procedure TSymbolTests.HatChar_LowercaseLetter_IsCharLiteral;
var
  T: TTokenList;
begin
  // ^v (lowercase) is also a valid control char literal.
  T := Tok('^v');
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count');
    Assert.AreEqual(Ord(tkCharLiteral), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('^v', T[0].Text, 'text');
  finally
    T.Free;
  end;
end;


procedure TSymbolTests.HatChar_Digit_IsCharLiteral;
var
  T: TTokenList;
begin
  // ^1 -- digit is a valid hat char (not just letters).
  T := Tok('^1');
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count');
    Assert.AreEqual(Ord(tkCharLiteral), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('^1', T[0].Text, 'text');
  finally
    T.Free;
  end;
end;


procedure TSymbolTests.HatChar_DoubleCaret_IsCharLiteral;
var
  T: TTokenList;
begin
  // ^^ -- caret followed by caret is a valid hat char (Chr(30)).
  T := Tok('^^');
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count');
    Assert.AreEqual(Ord(tkCharLiteral), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('^^', T[0].Text, 'text');
  finally
    T.Free;
  end;
end;


procedure TSymbolTests.HatChar_Asterisk_IsCharLiteral;
var
  T: TTokenList;
begin
  // ^* -- asterisk is a valid hat char (Chr(10)).
  T := Tok('^*');
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count');
    Assert.AreEqual(Ord(tkCharLiteral), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('^*', T[0].Text, 'text');
  finally
    T.Free;
  end;
end;


procedure TSymbolTests.HatChar_TextIsPreserved;
var
  T: TTokenList;
begin
  // Token text must round-trip exactly: '^X' not 'X' or Chr(24).
  T := Tok('^X');
  try
    Assert.AreEqual('^X', T[0].Text, 'text');
    Assert.AreEqual(NativeInt(2), NativeInt(Length(T[0].Text)), 'text length');
  finally
    T.Free;
  end;
end;


procedure TSymbolTests.HatChar_MultipleInSet_ThreeTokens;
var
  T: TTokenList;
begin
  // '[^V,^X,^C]' -- each hat literal is one token.
  // Expected non-trivia tokens: '[' '^V' ',' '^X' ',' '^C' ']' EOF = 8 tokens total.
  T := Tok('[^V,^X,^C]');
  try
    Assert.AreEqual(NativeInt(8), T.Count, 'count');
    Assert.AreEqual(Ord(tkSymbol),      Ord(T[0].Kind), 'T[0] kind');
    Assert.AreEqual(Ord(tkCharLiteral), Ord(T[1].Kind), 'T[1] kind');
    Assert.AreEqual('^V', T[1].Text, 'T[1] text');
    Assert.AreEqual(Ord(tkCharLiteral), Ord(T[3].Kind), 'T[3] kind');
    Assert.AreEqual('^X', T[3].Text, 'T[3] text');
    Assert.AreEqual(Ord(tkCharLiteral), Ord(T[5].Kind), 'T[5] kind');
    Assert.AreEqual('^C', T[5].Text, 'T[5] text');
  finally
    T.Free;
  end;
end;


procedure TSymbolTests.HatChar_SpaceBetweenCaretAndLetter_IsNotCharLiteral;
var
  T: TTokenList;
begin
  // '^ V' -- whitespace between '^' and 'V' means no hat literal.
  // The caret must be immediately adjacent to the letter; trivia is not allowed.
  // Expected tokens: tkSymbol('^'), tkWhitespace(' '), tkIdentifier('V'), tkEOF.
  T := Tok('^ V');
  try
    Assert.AreEqual(NativeInt(4), T.Count, 'count');
    Assert.AreEqual(Ord(tkSymbol),     Ord(T[0].Kind), 'T[0] kind');
    Assert.AreEqual('^',               T[0].Text,      'T[0] text');
    Assert.AreEqual(Ord(tkWhitespace), Ord(T[1].Kind), 'T[1] kind');
    Assert.AreEqual(Ord(tkIdentifier), Ord(T[2].Kind), 'T[2] kind');
    Assert.AreEqual('V',               T[2].Text,      'T[2] text');
  finally
    T.Free;
  end;
end;


initialization

TDUnitX.RegisterTestFixture(TSymbolTests);

end.
