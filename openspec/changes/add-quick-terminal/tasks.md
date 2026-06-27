## 1. Hotkey model in XttyCore (pure, view-free)

- [ ] 1.1 Add `HotKeySpec` to `XttyCore` (`virtualKeyCode: UInt32`, `carbonModifiers: UInt32`, `display: String`; `Equatable`/`Sendable`) — toolkit-independent, no AppKit/Carbon import (the numeric `kVK_*` / Carbon-mask values are defined locally as plain `UInt32` with comments).
- [ ] 1.2 Add the key-name → virtual-keycode table (~60 entries: letters, digits, F1–F12, `grave`/common punctuation, arrows, `space`, `escape`, `tab`, `return`) and the modifier-mask constants (`cmd`/`shift`/`option`/`control`) as local constants.
- [ ] 1.3 Implement `HotKeyParser.parse(_:) -> HotKeySpec?`: split on `+`, recognize modifier tokens, require **≥1 modifier + exactly 1 non-modifier key**, reject `fn`, map the key name to its virtual keycode, build the display string, and fail-soft (return `nil`) on anything invalid.
- [ ] 1.4 Factor the modifier-token recognizer shared with `KeybindParser` (a small shared helper) so the two parsers' modifier vocabularies cannot drift.
- [ ] 1.5 Add `HotKeyResolver` (mirroring `KeybindResolver`): from the parsed `[String:String]` pairs, read `quick-terminal` (bool, default off) + `quick-terminal-hotkey` → an `enabled` flag + optional `HotKeySpec`, fail-soft with a `warn` callback.
- [ ] 1.6 Unit tests (`swift test`): valid chords parse (e.g. `cmd+grave`, `ctrl+opt+t`); modifier-only / keyless / `fn` / unknown-key reject; resolver enables only when on + parseable, falls back/disables otherwise. Green.

## 2. Global-hotkey OS binding (app, Carbon shim)

- [ ] 2.1 Add a `GlobalHotKey` app type wrapping `RegisterEventHotKey` + `InstallEventHandler` + `UnregisterEventHotKey`, taking a `HotKeySpec` and a callback; bounce the `@convention(c)` handler through an `Unmanaged` `self` pointer passed as `userData`.
- [ ] 2.2 Surface registration failure: a non-`noErr` result (e.g. a system-reserved combo) is reported to the caller (no crash) so the feature can disable fail-soft; provide clean unregister/teardown.

## 3. Quick-terminal panel (app)

- [ ] 3.1 Create `QuickTerminalController` owning a borderless, non-activating `NSPanel` (`styleMask = [.nonactivatingPanel, .borderless]`, `level = .mainMenu + 1`, `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]`, `isReleasedWhenClosed = false`, `hidesOnDeactivate = false`).
- [ ] 3.2 Own a **private** `SessionRegistry` and lazily create one `PaneController` on first summon (config applied; the view fills the panel content) — excluding the quake from the app's main registry by construction (no `PaneController` change).
- [ ] 3.3 Implement `toggle()`: target the screen under the mouse; **summon-to-active** (if showing on a different screen, move it there rather than hide; if on the target screen, hide); recompute the frame from the target screen on every show; order the panel in and make it key (for typing) / order it out on hide.
- [ ] 3.4 On hide, let AppKit return focus to the previously active app (non-activating panel); ensure the panel + its shell never enter the main quit accounting.

## 4. Wiring + config (app)

- [ ] 4.1 In `AppDelegate`, resolve `quick-terminal` + `quick-terminal-hotkey` from the **existing single config read** via `HotKeyResolver`; when enabled + valid, create the `QuickTerminalController` and register a `GlobalHotKey` bound to `toggle()`.
- [ ] 4.2 On parse failure or `RegisterEventHotKey` failure, log and leave the feature disabled (no panel, no hotkey) — app still launches normally.
- [ ] 4.3 Quit accounting: closing the last *main* window terminates the app even when the quake exists/hidden; unregister the hotkey and tear down the controller on app termination.
- [ ] 4.4 Document `quick-terminal` + `quick-terminal-hotkey` (with an example chord and the off-by-default note) in `config.example`.

## 5. Harness (DEBUG hook + XCUITest)

- [ ] 5.1 Add a `#if DEBUG` "Toggle Quick Terminal" menu item in `MainMenu` that invokes the same `toggle()` as the hotkey, so XCUITest can drive the path without a synthesizable global keypress.
- [ ] 5.2 Ensure the app-level DEBUG dump follows the quake panel's focused pane when the panel is key (its grid is observable) and the main state-dump inventory continues to exclude the quake (private registry).
- [ ] 5.3 Add an XCUITest: trigger the DEBUG toggle, type into the panel, assert the panel grid dump shows the text; toggle again and assert the panel hides; assert the main multiplexing inventory (pane/tab counts) is unchanged throughout.

## 6. Verify + trackers

- [ ] 6.1 `xcodegen generate` (new source files), then `swift test` (XttyCore) and `xcodebuild test -project xtty.xcodeproj -scheme xtty -destination 'platform=macOS'` (app + UI) all green.
- [ ] 6.2 Manual/Peekaboo check of the un-CI-able paths: the real global keypress summons from another app, multi-monitor summon-to-active, and focus returning to the previous app on hide.
- [ ] 6.3 Update trackers: AGENTS.md **Current status**, `research/04-design/02-milestones.md` (P3b progress), and `research/03-analysis/p3b-shell-ux-decisions.md` (mark the resolved quake open-questions: private-registry exclusion, shared modifier tokenizer).
