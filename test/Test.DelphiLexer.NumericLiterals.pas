unit Test.DelphiLexer.NumericLiterals;

// Tests for numeric literal tokenization:
//   float (decimal + exponent), octal (&nnn), hex/binary digit separators.

interface

uses
  DUnitX.TestFramework,
  System.Generics.Collections,
  DelphiLexer.Token,
  DelphiLexer.Lexer;

type

  [TestFixture]
  TNumericLiteralTests = class
  private
    FLexer: TDelphiLexer;
    function Tok(const S: string): TList<TToken>;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // --- Float literals ---
    [Test] procedure Float_SimpleDecimal_IsSingleToken;
    [Test] procedure Float_WithExponent_IsSingleToken;
    [Test] procedure Float_WithNegativeExponent_IsSingleToken;
    [Test] procedure Float_WithPositiveExponent_IsSingleToken;
    [Test] procedure Float_ExponentWithoutDecimalPoint_IsSingleToken;
    [Test] procedure Float_UpperCaseExponent_IsSingleToken;
    [Test] procedure Integer_RangeOperator_NotCorruptedByFloatRule;
    [Test] procedure Integer_Simple_RegressionCheck;
    [Test] procedure Float_IncompleteExponent_BacktracksE;
    [Test] procedure Float_IncompleteExponentWithSign_BacktracksE;

    // --- Octal literals ---
    [Test] procedure Octal_WithLeadingZero_IsSingleToken;
    [Test] procedure Octal_BasicDigits_IsSingleToken;
    [Test] procedure Octal_SingleDigit_IsSingleToken;
    [Test] procedure Octal_DoesNotConsumeEscapedIdentifier;

    // --- Digit separators in hex and binary ---
    [Test] procedure Hex_WithDigitSeparator_IsSingleToken;
    [Test] procedure Hex_MultipleUnderscores_IsSingleToken;
    [Test] procedure Binary_WithDigitSeparator_IsSingleToken;
    [Test] procedure Hex_Plain_Regression;
    [Test] procedure Binary_Plain_Regression;

    // --- Digit separators in decimal ---
    [Test] procedure Decimal_IntegerPart_WithDigitSeparator_IsSingleToken;
    [Test] procedure Decimal_FractionalPart_WithDigitSeparator_IsSingleToken;
    [Test] procedure Decimal_ExponentPart_WithDigitSeparator_IsSingleToken;
  end;

implementation


procedure TNumericLiteralTests.Setup;
begin
  FLexer := TDelphiLexer.Create;
end;


procedure TNumericLiteralTests.TearDown;
begin
  FLexer.Free;
end;


function TNumericLiteralTests.Tok(const S: string): TList<TToken>;
begin
  Result := FLexer.Tokenize(S);
end;


// --- Float literals ---

procedure TNumericLiteralTests.Float_SimpleDecimal_IsSingleToken;
var
  T: TList<TToken>;
