## Context

xtty embeds SwiftTerm (`external/SwiftTerm @ v1.13.0` + `patches/swiftterm/xtty-accessors.diff`) and does **not** override `scrollWheel`. The whole bug is `MacTerminalView.scrollWheel(with:)` (`Mac/MacTerminalView.swift:2172`): it unconditionally calls `scrollUp`/`scrollDown` (local scrollback) and never reads `terminal.mouseMode`, so it emits nothing to the child; on the alternate screen `scrollUp`/`scrollDown` are no-ops (`maxScrollback = 0`). Full root-cause record, peer-consensus policy, byte-capture verify-by-effect, and the fates table: `research/03-analysis/mouse-wheel-scroll-forensics.md`. The fix API is already present in SwiftTerm — this change composes three patterns that `mouseMoved`/`mouseDown`/`pageUp` already use, into `scrollWheel`.

## Goals / Non-Goals

**Goals:**
- Full-screen mouse-tracking programs (htop, vim, tmux, fzf) scroll with the wheel (the report branch).
- Alt-screen programs without mouse tracking (pagers) scroll with the wheel (the arrow-key branch).
- Preserve local-scrollback wheel behavior on the primary screen, with a Shift-bypass escape hatch under mouse-tracking programs.
- Make the routing decision observable through the DEBUG state dump for deterministic tests.

**Non-Goals:**
- No config knob (mouse-scroll multiplier / alt-scroll toggle) — first cut is knob-free.
- No DECSET 1007 *parsing* — SwiftTerm parses no 1007, so the alt-screen fallback is unconditional (the kitty/WezTerm model); add real 1007 only if an app is observed disabling it.
- No **horizontal** wheel reports (buttons 66/67) — the `deltaY == 0` guard stays.
- No momentum-suppression research beyond a simple collapse (bounded emission is enough).

## Decisions

- **D1 — Deliver as a SwiftTerm patch hunk, upstream in parallel.** Add a hunk to `patches/swiftterm/xtty-accessors.diff` rewriting `scrollWheel(with:)`; file the fix upstream (it is a genuine SwiftTerm bug) and retire the hunk on merge — the same reconstitute-from-pin discipline the accessors already use. *Alternatives:* a fork (rejected — the no-fork patch strategy is deliberate); an xtty-side `scrollWheel` override in a `MacTerminalView` subclass (rejected — xtty hosts SwiftTerm's view directly and the coordinate/mouse-report helpers the fix needs are module-internal to SwiftTerm; overriding would duplicate `calculateMouseHit`/`sharedMouseEvent`).
- **D2 — The 3-way branch, gated in priority order.** Branch 1 gate = `allowMouseReporting && terminal.mouseMode.sendButtonPress()` — reusing `mouseDown`'s exact predicate (`sendButtonPress()` = `.vt200`/`.buttonEventTracking`/`.anyEvent`; excludes `.off` and `.x10`). Branch 2 = `terminal.isDisplayBufferAlternate`. Branch 3 = the existing `scrollUp`/`scrollDown`. *Alternative:* gate on "any `mouseMode != .off`" — **refuted**, it would send malformed wheel reports to X10 (DECSET 9) apps.
- **D3 — Wheel report via existing API.** `terminal.encodeButton(button: up ? 4 : 5, release: false, shift:…, meta:…, control:…)` (yields 64/65) → `terminal.sendEvent(buttonFlags:x:y:)`, **press-only** (no release). Emission format follows the app-negotiated `mouseProtocol` (defaults to `.x10` binary; SGR text only after the app sends DECSET 1006) — the fix is encoding-agnostic because it goes through `sendEvent`.
- **D4 — Coordinates from `calculateMouseHit(with:)`, reusing `sharedMouseEvent`'s math:** `x = hit.grid.col` (**0-based**; `sendEvent` adds `+1`), `y = max(0, min(rows-1, hit.grid.row - displayBuffer.yDisp))` (viewport-relative, clamped). *Alternative:* the synthesis's `cellCoordinates(from:)` / "1-based pointer cell" — **refuted** (nonexistent API; would double-increment). htop ignores wheel coords, but click-precise apps do not, so correctness matters.
- **D5 — Bounded emission, NOT `calcScrollingVelocity` as the report count.** `calcScrollingVelocity`'s `>9` bucket returns `max(rows,20)` → 20–32 reports for one fast notch → over-scroll past the iTerm baseline; it is a stateless per-event bucket, not a remainder-carrying accumulator. Emit ~one report/key per accumulated row (default ≈1 report per wheel event, iTerm's default), **collapse trackpad momentum** (ignore or coalesce `momentumPhase` events), and cap the per-gesture burst. The exact accumulator is finalized during apply against the report-count-vs-iTerm probe.
- **D6 — Arrow-key fallback is DECCKM-aware via public API.** `terminal.applicationCursor` (public, `:350`) selects `EscapeSequences.moveUpApp`/`moveDownApp` (SS3 `ESC O A/B`) vs `moveUpNormal`/`moveDownNormal` (CSI `ESC [ A/B`), sent per accumulated row. No new patch accessor needed.
- **D7 — Shift+wheel → local scrollback.** Route a Shift-modified wheel to Branch 3 (do **not** OR Shift into the report modifiers) — the xterm/iTerm2/kitty escape hatch. *Alternative:* send a shift-modified wheel report — rejected (removes the read-scrollback escape hatch users rely on).
- **D8 — Keep the `deltaY == 0` guard.** A purely horizontal gesture returns early (else it would compute a spurious wheel-down). Horizontal wheel reporting (66/67) is deferred.
- **D9 — Observability field (no product-behavior weight).** The wheel handler records its last routing decision (branch + button/key + direction + count) in the pane/terminal-view seam; `XttyCore`'s DEBUG state dump surfaces it (mirroring the "last link-open action" / "bracketed-paste mode" fields). Observe-only; DEBUG + `-UITestGridDump` gated.

