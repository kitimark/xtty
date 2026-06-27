## 1. XttyCore — ShellResolver (pure logic)

- [ ] 1.1 Add `ShellResolver` to `XttyCore`: resolve shell path (`$SHELL` if set & executable → `getpwuid(getuid()).pw_shell` → `/bin/zsh`)
- [ ] 1.2 Produce a launch config: `executable`, `args`, and `execName` = `"-" + basename(shell)` (login convention)
- [ ] 1.3 Build the seed environment (`TERM=xterm-256color`, `COLORTERM=truecolor`, `LANG`); do not reconstruct PATH (login shell builds it)
- [ ] 1.4 Unit tests (run via `swift test`, no app launch): `$SHELL` honored; fallback chain; argv[0] leading dash; seed env contents

## 2. XttyCore — TerminalSession (the seam anchor)

- [ ] 2.1 Add `TerminalSession` holding the SwiftTerm `Terminal` engine handle (observe-only), the launch config, and an exit status field
- [ ] 2.2 Keep `XttyCore` free of any concrete terminal-view import (engine type only); add an `exitCode` setter used by the exit policy
- [ ] 2.3 Unit test: a `TerminalSession` can be constructed around a headless `Terminal` and records an exit code, without launching the app

## 3. App — host SwiftTerm in SwiftUI

- [ ] 3.1 Add an `NSViewRepresentable` (`TerminalHostView`) wrapping `LocalProcessTerminalView`; create the view in `makeNSView`
- [ ] 3.2 In `makeNSView`: resolve the shell via `XttyCore.ShellResolver`, set the `Coordinator` as `processDelegate`, and call `startProcess(...)` exactly once
- [ ] 3.3 Keep `updateNSView` inert (no respawn); guard with a "started" flag on the Coordinator
- [ ] 3.4 Obtain `view.getTerminal()` and hand it to a `TerminalSession`; store the session on the Coordinator
- [ ] 3.5 Make the terminal first responder on appear and when the window becomes key
- [ ] 3.6 Implement `processTerminated`: record the exit code on the session, then close the window (exit policy A)
- [ ] 3.7 Terminate the child (`view.terminate()`) on teardown (window/app close) to avoid orphan shells

## 4. Wire into the window

- [ ] 4.1 Replace the empty `ContentView` with `TerminalHostView` in the `WindowGroup`
- [ ] 4.2 Confirm `XttyCore` is the only path to the engine from app logic (no view internals reached for logic)

## 5. Verify

- [ ] 5.1 `swift test` passes (ShellResolver + TerminalSession unit tests)
- [ ] 5.2 Build & launch: window opens to a working shell; `echo $0` shows a login shell (leading `-`)
- [ ] 5.3 Dotfiles/PATH: a user alias and/or a PATH entry from `~/.zprofile`/`~/.zshrc` resolves in the shell
- [ ] 5.4 Run `vim` and `htop`; resize the window — both redraw correctly (no corruption)
- [ ] 5.5 Paste multi-line text — it is inserted, not auto-executed (bracketed paste)
- [ ] 5.6 Scroll back through long output and select text — no display corruption
- [ ] 5.7 Focus: typing works immediately on window focus without an extra click
- [ ] 5.8 Type `exit` — the window closes; verify no orphaned shell process remains (e.g. `pgrep -lf zsh`)
- [ ] 5.9 Run `openspec validate integrate-swiftterm` and resolve any issues