begin
  T := Tok('3.14');
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count'); // tkNumber + tkEOF
    Assert.AreEqual(Ord(tkNumber), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('3.14', T[0].Text, 'text');
  finally
    T.Free;
  end;
end;


procedure TNumericLiteralTests.Float_WithExponent_IsSingleToken;
var
  T: TList<TToken>;
begin
  T := Tok('1.5e10');
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count');
    Assert.AreEqual(Ord(tkNumber), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('1.5e10', T[0].Text, 'text');
  finally
    T.Free;
  end;
end;


procedure TNumericLiteralTests.Float_WithNegativeExponent_IsSingleToken;
var
  T: TList<TToken>;
begin
  T := Tok('1.5e-10');
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count');
    Assert.AreEqual(Ord(tkNumber), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('1.5e-10', T[0].Text, 'text');
  finally
    T.Free;
  end;
end;


procedure TNumericLiteralTests.Float_WithPositiveExponent_IsSingleToken;
var
  T: TList<TToken>;
begin
  T := Tok('2.0e+3');
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count');
    Assert.AreEqual(Ord(tkNumber), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('2.0e+3', T[0].Text, 'text');
  finally
    T.Free;
  end;
end;


procedure TNumericLiteralTests.Float_ExponentWithoutDecimalPoint_IsSingleToken;
var
  T: TList<TToken>;
begin
  // '1e6' is a valid Delphi float: integer part + exponent, no fraction.
  T := Tok('1e6');
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count');
    Assert.AreEqual(Ord(tkNumber), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('1e6', T[0].Text, 'text');
  finally
    T.Free;
  end;
end;


procedure TNumericLiteralTests.Float_UpperCaseExponent_IsSingleToken;
var
  T: TList<TToken>;
begin
  T := Tok('9.99E2');
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count');
    Assert.AreEqual(Ord(tkNumber), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('9.99E2', T[0].Text, 'text');
  finally
    T.Free;
  end;
end;


procedure TNumericLiteralTests.Integer_RangeOperator_NotCorruptedByFloatRule;
var
  T: TList<TToken>;
begin
  // '1..9' must not be read as float '1.' -- the '..' guard must fire.
  // Expected: tkNumber('1') tkSymbol('..') tkNumber('9') tkEOF
  T := Tok('1..9');
  try
    Assert.AreEqual(NativeInt(4), T.Count, 'count');
    Assert.AreEqual(Ord(tkNumber), Ord(T[0].Kind), 'first kind');
    Assert.AreEqual('1', T[0].Text, 'first text');
    Assert.AreEqual(Ord(tkSymbol), Ord(T[1].Kind), 'dot-dot kind');
    Assert.AreEqual('..', T[1].Text, 'dot-dot text');
    Assert.AreEqual(Ord(tkNumber), Ord(T[2].Kind), 'last kind');
    Assert.AreEqual('9', T[2].Text, 'last text');
  finally
    T.Free;
  end;
end;


procedure TNumericLiteralTests.Integer_Simple_RegressionCheck;
var
  T: TList<TToken>;
begin
  T := Tok('42');
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count');
    Assert.AreEqual(Ord(tkNumber), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('42', T[0].Text, 'text');
  finally
    T.Free;
  end;
end;


procedure TNumericLiteralTests.Float_IncompleteExponent_BacktracksE;
var
  T: TList<TToken>;
begin
  // '1e' has no exponent digits, so the lexer backtracks before 'e'.
  // Expected: tkNumber('1'), tkIdentifier('e'), tkEOF
  T := Tok('1e');
  try
    Assert.AreEqual(NativeInt(3), T.Count, 'count');
    Assert.AreEqual(Ord(tkNumber),     Ord(T[0].Kind), '[0] kind');
    Assert.AreEqual('1',               T[0].Text,      '[0] text');
    Assert.AreEqual(Ord(tkIdentifier), Ord(T[1].Kind), '[1] kind');
    Assert.AreEqual('e',               T[1].Text,      '[1] text');
  finally
    T.Free;
  end;
end;


procedure TNumericLiteralTests.Float_IncompleteExponentWithSign_BacktracksE;
var
  T: TList<TToken>;
begin
  // '1e+' has sign but no exponent digits; backtrack past 'e'.
  // Expected: tkNumber('1'), tkIdentifier('e'), tkSymbol('+'), tkEOF
  T := Tok('1e+');
  try
    Assert.AreEqual(NativeInt(4), T.Count, 'count');
    Assert.AreEqual(Ord(tkNumber),     Ord(T[0].Kind), '[0] kind');
    Assert.AreEqual('1',               T[0].Text,      '[0] text');
    Assert.AreEqual(Ord(tkIdentifier), Ord(T[1].Kind), '[1] kind');
    Assert.AreEqual('e',               T[1].Text,      '[1] text');
    Assert.AreEqual(Ord(tkSymbol),     Ord(T[2].Kind), '[2] kind');
    Assert.AreEqual('+',               T[2].Text,      '[2] text');
  finally
    T.Free;
  end;
end;


// --- Octal literals ---

procedure TNumericLiteralTests.Octal_WithLeadingZero_IsSingleToken;
var
  T: TList<TToken>;
begin
  T := Tok('&0377');
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count');
    Assert.AreEqual(Ord(tkNumber), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('&0377', T[0].Text, 'text');
  finally
    T.Free;
  end;
end;


procedure TNumericLiteralTests.Octal_BasicDigits_IsSingleToken;
var
  T: TList<TToken>;
begin
  T := Tok('&377');
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count');
    Assert.AreEqual(Ord(tkNumber), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('&377', T[0].Text, 'text');
  finally
    T.Free;
  end;
end;


procedure TNumericLiteralTests.Octal_SingleDigit_IsSingleToken;
var
  T: TList<TToken>;
begin
  T := Tok('&7');
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count');
    Assert.AreEqual(Ord(tkNumber), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('&7', T[0].Text, 'text');
  finally
    T.Free;
  end;
end;


procedure TNumericLiteralTests.Octal_DoesNotConsumeEscapedIdentifier;
var
  T: TList<TToken>;
begin
  // &begin: first char after & is a letter, so this is an escaped identifier,
  // not an octal literal.
  T := Tok('&begin');
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count');
    Assert.AreEqual(Ord(tkIdentifier), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('&begin', T[0].Text, 'text');
  finally
    T.Free;
  end;
end;


// --- Digit separators in hex and binary ---

procedure TNumericLiteralTests.Hex_WithDigitSeparator_IsSingleToken;
var
  T: TList<TToken>;
begin
  T := Tok('$FF_FF');
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count');
    Assert.AreEqual(Ord(tkNumber), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('$FF_FF', T[0].Text, 'text');
  finally
    T.Free;
  end;
end;


procedure TNumericLiteralTests.Hex_MultipleUnderscores_IsSingleToken;
var
  T: TList<TToken>;
begin
  T := Tok('$FF_FF_FF');
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count');
    Assert.AreEqual(Ord(tkNumber), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('$FF_FF_FF', T[0].Text, 'text');
  finally
    T.Free;
  end;
end;


procedure TNumericLiteralTests.Binary_WithDigitSeparator_IsSingleToken;
var
  T: TList<TToken>;
begin
  T := Tok('%101_0___0101');
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count');
    Assert.AreEqual(Ord(tkNumber), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('%101_0___0101', T[0].Text, 'text');
  finally
    T.Free;
  end;
end;


procedure TNumericLiteralTests.Hex_Plain_Regression;
var
  T: TList<TToken>;
begin
  T := Tok('$DEADBEEF');
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count');
    Assert.AreEqual(Ord(tkNumber), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('$DEADBEEF', T[0].Text, 'text');
  finally
    T.Free;
  end;
end;


procedure TNumericLiteralTests.Binary_Plain_Regression;
var
  T: TList<TToken>;
begin
  T := Tok('%10110011');
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count');
    Assert.AreEqual(Ord(tkNumber), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('%10110011', T[0].Text, 'text');
  finally
    T.Free;
  end;
end;


// --- Digit separators in decimal ---

procedure TNumericLiteralTests.Decimal_IntegerPart_WithDigitSeparator_IsSingleToken;
var
  T: TList<TToken>;
begin
  T := Tok('1__000___000');
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count');
    Assert.AreEqual(Ord(tkNumber), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('1__000___000', T[0].Text, 'text');
  finally
    T.Free;
  end;
end;


procedure TNumericLiteralTests.Decimal_FractionalPart_WithDigitSeparator_IsSingleToken;
var
  T: TList<TToken>;
begin
  T := Tok('3.14___15__');
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count');
    Assert.AreEqual(Ord(tkNumber), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('3.14___15__', T[0].Text, 'text');
  finally
    T.Free;
  end;
end;


procedure TNumericLiteralTests.Decimal_ExponentPart_WithDigitSeparator_IsSingleToken;
var
  T: TList<TToken>;
begin
  T := Tok('1e1_0');
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count');
    Assert.AreEqual(Ord(tkNumber), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('1e1_0', T[0].Text, 'text');
  finally
    T.Free;
  end;
end;


initialization

TDUnitX.RegisterTestFixture(TNumericLiteralTests);

end.
