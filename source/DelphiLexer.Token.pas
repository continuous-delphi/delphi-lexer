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
    Text:        string;    // Characters of this token, as they appear in the source
    Line:        Integer;   // 1-based line number of the first character
    Col:         Integer;   // 1-based column number of the first character
    StartOffset: Integer;   // 0-based absolute character index into source
    Length:      Integer;   // character count of Text: equals `System.Length(Text)`
  end;

implementation

end.
