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
