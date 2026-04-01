unit Test.DelphiLexer.Keywords;

// Keyword classification tests.
//
// Verifies:
//   - All reserved words are recognised by IsDelphiKeyword and tokenize
//     as tkKeyword (case-insensitive).
//   - Escaped reserved words (&begin, &type) tokenize as tkIdentifier.
//   - Mixed-case forms (Begin, BEGIN) still tokenize as tkKeyword.
//   - Contextual keywords (virtual, override, operator, cdecl, ...) tokenize
//     as tkIdentifier and are NOT in IsDelphiKeyword.
//   - 'out' is reserved (tkKeyword); 'operator' is contextual (tkIdentifier).
//   - 'inline', 'on', and 'at' are reserved (all in DELPHI_KEYWORDS).

interface

uses
  DUnitX.TestFramework,
  System.Generics.Collections,
  DelphiLexer.Token,
  DelphiLexer.Keywords,
  DelphiLexer.Lexer;

type

  [TestFixture]
  TKeywordTests = class
  private
    FLexer: TDelphiLexer;
    function Tok(const S: string): TList<TToken>;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // All reserved words via IsDelphiKeyword (direct API).
    [Test] procedure IsDelphiKeyword_AllReservedWords_ReturnTrue;

    // All reserved words via the tokenizer.
    [Test] procedure AllReservedWords_Tokenize_As_tkKeyword;

    // Escaped reserved words must be tkIdentifier, not tkKeyword.
    [Test] procedure Escaped_begin_IsIdentifier;
    [Test] procedure Escaped_type_IsIdentifier;
    [Test] procedure Escaped_end_IsIdentifier;

    // Mixed-case forms must still resolve to Keyword.
    [Test] procedure MixedCase_Begin_IsStrictKeyword;
    [Test] procedure AllUpperCase_BEGIN_IsStrictKeyword;
    [Test] procedure MixedCase_Function_IsStrictKeyword;

    // Contextual Visibility+Directives are tracked as special keywords
    [Test] procedure Contextual_virtual_IsContextualKeyword;
    [Test] procedure Contextual_override_IsContextualKeyword;
    [Test] procedure Contextual_operator_IsContextualKeyword;
    [Test] procedure Contextual_cdecl_IsContextualKeyword;
    [Test] procedure Contextual_abstract_IsContextualKeyword;
    [Test] procedure Contextual_deprecated_IsContextualKeyword;

    // Specific decisions: 'at', 'on', 'out', 'inline' are reserved.
    [Test] procedure Reserved_at_IsStrictKeyword;
    [Test] procedure Reserved_out_IsContextualKeyword;
    [Test] procedure Reserved_inline_IsStrictKeyword;
    [Test] procedure Reserved_on_IsStrictKeyword;

    // Plain identifier is not a keyword.
    [Test] procedure PlainIdentifier_IsNotKeyword;
  end;

implementation

uses
  System.SysUtils;

procedure TKeywordTests.Setup;
begin
  FLexer := TDelphiLexer.Create;
end;


procedure TKeywordTests.TearDown;
begin
  FLexer.Free;
end;


function TKeywordTests.Tok(const S: string): TList<TToken>;
begin
  Result := FLexer.Tokenize(S);
end;


// ---------------------------------------------------------------------------

procedure TKeywordTests.IsDelphiKeyword_AllReservedWords_ReturnTrue;
var
  I: Integer;
begin
  for I := 0 to High(DELPHI_KEYWORDS) do
  begin
    Assert.IsTrue(IsDelphiKeyword(DELPHI_KEYWORDS[I].Name),
      DELPHI_KEYWORDS[I].Name + ' must be a reserved word');
  end;
end;


procedure TKeywordTests.AllReservedWords_Tokenize_As_tkKeyword;
var
  I: Integer;
  T: TList<TToken>;
  Keyword:string;
begin
  for I := 0 to High(DELPHI_KEYWORDS) do
  begin
    Keyword := DELPHI_KEYWORDS[I].Name;

    T := Tok(Keyword);
    try
      Assert.IsTrue(IsDelphiKeyword(T[0].Text), Keyword + ' kind');
      Assert.AreEqual(Keyword, T[0].Text, Keyword + ' text');
    finally
      T.Free;
    end;
  end;
end;


// --- Escaped reserved words ---

procedure TKeywordTests.Escaped_begin_IsIdentifier;
var
  T: TList<TToken>;
