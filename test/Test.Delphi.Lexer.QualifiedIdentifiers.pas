unit Test.Delphi.Lexer.QualifiedIdentifiers;

// Verifies that qualified names (System.SysUtils.FreeAndNil, Foo.bar.Baz)
// are tokenized as separate identifier and '.' tokens, not merged.

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  Delphi.Token,
  Delphi.Lexer;

type

  [TestFixture]
  TQualifiedIdentifierTests = class
  private
    FLexer: TDelphiLexer;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test] procedure Dotted_Unit_Type_Member_Call_Tokens_Are_Segmented_By_Dots;
    [Test] procedure Dotted_Assignment_Tokens_Are_Segmented_By_Dots;
  end;


implementation

uses
  Delphi.TokenKind,
  Delphi.TokenList;


// Local helper: assert kind and text of a single token.
procedure AssertKindText(const Tok: TToken; ExpectedKind: TTokenKind; const ExpectedText: string);
begin
  Assert.AreEqual<Integer>(Ord(ExpectedKind), Ord(Tok.Kind), 'Unexpected token kind');
  Assert.AreEqual(ExpectedText, Tok.Text, False, 'Unexpected token text');
end;


procedure TQualifiedIdentifierTests.Setup;
begin
  FLexer := TDelphiLexer.Create;
end;


procedure TQualifiedIdentifierTests.TearDown;
begin
  FLexer.Free;
end;


procedure TQualifiedIdentifierTests.Dotted_Unit_Type_Member_Call_Tokens_Are_Segmented_By_Dots;
const
  Src = 'System.SysUtils.FreeAndNil(Self);';
var
  T: TTokenList;
  I: Integer;
begin
  T := FLexer.Tokenize(Src);
  try
    // Expected sequence (trailing tkEOF ignored):
    // identifier 'System' '.' identifier 'SysUtils' '.'
    // identifier 'FreeAndNil' '(' identifier 'Self' ')' ';'
    I := 0;
    AssertKindText(T[I], tkIdentifier, 'System');     Inc(I);
    AssertKindText(T[I], tkSymbol,     '.');           Inc(I);
    AssertKindText(T[I], tkIdentifier, 'SysUtils');   Inc(I);
    AssertKindText(T[I], tkSymbol,     '.');           Inc(I);
    AssertKindText(T[I], tkIdentifier, 'FreeAndNil'); Inc(I);
    AssertKindText(T[I], tkSymbol,     '(');           Inc(I);
    AssertKindText(T[I], tkIdentifier, 'Self');        Inc(I);
    AssertKindText(T[I], tkSymbol,     ')');           Inc(I);
    AssertKindText(T[I], tkSymbol,     ';');
  finally
    T.Free;
  end;
end;


procedure TQualifiedIdentifierTests.Dotted_Assignment_Tokens_Are_Segmented_By_Dots;
const
  Src = 'Foo.bar.Baz := 42;';
var
  T: TTokenList;
  I: Integer;
begin
  T := FLexer.Tokenize(Src);
  try
    // Expected: identifier 'Foo' '.' identifier 'bar' '.' identifier 'Baz'
    //           ' ' ':=' ' ' number '42' ';'
    I := 0;
    AssertKindText(T[I], tkIdentifier, 'Foo');  Inc(I);
    AssertKindText(T[I], tkSymbol,     '.');     Inc(I);
    AssertKindText(T[I], tkIdentifier, 'bar');  Inc(I);
    AssertKindText(T[I], tkSymbol,     '.');     Inc(I);
    AssertKindText(T[I], tkIdentifier, 'Baz');  Inc(I);
    AssertKindText(T[I], tkWhitespace, ' ');    Inc(I);
    AssertKindText(T[I], tkSymbol,     ':=');   Inc(I);
    AssertKindText(T[I], tkWhitespace, ' ');    Inc(I);
    AssertKindText(T[I], tkNumber,     '42');   Inc(I);
    AssertKindText(T[I], tkSymbol,     ';');
  finally
    T.Free;
  end;
end;


initialization

TDUnitX.RegisterTestFixture(TQualifiedIdentifierTests);

end.
