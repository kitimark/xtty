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

- **Host the terminal in an AppKit `NSWindow`, not SwiftUI hosting.** *(Revised during implementation — supersedes the original "host via `NSViewRepresentable` in a SwiftUI `WindowGroup`" plan.)* SwiftTerm's `LocalProcessTerminalView` draws its grid into a hand-managed, layer-backed `CALayer` (CoreText `draw(_:)`). On **macOS 26**, SwiftUI's `NSViewRepresentable` host (`AppKitPlatformViewHost`) does not composite that subtree — the shell runs and the engine buffer fills, but the canvas stays **black**. We proved this empirically: the *same* view renders correctly in a plain `NSWindow` (as `contentView` **and** as a nested subview), and stays black under SwiftUI for **both** the CoreGraphics **and** the Metal render paths (even the `CAMetalLayer` an `MTKView` adds is not composited). Enabling SwiftTerm's Metal renderer did **not** fix it. So `XttyApp` keeps the SwiftUI `App` lifecycle but creates the terminal window in AppKit via an `NSApplicationDelegate` → `TerminalWindowController` (owns the `NSWindow` + `LocalProcessTerminalView`). The `XttyCore` seam is unchanged. This is corroborated by every Metal terminal we surveyed (Ghostty, iTerm2, SwiftTerm) — **none host the terminal surface through SwiftUI**; the terminal-bearing view (and its caret/find-bar/scroller siblings) must live in the AppKit hierarchy. SwiftUI may still host non-terminal chrome (P8 sidebar, file/diff) via `NSHostingView`.

- **Open the window on the built-in display.** The terminal window is centered on the `NSScreen` whose `CGDirectDisplayID` satisfies `CGDisplayIsBuiltin` (fallback `NSScreen.main`), because SwiftUI's `WindowGroup` defaulted to the *primary* screen (often an external monitor) and the user works on the built-in MacBook Pro display.

- **Renderer: CoreGraphics for P1; Metal deferred (per the milestone plan).** SwiftTerm's CoreGraphics path is the proven, battle-tested renderer and stays the **default**. We do **not** flip on SwiftTerm's built-in Metal (`setUseMetal(true)`) now: it is the least battle-tested of the surveyed renderers (single-frame-in-flight on the main thread, naive shelf atlas packer with all-or-nothing reset, plain-drawable present) and — critically — it does **not** even solve the black screen (the AppKit windowing fix does). Metal stays a **P2/P7 A/B measurement toggle** (cheap to wire now that hosting is AppKit), and a *custom* latency-first Metal renderer is a later-gate (P8) decision contingent on P7 measurement — cribbing Ghostty's IOSurface-as-`CALayer.contents` present + push/pull display-link split. See the research synthesis filed against this change.

- **Wrap `LocalProcessTerminalView` (L3), not a hand-built PTY.** It bundles PTY + view + input + selection + scrollback + bracketed paste. *Alternative:* own PTY loop now (L1) — rejected; that is the conditional P8 escape hatch, bought only with P7 measurement.

- **Spawn a login + interactive shell (argv[0] = `-zsh`).** The leading dash is the *mechanism* that makes PATH and dotfiles correct: a login shell sources `/etc/zprofile`+`~/.zprofile` (where `path_helper` sets PATH) and an interactive shell on a tty sources `~/.zshrc`. We seed only `TERM=xterm-256color`, `COLORTERM=truecolor`, `LANG` and let the shell do the rest. *Alternatives:* (a) inherit xtty's full environment — leaks our process env and still misses login-only setup; (b) bash default — ignores the user's chosen shell. Both rejected. Matches Terminal.app/iTerm.

