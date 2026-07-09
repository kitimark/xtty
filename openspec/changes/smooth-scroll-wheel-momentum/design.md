## Context

xtty embeds SwiftTerm (`external/SwiftTerm @ v1.13.0` + `patches/swiftterm/xtty-accessors.diff`). The shipped `fix-scroll-wheel-mouse-reporting` change rewrote `MacTerminalView.scrollWheel(with:)` into the priority-ordered 3-way branch (mouse-report → alt-screen cursor-keys → local scrollback), which was correct. But it added two anti-flood guards that regressed **trackpad/Magic-Mouse feel** — both **absent from pristine upstream SwiftTerm** (verified firsthand: `git -C external/SwiftTerm show HEAD:…MacTerminalView.swift` has **0** references to `momentumPhase`/`hasPreciseScrollingDeltas`) and implemented by **none** of five mature peers (iTerm2, Ghostty, kitty, WezTerm, Alacritty):

1. **Blanket momentum drop above the dispatch** — `if event.momentumPhase != [] { return }` at `MacTerminalView.swift:2194`, above BRANCH 1/2/3 (`:2201/:2226/:2243`). It discards **all** inertial-coast events for **all three branches**, including plain local scrollback (which has no child to flood), so scrolling stops dead on finger-lift — the native macOS coast is gone.
2. **Cap-and-discard accumulator** — `xttyWheelRowCount` does `whole = Int(remainder); remainder -= CGFloat(whole); return min(cap, whole)` (`cap = 5`): it subtracts the *full* `whole` but emits at most 5, so a fast gesture with `whole = 12` emits 5 and **7 rows vanish**.

Full root-cause, 5-peer consensus, the critic corrections, the fates table, and G(scroll-momentum): `research/03-analysis/scroll-momentum-smoothness-research.md` (fan-out `wf_2cf7d159-6ef`). This change is the **Targeted, knob-free** cut chosen for it (the fuller per-branch accumulator rework + a `scroll-multiplier` config knob are a deliberate deferral — see Non-Goals).

## Goals / Non-Goals

**Goals:**
- Restore the native macOS inertial coast to trackpad/precise-pointer scrolling on **every** branch (mouse-report, alt-screen cursor-keys, local scrollback).
- Stop discarding scroll distance on fast precise gestures (lossless remainder carry, no cap-discard).
- Bound flood by whole-cell quantization (peer-standard), not a fixed per-gesture cap.
- Make the momentum/precise nature of a routed event observable in the DEBUG dump for the manual physical-trackpad verify.

