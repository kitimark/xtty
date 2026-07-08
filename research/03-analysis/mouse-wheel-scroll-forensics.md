# Mouse-wheel scroll forensics — why alt-screen mouse-tracking apps (htop) don't scroll in xtty

> **Provenance:** Produced 2026-07-09 from a live debugging session (peekaboo-driven scroll comparison of htop in xtty vs iTerm2) → a `/xtty:research` source-research fan-out (run `wf_5857687e-56f`: 5 peer-terminal readers `sonnet` ∥ → synthesis `opus·high` → adversarial critic `opus·xhigh`, 7 agents / 0 errors / 505k subagent tokens) → orchestrator inline reads of xtty's embedded SwiftTerm + a `cat -v` byte-capture verify-by-effect. All SwiftTerm line numbers are against the pinned checkout `external/SwiftTerm @ v1.13.0` (+ the `xtty-accessors.diff` patch). Claims tagged ✅ measured/source-verified · ❌ refuted · ❓ open.
>
> **Sources:** `external/SwiftTerm/Sources/SwiftTerm/{Mac/MacTerminalView.swift, Apple/AppleTerminalView.swift, Terminal.swift, EscapeSequences.swift}` (read firsthand); shallow clones of iTerm2, Ghostty, kitty, WezTerm, Alacritty under `/tmp/xtty-research-*` (read by the reader fan-out — peer *line* citations are reader-stage, not re-verified against source here, so the **policy** is load-bearing, the specific peer line numbers are not); the workflow transcript at `…/subagents/workflows/wf_5857687e-56f/` (5 reader records + synthesis + critic, one `{"type":"result"}` per agent in `journal.jsonl`).

## Headline

xtty's embedded **SwiftTerm `MacTerminalView.scrollWheel(with:)` never forwards a wheel gesture to the child** — it unconditionally moves its own local scrollback and emits **zero bytes** to the pty. So a full-screen app that enabled mouse tracking (htop, DECSET 1002) receives nothing on the wheel and does not scroll; on the alternate screen the local-scroll it *does* attempt is a dead no-op (no scrollback to move). iTerm2 (identical synthetic input) scrolls htop a full page. The fix is to compose the **3-way branch every mature terminal converges on** — a fix whose entire API already exists in SwiftTerm; `scrollWheel` just never calls it. ✅ (source-verified + verified by effect + peer-consensus).

## 1. The bug, measured — iTerm2 baseline vs xtty

