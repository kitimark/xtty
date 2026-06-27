## Context

P0 (`add-app-skeleton`) delivered a non-sandboxed macOS app that launches an empty window, a UI-free `XttyCore` SPM package, and SwiftTerm v1.13.0 resolved but unused. P1 implements milestone **P1** in [research/04-design/02-milestones.md](../../../research/04-design/02-milestones.md): wire SwiftTerm into the window to get a real terminal, at SwiftTerm **Level 3** (wrap `LocalProcessTerminalView`).

Constraints come from the stack sketch's adoption decision ([01-stack-sketch.md](../../../research/04-design/01-stack-sketch.md)) and product values: **M5 keep the user's zsh/tmux/dotfiles working**, and the **load-bearing seam** — all xtty logic talks to the `Terminal` engine via `XttyCore`, never to view internals.

**Grounded facts about SwiftTerm (read from the resolved checkout):**
- `LocalProcessTerminalView.startProcess(executable:args:environment:execName:currentDirectory:)` defaults `executable` to `/bin/bash` and `execName` (argv[0]) to nil — **no login-shell semantics; that is ours.**
- `Terminal.getEnvironmentVariables()` seeds only `TERM`, `COLORTERM`, `LANG` and mirrors a few vars — **PATH is explicitly omitted.** A login shell must build PATH from dotfiles.
- `getWindowSize()` derives the PTY winsize from the view frame; `setFrameSize`/`resizeSubviews` recompute cols/rows on layout — **startup sizing self-heals after first layout.**
- Bracketed paste (mode 2004) is fully implemented — **multi-line paste safety is free.**
- `terminate()` sends `SIGTERM` to the child — **teardown must call it or leak orphan shells.**
- The view already sets `acceptsFirstResponder = true` and implements `becomeFirstResponder` — **input works once it is in the responder chain.**

## Goals / Non-Goals

**Goals:**
- A single live, interactive terminal in the window running the user's login shell.
- Dotfiles/PATH work because the shell is launched login+interactive (M5).
- The `XttyCore` seam gets real referents: `ShellResolver` (pure, tested) and `TerminalSession` (engine handle, observe-only).
- Correct process lifecycle: spawn-once, focus, terminate-on-teardown, exit policy.

**Non-Goals:**
- Font/size/theme, truecolor/ligature verification, scrollback cap, find bar (P2).
- Tabs, splits, multiple windows/sessions (P3).
- OSC 7 cwd / OSC 133 block capture (P4) — even though SwiftTerm exposes the hooks, we do not wire them here.
- Driving the engine from `XttyCore` (feeding bytes) — the view+PTY owns that.

## Decisions

- **Wrap `LocalProcessTerminalView` (L3), not a hand-built PTY.** It bundles PTY + view + input + selection + scrollback + bracketed paste. *Alternative:* own PTY loop now (L1) — rejected; that is the conditional P8 escape hatch, bought only with P7 measurement.

- **Spawn a login + interactive shell (argv[0] = `-zsh`).** The leading dash is the *mechanism* that makes PATH and dotfiles correct: a login shell sources `/etc/zprofile`+`~/.zprofile` (where `path_helper` sets PATH) and an interactive shell on a tty sources `~/.zshrc`. We seed only `TERM=xterm-256color`, `COLORTERM=truecolor`, `LANG` and let the shell do the rest. *Alternatives:* (a) inherit xtty's full environment — leaks our process env and still misses login-only setup; (b) bash default — ignores the user's chosen shell. Both rejected. Matches Terminal.app/iTerm.

- **`ShellResolver` lives in `XttyCore` as pure logic.** Resolves shell (`$SHELL` if set and executable, else `getpwuid(getuid()).pw_shell`, else `/bin/zsh`), derives argv[0] as `"-" + basename`, and builds the seed env. View-free → unit-testable without launching the app. This is the seam's first genuine test target.

- **Introduce `TerminalSession` now (thin).** Holds the `Terminal` from `getTerminal()` (observe-only), the launch config, and the exit status. Justification: it is the unit P3 multiplies (1 window→1 session today, 1 window→N sessions later); retrofitting a session type after tabs exist is the painful order. *Alternative:* defer to P3 — rejected; this is exactly what the P0 seam was built to anchor.

- **Spawn exactly once, in `makeNSView`; `updateNSView` is inert at P1.** `updateNSView` re-runs on every SwiftUI state change; calling `startProcess` there would respawn shells. The `Coordinator` creates the view, sets itself as `processDelegate`, resolves the shell via `XttyCore`, and calls `startProcess` once. Startup sizing self-heals on first layout, so no need to defer the spawn.

- **Exit policy A: close the window when the shell exits.** macOS-default feel and simplest. `processTerminated` records `exitCode` on the `TerminalSession` first, then closes the window — so a future "freeze + banner" (option B) is a localized policy swap, not a re-architecture.

- **Terminate-on-teardown.** The Coordinator calls `view.terminate()` (SIGTERM) when the window/app closes, preventing orphan shells.

- **Focus management.** Make the terminal the window's first responder when it appears / the window becomes key; do not let SwiftUI steal it back on update.

## Risks / Trade-offs

- **`updateNSView` respawn footgun** → Spawn only in `makeNSView`; keep `updateNSView` inert; assert/guard a "started" flag on the Coordinator.
- **Orphan child processes** → `terminate()` on teardown; verify no stray shell after closing the window.
- **First-responder not set → "I type and nothing happens"** → Explicitly set first responder on appear and on window key changes; manual verification in tasks.
- **Login-shell variance (zsh vs bash vs fish; Starship/p10k prompts)** → We only launch the login shell; we do not parse prompts at P1. Prompt-hook fragility is a P4 concern, not here.
- **Initial size flash** (spawn before layout) → Acceptable; SwiftTerm resizes the PTY on first layout. Note in verification.
- **Seam erosion** (reaching into the view for convenience) → Encode "UI drives, `XttyCore` observes" in the `terminal-session` spec; keep `XttyCore` free of view imports (CI-checkable later).

## Open Questions

- `$SHELL` trust: if `$SHELL` is set but not in `/etc/shells`, do we still honor it? *Lean:* honor any executable `$SHELL` (developer machine, non-sandboxed) and fall back to `getpwuid`. Finalize in `ShellResolver`.
- Whether to pass `currentDirectory` at all in P1 (home dir vs inherit). *Lean:* leave nil (inherit) at P1; OSC 7-driven cwd is P4.
