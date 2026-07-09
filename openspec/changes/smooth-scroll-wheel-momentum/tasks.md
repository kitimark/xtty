## 1. SwiftTerm patch revision (the product fix)

- [ ] 1.1 In `patches/swiftterm/xtty-accessors.diff`, **delete the blanket momentum guard** `if event.momentumPhase != [] { return }` from `scrollWheel(with:)` (D1). Keep the `deltaY == 0` horizontal guard and the priority-ordered 3-way branch (BRANCH 1/2/3) unchanged.
- [ ] 1.2 Add the **per-gesture remainder reset** (D3): zero `xttyWheelRowRemainder` when `event.phase.contains(.began)`, so a stale sub-cell fraction cannot leak across separate flicks.
- [ ] 1.3 Rewrite `xttyWheelRowCount(for:)`'s **precise** (`hasPreciseScrollingDeltas`) path to carry the full sub-cell remainder and **emit every accumulated whole row** — drop `min(cap, whole)`; subtract only what is emitted (D2). Drop the `cap` on the non-precise path too (D4); a discrete notch's behavior stays effectively unchanged.
- [ ] 1.4 Extend `public struct XttyWheelRouting` (`XttyAccessors.swift`) with `let momentum: Bool` + `let precise: Bool` (D6); set them at all three `xttyLastWheelRouting = …` assignments (report / cursorKey / scrollback).
- [ ] 1.5 Re-run `scripts/bootstrap-swiftterm.sh` to confirm the revised hunk applies cleanly from the pristine pin.

## 2. App-layer observability

- [ ] 2.1 Surface `momentum` + `precise` in the App-layer DEBUG state dump's wheel-routing field (mirror the existing branch/button/count fields; `#if DEBUG` + `-UITestGridDump` gated, observe-only).

## 3. Tests

- [ ] 3.1 In `AppUITests/XttyMouseWheelUITests.swift`, add a **crisp-negative** assertion that a synthetic wheel gesture is recorded with `momentum == false` (proves the field is wired; the coast is manual-verify-only). Leave the existing 48 routing/monotonicity assertions unchanged.

## 4. Verify

- [ ] 4.1 `make test-core` — `XttyCore` regression (inline, cheap).
- [ ] 4.2 Run the **Tier-1 XCUITest suite + full acceptance matrix** (both goldens) and confirm **no regression** — expected `48/48` unchanged, 0 vacuous passes (the removed guard never fired on synthetic events; the 3 routing branches are untouched). ⟶ xtty-test-validator (Tier-1 + full matrix, both goldens)
- [ ] 4.3 **MANUAL physical-trackpad verify-by-effect** (HUMAN-RUN — un-automatable; synthetic events carry no momentum). On the shipped (guard-removed) build, flick the trackpad under htop and confirm: (a) wheel reports **continue after finger-lift** during the coast — `cat -v` under `\e[?1002h\e[?1006h` shows `^[[<64/65…M` reports arriving after the fingers lift; (b) a fast gesture **does not lose distance**; (c) **htop stays interactive** (no pty-write / redraw back-pressure) — record the coast reports/sec; (d) local scrollback and an alt-screen pager also coast; (e) an xtty-vs-iTerm2 A/B on the same flick. Closes the load-bearing ❓ (research §6 unknown #1–#3).

## 5. Upstream (deferred)

- [ ] 5.1 Prepare the upstream SwiftTerm PR delta (the pure branch logic + this momentum/accumulation correction; the `momentum`/`precise` observability stripped) — **DEFERRED to a maintainer action** (outward-facing; not filed unilaterally), extending the routing fix's retire-on-merge plan.

## 6. Coherence + archive (the standard change tail)

- [ ] 6.1 Pre-archive coherence review of this change. ⟶ xtty-openspec-critic (smooth-scroll-wheel-momentum)
- [ ] 6.2 Archive + reconcile: `openspec archive`; correct the merged requirement text to what actually shipped; reconcile the trackers (AGENTS Current-status row + snapshot, HISTORY.md narrative, `research/04-design/02-milestones.md`, and — **contingent on the 4.3 manual verify passing** — a Learned-refutations one-liner "don't drop momentum / cap-and-discard / time-throttle the wheel"); update `packer/README.md` only if test counts changed (expected: none); verify against disk (`openspec list` / `ls openspec/changes/archive/` / `ls openspec/specs/`). ⟶ archive-ritual
