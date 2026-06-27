## 1. Decompose into panes + view-free model (layer 1)

- [x] 1.1 Add `XttyCore` model: `Pane` (wraps `TerminalSession` + a stable `PaneID`), `PaneNode` (`.leaf`/`.split(axis, children)`, n-ary), and `SessionRegistry` (all live panes + focused `PaneID`); no AppKit/view imports. (`Pane.swift`, `PaneNode.swift`, `SessionRegistry.swift`; ratios deferred to the view layer per design.)
- [x] 1.2 Unit-test the model: split/close/collapse transforms and focus tracking, asserted without launching the app (`PaneModelTests.swift`, 9 tests; full suite 42 green).
- [x] 1.3 Extract `PaneController` (App): owns one `XttyTerminalView` + PTY + `TerminalSession`, is its `LocalProcessTerminalViewDelegate` (title, `processTerminated`, DEBUG dump moved here); reports to its owner via `PaneControllerDelegate`.
- [x] 1.4 Reduce `TerminalWindowController` to a window/tab owner of a `PaneNode` tree (single leaf) + `[PaneID: PaneController]`; preserve behavior (built-in-display placement, focus-on-key, exit→close-window). AppDelegate owns the shared `SessionRegistry` + loads config once.
- [x] 1.5 Re-route font-size to the responder chain (`target: nil`) on `XttyTerminalView` (with a `validateUserInterfaceItem` override, since SwiftTerm returns false for unknown selectors); removed the `AppDelegate` font methods. Full suite green (42 unit + 8 UI).

## 2. Configurable keybindings (XttyCore model + presets + menu wiring)

- [x] 2.1 Add `XttyCore` keybinding model (`KeyChord.swift`): `KeyAction` enum, toolkit-independent `KeyChord` (`KeyToken` + `ModifierSet`); no AppKit imports.
- [x] 2.2 Implement a pure `KeybindParser` (`KeybindParser.swift`): name→token table (letters, digits, arrows, `plus`/`minus`/`equal`/`space`), modifier aliases, validation (≥1 modifier + exactly 1 key); fail-soft (invalid → nil).
- [x] 2.3 Add the `iterm` (default) + `ghostty` presets and `Keybindings.resolve` = preset ⊕ overrides (`Keybindings.swift`).
- [x] 2.4 `KeybindResolver.resolve(from:warn:)` reads `keybind-style` (unknown → `iterm` + warn) and `keybind-<action>` overrides (unparseable → keep preset + warn) from the parsed pairs; P2's `XttyConfig` untouched. AppDelegate loads config + keybinds from one file read.
- [x] 2.5 Unit-tests (`KeybindTests.swift`, 10): chord parse valid/invalid, preset shape + completeness, style selection/fallback, single-action override. Suite 52 green.
- [x] 2.6 App adapter `KeybindAdapter` (`KeyChord → NSMenuItem`, arrows via `NSUpArrowFunctionKey` + `.function`); `MainMenu.build(keybindings:)` applies chords to font + Find items (hardcoded equivalents removed). 8 UI tests green.

## 3. Splits / panes (layer 2)

- [ ] 3.1 Render the `PaneNode` tree into nested `NSSplitView`s (n-ary per split node); mount in the window's content area.
- [ ] 3.2 Implement split-focused-pane (right/down): spawn a new self-contained `LocalProcessTerminalView` + session, update model + view tree, focus the new pane.
- [ ] 3.3 Implement close-focused-pane with collapse rule (single-child split collapses; survivor promoted) and spatial-neighbor focus-follow; terminate the closed pane's child.
- [ ] 3.4 Implement directional focus navigation (nearest-neighbor over leaf frames → `makeFirstResponder`); confirm SwiftTerm caret follows focus.
- [ ] 3.5 Add split/focus menu items routed via the responder chain, with key equivalents from `Keybindings` (group 2).
- [ ] 3.6 Verify divider-drag reflows both shells (a full-screen program redraws at the new size) — no extra wiring expected (SwiftTerm `setFrameSize → PTY`).

## 4. Native tabs + windows + lifecycle (layer 3)

- [ ] 4.1 Enable native window tabbing: set `tabbingMode = .preferred` and a shared `tabbingIdentifier`; let macOS draw the tab bar + Cmd+Shift+[/].
- [ ] 4.2 New tab via `newWindowForTab(_:)` (+ the new-tab keybinding) creating a tabbed window controller with its own pane tree; new window via the new-window keybinding.
- [ ] 4.3 Implement the unified close/exit escalation (pane → tab/window → quit) for BOTH shell-exit and user close; keep `applicationShouldTerminateAfterLastWindowClosed = true`.
- [ ] 4.4 Add `confirm-close` (built-in default on) prompting before closing a pane with a running foreground process.
- [ ] 4.5 Confirm tab title tracks `setTerminalTitle` per window/tab; verify drag-tab-out-to-window works (no state migration needed).

## 5. Clickable URL links (layer 4)

- [ ] 5.1 Override `requestOpenLink` on the pane delegate: open `http(s)` directly; confirm before opening any other scheme; never execute clicked text.
- [ ] 5.2 Confirm OSC 8 + implicit `http(s)` hover highlight works (default SwiftTerm behavior) in xtty's AppKit host.

## 6. Pane-aware verification harness

- [ ] 6.1 Make the DEBUG grid dump follow the focused pane (single path); add a multiplexing inventory to the state dump (pane count, focused pane, tab count, per-pane cols/rows).
- [ ] 6.2 Add a DEBUG "resolve link at (row,col)" action surfacing the matched URL for link tests (no real hit-testing).
- [ ] 6.3 XCUITests: split creates a 2nd pane (typed text reaches the focused pane), close returns to 1 + focus moves, directional focus switches panes.
- [ ] 6.4 XCUITests: new tab → 2 tabs, new window → 2nd window, last-pane close escalates to window close; link resolution returns the expected URL.
- [ ] 6.5 Run the full suite green: `xcodebuild test -project xtty.xcodeproj -scheme xtty -destination 'platform=macOS'` and `cd XttyCore && swift test`.

## 7. Docs & trackers

- [ ] 7.1 Document the keybinding config (`keybind-style` + `keybind-<action>`) and the two presets in `config.example`; note no other new config keys land in this change.
- [ ] 7.2 Tick this `tasks.md`, refresh AGENTS.md **Current status** + open-changes, and advance Phase 3 state in `research/04-design/02-milestones.md` (P3a spine done; P3b extras remaining).
- [ ] 7.3 `openspec validate add-tabs-and-splits` clean; commit implementation under `feat(app)` and any spec/docs under `docs(openspec)`.
