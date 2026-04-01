# Dev Note -- Design Invariants

Internal architecture notes for **delphi-lexer**

Design invariants are rules that must hold across all components of the system.

They are different from implementation details:
- Implementation details may change as the code evolves.
- Invariants must remain true regardless of refactoring.

If a future design change requires violating an invariant,
the invariant must be revised here _first_ before code changes proceed.

Each invariant states:
- the rule
- why it exists
- what breaks if it is violated

---

## I-1: Round-trip fidelity

**Rule:** Concatenating `Token.Text` across every token in the list, in order,
reproduces `Source` exactly. No character may be added, removed, or altered.

**Why it exists:** Callers (formatters, linters, refactoring tools) need to
reconstruct the source from the token stream without a separate copy of the
original string. If any character is dropped or changed, the reconstructed
source diverges from the input.

**What breaks if violated:** A formatter that edits only whitespace tokens and
then concatenates the stream will silently corrupt the file. Round-trip tests
in `TGoldenTests` catch this at test time, but violations are hard to debug in
production because the corruption may be distant from the offending token.

---

## I-2: Complete coverage -- every character in exactly one token

**Rule:** Every character index in `Source` belongs to exactly one token's
`Text` field. There are no gaps and no overlaps.

**Why it exists:** A direct consequence of I-1. If a character appears in two
tokens, concatenation doubles it. If it appears in none, concatenation drops
it. The invariant makes the token list a lossless partition of the source.

**What breaks if violated:** Any tool that iterates tokens and tracks position
by summing lengths will desynchronize. Gap violations are the harder failure
mode -- they silently drop source characters.

---

## I-3: StartOffset and Length are consistent with Text

**Rule:** For every token `T`:
- `T.StartOffset` is the 0-based character index of `T.Text[1]` in `Source`.
- `T.Length = System.Length(T.Text)`.
- The next token's `StartOffset` equals `T.StartOffset + T.Length`.

**Why it exists:** Callers need fast random-access into the source without
rescanning. Storing the offset directly on the token avoids recomputation and
eliminates the class of bugs where a caller accumulates offsets incorrectly.

**What breaks if violated:** Any caller that uses `StartOffset` to highlight,
replace, or index into the source will operate on the wrong region. The
`TGoldenTests.CheckStandard` helper verifies the chain on every test run.

---

## I-4: Final token is always tkEOF with Text = ''

**Rule:** The last element of every token list produced by `TDelphiLexer` is
`tkEOF` with `Text = ''`. There is exactly one `tkEOF` token and it is always
last.

**Why it exists:** Consumers of the token stream can use a simple sentinel
check instead of bounds-checking on every lookahead. Pipeline code that reads
`Tokens[I+1]` or peeks ahead can always safely read up to and including the
EOF token without an index-out-of-range guard.

**What breaks if violated:** Lookahead code that stops at `tkEOF` will run
past the end of the list. Pipeline stages that assume the list ends with EOF
will misclassify the last real token or crash.

---

## I-5: Keyword classification is case-insensitive

**Rule:** A token is a `Keyword` if and only if its lowercased text matches an
entry in `DELPHI_KEYWORDS`. `BEGIN`, `Begin`, and `begin` are all keywords.
The stored `Text` preserves the original casing from the source.

**Why it exists:** Object Pascal is case-insensitive. A formatter or analyzer
that checks `Token.Kind = *Keyword` must not have to normalize case itself.
Classifying at lex time is cheaper and more reliable than doing it in every
downstream rule.

**What breaks if violated:** A keyword-casing rule that checks will miss
`BEGIN` or `Begin`.

---

## I-6: Escaped identifiers are always tkIdentifier, never *Keyword

**Rule:** A token beginning with `&` followed by identifier characters is
always `tkIdentifier`, regardless of the word that follows the ampersand.
`&begin`, `&type`, `&end` are all `tkIdentifier`.

**Why it exists:** The `&` prefix is the Delphi escape mechanism for using
reserved words as identifiers. Classifying `&begin` as `tkStrictKeyword` would
cause a keyword-casing rule to recase it, changing its meaning. The `&` signals
deliberate escaping.

**What breaks if violated:** A keyword-casing rule touches `&begin` and
produces `&BEGIN` or `&Begin`, which are different identifiers (or invalid
syntax). A structural pass that counts keyword tokens will over-count.

---

## I-7: IncI is the sole mutator of scanner position

**Rule:** All scanner position state (`I`, `Line`, `Col`, `AtLineStart`) is
updated exclusively through `IncI`. No read helper or dispatcher may directly
assign to these fields except via a save/restore pattern (see I-8).