- **`ShellResolver` lives in `XttyCore` as pure logic.** Resolves shell (`$SHELL` if set and executable, else `getpwuid(getuid()).pw_shell`, else `/bin/zsh`), derives argv[0] as `"-" + basename`, and builds the seed env. View-free → unit-testable without launching the app. This is the seam's first genuine test target.
  - **Seed env carries identity vars, not just `TERM`/`COLORTERM`/`LANG`.** SwiftTerm's `startProcess(environment:)` *replaces* the child environment wholesale (when non-nil it does not merge with `Terminal.getEnvironmentVariables`), so the seed must also mirror `HOME`/`USER`/`LOGNAME` from xtty's environment — otherwise the login shell may not find `~/.zprofile`/`~/.zshrc` and the M5 dotfiles guarantee breaks. We still never seed PATH (the login shell builds it). This matches what SwiftTerm's own env helper mirrors.

- **Introduce `TerminalSession` now (thin).** Holds the `Terminal` from `getTerminal()` (observe-only), the launch config, and the exit status. Justification: it is the unit P3 multiplies (1 window→1 session today, 1 window→N sessions later); retrofitting a session type after tabs exist is the painful order. *Alternative:* defer to P3 — rejected; this is exactly what the P0 seam was built to anchor.

- **Spawn exactly once, in `TerminalWindowController.init`.** *(Was "in `makeNSView`; `updateNSView` inert" under the SwiftUI plan.)* The controller creates the view, sets itself as `processDelegate`, resolves the shell via `XttyCore`, and calls `startProcess` once at window creation. There is no `updateNSView` respawn footgun anymore (no `NSViewRepresentable`). Startup sizing self-heals on first layout, so no need to defer the spawn.

- **Exit policy A: close the window when the shell exits.** macOS-default feel and simplest. `processTerminated` records `exitCode` on the `TerminalSession` first, then closes the window — so a future "freeze + banner" (option B) is a localized policy swap, not a re-architecture.

- **Terminate-on-teardown.** The Coordinator calls `view.terminate()` (SIGTERM) when the window/app closes, preventing orphan shells.

- **Focus management.** Make the terminal the window's first responder when it appears / the window becomes key; do not let SwiftUI steal it back on update.

## Risks / Trade-offs

- **SwiftUI hosting renders SwiftTerm black on macOS 26** (both CoreGraphics and Metal/`CAMetalLayer`) → host the terminal in an AppKit `NSWindow`, not `NSViewRepresentable`. Verified empirically and corroborated by Ghostty/iTerm2/SwiftTerm (none host the terminal through SwiftUI). The `updateNSView` respawn footgun is moot — there is no representable.
- **macOS 26 `_NSDisplayLinkForwarder` crash** (documented in iTerm2): a display-link callback through a dangling `CAMetalLayer` delegate crashes on window detach → when a future Metal renderer is added, clear the layer/display-link delegate and stop the link on `viewWillMove(toWindow: nil)`/`dealloc`. Not applicable to the CoreGraphics P1 path.
- **Orphan child processes** → `terminate()` on teardown; verify no stray shell after closing the window.
- **First-responder not set → "I type and nothing happens"** → Explicitly set first responder on appear and on window key changes; manual verification in tasks.
- **Login-shell variance (zsh vs bash vs fish; Starship/p10k prompts)** → We only launch the login shell; we do not parse prompts at P1. Prompt-hook fragility is a P4 concern, not here.
- **Initial size flash** (spawn before layout) → Acceptable; SwiftTerm resizes the PTY on first layout. Note in verification.
- **Seam erosion** (reaching into the view for convenience) → Encode "UI drives, `XttyCore` observes" in the `terminal-session` spec; keep `XttyCore` free of view imports (CI-checkable later).

## Open Questions

- `$SHELL` trust: if `$SHELL` is set but not in `/etc/shells`, do we still honor it? *Lean:* honor any executable `$SHELL` (developer machine, non-sandboxed) and fall back to `getpwuid`. Finalize in `ShellResolver`.
- Whether to pass `currentDirectory` at all in P1 (home dir vs inherit). *Lean:* leave nil (inherit) at P1; OSC 7-driven cwd is P4.
