unit Test.DelphiLexer.Keywords;

// Keyword classification tests.
//
// Verifies:
//   - All 67 reserved words are recognised by IsDelphiKeyword and tokenize
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

    // All 67 reserved words via IsDelphiKeyword (direct API).
    [Test] procedure IsDelphiKeyword_AllReservedWords_ReturnTrue;

    // All 67 reserved words via the tokenizer.
    [Test] procedure AllReservedWords_Tokenize_As_tkKeyword;

    // Escaped reserved words must be tkIdentifier, not tkKeyword.
    [Test] procedure Escaped_begin_IsIdentifier;
    [Test] procedure Escaped_type_IsIdentifier;
    [Test] procedure Escaped_end_IsIdentifier;

    // Mixed-case forms must still resolve to tkKeyword.
    [Test] procedure MixedCase_Begin_IsKeyword;
    [Test] procedure AllUpperCase_BEGIN_IsKeyword;
    [Test] procedure MixedCase_Function_IsKeyword;

    // Contextual keywords must be tkIdentifier and not in IsDelphiKeyword.
    [Test] procedure Contextual_virtual_IsIdentifier;
    [Test] procedure Contextual_override_IsIdentifier;
    [Test] procedure Contextual_operator_IsIdentifier;
    [Test] procedure Contextual_cdecl_IsIdentifier;
    [Test] procedure Contextual_abstract_IsIdentifier;
    [Test] procedure Contextual_deprecated_IsIdentifier;

    // Specific decisions: 'at', 'on', 'out', 'inline' are reserved.
    [Test] procedure Reserved_at_IsKeyword;
    [Test] procedure Reserved_out_IsKeyword;
    [Test] procedure Reserved_inline_IsKeyword;
    [Test] procedure Reserved_on_IsKeyword;

    // Plain identifier is not a keyword.
    [Test] procedure PlainIdentifier_IsNotKeyword;
  end;

implementation

uses
  System.SysUtils;

// The full Delphi reserved-word list (must match DELPHI_KEYWORDS in
// DelphiLexer.Keywords exactly -- 67 entries, sorted ascending).
const
  ALL_KEYWORDS: array[0..66] of string = (
    'and', 'array', 'as', 'asm', 'at',
    'begin',
    'case', 'class', 'const', 'constructor',
    'destructor', 'dispinterface', 'div', 'do', 'downto',
    'else', 'end', 'except', 'exports',
    'file', 'finalization', 'finally', 'for', 'function',
    'goto',
    'if', 'implementation', 'in', 'inherited', 'initialization', 'inline',
    'interface', 'is',
    'label', 'library',
    'mod',
    'nil', 'not',
    'object', 'of', 'on', 'or', 'out',
    'packed', 'procedure', 'program', 'property',
    'raise', 'record', 'repeat', 'resourcestring',
    'set', 'shl', 'shr', 'string',
    'then', 'threadvar', 'to', 'try', 'type',
    'unit', 'until', 'uses',
    'var',
    'while', 'with',
    'xor'
  );


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
  for I := 0 to High(ALL_KEYWORDS) do
    Assert.IsTrue(IsDelphiKeyword(ALL_KEYWORDS[I]),
      ALL_KEYWORDS[I] + ' must be a reserved word');
end;


procedure TKeywordTests.AllReservedWords_Tokenize_As_tkKeyword;
var
  I: Integer;
  T: TList<TToken>;
begin
  for I := 0 to High(ALL_KEYWORDS) do
  begin
    T := Tok(ALL_KEYWORDS[I]);
    try
      Assert.AreEqual(Ord(tkKeyword), Ord(T[0].Kind),
        ALL_KEYWORDS[I] + ' kind');
      Assert.AreEqual(ALL_KEYWORDS[I], T[0].Text,
        ALL_KEYWORDS[I] + ' text');
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

procedure TKeywordTests.MixedCase_Begin_IsKeyword;
var
  T: TList<TToken>;
