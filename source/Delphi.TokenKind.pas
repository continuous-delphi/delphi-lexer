unit Delphi.TokenKind;

interface

type

  //"tkKeyword" split to Strict & Contextual Keywords:
  // A language word that is globally reserved and cannot normally be used as an identifier.
  // vs one that has special meaning only in certain syntactic contexts, including visibility words and
  // directive-like words.

  TTokenKind = (
    tkIdentifier, // plain identifier
    tkStrictKeyword, // HardKeyword: Reserved words
    tkContextKeyword, // SoftKeyword: Directive + visibility
    tkNumber, // integer, hex ($), binary (%), octal (&digits), float
    tkString, // 'single-quoted' or '''triple-quoted multiline'''
    tkCharLiteral, // #nn or #$hex
    tkComment, // { } (* *) //
    tkDirective, // {$ } (*$ *)
    tkAsmBody, // opaque payload of an asm...end block; not tokenised as assembly
    tkSymbol, // operator or punctuation
    tkWhitespace, // space/tab/vt/ff run
    tkEOL, // CR, LF, or CRLF
    tkEOF, // end sentinel
    tkInvalid, // unrecognised character (e.g. stray NUL or illegal byte)
    tkInactiveCode // collapsed inactive conditional-compilation region (injected by delphi-conditional-processor; never produced by the lexer)
  );


const

  TokenKindNames:array[TTokenKind] of string = (
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


function TokenKindName(K:TTokenKind):string;

// Returns True if Kind is a trivia token: whitespace, EOL, comment, or directive.
// tkAsmBody is NOT trivia -- it is a semantic token whose text happens to be opaque.
// These are the token kinds that the grouping pass assigns as leading/trailing
// trivia on the surrounding semantic tokens.
function IsTrivia(Kind:TTokenKind):Boolean;

implementation


function TokenKindName(K:TTokenKind):string;
begin
  Result := TokenKindNames[K];
end;


function IsTrivia(Kind:TTokenKind):Boolean;
begin
  Result := Kind in [tkWhitespace, tkEOL, tkComment, tkDirective, tkInactiveCode];
end;




end.
