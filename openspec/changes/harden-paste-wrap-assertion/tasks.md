## 1. Fix the multi-line-paste content assertions

- [ ] 1.1 In `AppUITests/XttyUITests.swift`, change the `:82` and `:84` assertions in `testMultiLinePasteIsNotAutoExecuted` from strict `GridDumpReader.waitForContains(lineA/lineB, timeout: 5)` to the wrap-tolerant `GridDumpReader.waitForContains(lineA/lineB, timeout: 5, ignoringLineWraps: true)`, mirroring `:53` and `:198`; keep the surrounding flow (pasteboard set → Cmd+V → assert lines reached grid → `:87` not-executed check → `Ctrl+U` clear) unchanged.
- [ ] 1.2 Leave the `:87` negative "command not found" check strict (design D3) — do not touch it.
- [ ] 1.3 Add/extend the inline comment at the `:82`/`:84` call sites noting a pasted line can soft-wrap behind a long prompt (the wide-prompt zsh-rig case), that paste insertion is still what's asserted, and that the bash execution arm (`:87`) is a separate shell-capability concern owned by `split-shell-dependent-testplan`.

## 2. Confirm the existing regression guard covers this (no new guard — design D2)

- [ ] 2.1 Confirm `testSoftWrapGuardIsWrapTolerant` (shipped by `harden-findbar-wrap-assertion`) is present in `AppUITests/XttyUITests.swift` and still deterministically proves the wrap-tolerant matcher is required and works (strict whole-token match false, wrap-tolerant true) independent of prompt width. No new guard is added; record this in the change (do not duplicate the guard).

## 3. Verify

- [ ] 3.1 Iterate inline while coding: `make test-core` (matcher/unit sanity) and `xcodebuild build-for-testing` to confirm the edited `:82`/`:84` assertions compile under the real toolchain. (Inline — cheap iterate tier.)
- [ ] 3.2 Acceptance (regression): run the Tier-1 local XCUITest suite (`make test`) and confirm `testMultiLinePasteIsNotAutoExecuted` still passes locally (local prompt does not wrap), the existing guard passes, and no strict-default caller regressed. ⟶ xtty-test-validator (Tier-1 local XCUITests)
- [ ] 3.3 Acceptance (red→green proof): on the wide-prompt **zsh** VM rig (`xtty-test-zsh:26.5`), confirm `testMultiLinePasteIsNotAutoExecuted` **flips from the reproduced `:82` red to green** under the wide prompt — the in-guest fix proof — and the zsh-rig envelope moves `40/1/1` → `41/0/1`; confirm 0 `capture inactive` (semantic family still asserts for real) and no Local-Network/modal regression. ⟶ xtty-test-validator (zsh VM graphics+headless — paste :82 red→green)

## 4. Reverse-duty tracker updates (same session)

- [ ] 4.1 `packer/README.md` Acceptance/matrix: correct the "Bracketed-paste — zsh grid-capture arm" row cause from "staged/highlighted region scrape miss" to **prompt-width soft-wrap (find-bar wrap class)** and move it residual → **fixed** (wrap-tolerant matcher at `:82`/`:84`; a recurrence is now a REGRESSION); flip the zsh-rig envelope `40/1/1` → **`41/0/1`**; leave the bash-rig `:87` execution-arm row and the bash envelope `40/1/1` unchanged.
- [ ] 4.2 `research/03-analysis/github-actions-ci-cd.md` §19b: update the `add-zsh-test-image` zsh cross-check note so the paste guarantee on zsh reads as **exercised via a now wrap-tolerant `:82`** (fixed), not a strict-matcher residual; the hosted-CI bash `:87` residual (`bash32-no-bracketed-paste`) is unchanged (CI runs bash).
- [ ] 4.3 `research/03-analysis/shell-dependent-test-partitioning.md`: correct the characterization so the zsh `:82` paste red is a **matcher fix (this change)**, not a `split-shell-dependent-testplan` skip candidate; only the bash `:87` execution arm is shell-dependent (skip). Update the strategy/divergence bullets accordingly.
- [ ] 4.4 `openspec/changes/split-shell-dependent-testplan/design.md`: add a one-line interaction pointer — the zsh `:82` soft-wrap red is fixed by `harden-paste-wrap-assertion`; the split change's `XCTSkipUnless(bracketedPasteMode)` skips only the **bash** execution arm and must preserve the `:82`/`:84` wrap-tolerance (design D4). Minimal edit, no restructuring.

## 5. Close-out

- [ ] 5.1 `openspec validate harden-paste-wrap-assertion` (fix any delta/scenario errors) and confirm the `verification-harness` MODIFIED "Soft-wrap-robust content assertion" requirement pasted the **full** existing block (all four prior scenarios verbatim) then extended it (prose adds multi-line-paste coverage; 1 new scenario for a soft-wrapped pasted line). (Inline — cheap validate tier.)
- [ ] 5.2 Pre-archive coherence review of the change (and the active change-set, incl. the `split-shell-dependent-testplan` interaction / red→green framing). ⟶ xtty-openspec-critic (harden-paste-wrap-assertion)
- [ ] 5.3 Archive + reconcile: `openspec archive harden-paste-wrap-assertion`, finish the merge by hand (verify the `verification-harness` block merged correctly), then update trackers per Keep-progress-current — AGENTS.md Current-status snapshot + table row, append the narrative to HISTORY.md, milestone state if any (none expected — test-hardening tooling), Learned-refutations unaffected — and verify-against-disk (`openspec list`, `ls openspec/changes/archive/`, `ls openspec/specs/`). ⟶ archive-ritual