**Non-Goals:**
- **No config knob** — no user-facing `scroll-multiplier`; keep the hardcoded constants (parallels the routing fix's "knob-free first cut"). Deferred follow-up.
- **No local-scrollback accumulator rework** — BRANCH 3 keeps its existing `calcScrollingVelocity` line-based logic; classic-wheel scrollback feel is unchanged (so the "classic-wheel regresses to 1-cell/notch" risk the research flagged for the *full* rework does not arise here — the precise accumulator change is confined to the program-directed branches). Deleting the guard alone restores BRANCH 3's coast because momentum's per-event `deltaY ≈ 0–1` → `calcScrollingVelocity` returns 1 (no flood).
- **No** iTerm2-style `_disableScrollReportingUntilMomentumEnds` late-report latch — recorded as a known deferred correctness risk (Risks).
- **No** horizontal wheel reporting (the `deltaY == 0` guard stays); **no** momentum-friction synthesis (macOS supplies the coast frames).
- **No** upstream SwiftTerm PR filed here (deferred to a maintainer action, as with the routing fix).

## Decisions

- **D1 — Delete the momentum guard entirely (do not narrow it per-branch).** Remove `if event.momentumPhase != [] { return }` at `:2194` so momentum frames flow into the normal branch dispatch. *Alternative — keep the drop but scope it to BRANCH 1 only (the flood-sensitive one)* — rejected: it still starves scrollback and alt-screen of the coast, and the flood on BRANCH 1 is already bounded by whole-cell quantization (D2), not by dropping. Peer-unanimous: 0/5 drop momentum on any branch.
- **D2 — Lossless remainder carry, no cap, for the precise program-directed path.** In `xttyWheelRowCount`'s `hasPreciseScrollingDeltas` branch, emit the full accumulated `whole` and subtract only what is emitted (carry the sub-cell fraction) — drop the `min(cap, whole)`. Flood is bounded structurally: at most ~1 report/key per whole cell traversed. *Alternative — keep a cap but carry the overflow instead of discarding it* — a valid safety valve, but during momentum `whole` per event is ~0–1 so a cap never triggers; the cap only ever bit a single pathological finger-down event, and no peer keeps one. Omit it for simplicity; revisit only if the physical-flick verify (Risks) shows a pathological single-event burst.
- **D3 — Reset the remainder on the user-driven `.began` phase.** `xttyWheelRowRemainder` is a persistent stored property; reset it to 0 when `event.phase.contains(.began)` so a stale sub-cell fraction cannot leak across two separate flicks as a phantom first-line jump. *Alternative — also reset on direction reversal (WezTerm) or a staleness timer* — deferred polish; `.began` is the minimal-correct trigger. (Alacritty's momentum-Began→Started reset does not transfer: winit synthesizes it; xtty reads raw `NSEvent`, so we key on `.phase` directly.)
- **D4 — The non-precise (classic wheel) program-directed path is unchanged in spirit.** Keep `max(1, Int(abs(event.deltaY).rounded()))` for discrete notches (a classic wheel emits no momentum frames and no sub-cell deltas). The `cap` is dropped here too for consistency, but a discrete notch's `deltaY` is small so behavior is effectively identical. Classic-wheel *scrollback* (BRANCH 3) is untouched (Non-Goals).
- **D5 — "Multiplier→1×" is a no-op under knob-free.** The peers' mouse-report flood bound is "neutralize the user scroll multiplier to 1× under mouse-tracking." xtty has no scroll multiplier (D-knob-free), so the accumulator already emits ~1 report per cell — the 1× behavior is the default. No multiplier code is added; if the deferred config knob lands, it MUST neutralize to 1× on BRANCH 1.
- **D6 — Observability: add `momentum` + `precise` to `XttyWheelRouting`.** Extend `public struct XttyWheelRouting` (`XttyAccessors.swift`) with `let momentum: Bool` (the event was an inertial-coast frame) and `let precise: Bool` (`hasPreciseScrollingDeltas`); set them at each of the three `xttyLastWheelRouting = …` assignments; surface them through the App-layer DEBUG state dump's wheel-routing field. The synthetic XCUITest harness always sees `momentum == false` (synthetic gestures carry no coast) → a crisp-negative automated assertion; `momentum == true` is confirmed only by the manual physical-trackpad verify. *Alternative — no harness field, acceptance purely by `cat -v` byte capture (the fix-osc7 precedent)* — rejected: a wired dump field makes the manual verify rigorous (classifies each frame) and gives the harness a real non-vacuous negative to assert, matching the repo's "assert per observed capability" posture.
- **D7 — Same patch-hunk delivery + deferred upstream.** Revise the existing `scrollWheel`/`xttyWheelRowCount` hunk in `patches/swiftterm/xtty-accessors.diff`; `scripts/bootstrap-swiftterm.sh` reapplies. The upstream PR (the pure branch logic + this momentum/accumulation correction) stays deferred to a maintainer action, extending the routing fix's retire-on-merge plan.

## Maintainer choices settled (from the research §3–§4; recorded here, not re-litigated)

| # | Choice | Peers diverge | Settled |
|---|---|---|---|
| Scope | Targeted vs full peer-alignment | — | **Targeted** (user) — guard delete + cap-fix on the precise program branches; BRANCH 3 accumulator rework deferred |
| Config | knob-free vs `scroll-multiplier` | all peers expose ≥1 | **Knob-free** (user) — hardcoded constants; config deferred |
| Mouse-report bound | 1× / full / magnitude-less | kitty·Alacritty 1× · Ghostty·iTerm2 full · WezTerm 1/event | **1× (moot under knob-free)** — accumulator already ~1 report/cell (D5) |
| Remainder reset | `.began` / reversal / timer | iTerm2 `.began` · WezTerm reversal+250 ms | **`.began`** (D3) |
| Pixels-per-line | cell height / 15 / raw-fast | most: cell height | **Cell height** — already `cellDimension.height` |

## Risks / Trade-offs

- **Momentum-flood on BRANCH 1 is peer-analogy, not measured** → a hard trackpad flick emits ~1 report/cell over the whole coast (~1000–2000 reports/1.5 s for a multi-screen flick); the peers accept this as smooth because each report is cheap and the child coalesces its own redraws. **Mitigation:** the physical-trackpad verify (below) measures the actual reports/sec and confirms htop stays interactive (no pty-write / redraw back-pressure); the whole-cell quantization (D2) is the same structural bound the peers rely on. If the verify shows a pathological burst, the fallback is D2's carry-with-cap safety valve and/or the D-deferred latch.
- **iTerm2's late-report latch is deferred** → the one momentum-specific correctness safeguard the most-mature peer kept ("fingers lifted, region changed, stop firing into a now-inappropriate target"). **Mitigation:** recorded as a known deferred correctness risk; xtty's coordinate is recomputed per event via `calculateMouseHit`, and 4/5 peers ship without it — add it only if a real misfire is observed.
- **The coast behavior is un-coverable by the automated suite** → synthetic `CGEvent`/XCUITest `scroll(byDeltaX:deltaY:)` carry `momentumPhase == none`, so no automated test can drive inertial coast. **Mitigation:** the harness asserts the crisp negative (synthetic → `momentum == false`, D6) and the coast is a **manual physical-trackpad verify** (spec'd explicitly in `verification-harness`), consistent with the original forensics' deferred physical-mouse ❓.
- **Removing the guard changes no synthetic-test behavior** → synthetic gestures never hit the (momentum-only) guard, and the 3 routing branches are untouched, so the existing 48 `XttyMouseWheelUITests` + full VM matrix stay green unchanged (no `packer/README.md` envelope change). Low regression risk; confirmed by the Tier-1/VM validator run.

## Migration Plan

1. Revise the `scrollWheel(with:)` + `xttyWheelRowCount(for:)` hunk and extend `XttyWheelRouting` in `patches/swiftterm/xtty-accessors.diff`; `scripts/bootstrap-swiftterm.sh` reapplies on next bootstrap.
2. Surface `momentum`/`precise` in the App-layer DEBUG wheel-routing dump field; add the crisp-negative XCUITest assertion.
3. Verify: `make test-core`; the Tier-1 XCUITest suite + full VM matrix via the validator (regression: 48/48 unchanged); then the **manual physical-trackpad verify** (guard-removed build is the shipped build — flick under htop, confirm coast reports after finger-lift + no lost distance + no back-pressure, xtty-vs-iTerm2 A/B).
4. File the upstream SwiftTerm PR — **deferred to a maintainer action**.
- **Rollback:** revert the patch-hunk revision + the two dump booleans; `bootstrap` restores the prior (routing-fix) `scrollWheel`.

## Open Questions

- **Physical-flick measurement (human-run, closes the load-bearing ❓):** does macOS deliver populated momentum frames into xtty's precise path during coast, and at what reports/sec — and does htop stay interactive under that rate? Carried as a verify task; cannot be closed in-repo without a physical trackpad.
- **Does any pathological single event exceed a sane per-event burst?** If the flick verify shows one, reinstate D2's carry-with-cap safety valve (cap that carries, never discards).
