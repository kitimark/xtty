## Context

Git review already limits its returned model to 5,000 hunk lines and clips each parsed line to 3,000 `Character`s, but those checks happen after the complete child output has been materialized:

```
git stdout
  → Pipe.readDataToEndOfFile()       // complete Data
  → String(decoding:)                // complete String
  → split(...).map(String.init)      // complete [String]
  → DiffParser's line/character caps
```

This is KI-1 in `research/03-analysis/known-product-issues.md` and contradicts the original P6 large-diff safety decision. Both tracked and untracked per-file previews use the same complete-output `GitRunner.run`; status, branch, and numstat queries use it too.

Focused exploration established the scale and the producer seam:

- A disposable reproduction of the current allocation shape grew peak memory by about **23.3 MiB**, **111.8 MiB**, and **321.6 MiB** for 5, 25, and 75 MiB many-line inputs respectively (roughly 4.3× input).
- A bounded chunk-reader prototype stayed around **3.3 MiB** across those same input sizes.
- Merely draining and discarding after a logical line cap did not solve a single-line adversary: a 25 MiB line still cost about **26.9 MiB**. The reader must terminate on a per-physical-line byte limit instead of consuming to the next newline.
- Against the real Git 2.53 process, a many-line cutoff stopped at 524,288 retained bytes / 5,008 newlines and reaped Git with SIGTERM in about 0.33 s; a single-line cutoff stopped on the first 64 KiB read after crossing a 16 KiB line budget and reaped Git in about 0.19 s.
- `--no-ext-diff` does **not** disable a configured `textconv` driver. A local fixture executed its configured `/usr/bin/xxd` converter until `--no-textconv` was added, after which Git emitted its normal binary summary.

The change crosses the App process boundary, the view-free diff model/parser, and the panel's empty/truncated presentation. It therefore needs an explicit design even though it adds no dependency or configuration.

## Goals / Non-Goals

**Goals:**

- Bound xtty's retained and subsequently materialized per-file diff input by fixed limits independent of total Git stdout.
- Bound both many-line output and a single line with no newline.
- Stop, close, and reap the Git child promptly when xtty reaches a preview limit.
- Preserve complete behavior for ordinary diffs and preserve the current parser/emphasis/view architecture.
- Surface every producer cutoff as a truncated preview with the existing open-in-editor escape hatch.
- Prevent configured text converters from turning a binary preview into arbitrary external output.
- Prove the bound deterministically at the accumulator seam and re-verify the user-visible/resource effect with real Git.

**Non-Goals:**

- Incrementally parse Git hunks while bytes arrive. Once the producer is bounded, the current batch parser is the lower-risk path.
- Add user-configurable limits, a full-file viewer, syntax highlighting, staging, or any repository write.
- Apply the diff limits to `status`, `rev-parse`, branch, or numstat output. Those record formats have separate correctness requirements; silently clipping the generic runner would be unsafe.
- Bound every allocation performed internally by Git before it emits stdout. This design bounds xtty's diff-output path and removes external text conversion; Git's own diff algorithm remains a child-process residual.
- Change the existing 3,000-`Character` presentation clip or the bounded intra-line emphasis algorithm.

## Decisions

### D1 — Add a diff-specific bounded producer; keep the generic runner complete

Add a per-file diff execution path beside `GitRunner.run`, with a result that distinguishes:

- launch failure;
- normal completion with an exit status; and
- an xtty-initiated cutoff with a reason and bounded stdout prefix.

Only the three preview invocations use it: tracked against `HEAD`, the fresh-repository staged fallback, and untracked `--no-index`. Repository discovery, status, branch, and numstat retain complete-output semantics.

This avoids a dangerous global change: a partial `status -z` or `numstat -z` record could silently produce a plausible but false repository snapshot. A reusable generic process-output framework is unnecessary for one proven call site and can be extracted later if another command earns the same policy.

**Alternative rejected — cap inside `DiffParser`:** the complete `Data`, `String`, and line array already exist before that cap.

**Alternative rejected — pipe through `head`, preflight file size, or write a temporary diff:** each adds another process or I/O surface, does not cover every generated-output shape, and still needs correct Git cleanup. The bound belongs where xtty owns the stdout pipe.

### D2 — Read 64 KiB chunks into a three-limit accumulator

