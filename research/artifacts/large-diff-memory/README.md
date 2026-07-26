# Large-diff memory probe

This artifact drives the **built xtty App path** for
`fix-large-diff-memory-bound`: a fresh repository and fresh app process per case,
the existing `-UITestGitReview` file-selection seam, the real `GitRunner.diff`,
and the DEBUG state dump's `memoryFootprintBytes`/selected-diff state.

Run from the repository root after a DEBUG build:

```sh
research/artifacts/large-diff-memory/probe.sh \
  .build/DerivedData/Build/Products/Debug/xtty.app/Contents/MacOS/xtty \
  /tmp/xtty-large-diff-memory.tsv
```

The four cases are exact 5, 25, and 75 MiB many-line working-tree files plus an
exact 25 MiB single-line file. Each case:

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

## Recorded post-fix run

The 2026-07-26 run is preserved in
[`post-fix-2026-07-26.tsv`](post-fix-2026-07-26.tsv):

| Case | Input | Peak RSS growth | Completion | Cutoff | Preview children |
| --- | ---: | ---: | ---: | --- | ---: |
| many-line | 5 MiB | 5,280 KiB | 458 ms | physical lines, 510,329 B retained | 0 |
| many-line | 25 MiB | 5,120 KiB | 602 ms | physical lines, 510,330 B retained | 0 |
| many-line | 75 MiB | 4,928 KiB | 734 ms | physical lines, 510,330 B retained | 0 |
| single line | 25 MiB | 3,168 KiB | 455 ms | current line, 16,503 B retained | 0 |

The 5→75 MiB input increase leaves xtty's peak growth flat within 352 KiB. Both
cutoff shapes publish in under one second and the post-publication child census
is zero. These are observations from one machine, not timing or RSS budgets.

The cutoff's retained-byte value includes Git's diff headers before the bounded
file content, which is why the physical-line cases retain about 510 KiB and the
single-line case retains 16,503 B rather than exactly the limit constants.

The script creates only a validated `mktemp` directory under `/tmp`, removes it
on exit, and terminates any app process it launched. It does not touch the
working repository.
