# DelphiLexer.TokenDump project

Utility project from `delphi-lexer`
[https://github.com/continuous-delphi/delphi-lexer/](https://github.com/continuous-delphi/delphi-lexer/)

Usage:

```text
DelphiLexer.TokenDump <file.pas> [--encoding <name>]

Options:
  --encoding <name>   Source file encoding (default: utf-8)
                      Supported: utf-8, utf-16, utf-16be, ansi, ascii, default

```

Outputs a token table to stdout, including:

- token kind
- line/column
- start offset and length
- safely escaped token text

Also reports:

- round-trip verification result
- count of `tkInvalid` tokens

Primarily intended for debugging, diagnostics, and regression analysis.

## Example

`DelphiLexer.TokenDump.exe test\golden\minimal.pas`

```
    Idx  Kind               L:C      Offset    Len  Text
  -----  -----------------  -------  ------  -----  ------------------------
      0  tkKeyword              1:1       0      4  unit
      1  tkWhitespace           1:5       4      1
      2  tkIdentifier           1:6       5      7  Minimal
      3  tkSymbol              1:13      12      1  ;
      4  tkEOL                 1:14      13      2  <CRLF>
      5  tkEOL                  2:1      15      2  <CRLF>
      6  tkKeyword              3:1      17      9  interface
      7  tkEOL                 3:10      26      2  <CRLF>
      8  tkEOL                  4:1      28      2  <CRLF>
      9  tkKeyword              5:1      30     14  implementation
     10  tkEOL                 5:15      44      2  <CRLF>
     11  tkEOL                  6:1      46      2  <CRLF>
     12  tkKeyword              7:1      48      3  end
     13  tkSymbol               7:4      51      1  .
     14  tkEOL                  7:5      52      2  <CRLF>
     15  tkEOF                  8:1      54      0

Tokens: 16  Source: 54 chars  Invalid: 0  Round-trip: OK
```
