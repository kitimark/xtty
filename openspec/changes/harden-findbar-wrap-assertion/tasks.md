## 1. Fix the find-bar focus-restore assertion

- [ ] 1.1 In `AppUITests/XttyUITests.swift`, change the `:192` assertion in `testFindBarOpensLocatesAndDismisses` from the strict `GridDumpReader.waitForContains(marker, timeout: 5)` to the wrap-tolerant `GridDumpReader.waitForContains(marker, timeout: 5, ignoringLineWraps: true)`, mirroring `testFocusTypingOnActivateWithoutClicking` at `:53`; keep the surrounding flow (type marker → assert reached grid → `Ctrl+U` clear) unchanged.
- [ ] 1.2 Add/extend the inline comment at the call site noting the marker can soft-wrap behind a long prompt (the hosted-runner `findbar-marker-wrap` case) and that focus restoration is still what's asserted — pointing to `ci-runner-prompt-width-forensics.md`.

## 2. Deterministic soft-wrap regression guard

- [ ] 2.1 Add a new test to `AppUITests/XttyUITests.swift` (DEBUG/`-UITestGridDump`-gated, matching the file's other dump-gated assertions) that types a **single contiguous marker wider than the focused pane** (e.g. ≥ ~120 chars of a unique random token) at the prompt.
- [ ] 2.2 Make the guard **self-validating**: assert (a) a **strict** `waitForContains(marker)` returns *false* (the marker genuinely spanned ≥2 physical rows — a real wrap occurred), and (b) the wrap-tolerant `waitForContains(marker, ignoringLineWraps: true)` returns *true*. The test can never pass without a real wrap; if the marker unexpectedly does not wrap, (a) fails loudly (widen the marker).
- [ ] 2.3 Clear staged input (`Ctrl+U`) at the end, consistent with the sibling type-at-prompt tests.

## 3. Verify

- [ ] 3.1 Iterate inline while coding: `make test-core` (matcher/unit sanity) and a one-off `-UITestGridDump` launch or a focused run of the two tests to confirm the guard wraps and the find-bar assertion passes locally. (Inline — cheap iterate tier.)
- [ ] 3.2 Acceptance: run the Tier-1 local XCUITest suite (`make test`) and confirm the new guard passes, `testFindBarOpensLocatesAndDismisses` still passes locally, and no strict-default caller regressed. ⟶ xtty-test-validator (Tier-1 local XCUITests)
- [ ] 3.3 If `add-vm-prompt-width-parity` was applied first (the red→green order): on the wide-prompt VM rig, confirm `testFindBarOpensLocatesAndDismisses` **flips from the reproduced red to green** under the same wide prompt — the in-guest fix proof (and update the wide-prompt envelope to find-bar green). ⟶ xtty-test-validator (graphics VM — find-bar red→green)
- [ ] 3.4 Post-merge: watch the next `build-and-test` run (`gh run watch` — inline) and confirm the find-bar red flips green under the runner's real long-prompt wrap; `test-core` stays green. If it is unexpectedly still red, investigate the run ⟶ xtty-ci-investigator (<run>).

## 4. Reverse-duty tracker updates (same session)

- [ ] 4.1 `research/03-analysis/github-actions-ci-cd.md` §19b: move the `findbar-marker-wrap` bucket from known-benign residual → **fixed** (note the shipped fix: wrap-tolerant matcher at `:192`); update the §19b "Fixes" line and the intro provenance so a future CI investigation classifies a recurrence as a **regression**, not a benign residual.
- [ ] 4.2 `packer/README.md` Acceptance: refresh the note to reflect the assertion is now wrap-tolerant (fixed). If applied after `add-vm-prompt-width-parity`, record that find-bar was the *reproduced red* on the wide-prompt VM and this change greens it (the final envelope carries find-bar green); otherwise note the count is unchanged (find-bar passed on the short-`\h` VM).
- [ ] 4.3 `research/03-analysis/ci-runner-prompt-width-forensics.md`: add a dated line in §6 recording that Option A (wrap-tolerant fix) + the deterministic guard landed, with the change name.

## 5. Close-out

- [ ] 5.1 `openspec validate harden-findbar-wrap-assertion` (fix any delta/scenario errors) and confirm the `verification-harness` MODIFIED requirement pasted the full existing block.
- [ ] 5.2 On archive, update the AGENTS.md Current-status snapshot/table and append the narrative to HISTORY.md (per Keep-progress-current); the Learned-refutations bullet is unaffected (the *reproducibility* refutation still holds — the fix doesn't make the runner hostname derivable).
