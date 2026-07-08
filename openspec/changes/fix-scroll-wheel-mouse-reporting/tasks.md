## 1. Product fix — rewrite `scrollWheel` (SwiftTerm patch hunk)

- [ ] 1.1 In `patches/swiftterm/xtty-accessors.diff`, rewrite `MacTerminalView.scrollWheel(with:)` as the priority-ordered 3-way branch (design D2). **Branch 1** (mouse reporting): gate on `allowMouseReporting && terminal.mouseMode.sendButtonPress()`; emit a wheel report via `terminal.encodeButton(button: up ? 4 : 5, release: false, shift/meta/control from modifierFlags)` → `terminal.sendEvent(buttonFlags:x:y:)`, **press-only**, at `calculateMouseHit(with:)` coords reused from `sharedMouseEvent` — `x = hit.grid.col` (0-based), `y = max(0, min(rows-1, hit.grid.row - displayBuffer.yDisp))` (design D3/D4).
- [ ] 1.2 **Branch 2** (alt screen, mouse off): send cursor Up/Down keys per accumulated row, DECCKM-aware via public `terminal.applicationCursor` selecting `EscapeSequences.moveUp/DownApp` (SS3) vs `moveUp/DownNormal` (CSI) (design D6).
- [ ] 1.3 **Branch 3** (primary, mouse off): keep the existing `scrollUp`/`scrollDown` local scrollback. Add the **Shift-bypass** — a Shift-modified wheel routes to Branch 3 even under mouse reporting (design D7). Keep the `deltaY == 0` early-return so a purely horizontal gesture emits nothing (design D8).
- [ ] 1.4 **Bounded emission** (design D5): emit ~one report/key per accumulated row (default ≈1 per wheel event), collapse trackpad momentum (skip/coalesce `momentumPhase`), cap the per-gesture burst — do **not** use `calcScrollingVelocity` as the report count.
- [ ] 1.5 Reapply the patch (`scripts/bootstrap-swiftterm.sh`) and confirm the app builds (`make build`).

## 2. Observability — DEBUG wheel-routing state-dump field

- [ ] 2.1 Record the last wheel-routing action (branch taken + emitted button/key form + direction + count) in the pane/terminal-view seam and surface it in `XttyCore`'s DEBUG state dump (design D9), gated by `#if DEBUG` + `-UITestGridDump`, observe-only — satisfies the `verification-harness` "Mouse-wheel routing is observable" requirement.

## 3. Tests — end-to-end coverage

- [ ] 3.1 **Harness-fidelity precheck first** (research probe #1): with `mouseMode == .off` on the primary screen, N synthetic wheel ticks move scrollback a deterministic, monotonic amount and the gesture injects no stray click/keypress — establishes the synthetic-event generator is faithful before trusting routing assertions.
- [ ] 3.2 Add XCUITest coverage for the four `verification-harness` scenarios, asserting via the wheel-routing dump field: alt-screen mouse-tracking → wheel-report branch; alt-screen no-mouse → cursor-key branch; primary no-mouse → local scrollback; Shift+wheel under mouse reporting → local scrollback.
- [ ] 3.3 Update `packer/README.md` Acceptance/expected-difference matrix for the added tests (the reverse-duty: any change to test counts/expected residuals updates the living envelope in the same session).

## 4. Verify & accept

- [ ] 4.1 Iterate (inline): `make test-core`, and one-off `-UITestGridDump` wheel launches over htop/less to eyeball each branch and the emitted routing field.
- [ ] 4.2 Verify-by-effect (inline): the report-count-vs-iTerm baseline probe (≈1 report/notch, momentum bounded), the Branch-2 pager probe (DECCKM flips `ESC [ B` → `ESC O B`), the horizontal-guard probe, and the Shift-bypass probe — plus the `cat -v` byte capture confirming the report is now emitted under htop's modes (`\e[?1002h\e[?1006h`).
- [ ] 4.3 Full acceptance: run the Tier-1 XCUITest suite locally and on both VM goldens against the acceptance envelope ⟶ xtty-test-validator (Tier-1 local + headless + graphics VM, both bash & zsh goldens).

## 5. Upstream

- [ ] 5.1 File the `scrollWheel` fix upstream to SwiftTerm (it is a genuine upstream bug); record the issue/PR link in the change and note the retire-on-merge plan for the patch hunk (design D1).

## 6. Coherence & completion (standard change tail)

- [ ] 6.1 Pre-archive coherence review ⟶ xtty-openspec-critic (fix-scroll-wheel-mouse-reporting)
- [ ] 6.2 Archive + reconcile trackers ⟶ archive-ritual