**Why it exists:** `IncI` is the only place that correctly handles all three
EOL forms (CRLF, LF, bare CR). Any direct assignment to `Sc.I` without going
through `IncI` risks corrupting `Line`, `Col`, or `AtLineStart`.

**What breaks if violated:** Token positions (`Line`, `Col`) diverge from
reality. `AtLineStart` becomes incorrect, which breaks multiline-string
detection (which relies on `AtLineStart` to identify delimiter lines).

---

## I-8: Save/restore must capture all four scanner state fields

**Rule:** When a read helper needs to backtrack (speculatively advance and then
undo), it must save and restore all four fields: `I`, `Line`, `Col`, and
`AtLineStart`. Saving only `I` is not sufficient.

**Why it exists:** `Line`, `Col`, and `AtLineStart` are derived from the
sequence of characters consumed by `IncI`. If the helper consumed an EOL
before deciding to backtrack, all four fields changed. Restoring only `I`
leaves the others in an inconsistent state.

**What breaks if violated:** Token positions for all tokens following the
backtrack point are wrong. `AtLineStart` corruption silently prevents
multiline-string delimiters from being recognized, producing a tkString that
swallows the rest of the file.

---

## I-9: AtLineStart is set by IncI, not derived retrospectively

**Rule:** `TScanner.AtLineStart` is the authoritative flag for whether the
scanner is at the start of a line. It must not be recomputed by scanning
backwards through the source string.

