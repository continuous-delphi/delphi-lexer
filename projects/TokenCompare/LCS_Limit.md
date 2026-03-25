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
ever reaching the Myers path.

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

## Adjusting the threshold

The constant is isolated at the top of the implementation section in
`TokenCompare.pas`:

    MAX_MYERS_TOKENS = 200000;

To raise or lower it, change this one value.  A reasonable rule of thumb:
choose the largest N where d*(2N) fits in the memory budget for your
expected worst-case d.  For a 512 MB budget and d = 500:

    N = 512 MB / (500 * 2 * 4 bytes) = ~128,000

For a 2 GB budget and the same d, the safe MAX_MYERS_TOKENS value is:

    N = 2 GB / (500 * 2 * 4 bytes) = ~500,000
