## 1. SwiftTerm patch (the product fix)

- [ ] 1.1 In `patches/swiftterm/xtty-accessors.diff`, add a new hunk to `cmdScrollDown` (`Terminal.swift:4646`) mirroring `cmdScrollUp`'s existing `if marginMode { … } else { … }` shape (D1): keep the current narrow, margin-bounded `copyFrom` path when `marginMode` is true, unchanged; add an `else` branch doing a full-width whole-line `splice` — direction-mirrored from `cmdScrollUp`'s non-margin branch — deleting the line scrolling off `scrollBottom` and inserting a fresh blank line at `scrollTop`, per iteration of `p`.
- [ ] 1.2 Update the patch file's header comment to note it now also carries a `Terminal.swift` correctness fix, not only additive `MacTerminalView.swift` accessors (D2) — a departure from every prior hunk in this file, worth flagging explicitly for the next reader.
- [ ] 1.3 Re-run `scripts/bootstrap-swiftterm.sh` to confirm the revised patch applies cleanly from the pristine pin.

## 2. Tests

- [x] 2.1 Add an `AppUITests` end-to-end scenario (`testScrollRegionReversalDoesNotCorruptOtherColumns` in `XttyMouseWheelUITests.swift`) driving the exact escape sequences directly via `printf` (D3): enter the alternate screen, set an 8-row scroll region, write three rows of distinct 10-character content, issue `SU` once then `SD` once, and assert row 1 is fully restored — not just column 0. Investigated and rejected driving a real full-screen program first (`vim`/`less`, bundled in the test VM, don't exercise the buggy `cmdScrollDown` path at all; `htop`, which does, is brew-only and absent from the VM image) — see D3's full rationale. Confirmed red against the current unfixed patch: row 1 reads `"BCCCCCCCCC"` instead of the expected `"BBBBBBBBBB"`, matching the hand-traced defect exactly. Ticket for re-verification once 1.1–1.3 land: this test must flip green.

## 3. Verify

- [ ] 3.1 `make test-core` — `XttyCore` regression (inline, cheap; no new headless test in this change — see D3).
- [ ] 3.2 Run the Tier-1 XCUITest suite + full acceptance matrix (both goldens) and confirm the new end-to-end scenario is green with no regressions elsewhere. ⟶ xtty-test-validator (Tier-1 + full matrix, both goldens)

## 4. Upstream (deferred)

- [ ] 4.1 Note the upstream SwiftTerm PR opportunity (the `cmdScrollDown` margin-guard fix) as a deferred maintainer action, per the precedent set by `fix-scroll-wheel-mouse-reporting`/`smooth-scroll-wheel-momentum` — not filed as part of this change.

## 5. Coherence + archive (the standard change tail)

- [ ] 5.1 Pre-archive coherence review of this change. ⟶ xtty-openspec-critic (fix-scroll-reversal-redraw-corruption)
- [ ] 5.2 Archive + reconcile: `openspec archive`; correct the merged requirement text to reflect what actually shipped; reconcile the trackers (AGENTS.md Current-status row + snapshot, HISTORY.md narrative, `packer/README.md`'s expected-difference matrix row — flip from "root-caused, not yet fixed" to fixed, citing the new tests); verify against disk (`openspec list` / `ls openspec/changes/archive/` / `ls openspec/specs/`). ⟶ archive-ritual