**Why it exists:** Backwards scanning is fragile near the start of source,
ambiguous for CRLF (does the #13 or the #10 end the line?), and O(n) in the
worst case. `IncI` maintains the flag incrementally at zero extra cost.

**What breaks if violated:** CRLF sequences produce an off-by-one: a backwards
scan that stops at #13 misidentifies the #10 position as being at line start.
The original pre-fix scanner had this exact bug.

---

## I-10: Malformed input produces tkInvalid, not a best-guess token

**Rule:** Characters or sequences that do not form a valid Delphi token must
produce a `tkInvalid` token containing exactly those characters. Examples:
bare `$` (no hex digits), `#$` (no hex digits after the dollar), bare `&`
(not followed by ident or octal digit), `~`, `\`, `!`, `?`.

**Why it exists:** Silently accepting malformed input as a valid token kind
(e.g., treating bare `$` as `tkNumber`) hides lexer errors and allows
downstream tools to operate on incorrect token streams. `tkInvalid` is a clear,
inspectable signal that the lexer encountered something it could not classify.

**What breaks if violated:** A formatter that processes a `tkNumber` token
containing `$` (no digits) may emit it unchanged and produce source that does
not compile. A linter that checks `InvalidCount = 0` as a validity gate will
pass malformed files.

---

## I-11: DELPHI_KEYWORDS must remain sorted in ascending order

**Rule:** The `DELPHI_KEYWORDS` array in `DelphiLexer.Keywords.pas` must
remain sorted in ascending ASCII/case-folded order at all times. Any addition,
removal, or rename must preserve the sort.

**Why it exists:** `IsDelphiKeyword` uses binary search. An unsorted array
causes binary search to return incorrect results -- words that are present may
be reported absent, or absent words may be falsely found.

**What breaks if violated:** Keywords are misclassified as `tkIdentifier`, or
plain identifiers are misclassified as `*Keyword`. The failure mode is silent
and test-dependent: only keywords in the affected region of the array are
misclassified.

---

## I-13: Operators are matched longest-first

**Rule:** In `ReadSymbol`, multi-character operators (`:=`, `<>`, `<=`, `>=`,
`..`) must be tested before their single-character prefixes. The first matching
prefix wins; no further alternatives are tried.

**Why it exists:** If single-character operators were checked first, `:=` would
produce `tkSymbol(':')` + `tkSymbol('=')` instead of a single `tkSymbol(':=')`.
Delphi requires `:=` to be a single assignment operator; splitting it makes it
unrecognizable to any downstream tool that inspects `Token.Text`.

**What breaks if violated:** Assignment (`:=`), comparison (`<>`, `<=`, `>=`),
and range (`..`) operators are each split into two separate tokens. The
round-trip guarantee (I-1) is still satisfied -- no characters are lost -- but
the token structure is wrong. Any consumer that matches on `Token.Text = ':='`
or `Token.Kind = tkSymbol` with a two-char text will never find the operator.

---

## I-12: Token kind is assigned at lex time; callers do not reclassify

**Rule:** `Token.Kind` is set once, during tokenization, and is not modified
afterward. No downstream consumer (formatter rule, structural pass, etc.) may
change a token's kind.

**Why it exists:** Token kind is the contract between the lexer and its
callers. Allowing reclassification downstream creates hidden coupling between
components and makes the token stream's meaning context-dependent. If a
higher-level analysis needs a finer classification, it should store that
information externally (e.g., in an annotation record that wraps `TToken`).

**What breaks if violated:** Two consumers that each reclassify the same token
differently produce inconsistent views of the stream. The lexer's guarantee
that `*Keyword` means "reserved word per the Delphi spec" no longer holds.

---

## I-14: Trivia ownership is complete and non-overlapping

**Rule:** Every trivia token in the flat list (`tkWhitespace`, `tkEOL`,
`tkComment`, `tkDirective`) appears in exactly one span -- either the
`LeadingTrivia` or `TrailingTrivia` of exactly one semantic token (or the
`tkEOF` sentinel). No trivia token is unowned; none appears in two spans.

Formally: if `Owned[I]` counts the number of times index `I` appears in any
span across the whole list, then `Owned[I] = 1` for every trivia token and
`Owned[I] = 0` for every non-trivia token.

**Why it exists:** The trivia spans are the authoritative ownership model for
downstream consumers (formatters, navigators). If a trivia token is unowned,
a formatter cannot determine which declaration or statement it belongs to. If
it is owned twice, moving one owner's trivia corrupts the other owner.

**What breaks if violated:** A formatter that moves a declaration and transfers
its `LeadingTrivia` will silently duplicate or drop comments. An ownership
uniqueness check (as in `Test.DelphiLexer.TriviaSpans`) will fail.

---

## I-15: Trivia tokens carry no trivia of their own

**Rule:** For every token where `Kind in [tkWhitespace, tkEOL, tkComment,
tkDirective]`, both `LeadingTrivia.IsEmpty` and `TrailingTrivia.IsEmpty` are
`True`. Trivia tokens are owned by semantic tokens; they do not themselves own
other trivia.

**Why it exists:** Trivia of trivia has no meaningful interpretation and would
make the ownership model recursive. `MakeToken` initialises both span fields to
`(-1, -1)` and `ApplyTriviaSpans` skips trivia tokens, so the property holds
by construction without extra logic.

**What breaks if violated:** Consumer code that walks a token's trivia and then
walks the trivia of that trivia enters an unexpected recursive case. The
`I14_SumOfSpanCountsEqualsTriviaTokenCount` invariant test will fail because
trivia-of-trivia counts would inflate `SpanTotal` above `TriviaCount`.

---

## I-16: EOF sentinel owns all trailing-file trivia as leading trivia

**Rule:** Any trivia token that follows the last non-EOF semantic token and
precedes `tkEOF` is owned as the `LeadingTrivia` of the `tkEOF` sentinel.
`tkEOF.TrailingTrivia.IsEmpty` is always `True`.

**Why it exists:** I-14 requires every trivia token to have an owner.
Trailing-file trivia (a comment or blank line after the last statement, with
no following semantic token) would otherwise be unowned. Assigning it to the
EOF sentinel gives it a deterministic owner without introducing a special
"floating trivia" concept.

**What breaks if violated:** Trailing-file comments are dropped or unowned,
violating I-14. A formatter that processes the whole file and transfers each
token's trivia will silently lose end-of-file comments.

---

## TToken field summary

`TToken` is defined in `DelphiLexer.Token.pas`. Current fields:

| Field | Type | Description |
|---|---|---|
| `Kind` | `TTokenKind` | Token classification; set once at lex time (I-12) |
| `Text` | `string` | Characters as they appear in source; concatenation is lossless (I-1) |
| `Line` | `Integer` | 1-based line number of the first character |
| `Col` | `Integer` | 1-based column number of the first character |
| `StartOffset` | `Integer` | 0-based absolute character index into source (I-3) |
| `Length` | `Integer` | Character count; always equals `System.Length(Text)` (I-3) |
| `LeadingTrivia` | `TTriviaSpan` | Inclusive index range of trivia tokens preceding this token (I-14, I-15) |
| `TrailingTrivia` | `TTriviaSpan` | Inclusive index range of same-line trivia tokens after this token, through the first EOL (I-14, I-15) |

`TTriviaSpan` is a record with `FirstTokenIndex` and `LastTokenIndex` (both
`-1` when empty) and helpers `IsEmpty` and `Count`.
