## 1. Hotkey model in XttyCore (pure, view-free)

- [x] 1.1 Add `HotKeySpec` to `XttyCore` (`virtualKeyCode: UInt32`, `modifiers: ModifierSet`, `display: String`; `Equatable`/`Sendable`) — toolkit-independent, no AppKit/Carbon import (the numeric `kVK_*` values are stored as plain `UInt32`; modifiers reuse the existing `ModifierSet`, mapped to a Carbon mask in the app adapter).
- [x] 1.2 Add the key-name → virtual-keycode table (~60 entries: letters, digits, F1–F12, `grave`/common punctuation, arrows, `space`, `escape`, `tab`, `return`) as local constants in `HotKeyParser`.
- [x] 1.3 Implement `HotKeyParser.parse(_:) -> HotKeySpec?`: split on `+`, recognize modifier tokens, require **≥1 modifier + exactly 1 non-modifier key**, reject `fn`, map the key name to its virtual keycode, build the display string, and fail-soft (return `nil`) on anything invalid.
- [x] 1.4 Factor the split + modifier-token recognizer shared with `KeybindParser` into `ChordTokenizing` so the two parsers' modifier vocabularies cannot drift (KeybindParser refactored onto it; its tests stay green).
- [x] 1.5 Add `HotKeyResolver` + `QuickTerminalSettings` (mirroring `KeybindResolver`): from the parsed `[String:String]` pairs, read `quick-terminal` (bool, default off) + `quick-terminal-hotkey` → an `enabled` flag + optional `HotKeySpec`, fail-soft with a `warn` callback.
- [x] 1.6 Unit tests (`swift test`): valid chords parse (e.g. `cmd+grave`, `ctrl+opt+t`); modifier-only / keyless / `fn` / unknown-key reject; resolver enables only when on + parseable, falls back/disables otherwise. **69/69 green.**

## 2. Global-hotkey OS binding (app, Carbon shim)

- [x] 2.1 Add a `GlobalHotKey` app type wrapping `RegisterEventHotKey` + `InstallEventHandler` + `UnregisterEventHotKey`, taking a `HotKeySpec` and a callback; bounce the `@convention(c)` handler through an `Unmanaged` `self` pointer passed as `userData`. (`ModifierSet` → Carbon mask mapping lives here.)
- [x] 2.2 Surface registration failure: a failable `init?` returns `nil` on non-`noErr` (e.g. a system-reserved combo) so the caller disables fail-soft; `deinit` unregisters the hotkey + handler (`nonisolated(unsafe)` for the Carbon pointers).

## 3. Quick-terminal panel (app)

- [x] 3.1 Create `QuickTerminalController` owning a borderless, non-activating `QuickTerminalPanel` subclass (`canBecomeKey = true`; `styleMask = [.nonactivatingPanel, .borderless, .resizable]`, `level = .mainMenu + 1`, `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]`, `isReleasedWhenClosed = false`, `hidesOnDeactivate = false`).
- [x] 3.2 Own a **private** `SessionRegistry` and lazily create one `PaneController` on first summon (config applied; the view fills the panel content) — excluding the quake from the app's main registry by construction (no `PaneController` change).
- [x] 3.3 Implement `toggle()`: target the screen under the mouse; **summon-to-active** (if showing on a different screen, move it there rather than hide; if on the target screen, hide); recompute the frame from the target screen on every show; order the panel in and make it key (for typing) / order it out on hide. (Instant order-in for v1; slide animation deferred — design Open Question.)
- [x] 3.4 On hide, `orderOut` lets AppKit return key/focus to the previously active context (non-activating panel); a shell exit tears the panel down so the next summon recreates a fresh scratch shell.

## 4. Wiring + config (app)

- [x] 4.1 In `AppDelegate`, resolve `quick-terminal` + `quick-terminal-hotkey` from the **existing single config read** (`loadConfigAndKeybindings` now returns `QuickTerminalSettings` too) via `HotKeyResolver`; when enabled + valid, create the `QuickTerminalController` and register a `GlobalHotKey` bound to `toggle()`.
- [x] 4.2 On a missing/unparseable chord the resolver disables the feature (warn); on a `RegisterEventHotKey` failure the controller still exists but logs that it can't be summoned by the hotkey — app launches normally.
- [x] 4.3 Quit accounting: when the last main window closes with a quake present, tear it down + `NSApp.terminate` (design D8); the no-quake path keeps relying on `applicationShouldTerminateAfterLastWindowClosed`. `applicationWillTerminate` tears down the quake + drops the hotkey.
- [x] 4.4 Document `quick-terminal` + `quick-terminal-hotkey` (example chord + off-by-default note) in `config.example`.

## 5. Harness (DEBUG hook + XCUITest)

- [x] 5.1 Add a `#if DEBUG` "Toggle Quick Terminal" item (in a DEBUG "Debug" menu) in `MainMenu`, `target: nil` → responder chain → `AppDelegate.toggleQuickTerminalForTest(_:)` → the same `toggle()` as the hotkey.
- [x] 5.2 Split the DEBUG dump into grid (content) + state (structure) writers (shared `UITestDump.writeGrid`); the app timer writes the quake pane's grid when its panel is key while still sourcing the inventory from a main window, so the quake stays out of the counts.
- [x] 5.3 Add `XttyQuickTerminalUITests`: trigger the DEBUG toggle, type into the panel, assert the panel grid dump shows the text; toggle again to hide; assert the main inventory (pane/tab counts) is unchanged and the app stays alive. **Green.**

## 6. Verify + trackers

- [x] 6.1 `xcodegen generate` (new source files), then `swift test` (XttyCore, **69/69**) and `xcodebuild test … platform=macOS` (app + **13 XCUITests**) all green.
- [ ] 6.2 Manual/Peekaboo check of the un-CI-able paths: the real global keypress summons from another app, multi-monitor summon-to-active, and focus returning to the previous app on hide. **(Pending manual verification — not assertable in XCUITest.)**
- [x] 6.3 Update trackers: AGENTS.md **Current status**, `research/04-design/02-milestones.md` (P3b progress), and `research/03-analysis/p3b-shell-ux-decisions.md` (mark the resolved quake open-questions: private-registry exclusion, shared modifier tokenizer).
