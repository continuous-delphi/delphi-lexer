# Delphi.Lexer.TokenStats

A command-line utility for analyzing the token stream produced by `delphi-lexer`,
providing token-level statistics and metrics.

![delphi-lexer logo](../../assets/delphi-lexer-480x270.png)

[https://github.com/continuous-delphi/delphi-lexer/](https://github.com/continuous-delphi/delphi-lexer/)

## When to use this tool

`Delphi.Lexer.TokenStats` is useful for:

- analyzing token distribution within a source file or across a directory tree
- detecting unexpected changes in token counts during development
- identifying the presence and frequency of invalid tokens
- tracking keyword and symbol usage patterns
- establishing baseline metrics for regression testing
- comparing code characteristics across files or revisions
- supporting CI checks for lexer stability and output consistency

This utility is part of the `delphi-lexer` repository and is not distributed as a standalone project.

## Usage:

```text
Delphi.Lexer.TokenStats
Provides token-level statistics and metrics of Object Pascal source code
A command-line utility for delphi-lexer from Continuous-Delphi
https://github.com/continuous-delphi/delphi-lexer
MIT Licensed.  Copyright (C) 2026, Darian Miller
Version: 0.5.0

Delphi.Lexer.TokenStats.exe [file] [options]

[file]              - Delphi source file to tokenize
[-r], [--recursive] - Search subdirectories recursively
[--encoding:name]   - Source file encoding (utf-8, utf-16, utf-16be, ansi,
                      ascii, default), default: utf-8
[--format:name]     - Output format: text or json, default: text
[-?], [--help]      - Show this help and exit
[-v], [--version]   - Show tool version and exit
```

The `[file]` argument accepts:

- a single file: `myfile.pas`
- a wildcard specification: `*.pas` or `src\*.pas`
- a full path with wildcard: `C:\dev\src\*.pas`

When `--recursive` is specified, the search descends into all subdirectories
of the path component. For example, `myfile.pas --recursive` finds every file
named `myfile.pas` under the current directory.

## Example Commands:

### Single file

`Delphi.Lexer.TokenStats.exe test\golden\real_unit.pas`

```text
Delphi.Lexer.TokenStats
inputPath: test\golden\real_unit.pas
formatVersion: 1.2.0

PathSpec           : test\golden\real_unit.pas
Recursive          : False
Files              : 1
Tokens             : 204
Lines              : 36
Invalid            : 0
RoundTrip          : PASS

By Kind:
  tkIdentifier     : 39
  tkStrictKeyword  : 24
  tkContextKeyword : 1
  tkNumber         : 1
  tkString         : 0
  tkCharLiteral    : 0
  tkComment        : 3
  tkDirective      : 0
  tkAsmBody        : 0
  tkSymbol         : 47
  tkWhitespace     : 55
  tkEOL            : 33
  tkEOF            : 1
  tkInvalid        : 0

Top Strict Keywords:
  function         : 4
  end              : 3
  begin            : 2
  const            : 2
  array            : 1
  do               : 1
  else             : 1
  for              : 1
  if               : 1
  implementation   : 1

Top Contextual Keywords:
  deprecated       : 1

Top Symbols:
  ;                : 13
  :                : 9
  (                : 6
  )                : 6
  :=               : 5
  ,                : 2
  +                : 1
  .                : 1
  =                : 1
  >=               : 1

Exit Code: 0
```

### Wildcard (aggregate stats across multiple files)

`Delphi.Lexer.TokenStats.exe test\golden\*.pas`

```text
Delphi.Lexer.TokenStats
inputPath: test\golden\*.pas
formatVersion: 1.2.0

PathSpec           : test\golden\*.pas
Recursive          : False
Files              : 10
Tokens             : 1337
Lines              : 241
Invalid            : 0
RoundTrip          : PASS

By Kind:
  tkIdentifier     : 235
  tkStrictKeyword  : 148
  tkContextKeyword : 6
  tkNumber         : 12
  tkString         : 3
  tkCharLiteral    : 2
  tkComment        : 22
  tkDirective      : 2
  tkAsmBody        : 0
  tkSymbol         : 307
  tkWhitespace     : 369
  tkEOL            : 221
  tkEOF            : 10
  tkInvalid        : 0

Top Strict Keywords:
  function         : 24
  end              : 19
  begin            : 12
  const            : 12
  implementation   : 7
  interface        : 7
  unit             : 7
  array            : 6
  do               : 6
  else             : 6

Top Contextual Keywords:
  deprecated       : 6

Top Symbols:
  ;                : 80
  :                : 55
  (                : 37
  )                : 37
  :=               : 31
  ,                : 13
  +                : 7
  .                : 7
  =                : 7
  >=               : 7

Exit Code: 0
```

## Format 'text' output (default)

- The output is deterministic and stable across runs for identical input,
  making it suitable for regression testing and snapshot comparison.

- Outputs consist of a header followed by a summary section and grouped statistics.

- All counts are aggregated across all matched files.

```text
Header Lines:

  AppName       -- Delphi.Lexer.TokenStats
  inputPath     -- the file path or wildcard specification provided
  formatVersion -- {X.Y.Z}

Summary fields:

  PathSpec    -- file path or wildcard specification
  Recursive   -- whether subdirectory search was enabled
  Files       -- number of files matched and processed
  Tokens      -- total token count across all files
  Lines       -- estimated line count (sum of per-file max line numbers)
  Invalid     -- number of `tkInvalid` tokens detected
  RoundTrip   -- round-trip verification result (PASS|FAIL)

Statistics sections:

  By Kind       -- counts by `TTokenKind`
  Top Keywords  -- keyword frequency table (descending)
  Top Symbols   -- symbol frequency table (descending)
```

## Format 'json' output

- When `--format:json` is specified, the tool emits a machine-readable
representation of token statistics derived from the `delphi-lexer` token stream.

- The JSON format is intended for use in automated testing, CI pipelines,
and tooling integrations.

- Top-level keys: `toolName`, `inputPath`, `recursive`, `fileCount`,
  `formatVersion`, `options`, `summary`, `countsByKind`,
  `strictKeywordCounts`, `contextualKeywordCounts`, `symbolCounts`, `invalidTokens`.

- `strictKeywordCounts`, `contextualKeywordCounts`, and `symbolCounts` include
  all entries sorted by count in descending order.
  Entries with equal counts are sorted lexicographically.

- `invalidTokens` includes `file`, `text`, `line`, `col`, `startOffset`,
  and `length` for each `tkInvalid` token.

`Delphi.Lexer.TokenStats.exe test\golden\real_unit.pas --format:json`

```json
{
  "toolName": "Delphi.Lexer.TokenStats",
  "inputPath": "test\\golden\\real_unit.pas",
  "recursive": false,
  "fileCount": 1,
  "formatVersion": "1.2.0",
  "options": {
    "encoding": "65001 (UTF-8)"
  },
  "summary": {
    "totalTokens": 204,
    "totalTokensExcludingEOF": 203,
    "totalTokensExcludingTrivia": 115,
    "invalidTokenCount": 0,
    "eofTokenCount": 1,
    "roundTripMatches": true,
    "lineCountEstimate": 36,
    "exitCode": 0
  },
  "countsByKind": {
    "tkIdentifier": 39,
    "tkStrictKeyword": 24,
    "tkContextKeyword": 1,
    "tkNumber": 1,
    "tkString": 0,
    "tkCharLiteral": 0,
    "tkComment": 3,
    "tkDirective": 0,
    "tkAsmBody": 0,
    "tkSymbol": 47,
    "tkWhitespace": 55,
    "tkEOL": 33,
    "tkEOF": 1,
    "tkInvalid": 0
  },
  "strictKeywordCounts": [
    { "keyword": "function",       "count": 4 },
    { "keyword": "end",            "count": 3 },
    { "keyword": "begin",          "count": 2 },
    { "keyword": "const",          "count": 2 },
    { "keyword": "array",          "count": 1 },
    { "keyword": "do",             "count": 1 },
    { "keyword": "else",           "count": 1 },
    { "keyword": "for",            "count": 1 },
    { "keyword": "if",             "count": 1 },
    { "keyword": "implementation", "count": 1 },
    { "keyword": "interface",      "count": 1 },
    { "keyword": "of",             "count": 1 },
    { "keyword": "then",           "count": 1 },
    { "keyword": "to",             "count": 1 },
    { "keyword": "type",           "count": 1 },
    { "keyword": "unit",           "count": 1 },
    { "keyword": "var",            "count": 1 }
  ],
  "contextualKeywordCounts": [
    { "keyword": "deprecated", "count": 1 }
  ],
  "symbolCounts": [
    { "symbol": ";",  "count": 13 },
    { "symbol": ":",  "count": 9  },
    { "symbol": "(",  "count": 6  },
    { "symbol": ")",  "count": 6  },
    { "symbol": ":=", "count": 5  },
    { "symbol": ",",  "count": 2  },
    { "symbol": "+",  "count": 1  },
    { "symbol": ".",  "count": 1  },
    { "symbol": "=",  "count": 1  },
    { "symbol": ">=", "count": 1  },
    { "symbol": "[",  "count": 1  },
    { "symbol": "]",  "count": 1  }
  ],
  "invalidTokens": [
  ]
}
```

All token counts and summaries are derived directly from the `delphi-lexer` token stream
and aggregated across all matched files.

## Encoding

The input file is read using the specified encoding.

Notes:

- `utf-8` is the default
- BOM is respected where applicable
- `default` uses the system default ANSI code page
- no automatic encoding detection is performed
- all files in a wildcard expansion are read with the same encoding

## Exit codes

- `0` -- success
- `1` -- error (invalid input, file not found, no files matched, etc.)
- `2` -- one or more `tkInvalid` tokens were detected
- `3` -- round-trip verification failed for one or more files


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

Round-trip validation is performed per file. The summary reports `FAIL` if any
matched file fails the check.

## Future

- Additional metrics and analysis options may be added in future versions.

- Visit the [GitHub Issues list](https://github.com/continuous-delphi/delphi-lexer/issues) to view existing items.
You are encouraged to submit feature requests or bug reports.

- `delphi-lexer` will be used in the upcoming `delphi-parser` project

---

## Example Unit Tokenized

Found in: `test/golden/real_unit.pas`

```pascal
unit NumberUtils;

interface

type
  TIntArray = array of Integer;

function Sum(const Values: TIntArray): Integer;
function Max(A, B: Integer): Integer;

implementation

function Sum(const Values: TIntArray): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := Low(Values) to High(Values) do
    Result := Result + Values[I];
end;

function Max(A, B: Integer): Integer;
begin
  if A >= B then
    Result := A
  else
    Result := B;
end;

end.
```

---

![continuous-delphi logo](../../assets/continuous-delphi-480x270.png)

Part of the [Continuous-Delphi](https://github.com/continuous-delphi) ecosystem including:

- `delphi-lexer` -- core tokenizer
  - `Delphi.Lexer.TokenDump` -- token inspection
  - `Delphi.Lexer.TokenStats` -- token analysis
  - `Delphi.Lexer.TokenCompare` -- token comparison
- `delphi-compiler-versions` -- Canonical list of versions with aliases and toolchain metadata
- `delphi-inspect` -- Delphi toolchain discovery and normalization for assisting with automated builds
- `delphi-powershell-ci` -- Automate clean, build, test and other steps for reliable pre-commit verification
