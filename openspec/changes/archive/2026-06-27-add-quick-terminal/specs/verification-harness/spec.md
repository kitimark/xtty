## MODIFIED Requirements

### Requirement: Committed end-to-end UI test layer

The project SHALL include a macOS XCUITest target that launches the real xtty app and drives it via `XCUIApplication`, runnable with `xcodebuild test -scheme xtty`. The target MUST be type `bundle.ui-testing`, depend on the `xtty` app target, mirror the app's ad-hoc/manual signing, and keep its sources outside the app target's source tree. It SHALL cover focus-typing-on-activate, multi-line paste staged-not-executed, window-resize redraw, basic typed echo, and the multiplexing behaviors: splitting and closing panes, directional pane focus, and opening a tab and a window. It SHALL also cover the quick-terminal behavior — summon, typed echo, and dismiss — driven through a DEBUG-only "Toggle Quick Terminal" action that invokes the same `toggle()` as the global hotkey, because a real global hotkey cannot be synthesized by XCUITest.

#### Scenario: Running the test action drives the app

- **WHEN** a developer runs `xcodebuild test -project xtty.xcodeproj -scheme xtty -destination 'platform=macOS'`
- **THEN** the `xttyUITests` target builds, launches xtty, exercises the covered behaviors (including splits, pane focus, tabs/windows, and the quick-terminal toggle), and reports pass/fail per test

#### Scenario: App target excludes test sources

- **WHEN** the app target (`sources: App`) is compiled
- **THEN** no XCUITest source is compiled into it (test sources live under `AppUITests/`)

#### Scenario: Quick terminal is exercised via a DEBUG toggle

- **WHEN** the tests trigger the DEBUG-only "Toggle Quick Terminal" action in a `-UITestGridDump` DEBUG build, type into the panel, and trigger it again
- **THEN** the quick terminal panel's grid dump shows the typed text, the panel hides on the second toggle, and the main multiplexing inventory (pane and tab counts) is unchanged throughout — confirming the quick terminal is excluded from the session registry
