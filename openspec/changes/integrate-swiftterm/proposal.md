## Why

P0 left us a buildable app that launches an *empty* window behind the `XttyCore` seam. P1 turns it into an actual terminal: spawn the user's login shell and host SwiftTerm's terminal view so you can run real programs. Starting at SwiftTerm **Level 3**, the PTY, VT parsing, rendering, input, selection, scrollback, and bracketed paste are already provided — so this change is integration + lifecycle discipline, and the first chance to give the `XttyCore` seam a real, testable referent.

## What Changes

- Add a **`terminal-session`** capability: a single live terminal in the app window, backed by SwiftTerm's `LocalProcessTerminalView` hosted in SwiftUI via `NSViewRepresentable`.
- **Spawn the user's login shell** so dotfiles/PATH work (M5): resolve the shell (`$SHELL` → `getpwuid` fallback) and launch it as a **login + interactive** shell (argv[0] = `-zsh`), seeding only `TERM`/`COLORTERM`/`LANG` and letting the login shell build the rest.
- Add **`XttyCore.ShellResolver`** (pure, view-free, unit-tested): resolve shell path, build login argv, assemble the seed environment.
- Add **`XttyCore.TerminalSession`**: a thin seam anchor holding the engine handle from `getTerminal()` (observe-only) plus launch config and exit status. This is the unit P3 (tabs/splits) will multiply.
- **Lifecycle:** spawn the shell exactly once (in `makeNSView`, never `updateNSView`); on window/app teardown call `terminate()` so no orphan shell is leaked; make the terminal first responder so keystrokes land.
- **Shell exit policy:** when the shell process exits, close the window (macOS-default behavior); record the exit code on the session for later use.
- **Out of scope (deferred):** font/size/theme config, scrollback cap, find bar (P2); tabs/splits/window management (P3); OSC 7 cwd and OSC 133 blocks (P4). Single window, single session.

## Capabilities

### New Capabilities
- `terminal-session`: a live, interactive terminal in the window — resolve and spawn the user's login shell over a PTY, host the SwiftTerm view, route the engine handle through `XttyCore`, and handle process lifecycle (spawn-once, focus, terminate-on-teardown, exit policy).

### Modified Capabilities
- `app-shell`: the window now hosts a live terminal session on launch (the P0 "no terminal session, rendering, or shell process is started" constraint is lifted). The engine-facing seam requirement is reinforced — UI hosts the view, `XttyCore` observes the engine.

## Impact

- **New code:** `App/` SwiftUI `NSViewRepresentable` host + Coordinator (delegate, lifecycle); `XttyCore` gains `ShellResolver` and `TerminalSession` (+ unit tests for `ShellResolver`).
- **Dependencies:** SwiftTerm moves from "resolved but unused" to wired into the UI (its `LocalProcessTerminalView`). No new third-party deps.
- **Behavior:** launching xtty now opens a working shell; closing the window terminates the child process.
- **Seam:** establishes the enduring rule — the view+PTY *drive* the engine; `XttyCore` only *observes* it. Keeps the L3→L1 escape hatch (P8) contained.
- Follows `research/04-design/02-milestones.md` (P1) and the SwiftTerm adoption decision in `research/04-design/01-stack-sketch.md`.
