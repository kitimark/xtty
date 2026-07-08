## 0. Precondition (apply-ordering gate)

- [ ] 0.1 Confirm `add-zsh-test-image` is archived and its divergence measured (bash-rig vacuous/red vs zsh-rig real-green) and that `harden-paste-wrap-assertion` has landed (wrap-tolerant zsh paste `:82`/`:84`) — this change's per-shell assertions + per-test assert/skip decisions are grounded in that measurement; if `harden-paste-wrap-assertion` has not landed, fold its wrap-tolerance into task 2. Recommended order: `harden-paste-wrap-assertion` → this change.

## 1. Harness: expose bracketed-paste mode (verification-harness delta)

- [ ] 1.1 Add the focused pane's `bracketedPasteMode` to the DEBUG state dump (`App/UITestDump.swift` + the `writeStateDump` callers), read from `terminal.bracketedPasteMode` (SwiftTerm `public private(set)`), `#if DEBUG` + `-UITestGridDump`-gated, observe-only.
- [ ] 1.2 (verify, inline) One-off `-UITestGridDump` launches confirm the field reads correctly after the first prompt — false under bash 3.2, true under zsh. *(cheap iterate — inline)*

## 2. Parameterize the multi-line-paste test per shell (test-only)

- [ ] 2.1 Rename `testMultiLinePasteIsNotAutoExecuted` (`XttyUITests.swift:62`) to a capability-neutral name (e.g. `testMultiLinePasteMatchesShellBracketing`) and branch on the focused pane's **observed** `bracketedPasteMode` (from 1.1), read from the state dump **after** the computed-marker shell-readiness gate (`harden-churn-shell-readiness`) — never before the first prompt (design D5).
- [ ] 2.2 zsh / bracketed-on arm: assert both pasted lines are present in the grid (keep the wrap-tolerant matcher from `harden-paste-wrap-assertion`) and that `"command not found"` is **absent** (staged, not executed).
- [ ] 2.3 bash 3.2 / bracketed-off arm: assert the newline-terminated first line was **executed** (`"command not found"` present) while the unterminated tail line remains **staged** — xtty's faithful forwarding (design D2). Assert exactly one execution (no second `command not found` for the tail).
- [ ] 2.4 (verify, inline) One-off/focused run confirms the branch selects correctly and each arm asserts. *(cheap iterate — inline)*

## 3. Parameterize the semantic-capture family (test-only)

- [ ] 3.1 For `XttySemanticCaptureUITests`, `XttySessionSidebarUITests`, `XttyBlockSidebarUITests`, `XttyGitReviewUITests`, `XttySpatialBlocksUITests`, `XttyFileLinkOpenUITests`: when `waitForSemanticCaptureActive()` is true, assert the real behavior (blocks form; sidebar populates). When false, assert a **crisp capability-absent negative** where one is meaningful and cheap (e.g. no OSC 133 command boundaries / the semantic sidebar stays empty); only where no meaningful assertion exists, replace the silent `guard … else { return }` with `throw XCTSkip(…)`. Decide each method's arm from `add-zsh-test-image`'s measured divergence (which produced a `"…capture inactive…"` attachment) — design D4/Q2.
- [ ] 3.2 The i18n-paste half of `testTruecolorEmojiAndWideChars` (delivers emoji/CJK via Cmd+V) parameterizes like the paste test (2.x); keep its shell-agnostic ASCII-color assertion asserting on every shell.

## 4. Validator: make the zsh rig a standing environment (test-validation delta)

- [ ] 4.1 Update `.claude/agents/xtty-test-validator.md` so a full sweep runs the whole suite on the zsh golden (capability-present arm asserts; bash rig runs the same suite on the capability-absent arm), and update the enumerated environments; **bump the `Definition:` stamp** and update the `/xtty:validate` launcher's stamp check (agent-definition edits reach spawns with unpredictable lag — verify by report stamp, never assume delivery).

## 5. Reverse duty: reconcile the runtime docs (same change)

- [ ] 5.1 Update `packer/README.md` Acceptance/matrix: the paste test's **bash execution arm** is now an **asserted** bash behavior (not a red, not a skip); the semantic family is asserted-or-last-resort-skip; record both rigs' full-suite envelopes (no per-plan split).
- [ ] 5.2 Update `research/03-analysis/github-actions-ci-cd.md` §19b: `bash32-no-bracketed-paste` is now an **asserted bash execution arm** on the bash rig / hosted CI (not a red), covered on both arms.
- [ ] 5.3 (verify, inline) `openspec validate split-shell-dependent-testplan` passes; the proposal↔specs capability contract holds (verification-harness + test-validation). *(cheap — inline)*

## 6. Validate (acceptance)

- [ ] 6.1 (verify — full acceptance matrix, both rigs) Run the matrix on both goldens: bash rig (shell-dependent tests assert their bash arm, or last-resort-skip) and zsh rig (assert their zsh arm); confirm **no vacuous passes remain** (no `"…capture inactive…"` attachment coincides with a "passed"), no product red, and the paste test green on **both** arms. ⟶ xtty-test-validator (full matrix, both goldens — bash `xtty-test:26.5` + zsh `xtty-test-zsh:26.5`)
- [ ] 6.2 (verify — coherence, pre-archive) Review the change for coherence against AGENTS.md's rulebook + disk state, including the sibling `harden-paste-wrap-assertion` interaction (the paste-test rename supersedes its `:82`/`:84` edits) and the archive ordering. ⟶ xtty-openspec-critic (split-shell-dependent-testplan)

## 7. On completion (post-verify)

- [ ] 7.1 Reconcile trackers per AGENTS.md "Keep progress current": Current-status table row + snapshot (the shell-dependent tests are parameterized per shell; both rigs' full-suite envelopes), append the narrative to `HISTORY.md`, advance `research/04-design/02-milestones.md` if applicable, and flip `research/03-analysis/shell-dependent-test-partitioning.md` from "decided" to "built + parameterized" (note the pivot away from the test-plan partition). Confirm this change archives **after** `harden-paste-wrap-assertion`.
- [ ] 7.2 Archive + reconcile: run the full ritual — `openspec archive split-shell-dependent-testplan` (merge the `verification-harness` + `test-validation` deltas), finish-by-hand (correct the merged text to what shipped, `openspec validate --all --type spec`), confirm the trackers reconciled (7.1) + the archive ordering, and verify against disk (`openspec list`, `ls openspec/changes/archive/`, `ls openspec/specs/`). ⟶ archive-ritual