Controlled A/B: same synthetic wheel events (`peekaboo scroll`, cursor parked over each terminal's htop process list), htop running in both.

| Input | iTerm2 | xtty |
|---|---|---|
| 6 wheel-down ticks (120 ms apart) | list jumps a full page — top PID `64679` (`…/Xcode`) → `36598` (`…/CoreServices`) | list **unchanged** — top PID `25349`, selection stuck on the same PID; only live CPU/mem numbers tick |
| ~40 rapid ticks | (n/a) | selection appeared to move **1 line** — later resolved as **noise**, not input (see fates) |

**Note the synthetic-vs-hardware caveat, controlled:** the events are synthetic (`CGEvent`/peekaboo, which can carry smaller deltas than a physical Magic Mouse/trackpad). But iTerm2 received the *identical* synthetic stream and scrolled correctly, so this is a genuine xtty-vs-iTerm divergence, not a test artifact. (A physical-mouse re-confirm is still worth doing — ❓.)

## 2. Root cause — SwiftTerm source

xtty embeds SwiftTerm **unmodified** for scroll handling (no `scrollWheel` override in `App/` — grep-confirmed). The whole bug is one function:

```swift
// MacTerminalView.swift:2172
public override func scrollWheel(with event: NSEvent) {
    if event.deltaY == 0 { return }
    let velocity = calcScrollingVelocity(delta: Int(abs(event.deltaY)))   // 1 / 3 / 10 / max(rows,20) buckets
    if event.deltaY > 0 { scrollUp(lines: velocity) } else { scrollDown(lines: velocity) }
}
```

1. **It never reads `terminal.mouseMode`** → it never emits a wheel mouse-report, even when the app enabled DECSET 1000/1002/1003. It does the *lowest*-priority action (local scrollback) in *all* cases — the exact inversion of the peer consensus (§3). ✅
2. `scrollUp`/`scrollDown` (`AppleTerminalView.swift:1885/1892`) move `displayBuffer.yDisp` via `scrollTo(row:)`. On the **alternate buffer** there is no scrollback: `maxScrollback = lines.count − rows = 0`, `yDisp` is already `0`, and `scrollTo` early-returns (`if row != yDisp`) → a **complete no-op**. So on the alt screen the wheel does *nothing*, both branches dead. ✅

**The irony — SwiftTerm already knows all three patterns, just not in `scrollWheel`:**
- `mouseMoved` (`:2166`) gates on `terminal.mouseMode.sendMotionEvent()` → `terminal.sendMotion(...)` — the Branch-1 gate.
- `mouseDown`/`mouseUp` (`:1963/:2008`) gate on `allowMouseReporting && mouseMode.sendButtonPress()/Release()` — the exact predicate Branch 1 needs.
- `pageUp`/`pageDown` (`:1865/:1875`) branch on `terminal.isDisplayBufferAlternate` → `send(EscapeSequences.cmdPageUp/Down)` vs local scroll — the Branch-2/Branch-3 split, already proving SwiftTerm sends escape sequences on the alt screen instead of dead local scrolls.

## 3. The correct policy — 5-terminal peer consensus

All five (iTerm2, Ghostty, kitty, WezTerm, Alacritty) implement the **identical priority-ordered 3-way branch**:

```
scrollWheel(event):
  rows = accumulate_deltas_to_whole_cells(event)      # carry sub-cell remainder forward
  if mouseReportingActive:                             # BRANCH 1 — highest priority
      for each row: emit wheel report (SGR button 64 up / 65 down), press-only, at pointer cell
  elif altScreen and alternateScrollEnabled:           # BRANCH 2
      for each row: emit arrow key (Up/Down), DECCKM-aware (SS3 ESC O A/B vs CSI ESC [ A/B)
  else:                                                 # BRANCH 3
      move local scrollback viewport
```

**Agreements — adopt directly (✅ consensus):** wheel buttons **64 (up) / 65 (down)** (horizontal 66/67); **press only**, never a release; modifiers OR'd onto the button; coordinate = **current pointer cell** (not top-left); **accumulate to whole rows, one report per row** (not per hardware notch, not per pixel); wheel-up→Up arrow.

**Design choices xtty must make (where peers diverge):**

| Question | Consensus / recommendation | Evidence |
|---|---|---|
| Which `mouseMode` gates the wheel report? | **`sendButtonPress()` modes: `.vt200`/`.buttonEventTracking`/`.anyEvent`. Exclude `.off` and `.x10`.** | Ghostty drops wheel in X10; iTerm2 excludes highlight(1001); kitty/Alacritty/WezTerm report for 1000/1002/1003. Reuses SwiftTerm's own `mouseDown` gate. |
| Alt-screen w/o mouse → arrow keys? DECSET 1007 default? | **Yes, translate to arrows; effectively default-ON.** SwiftTerm **does not parse 1007** (✅ zero hits), so the only first cut is the **unconditional (kitty/WezTerm) model** — arrows on alt-screen whenever mouse is off; add real 1007 parsing only if an app is observed disabling it. | 4/5 give `less`/`man` wheel-scroll out of the box (Ghostty/Alacritty default-on 1007; kitty/WezTerm hardcoded). Only iTerm2 defaults off. |
| Per-notch vs per-line report count? | **Per accumulated row, bounded (~1/event default, cap the burst).** | All five accumulate to rows; iTerm2 defaults ~1 report/NSEvent, caps at 32. |
| App-cursor-keys (DECCKM) in the fallback? | **Respect DECCKM** — SS3 when app-cursor on, CSI when off. SS3-always (Alacritty) is an acceptable shortcut. | iTerm2/Ghostty/kitty/WezTerm respect it (4/5). |
| Shift+wheel? | **Shift bypasses reporting → local scrollback** (xterm/iTerm2/kitty escape hatch). Do **not** OR Shift into the report. | Peer convention; lets users read scrollback under vim/htop. |

## 4. The fix — land-ready (critic-corrected)

Rewrite `MacTerminalView.scrollWheel(with:)` using only APIs **verified present** in `v1.13.0`. Deliver as an added hunk in `patches/swiftterm/xtty-accessors.diff` (fast, self-contained — same mechanism as the existing accessors) **and** file upstream in parallel (it's a genuine SwiftTerm bug), retiring the hunk when it merges.

Verified fix API surface (all ✅ against source):
- `Terminal.encodeButton(button:release:shift:meta:control:) -> Int` (`Terminal.swift:5596`): button `4→64`, `5→65` (`:5610-13`); wheel codes never trip the SGR release-bit.
- `Terminal.sendEvent(buttonFlags:x:y:)` (`:5632`) emits per `mouseProtocol` (**defaults to `.x10`** `:493` — binary `ESC [ M …`; SGR text only after the app sends 1006).
- `MouseMode.sendButtonPress()` = `vt200 || buttonEventTracking || anyEvent` (`:592-95`) — the gate, module-internal but the fix lives in-module (no accessor needed).
- Coordinates: `calculateMouseHit(with:) -> (grid, pixels)` (`:1915`) + reuse `sharedMouseEvent`'s exact math — `x: hit.grid.col` (**0-based**; `sendEvent` adds `+1`), `y: max(0, min(rows-1, hit.grid.row - displayBuffer.yDisp))` (`:1944-45`). **Not** "1-based, pointer cell" and **not** a fabricated `cellCoordinates(from:)`.
- `terminal.applicationCursor` is **`public`** (`:350`) → DECCKM branch needs no new accessor.
- `EscapeSequences.moveUp/DownApp/Normal` = SS3/CSI `A`/`B` (`:86-92`).

**Critic-flagged defects to avoid** (the naïve rewrite regresses):
- ❌ **Do not use `calcScrollingVelocity` as the report count.** Its `>9` bucket returns `max(rows,20)` → 20–32 reports for a single fast notch → *over*-scroll well past the iTerm baseline. It is a stateless nonlinear per-event bucket, **not** a remainder-carrying accumulator. Emit ~1 report/event (iTerm default) or build a real cross-event row accumulator.
- ❌ **Momentum spam** — inspect `event.momentumPhase`; a trackpad flick delivers ~10–30 momentum events that otherwise flood the pty with hundreds of reports.
- ❌ **Horizontal-guard regression** — keep `if event.deltaY == 0 { return }` (a pure horizontal swipe would otherwise compute `up=false` and emit a spurious wheel-**down**) *until* buttons 66/67 are wired.
- ❌ **Shift handling** — route Shift+wheel to local scrollback (Branch 3), don't OR it into the report modifiers.
- Coordinate mistake is latent for htop (it ignores wheel coords) but breaks click-precise apps — use the `sharedMouseEvent` math.

## 5. Verify-by-effect

**Headline verification, already run (✅):** enable htop's modes and capture the wire.
```sh
# in the terminal under test, at a shell prompt:
printf '\033[?1002h\033[?1006h'; cat -v      # enable button-event + SGR mouse reporting, echo bytes
# then scroll the wheel over the window; Ctrl-C; printf '\033[?1002l\033[?1006l'; clear
```
- **xtty:** scroll **up and down** → **zero bytes printed** (only the local scrollback viewport moves). No `^[[<64/65…M` report, no `^[[A/B` arrow. → confirms `scrollWheel` sends nothing to the child. ✅
- **iTerm2 (control):** the same probe prints wheel reports and scrolls htop. ✅
- *What it cannot prove:* the exact wire encoding depends on the active `mouseProtocol` (defaults to `.x10`; enable 1006 to see SGR text — this probe does).

**Post-fix probes (for the eventual change's verify tasks — the critic's set):**
1. **Harness fidelity first** — with `mouseMode == .off` on the *primary* screen, N synthetic ticks must move scrollback a deterministic, monotonic amount; log `scrollWheel`/`mouseDown`/`keyDown` on the 40-tick sequence to prove no stray click/keypress rides along. (Precondition for trusting any post-fix "page of movement" claim.)
2. **Wire bytes under htop, encoding-aware** — tee the pty; 6 wheel-down notches → expect `CSI < 65 ; x ; y M` (1006 on) *and* separately assert the binary `.x10` form (1002 without 1006).
3. **Report count vs iTerm baseline** — one physical notch ≈ 1 report (not 20–32); a momentum flick stays bounded (not hundreds). Fails the `calcScrollingVelocity`-as-count design.
4. **Branch-2** — `less`/`man` (alt screen, no mouse) scrolls via wheel; set DECCKM and assert bytes flip `ESC [ B` → `ESC O B`.
5. **Horizontal guard** — pure horizontal gesture emits no vertical report / no down-scroll.
6. **Shift-bypass** — Shift+wheel under htop moves local scrollback (decide deliberately).
7. **Coordinate correctness** — coordinate-echoing SGR app; wheel after scrolling scrollback (`yDisp>0`) → report `x;y` == `grid.col` / `grid.row − yDisp` (0-based, +1).

## 6. Fates table — retired theories

| # | Theory | Verdict | Killed by |
|---|---|---|---|
| T1 | "It was a mis-click; the wheel does work in xtty." | ❌ | iTerm baseline scrolls htop; xtty (identical input) shows byte-for-byte no movement (§1) and emits zero pty bytes (§5). |
| T2 | Reading `scrollWheel` is enough to characterize what xtty sends to the child. | ❌ | The code read alone suggested "pure no-op on alt-screen," but the messy first byte-probe showed a stray `^[[B` (down-arrow) — only the *clean* re-probe (zero bytes both directions) settled it. **Verify terminal input emission by effect, not by reading the handler.** |
| T3 | "40 ticks moved 1 line" ⇒ `calcScrollingVelocity` under-counts synthetic `deltaY`. | ❌ (category error) | On the buggy alt-screen path **nothing is sent to htop regardless of velocity**, so a velocity undercount cannot manifest as selection movement in the current build. The 1-line move was **htop re-sort / process-exit churn** (600-process list) or a phantom event — not scroll input. Velocity accuracy only becomes load-bearing *after* the fix (Branch 1). |
| T4 | Synthesis's drop-in used `cellCoordinates(from:)`, "1-based pointer cell". | ❌ | `cellCoordinates` does not exist; real API is `calculateMouseHit(with:)`; `sendEvent` adds `+1` so coords are **0-based**, and `y` must be `yDisp`-clamped (`sharedMouseEvent:1944-45`). Won't-compile + off-by-one. |
| T5 | Reuse `calcScrollingVelocity` as the report count "for free". | ❌ | Its `max(rows,20)` bucket → 20–32 reports per fast notch; stateless bucket, not a remainder-carrying accumulator → over-scroll past the iTerm baseline. |
| T6 | Branch 2 can check an existing `terminal.<alternateScroll>` / DECSET 1007 flag. | ❌ | SwiftTerm parses **no** 1007 (grep: zero `case 1007`/`alternateScroll`). The unconditional (kitty) model is the only first cut without adding a mode-parser case. |
| T7 | Gate the wheel report on "any `mouseMode != .off`". | ❌ | Includes `.x10` (DECSET 9), which would get malformed wheel reports; use `sendButtonPress()` (excludes `.off` and `.x10`). |
| T8 | DECCKM support needs a 3rd patch accessor. | ❌ | `terminal.applicationCursor` is already `public` (`:350`). |
| T9 | The bug is xtty-specific product code. | ❌ | xtty has no `scrollWheel` override; the defect is entirely in embedded SwiftTerm — a real upstream bug. |

## 7. Reusable guideline

**G(scroll): a terminal's scroll-wheel handler must implement the priority-ordered 3-way branch — mouse-report (highest) → alt-screen alternate-scroll arrow keys → local scrollback — and its *input emission* must be verified by effect, not by reading the handler.** A wheel handler that only moves local scrollback silently breaks every full-screen mouse-tracking app (htop/vim/tmux/fzf) and, on the alt-screen, does literally nothing (no scrollback to move). Confirm what a terminal sends to its child with a `cat -v` byte capture under the app's own mouse modes (`\e[?1002h\e[?1006h`) against a known-good control terminal — the source read misled here twice (a "pure no-op" that a stray byte contradicted, and a peer *policy* whose specific line numbers were unverifiable). Fold in the peer escape-hatches (Shift → local scrollback) and anti-flood (bound reports/gesture, collapse momentum) — the naïve "just send a report per velocity-line" over-scrolls worse than the original under-scroll.

## 8. Status & artifacts

> **Follow-up (2026-07-09):** this doc settled the **routing** policy (shipped as `fix-scroll-wheel-mouse-reporting`, archived 2026-07-08). The distinct **smoothness / momentum** dimension it left open (D5 anti-flood shape + the physical-mouse re-confirm ❓) is settled in **[`scroll-momentum-smoothness-research.md`](scroll-momentum-smoothness-research.md)** — the routing fix's own momentum guard + cap turned out to regress trackpad feel.

- **Not yet an OpenSpec change** — this is captured root-cause research feeding a **candidate change** (e.g. `fix-scroll-wheel-mouse-reporting`): a SwiftTerm-patch rewrite of `scrollWheel` + a `verification-harness` delta exposing wheel-report emission, with the §5 probes as verify tasks. No product code shipped; trackers unchanged except this doc + its README index.
- **Evidence:** workflow run `wf_5857687e-56f` transcript (`…/subagents/workflows/wf_5857687e-56f/journal.jsonl` — 5 reader records + synthesis + critic verbatim); the §5 `cat -v` probe is the durable re-verification; session A/B screenshots (xtty vs iTerm htop before/after) were captured to the session scratchpad (ephemeral — re-run the probe to reproduce).
