unit Test.DelphiLexer.Symbols;

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
  System.Generics.Collections,
  DelphiLexer.Token,
  DelphiLexer.Lexer;

type

  [TestFixture]
  TSymbolTests = class
  private
    FLexer: TDelphiLexer;
    function Tok(const S: string): TList<TToken>;
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
  end;

implementation


procedure TSymbolTests.Setup;
begin
  FLexer := TDelphiLexer.Create;
end;


procedure TSymbolTests.TearDown;
begin
  FLexer.Free;
end;


function TSymbolTests.Tok(const S: string): TList<TToken>;
begin
  Result := FLexer.Tokenize(S);
end;


// ---------------------------------------------------------------------------
// Multi-char operators
// ---------------------------------------------------------------------------

procedure TSymbolTests.ColonEquals_IsSingleSymbol;
var
  T: TList<TToken>;
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
  T: TList<TToken>;
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
  T: TList<TToken>;
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
  T: TList<TToken>;
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
  T: TList<TToken>;
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
  T: TList<TToken>;
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
  T: TList<TToken>;
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
  T: TList<TToken>;
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
  T: TList<TToken>;
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
  T: TList<TToken>;
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
  T: TList<TToken>;
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


initialization

TDUnitX.RegisterTestFixture(TSymbolTests);

end.
