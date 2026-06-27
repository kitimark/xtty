## 1. Decompose into panes + view-free model (layer 1)

- [ ] 1.1 Add `XttyCore` model: `Pane` (wraps `TerminalSession` + a stable `PaneID`), `PaneNode` (`.leaf`/`.split(axis, ratios, children)`), and `SessionRegistry` (all live panes + focused `PaneID`); no AppKit/view imports.
- [ ] 1.2 Unit-test the model: split/close/collapse transforms and focus tracking, asserted without launching the app (extend `XttyCoreTests`).
- [ ] 1.3 Extract `PaneController` (App): owns one `LocalProcessTerminalView` + PTY + `TerminalSession`, is its `LocalProcessTerminalViewDelegate` (title, `processTerminated`, font sizing, DEBUG dump moved here).
- [ ] 1.4 Reduce `TerminalWindowController` to a window/tab owner of a single-leaf pane tree; preserve current behavior (one window, one pane), built-in-display placement, focus-on-key.
- [ ] 1.5 Re-route font-size menu actions to the responder chain (`target: nil`), implemented on the focused pane/view; remove the `AppDelegate → single controller` font coupling. Verify existing font-size UI test still passes.

## 2. Splits / panes (layer 2)

- [ ] 2.1 Render the `PaneNode` tree into nested `NSSplitView`s (n-ary per split node); mount in the window's content area.
- [ ] 2.2 Implement split-focused-pane (horizontal/vertical): spawn a new self-contained `LocalProcessTerminalView` + session, update model + view tree, focus the new pane.
- [ ] 2.3 Implement close-focused-pane with collapse rule (single-child split collapses; survivor promoted) and spatial-neighbor focus-follow; terminate the closed pane's child.
- [ ] 2.4 Implement directional focus navigation (nearest-neighbor over leaf frames → `makeFirstResponder`); confirm SwiftTerm caret follows focus.
- [ ] 2.5 Add menu items + default keybindings (Cmd+D vertical, Cmd+Shift+D horizontal, Cmd+Opt+arrows focus) routed via the responder chain.
- [ ] 2.6 Verify divider-drag reflows both shells (a full-screen program redraws at the new size) — no extra wiring expected (SwiftTerm `setFrameSize → PTY`).

## 3. Native tabs + windows + lifecycle (layer 3)

- [ ] 3.1 Enable native window tabbing: set `tabbingMode = .preferred` and a shared `tabbingIdentifier`; let macOS draw the tab bar + Cmd+Shift+[/].
- [ ] 3.2 New tab via `newWindowForTab(_:)` (+ Cmd+T) creating a tabbed window controller with its own pane tree; new window via Cmd+N.
- [ ] 3.3 Implement the unified close/exit escalation (pane → tab/window → quit) for BOTH shell-exit and user close (Cmd+W); keep `applicationShouldTerminateAfterLastWindowClosed = true`.
- [ ] 3.4 Add `confirm-close` (built-in default on) prompting before closing a pane with a running foreground process.
- [ ] 3.5 Confirm tab title tracks `setTerminalTitle` per window/tab; verify drag-tab-out-to-window works (no state migration needed).

## 4. Clickable URL links (layer 4)

- [ ] 4.1 Override `requestOpenLink` on the pane delegate: open `http(s)` directly; confirm before opening any other scheme; never execute clicked text.
- [ ] 4.2 Confirm OSC 8 + implicit `http(s)` hover highlight works (default SwiftTerm behavior) in xtty's AppKit host.

## 5. Pane-aware verification harness

- [ ] 5.1 Make the DEBUG grid dump follow the focused pane (single path); add a multiplexing inventory to the state dump (pane count, focused pane, tab count, per-pane cols/rows).
- [ ] 5.2 Add a DEBUG "resolve link at (row,col)" action surfacing the matched URL for link tests (no real hit-testing).
- [ ] 5.3 XCUITests: split creates a 2nd pane (typed text reaches the focused pane), close returns to 1 + focus moves, directional focus switches panes.
- [ ] 5.4 XCUITests: Cmd+T → 2 tabs, Cmd+N → 2nd window, last-pane close escalates to window close; link resolution returns the expected URL.
- [ ] 5.5 Run the full suite green: `xcodebuild test -project xtty.xcodeproj -scheme xtty -destination 'platform=macOS'` and `cd XttyCore && swift test`.

## 6. Docs & trackers

- [ ] 6.1 Update `config.example`/docs if any user-facing default is introduced (e.g. note keybindings); no new config keys land in this change.
- [ ] 6.2 Tick this `tasks.md`, refresh AGENTS.md **Current status** + open-changes, and advance Phase 3 state in `research/04-design/02-milestones.md` (P3a spine done; P3b extras remaining).
- [ ] 6.3 `openspec validate add-tabs-and-splits` clean; commit implementation under `feat(app)` and any spec/docs under `docs(openspec)`.
