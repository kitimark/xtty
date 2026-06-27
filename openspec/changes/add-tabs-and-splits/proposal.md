## Why

xtty today is a single window hosting a single SwiftTerm view — one shell, no multiplexing. That's the one thing SwiftTerm's `TerminalView` does **not** provide, and it's table-stakes native UX (cf. Ghostty): without tabs and splits xtty can't be a daily driver for real work, and it can't host more than one agent CLI at a time. This is the **P3 native-shell-UX** milestone's core (M6 "great agent host", N3 "native splits/tabs"). It also lays the structural foundation — a view-free pane/session model — that the P5 session-progress sidebar and a future agent API will enumerate.

This change is the **spine** of P3 ("P3a"): decompose the monolithic controller, add splits + native tabs + window management, and surface clickable URL links (nearly free in SwiftTerm). The heavier, more-decision subsystems (Quick-Terminal dropdown, profiles, file:line error-matching) are deliberately deferred to a follow-up change ("P3b") — see Impact.

## What Changes

- **Decompose the god-object.** Today's `TerminalWindowController` owns the single view, its delegate, font sizing, exit policy, and the DEBUG dump. Split out a **`PaneController`** (the per-view `LocalProcessTerminalViewDelegate`, owning one self-contained `LocalProcessTerminalView` + PTY + `TerminalSession`); the window controller becomes a tab/window owning a **tree** of panes.
- **Splits / panes.** A window's content becomes a recursive split tree (`NSSplitView`) of terminal panes. New split (horizontal / vertical), close pane (with tree collapse), and directional focus navigation between panes. Divider-drag resize and per-pane focus (caret) ride SwiftTerm's existing `setFrameSize → PTY resize` and first-responder behavior.
- **Native tabs + windows.** Adopt macOS native window tabbing (`tabbingMode = .preferred` + a `tabbingIdentifier`; today it is `.disallowed`): each tab is its own window + pane tree, grouped by macOS — giving the tab bar, Cmd+Shift+[/], drag-tab-out, and Merge All for free. New tab (Cmd+T), new window (Cmd+N).
- **Unified close / exit escalation.** Both a shell exiting and Cmd+W resolve through one rule: close the **pane** (collapse the tree), escalating to close the tab/window only when it was the last pane, and quit when it was the last window. A configurable confirm-on-close guards a pane with a running foreground process. This replaces today's "shell exits → close the whole window" policy.
- **Responder-chain command routing.** Move pane-scoped menu actions (font size, and the new split/close/focus actions) onto the responder chain (`target: nil`), like Find/Copy/Paste already are — so "the active pane" is simply the key window's first responder and no controller needs to track it for dispatch.
- **Configurable keybindings with presets.** A `keybind-style` preset (`iterm` default, `ghostty`) plus per-action `keybind-<action>` overrides drive the app's menu key equivalents for the new split/focus/tab/window/close actions (and the existing font/find actions), so iTerm/Ghostty users can migrate with a familiar base and still rebind individual actions. The neutral chord parser + presets live view-free in `XttyCore` and are reused by P3b's Quick-Terminal global hotkey.
- **Clickable URL links.** Surface SwiftTerm's existing OSC 8 + implicit URL detection (hover highlight + open on click is already wired to `NSWorkspace.open`), adding a **security guard**: confirm before opening non-`http(s)` schemes. (Bare `file:line` matching is **not** free in SwiftTerm and is deferred — see Impact.)
- **View-free model in `XttyCore`.** Introduce a pane/split-tree model and a session registry (structure + identity + focus, no view types) that mirrors the AppKit tree — the single source non-view features read.
- **Harness:** make the DEBUG dump pane-aware (active-pane grid dump + a pane/tab inventory in the state dump) and add e2e tests for split/close/focus/new-tab/new-window and link resolution.

## Capabilities

### New Capabilities
- `terminal-multiplexing`: tabs, splits/panes, window management, per-pane focus, and the unified close/exit-escalation lifecycle — multiple terminal sessions arranged within and across native macOS windows/tabs.
- `terminal-links`: clickable links in terminal output — surfacing SwiftTerm's URL/OSC-8 detection with a security guard for non-`http(s)` schemes. (file:line error-matching and open-in-editor are out of scope here.)
- `terminal-keybindings`: configurable keybindings — a preset (`iterm` default / `ghostty`) plus per-action overrides, parsed by a view-free chord model in `XttyCore`, applied to the app's menu commands. The `keybind-*` config keys live in this capability (P2's `terminal-configuration` spec is left untouched).

### Modified Capabilities
- `app-shell`: the "present a single window on startup" requirement broadens to support multiple windows and native tabs (still one window at launch).
- `terminal-session`: the shell-exit policy changes from "shell exits → window closes" to per-pane close with escalation; a window may now hold multiple sessions, all still accessed only through the `XttyCore` seam.
- `verification-harness`: the DEBUG content channel becomes pane-aware (active-pane grid dump + pane/tab inventory) so multiplexing behaviors are deterministically assertable.

## Impact

- **Code:** `App/TerminalWindowController.swift` (decomposed into a window/tab controller + new `PaneController`), `App/MainMenu.swift` (split/close/focus/new-tab/window items, with key equivalents built from the resolved keybindings; font actions re-routed to the responder chain), `App/XttyApp.swift` (multi-window lifecycle, `newWindowForTab`), `App/TerminalConfigurator.swift` (per-pane apply). New `XttyCore` types (pane/split-tree model + session registry; keybinding chord model + presets + parser). Harness support + tests in `AppUITests/`.
- **Dependencies:** none new — native AppKit tabbing + `NSSplitView` + SwiftTerm's existing link support.
- **Deferred to P3b (`add-shell-ux-extras`):** Quick-Terminal dropdown (global hotkey + nonactivating panel), profiles (sectioned config that grows `terminal-configuration` and couples it to launch/`ShellResolver`), and **file:line error-matching / open-in-editor** — the last has a soft dependency on **P4 OSC 7 cwd** for resolving relative paths, so it may instead land with P4.
- **Risks:** native-tab semantics (a tab == a window) must be handled correctly for termination accounting; split-tree collapse correctness; keeping the harness deterministic with N panes. All covered by design.md + the harness tasks.
