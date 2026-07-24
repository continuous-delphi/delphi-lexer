# Changelog for delphi-lexer
Home repo: https://github.com/continuous-delphi/delphi-lexer

---

## v0.8.142.0
- Deterministic, lossless `TLexerUtils.ReadAllText`: BOM-authoritative decode
  and pure-Pascal UTF-8 validation (new `Delphi.SourceIO` unit), so a legacy
  CP1252 file is no longer at the mercy of RTL-version decode behavior. Removed
  the locale-dependent `--encoding default` value.
[#22](https://github.com/continuous-delphi/delphi-lexer/issues/22)
