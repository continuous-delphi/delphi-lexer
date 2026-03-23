program DelphiLexer.TokenDump;

{$APPTYPE CONSOLE}


// Token dump utility for DelphiLexer.
//
// Usage:
//   DelphiLexer.TokenDump <file.pas>
//   DelphiLexer.TokenDump <file.pas> --encoding <name>
//   DelphiLexer.TokenDump <file.pas> --format <name>
//   DelphiLexer.TokenDump --help
//
// Options:
//   --encoding <name>   Source file encoding (default: utf-8)
//                       Supported: utf-8, utf-16, utf-16be, ansi, ascii, default
//   --format <name>     Output format (default: text)
//                       Supported: text, json
//
// Tokenizes a Delphi source file and writes the token stream to stdout.
//
// text format (default):
//   A line-per-token table followed by a one-line summary. Intended for
//   interactive debugging and exploring what TDelphiLexer produces.
//
//   Output columns:
//     Idx    -- 0-based token index
//     Kind   -- TTokenKind name (tkKeyword, tkSymbol, ...)
//     L:C    -- 1-based line:column of the token's first character
//     Offset -- 0-based character offset into the source string
//     Len    -- character count of the token (= System.Length(Token.Text))
//     Text   -- token text; control characters replaced with angle-bracket
//               tags (<CRLF>, <LF>, <CR>, <TAB>); truncated at 48 printable
//               characters with a trailing '...' if longer
//
//   The summary reports total token count, source length, count of tkInvalid
//   tokens (non-zero means malformed input), and a round-trip verification
//   (concatenating all texts must reproduce the source exactly).
//
// json format:
//   Pure JSON to stdout. Top-level keys: tool, formatVersion, sourceFile,
//   options, summary, tokens. Suitable for piping into jq or other tools.
//
// Example:
//   LexDump minimal.pas
//
//     Idx  Kind               L:C      Offset    Len  Text
//   -----  -----------------  -------  ------  -----  ----
//       0  tkKeyword            1:1         0      4  unit
//       1  tkWhitespace         1:5         4      1
//       2  tkIdentifier         1:6         5      7  Minimal
//       3  tkSymbol             1:13       12      1  ;
//       4  tkEOL                1:14       13      2  <CRLF>
//     ...
//   Tokens: 16  Source: 54 chars  Invalid: 0  Round-trip: OK


{$R *.res}

uses
  System.SysUtils,
  TokenDump in 'TokenDump.pas',
  DelphiLexer.Lexer in '..\..\source\DelphiLexer.Lexer.pas',
  DelphiLexer.Scanner in '..\..\source\DelphiLexer.Scanner.pas',
  DelphiLexer.Token in '..\..\source\DelphiLexer.Token.pas',
  DelphiLexer.Keywords in '..\..\source\DelphiLexer.Keywords.pas';

begin

  ExitCode := TTokenDumper.Run;

end.
