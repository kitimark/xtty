## 1. SwiftTerm patch (the product fix)

- [ ] 1.1 In `patches/swiftterm/xtty-accessors.diff`, add a new hunk to `cmdScrollDown` (`Terminal.swift:4646`) mirroring `cmdScrollUp`'s existing `if marginMode { … } else { … }` shape (D1): keep the current narrow, margin-bounded `copyFrom` path when `marginMode` is true, unchanged; add an `else` branch doing a full-width whole-line `splice` — direction-mirrored from `cmdScrollUp`'s non-margin branch — deleting the line scrolling off `scrollBottom` and inserting a fresh blank line at `scrollTop`, per iteration of `p`.
- [ ] 1.2 Update the patch file's header comment to note it now also carries a `Terminal.swift` correctness fix, not only additive `MacTerminalView.swift` accessors (D2) — a departure from every prior hunk in this file, worth flagging explicitly for the next reader.
- [ ] 1.3 Re-run `scripts/bootstrap-swiftterm.sh` to confirm the revised patch applies cleanly from the pristine pin.

## 2. Tests

- [ ] 2.1 Add a fast, headless `XttyCoreTests` regression (the `NoopTerminalDelegate` + `Terminal(delegate:)` pattern from `TerminalSessionTests.swift`): enter the alternate screen (`DECSET 1049` — the confirmed-buggy configuration), set a scroll region via `DECSTBM`, write distinct full-width content into two or more rows inside the region, issue `SU` then `SD`, and assert every column of the shifted row reflects the correct content — not just column 0 (D3.1). This is the test that would have caught the original defect deterministically and fast.
- [ ] 2.2 Add an `AppUITests` end-to-end scenario (in `XttyMouseWheelUITests.swift`, mirroring `testWheelScrollsRealMouseTrackingPager`'s real-program pattern): drive a real full-screen mouse-tracking program through a wheel scroll some distance then a reversal, and assert via the DEBUG grid dump that the visible rows show correct, non-duplicated content afterward — not merely that the wheel gesture was routed (the existing routing coverage already asserts that) (D3.2).

## 3. Verify

- [ ] 3.1 `make test-core` — `XttyCore` regression including the new headless test (inline, cheap).
- [ ] 3.2 Run the Tier-1 XCUITest suite + full acceptance matrix (both goldens) and confirm the new end-to-end scenario is green with no regressions elsewhere. ⟶ xtty-test-validator (Tier-1 + full matrix, both goldens)

## 4. Upstream (deferred)

- [ ] 4.1 Note the upstream SwiftTerm PR opportunity (the `cmdScrollDown` margin-guard fix) as a deferred maintainer action, per the precedent set by `fix-scroll-wheel-mouse-reporting`/`smooth-scroll-wheel-momentum` — not filed as part of this change.

## 5. Coherence + archive (the standard change tail)

- [ ] 5.1 Pre-archive coherence review of this change. ⟶ xtty-openspec-critic (fix-scroll-reversal-redraw-corruption)
- [ ] 5.2 Archive + reconcile: `openspec archive`; correct the merged requirement text to reflect what actually shipped; reconcile the trackers (AGENTS.md Current-status row + snapshot, HISTORY.md narrative, `packer/README.md`'s expected-difference matrix row — flip from "root-caused, not yet fixed" to fixed, citing the new tests); verify against disk (`openspec list` / `ls openspec/changes/archive/` / `ls openspec/specs/`). ⟶ archive-ritual
