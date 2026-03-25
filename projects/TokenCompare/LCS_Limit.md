# MAX_MYERS_TOKENS = 200,000 -- Rationale

## What drives Myers memory usage

Myers diff stores a trace: one snapshot of the V array per edit-distance
step d.  Each V snapshot has 2*(N+M)+1 integer slots, where N and M are
the token counts of the two files.  The total trace memory is therefore:

    trace_bytes = (d + 1) * (2*(N+M) + 1) * 4

d is the edit distance -- the number of insertions plus deletions in the
minimal edit script.

## Two very different worlds

### Expected case: nearly-identical files

TokenCompare's primary use case is formatter and round-trip verification,
where the two files are the same source before and after a tool pass.
Edit distances in this range are tiny -- typically 0 to a few dozen.

At N = M = 200,000 and d = 10:

    trace = 11 * 800,001 * 4 bytes = ~34 MB

At d = 100:

    trace = 101 * 800,001 * 4 bytes = ~320 MB

Both are well within normal desktop RAM budgets.

### Pathological case: completely different files

If the two files share no tokens, d = N + M.  At N = M = 200,000:

    trace = 400,001 * 800,001 * 4 bytes = ~1.28 TB

That is unusable.  The fallback threshold prevents this scenario from
ever reaching the Myers path.  Even when both files are within the
200,000-token limit, the edit-distance abort (see below) provides a
second line of defence for large, highly-divergent inputs.

## Why 200,000 specifically

**Real Delphi files are much smaller.**  A survey of large open-source
Delphi codebases shows:

| File size category | Approximate token range |
|---|---|
| Small unit (< 200 LOC) | 500 -- 2,000 |
| Medium unit (200-1000 LOC) | 2,000 -- 15,000 |
| Large unit (1000-5000 LOC) | 15,000 -- 80,000 |
| Very large unit (> 5000 LOC) | 80,000 -- 150,000 |
| Exceptional outliers | 150,000+ |

200,000 tokens corresponds to roughly 6,000-8,000 lines of dense Delphi
code -- practically larger than most single-unit files.  The threshold
is therefore rarely hit in practice for legitimate source inputs.

**The limit is per-file, not combined.**  Two files each just under
200,000 tokens produce N+M close to 400,000, which at low d is still
well-behaved.  At high d the fallback protects against the worst case.

**The fallback is correct, just less precise.**  The sequential algorithm
still gives the correct equal/not-equal answer and still reports
differences; it just produces sequential positional diffs rather than
a minimal edit script.  A warning line in the output tells the user which
algorithm was used.

## Edit-distance abort: MAX_MYERS_EDIT_DISTANCE_PCT

Even when both files are within the token-count limit, a forward pass over
two completely unrelated 200,000-token files would iterate through up to
400,000 d-steps, each scanning up to 800,001 diagonals -- roughly 3.2 x 10^11
inner-loop iterations.  That is not a memory problem; it is a runtime problem.

To prevent runaway computation, `MyersForward` aborts if d exceeds:

    threshold = max((N + M) * 30 / 100, 100)

The constants in `DelphiLexer.Diff.pas` are:

    MAX_MYERS_EDIT_DISTANCE_PCT   = 30;   // percent of (N + M)
    MAX_MYERS_EDIT_DISTANCE_FLOOR = 100;  // minimum threshold

### Why 30 %

An edit distance of 30 % of (N + M) means roughly one in three tokens is an
insertion or deletion.  Files that differ by that margin are almost certainly
not related versions of the same source -- the user has likely compared the
wrong pair.  There is no useful diff to report at that divergence level.

Keeping the threshold at 30 % (rather than, say, 10 %) leaves comfortable
headroom for legitimate heavy-edit scenarios such as large automated
refactors, while still aborting cleanly on accidental cross-file comparisons.

### Why the floor of 100

When N + M is small (fewer than 334 tokens combined), 30 % rounds down to
fewer than 100 steps.  Without the floor, a 50-token pair that is completely
different would abort at d = 15, even though the forward pass would finish
naturally at d = 50 almost instantly.  The floor ensures the abort never
triggers for inputs where performance is not a concern.

### Abort behaviour

When the threshold is exceeded, `BuildDiffList`:
- sets `AbortedTooManyDiffs := True`
- sets `TotalDiffs := -1` (unknown; forward pass did not complete)
- returns an empty diff list
- exits with code 11 (distinct from code 10 for a normal difference)

The text output prints:

    (aborted: edit distance exceeds 30% of token count; are these the right files?)

The JSON options object includes `"abortedTooManyDiffs": true` and
`"diffCount": -1` in the summary.

## Adjusting the thresholds

All three constants are defined at the top of `DelphiLexer.Diff.pas`:

    MAX_MYERS_TOKENS              = 200000;
    MAX_MYERS_EDIT_DISTANCE_PCT   = 30;
    MAX_MYERS_EDIT_DISTANCE_FLOOR = 100;

### Adjusting MAX_MYERS_TOKENS

Choose the largest N where d*(2N) fits in the memory budget for your
expected worst-case d.  For a 512 MB budget and d = 500:

    N = 512 MB / (500 * 2 * 4 bytes) = ~128,000

For a 2 GB budget and the same d, the safe MAX_MYERS_TOKENS value is:

    N = 2 GB / (500 * 2 * 4 bytes) = ~500,000

### Adjusting MAX_MYERS_EDIT_DISTANCE_PCT

Raise the percentage to tolerate heavier-edited file pairs before aborting.
Lower it to abort sooner and reduce worst-case forward-pass time.
The value has no effect on memory; it affects only the number of d-steps
the forward pass is allowed to take.

### Adjusting MAX_MYERS_EDIT_DISTANCE_FLOOR

The floor only matters for tiny inputs (N + M < 334 at the default 30 %).
There is rarely a reason to change it.
