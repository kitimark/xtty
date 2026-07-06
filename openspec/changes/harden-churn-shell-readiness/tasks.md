# Tasks: harden-churn-shell-readiness

## 1. Dump liveness during modals (App, DEBUG-only)

- [ ] 1.1 In `App/XttyApp.swift` (~line 194), construct the dump `Timer` explicitly and register it via `RunLoop.main.add(timer, forMode: .common)` (replacing `Timer.scheduledTimer`'s `.default`-mode-only registration), leaving the `#if DEBUG` + `-UITestGridDump` gating untouched
- [ ] 1.2 Sanity-check no behavior change outside modals: build + run one existing dump-consuming XCUITest (e.g. `testBasicTypedEcho`) green

## 2. Churn test — shell-readiness gate + asserted steps (test-only)

- [ ] 2.1 In `AppUITests/XttyLifecycleCensusUITests.swift`, set `continueAfterFailure = false` and convert every discarded `_ = StateDumpReader.waitForState(...)` in both churn loops into hard assertions that name the loop and iteration on failure
- [ ] 2.2 Pane loop: after the `paneCount == 2` wait, type `echo $((41000+i))` (unique per iteration, i = 1…4) and require `GridDumpReader.waitForContains` of the computed output token with `timeout: 15`, `ignoringLineWraps: true`; on timeout attach the grid dump, fail, and return without sending ⌘W
- [ ] 2.3 Tab loop: same gate with `echo $((42000+i))` (i = 1…3) between the `tabCount == 2` wait and ⌘W
- [ ] 2.4 Keep the final settle-and-assert census logic unchanged (the leak-net assertion itself is not modified)

## 3. Verification

- [ ] 3.1 Run the churn test 5× consecutively locally (`xcodebuild test … -only-testing:xttyUITests/XttyLifecycleCensusUITests`) — expect 5/5 green against the recorded F/F/P baseline; if any run fails, treat it as the design's D6 escalation signal (do not add retries)
- [ ] 3.2 ⟶ xtty-test-validator (full sweep) — full-suite acceptance (`make test`, bench e2e opt-in/skipped): **delegate to the validator** per AGENTS.md → test-validation (a product-code change gets the agent's full-sweep default — Tier 0+1 + headless ×2 + graphics — so the churn fix is exercised across local *and* the VM rigs where the per-launch race lives), and tick from the report's verbatim counts rather than running the suite inline (retrofit by `harden-validator-delegation-trigger`)
- [ ] 3.3 `openspec validate "harden-churn-shell-readiness"` passes
- [ ] 3.5 **Archive-time reconciliation (three-way, inserted by `fix-main-menu-clobber`):** this change's `verification-harness` delta MODIFIES the shared "Deterministic content assertion channel" requirement, which `retire-metal-renderer` and `fix-main-menu-clobber` also MODIFY. Before `openspec archive`, re-paste the then-current established block from `openspec/specs/verification-harness/spec.md` into this change's delta and re-apply only this change's own edit (the modal-liveness dump sentence/scenario), so an earlier-archived sibling's merged text (e.g. `fix-main-menu-clobber`'s `mainMenuTitles`/`windowCount` sentence + two scenarios) is not silently reverted
- [ ] 3.4 Document the expected CI readout in the change (commit message or PR note): churn stays red on CI until `fix-main-menu-clobber` lands (different root cause — pre-registered), so a red CI churn is not a regression of this change

## 4. Trackers

- [ ] 4.1 Update `AGENTS.md` Current status / open-changes narrative and `research/04-design/02-milestones.md` (change implemented; test counts refreshed), and note the implementation result in `research/03-analysis/confirm-close-shell-readiness.md` as a dated addendum if anything diverged from the §5 design
