# Design: harden-churn-shell-readiness

## Context

The churn test fires ⌘W ~0.2–0.6 s after a fresh pane/tab registers — squarely inside the window where the new shell is still sourcing startup files. An empirical pty probe (`research/03-analysis/confirm-close-shell-readiness.md` §2) showed the foreground pgid equals the shell's from ~3 ms (before rc files run), then flickers through 15–57 ms child episodes (invisible to the 150 ms dump sampler) with the last flicker as late as ~2 s under load; CI's bash settles <35 ms with zero flicker. When a close lands on a child episode, the default confirm-close alert blocks it — and `NSAlert.runModal` spins `NSModalPanelRunLoopMode`, where the `.default`-mode dump timer freezes, so all subsequent waits read frozen JSON (artifact-confirmed in §7: instant-pass/5 s-timeout alternation, failure surfacing one step removed). Prior art (§4): no terminal fixes the fresh-shell race product-side; xtty's `tcgetpgrp` check is field-defensible — fix the test, not the product.

## Goals / Non-Goals

**Goals:**
- The churn test passes deterministically on machines with slow shell startup (local baseline F/F/P → consistently green) while still exercising the **user-default** close path (confirm-close on, real ⌘W keybinding).
- A churn step that cannot proceed fails **at that step** with truthful artifacts (no timeout cascade, no keystrokes into a modal).
- DEBUG dumps stay live during modal panels so future alert-class failures are diagnosable from artifacts.

**Non-Goals:**
- The `hasForegroundJob` state-dump field (pre-planned escalation, shipped only if a residual flake is observed).
- The churn test's **CI** failure mode (the SwiftUI menu clobber — `fix-main-menu-clobber`, separate change).
- Product changes to confirm-close (the at-prompt gate, bash shell integration, the zero-input latch — captured future candidates in the research doc).

## Decisions

- **D1 — Readiness = a computed-marker execution roundtrip, not a state wait.** After `paneCount==2` (resp. `tabCount==2`), type `echo $((41000+i))` (pane loop) / `echo $((42000+i))` (tab loop) and wait for the *output* token (`41001`…) in the grid dump. The token never appears in the echoed input line, so a match proves the shell **read and executed** a command — rc files complete, shell back at its prompt. Rejected alternatives (all per the research doc §5): a `hasForegroundJob` dump wait (empirically unusable — true from ~3 ms pre-rc; sampler blind to the flicker; k-consecutive-reads = a disguised load-scaled sleep), OSC-133-derived waits (`sessionActivity`/blocks — read `idle` during startup and are inert under CI bash), `confirm-close = false` (removes the very branch the leak net exercises), and prior-art product mechanisms (skip lists don't cover rc children; no terminal has a creation grace).
- **D2 — The gate goes in BOTH loops.** The tab loop closes an equally fresh shell through the identical `paneRequestsClose → confirmClose` path; §7's run 2 was struck in the tab loop. Unique per-iteration markers (41001–41004, 42001–42003) make stale-dump false-positives impossible.
- **D3 — Fail-fast, asserted steps.** `continueAfterFailure = false`; every `waitForState` result is asserted (no `_ =` discards); on a marker timeout the test attaches the grid dump and returns **without** sending ⌘W. This kills the §7-observed cascade (post-alert keystrokes into the modal, failure surfacing at the final census off frozen state).
- **D4 — Timeout 15 s, wrap-tolerant matching.** 15 s ≈ 7.5× the worst probe-measured settle (~2 s under synthetic load; real cold-cache churn can be slower — a generous budget beats a cliff). Grid matching uses the existing `ignoringLineWraps:` matcher (the `harden-focus-typing-assertion` lesson: long prompts wrap tokens). Warm cost ≈ +0.5–1 s/iteration.
- **D5 — Dump timer moves to `RunLoop.main.add(timer, forMode: .common)`.** `NSModalPanelRunLoopMode` is among AppKit's common modes, so dumps keep ticking during alerts. Observe-only: the `#if DEBUG` + `-UITestGridDump` gating is untouched; no consumer depends on the freeze. (The harness may *observe* during modals; it never *repairs* anything — the masking-hazard rule from the §15 review.)
- **D6 — Escalation is pre-planned, not shipped.** If a residual flake ever appears (the post-marker precmd window — prompt-render children can grab the tty 15–57 ms after the marker's output), the designed next step is a one-line `hasForegroundJob` dump field + a single post-marker `== false` wait (a single read is meaningful *post*-marker). Not speculatively included: it would add a dump field and a spec delta for a residual measured at ~nil.

## Risks / Trade-offs

- [Exotic rc configs may eat typed input during startup (raw-mode toggles, powerlevel10k instant prompt)] → the marker wait fails loudly at 15 s with an attached grid dump naming the iteration; the D6 escalation (or a per-machine investigation) follows the clear signal. Canonical-mode input buffering plus the suite's own SPLITMARK prior art cover the common case.
- [Post-marker precmd flicker (residual race, ~nil probability)] → D6 pre-planned escalation; a marker-gated close that still alerts would now fail *at its iteration* with live dumps (D3+D5), i.e. diagnosable in one run.
- [The churn test on CI stays red after this change] → pre-registered: its CI mode is the menu clobber (different root cause, separate change). The verify tasks document the expected local-green/CI-red split so the CI readout isn't misread.
- [+3–7 s test duration when green] → acceptable for a leak-net that was previously flaky; the alternative (dump-state waits) is either wrong or slower.

## Migration Plan

None — test-only changes plus one DEBUG-gated scheduling line. Reverting is a two-file revert.

## Open Questions

None blocking. The only watch-item is the D6 escalation trigger: a marker-gated churn failure at any iteration on any machine should be treated as the residual-flake signal, not re-rolled.
