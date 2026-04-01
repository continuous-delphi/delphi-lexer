# delphi-lexer

![delphi-lexer logo](https://continuous-delphi.github.io/assets/logos/delphi-lexer-480x270.png)

[![Delphi](https://img.shields.io/badge/delphi-red)](https://www.embarcadero.com/products/delphi)
[![CI](https://github.com/continuous-delphi/delphi-lexer/actions/workflows/ci.yml/badge.svg)](https://github.com/continuous-delphi/delphi-lexer/actions/workflows/ci.yml)
[![GitHub Release](https://img.shields.io/github/v/release/continuous-delphi/delphi-lexer?display_name=release)](https://github.com/continuous-delphi/delphi-lexer/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/continuous-delphi/delphi-lexer)
[![Continuous Delphi](https://img.shields.io/badge/org-continuous--delphi-red)](https://github.com/continuous-delphi)


A standalone, reusable lexer for Delphi (Object Pascal) source code.
Produces a flat `TList<TToken>` from source text with full round-trip
fidelity and precise source mapping.

Lexer only (no parser, no AST, no formatter, or configuration dependencies).

---

## Quick start

```pascal
uses
  System.Generics.Collections,
  DelphiLexer.Token,
  DelphiLexer.Lexer;

var
  Lexer:  TDelphiLexer;
  Tokens: TList<TToken>;
  Tok:    TToken;
begin
  Lexer := nil;
  Tokens := nil;

  try
    Lexer  := TDelphiLexer.Create;
    Tokens := Lexer.Tokenize(SourceText);
    for Tok in Tokens do
    begin
      WriteLn(Tok.Line, ':', Tok.Col, '  ', Tok.Text);
    end;
  finally
    Tokens.Free;
    Lexer.Free;
  end;
end;
```

`Tokenize` allocates and returns a `TList<TToken>`; the caller owns it.
`TokenizeInto` appends tokens to a caller-supplied list (avoids the allocation).

---

## Repository layout

```
source/             Core library units
  DelphiLexer.Token.pas       TToken record, TTokenKind enum
  DelphiLexer.Keywords.pas    DELPHI_KEYWORDS list, IsDelphiKeyword
  DelphiLexer.Scanner.pas     TScanner + helpers (internal; not public API)
  DelphiLexer.Lexer.pas       TDelphiLexer (public entry point)
  DelphiLexer.Utils.pas       Shared command line options/utilities
  DelphiLexer.Diff.pas        Myers diff algorithm over tokens

test/               DUnitX test project
  golden/           Representative .pas files for round-trip tests

projects
  TokenDump/        Inspect tokens within a file
  TokenStats/       Analyze token metrics within a file
  TokenCompare/     Verify tokens between two files

tools/              developer tools
docs/               Architecture notes
shared/             Third-party code
```

---

## Design goals

- Deterministic tokenization (no context-dependent behavior)
- Lossless round-trip fidelity
- Precise source mapping (offset + length)
- Minimal assumptions about downstream usage
- Clear handling of malformed input

See also: [Dev Note - Design Invariants.md](/docs/dev-note--design-invariants.md)

---

## Token utilities

In addition to the core lexer, this repository provides three command-line tools
for working with token streams:

- **DelphiLexer.TokenDump** – inspect tokens
- **DelphiLexer.TokenStats** – analyze token metrics
- **DelphiLexer.TokenCompare** – compare token streams

These utilities are intended for debugging, regression testing, and validating
source transformations using deterministic token-level output.

---

## TToken fields

| Field | Type | Description |
|---|---|---|
| `Kind` | `TTokenKind` | Token classification (see below) |
| `Text` | `string` | Characters of this token, as they appear in the source |
| `Line` | `Integer` | 1-based line number of the first character |
| `Col` | `Integer` | 1-based column number of the first character |
| `StartOffset` | `Integer` | 0-based character index of the first character in the source string |
| `Length` | `Integer` | Character count of `Text` (equals `System.Length(Text)`) |
| `LeadingTrivia` | 'Integer` |  Trivia tokens immediately before this token |
| `TrailingTrivia` | 'Integer` | same-line trivia tokens after this token (incl. EOL) |

## TTokenKind values

| Kind | Produced for |
|---|---|
| `tkIdentifier` | Plain identifier, or `&ident` escaped identifier |
| `tkStrictKeyword` | Globally reserved keyword (`begin`, `if`...) |
| `tkContextKeyword` | Contextually relevant keyword (`public`, `deprecated`...) |
| `tkNumber` | Decimal, hex (`$`), binary (`%`), octal (`&`), float |
| `tkString` | `'single-quoted'` or `'''triple-quoted multiline'''` |
| `tkCharLiteral` | `#nn` or `#$hex` character literal |
| `tkComment` | `{ }`, `(* *)`, or `//` comment |
| `tkDirective` | `{$ }` or `(*$ *)` compiler directive |
| `tkSymbol` | Operator or punctuation (`:=`, `..`, `<=`, `>=`, `<>`, `(`, `)`, etc.) |
| `tkWhitespace` | Run of spaces and/or tabs |
| `tkEOL` | Line ending: `#13#10` (CRLF), `#10` (LF), or `#13` (bare CR) |
| `tkEOF` | End-of-source sentinel; always the last token, `Text = ''` |
| `tkInvalid` | Character or prefix that does not begin any valid Delphi token |


Note: `//` comment tokens do not include the trailing EOL.
After a line comment, the line ending is a separate `tkEOL` token -- it is
not part of the `tkComment` text. This is consistent with how EOLs are
handled everywhere else in the token stream (they are always their own
tokens), but it differs from some other lexers where the newline is
considered part of the comment. Callers that need to detect "end of line
after a comment" should look at the token immediately following the
`tkComment`.

---

## Invalid token policy

A character or prefix that cannot begin any valid Delphi token produces a
`tkInvalid` token containing **exactly that character**. The lexer never
absorbs adjacent valid characters into an invalid token; those are
tokenized independently on the next iteration.

Characters and prefixes that produce `tkInvalid`:

| Input | Behavior |
|---|---|
| `$` (no following hex digit) | `tkInvalid('$')` |
| `#` (no following digit or `$hex`) | `tkInvalid('#')` |
| `#$` (no following hex digit) | `tkInvalid('#')` + `tkInvalid('$')` |
| `&` (not followed by ident char or octal digit) | `tkInvalid('&')` |
| `%` (not followed by `0` or `1`) | `tkInvalid('%')` |
| `}` (stray close brace) | `tkInvalid('}')` |
| `?`, `!`, `\`, `~`, `#0`, and other unrecognised chars | `tkInvalid(c)` |

Unterminated block constructs (`{hello` with no closing brace, `(*hello`
with no closing `*)`) do **not** produce `tkInvalid`. The lexer reads to EOF
and emits `tkComment` with all consumed characters in `Text`.

Single-quoted strings stop at the first EOL if no closing quote appears on
the same line. The EOL becomes a separate `tkEOL` token and is not absorbed
into the string. Tokens on subsequent lines are unaffected. A string token
whose `Text` contains no closing `'` signals an unterminated string to
callers.

Round-trip fidelity is preserved in all unterminated cases.

Callers that require valid input can check `Token.Kind = tkInvalid` or count
invalid tokens with `TokenDump`'s `Invalid:` summary field.

---

## Multiline string policy

A multiline string is delimited by an odd number of single quotes N >= 3
(the *delimiter width*), optionally followed by trailing whitespace, and then
a line ending. The closing delimiter is exactly N quotes at the start of a
line (after optional leading whitespace) where the character immediately
after the N quotes is not another quote.

### Delimiter widths

| Delimiter | Can embed in body |
|---|---|
| `'''` (3) | Any content that does not start a line with exactly `'''` |
| `'''''` (5) | Content including `'''` at line start |
| `'''''''` (7) | Content including `'''''` at line start |

To embed a triple-quote sequence in a multiline string, use a 5-quote
delimiter:

```pascal
var S := '''''
  some text
  and now '''
  some more text
''''';
```

Even quote counts (2, 4, 6, ...) are not multiline delimiters. They are
runs of escaped quotes inside a regular single-quoted string.

The lexer does not strip leading indentation or trailing newlines from
the body -- that is a compiler concern. The token text is the verbatim
source slice from the opening delimiter to the closing delimiter inclusive,
preserving all whitespace.

---

## Numeric literal policy

### Bases supported

| Form | Example | Notes |
|---|---|---|
| Decimal integer | `42` | |
| Decimal float | `3.14`, `1.5e-10`, `1e6` | See exponent rules below |
| Hex | `$DEADBEEF` | Leading `$`, hex digits `0-9 A-F a-f` |
| Binary | `%10110011` | Leading `%`, digits `0` and `1` |
| Octal | `&0377` | Leading `&`, digits `0-7` |

### Digit separators

Underscore (`_`) is allowed as a digit separator in all bases and in all
parts of a decimal literal (integer part, fractional part, exponent part).
One or more consecutive underscores are accepted.

```text
$FF_FF      1__000___000    3.14___15__    1e1_0    %101_0___0101
```

### Float exponent backtracking

If `e` or `E` appears after a decimal integer but is not followed by digits
(optionally with a leading `+` or `-` sign), the lexer backtracks past the
`e`. The digit run up to that point becomes `tkNumber`; the `e` begins the
next token (typically `tkIdentifier` or `tkStrictKeyword/tkContextKeyword`).

```text
1e6    ->  tkNumber('1e6')       // exponent digits present
1e     ->  tkNumber('1') + tkIdentifier('e')   // no digits after e
1exit  ->  tkNumber('1') + tkIdentifier('exit')   // e starts identifier
```

### Range operator guard

`1..9` is tokenized as `tkNumber('1')` + `tkSymbol('..')` + `tkNumber('9')`.
The lexer looks ahead before consuming the `.` fractional part: if the
character after `.` is also `.`, the decimal point is not consumed.

---

## Reserved words

- 123 keywords are classified as `tkStrictKeyword` or `tkContextKeyword`.
All others tokenize as `tkIdentifier`. The list is maintained in
`DelphiLexer.Keywords.pas` and has been matched to Embarcadero's official
documentation: [Embarcadero: Fundamental Syntactic Elements](https://docwiki.embarcadero.com/RADStudio/en/Fundamental_Syntactic_Elements_%28Delphi%29)


### Known simplifications

- Char literal code point values are not range-checked.
`#999`, `#$FFFFFF`, and other out-of-range forms tokenize as `tkCharLiteral`
without validation. Whether the code point is a valid Unicode scalar value
is the compiler's concern, not the lexer's.

- `Col` is in UTF-16 code units.
`TToken.Col` counts UTF-16 code units from the start of the line, which is
consistent with Delphi's own `string` type and with the default position
encoding in the Language Server Protocol. For source containing characters
outside the Unicode Basic Multilingual Plane (e.g., emoji in string literals
or comments), a single visible character occupies two code units, so `Col`
will not correspond to the visible display column for tokens that follow
such content. `StartOffset` and `Length` are also in code units, consistent
with Delphi string indexing.

### Current non-goals

- No semantic annotations on TToken.
`TToken` carries no `Depth`, `AsmBody`, or any other field that requires
understanding the surrounding structure. Callers that need annotation must
wrap `TToken` in their own record (e.g., `TAnnotatedToken`).

- No language-version configuration.
There is currently no switch to target Delphi 7, XE2, or any earlier version. The
keyword list and literal syntax target the latest release.

- No encoding detection.
The source string is a Delphi `string` (UTF-16). Reading files and detecting
or converting encoding is the caller's responsibility.

- No error recovery strategy.
The lexer produces `tkInvalid` for unrecognised input but makes no attempt
to re-synchronize or guess the intended token. Recovery is the caller's
concern.

---

## Maturity

This repository is currently `incubator` and is under active development.
It will graduate to `stable` once:

- At least one downstream consumer exists.
- No breaking API changes are anticipated.

Until graduation, breaking changes may occur.

---

![continuous-delphi logo](https://continuous-delphi.github.io/assets/logos/continuous-delphi-480x270.png)

## Part of Continuous Delphi

This tool is part of the [Continuous-Delphi](https://github.com/continuous-delphi)
ecosystem, dedicated to the long-term success of Delphi applications.
