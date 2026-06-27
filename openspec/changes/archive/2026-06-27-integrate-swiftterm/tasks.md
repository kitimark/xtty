## 1. XttyCore — ShellResolver (pure logic)

- [x] 1.1 Add `ShellResolver` to `XttyCore`: resolve shell path (`$SHELL` if set & executable → `getpwuid(getuid()).pw_shell` → `/bin/zsh`)
- [x] 1.2 Produce a launch config: `executable`, `args`, and `execName` = `"-" + basename(shell)` (login convention)
- [x] 1.3 Build the seed environment (`TERM=xterm-256color`, `COLORTERM=truecolor`, `LANG`); do not reconstruct PATH (login shell builds it)
- [x] 1.4 Unit tests (run via `swift test`, no app launch): `$SHELL` honored; fallback chain; argv[0] leading dash; seed env contents

## 2. XttyCore — TerminalSession (the seam anchor)

- [x] 2.1 Add `TerminalSession` holding the SwiftTerm `Terminal` engine handle (observe-only), the launch config, and an exit status field
- [x] 2.2 Keep `XttyCore` free of any concrete terminal-view import (engine type only); add an `exitCode` setter used by the exit policy
- [x] 2.3 Unit test: a `TerminalSession` can be constructed around a headless `Terminal` and records an exit code, without launching the app

## 3. App — host SwiftTerm in AppKit

_Revised from "host in SwiftUI": SwiftUI's `NSViewRepresentable` renders SwiftTerm black on macOS 26 (both CoreGraphics and Metal paths). The terminal is hosted in an AppKit `NSWindow` via `TerminalWindowController`. See `design.md`._

- [x] 3.1 Host `LocalProcessTerminalView` in an AppKit `NSWindow` via `TerminalWindowController` (replaces the planned `NSViewRepresentable`)
- [x] 3.2 In `TerminalWindowController.init`: resolve the shell via `XttyCore.ShellResolver`, set the controller as `processDelegate`, and call `startProcess(...)` exactly once
- [x] 3.3 Spawn exactly once at window creation (no `NSViewRepresentable`, so no `updateNSView` respawn footgun)
- [x] 3.4 Obtain `view.getTerminal()` and hand it to a `TerminalSession`; store the session on the controller
- [x] 3.5 Make the terminal first responder on appear and when the window becomes key
- [x] 3.6 Implement `processTerminated`: record the exit code on the session, then close the window (exit policy A)
- [x] 3.7 Terminate the child (`view.terminate()`) on teardown (window/app close) to avoid orphan shells

## 4. Wire into the window

- [x] 4.1 Drive the terminal window from AppKit (`@NSApplicationDelegateAdaptor` → `AppDelegate` creates `TerminalWindowController`); keep the SwiftUI `App` lifecycle with an inert `Settings` scene
- [x] 4.2 Open the window on the built-in display (`CGDisplayIsBuiltin`, fallback `NSScreen.main`) — verified placed on "Built-in Retina Display"
- [x] 4.3 Confirm `XttyCore` is the only path to the engine from app logic (no view internals reached for logic)

## 5. Verify

- [x] 5.1 `swift test` passes (ShellResolver + TerminalSession unit tests) — 14/14 pass
- [x] 5.2 Build & launch: window opens to a working shell; `echo $0` shows a login shell (leading `-`) — build succeeds; launched app spawns child `-zsh` (login shell, leading dash) confirmed via `ps`
- [x] 5.3 Dotfiles/PATH: a user alias and/or a PATH entry from `~/.zprofile`/`~/.zshrc` resolves in the shell — verified via grid dump: `$PATH` includes login-shell dirs (`~/.local/bin`, `~/.ghcup/bin`, …) and `~/.zshrc` is sourced (alias count 282)
- [x] 5.4 Run `vim` and `htop`; resize the window — both redraw correctly (no corruption) — verified: `vim` reflows cleanly on grow + shrink (box-drawing + emoji intact); `htop` reflows cleanly both directions (colored CPU/Mem meters, header, full→truncated Command column, function bar — no artifacts)
- [x] 5.5 Paste multi-line text — it is inserted, not auto-executed (bracketed paste) — verified: pasting `AAA\nBBB\nCCC` lands on a single multi-line input buffer (no `command not found` per line); also covered by XCUITest `testMultiLinePasteIsNotAutoExecuted`
- [x] 5.6 Scroll back through long output and select text — no display corruption — verified with `seq 1 500`: wheel-scroll through scrollback renders cleanly (lines 287–500, scrollbar tracks); drag-select highlights cleanly (stream selection) and Cmd+C copies the exact selected lines
- [x] 5.7 Focus: typing works immediately on window focus without an extra click — verified: key observer re-focuses the terminal on `didBecomeKeyNotification`; covered by XCUITest `testFocusTypingOnActivateWithoutClicking`
- [x] 5.8 Type `exit` — the window closes; verify no orphaned shell process remains — verified end-to-end: typing `exit` fired `processTerminated` → window closed → app terminated (last-window policy) and the child login shell was reaped (no orphan `zsh`)
- [x] 5.9 Run `openspec validate integrate-swiftterm` and resolve any issues — "Change is valid"
