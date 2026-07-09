## Why

The shipped mouse-wheel routing fix (`fix-scroll-wheel-mouse-reporting`) made htop/pagers/scrollback scroll again, but its two anti-flood guards regressed **trackpad feel**: a blanket `momentumPhase` drop and a cap-and-discard accumulator that xtty's own `scrollWheel` patch *added* (both absent from pristine upstream SwiftTerm — verified firsthand — and implemented by **zero** of five mature peers). On a trackpad or Magic Mouse, scrolling now stops dead the instant you lift your fingers (no macOS inertial coast) and fast gestures silently lose distance — choppy versus iTerm2/Warp. Root-cause + 5-peer consensus: `research/03-analysis/scroll-momentum-smoothness-research.md`.

## What Changes

Targeted, knob-free refinement of the same SwiftTerm `scrollWheel` patch hunk (no new config, no classic-wheel behavior change):

- **Honor momentum on every branch.** Remove the blanket `if event.momentumPhase != [] { return }` guard that sits above the 3-way dispatch, so inertial-coast events flow into the mouse-report, alt-screen, and local-scrollback branches exactly as finger-driven events do — restoring the native macOS coast that pristine upstream never suppressed. (Peer-unanimous: 0/5 drop momentum.)
- **Stop discarding scroll distance.** Fix the precise-delta accumulator (`xttyWheelRowCount`) so it carries a **lossless** sub-cell remainder and emits every accumulated whole row, instead of subtracting the full accumulated amount while emitting at most 5 (the current `remainder -= whole; return min(5, whole)` silently drops the overflow). Bound flood by whole-cell **quantization** (≤ ~1 report/key per cell traversed), not by a fixed per-gesture cap — the mechanism every peer uses.
- **Reset the remainder per gesture** (on the user-driven `.began` phase) so a stale sub-cell fraction can't leak across two separate flicks as a phantom first-line jump.
- **Make momentum observable.** Extend the DEBUG wheel-routing dump so each routed decision records whether it came from an inertial-coast (momentum) frame and whether it used precise (trackpad) deltas — the observability the manual physical-trackpad verify needs (the coast behavior is structurally un-drivable by the synthetic XCUITest harness, which never produces momentum).

Explicitly out of scope (deferred to a follow-up): a user-facing `scroll-multiplier` config knob, the discrete-wheel accumulator rework of the local-scrollback branch (classic-wheel scrollback keeps its current `calcScrollingVelocity` feel), horizontal wheel reporting, and iTerm2's `_disableScrollReportingUntilMomentumEnds` late-report latch (recorded as a known deferred correctness risk).

## Capabilities

### New Capabilities

<!-- none — this refines existing behavior -->

### Modified Capabilities

- `terminal-session`: the **Mouse-wheel routing** requirement changes its emission policy — inertial-coast (momentum) events are honored on every branch (not collapsed/dropped), and emission is bounded by lossless whole-cell quantization rather than a fixed per-gesture cap.
- `verification-harness`: the **Mouse-wheel routing is observable** requirement (and its end-to-end coverage) extends the wheel-routing dump to record the momentum/precise nature of the routed event, and records that the inertial-coast behavior is verified manually (physical trackpad) because synthetic gestures carry no momentum.

## Impact

- **SwiftTerm patch** (`patches/swiftterm/xtty-accessors.diff`): revise the `scrollWheel(with:)` hunk (delete the momentum guard; the priority-ordered 3-way branch is unchanged) and the `xttyWheelRowCount(for:)`/remainder logic; extend `public struct XttyWheelRouting` (in `XttyAccessors.swift`) with the momentum/precise fields. Same reconstitute-from-pin discipline; the upstream PR remains deferred to a maintainer action (as with the routing fix).
- **App layer**: the DEBUG state dump's wheel-routing field surfaces the two new booleans (mirrors the existing routing fields).
- **Tests**: `AppUITests/XttyMouseWheelUITests.swift` gains a crisp-negative assertion that synthetic gestures are recorded as non-momentum (the momentum=true coast is a manual verify); the existing 48-test routing coverage is unchanged (synthetic events never hit the removed guard, and the routing branches are untouched).
- **No** `terminal-configuration` / `terminal-keybindings` impact; **no** new test count (so no `packer/README.md` acceptance-envelope change); Debug/Release build paths unchanged.
