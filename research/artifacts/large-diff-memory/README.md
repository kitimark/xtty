# Large-diff memory probe

This artifact drives the **built xtty App path** for
`fix-large-diff-memory-bound`: a fresh repository and fresh app process per case,
the existing `-UITestGitReview` file-selection seam, the real `GitRunner.diff`,
and the DEBUG state dump's `memoryFootprintBytes`/selected-diff state.

Run from the repository root after a DEBUG build:

```sh
research/artifacts/large-diff-memory/probe.sh \
  build/Build/Products/Debug/xtty.app/Contents/MacOS/xtty \
  /tmp/xtty-large-diff-memory.tsv
```

(Matches `make build`'s `DERIVED := build` convention; corrected in
cross-review round 2 from a stale `.build/DerivedData/...` path.)

The cases are exact 5, 25, and 75 MiB many-line (100-byte lines) working-tree
files, an exact 25 MiB single-line file, and — added in cross-review round 1
(2026-07-27) — 10 and 40 MiB `wide`-line files (2,000-byte lines): long enough
that the accumulator's 4 MiB `retainedBytes` ceiling fires (at ~2,096 lines,
well before the 5,008-line `physicalLines` ceiling), a shape the original four
cases never exercised. Each case:

1. creates and commits a one-line baseline;
2. replaces it with the requested generated file;
3. launches a fresh xtty configured to start in that repository;
4. waits for Git review to classify the repo;
5. samples the xtty PID's RSS every 10 ms while selecting `sample.txt`;
6. waits for `selectedDiff.truncated == true`;
7. records the cutoff log (reason + retained bytes); and
8. checks that no `git diff --unified=…` child for the fixture remains.

The TSV's `rss_delta_kib` is corroborating by-effect evidence, not a portable
hard threshold: allocator pooling and WindowServer state vary. The deterministic
gate is `BoundedDiffOutputTests`, which proves retained-prefix invariants. The
effect discriminator is the **slope** across increasing total output.

## Recorded post-fix runs

The 2026-07-26 run (four cases; never reached the `retainedBytes` ceiling) is
preserved in [`post-fix-2026-07-26.tsv`](post-fix-2026-07-26.tsv). The
2026-07-27 run (all six cases, same DEBUG build, superseding the 2026-07-26
figures for the shapes they share) is preserved in
[`post-fix-2026-07-27.tsv`](post-fix-2026-07-27.tsv):

| Case | Input | Peak RSS growth | Completion | Cutoff | Preview children |
| --- | ---: | ---: | ---: | --- | ---: |
| many-line | 5 MiB | 4,880 KiB | 458 ms | physical lines, 510,329 B retained | 0 |
| many-line | 25 MiB | 4,528 KiB | 640 ms | physical lines, 510,330 B retained | 0 |
| many-line | 75 MiB | 4,880 KiB | 752 ms | physical lines, 510,330 B retained | 0 |
| single line | 25 MiB | 3,168 KiB | 422 ms | current line, 16,503 B retained | 0 |
| wide line | 10 MiB | 20,480 KiB | 744 ms | retained bytes, 4,194,304 B retained | 0 |
| wide line | 40 MiB | 20,544 KiB | 933 ms | retained bytes, 4,194,304 B retained | 0 |

The 5→75 MiB many-line increase leaves xtty's peak growth flat within 352 KiB;
the 10→40 MiB wide-line increase leaves it flat within 64 KiB. All four cutoff
observations publish in under one second and the post-publication child census
is zero. These are observations from one machine, not timing or RSS budgets.

**The `retainedBytes`-cutoff shape (wide line) costs about 4× the many-line and
single-line shapes** — around 20.5 MiB rather than ~5 MiB — because it is the
only shape where the full 4 MiB accumulator ceiling is reached, so `Data`,
decoded `String`, the split `[String]`, and the parsed model transiently
coexist at close to their full size. Quote the wide-line figure, not the
many-line one, as xtty's peak growth for an arbitrarily large diff in general;
the many-line/single-line figures characterize their own, cheaper shapes only.

The cutoff's retained-byte value includes Git's diff headers before the bounded
file content, which is why the physical-line cases retain about 510 KiB and the
single-line case retains 16,503 B rather than exactly the limit constants; the
wide-line cases retain exactly the 4,194,304 B (4 MiB) limit itself, since that
limit — not a header offset — is what stops them.

The script creates only a validated `mktemp` directory under `/tmp`, removes it
on exit, and terminates any app process it launched. It does not touch the
working repository.

## Submodule-diff-recursion probe

[`submodule-diff-recursion-probe.sh`](submodule-diff-recursion-probe.sh) is a
separate, App-free real-Git fixture (cross-review round 1, 2026-07-27) that
reproduces a distinct hole found by the cross-review's Codex pass: a changed
submodule with `diff.submodule=diff` configured recurses `git diff` into the
submodule's own nested content diff instead of the safe one-line `Subproject
commit` summary, defeating the "this preview shows exactly one file's own
diff" scope assumption `GitRunner.diff` relies on. It confirms `--submodule=short`
(added to all three preview invocations and to snapshot numstat) closes the
recursion. Run it directly; no App build is required:

```sh
research/artifacts/large-diff-memory/submodule-diff-recursion-probe.sh
```
