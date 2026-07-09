# Scroll-reversal redraw corruption — stale terminal cells bleed through when a mouse-tracking app's scroll direction reverses

> **Provenance:** Found 2026-07-10 during the human physical-trackpad verify for `smooth-scroll-wheel-momentum` (task 4.4, step (c) — htop back-pressure check). The user observed real corruption while flicking the trackpad in htop; the finding was then isolated via a live interactive debugging session (not a `/xtty:research` fan-out): the app's own DEBUG grid-dump (`-UITestGridDump`, `App/UITestDump.swift`) as ground truth, `peekaboo` for keyboard/mouse input synthesis and screen capture, and the existing DEBUG synthetic-wheel-injection hook (`XTTY_TEST_WHEEL_PATH`, added by `smooth-scroll-wheel-momentum` task 2.2) for deterministic, no-hardware repro. Claims tagged ✅ measured · ❌ refuted · ❓ open.
>
> **Sources:** live `htop` sessions inside a locally-built Debug `xtty.app` (`build/Build/Products/Debug/xtty.app`), driven via `peekaboo hotkey`/`peekaboo scroll`/`peekaboo paste` and the DEBUG wheel-injection file protocol; `/tmp/xtty-state-dump.json` + `/tmp/xtty-grid-dump.txt` (the app's own DEBUG dumps, polled and logged to a session scratchpad); a real iTerm2 window driven identically via `peekaboo scroll` + `screencapture -x -D 1` for the A/B baseline. No SwiftTerm source-level trace was done in this session — the mechanism below is **behaviorally isolated, not source-confirmed** (flagged ❓ where so).

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

- **Not yet an OpenSpec change.** This is a real, reproducible, xtty-specific bug (confirmed by direct A/B against iTerm2) worth its own investigation and fix, but it is **out of scope** for `smooth-scroll-wheel-momentum` (§3) and does not block that change's archival. Tracked in `packer/README.md`'s expected-difference matrix alongside the other known-open, not-yet-fixed findings from this session (the confirm-close race).
- **Open before a fix is attempted:** the SwiftTerm-source-level mechanism (❓ — likely a scroll-region/dirty-tracking bug in how `Terminal`/`MacTerminalView` handles the ANSI sequences htop emits on redraw, but not traced to a specific function this session); whether momentum phase is required (❓, §2); whether the trigger is *any* reversal or specifically a reversal that crosses back over previously-corrupted rows.
- **Re-verify by effect:** re-run the §2 injection recipe against a fresh `htop` on a Debug build launched with `XTTY_TEST_WHEEL_PATH` set; a clean top-of-list dump after the down-then-up sequence means this is fixed (or was never present in the build under test) — do not accept a report-branch-only check (`lastWheelRouting`) as sufficient, the defect is invisible to that field.
- **Evidence:** session scratchpad (ephemeral — re-run the probe to reproduce): `/tmp/xtty-wheel-manual-log.jsonl` (routing-state timeline), `/tmp/xtty-grid-dump.txt` snapshots, `iterm-baseline-before.png` / `iterm-after-down-up.png` (iTerm2 A/B screenshots via `screencapture -x -D 1`).
