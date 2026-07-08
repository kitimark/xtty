# Scroll-momentum smoothness research — why xtty's wheel feels choppy after the routing fix

> **Follow-up to [`mouse-wheel-scroll-forensics.md`](mouse-wheel-scroll-forensics.md).** That doc settled the **3-way branch _routing_ policy** (the reason htop didn't scroll at all) and shipped it as `fix-scroll-wheel-mouse-reporting` (archived 2026-07-08). This doc settles the distinct **_smoothness / feel_ dimension** the routing fix left open — its D5 "anti-flood policy exact shape" and the deferred **physical-mouse re-confirm ❓**. Symptom: after the routing fix, htop/pagers/scrollback scroll, but on a **trackpad/Magic Mouse** the motion stops dead on finger-lift and fast flicks under-travel — choppy vs iTerm2/Warp.
>
> **Provenance:** Produced 2026-07-09 from a `/xtty:research` source-research fan-out (run `wf_2cf7d159-6ef`: 6 peer/baseline readers `sonnet·medium` ∥ [iTerm2, Ghostty, kitty, WezTerm, Alacritty, SwiftTerm-local] → synthesis `opus·high` → adversarial critic `opus·xhigh`; **8 agents / 0 errors / 529k subagent tokens**) → orchestrator **firsthand git verification** of the two xtty bugs against the working tree. Claims tagged ✅ verified · ⚠️ code-read-only (not by-effect) · ❌ refuted · ❓ open.
>
> **Sources:** `external/SwiftTerm/Sources/SwiftTerm/Mac/MacTerminalView.swift` + `patches/swiftterm/xtty-accessors.diff` + `git -C external/SwiftTerm show HEAD:…` (pristine upstream, **read firsthand by the orchestrator** — the xtty/SwiftTerm line numbers below are verified). Shallow `--depth 1` clones of iTerm2, Ghostty, kitty, WezTerm, Alacritty under `/tmp/xtty-scroll-*` (read by the reader fan-out — **peer line numbers are reader-stage, not re-verified against source; the _policy_ is load-bearing, the specific peer lines are not**, and the momentum-during-coast claim is code-read across **all** peers, never measured — see §6). Transcript: `…/subagents/workflows/wf_2cf7d159-6ef/journal.jsonl` (6 records + synthesis + critic, one `{"type":"result"}` per agent).

## Headline

xtty's scroll-smoothness regression is **two mechanisms its own `scrollWheel` patch _added_** — both **absent from pristine upstream SwiftTerm** (verified firsthand) and **implemented by zero of the five mature peers**:

1. **Blanket momentum drop, above the dispatch.** `if event.momentumPhase != [] { return }` sits at the **top of `scrollWheel`, above the 3-way branch** (`MacTerminalView.swift:2194`, dispatch at `:2201/:2226/:2243`). It discards **all** trackpad/Magic-Mouse inertial (coast) events for **all three branches — including plain local scrollback**, which has no child to flood. Result: scrolling stops dead the instant you lift your fingers; the native macOS inertial glide is gone.
2. **Cap-and-discard accumulator.** `xttyWheelRowCount` carries a sub-row remainder correctly, then `whole = Int(remainder); remainder -= CGFloat(whole); return min(cap, whole)` (`cap = 5`) — it **subtracts the full `whole` but emits at most 5**, so a fast gesture with `whole = 12` emits 5 and **7 rows vanish** (not carried, not emitted). Fast scrolling under-travels.

**Peer consensus (5/5): never drop momentum, never cap-and-discard, never time-throttle.** Flood is bounded _structurally_ by pixel→cell quantization plus (on the mouse-report branch) multiplier-neutralization-to-1× or magnitude-less SGR — not by a cap or a debounce. The fix moves xtty onto the shared peer path; two facts must still be closed by a **physical-trackpad** verify-by-effect (§6) before committing a design.

## 1. The two bugs — verified firsthand against the working tree ✅

The orchestrator read the actual checkout (not peer analogy):

```sh
# pristine upstream (git show HEAD = pinned v1.13.0; the patch is git-apply, not committed)
git -C external/SwiftTerm show HEAD:Sources/SwiftTerm/Mac/MacTerminalView.swift \
  | grep -c 'momentumPhase\|hasPreciseScrollingDeltas'      # => 0
```

- **Pristine upstream is momentum-blind.** `0` references to `momentumPhase`/`hasPreciseScrollingDeltas` anywhere in the file; upstream `scrollWheel:2172` does only `calcScrollingVelocity(abs(event.deltaY))` → local scrollback. Upstream has **no mouse-report branch and no alt-screen branch at all** — so "upstream glides through momentum for the child" would be misleading: upstream never reported to the child on the wheel. **The momentum-during-report behavior has no upstream precedent; xtty builds it from peer analogy.** → the regression is **100 % xtty-added**. ✅
- **The guard is above the dispatch.** Patched `:2194` precedes BRANCH 1 (`:2201`, mouse-report) / BRANCH 2 (`:2226`, alt-screen arrows) / BRANCH 3 (`:2243`, scrollback). Its own comment admits the rationale is child-flood-only ("so a flick can't flood the child") while its _placement_ also starves scrollback that upstream never restricted. ✅
- **Cap subtracts more than it emits.** `patches/swiftterm/xtty-accessors.diff` `xttyWheelRowCount`: the correct remainder-carry lives two lines above and is defeated by `min(cap, whole)`. ✅

## 2. Peer consensus — how five mature terminals handle it

⚠️ **All rows are macOS _code-read_, not by-effect.** No reader ran a terminal, enabled mouse mode, and physically flicked a trackpad to watch reports arrive during coast — that is the single biggest unverified load-bearing fact (§6, unknown #1).

| Facet | iTerm2 | Ghostty | kitty | WezTerm | Alacritty | **xtty (shipped — the bug)** |
|---|---|---|---|---|---|---|
| **Momentum** | Honored; `momentumPhase` used only for a bookkeeping flag + one narrow alt-screen correctness latch | Honored (captured as metadata, never branched on) | Honored uniformly | **Ignored entirely** (`momentumPhase` never read) — coast still flows | Honored (winit collapses momentum→`TouchPhase`, same path as drag) | **DROPPED** blanket, all 3 branches |
| **Pixel→line + remainder** | `takeWholePortion`, lossless carry, resets at `phaseBegan` only | `pending_scroll_y` persistent remainder | `pending_scroll_pixels` + sub-line `screen_apply_pixel_scroll` | px÷`15.0` + `fract()`; 250 ms staleness reset | `accumulated_scroll %= cell` (lossless); resets at momentum-Began | Carries remainder **but cap discards overflow** |
| **Per-gesture cap / throttle** | **None** | **None** | **None** | **None** (magnitude-less SGR → 1 report/event) | **None** | **cap = 5 + discard** |
| **Branch-differentiated** | scrollback → **stock AppKit** `super scrollWheel:` (native glide) | No (shared row-delta, sink differs) | Under mouse-tracking, multiplier→1× + `min_lines`=1 | mouse-report 1/event; alt-screen fixed N=3; scrollback 1:1 | mouse-report multiplier→1×; else full | Inverted: momentum-drop over-broad, cap on the wrong branches |
| **Config multiplier (default)** | acceleration exp=1, `fastTrackpad`=YES | precision **1.0** (×2 Swift layer) / discrete **3.0** | wheel **5.0** / touch **1.0** / min_lines 1 | alt-screen speed **3**; px/line 15 | `scrolling.multiplier` **3** (→1 under report) | **None** |

**Flood is bounded structurally, never by a throttle.** A hard flick legitimately emits **~1 report per cell traversed over the whole coast** (~1000–2000 reports over ~1.5 s for a multi-screen flick). The industry accepts this as "smooth" because each report is cheap and the child coalesces its own redraws — **not** because volume is low. xtty reached for the one tool nobody else uses (a hard cap + a momentum drop).

**iTerm2 is the least-transferable model.** Its headline smoothness trick — hand the wheel to stock `NSScrollView`/`super scrollWheel:` for local scrollback — is **unavailable to xtty**: SwiftTerm's grid is a **custom-drawn `NSView`, not an `NSScrollView`**. So xtty is architecturally a **hand-roller** like Ghostty/kitty/WezTerm/Alacritty — **those four are the templates**, not iTerm2.

## 3. Recommended fix shape (per branch — for the candidate change, not shipped)

**Global:** delete the momentum guard (`:2194`). Restores coast to all three branches immediately, and is safe even as a standalone first step because momentum's per-event `deltaY ≈ 0–1` → `calcScrollingVelocity` returns 1 (no scrollback flood; the `>9→max(rows,20)` over-scroll needs a big _classic-wheel_ notch momentum never produces).

- **Branch 3 — local scrollback (highest-value):** honor momentum, full multiplier, no cap; replace the `calcScrollingVelocity` bucket table with the precise remainder-carrying accumulator (minus the cap). **Required, not optional:** add a **discrete (classic-wheel) multiplier** (kitty ships `5.0`) or classic mouse-wheel scrollback regresses to 1-cell-per-notch (painfully slow) — the precise accumulator branch isn't taken for a non-precise wheel, so `min(cap, round(deltaY))` = ~1 line/notch without it.
- **Branch 2 — alt-screen arrows:** honor momentum, remainder-carry, no discard; bound by per-cell quantization with **multiplier→1×** (preferred) or WezTerm's fixed **N=3** presses/event.
- **Branch 1 — mouse-report (SGR 64/65):** honor momentum; replace cap-5-discard with **multiplier→1× under mouse-tracking** + uncapped remainder-carry (equivalently WezTerm's magnitude-less 1-report/event). This is where the original flood concern is _real_ — and the peers solve it by neutralizing magnitude, **not** by discarding distance.
- **Do NOT** add a time-based rate limit / debounce / `DispatchQueue` coalescing — 0/5 peers do; AppKit's own `NSEvent` cadence is the only implicit coalescing you get and need.

### Choices the maintainer must make (peers genuinely diverge)

1. **Mouse-report multiplier:** 1× (kitty/Alacritty) vs full (Ghostty/iTerm2) vs magnitude-less 1-report/event (WezTerm). → recommend **1×**.
2. **Alt-screen speed:** per-cell multiplier-honoring (kitty/Alacritty) vs fixed N=3/event (WezTerm). → recommend **per-cell**.
3. **Pixels-per-line factor:** cell height (most) vs hardcoded 15 (WezTerm) vs raw round-away-from-zero "fast" mode (iTerm2 `fastTrackpad`). → recommend **cell height** (xtty already uses `cellDimension.height`).
4. **First-flick immediacy:** WezTerm's 250 ms staleness reset (rounds first sub-line delta up, zeroes remainder). → **optional polish**.
5. **Config surface:** add a `scroll-multiplier` (precision/discrete); default **precision 1.0 / discrete 3.0** (Ghostty/Alacritty center of mass). Touches `terminal-configuration`.

## 4. Critic corrections (adversarial, `opus·xhigh`) — folded in

- **The two bugs are not co-equal — the guard _shadows_ the cap.** The momentum drop discards events _before_ `xttyWheelRowCount` runs, so fixing only the cap does nothing (still "stops dead"); they must be fixed **together, guard first**. "Two peer-unanimously-wrong mechanisms" overstates the cap's standalone weight _today_ (it only bites during the short finger-down window of a hard flick until the guard is gone).
- **Remainder-reset trigger is unspecified and mandatory.** `xttyWheelRowRemainder` is a persistent ivar; a stale fraction leaking across two separate flicks yields a phantom first-line jump. Minimal-correct = reset on `event.phase == .began`. **Alacritty's reset doesn't transfer for free** — winit maps momentum-Began→`Started` (its reset trigger); xtty reads raw `NSEvent` and has no equivalent, so "copy Alacritty's lossless accumulator" silently omits its reset semantics.
- **iTerm2's `_disableScrollReportingUntilMomentumEnds` latch is a deferred correctness risk, not "polish."** It is the _one_ momentum-specific safeguard the most-mature peer kept ("finger lifted, region changed, stop firing"); adopting "momentum is inert everywhere" wholesale discards the single hard-won correctness lesson in the dataset. Record it explicitly.
- **Citation quality (peer records):** WezTerm + Alacritty **best-cited** (verbatim, incl. WezTerm's repo-wide `grep -rn momentumPhase` = 0 matches and `mouse.rs:54 WheelUp→64` magnitude-less SGR; Alacritty `input/mod.rs:769` mult→1, `:826 %=`, winit `view.rs:678` momentum→phase collapse). **iTerm2 is shakiest on the exact claim the "5/5" verdict leans on** — its "honors momentum on the _mouse-report_ branch" rests on body-only citations (`:1255-1301`, `:1483`); the branch-scoping of its latch is reader-inferred. **kitty** has an internal discrepancy between its accumulation body text and its own `:1416-1422` citation (the load-bearing `:1411` multiplier-neutralize _is_ verbatim).
- **"Verified" was the wrong word** in the synthesis's consensus line → downgraded to "read on the macOS code path"; **no peer momentum-during-coast claim was measured by effect.**

## 5. Re-verify by effect (how a future reader re-checks the headline)

- **The two xtty bugs (source facts):** re-run the `git show HEAD | grep -c` above (→ 0, upstream momentum-blind); read `MacTerminalView.swift:2194` (guard above `:2201/:2226/:2243`) and `xttyWheelRowCount` in the patch (`remainder -= whole` vs `return min(5, whole)`). Cheap, deterministic. ✅
- **The feel claim** is only re-checkable with a **physical trackpad** — synthetic events carry no momentum (§6). See the probes below.

## 6. Load-bearing UNKNOWNS — cannot be closed in research (verify tasks for the change) ❓

These need a **physical trackpad flick** on a **guard-removed DEBUG build** — synthetic `CGEvent`/peekaboo/XCUITest `scroll(byDeltaX:deltaY:)` all carry `momentumPhase == none`, so neither the AI nor the XCUITest harness can generate a momentum/coast event. This is the same ❓ the original forensics deferred ("physical-mouse re-confirm"). **Human-run.**

1. **THE unknown — does macOS deliver populated momentum events into xtty's precise path during coast, and at what reports/sec?** Every peer record _infers_ "reports during momentum" from an absent guard; none measured it. **Probe:** DEBUG build with the guard removed; log per wheel event `{momentumPhase, hasPreciseScrollingDeltas, scrollingDeltaY, cellHeight, computed rows, branch}` via the existing `xttyLastWheelRouting` dump; one hard trackpad flick over `htop`; confirm `.report` events with `count>0` fire **after** finger-lift and **capture reports/sec during the coast**. Turns "won't flood (by peer analogy)" into a measured number.
2. **htop back-pressure.** At the measured reports/sec, does htop stay interactive, or does the pty write buffer / htop redraw stall? Peer code-reads prove the _emit_ side, never the _consume_ side.
3. **Remainder-reset validated.** Flick up, pause, flick up again → confirm no spurious first-line jump (closes the reset-trigger choice from §4).

## 7. Fates table — retired theories / framings

| # | Theory / framing | Verdict | Killed by |
|---|---|---|---|
| T1 | The choppiness is inherited from upstream SwiftTerm. | ❌ | `git show HEAD` = 0 `momentumPhase`/`hasPreciseScrollingDeltas`; upstream `scrollWheel` is scrollback-only. The momentum drop + cap are **xtty-added** by the routing patch (§1). |
| T2 | The two bugs are independent, co-equal wrongs. | ❌ (miscalibrated) | The guard drops events _before_ `xttyWheelRowCount`, so it **shadows** the cap; fixing only the cap changes nothing. Fix together, guard first (§4). |
| T3 | Bound the flood with a per-event cap / time throttle. | ❌ | 0/5 peers cap-and-discard or time-throttle; flood is bounded by pixel→cell quantization + multiplier→1× / magnitude-less SGR. A cap loses distance; a throttle is what nobody ships (§2). |
| T4 | Copy iTerm2 — it's the macOS gold standard. | ❌ (non-transferable) | iTerm2's smoothness trick is delegating scrollback to stock `NSScrollView` `super scrollWheel:`; SwiftTerm's grid is a custom-drawn `NSView`, not an `NSScrollView`. The **hand-rollers** (Ghostty/kitty/WezTerm/Alacritty) are the templates (§2). |
| T5 | Just "carry the fraction" — the accumulator is otherwise done. | ❌ (incomplete) | The **reset trigger** is unspecified; a stale fraction across two flicks = phantom first-line jump. Alacritty's winit-Started reset doesn't transfer to raw-NSEvent xtty (§4). |
| T6 | Give scrollback the precise accumulator and it's fixed. | ❌ (regresses classic wheel) | The precise branch isn't taken for a non-precise wheel → `min(cap, round(deltaY))` ≈ 1 line/notch; needs a **discrete multiplier** (kitty 5.0) or classic-wheel scrollback becomes painfully slow (§3). |
| T7 | The peer "reports during momentum" claim is established. | ⚠️ (code-read only) | Every peer record infers it from an absent guard; **none measured it**. Load-bearing → §6 unknown #1, physical-flick, human-run. |
| T8 | iTerm2's momentum latch is optional polish. | ❌ | It is the only momentum-specific correctness safeguard the most-mature peer kept; record as a **known deferred correctness risk** (§4). |

## 8. Reusable guideline

**G(scroll-momentum): a hand-rolling terminal (custom-drawn grid, not an `NSScrollView`) must —**
(a) **never drop macOS momentum events** — they are legitimate scroll input on every branch, and dropping them kills the native coast (the felt regression);
(b) **carry a lossless fractional pixel→cell remainder, never cap-and-discard** — and choose an explicit **reset trigger** (`event.phase == .began`) or a stale fraction leaks a phantom line across gestures;
(c) **bound mouse-report flood by pixel→cell _quantization_ + multiplier→1× under mouse-tracking, not by a per-event cap or a time throttle** (0/5 mature terminals throttle; a hard flick legitimately emits ~1 report/cell over the whole coast);
(d) **distinguish precise (trackpad) from non-precise (wheel) deltas**, and give classic-wheel scrollback a **discrete multiplier** or it regresses to 1-cell-per-notch;
(e) the **momentum-during-coast rate is only closable by a physical trackpad flick** — synthetic events carry no `momentumPhase`, so this behavior class is **un-coverable by the XCUITest harness** and must be a manual verify-by-effect.
iTerm2's stock-AppKit delegation for scrollback is the smoothest path but is **non-transferable** to a custom-drawn grid; the hand-rollers (Ghostty/kitty/WezTerm/Alacritty) are the templates.

## 9. Status & artifacts

- **Not yet an OpenSpec change** — captured research feeding a **candidate change** (e.g. `smooth-scroll-wheel-momentum`): delete the momentum guard, replace cap-5-discard with a lossless remainder accumulator per branch (+ discrete scrollback multiplier + mouse-report multiplier→1×), add a `scroll-multiplier` config knob, and carry the §6 physical-flick probes as verify tasks. **No product code shipped; no trackers changed except this doc + its `research/README.md` index** (parallels how the sibling forensics doc was captured pre-change).
- **Evidence:** workflow run `wf_2cf7d159-6ef` transcript (`…/subagents/workflows/wf_2cf7d159-6ef/journal.jsonl` — 6 reader records + synthesis + critic verbatim); the §1 `git show`/`grep` and §6 physical-flick probes are the durable re-verification.
- **Cross-links:** routing root-cause + the shipped 3-way-branch fix → [`mouse-wheel-scroll-forensics.md`](mouse-wheel-scroll-forensics.md); the shipped change `fix-scroll-wheel-mouse-reporting` (archived 2026-07-08) is what this proposes to refine.
