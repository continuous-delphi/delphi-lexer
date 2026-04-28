unit Delphi.Token.Kind;

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
    tkBOM, // UTF-8 BOM (U+FEFF) at position 0; mid-file BOM is tkInvalid
    tkEOF, // end sentinel
    tkInvalid, // unrecognised character (e.g. stray NUL or illegal byte)
    tkInactiveCode // collapsed inactive conditional-compilation region (injected by delphi-conditional-processor; never produced by the lexer)
  );


(*

tkInactiveCode A region of source that exists but is inactive under current context
Characteristics:
  * contains full original source text
  * not parsed
  * preserved for round-trip
  * treated similarly to trivia by parser
  * produced by conditional processor
*)

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
    'tkBOM',
    'tkEOF',
    'tkInvalid',
    'tkInactiveCode'
    );


function TokenKindName(K:TTokenKind):string;

// Lexical trivia: tokens that do not participate in grammar structure
// but are preserved for round-trip fidelity (whitespace, comments,
// directives, inactive code, etc.)
function IsLexicalTrivia(Kind:TTokenKind):Boolean;

implementation


function TokenKindName(K:TTokenKind):string;
begin
  Result := TokenKindNames[K];
end;


function IsLexicalTrivia(Kind:TTokenKind):Boolean;
begin
  Result := Kind in [tkWhitespace, tkEOL, tkComment, tkDirective, tkBOM];
end;




end.
