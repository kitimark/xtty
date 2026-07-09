## 1. SwiftTerm patch revision (the product fix)

- [ ] 1.1 In `patches/swiftterm/xtty-accessors.diff`, **delete the blanket momentum guard** `if event.momentumPhase != [] { return }` from `scrollWheel(with:)` (D1). Keep the `deltaY == 0` horizontal guard and the priority-ordered 3-way branch (BRANCH 1/2/3) unchanged.
- [ ] 1.2 Add the **per-gesture remainder reset** (D3): zero `xttyWheelRowRemainder` when `event.phase.contains(.began)`, so a stale sub-cell fraction cannot leak across separate flicks.
- [ ] 1.3 Rewrite `xttyWheelRowCount(for:)`'s **precise** (`hasPreciseScrollingDeltas`) path to carry the full sub-cell remainder and **emit every accumulated whole row** — drop `min(cap, whole)`; subtract only what is emitted (D2). Drop the `cap` on the non-precise path too (D4); a discrete notch's behavior stays effectively unchanged.
- [ ] 1.4 Extend `public struct XttyWheelRouting` (`XttyAccessors.swift`) with `let momentum: Bool` + `let precise: Bool` (D6); set them at all three `xttyLastWheelRouting = …` assignments (report / cursorKey / scrollback).
- [ ] 1.5 Re-run `scripts/bootstrap-swiftterm.sh` to confirm the revised hunk applies cleanly from the pristine pin.

## 2. App-layer observability + injection hook

- [ ] 2.1 Surface `momentum` + `precise` in the App-layer DEBUG state dump's wheel-routing field (mirror the existing branch/button/count fields; `#if DEBUG` + `-UITestGridDump` gated, observe-only).
- [ ] 2.2 Add the **DEBUG synthetic-wheel-event injection hook** (D8), following the existing `App/XttyApp.swift` XCUITest-trigger family (link-open / spatial-op / git-select / git-open / block-select): the test writes a wheel-event spec (momentum phase, precise flag, vertical delta, modifiers); the app constructs a faithful wheel `NSEvent` via `CGEvent(scrollWheelEvent2Source:…)` → `NSEvent(cgEvent:)` and drives it through the **real** `scrollWheel(with:)` on the focused pane's terminal view. `#if DEBUG` + `-UITestGridDump` gated; route through the real handler, never a reimplemented branch.

## 3. Tests

- [ ] 3.1 In `AppUITests/XttyMouseWheelUITests.swift`, add the **crisp-negative** assertion that a real automation-channel gesture is recorded with `momentum == false` (proves the field is wired on the real-gesture path). Update the stale `capped at 5` comment/assumption in the existing suite (the cap is removed by 1.3). Leave the existing 48 routing/monotonicity assertions otherwise unchanged.
- [ ] 3.2 **Momentum-not-dropped** (via 2.2's injection hook): inject a wheel event carrying an inertial-coast (momentum) phase over a focused pane and assert it routes on its branch with `momentum == true` — not silently dropped. Guards the D1 guard-deletion against regression.
- [ ] 3.3 **Lossless-carry** (injection): inject precise input whose accumulated travel exceeds several whole cells and assert the routed emission count tracks the cells traversed (carrying the remainder), not clamped to a fixed cap. Guards the D2 cap-discard fix.
- [ ] 3.4 **`.began` reset** (injection): inject a precise gesture that leaves a sub-cell remainder, then begin a new gesture, and assert no phantom extra cell is emitted from the leftover remainder. Guards D3.

## 4. Verify

- [ ] 4.1 `make test-core` — `XttyCore` regression (inline, cheap).
- [ ] 4.2 **Update `packer/README.md`'s acceptance envelope** for the grown test count (the 3.2–3.4 injection tests add methods: 48 → the new total) so the validator's runtime read matches — do this *before* 4.3 (reverse-duty; else the validator flags the extra passes as unclassified).
- [ ] 4.3 Run the **Tier-1 XCUITest suite + full acceptance matrix** (both goldens) and confirm the routing branches are regression-clean and the new momentum-injection tests (3.2–3.4) + the crisp negative (3.1) are green, 0 vacuous passes. ⟶ xtty-test-validator (Tier-1 + full matrix, both goldens)
- [ ] 4.4 **MANUAL physical-trackpad verify-by-effect** (HUMAN-RUN — closes only what D8's injection cannot: the OS delivery/rate/back-pressure). On the shipped build, flick the trackpad under htop and confirm: (a) wheel reports **continue after finger-lift** during the coast — `cat -v` under `\e[?1002h\e[?1006h` shows `^[[<64/65…M` arriving after the fingers lift; (b) a fast gesture **does not lose distance**; (c) **htop stays interactive** (no pty-write / redraw back-pressure) — record the coast reports/sec; (d) local scrollback and an alt-screen pager also coast; (e) an xtty-vs-iTerm2 A/B on the same flick.

## 5. Upstream (deferred)

- [ ] 5.1 Prepare the upstream SwiftTerm PR delta (the pure branch logic + this momentum/accumulation correction; the `momentum`/`precise` observability + injection hook stripped) — **DEFERRED to a maintainer action** (outward-facing; not filed unilaterally), extending the routing fix's retire-on-merge plan.

## 6. Coherence + archive (the standard change tail)

- [ ] 6.1 Pre-archive coherence review of this change. ⟶ xtty-openspec-critic (smooth-scroll-wheel-momentum)
- [ ] 6.2 Archive + reconcile: `openspec archive`; correct the merged requirement text to what actually shipped; reconcile the trackers (AGENTS Current-status row + snapshot, HISTORY.md narrative, `research/04-design/02-milestones.md`, and — **contingent on the 4.4 manual verify passing** — a Learned-refutations one-liner "don't drop momentum / cap-and-discard / time-throttle the wheel"); confirm `packer/README.md`'s envelope reflects the final test count (per 4.2); verify against disk (`openspec list` / `ls openspec/changes/archive/` / `ls openspec/specs/`). ⟶ archive-ritual
