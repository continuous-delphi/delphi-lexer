unit Test.Delphi.Lexer.Directive;

// Tests that compiler directives ({$...} and (*$...*)) are classified as
// tkDirective, and that ordinary comments remain tkComment.

interface

uses
  DUnitX.TestFramework,
  Delphi.Token,
  Delphi.Token.List,
  Delphi.Lexer;

type

  [TestFixture]
  TDirectiveTests = class
  private
    FLexer: TDelphiLexer;
    function Tok(const S: string): TTokenList;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // Correct kind emitted
    [Test] procedure BraceDirective_EmitsKind_tkDirective;
    [Test] procedure BraceComment_EmitsKind_tkComment;
    [Test] procedure ParenStarDirective_EmitsKind_tkDirective;
    [Test] procedure ParenStarComment_EmitsKind_tkComment;
    [Test] procedure SlashSlashComment_EmitsKind_tkComment;
    [Test] procedure SlashSlash_WithDollarPrefix_IsNeverDirective;

    [Test] procedure BraceDirective;
    [Test] procedure ParenStarDirective;

    // Non-nesting: opposite-style delimiters inside a comment are literal text.
    [Test] procedure Brace_ContainingParenStar_IsSingleToken;
    [Test] procedure Brace_ContainingParenStarClose_IsSingleToken;
    [Test] procedure ParenStar_ContainingBraceOpen_IsSingleToken;
    [Test] procedure ParenStar_ContainingBraceClose_IsSingleToken;
    [Test] procedure Brace_ContainingFullParenStarComment_IsSingleToken;
    [Test] procedure ParenStar_ContainingFullBraceComment_IsSingleToken;
  end;


implementation

uses
  Delphi.Token.Kind;


procedure TDirectiveTests.Setup;
begin
  FLexer := TDelphiLexer.Create;
end;


procedure TDirectiveTests.TearDown;
begin
  FLexer.Free;
end;


function TDirectiveTests.Tok(const S: string): TTokenList;
begin
  Result := FLexer.Tokenize(S);
end;


// --- Correct kind emitted ---

procedure TDirectiveTests.BraceDirective_EmitsKind_tkDirective;
var
  T: TTokenList;
begin
  T := Tok('{$IFDEF DEBUG}');
  try
    Assert.AreEqual(Ord(tkDirective), Ord(T[0].Kind), 'kind');
  finally
    T.Free;
  end;
end;


procedure TDirectiveTests.BraceComment_EmitsKind_tkComment;
var
  T: TTokenList;
begin
  T := Tok('{ this is a comment }');
  try
    Assert.AreEqual(Ord(tkComment), Ord(T[0].Kind), 'kind');
  finally
    T.Free;
  end;
end;


procedure TDirectiveTests.ParenStarDirective_EmitsKind_tkDirective;
var
  T: TTokenList;
begin
  T := Tok('(*$R+*)');
  try
    Assert.AreEqual(Ord(tkDirective), Ord(T[0].Kind), 'kind');
  finally
    T.Free;
  end;
end;


procedure TDirectiveTests.ParenStarComment_EmitsKind_tkComment;
var
  T: TTokenList;
begin
  T := Tok('(* this is a comment *)');
  try
    Assert.AreEqual(Ord(tkComment), Ord(T[0].Kind), 'kind');
  finally
    T.Free;
  end;
end;


procedure TDirectiveTests.SlashSlashComment_EmitsKind_tkComment;
var
  T: TTokenList;
begin
  T := Tok('// line comment');
  try
    Assert.AreEqual(Ord(tkComment), Ord(T[0].Kind), 'kind');
  finally
    T.Free;
  end;
end;


procedure TDirectiveTests.SlashSlash_WithDollarPrefix_IsNeverDirective;
var
  T: TTokenList;