## Risks / Trade-offs

- **Behavior change on the primary screen** (a mouse-tracking app now gets wheel reports instead of local scrollback) → mitigated by the Shift-bypass (D7); this matches every peer terminal and is the correct behavior, but is user-visible and called out here.
- **Momentum flooding** (a trackpad flick could emit hundreds of reports) → mitigated by D5's momentum collapse + per-gesture cap; validated by the report-count-vs-iTerm probe.
- **Synthetic-event test fidelity** — `CGEvent`/peekaboo wheel deltas can differ from a physical mouse, and the earlier "40 ticks = 1 line" was harness/re-sort noise → tests assert the deterministic **state-dump routing field** (D9), not a program's own scroll count, and the harness-fidelity probe runs **first** (per the research's probe #1).
- **Patch drift** if SwiftTerm is re-pinned → mitigated by upstreaming (D1) and the existing patch-reconstitution guard (`bootstrap-swiftterm.sh` reapplies; a failed apply is loud).
- **Coordinate correctness** for click-precise apps → mitigated by reusing `sharedMouseEvent`'s exact 0-based/`yDisp`-clamped math (D4).

## Migration Plan

1. Add the `scrollWheel` rewrite hunk to `patches/swiftterm/xtty-accessors.diff`; `scripts/bootstrap-swiftterm.sh` reapplies on next bootstrap.
2. Add the DEBUG wheel-routing field to the state dump; add XCUITest coverage.
3. File the fix upstream to SwiftTerm; when it merges into the pinned ref, drop the hunk (same retire-on-upstream pattern as the P4b-2 accessors).
- **Rollback:** revert the patch hunk + the dump field; `bootstrap` restores the pristine `scrollWheel`.

## Open Questions

- **Anti-flood policy exact shape** — ~1 report per wheel event vs a cross-event whole-row accumulator with a cap N; decided during apply by matching iTerm2's ≈1-report-per-notch baseline (report-count probe).
- **Does any target app disable alternate-scroll (`?1007l`)?** If observed, escalate from the unconditional model to real DECSET 1007 parsing. Low priority — flag, don't block.
- **Physical-mouse re-confirm** — verify the fix with a real Magic Mouse/trackpad beyond synthetic events (the synthetic stream under-represents hi-res deltas; the iTerm control makes the current comparison valid but a hardware pass is worth one manual check).
