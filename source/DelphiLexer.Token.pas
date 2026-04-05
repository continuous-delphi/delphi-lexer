unit DelphiLexer.Token;

interface

type

  //"tkKeyword" split to Strict & Contextual Keywords:
  // A language word that is globally reserved and cannot normally be used as an identifier.
  // vs one that has special meaning only in certain syntactic contexts, including visibility words and
  // directive-like words.

  TTokenKind = (
    tkIdentifier,    // plain identifier
    tkStrictKeyword, // HardKeyword: Reserved words
    tkContextKeyword, // SoftKeyword: Directive + visibility
    tkNumber,        // integer, hex ($), binary (%), octal (&digits), float
    tkString,        // 'single-quoted' or '''triple-quoted multiline'''
    tkCharLiteral,   // #nn or #$hex
    tkComment,       // { } (* *) //
    tkDirective,     // {$ } (*$ *)
    tkAsmBody,       // opaque payload of an asm...end block; not tokenised as assembly
    tkSymbol,        // operator or punctuation
    tkWhitespace,    // space/tab/vt/ff run
    tkEOL,           // CR, LF, or CRLF
    tkEOF,           // end sentinel
    tkInvalid,       // unrecognised character (e.g. stray NUL or illegal byte)
    tkInactiveCode   // collapsed inactive conditional-compilation region (injected by delphi-conditional-processor; never produced by the lexer)
  );


  // Inclusive range [FirstTokenIndex .. LastTokenIndex] into a TList<TToken>.
  // Identifies a contiguous run of trivia tokens owned by one semantic token.
  // Empty when FirstTokenIndex = -1 (use IsEmpty / Count helpers).
  TTriviaSpan = record
    FirstTokenIndex: Integer;
    LastTokenIndex:  Integer;
    function IsEmpty: Boolean;
    function Count: Integer;
  end;


  TToken = record
    Kind:           TTokenKind;
    Text:           string;    // Characters of this token, as they appear in the source
    Line:           Integer;   // 1-based line number of the first character
    Col:            Integer;   // 1-based column number of the first character
    StartOffset:    Integer;   // 0-based absolute character index into source
    Length:         Integer;   // character count of Text: equals `System.Length(Text)`
    LeadingTrivia:  TTriviaSpan;  // trivia tokens immediately before this token
    TrailingTrivia: TTriviaSpan;  // same-line trivia tokens after this token (incl. EOL)
  end;


const

  TokenKindNames: array[TTokenKind] of string = (
    'tkIdentifier',
    'tkStrictKeyword',
    'tkContextKeyword',
    'tkNumber',
    'tkString',
    'tkCharLiteral',
    'tkComment',
    'tkDirective',
    'tkAsmBody',
    'tkSymbol',
    'tkWhitespace',
    'tkEOL',
    'tkEOF',
    'tkInvalid',
    'tkInactiveCode'
  );

function TokenKindName(K: TTokenKind): string;

// Returns True if Kind is a trivia token: whitespace, EOL, comment, or directive.
// tkAsmBody is NOT trivia -- it is a semantic token whose text happens to be opaque.
// These are the token kinds that the grouping pass assigns as leading/trailing
// trivia on the surrounding semantic tokens.
function IsTrivia(Kind: TTokenKind): Boolean;

implementation


function TTriviaSpan.IsEmpty: Boolean;
begin
  Result := FirstTokenIndex = -1;
end;


function TTriviaSpan.Count: Integer;
begin
  if IsEmpty then
    Exit(0);
  Result := LastTokenIndex - FirstTokenIndex + 1;
end;


function IsTrivia(Kind: TTokenKind): Boolean;
begin
  Result := Kind in [tkWhitespace, tkEOL, tkComment, tkDirective, tkInactiveCode];
end;


function TokenKindName(K: TTokenKind): string;
begin
  Result := TokenKindNames[K];
end;


end.