begin
  // '//' has no directive form: even a dollar-sign prefix must produce tkComment.
  T := Tok('//$IFDEF DEBUG');
  try
    Assert.AreEqual(Ord(tkComment), Ord(T[0].Kind), 'kind');
    Assert.IsFalse(Ord(T[0].Kind) = Ord(tkDirective), 'must not be tkDirective');
  finally
    T.Free;
  end;
end;


procedure TDirectiveTests.BraceDirective;
const
  Input = '{$IFDEF DEBUG}';
var
  T: TTokenList;
begin
  T := Tok(Input);
  try
    Assert.AreEqual(Input, T[0].Text, 'text');
  finally
    T.Free;
  end;
end;


procedure TDirectiveTests.ParenStarDirective;
const
  Input = '(*$R+*)';
var
  T: TTokenList;
begin
  T := Tok(Input);
  try
    Assert.AreEqual(Ord(tkDirective), Ord(T[0].Kind), 'kind');
    Assert.AreEqual(Input, T[0].Text, 'text');
  finally
    T.Free;
  end;
end;


// ---------------------------------------------------------------------------
// Non-nesting: opposite-style delimiters are literal text, not nested comments.
// Delphi comments do not nest. A { comment can contain (* and *) literally,
// and a (* comment can contain { and } literally.
// ---------------------------------------------------------------------------

procedure TDirectiveTests.Brace_ContainingParenStar_IsSingleToken;
var
  T: TTokenList;
begin
  // The (* inside the brace comment is literal text, not a nested opener.
  T := Tok('{ comment (* still brace }');
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count: comment + EOF');
    Assert.AreEqual(Ord(tkComment), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('{ comment (* still brace }', T[0].Text, 'text');
  finally
    T.Free;
  end;
end;


procedure TDirectiveTests.Brace_ContainingParenStarClose_IsSingleToken;
var
  T: TTokenList;
begin
  // A *) inside a brace comment is literal text; the brace closes at }.
  T := Tok('{ has a *) inside }');
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count: comment + EOF');
    Assert.AreEqual(Ord(tkComment), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('{ has a *) inside }', T[0].Text, 'text');
  finally
    T.Free;
  end;
end;


procedure TDirectiveTests.ParenStar_ContainingBraceOpen_IsSingleToken;
var
  T: TTokenList;
begin
  // A { inside a (* comment is literal text, not a nested opener.
  T := Tok('(* comment { still paren-star *)');
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count: comment + EOF');
    Assert.AreEqual(Ord(tkComment), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('(* comment { still paren-star *)', T[0].Text, 'text');
  finally
    T.Free;
  end;
end;


procedure TDirectiveTests.ParenStar_ContainingBraceClose_IsSingleToken;
var
  T: TTokenList;
begin
  // A } inside a (* comment is literal text; the comment closes at *).
  T := Tok('(* has a } inside *)');
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count: comment + EOF');
    Assert.AreEqual(Ord(tkComment), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('(* has a } inside *)', T[0].Text, 'text');
  finally
    T.Free;
  end;
end;


procedure TDirectiveTests.Brace_ContainingFullParenStarComment_IsSingleToken;
var
  T: TTokenList;
begin
  // A complete (* ... *) pair inside a { comment is just literal text.
  // The brace comment still closes at the first }.
  T := Tok('{ outer (* inner *) still outer }');
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count: comment + EOF');
    Assert.AreEqual(Ord(tkComment), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('{ outer (* inner *) still outer }', T[0].Text, 'text');
  finally
    T.Free;
  end;
end;


procedure TDirectiveTests.ParenStar_ContainingFullBraceComment_IsSingleToken;
var
  T: TTokenList;
begin
  // A complete { ... } pair inside a (* comment is just literal text.
  // The paren-star comment still closes at the first *).
  T := Tok('(* outer { inner } still outer *)');
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count: comment + EOF');
    Assert.AreEqual(Ord(tkComment), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('(* outer { inner } still outer *)', T[0].Text, 'text');
  finally
    T.Free;
  end;
end;


initialization

TDUnitX.RegisterTestFixture(TDirectiveTests);

end.
