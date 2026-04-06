# Delphi.Lexer.TokenCompare

A command-line utility for comparing the token stream produced by `delphi-lexer` for
two Object Pascal source files.

Comparison is by token Kind and Text. Line, col, and offset are not
compared but are included in diff output for diagnostics.

The comparison uses the Myers diff algorithm to minimize diff noise and
highlight meaningful token differences. A sequential fallback is used for
very large files (> 200,000 tokens per file). Comparisons are aborted when
the edit distance exceeds 30% of the combined token count, which indicates
the files are almost certainly unrelated.


![delphi-lexer logo](../../assets/delphi-lexer-480x270.png)

[https://github.com/continuous-delphi/delphi-lexer/](https://github.com/continuous-delphi/delphi-lexer/)

## When to use this tool

`Delphi.Lexer.TokenCompare` is useful for:

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

Example:  `Delphi.Lexer.TokenCompare.exe -?`

```text
Delphi.Lexer.TokenCompare
Compares the token streams of two Object Pascal source files
A command-line utility for delphi-lexer from Continuous-Delphi
https://github.com/continuous-delphi/delphi-lexer
MIT Licensed.  Copyright (C) 2026, Darian Miller
Version: 1.0.1

Delphi.Lexer.TokenCompare.exe [file] [file2] [options]

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

`delphi.lexer.tokencompare test\golden\real_unit.pas test\golden\real_unit_plus_CRLF.pas`

Result (notice Myers diff reduces noise):

```text
Delphi.Lexer.TokenCompare
formatVersion: 2.0.0
File A             : test\golden\real_unit.pas
File B             : test\golden\real_unit_plus_CRLF.pas
Mode               : exact
Equal              : no
Compared Tokens    : 201 / 206
Diff Count         : 5

Differences:

  [1]
    Type           : missing-token-in-a
    Index B        : 44
    B              : tkEOL "<CRLF>"

  [2]
    Type           : missing-token-in-a
    Index B        : 66
    B              : tkEOL "<CRLF>"

  [3]
    Type           : missing-token-in-a
    Index B        : 67
    B              : tkEOL "<CRLF>"

  [4]
    Type           : missing-token-in-a
    Index B        : 145
    B              : tkEOL "<CRLF>"

  [5]
    Type           : missing-token-in-a
    Index B        : 146
    B              : tkEOL "<CRLF>"

Exit Code: 10
```

`delphi.lexer.tokencompare test\golden\real_unit.pas test\golden\real_unit_plus_CRLF.pas -e`

Result

```text
Delphi.Lexer.TokenCompare
formatVersion: 2.0.0
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

  AppName         -- Delphi.Lexer.TokenCompare
  formatVersion   -- {X.Y.Z}
  File A          -- First file to compare
  File B          -- Second file to compare
  Mode            -- comparison mode derived from ignore-options, or `exact` when no filters are applied
  Equal           -- yes | no
  Compared Tokens -- number of tokens compared (if unequal, displayed as A# / B#)
  Diff Count      -- total edit distance (or "(unknown; aborted)" if abort threshold triggered)

  Followed by optional warning lines (fallback algorithm used, comparison aborted, truncation active)
  Followed by each token difference found, limited by effective max-diffs
```

### Diff Types

Diff entries may include:

- `substitution`         -- token replaced: dkMissingInB followed immediately by dkMissingInA at the same position
- `missing-token-in-a`   -- token exists in B but not A (insertion)
- `missing-token-in-b`   -- token exists in A but not B (deletion)

## Format 'json' output

- When `--format:json` is specified, the tool emits a machine-readable
representation of token comparison results derived from the `delphi-lexer` token stream.

- The JSON format is intended for use in automated testing, CI pipelines,
and tooling integrations.

- `usedFallback` indicates whether the sequential comparison algorithm was used
  instead of Myers. This occurs when either file exceeds 200,000 tokens.

- `abortedTooManyDiffs` indicates the comparison was aborted because the edit
  distance exceeded 30% of the combined token count. When true, `diffCount`
  is `-1` (unknown) and the `diffs` array is empty.

`delphi.lexer.tokencompare test\golden\real_unit.pas test\golden\real_unit_plus_CRLF.pas --format:json`

Result (notice Myers diff reduces noise):

```json
{
  "toolName": "Delphi.Lexer.TokenCompare",
  "formatVersion": "2.0.0",
  "fileA": "test\\golden\\real_unit.pas",
  "fileB": "test\\golden\\real_unit_plus_CRLF.pas",
  "options": {
    "encoding": "65001 (UTF-8)",
    "ignoreWhitespace": false,
    "ignoreEOL": false,
    "ignoreComments": false,
    "stopAfterFirstDiff": false,
    "maxDiffs": 2147483647,
    "usedFallback": false,
    "abortedTooManyDiffs": false
  },
  "summary": {
    "equal": false,
    "comparisonMode": "exact",
    "rawTokenCountA": 201,
    "rawTokenCountB": 206,
    "comparedTokenCountA": 201,
    "comparedTokenCountB": 206,
    "diffCount": 5
  },
  "diffs": [
    {
      "diffType": "missing-token-in-a",
      "indexB": 44,
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
      "diffType": "missing-token-in-a",
      "indexB": 66,
      "tokenB": {
        "kind": "tkEOL",
        "text": "\r\n",
        "line": 16,
        "col": 1,
        "startOffset": 239,
        "length": 2
      }
    },
    {
      "diffType": "missing-token-in-a",
      "indexB": 67,
      "tokenB": {
        "kind": "tkEOL",
        "text": "\r\n",
        "line": 17,
        "col": 1,
        "startOffset": 241,
        "length": 2
      }
    },
    {
      "diffType": "missing-token-in-a",
      "indexB": 145,
      "tokenB": {
        "kind": "tkEOL",
        "text": "\r\n",
        "line": 27,
        "col": 1,
        "startOffset": 436,
        "length": 2
      }
    },
    {
      "diffType": "missing-token-in-a",
      "indexB": 146,
      "tokenB": {
        "kind": "tkEOL",
        "text": "\r\n",
        "line": 28,
        "col": 1,
        "startOffset": 438,
        "length": 2
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

- `0`  -- success / files matched
- `1`  -- operational error (invalid input, file not found, etc.)
- `10` -- comparison complete, differences found
- `11` -- comparison aborted: edit distance exceeded threshold (files likely unrelated)

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
  - `Delphi.Lexer.TokenDump` -- token inspection
  - `Delphi.Lexer.TokenStats` -- token analysis
  - `Delphi.Lexer.TokenCompare` -- token comparison
- `delphi-compiler-versions` -- Canonical list of versions with aliases and toolchain metadata
- `delphi-inspect` -- Delphi toolchain discovery and normalization for assisting with automated builds
- `delphi-powershell-ci` -- Automate clean, build, test and other steps for reliable pre-commit verification


