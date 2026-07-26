## 1. XttyCore — bounded diff input + parser contract

- [x] 1.1 Add view-free `DiffOutputLimits`, cutoff-reason/result values, and a bounded diff accumulator with the design defaults: 64 KiB read chunks, 4 MiB retained stdout, 5,008 physical newline records, and 16 KiB for the current physical line.
- [x] 1.2 Implement chunk ingestion across arbitrary boundaries: count LF records and current-line UTF-8 bytes, retain no byte beyond a limit, distinguish exact-limit EOF from observed excess output, and expose the bounded prefix plus its cutoff state.
- [x] 1.3 Extend `DiffParser` with a default-false producer/source-truncated input and OR it with the existing parser caps, including empty/header-only prefixes; confirm `DiffEmphasis.refine` preserves the result.
- [x] 1.4 Add `XttyCore` unit tests for byte-identical small input; every cutoff reason; exact-limit versus one-byte-over behavior; split LF/UTF-8 boundaries; one no-newline line; retained/current-line invariants across increasing offered input; and parser-side/producer-side truncation propagation.
- [x] 1.5 Mutation-check the discriminator tests by temporarily disabling each of the retained-byte, record, and current-line guards in turn and confirming its corresponding test fails; restore the production limits before ticking.

## 2. App — cutoff-aware Git process lifecycle

- [x] 2.1 Add a per-file diff runner in `App/GitRunner.swift` that feeds 64 KiB stdout reads into the bounded accumulator and returns launch failure, normal completion, or an xtty-owned cutoff distinctly; leave the generic complete-output runner unchanged.
- [x] 2.2 On cutoff, record ownership before signaling, request SIGTERM, close the read handle, allow the 250 ms grace period, fall back to SIGKILL if the direct Git child is still running, and reap it before returning.
- [x] 2.3 Route tracked-HEAD, fresh-repository staged, and untracked `--no-index` previews through the bounded runner; parse an xtty-owned cutoff regardless of its signal status while preserving the existing normal exit-code and HEAD→staged fallback rules.
- [x] 2.4 Add `--no-textconv` beside `--no-ext-diff --no-color` on every per-file preview invocation and on snapshot numstat so configured converters cannot execute during refresh or expand binary preview output.

## 3. Panel behavior + real-Git regressions

- [x] 3.1 Update `GitReviewView` so a truncated diff with no complete hunk presents “Diff too large — open in editor” and invokes the existing opener, while a complete no-hunk diff still presents “No textual changes” and binary files retain their summary.
- [x] 3.2 Extend the existing ordinary real-Git XCUITest to assert its selected diff is complete (`truncated == false`) so the bounded path cannot silently truncate normal input.
- [x] 3.3 Add parameterized real-Git XCUITest coverage using production limits for a many-line file and a single overlong line: select each through the real Git-review seam, assert bounded-time publication with `selectedDiff.truncated == true`, drive the open-in-editor escape hatch, and assert the DEBUG observation's exact preview PID is reaped and OS-absent after publication.
- [x] 3.4 Add a real repository fixture with a configured textconv driver that writes a sentinel; select its binary file and assert the sentinel is absent and `selectedDiff.isBinary == true`.

## 4. Verify + capture the settled mechanism

- [x] 4.1 Run `make test-core` and confirm the accumulator/parser suite and all existing `XttyCore` tests pass. — 260 passed, 0 failed, 0 skipped
- [x] 4.2 Re-run the focused 5/25/75 MiB many-line RSS probe plus the 25 MiB single-line probe against the implemented App path; preserve exact commands/results as evidence and verify peak xtty growth plateaus independently of total output, both cutoff shapes finish promptly, and no Git child lingers.
- [x] 4.3 Update KI-1 in `research/03-analysis/known-product-issues.md` with the measured pre/post mechanism, exact reproducible probes and their limits, failed approaches (parser-only cap, drain/discard, stop-reading-then-wait, `--no-ext-diff` alone), evidence pointers, the Git-child residual, re-verify-by-effect instructions, and the implementation/archive state.
- [ ] 4.4 Run the Tier-1 XCUITest suite with no retry flags and confirm the new real-Git cases and existing suite are green. ⟶ xtty-test-validator (Tier-1 `make test`) — BLOCKED: the no-retry run was 46/11/1 of 58 while Codex was running inside an already-live same-bundle xtty; 10 shared activation reds plus an invalid runner-side `ps` probe. The corrected exact-PID many-line arm passed, but the single-line arm attached to the two developer windows. Requires an isolated local rerun with no other xtty instance.
- [x] 4.5 Update `packer/README.md`'s authoritative acceptance counts if either the `XttyCore` or XCUITest totals moved (reverse duty for the added tests).
- [x] 4.6 Run `openspec validate fix-large-diff-memory-bound --strict` and reconcile any proposal/design/spec/task drift exposed by the implemented behavior.

## 5. Land the change

- [x] 5.1 Pre-archive coherence review of the change against AGENTS.md's rulebook, the OpenSpec coherence checklist, and live disk state. ⟶ xtty-openspec-critic (fix-large-diff-memory-bound) — implementation/artifact coherence clean at `30cb8c4`; archive remains blocked only on task 4.4's isolated Tier-1 acceptance.
- [ ] 5.2 Human-attestation cross-review for the implementation-bearing reviewed range (the planned `App/*.swift` and `XttyCore/*.swift` paths are outside the docs/tracker allowlist; do not treat the range classifier's verdict as attribution to this change). After all reviewable work is committed, run `/xtty:cross-review fix-large-diff-memory-bound` and read the complete ledger. Then, on a clean tree, run `scripts/cross-review-digest.sh --line fix-large-diff-memory-bound | pbcopy` yourself and paste its delimited attestation line below. Source the pasted line only from a command the human ran in their own terminal; a line in a model transcript or a model-populated clipboard is not attestable provenance. **HUMAN-ONLY — the model MUST NOT tick this task or derive/write the attested value.**
- [ ] 5.3 Archive + reconcile: run the cross-model gate's step-0 precondition, archive and merge the spec delta, finish the merged spec by hand, update the Current-status row/snapshot/HISTORY/milestone/refutations as applicable, and verify active changes + archives + specs against disk. ⟶ archive-ritual