The bounded reader uses blocking `FileHandle` reads on the existing off-main Git queue. A view-free accumulator retains only the accepted prefix and tracks physical records across arbitrary chunk boundaries.

| Limit | Value | Purpose |
| --- | ---: | --- |
| Read chunk | 64 KiB | Fixed transient read allocation; large enough to avoid syscall churn |
| Retained stdout | 4 MiB | Hard ceiling before `Data` becomes a `String` and parser-owned values |
| Physical newline records | 5,008 | Existing 5,000 preview-row budget plus a small fixed single-file header allowance |
| Current physical line | 16 KiB UTF-8 bytes | Stops a no-newline adversary while accommodating ordinary 3,000-character rows |

The accumulator scans bytes as they arrive, resets the current-line count on LF, and never appends a byte beyond a limit. If output ends exactly at a limit it is complete, not truncated: the reader attempts the next read and declares cutoff only when it observes additional output.

The three limits are independent by design:

- the record limit stops a huge count of short lines;
- the retained-byte limit stops a bounded line count containing broad lines; and
- the current-line limit stops one unbroken line without draining it.

The accumulator belongs in `XttyCore` so chunk-boundary and retention invariants are covered by the fast view-free tests. `Process` ownership remains in the App layer.

The fixed values are implementation policy, not user configuration. They cap the bounded prefix; total peak xtty growth can be a larger fixed multiple while `Data`, decoded `String`, parser arrays, and the final model briefly coexist, but it no longer scales with total Git output.

**Trade-off:** 16 KiB is byte-based while the existing presentation clip is character-based. It preserves ordinary 3,000-scalar UTF-8 lines (at most about 12 KiB) but can truncate pathological grapheme clusters containing many combining scalars. That is preferable to permitting an unbounded physical line; the editor remains the lossless escape hatch.

### D3 — Cutoff is an owned process state, never inferred from exit code

When any accumulator limit fires, the runner records the cutoff reason, asks the direct Git child to terminate, closes the pipe's read handle so no writer can remain blocked on xtty, and reaps the process. Give SIGTERM a short bounded grace period (250 ms); if the direct child is still running, send SIGKILL and then wait for its termination.

The result is successful preview data only when the runner's own cutoff state is present. A coincidental signal exit or nonzero status without that state remains an error and follows the existing HEAD→staged fallback rules. Conversely:

- tracked/staged cutoff is parsed instead of mistaken for a Git failure;
- untracked cutoff is parsed instead of rejected by the normal `--no-index` `0...1` status rule; and
- normal completion keeps its current status handling unchanged.

This explicit state avoids treating every exit status 15 as success. Publishing the selected diff happens only after the child has been reaped, which gives the end-to-end test a deterministic cleanup boundary.

**Alternative rejected — stop reading and call `waitUntilExit`:** Git can block forever writing to a full pipe.

**Alternative rejected — keep draining after the preview is full:** it bounds retained bytes for many-line input but not transient work or time for an arbitrarily long line, and it makes selecting a file wait for output the UI will discard.

### D4 — Keep batch parsing, but propagate producer truncation

Extend the parser seam with a producer/source-truncated input (default `false`). `DiffParser` ORs that flag with its existing per-line and per-model truncation conditions when constructing `FileDiff`. The bounded prefix is decoded with Swift's replacement behavior for a partial trailing UTF-8 sequence; because the model is explicitly truncated, that final lossy fragment cannot be mistaken for complete content.

The parser continues to split and classify the bounded prefix in one batch. This minimizes churn in proven hunk classification and intra-line emphasis while making all parser allocations a fixed function of the producer limits.

Producer truncation must survive every shape, including an empty or header-only parsed prefix. The UI presentation order becomes:

1. binary summary;
2. truncated-with-no-hunk → “Diff too large — open in editor” action;
3. complete-with-no-hunk → “No textual changes”;
4. rendered hunks, followed by the existing truncated open-in-editor action when needed.

`DiffEmphasis.refine` already copies `FileDiff.truncated` and remains separately bounded (`maxPairs = 5`, `maxLineBytes = 512`).

**Alternative rejected — fully incremental hunk parser:** it would couple stream lifecycle, UTF-8 boundary handling, hunk state, emphasis, and process termination in one change. The 4 MiB producer ceiling makes that complexity unnecessary.

### D5 — Disable text conversion throughout refresh and preview

