# DelphiLexer.TokenCompare

A command-line utility for comparing the token stream produced by `delphi-lexer` for
two Object Pascal source files.

Comparison is by token Kind and Text. Line, col, and offset are not
compared but are included in diff output for diagnostics.


![delphi-lexer logo](../../assets/delphi-lexer-480x270.png)

[https://github.com/continuous-delphi/delphi-lexer/](https://github.com/continuous-delphi/delphi-lexer/)

## When to use this tool

`DelphiLexer.TokenCompare` is useful for:

- verifying that two source files produce equivalent token streams
- validating that formatting changes do not alter semantic tokens
- detecting unintended changes introduced by refactoring or code generation
- comparing before/after states in automated transformations
- supporting regression testing for lexer and formatter behavior
- enabling CI checks for semantic-preserving modifications
- isolating token-level differences during debugging

This utility is part of the `delphi-lexer` repository and is not distributed as a standalone project.

## Usage

View help with `-?` or `--help`

Example:  `DelphiLexer.TokenCompare.exe -?`

```text
DelphiLexer.TokenCompare
Compares the token streams of two Object Pascal source files
A command-line utility for delphi-lexer from Continuous-Delphi
https://github.com/continuous-delphi/delphi-lexer
MIT Licensed.  Copyright (C) 2026, Darian Miller
Version: 1.0.1

DelphiLexer.TokenCompare.exe [file] [file2] [options]

[file]                          - Delphi source file to tokenize
[file2]                         - Second source file to tokenize
[-t], [--ignore-trivia]         - Ignore whitespace and EOL tokens
[-w], [--ignore-whitespace]     - Ignore Whitespace tokens
[-e], [--ignore-eol]            - Ignore EOL tokens
[-c], [--ignore-comments]       - Ignore Comment tokens
[-x], [--stop-after-first-diff] - Stop after the first difference is found
[--max-diffs:value]             - Limit reported differences to N (0 =
                                  unlimited), default: 0
[--encoding:name]               - Source file encoding (utf-8, utf-16,
                                  utf-16be, ansi, ascii, default), default: utf-8
[--format:name]                 - Output format: text or json, default: text
[-?], [--help]                  - Show this help and exit
[-v], [--version]               - Show tool version and exit

```

Note: named option values use `--key:value` or `--key=value` syntax (not `--key value`).

## Example Commands

`delphilexer.tokencompare test\golden\real_unit.pas test\golden\real_unit_plus_CRLF.pas`

Result (truncated)

```text
DelphiLexer.TokenCompare
formatVersion: 1.0.0
File A             : test\golden\real_unit.pas
File B             : test\golden\real_unit_plus_CRLF.pas
Mode               : exact
Equal              : no
Compared Tokens    : 201 / 206
Diff Count         : 154

Differences:

  [1]
  Index A          : 44
  Index B          : 44
  A                : tkKeyword "function"
  B                : tkEOL "<CRLF>"

  [2]
  Index A          : 45
  Index B          : 45
  A                : tkWhitespace " "
  B                : tkKeyword "function"

  [3]
  Index A          : 46
  Index B          : 46
  A                : tkIdentifier "Max"
  B                : tkWhitespace " "

  [4]
  Index A          : 47
  Index B          : 47
  A                : tkSymbol "("
  B                : tkIdentifier "Max"

  ...

  [154]
  Type             : missing-token-in-a
  Index B          : 205
  B                : tkEOF ""

Exit Code: 10

```

`delphilexer.tokencompare test\golden\real_unit.pas test\golden\real_unit_plus_CRLF.pas -e`

Result

```text
DelphiLexer.TokenCompare
formatVersion: 1.0.0
File A             : test\golden\real_unit.pas
File B             : test\golden\real_unit_plus_CRLF.pas
Mode               : ignore-eol
Equal              : yes
Compared Tokens    : 168
Diff Count         : 0

Exit Code: 0
```

## Format 'text' output (default)

- The output is deterministic and stable across runs for identical input,
  making it suitable for regression testing and snapshot comparison.

- Outputs consist of a header followed by differences found (limited by
`--max-diffs` and `--stop-after-first-diff` which effectively
sets `--max-diffs` to 1)

```text
Header Lines:

  AppName         -- DelphiLexer.TokenCompare
  formatVersion   -- {X.Y.Z}
  File A          -- First file to compare
  File B          -- Second file to compare
  Mode            -- comparison mode derived from ignore-options, or `exact` when no filters are applied
  Equal           -- yes | no
  Compared Tokens -- number of tokens discovered (if unequal, displayed as A# / B#)
  Diff Count      -- Total tokens different based on mode

  Followed by each token difference found, limited by effective max-diffs
```

### Diff Types

Diff entries may include:

- `token-mismatch`       -- tokens differ at the same position
- `missing-token-in-a`   -- token exists in B but not A
- `missing-token-in-b`   -- token exists in A but not B

## Format 'json' output

- When `--format:json` is specified, the tool emits a machine-readable
representation of token comparison results derived from the `delphi-lexer` token stream.

- The JSON format is intended for use in automated testing, CI pipelines,
and tooling integrations.

`delphilexer.tokencompare test\golden\real_unit.pas test\golden\real_unit_plus_CRLF.pas --format:json`

Result (truncated)
```json
{
  "toolName": "DelphiLexer.TokenCompare",
  "formatVersion": "1.0.0",
  "fileA": "test\\golden\\real_unit.pas",
  "fileB": "test\\golden\\real_unit_plus_CRLF.pas",
  "options": {
    "encoding": "65001 (UTF-8)",
    "ignoreWhitespace": false,
    "ignoreEOL": false,
    "ignoreComments": false,
    "stopAfterFirstDiff": false,
    "maxDiffs": 2147483647
  },
  "summary": {
    "equal": false,
    "comparisonMode": "exact",
    "rawTokenCountA": 201,
    "rawTokenCountB": 206,
    "comparedTokenCountA": 201,
    "comparedTokenCountB": 206,
    "diffCount": 154
  },
  "diffs": [
    {
      "diffType": "token-mismatch",
      "indexA": 44,
      "indexB": 44,
      "tokenA": {
        "kind": "tkKeyword",
        "text": "function",
        "line": 11,
        "col": 1,
        "startOffset": 178,
        "length": 8
      },
      "tokenB": {
        "kind": "tkEOL",
        "text": "\r\n",
        "line": 11,
        "col": 1,
        "startOffset": 178,
        "length": 2
      }
    },
    {
      "diffType": "token-mismatch",
      "indexA": 45,
      "indexB": 45,
      "tokenA": {
        "kind": "tkWhitespace",
        "text": " ",
        "line": 11,
        "col": 9,
        "startOffset": 186,
        "length": 1
      },
      "tokenB": {
        "kind": "tkKeyword",
        "text": "function",
        "line": 12,
        "col": 1,
        "startOffset": 180,
        "length": 8
      }
    },
    ...
    {
      "diffType": "missing-token-in-a",
      "indexB": 205,
      "tokenB": {
        "kind": "tkEOF",
        "text": "",
        "line": 42,
        "col": 1,
        "startOffset": 603,
        "length": 0
      }
    }
  ]
}
```

## Encoding

Both input files are read using the same specified encoding.

Notes:

- `utf-8` is the default
- BOM is respected where applicable
- `default` uses the system default ANSI code page
- no automatic encoding detection is performed

## Exit codes

- `0`  -- success / matched
- `1`  -- operational error (invalid input, file not found, etc.)
- `10` -- comparison failed

## Future

- Additional comparison options planned in future versions.

- Visit the [GitHub Issues list](https://github.com/continuous-delphi/delphi-lexer/issues) to view existing items.
You are encouraged to submit feature requests or bug reports.

- `delphi-lexer` will be used in the upcoming `delphi-parser` project

---

## Example Units Tokenized

First file: `test/golden/real_unit.pas`

```pascal
unit NumberUtils;

interface

type

  ///<summary> Custom TIntArray summary </summary>
  TIntArray = array of Integer;

function Sum(const Values: TIntArray): Integer;
function Max(A, B: Integer): Integer;

implementation

function Sum(const Values: TIntArray): Integer;  {EOL Comment}
var
  I: Integer;
begin
  Result := 0;
  for I := Low(Values) to High(Values) do
    Result := Result + Values[I];
end;

function Max(A, B: Integer): Integer;
begin
  (*
    extra comments
    here
  *)
  if A >= B then
    Result := A
  else
    Result := B;
end;

end.
```

Second file: `test/golden/real_unit_plus_CRLF.pas`

```pascal
unit NumberUtils;

interface

type

  ///<summary> Custom TIntArray summary
  /// additional</summary>
  TIntArray = array of Integer;

function Sum(const Values: TIntArray): Integer;
function Max(A, B: Integer): Integer;

implementation

function Sum(const Values: TIntArray): Integer;  {EOL Comment extended}
var
  I: Integer;
begin
  Result := 0;
  for I := Low(Values) to High(Values) do
    Result := Result + Values[I];
end;

function Max(A, B: Integer): Integer;
begin
  (*
    extra comments
    added here
  *)
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
  - `DelphiLexer.TokenDump` -- token inspection
  - `DelphiLexer.TokenStats` -- token analysis
  - `DelphiLexer.TokenCompare` -- token comparison
- `delphi-compiler-versions` -- Canonical list of versions with aliases and toolchain metadata
- `delphi-inspect` -- Delphi toolchain discovery and normalization for assisting with automated builds
- `delphi-powershell-ci` -- Automate clean, build, test and other steps for reliable pre-commit verification


