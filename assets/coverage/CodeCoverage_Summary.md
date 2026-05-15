# radCodeCoverage Report

![Coverage](https://img.shields.io/badge/Coverage-95.5%25-brightgreen)

## Summary

| Metric | Value |
|---|---:|
| Coverage | 95.5% |
| Covered lines | 3110 |
| Total lines | 3256 |
| Missed lines | 146 |
| Units | 27 |
| Status | PASS |

## Coverage By Module

| Module | Coverage | Covered | Total | Status |
|---|---:|---:|---:|---|
| Delphi.Lexer.Tests.exe | 95.5% | 3110 | 3256 | PASS |

## Coverage Visuals

**Overall**  🟩🟩🟩🟩🟩  95.5%

**Delphi.Lexer.Tests.exe**  🟩🟩🟩🟩🟩  95.5%

## Largest Uncovered-Line Risk

| Unit | Module | Coverage | Missed | Covered | Total | Status |
|---|---|---:|---:|---:|---:|---|
| Delphi.Lexer.MyersDiff.pas | Delphi.Lexer.Tests.exe | 63.9% | 52 | 92 | 144 | RISK |
| Delphi.Token.List.pas | Delphi.Lexer.Tests.exe | 3.6% | 27 | 1 | 28 | RISK |
| Delphi.Lexer.pas | Delphi.Lexer.Tests.exe | 93.7% | 26 | 384 | 410 | PASS |
| Delphi.Token.pas | Delphi.Lexer.Tests.exe | 4.3% | 22 | 1 | 23 | RISK |
| Delphi.Token.TriviaSpan.pas | Delphi.Lexer.Tests.exe | 64.3% | 5 | 9 | 14 | RISK |
| Delphi.Lexer.Tests.dpr | Delphi.Lexer.Tests.exe | 70.6% | 5 | 12 | 17 | WATCH |
| Delphi.Lexer.Scanner.pas | Delphi.Lexer.Tests.exe | 90.7% | 5 | 49 | 54 | PASS |
| Test.Delphi.Lexer.MultiLineStrings.pas | Delphi.Lexer.Tests.exe | 99.0% | 3 | 299 | 302 | PASS |
| Test.Delphi.Lexer.Golden.pas | Delphi.Lexer.Tests.exe | 99.1% | 1 | 115 | 116 | PASS |
| Delphi.Keywords.pas | Delphi.Lexer.Tests.exe | 100.0% | 0 | 17 | 17 | PASS |

## Unit Details

<details>
<summary>All units</summary>

| Unit | Module | Coverage | Covered | Total | Status |
|---|---|---:|---:|---:|---|
| Delphi.Lexer.MyersDiff.pas | Delphi.Lexer.Tests.exe | 63.9% | 92 | 144 | RISK |
| Delphi.Token.List.pas | Delphi.Lexer.Tests.exe | 3.6% | 1 | 28 | RISK |
| Delphi.Lexer.pas | Delphi.Lexer.Tests.exe | 93.7% | 384 | 410 | PASS |
| Delphi.Token.pas | Delphi.Lexer.Tests.exe | 4.3% | 1 | 23 | RISK |
| Delphi.Token.TriviaSpan.pas | Delphi.Lexer.Tests.exe | 64.3% | 9 | 14 | RISK |
| Delphi.Lexer.Tests.dpr | Delphi.Lexer.Tests.exe | 70.6% | 12 | 17 | WATCH |
| Delphi.Lexer.Scanner.pas | Delphi.Lexer.Tests.exe | 90.7% | 49 | 54 | PASS |
| Test.Delphi.Lexer.MultiLineStrings.pas | Delphi.Lexer.Tests.exe | 99.0% | 299 | 302 | PASS |
| Test.Delphi.Lexer.Golden.pas | Delphi.Lexer.Tests.exe | 99.1% | 115 | 116 | PASS |
| Delphi.Keywords.pas | Delphi.Lexer.Tests.exe | 100.0% | 17 | 17 | PASS |
| Delphi.Token.Kind.pas | Delphi.Lexer.Tests.exe | 100.0% | 4 | 4 | PASS |
| Delphi.Tokenizer.pas | Delphi.Lexer.Tests.exe | 100.0% | 1 | 1 | PASS |
| Test.Delphi.Lexer.AsmBody.pas | Delphi.Lexer.Tests.exe | 100.0% | 232 | 232 | PASS |
| Test.Delphi.Lexer.BOM.pas | Delphi.Lexer.Tests.exe | 100.0% | 116 | 116 | PASS |
| Test.Delphi.Lexer.Core.pas | Delphi.Lexer.Tests.exe | 100.0% | 144 | 144 | PASS |
| Test.Delphi.Lexer.Directive.pas | Delphi.Lexer.Tests.exe | 100.0% | 109 | 109 | PASS |
| Test.Delphi.Lexer.FindTokenAtOffset.pas | Delphi.Lexer.Tests.exe | 100.0% | 98 | 98 | PASS |
| Test.Delphi.Lexer.InvalidTokens.pas | Delphi.Lexer.Tests.exe | 100.0% | 198 | 198 | PASS |
| Test.Delphi.Lexer.Keywords.pas | Delphi.Lexer.Tests.exe | 100.0% | 167 | 167 | PASS |
| Test.Delphi.Lexer.MultiSegmentStrings.pas | Delphi.Lexer.Tests.exe | 100.0% | 47 | 47 | PASS |
| Test.Delphi.Lexer.NumericLiterals.pas | Delphi.Lexer.Tests.exe | 100.0% | 213 | 213 | PASS |
| Test.Delphi.Lexer.QualifiedIdentifiers.pas | Delphi.Lexer.Tests.exe | 100.0% | 43 | 43 | PASS |
| Test.Delphi.Lexer.Symbols.pas | Delphi.Lexer.Tests.exe | 100.0% | 107 | 107 | PASS |
| Test.Delphi.Lexer.TokenCompare.Myers.pas | Delphi.Lexer.Tests.exe | 100.0% | 218 | 218 | PASS |
| Test.Delphi.Lexer.TokenMetadata.pas | Delphi.Lexer.Tests.exe | 100.0% | 161 | 161 | PASS |
| Test.Delphi.Lexer.TokenPosition.pas | Delphi.Lexer.Tests.exe | 100.0% | 56 | 56 | PASS |
| Test.Delphi.Lexer.TriviaSpans.pas | Delphi.Lexer.Tests.exe | 100.0% | 217 | 217 | PASS |

</details>
