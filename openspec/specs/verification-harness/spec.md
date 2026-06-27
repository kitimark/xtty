# verification-harness Specification

## Purpose

Defines xtty's verification harness: a committed macOS XCUITest target that launches the real app and drives it via `XCUIApplication`, a deterministic content-assertion channel that reads the headless engine grid (a DEBUG-only, `-UITestGridDump`-gated hook) — necessary because the custom-drawn terminal view exposes no per-cell text to accessibility — and documented local manual tooling (Peekaboo) for exploratory/agent-driven inspection. It establishes how the P1 interactive behaviors are checked repeatably without relying on the accessibility tree.
## Requirements
### Requirement: Committed end-to-end UI test layer

The project SHALL include a macOS XCUITest target that launches the real xtty app and drives it via `XCUIApplication`, runnable with `xcodebuild test -scheme xtty`. The target MUST be type `bundle.ui-testing`, depend on the `xtty` app target, mirror the app's ad-hoc/manual signing, and keep its sources outside the app target's source tree. It SHALL cover focus-typing-on-activate, multi-line paste staged-not-executed, window-resize redraw, basic typed echo, and the multiplexing behaviors: splitting and closing panes, directional pane focus, and opening a tab and a window.

#### Scenario: Running the test action drives the app

- **WHEN** a developer runs `xcodebuild test -project xtty.xcodeproj -scheme xtty -destination 'platform=macOS'`
- **THEN** the `xttyUITests` target builds, launches xtty, exercises the covered behaviors (including splits, pane focus, and tabs/windows), and reports pass/fail per test

#### Scenario: App target excludes test sources

- **WHEN** the app target (`sources: App`) is compiled
- **THEN** no XCUITest source is compiled into it (test sources live under `AppUITests/`)

### Requirement: Deterministic content assertion channel

Because SwiftTerm's terminal view exposes no per-cell text to accessibility, the harness SHALL assert terminal content via a DEBUG-only hook that writes the **focused pane's** headless engine grid to a temp file, plus `XCTAttachment` screenshots for human/vision review. When multiple panes, tabs, or windows exist, the hook SHALL additionally emit a DEBUG state dump describing the multiplexing inventory — at minimum the pane count, the focused pane, and the tab count — so multiplexing behaviors are deterministically assertable. The hook MUST be gated by `#if DEBUG` and the `-UITestGridDump` launch argument so it never runs in shipping or non-test builds. Accessibility identifiers SHALL be used only to locate the view/window and route input, never to read cell contents.

#### Scenario: Grid dump enables substring assertions on the focused pane

- **WHEN** the app is launched with `-UITestGridDump` in a DEBUG build and text is typed into the focused pane
- **THEN** the typed text appears in the grid-dump file for the focused pane and the test can assert on it deterministically

#### Scenario: Multiplexing inventory is observable

- **WHEN** the user splits a pane, closes a pane, or opens a new tab in a `-UITestGridDump` DEBUG build
- **THEN** the state dump reflects the updated pane count, focused pane, and tab count so the test can assert the multiplexing change

#### Scenario: Graceful degradation without the hook

- **WHEN** the tests run against a build where the grid-dump hook is absent (e.g. Release)
- **THEN** the substring assertions are skipped and the screenshot attachments remain the verification record

### Requirement: Local manual inspection tooling

The change SHALL document Peekaboo as local, uncommitted tooling for manual/agent-driven inspection (window screenshots, accessibility/window queries, synthetic input). It MUST NOT be part of the committed build or required for `xcodebuild test`. The documentation SHALL state the required macOS TCC grants (Accessibility + Screen Recording, attributed to the host terminal) and the accessibility-content ceiling for the custom-drawn terminal view.

#### Scenario: Agent drives the app manually

- **WHEN** Claude Code (or a developer) needs to inspect xtty interactively outside the committed tests
- **THEN** Peekaboo can screenshot the window, route input, and resize/move it via its CLI, with terminal content verified by screenshot/vision (not by the accessibility tree)

