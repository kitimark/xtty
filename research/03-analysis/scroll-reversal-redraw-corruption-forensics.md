# Scroll-reversal redraw corruption — stale terminal cells bleed through when a mouse-tracking app's scroll direction reverses

> **Provenance:** Found 2026-07-10 during the human physical-trackpad verify for `smooth-scroll-wheel-momentum` (task 4.4, step (c) — htop back-pressure check). The user observed real corruption while flicking the trackpad in htop; the finding was then isolated via a live interactive debugging session (not a `/xtty:research` fan-out): the app's own DEBUG grid-dump (`-UITestGridDump`, `App/UITestDump.swift`) as ground truth, `peekaboo` for keyboard/mouse input synthesis and screen capture, and the existing DEBUG synthetic-wheel-injection hook (`XTTY_TEST_WHEEL_PATH`, added by `smooth-scroll-wheel-momentum` task 2.2) for deterministic, no-hardware repro. Claims tagged ✅ measured · ❌ refuted · ❓ open.
>
> **Sources:** live `htop` sessions inside a locally-built Debug `xtty.app` (`build/Build/Products/Debug/xtty.app`), driven via `peekaboo hotkey`/`peekaboo scroll`/`peekaboo paste` and the DEBUG wheel-injection file protocol; `/tmp/xtty-state-dump.json` + `/tmp/xtty-grid-dump.txt` (the app's own DEBUG dumps, polled and logged to a session scratchpad); a real iTerm2 window driven identically via `peekaboo scroll` + `screencapture -x -D 1` for the A/B baseline. No SwiftTerm source-level trace was done in this session — the mechanism below is **behaviorally isolated, not source-confirmed** (flagged ❓ where so).
>
> **Update (2026-07-10, same-day follow-up):** a second pass found and source-confirmed the exact root cause — see **§7**. Methodology: live interactive `peekaboo`-driven poking against the running Debug build; two `/xtty:research` Workflow fan-outs (source readers over `mirror/ncurses` + vendored SwiftTerm v1.13.0, adversarial synthesis/critique, verify-by-effect); a real byte-exact PTY capture of the live app (via `script -q`) replayed through a headless SwiftTerm `Terminal`; and a final direct source trace confirming the numeric defect. This Provenance/Sources block above covers only the original finding; §7 has its own trail.

## Headline

Scrolling a full-screen mouse-tracking program (htop) via xtty's SGR mouse-report path (`BRANCH 1`, "report"), then **reversing direction** after having scrolled some distance, reliably corrupts the redraw: stale characters from rows drawn *before* the reversal bleed into the new rows drawn *after* it, producing garbled text (e.g. `launchd` + a trailing ghost fragment `echd_syst` from an unrelated process several rows away). htop's own data keeps updating live in the corrupted rows (CPU%/MEM%/TIME+ tick normally) — this is a **redraw/stale-cell bug, not a frozen or hung child**. It is fully reproducible without physical hardware via the DEBUG injection hook, is specific to the mouse-report path (keyboard reproduces nothing, matched for volume and jump size), and does **not** reproduce in iTerm2 under the identical recipe. ✅ (measured + isolated + A/B-confirmed; SwiftTerm-source root cause still ❓).

## 1. The bug, measured

Real physical trackpad session (the original finding, task 4.4 step (c)): after flicking the trackpad up and down over htop for a while, the DEBUG grid dump showed rows like:

```
  381 root        17   0     0     0 ?   0.0  0.0  0:00.00 launchdechd_syst
  366 root        17   0     0     0 ?   0.0  0.0  0:00.00 logdhdogd
  370 root        50   0     0     0 ?   0.0  0.0  0:00.00 fseventsdagerd
```

`launchd` (correct name for that row) is followed by `echd_syst` — a fragment of `corespeechd_syst`, a *different* process that was visible in an earlier, more-scrolled-down frame. `logd` picks up `hdogd` (from `watchdogd`), `fseventsd` picks up `agerd` (from `kernelmanagerd`). Every ghost fragment matches a process name that was on-screen in the *previous* scroll position, at roughly the same row — not random noise, not a data-layer bug (the numeric columns for these same rows kept updating correctly in later dumps).

## 2. Isolation — what actually triggers it

Reproduced deterministically via the DEBUG wheel-injection hook (`App/PaneController.swift`'s `routeTestWheelInjection`, spec format `gesturePhase:momentumPhase:precise:deltaY:shift`), which drives the real `scrollWheel(with:)` — no CGEvent/hardware involved:

```bash
# fresh htop, then:
SPEC=/tmp/xtty-wheel-inject/spec.txt   # requires launching xtty with XTTY_TEST_WHEEL_PATH=$SPEC
echo "began:none:true:-30:false" > "$SPEC"; sleep 0.2   # scroll DOWN deep
for i in $(seq 1 120); do
  while [ -f "$SPEC" ]; do sleep 0.05; done
  echo "changed:changed:true:-35:false" > "$SPEC"        # negative deltaY = down (button 65)
done
echo "began:none:true:30:false" > "$SPEC"; sleep 0.2     # reverse: scroll UP back toward top
for i in $(seq 1 100); do
  while [ -f "$SPEC" ]; do sleep 0.05; done
  echo "changed:changed:true:35:false" > "$SPEC"          # positive deltaY = up (button 64)
done
# read /tmp/xtty-grid-dump.txt — the top rows show bled-through fragments
```

Isolation matrix (all against the same fresh-`htop`-per-run protocol, matched down/up magnitude so the viewport returns to the same position):

| Input method | Jump size | Direction reversal | Result |
|---|---|---|---|
| DEBUG wheel injection (`report` branch) | multi-row/tick | down (120) → up (100–120, matched) | **corrupted**, reliably, every run |
| Real physical trackpad flick | multi-row, variable | repeated up/down flicks | **corrupted** (the original finding) |
| Keyboard `Down`/`Up` arrows | 1 row/press | 300 down → 300 up (exact) | clean |
| Keyboard `Page Down`/`Page Up` | ~1 screen/press | 15 down → 15 up (exact) | clean |
| Real wheel scroll (`peekaboo scroll`, CGEvent) in **iTerm2**, same htop | multi-row/tick | 120 down → 120 up | clean |

So: **not** "any multi-row jump" (Page Down/Up is one too, and stays clean) — refuted in §4. **Not** htop-specific (iTerm2 runs the same htop, same jump pattern, clean). **Not** requiring real hardware (the DEBUG injection reproduces it with a synthetic, evenly-paced ~6–7 events/sec stream — nowhere near real trackpad's event rate). The one variable that flips it every time: **routing through xtty's SGR mouse-report branch, with a direction reversal after some distance already scrolled.**

**Not yet tested (❓):** whether momentum phase is required. All confirmed repros above used `momentumPhase: "changed"` (or a real momentum coast) on both legs. A pure discrete/non-momentum (`momentumPhase: "none"`) down-then-reverse-up injection sequence was not tried — open follow-up.

→ **Resolved 2026-07-10 (§7.2):** momentum is not required — a plain discrete, non-precise scripted tick reproduces it identically. Depth isn't required either — even a single tick each way triggers it, fully deterministically.

## 3. Scope relative to `smooth-scroll-wheel-momentum`

This is **not** a regression from `smooth-scroll-wheel-momentum`'s own diff (D1–D3: momentum-guard removal, per-gesture remainder reset, lossless whole-cell quantization). Reasoning:
- The corruption is character-level VT/redraw corruption in *htop's own drawn output*, not a routing-branch or row-count decision — nothing in D1–D3 touches how received bytes get painted to the grid.
- It reproduces via plain non-momentum-looking discrete ticks conceptually (see the un-tested ❓ above) and was first isolated using `momentumPhase:"changed"` injections, which existed as a code path (BRANCH 1 report) before this change too.

It **was** unreachable before `fix-scroll-wheel-mouse-reporting` shipped — prior to that change, wheel input never emitted SGR reports to a mouse-tracking full-screen app at all (§1 of `mouse-wheel-scroll-forensics.md`: "zero pty bytes"), so this defect had no way to manifest. It is best understood as a **latent SwiftTerm/xtty terminal-rendering bug newly exposed by the wheel→mouse-report feature family**, not caused by the momentum/accumulator work specifically.

## 4. Fates table — retired theories

| # | Theory | Verdict | Killed by |
|---|---|---|---|
| T1 | The large process/thread ID numbers seen in corrupted rows (e.g. `25099197`) are themselves the corruption. | ❌ | These are legitimate macOS kernel thread IDs (8-digit, non-sequential) — htop shows them when scrolled deep into a thread-heavy view. Real bug is the trailing **text** fragments in the Command column, unrelated to PID width. |
| T2 | htop's data feed froze/hung during the corruption. | ❌ | CPU%/MEM%/TIME+ columns in the *same* corrupted rows kept updating across repeated dumps a few seconds apart — the process is alive and refreshing; only specific screen cells are stale. |
| T3 | It's a `peekaboo` screen-capture artifact, not real. | ❌ | Confirmed via the app's own DEBUG grid dump (`/tmp/xtty-grid-dump.txt`, read directly from the terminal's internal buffer state, no screenshot involved) — the corruption is in xtty's actual model, not a capture-pipeline quirk. (A *separate*, real, already-documented peekaboo issue — blank/off-screen window capture, `native-app-testing-tooling.md:62` — was also hit along the way and is unrelated to this bug.) |
| T4 | Needs real hardware trackpad event rate (~60–120 Hz) — synthetic injection can't reproduce it. | ❌ | A sustained 81-tick DEBUG injection at ~6–7 events/sec (one direction only) stayed clean; the *same* rate with a **down-then-reverse-up** sequence corrupted reliably. Rate was never the variable. |
| T5 | Any multi-row jump (regardless of input method) triggers it, since single-row keyboard arrows are "too fine-grained" to hit it. | ❌ | Keyboard `Page Down`/`Page Up` (also multi-row jumps, same magnitude range as the wheel ticks), reversed with matched counts, stayed clean. |
| T6 | It's an htop quirk unrelated to xtty (e.g. htop's own mouse-scroll redraw path is buggy). | ❌ | Identical htop, identical `peekaboo scroll` down-then-up recipe, run against a real iTerm2 window — completely clean, every row correct. |
| T7 | 120 keyboard-arrow-key down-presses then 100 up-presses (unequal counts) not reproducing means keyboard is immune. | ❌ (methodology fix, not a real finding) | That test landed ~20 rows short of the true top (1 keypress = 1 row, so unequal counts don't return to the same position) — re-run with exactly matched 300/300 to land precisely back at row 0, still clean. Don't trust an "immune" result without confirming the viewport actually returned to the same reference point. |

## 5. Reusable guideline

**G(scroll-reversal): when a scroll-driven redraw bug is suspected, test direction reversal explicitly and hold every other variable (jump size, viewport start/end position, input volume) constant across arms — a single-direction scroll test, however thorough, will not surface a reversal-specific defect.** This bug survived three single-direction repro attempts (keyboard, one CGEvent burst, sustained one-direction DEBUG injection) before the down-then-reverse-up sequence caught it on the first try. When comparing two conditions (here: keyboard vs. wheel, or xtty vs. iTerm2), match the **net position reached**, not just the number of inputs sent — an unequal down/up count silently changes what's being compared (T7).

## 6. Status & artifacts

- **Not yet an OpenSpec change.** This is a real, reproducible, xtty-specific bug (confirmed by direct A/B against iTerm2) worth its own investigation and fix, but it is **out of scope** for `smooth-scroll-wheel-momentum` (§3) and does not block that change's archival. Tracked in `packer/README.md`'s expected-difference matrix alongside the other known-open, not-yet-fixed findings from this session (the confirm-close race). → **The diagnosis is now settled (§7)**; still no fix proposal drafted.
- **Open before a fix is attempted:** the SwiftTerm-source-level mechanism (❓ — likely a scroll-region/dirty-tracking bug in how `Terminal`/`MacTerminalView` handles the ANSI sequences htop emits on redraw, but not traced to a specific function this session); whether momentum phase is required (❓, §2); whether the trigger is *any* reversal or specifically a reversal that crosses back over previously-corrupted rows. → **All resolved 2026-07-10 — see §7.** Root cause found and source-cited (§7); momentum/depth resolved (§7.2); it's not "any reversal crossing corrupted rows" but specifically "any invocation of `cmdScrollDown`, reversal is just the practical way to reach it" (§7.1).
- **Re-verify by effect:** re-run the §2 injection recipe against a fresh `htop` on a Debug build launched with `XTTY_TEST_WHEEL_PATH` set; a clean top-of-list dump after the down-then-up sequence means this is fixed (or was never present in the build under test) — do not accept a report-branch-only check (`lastWheelRouting`) as sufficient, the defect is invisible to that field. → **Superseded by §7.5**, which adds a source-level re-check that doesn't require running the app at all.
- **Evidence:** session scratchpad (ephemeral — re-run the probe to reproduce): `/tmp/xtty-wheel-manual-log.jsonl` (routing-state timeline), `/tmp/xtty-grid-dump.txt` snapshots, `iterm-baseline-before.png` / `iterm-after-down-up.png` (iTerm2 A/B screenshots via `screencapture -x -D 1`).

## 7. Update (2026-07-10, same-day follow-up) — mechanism found, root cause confirmed

**Headline of this update:** the mechanism is no longer a ❓. Root cause, fully traced to source: SwiftTerm's `cmdScrollDown` (`Terminal.swift:4646-4667`, handles `CSI Ps T` / SD — "scroll down", the operation htop's ncurses issues when the user scrolls back **toward the top** of the process list) is missing the `if marginMode { … } else { … }` guard its sibling `cmdScrollUp` (`Terminal.swift:4672-4703`, `CSI Ps S` / SU) has. `cmdScrollDown` *always* computes its shift width as `columnCount = buffer.marginRight - buffer.marginLeft + 1` and does a narrow, margin-bounded per-cell `copyFrom` — with no fallback to a full-width whole-line splice when column-margin-mode (DECLRMM) is inactive, which is the case for htop (and virtually every normal terminal app — DECLRMM is a rarely-used feature). Traced fully: neither `Buffer.init` (`Buffer.swift:273-296`) nor `activateAltBuffer` (`Terminal.swift:789-802`, which creates/activates the alt-screen buffer htop runs on) ever sets `marginLeft`/`marginRight` — so they sit at their raw property defaults, `_marginLeft = 0` / `_marginRight = 0` (`Buffer.swift:162`, `175`). `Buffer.softReset()` (`Buffer.swift:370-382`) *does* correctly set `marginRight = cols-1`, but it is never invoked along the alt-buffer-activation path — so htop's alt buffer always has `marginLeft=0, marginRight=0`, giving **`columnCount = 1`**. Every SD scroll therefore shifts **only column 0** of the scroll region, leaving every other column (1 through cols-1) completely untouched — not shifted, not erased — for the lifetime of the scroll region. ✅ (source-confirmed, numerically verified, byte-exact real reproduction).

### 7.1 Why this explains every observed symptom, unified

- **The trailing Command-column garbage** (e.g. `launchd` + ghost `echd_syst`): the Command column sits well past column 0, so it's never touched by the buggy 1-column-wide shift — it simply retains whatever text was drawn there some number of scroll-ticks ago, frozen indefinitely (htop trusts the terminal to have already moved that content via the SD op it issued, so it doesn't redundantly rewrite untouched rows).
- **The single-digit/leading-character corruption** (a live-captured PID row `72422` → ` 2422`): column 0 is the *only* column the shift actually touches — it legitimately gets blanked/shifted, while columns 1+ (`2422`) are frozen, unrelated to the shift.
- **The row-duplication** (PID 378 `configd` shown at two physical rows in one frame): when htop's own internal view genuinely moves a process to a new physical row, htop explicitly redraws that new row with the correct content (confirmed: htop *does* explicitly rewrite boundary/changed rows with full `CR`+color+text+`EL` framing). But the process's **old** physical row's columns 1+ were never shifted or cleared by the buggy SD op — so the old row keeps showing the same content too. Two physical rows end up displaying the same process: one freshly (correctly) written by htop, one stale (never cleared) by the broken scroll. **One root cause, not two** — resolves T12 in the fates table below.
- **The CPU-meter-bar analog on width-shrink** (live-poking data, §7.2): same underlying class — any redraw path that shifts/copies fewer columns than it should leaves untouched trailing cells frozen; width-shrink just reaches a different, adjacent code path (not traced to the exact function, but the "columns silently un-updated" shape matches).
- **Why "reversal" specifically, and only via the mouse-report path:** `cmdScrollUp` (SU — invoked scrolling *down* the list, toward higher PIDs) is not buggy in the common case; it correctly falls back to a full-width whole-line splice when `marginMode` is off. `cmdScrollDown` (SD — invoked scrolling *up*, back toward the top) is **always** buggy, regardless of any prior direction. "Reversal" was never inherently special — a user has to scroll down at least once before there's room to scroll back up (if starting at the top), so reversal is simply the practical way to reach the direction that invokes the broken function. Keyboard arrow/page navigation stays clean because it takes an entirely different code path (`BRANCH 2`, sends cursor-key sequences; htop's own key handling doesn't invoke the same SD hardware-scroll optimization the same way mouse-driven list-scrolling does).

### 7.2 New live-reproduction facts (this session, via `peekaboo` against the running Debug build)

Confirmed interactively against a real Debug `xtty.app` (launched with `-UITestGridDump`, DEBUG grid/state dumps polled from `/tmp/xtty-grid-dump.txt` / `/tmp/xtty-state-dump.json`), driven with `peekaboo` (scroll/move/window/type) rather than physical hardware:

- **Momentum is not required.** A plain discrete, non-precise scripted wheel tick (`lastWheelRouting.momentum == false`, `.precise == false`, confirmed via the DEBUG dump after every gesture) reproduces the corruption identically to a real trackpad flick. Resolves the original doc's §2 open question.
- **Depth is not required.** From a freshly-healed clean baseline, the *shallowest possible* reversal — a single wheel tick down immediately followed by a single wheel tick up (which xtty's own quantization turns into exactly 5 SGR mouse-report events each direction, confirmed via `lastWheelRouting.count == 5`) — reproduces full corruption. No deep scroll into the list is needed.
- **It is fully deterministic.** Repeating the identical minimal down-then-up sequence from a freshly-healed clean baseline produces **byte-for-byte identical** garbled text every run (verified across ≥4 independent repro attempts).
- **A window resize that changes the actual character grid (rows/cols) heals it completely and instantly** — this only works if the resize crosses a real cell-size boundary, so htop receives a genuine `SIGWINCH` and does an unconditional full ncurses repaint (`clearok`/`redrawwin`-class). A resize that does **not** change rows/cols (e.g. a 1px bump) does nothing — htop never gets `SIGWINCH`, corruption persists unchanged. This became the decisive **model-vs-render discriminator**: a sub-cell resize forces the CoreGraphics view to fully redraw from the *same* (still-wrong) `Terminal` model without healing — proving the corruption lives in the model (`BufferLine` data), not the renderer (the renderer's own per-row dirty-skip optimization is disabled — an `#if false` in `AppleTerminalView.swift` — so every draw already rebuilds fresh from the model regardless).
- **An analogous, same-signature glitch appears in the CPU-meter-bar area on terminal-width-shrink** (stale trailing fragments like `4.6%]`/`unning` bleeding past a shorter new bar-string, surviving multiple live data updates) — same "survives repeated legitimate redraws" signature, likely the same class of bug via an adjacent code path.
- **A live-captured frame showed a full row duplicated** at two different physical positions (PID 378 `configd`, identical field values, twice) — now fully explained by §7.1.

### 7.3 Investigation-arc fates table (the mechanism hunt itself — distinct from §4's isolation-testing fates, numbered onward from T7 to avoid collision)

This session's mechanism hunt genuinely refuted-then-reinstated one line of investigation; recorded honestly because the "refutation" turned out to be a harness artifact, not new counter-evidence:

| # | Theory | Verdict | Killed / revived by |
|---|---|---|---|
| T8 | ncurses' own hashmap/hardscroll scroll-detection has a reversal-specific asymmetry bug | ❌ | Direct read of `mirror/ncurses`'s `tty/hashmap.c`/`hardscroll.c`: the algorithm is fully recomputed from the live `curscr`/`newscr` diff every `doupdate()` call, structurally symmetric across direction, no reversal-specific state. |
| T9 | htop's wheel-redraw idiom is pure `VPA`(`CSI Pn d`)+`DCH`(`CSI Pn P`)+text+`EL`(`CSI K`) — no scroll-region ops involved at all | ❌ **— refuted, but by a harness artifact, not new evidence.** | A bare `pty.fork()` capture of real htop receiving injected SGR wheel bytes found zero `CSI r`/`S`/`T`/`L`/`M` in 80 tick frames. This measurement was honest but of the wrong regime: a later check found htop's process-list body *never actually scrolled* in that harness (content stayed byte-identical across 60+ ticks despite htop visibly reacting) — a mouse-coordinate/focus-calibration gap specific to driving bare htop outside the real app. A subsequent **real** capture (via `script -q` wrapping htop inside the live, already-reproducing xtty app) found htop genuinely uses `DECSTBM`(`CSI 11;34 r`) + `SU`/`SD` (`CSI 10 S`/`CSI 10 T`) for real list-scrolling — T9 is retracted. |
| T10 | The mechanism is a **stale `marginRight`** left over from a `Buffer.resize` that clamps down on shrink but never restores on growth | ❌ | Direct read of `activateAltBuffer`/`Buffer.init`/`Buffer.resize` (`Buffer.swift:408-414`): htop's alt-buffer `marginRight` is never raised above its raw `0` default *in the first place* — no resize is needed for it to be wrong, and the real repro never involved a resize at all. |
| T11 | The divergence-creating operation is `DCH`/`EL`'s trailing-cell-clear logic (an erase that silently leaves stale cells) | ❌ | Direct read: `BufferLine.deleteCells` (`BufferLine.swift:152-168`) blanks the exact complement of the shifted range regardless of position, and `EL` erases from a `buffer.x` that `cmdCarriageReturn` (`Terminal.swift:1595`) reliably resets to 0 before each row-write — both handlers clear trailing cells correctly. The real defect (§7) is in the scroll-region **shift** width, not any erase op. |
| T12 | The row-duplication is a "skipped erase" of the old position — the same erase-divergence class as the trailing-garbage symptom | ❌ as literally stated → ✅ **unified under `columnCount=1`** | An adversarial critic correctly noted a genuinely-moved process implies a real content diff in htop's own model, so ncurses *would* emit fresh bytes for the old position — a surviving duplicate therefore isn't a "skipped erase." Resolved by §7.1: it isn't an erase failure at all — the buggy scroll only ever moves column 0, so the old row's columns 1+ are never touched by *any* mechanism, regardless of what ncurses decided to (re)send. |

**Dead instrument, explicitly recorded:** a bare `pty.fork()` Python harness driving real htop directly (no xtty app in the loop) with injected raw SGR mouse-report bytes. It **can** prove/disprove low-level byte-sequence questions about a *scrolling* htop, but it **cannot** be trusted to have actually scrolled htop just because htop reacted/repainted — confirm the app's own content genuinely changed (not just that bytes were sent and something came back) before treating a negative result from this kind of harness as evidence.

### 7.4 Reproducible probes (new this session)

**Minimal live repro, with the mouse-position gotcha** (a real, silent failure mode found this session: `peekaboo scroll --app/--window-title` does *not* reliably deliver events unless the cursor is actually over the target window):

```bash
# 1. Get window bounds, compute center, move there, and VERIFY (top-left-origin space):
peekaboo window list --app xtty --json   # read bounds: x, y, width, height
peekaboo move <centerX>,<centerY>
swift -e 'import AppKit; let loc = NSEvent.mouseLocation; let h = NSScreen.main?.frame.height ?? 0; print("x=\(loc.x), y=\(h - loc.y)")'
# confirm the printed x/y falls inside the window bounds — do this before every scroll, it has silently failed before

# 2. From a clean baseline, the minimal trigger:
peekaboo scroll --amount 1 --direction down --delay 15   # or --amount 10 for reliability margin
peekaboo scroll --amount 1 --direction up --delay 15

# 3. Confirm real delivery (don't trust peekaboo's own success message):
python3 -c "import json; print(json.load(open('/tmp/xtty-state-dump.json'))['lastWheelRouting'])"
# must show FRESH button/direction/count values, not stale leftover data from a prior gesture
```

**Heal back to a clean baseline** (resize must cross a real character-cell boundary — a 1px bump does nothing):

```bash
peekaboo window resize --app xtty --window-title htop --width 1000 --height 650; sleep 1.2
peekaboo window resize --app xtty --window-title htop --width 900 --height 592; sleep 1.2
# confirm clean via /tmp/xtty-grid-dump.txt before proceeding
```

**Real byte-exact capture + headless replay** (the decisive probe — proves the bug is 100% in upstream SwiftTerm's parser, zero xtty-app involvement): inside the live xtty pane, quit htop, relaunch wrapped in `script -q /tmp/htop-real-capture.typescript htop` (transparent PTY tap, no code changes), reproduce the minimal recipe above, then quit htop again to flush/close the typescript. Then feed the captured bytes into a headless SwiftTerm `Terminal` — the exact construction pattern already lives in this repo at `XttyCore/Tests/XttyCoreTests/TerminalSessionTests.swift`:

```swift
final class NoopTerminalDelegate: TerminalDelegate { func send(source: Terminal, data: ArraySlice<UInt8>) {} }
let engine = Terminal(delegate: NoopTerminalDelegate(), options: TerminalOptions(cols: 80, rows: 35))
engine.feed(byteArray: capturedBytes)   // capturedBytes = contents of the .typescript file, in order
for row in 0..<engine.rows {
    print(engine.getLine(row: row)?.translateToString(trimRight: true, skipNullCellsFollowingWide: true,
        characterProvider: { engine.getCharacter(for: $0) }) ?? "")
}
```

This reproduced **byte-for-byte identical** corrupted rows to the live app (verified 2026-07-10): `launchdechd_systCor`, `logdhdogdntAgentard`, `mediaremotediondstd`, the duplicated PID row, and the digit-corrupted PID — with zero PTY, zero view, zero timing involved; a single deterministic `feed()` call into upstream v1.13.0.

### 7.5 Re-verify by effect (supersedes §6's original re-verify note)

Re-running the §2 injection recipe (or §7.4's peekaboo recipe) and getting a clean top-of-list dump after a down-then-up reversal means the fix landed. For a **source-level** re-check that doesn't require running the app at all: confirm `cmdScrollDown` (search `Terminal.swift` for `func cmdScrollDown`) has gained the same `if marginMode { … } else { <full-width splice> }` shape `cmdScrollUp` already has — if it's still an unconditional `columnCount = buffer.marginRight - buffer.marginLeft + 1` narrow copy with no non-margin-mode fallback, the defect is still present regardless of what any test currently shows green (a routing-branch check like `lastWheelRouting` is blind to this — it was blind to it throughout this whole investigation).

### 7.6 Reusable guideline

**G(verify-the-regime): a verify-by-effect probe that returns a clean/negative result must confirm it actually reached the state under test — not just that it sent input and got some reaction back.** A harness can look diligent (real command execution, real bytes exchanged, real CPU spent) while never exercising the regime it was meant to probe. This session's bare-`pty.fork()` htop harness "reacted" to injected SGR bytes (repainted, used real byte volume) on every attempt, yet never actually moved htop's scroll offset — a negative result from it was worthless until cross-checked against the target's own ground truth (here: did the visible/dumped *content* actually change, not just "did output volume look plausible"). Complements §5's `G(scroll-reversal)`: that guideline is about test *design* (match net position across arms); this one is about test *validity* (confirm the probe reached the state it claims to test before trusting what it reports).

### 7.7 Status update

**No longer ❓ at the SwiftTerm-source level** (§6's original open item is resolved): root cause is `cmdScrollDown`'s missing `marginMode` guard (§7), fully source-cited and numerically confirmed (`marginLeft=marginRight=0` for htop's alt buffer → `columnCount=1`), with a byte-exact real reproduction that requires zero xtty-app involvement. **Still not yet an OpenSpec change** — this addendum settles the *diagnosis*; a fix proposal (mirroring `cmdScrollUp`'s `if marginMode {…} else {…}` shape onto `cmdScrollDown`, likely an upstream-SwiftTerm-style patch given the precedent established by `fix-scroll-wheel-mouse-reporting`/`smooth-scroll-wheel-momentum`) has not been drafted. Evidence from this session (ephemeral, re-run §7.4's recipes to reproduce): live grid/state dump snapshots, the real `.typescript` PTY capture, and a throwaway SPM headless-replay package — all in per-session `/tmp` scratch paths, none committed or persisted.