begin
  T := Tok('Begin');
  try
    Assert.AreEqual(Ord(tkKeyword), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('Begin', T[0].Text, 'text preserved as-is');
  finally
    T.Free;
  end;
end;


procedure TKeywordTests.AllUpperCase_BEGIN_IsKeyword;
var
  T: TList<TToken>;
begin
  T := Tok('BEGIN');
  try
    Assert.AreEqual(Ord(tkKeyword), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('BEGIN', T[0].Text, 'text preserved as-is');
  finally
    T.Free;
  end;
end;


procedure TKeywordTests.MixedCase_Function_IsKeyword;
var
  T: TList<TToken>;
begin
  T := Tok('Function');
  try
    Assert.AreEqual(Ord(tkKeyword), Ord(T[0].Kind), 'kind');
  finally
    T.Free;
  end;
end;


// --- Contextual keywords (must be tkIdentifier) ---

procedure TKeywordTests.Contextual_virtual_IsIdentifier;
var
  T: TList<TToken>;
begin
  Assert.IsFalse(IsDelphiKeyword('virtual'), 'IsDelphiKeyword');
  T := Tok('virtual');
  try
    Assert.AreEqual(Ord(tkIdentifier), Ord(T[0].Kind), 'kind');
  finally
    T.Free;
  end;
end;


procedure TKeywordTests.Contextual_override_IsIdentifier;
var
  T: TList<TToken>;
begin
  Assert.IsFalse(IsDelphiKeyword('override'), 'IsDelphiKeyword');
  T := Tok('override');
  try
    Assert.AreEqual(Ord(tkIdentifier), Ord(T[0].Kind), 'kind');
  finally
    T.Free;
  end;
end;


procedure TKeywordTests.Contextual_operator_IsIdentifier;
var
  T: TList<TToken>;
begin
  Assert.IsFalse(IsDelphiKeyword('operator'), 'IsDelphiKeyword');
  T := Tok('operator');
  try
    Assert.AreEqual(Ord(tkIdentifier), Ord(T[0].Kind), 'kind');
  finally
    T.Free;
  end;
end;


procedure TKeywordTests.Contextual_cdecl_IsIdentifier;
var
  T: TList<TToken>;
begin
  Assert.IsFalse(IsDelphiKeyword('cdecl'), 'IsDelphiKeyword');
  T := Tok('cdecl');
  try
    Assert.AreEqual(Ord(tkIdentifier), Ord(T[0].Kind), 'kind');
  finally
    T.Free;
  end;
end;


procedure TKeywordTests.Contextual_abstract_IsIdentifier;
var
  T: TList<TToken>;
begin
  Assert.IsFalse(IsDelphiKeyword('abstract'), 'IsDelphiKeyword');
  T := Tok('abstract');
  try
    Assert.AreEqual(Ord(tkIdentifier), Ord(T[0].Kind), 'kind');
  finally
    T.Free;
  end;
end;


procedure TKeywordTests.Contextual_deprecated_IsIdentifier;
var
  T: TList<TToken>;
begin
  Assert.IsFalse(IsDelphiKeyword('deprecated'), 'IsDelphiKeyword');
  T := Tok('deprecated');
  try
    Assert.AreEqual(Ord(tkIdentifier), Ord(T[0].Kind), 'kind');
  finally
    T.Free;
  end;
end;


// --- Specific reserved-word decisions ---

procedure TKeywordTests.Reserved_at_IsKeyword;
var
  T: TList<TToken>;
begin
  Assert.IsTrue(IsDelphiKeyword('at'), 'IsDelphiKeyword');
  T := Tok('at');
  try
    Assert.AreEqual(Ord(tkKeyword), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('at', T[0].Text, 'text');
  finally
    T.Free;
  end;
end;


procedure TKeywordTests.Reserved_out_IsKeyword;
var
  T: TList<TToken>;
begin
  Assert.IsTrue(IsDelphiKeyword('out'), 'IsDelphiKeyword');
  T := Tok('out');
  try
    Assert.AreEqual(Ord(tkKeyword), Ord(T[0].Kind), 'kind');
  finally
    T.Free;
  end;
end;


procedure TKeywordTests.Reserved_inline_IsKeyword;
var
  T: TList<TToken>;
begin
  Assert.IsTrue(IsDelphiKeyword('inline'), 'IsDelphiKeyword');
  T := Tok('inline');
  try
    Assert.AreEqual(Ord(tkKeyword), Ord(T[0].Kind), 'kind');
  finally
    T.Free;
  end;
end;


procedure TKeywordTests.Reserved_on_IsKeyword;
// 'on' is in DELPHI_KEYWORDS (used in exception handlers: on E: Exception do).
var
  T: TList<TToken>;
begin
  Assert.IsTrue(IsDelphiKeyword('on'), 'IsDelphiKeyword');
  T := Tok('on');
  try
    Assert.AreEqual(Ord(tkKeyword), Ord(T[0].Kind), 'kind');
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
