unit Test.DelphiLexer.Directive;

// Tests that compiler directives ({$...} and (*$...*)) are classified as
// tkDirective, and that ordinary comments remain tkComment.

interface

uses
  DUnitX.TestFramework,
  System.Generics.Collections,
  DelphiLexer.Token,
  DelphiLexer.Lexer;

type

  [TestFixture]
  TDirectiveTests = class
  private
    FLexer: TDelphiLexer;
    function Tok(const S: string): TList<TToken>;
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
  end;

implementation


procedure TDirectiveTests.Setup;
begin
  FLexer := TDelphiLexer.Create;
end;


procedure TDirectiveTests.TearDown;
begin
  FLexer.Free;
end;


function TDirectiveTests.Tok(const S: string): TList<TToken>;
begin
  Result := FLexer.Tokenize(S);
end;


// --- Correct kind emitted ---

procedure TDirectiveTests.BraceDirective_EmitsKind_tkDirective;
var
  T: TList<TToken>;
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
  T: TList<TToken>;
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
  T: TList<TToken>;
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
  T: TList<TToken>;
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
  T: TList<TToken>;
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
  T: TList<TToken>;
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
  T: TList<TToken>;
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
  T: TList<TToken>;
begin
  T := Tok(Input);
  try
    Assert.AreEqual(Input, T[0].Text, 'text');
  finally
    T.Free;
  end;
end;


initialization

TDUnitX.RegisterTestFixture(TDirectiveTests);

end.
