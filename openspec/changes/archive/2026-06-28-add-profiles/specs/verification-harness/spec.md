## MODIFIED Requirements

### Requirement: Committed end-to-end UI test layer

The project SHALL include a macOS XCUITest target that launches the real xtty app and drives it via `XCUIApplication`, runnable with `xcodebuild test -scheme xtty`. The target MUST be type `bundle.ui-testing`, depend on the `xtty` app target, mirror the app's ad-hoc/manual signing, and keep its sources outside the app target's source tree. It SHALL cover focus-typing-on-activate, multi-line paste staged-not-executed, window-resize redraw, basic typed echo, and the multiplexing behaviors: splitting and closing panes, directional pane focus, and opening a tab and a window. It SHALL also cover the quick-terminal behavior — summon, typed echo, and dismiss — driven through a DEBUG-only "Toggle Quick Terminal" action that invokes the same `toggle()` as the global hotkey, because a real global hotkey cannot be synthesized by XCUITest. It SHALL also cover a profile-launched session: opening a tab with a named profile and asserting, via the state dump, that the pane reflects that profile.

#### Scenario: Running the test action drives the app

- **WHEN** a developer runs `xcodebuild test -project xtty.xcodeproj -scheme xtty -destination 'platform=macOS'`
- **THEN** the `xttyUITests` target builds, launches xtty, exercises the covered behaviors (including splits, pane focus, tabs/windows, the quick-terminal toggle, and a profile-launched tab), and reports pass/fail per test

#### Scenario: App target excludes test sources

- **WHEN** the app target (`sources: App`) is compiled
- **THEN** no XCUITest source is compiled into it (test sources live under `AppUITests/`)

#### Scenario: Quick terminal is exercised via a DEBUG toggle

- **WHEN** the tests trigger the DEBUG-only "Toggle Quick Terminal" action in a `-UITestGridDump` DEBUG build, type into the panel, and trigger it again
- **THEN** the quick terminal panel's grid dump shows the typed text, the panel hides on the second toggle, and the main multiplexing inventory (pane and tab counts) is unchanged throughout — confirming the quick terminal is excluded from the session registry

#### Scenario: Profile-launched tab reflects its profile

- **WHEN** the tests open a tab with a named profile (e.g. one setting a non-default theme/font and a `cwd`) in a `-UITestGridDump` DEBUG build
- **THEN** the state dump for that pane reports the profile name and the configured working directory and appearance, so the test can assert the profile was applied

### Requirement: Deterministic content assertion channel

Because SwiftTerm's terminal view exposes no per-cell text to accessibility, the harness SHALL assert terminal content via a DEBUG-only hook that writes the **focused pane's** headless engine grid to a temp file, plus `XCTAttachment` screenshots for human/vision review. When multiple panes, tabs, or windows exist, the hook SHALL additionally emit a DEBUG state dump describing the multiplexing inventory — at minimum the pane count, the focused pane, the tab count, and (for the focused pane) the name of the profile it was launched with and its working directory — so multiplexing and profile behaviors are deterministically assertable. The hook MUST be gated by `#if DEBUG` and the `-UITestGridDump` launch argument so it never runs in shipping or non-test builds. Accessibility identifiers SHALL be used only to locate the view/window and route input, never to read cell contents.

#### Scenario: Grid dump enables substring assertions on the focused pane

- **WHEN** the app is launched with `-UITestGridDump` in a DEBUG build and text is typed into the focused pane
- **THEN** the typed text appears in the grid-dump file for the focused pane and the test can assert on it deterministically

#### Scenario: Multiplexing inventory is observable

- **WHEN** the user splits a pane, closes a pane, or opens a new tab in a `-UITestGridDump` DEBUG build
- **THEN** the state dump reflects the updated pane count, focused pane, and tab count so the test can assert the multiplexing change

#### Scenario: Profile and working directory are observable

- **WHEN** a pane launched with a named profile is focused in a `-UITestGridDump` DEBUG build
- **THEN** the state dump reports that pane's profile name and working directory so the test can assert the profile-driven launch

#### Scenario: Graceful degradation without the hook

- **WHEN** the tests run against a build where the grid-dump hook is absent (e.g. Release)
- **THEN** the substring assertions are skipped and the screenshot attachments remain the verification record
