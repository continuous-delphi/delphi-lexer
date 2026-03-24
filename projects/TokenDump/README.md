# DelphiLexer.TokenDump

A command-line utility for inspecting the token stream produced by `delphi-lexer`,
providing a lossless, position-accurate view of the source.

![delphi-lexer logo](../../assets/delphi-lexer-480x270.png)

[https://github.com/continuous-delphi/delphi-lexer/](https://github.com/continuous-delphi/delphi-lexer/)

## When to use this tool

`DelphiLexer.TokenDump` is useful for:

- debugging unexpected tokenization behavior
- validating edge cases (strings, directives, numeric literals)
- verifying round-trip fidelity during development
- generating baseline outputs for regression tests
- inspecting token metadata during parser development
- identifying invalid tokens

This utility is part of the `delphi-lexer` repository and is not distributed as a standalone project.

## Usage

```text
DelphiLexer.TokenDump <file.pas> [options]

Options:
  --encoding <name>   Source file encoding (default: utf-8)
                      Supported: utf-8, utf-16, utf-16be, ansi, ascii, default

  --format <name>     Output format (default: text)
                      Supported: text, json

```

## Example Command

`DelphiLexer.TokenDump.exe test\golden\minimal.pas`

```text
DelphiLexer.TokenDump
formatVersion: 1.0.0

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

Tokens: 16; Source: 54 chars; Invalid: 0; Round-trip: OK
```

## Format 'text' output (default)

- The output is deterministic and stable across runs for identical input,
  making it suitable for regression testing and snapshot comparison.

- Outputs consist of a header followed by a line-per-token table and then a one-line summary.

```text
Header Lines:

  App Name (DelphiLexer.TokenDump)
  App Version
  Text Format Version

Token Table Columns:

  Idx    -- 0-based token index
  Kind   -- TTokenKind name (tkKeyword, tkSymbol, ...)
  L:C    -- 1-based line:column of the token's first character
  Offset -- 0-based character offset into the source string
  Len    -- character count of the token (= System.Length(Token.Text))
  Text   -- token text; control characters replaced with angle-bracket
            tags (<CRLF>, <LF>, <CR>, <TAB>); truncated at 48 printable
            characters with a trailing '...' if longer

Summary line contains delimited values:

   - total token count
   - source character count
   - count of invalid tokens
   - round-trip verification result  (OK|FAIL)
```

## Format 'json' output

- When `--format json` is specified, the tool emits a machine-readable
representation of the token stream.

- The JSON format is versioned (`formatVersion`) and intended for use in
automated testing, CI pipelines, and tooling integrations.

Example (truncated):

```json
{
  "tool": "DelphiLexer.TokenDump",
  "formatVersion": "1.0.0",
  "sourceFile": "minimal.pas",
  "tokens": [
    {
      "index": 0,
      "kind": "tkKeyword",
      "text": "unit",
      "line": 1,
      "col": 1,
      "startOffset": 0,
      "length": 4
    }
  ],
  "summary": {
    "tokenCount": 16,
    "invalidCount": 0,
    "roundTripMatches": true
  }
}
```

All token fields directly reflect the underlying `TToken` structure produced by
`delphi-lexer`.

## Encoding

The input file is read using the specified encoding.

Notes:

- `utf-8` is the default
- BOM is respected where applicable
- `default` uses the system default ANSI code page
- no automatic encoding detection is performed

## Exit codes

- `0` – success
- `1` – error (invalid input, file not found, etc.)


## Round Trip Validation

Example code used to validate the tokenization process:

```pascal
  SB := TStringBuilder.Create(System.Length(ASource));
  try
    for I := 0 to Tokens.Count - 1 do
      SB.Append(Tokens[I].Text);
    RoundTripOK := (SB.ToString = ASource);
  finally
    SB.Free;
  end;
```

## Future

- Additional output control options may be added in future versions.

- Visit the [GitHub Issues list](https://github.com/continuous-delphi/delphi-lexer/issues) to view existing items.
You are encouraged to submit feature requests or bug reports.

- `delphi-lexer` will be used in the upcoming `delphi-parser` project

---

![continuous-delphi logo](../../assets/continuous-delphi-480x270.png)

Part of the [Continuous-Delphi](https://github.com/continuous-delphi) ecosystem including:

- `delphi-lexer` – core tokenizer
- `DelphiLexer.TokenDump` – token inspection
- `DelphiLexer.TokenStats` – token analysis
- `DelphiLexer.TokenCompare` – token comparison

