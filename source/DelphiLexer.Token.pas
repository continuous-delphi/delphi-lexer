unit DelphiLexer.Token;

interface

type

  TTokenKind = (
    tkIdentifier,    // plain identifier
    tkKeyword,       // reserved word (binary-searched against keyword list)
    tkNumber,        // integer, hex ($), binary (%), octal (&digits), float
    tkString,        // 'single-quoted' or '''triple-quoted multiline'''
    tkCharLiteral,   // #nn or #$hex
    tkComment,       // { } (* *) //
    tkDirective,     // {$ } (*$ *)
    tkSymbol,        // operator or punctuation
    tkWhitespace,    // space/tab run
    tkEOL,           // CR, LF, or CRLF
    tkEOF,           // end sentinel
    tkInvalid        // unrecognised character (e.g. stray NUL or illegal byte)
  );


  TToken = record
    Kind:        TTokenKind;
    Text:        string;
    Line:        Integer;   // 1-based; set by lexer
    Col:         Integer;   // 1-based; set by lexer
    StartOffset: Integer;   // 0-based absolute character index into source; set by lexer
    Length:      Integer;   // character count of Text; set by lexer
  end;

implementation

end.