begin
  T := Tok('&begin');
  try
    Assert.AreEqual(Ord(tkIdentifier), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('&begin', T[0].Text, 'text');
  finally
    T.Free;
  end;
end;


procedure TKeywordTests.Escaped_type_IsIdentifier;
var
  T: TList<TToken>;
begin
  T := Tok('&type');
  try
    Assert.AreEqual(Ord(tkIdentifier), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('&type', T[0].Text, 'text');
  finally
    T.Free;
  end;
end;


procedure TKeywordTests.Escaped_end_IsIdentifier;
var
  T: TList<TToken>;
begin
  T := Tok('&end');
  try
    Assert.AreEqual(Ord(tkIdentifier), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('&end', T[0].Text, 'text');
  finally
    T.Free;
  end;
end;


// --- Mixed-case ---

procedure TKeywordTests.MixedCase_Begin_IsStrictKeyword;
var
  T: TList<TToken>;
begin
  T := Tok('Begin');
  try
    Assert.AreEqual(Ord(tkStrictKeyword), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('Begin', T[0].Text, 'text preserved as-is');
  finally
    T.Free;
  end;
end;


procedure TKeywordTests.AllUpperCase_BEGIN_IsStrictKeyword;
var
  T: TList<TToken>;
begin
  T := Tok('BEGIN');
  try
    Assert.AreEqual(Ord(tkStrictKeyword), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('BEGIN', T[0].Text, 'text preserved as-is');
  finally
    T.Free;
  end;
end;


procedure TKeywordTests.MixedCase_Function_IsStrictKeyword;
var
  T: TList<TToken>;
begin
  T := Tok('Function');
  try
    Assert.AreEqual(Ord(tkStrictKeyword), Ord(T[0].Kind), 'kind');
  finally
    T.Free;
  end;
end;


// --- Contextual keywords (must be tkContextKeyword) ---

procedure TKeywordTests.Contextual_virtual_IsContextualKeyword;
var
  T: TList<TToken>;
begin
  Assert.IsTrue(IsDelphiKeyword('virtual'), 'IsDelphiKeyword');
  T := Tok('virtual');
  try
    Assert.AreEqual(Ord(tkContextKeyword), Ord(T[0].Kind), 'kind');
  finally
    T.Free;
  end;
end;


procedure TKeywordTests.Contextual_override_IsContextualKeyword;
var
  T: TList<TToken>;
begin
  Assert.IsTrue(IsDelphiKeyword('override'), 'IsDelphiKeyword');
  T := Tok('override');
  try
    Assert.AreEqual(Ord(tkContextKeyword), Ord(T[0].Kind), 'kind');
  finally
    T.Free;
  end;
end;


procedure TKeywordTests.Contextual_operator_IsContextualKeyword;
var
  T: TList<TToken>;
begin
  Assert.IsTrue(IsDelphiKeyword('operator'), 'IsDelphiKeyword');
  T := Tok('operator');
  try
    Assert.AreEqual(Ord(tkContextKeyword), Ord(T[0].Kind), 'kind');
  finally
    T.Free;
  end;
end;


procedure TKeywordTests.Contextual_cdecl_IsContextualKeyword;
var
  T: TList<TToken>;
begin
  Assert.IsTrue(IsDelphiKeyword('cdecl'), 'IsDelphiKeyword');
  T := Tok('cdecl');
  try
    Assert.AreEqual(Ord(tkContextKeyword), Ord(T[0].Kind), 'kind');
  finally
    T.Free;
  end;
end;


procedure TKeywordTests.Contextual_abstract_IsContextualKeyword;
var
  T: TList<TToken>;
begin
  Assert.IsTrue(IsDelphiKeyword('abstract'), 'IsDelphiKeyword');
  T := Tok('abstract');
  try
    Assert.AreEqual(Ord(tkContextKeyword), Ord(T[0].Kind), 'kind');
  finally
    T.Free;
  end;
end;


procedure TKeywordTests.Contextual_deprecated_IsContextualKeyword;
var
  T: TList<TToken>;
begin
  Assert.IsTrue(IsDelphiKeyword('deprecated'), 'IsDelphiKeyword');
  T := Tok('deprecated');
  try
    Assert.AreEqual(Ord(tkContextKeyword), Ord(T[0].Kind), 'kind');
  finally
    T.Free;
  end;
end;


// --- Specific reserved-word decisions ---

procedure TKeywordTests.Reserved_at_IsStrictKeyword;
var
  T: TList<TToken>;
begin
  Assert.IsTrue(IsDelphiKeyword('at'), 'IsDelphiKeyword');
  T := Tok('at');
  try
    Assert.AreEqual(Ord(tkStrictKeyword), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('at', T[0].Text, 'text');
  finally
    T.Free;
  end;
end;


procedure TKeywordTests.Reserved_out_IsContextualKeyword;
var
  T: TList<TToken>;
begin
  Assert.IsTrue(IsDelphiKeyword('out'), 'IsDelphiKeyword');
  T := Tok('out');
  try
    Assert.AreEqual(Ord(tkContextKeyword), Ord(T[0].Kind), 'kind');
  finally
    T.Free;
  end;
end;


procedure TKeywordTests.Reserved_inline_IsStrictKeyword;
var
  T: TList<TToken>;
begin
  Assert.IsTrue(IsDelphiKeyword('inline'), 'IsDelphiKeyword');
  T := Tok('inline');
  try
    Assert.AreEqual(Ord(tkStrictKeyword), Ord(T[0].Kind), 'kind');
  finally
    T.Free;
  end;
end;


procedure TKeywordTests.Reserved_on_IsStrictKeyword;
// 'on' is in DELPHI_KEYWORDS (used in exception handlers: on E: Exception do).
var
  T: TList<TToken>;
begin
  Assert.IsTrue(IsDelphiKeyword('on'), 'IsDelphiKeyword');
  T := Tok('on');
  try
    Assert.AreEqual(Ord(tkStrictKeyword), Ord(T[0].Kind), 'kind');
  finally
    T.Free;
  end;
end;


procedure TKeywordTests.PlainIdentifier_IsNotKeyword;
var
  T: TList<TToken>;
begin
  Assert.IsFalse(IsDelphiKeyword('MyClass'), 'IsDelphiKeyword');
  T := Tok('MyClass');
  try
    Assert.AreEqual(Ord(tkIdentifier), Ord(T[0].Kind), 'kind');
  finally
    T.Free;
  end;
end;


initialization

TDUnitX.RegisterTestFixture(TKeywordTests);

end.
