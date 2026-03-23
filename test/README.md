# Tests

DUnitX test project: `/tests/DelphiLexer.Tests.dproj`


| Fixture | Coverage |
|---|---|
| `Core` | Basic token kinds, round-trip on trivial input |
| `Keywords` | All 67 reserved words; escaped identifiers; contextual keywords |
| `NumericLiterals` | Float, exponent backtracking, octal, hex/binary digit separators, decimal separators |
| `TokenMetadata` | StartOffset and Length for all token kinds |
| `TokenPosition` | Line and Col after EOL sequences including bare CR |
| `Directive` | `{$...}` and `(*$..*)` directives vs. comments |
| `MultiLineStrings` | 3-quote, 5-quote, 7-quote delimiters; edge cases; round-trip |
| `MultiSegmentStrings` | Concatenated string segments |
| `QualifiedIdentifiers` | `Unit.Type.Member` dot chains |
| `InvalidTokens` | tkInvalid for all bare prefixes, stray chars, malformed base literals, unterminated constructs |
| `Symbols` | Multi-char operators emitted as single tokens; single-char symbols unaffected |
| `Golden` | Round-trip + StartOffset chain on 6 representative .pas files |