Add `--no-textconv` alongside `--no-ext-diff --no-color` for tracked, staged, and untracked preview invocations. `--no-ext-diff` blocks external diff commands but does not block Git attributes/configuration from launching a text converter.

The snapshot's `diff HEAD --numstat -z` query also receives `--no-textconv`.
It remains on the generic complete-output runner—the record is not clipped—but
without this flag merely opening/refreshing Git review can execute the converter
before a file is selected. The intended P6 behavior is binary badges/summary,
not executing arbitrary conversion programs to synthesize text. A real fixture
with a converter that writes a sentinel proves the command is not run during
either refresh or preview, while Git's binary-summary parsing proves the
preview still degrades correctly.

### D6 — Verification combines hard invariants with by-effect probes

The deterministic gate is a view-free accumulator test matrix:

- small input completes byte-identically;
- retained-byte, physical-record, and current-line limits each fire independently;
- LF and UTF-8 sequences split at every relevant chunk boundary behave correctly;
- exact-limit EOF is complete while one additional byte is truncated;
- retained bytes never exceed 4 MiB and current-line state never exceeds 16 KiB, regardless of offered input size;
- parser-side and producer-side truncation are ORed, including empty/header-only prefixes.

Real-Git coverage then selects generated many-line and single-line fixtures through the panel and asserts:

- the selected diff becomes truncated;
- the open-in-editor escape hatch remains usable;
- the state arrives within a bounded timeout (which also proves the runner returned after reaping);
- no matching Git preview child remains; and
- an ordinary small diff remains complete.

The cleanup assertion observes the exact preview PID in the DEBUG state dump,
including the xtty-owned cutoff reason, reap completion, and an App-side
`kill(pid, 0) == ESRCH` absence check. This reaches the process-lifecycle claim
directly without trusting `Process.isRunning`. A runner-side `/bin/ps` probe was
measured unusable (`EPERM` under the XCUITest runner sandbox), so it is retired;
the separate real-App RSS probe retains an external command-line child census.

A focused before/after RSS probe repeats increasing 5/25/75 MiB inputs and records peak xtty footprint. The acceptance property is a plateau independent of total output, not an allocator-sensitive exact byte threshold; therefore RSS is preserved as by-effect evidence rather than a noisy CI hard gate. The configured-textconv sentinel fixture is a separate real-Git regression.

## Risks / Trade-offs

- **[Git may allocate heavily before emitting stdout]** → xtty's memory remains bounded and Git is stopped once the preview is full; `--no-textconv` removes the arbitrary converter process. A future Git-child resource policy or blob-size preflight is a separate change if measurement shows this residual matters.
- **[A legitimate broad or combining-heavy line truncates earlier than the old character clip]** → the limit is fixed and explicit, the preview is marked truncated, and open-in-editor preserves access to the complete file.
- **[Termination races leave a direct child alive]** → cutoff is an owned state, the pipe closes, SIGTERM has a bounded grace period, SIGKILL is the fallback, and publication occurs after reap.
- **[A partial final UTF-8 scalar renders a replacement character]** → only the final truncated fragment can be affected and the model/action clearly reports truncation.
- **[The XCUITest runner cannot spawn a process census]** → observe the exact PID's reap/absence through bounded DEBUG state, and independently census matching command lines in the real-App probe.
- **[Generic status output remains complete-buffered]** → this change does not claim otherwise. Status and numstat need record-aware limits and honest incomplete-state UX before they can be bounded.
- **[The fixed header allowance does not preserve exactly 5,000 content rows for an unusually fragmented diff]** → total physical records are strictly bounded and the user-visible contract promises a bounded preview, not an exact row count.

## Migration Plan

1. Add the view-free bounded accumulator and producer-truncation parser contract with unit tests.
2. Route only per-file previews through the bounded process path and add `--no-textconv`.
3. Correct the no-hunk truncated UI state and add real-Git/XCUITest coverage.
4. Re-run the focused RSS probe, record its evidence in the known-issues research ledger, then run the repository's full required validation.

There is no stored-data or configuration migration. Rollback is a code revert: no persisted format changes or repository mutations need cleanup.

## Open Questions

None. The limit shape, process ownership, textconv behavior, and verification split were settled by the exploration; implementation should re-measure the claimed effect rather than reopen the discarded buffering alternatives.
