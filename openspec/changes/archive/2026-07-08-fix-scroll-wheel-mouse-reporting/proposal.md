## Why

Full-screen apps that enable mouse tracking (htop, vim, tmux, fzf, less with mouse) **do not scroll with the mouse wheel** in xtty. Root-caused (source + a `cat -v` byte-capture verify-by-effect + a 5-terminal peer-consensus fan-out — `research/03-analysis/mouse-wheel-scroll-forensics.md`): xtty's embedded SwiftTerm `MacTerminalView.scrollWheel` unconditionally moves its own local scrollback and **never reads `terminal.mouseMode`**, so it emits **zero pty bytes** on the wheel; on the alternate screen that local scroll is a dead no-op (`maxScrollback = 0`). iTerm2 given the identical input scrolls htop a full page. This is a daily-driver correctness gap and the fix API already exists in SwiftTerm — `scrollWheel` just never calls it.

## What Changes

- Rewrite the wheel handler (SwiftTerm `MacTerminalView.scrollWheel(with:)`, delivered via the existing `patches/swiftterm/xtty-accessors.diff` mechanism) to implement the **priority-ordered 3-way branch** every mature terminal converges on:
  1. **mouse reporting active** (`terminal.mouseMode` is a `sendButtonPress()`-capable mode: `.vt200`/`.buttonEventTracking`/`.anyEvent`) → emit a **wheel mouse-report** (SGR button 64 up / 65 down, press-only, at the pointer cell) — this is the htop/vim/tmux fix;
  2. **alternate screen, mouse reporting off** (e.g. `less`/`man` without mouse) → emit **arrow keys** (Up/Down), DECCKM-aware (SS3 `ESC O A/B` when application-cursor mode is on, CSI `ESC [ A/B` otherwise) — the "alternate scroll" behavior;
  3. **primary screen, mouse off** → keep the existing **local scrollback** movement (unchanged).
- **Shift+wheel bypasses reporting → local scrollback** (the standard escape hatch, so users can read scrollback under a mouse-tracking app).
- Bound the emission: keep the existing `deltaY == 0` guard (no spurious vertical report on a pure horizontal swipe until 66/67 are wired), emit ~one report/arrow per accumulated row (not per hardware notch), and **collapse trackpad momentum** so a flick can't flood the pty.
- Expose the wheel-routing decision through the DEBUG state dump so it is deterministically testable on xtty's custom-drawn, accessibility-opaque view, and add end-to-end coverage.

Not in scope (first cut, per the research): a config knob (mouse-scroll multiplier / alt-scroll toggle), DECSET 1007 *parsing* (SwiftTerm parses no 1007 → the alt-screen fallback is unconditional, the kitty/WezTerm model), and **horizontal** wheel reports (buttons 66/67).

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `terminal-session`: add a requirement for **mouse-wheel routing to the terminal** — the 3-way branch (mouse-report / alt-screen arrow keys / local scrollback) plus the Shift-bypass and the anti-flood/horizontal guards. Extends the existing interactive-terminal behavior set without changing keyboard/resize/paste/scrollback/selection behavior.
- `verification-harness`: add a requirement that **mouse-wheel routing is observable** via the DEBUG state dump (the branch taken and, for the report branch, the emitted wheel button + count + cell; for the arrow branch, the emitted key sequence + count), and a requirement for **end-to-end coverage** driving the wheel in each branch and asserting the routed action.

## Impact

- **Product code:** `patches/swiftterm/xtty-accessors.diff` gains a hunk rewriting `MacTerminalView.scrollWheel(with:)` (reusing `Terminal.encodeButton`/`sendEvent`, `calculateMouseHit`, `terminal.applicationCursor`, `EscapeSequences.moveUp/DownApp/Normal` — all already public/present in `external/SwiftTerm @ v1.13.0`); the fix is filed upstream in parallel and the hunk retires on merge. The DEBUG state-dump seam (`XttyCore`/App) gains a wheel-routing field.
- **Behavior change (intended):** on the primary screen, when an app has mouse tracking on, the wheel now reports to the app instead of moving local scrollback (Shift+wheel preserves the old behavior). On the alt screen the wheel now scrolls the app (was a no-op).
- **Tests:** new XCUITest coverage + a `verification-harness` dump field; `make test-core` and the XCUITest suite must stay within the acceptance envelope. Upstream SwiftTerm bug filed (tracked out-of-band).
- **No** `terminal-configuration` change (no new key), **no** milestone-gate dependency (a standalone correctness fix, like `fix-osc7-hostname-reverse-dns`).
