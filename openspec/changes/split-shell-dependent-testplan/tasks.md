## 0. Precondition (apply-ordering gate)

- [ ] 0.1 Confirm `add-zsh-test-image` is applied and its divergence measured (bash-rig vacuous/red vs zsh-rig real-green) — this change's skip predicates + envelope numbers are grounded in that measurement; do not apply ahead of it.

## 1. Harness: expose bracketed-paste mode (verification-harness delta)

- [ ] 1.1 Add the focused pane's `bracketedPasteMode` to the DEBUG state dump (`App/UITestDump.swift` + the `writeStateDump` callers), read from `terminal.bracketedPasteMode` (SwiftTerm `public private(set)`), `#if DEBUG` + `-UITestGridDump`-gated, observe-only.
- [ ] 1.2 (verify, inline) One-off `-UITestGridDump` launches confirm the field reads correctly after the first prompt — false under bash 3.2, true under zsh. *(cheap iterate — inline)*

## 2. Partition the suite into two test plans

- [ ] 2.1 Add `Intersection.xctestplan` (shell-agnostic) + `ShellInteractive.xctestplan` (shell-dependent) and wire them under the scheme `testPlans:` in `project.yml`; their union SHALL be the whole suite.
- [ ] 2.2 (verify, inline) `xcodegen generate`; confirm both plans appear in the generated scheme and each test lands in exactly one plan (union = 42); `make test` still runs the full suite by default. *(cheap iterate — inline)*

## 3. Convert graceful degradation into honest skips (test-only)

- [ ] 3.1 Semantic-capture family: replace the silent `guard waitForSemanticCaptureActive() else { …; return }` with `throw XCTSkip(…)` in `XttySemanticCaptureUITests`, `XttySessionSidebarUITests`, `XttyBlockSidebarUITests`, `XttyGitReviewUITests`, `XttySpatialBlocksUITests`, `XttyFileLinkOpenUITests`.
- [ ] 3.2 `testMultiLinePasteIsNotAutoExecuted` (`XttyUITests.swift:62`): gate with `XCTSkipUnless(<focused pane bracketedPasteMode true>, …)` read from the state dump (1.1), sampled **after** the computed-marker shell-readiness gate (`harden-churn-shell-readiness`) — never before the first prompt.
- [ ] 3.3 Assign the i18n-paste half of `testTruecolorEmojiAndWideChars` to `ShellInteractive`; decide from change 1's measurement whether to factor its shell-agnostic ASCII-color assertion into an `Intersection` test (design Q2).

## 4. Validator: make the zsh rig a standing environment (test-validation delta)

- [ ] 4.1 Update `.claude/agents/xtty-test-validator.md` so a full sweep runs `ShellInteractive` on the zsh golden (bash rigs → shell-dependent set skips = expected; zsh rig → asserts), and update the enumerated environments; **bump the `Definition:` stamp** and update the `/xtty:validate` launcher's stamp check (agent-definition edits reach spawns with unpredictable lag — verify by report stamp, never assume delivery).

## 5. Reverse duty: reconcile the runtime docs (same change)

- [ ] 5.1 Update `packer/README.md` Acceptance/matrix: bash rig paste **red → skip**; `ShellInteractive` on bash = skips (expected), on zsh = real coverage; record both rigs' per-plan envelopes.
- [ ] 5.2 Update `research/03-analysis/github-actions-ci-cd.md` §19b: `bash32-no-bracketed-paste` is now an honest **skip** (not a red), covered green on the zsh rig.
- [ ] 5.3 (verify, inline) `openspec validate split-shell-dependent-testplan` passes; the proposal↔specs capability contract holds (verification-harness + test-validation). *(cheap — inline)*

## 6. Validate the split (acceptance)

- [ ] 6.1 (verify — full acceptance matrix, both rigs, per-plan) Run the matrix: bash rig (`Intersection` green; `ShellInteractive` skips) and zsh rig (`Intersection` green; `ShellInteractive` real green); confirm **no vacuous passes remain** (no `"…capture inactive…"` attachment coincides with a "passed") and no product red. ⟶ xtty-test-validator (full matrix, both goldens — bash `xtty-test:26.5` + zsh `xtty-test-zsh:26.5`, per-plan)
- [ ] 6.2 (verify — coherence, pre-archive) Review the change for coherence against AGENTS.md's rulebook + disk state, including the `add-zsh-test-image`→this archive ordering. ⟶ xtty-openspec-critic (split-shell-dependent-testplan)

## 7. On completion (post-verify)

- [ ] 7.1 Reconcile trackers per AGENTS.md "Keep progress current": Current-status table row + snapshot (the suite is split; both rigs' per-plan envelopes), append the narrative to `HISTORY.md`, advance `research/04-design/02-milestones.md` if applicable, and flip `research/03-analysis/shell-dependent-test-partitioning.md` from "decided" to "built + split". Confirm this change archives **after** `add-zsh-test-image`.
