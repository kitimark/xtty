# verification-harness Specification

## Purpose

Defines xtty's verification harness: a committed macOS XCUITest target that launches the real app and drives it via `XCUIApplication`, a deterministic content-assertion channel that reads the headless engine grid (a DEBUG-only, `-UITestGridDump`-gated hook) — necessary because the custom-drawn terminal view exposes no per-cell text to accessibility — and documented local manual tooling (Peekaboo) for exploratory/agent-driven inspection. It establishes how the P1 interactive behaviors are checked repeatably without relying on the accessibility tree.

## Requirements
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

Because SwiftTerm's terminal view exposes no per-cell text to accessibility, the harness SHALL assert terminal content via a DEBUG-only hook that writes the **focused pane's** headless engine grid to a temp file, plus `XCTAttachment` screenshots for human/vision review. When multiple panes, tabs, or windows exist, the hook SHALL additionally emit a DEBUG state dump describing the multiplexing inventory — at minimum the pane count, the focused pane, the tab count, and (for the focused pane) the name of the profile it was launched with and its working directory — so multiplexing and profile behaviors are deterministically assertable. The state dump SHALL also expose, for the focused pane, the **live working directory** (from OSC 7), whether the pane is on the **alternate screen**, the captured **command-block list** (each with its command text, exit code, and state), the derived **session activity state** (idle/running/succeeded/failed/fullScreen), and the **running command** text when one is in flight — so semantic-capture and session-progress behavior are deterministically assertable. The state dump SHALL also expose the **last resolved link-open action** for the focused pane — the target kind (URL or file), the working-directory-resolved path, the line/column when present, and whether the action was opened, blocked by the scheme guard, or a no-op — so file-link routing and working-directory resolution are deterministically assertable without launching a real editor. The hook MUST be gated by `#if DEBUG` and the `-UITestGridDump` launch argument so it never runs in shipping or non-test builds. Accessibility identifiers SHALL be used only to locate the view/window and route input, never to read cell contents.

#### Scenario: Grid dump enables substring assertions on the focused pane

- **WHEN** the app is launched with `-UITestGridDump` in a DEBUG build and text is typed into the focused pane
- **THEN** the typed text appears in the grid-dump file for the focused pane and the test can assert on it deterministically

#### Scenario: Multiplexing inventory is observable

- **WHEN** the user splits a pane, closes a pane, or opens a new tab in a `-UITestGridDump` DEBUG build
- **THEN** the state dump reflects the updated pane count, focused pane, and tab count so the test can assert the multiplexing change

#### Scenario: Profile and working directory are observable

- **WHEN** a pane launched with a named profile is focused in a `-UITestGridDump` DEBUG build
- **THEN** the state dump reports that pane's profile name and working directory so the test can assert the profile-driven launch

#### Scenario: Semantic capture state is observable

- **WHEN** commands run, the directory changes, or a full-screen app runs in the focused pane in a `-UITestGridDump` DEBUG build
- **THEN** the state dump reports the live working directory, the alternate-screen flag, and the command-block list (with exit codes and state) so the test can assert semantic capture

#### Scenario: Session activity and running command are observable

- **WHEN** a command is running, and again after it finishes succeeding or failing, in the focused pane in a `-UITestGridDump` DEBUG build
- **THEN** the state dump reports the derived session activity state (running, then succeeded/failed) and the running command text while it runs, so the test can assert the sidebar's data

#### Scenario: Resolved link-open action is observable

- **WHEN** a file or URL link is routed through the DEBUG link-open trigger in a `-UITestGridDump` DEBUG build
- **THEN** the state dump reports the resolved target path (resolved against the live working directory), the line/column when present, and the action (opened/blocked/no-op) so the test can assert routing without launching an editor

#### Scenario: Graceful degradation without the hook

- **WHEN** the tests run against a build where the grid-dump hook is absent (e.g. Release)
- **THEN** the substring assertions are skipped and the screenshot attachments remain the verification record

### Requirement: Local manual inspection tooling

The change SHALL document Peekaboo as local, uncommitted tooling for manual/agent-driven inspection (window screenshots, accessibility/window queries, synthetic input). It MUST NOT be part of the committed build or required for `xcodebuild test`. The documentation SHALL state the required macOS TCC grants (Accessibility + Screen Recording, attributed to the host terminal) and the accessibility-content ceiling for the custom-drawn terminal view.

#### Scenario: Agent drives the app manually

- **WHEN** Claude Code (or a developer) needs to inspect xtty interactively outside the committed tests
- **THEN** Peekaboo can screenshot the window, route input, and resize/move it via its CLI, with terminal content verified by screenshot/vision (not by the accessibility tree)

### Requirement: Semantic-capture end-to-end coverage

The harness SHALL cover semantic capture end-to-end by driving a real shell with shell-integration injection active and asserting, via the DEBUG state dump, that command blocks form with their exit codes, that the live working directory updates when the shell changes directory, and that a full-screen (alternate-screen) program does not produce a command block.

#### Scenario: Running commands produces blocks with exit codes

- **WHEN** the tests run a succeeding command and a failing command in an injected shell in a `-UITestGridDump` DEBUG build
- **THEN** the state dump shows a block for each with the correct command-end exit code and a succeeded/failed state

#### Scenario: Changing directory updates the live working directory

- **WHEN** the tests run `cd` to a known directory in an injected shell
- **THEN** the state dump's live working directory updates to that directory

#### Scenario: A full-screen program is not a normal command block

- **WHEN** the tests start a program that switches to the alternate screen (e.g. `vim` or `tput smcup`)
- **THEN** the state dump shows the alternate-screen flag set and the full-screen program is not recorded as a normal (succeeded/failed) command block — at most a single opaque block

### Requirement: Session-sidebar end-to-end coverage

The harness SHALL cover the session-progress sidebar end-to-end by driving a real injected shell and asserting, via the DEBUG state dump, that a pane's session activity state transitions to running while a command executes and to succeeded or failed after it completes, and that the running command text is reported while it runs. Because the sidebar is custom-drawn chrome with no per-cell accessibility text, the assertion SHALL be made against the state dump, not the accessibility tree.

#### Scenario: Sidebar state reflects a running then finished command

- **WHEN** the tests start a long-enough command and then let it finish (succeeding and, separately, failing) in an injected shell in a `-UITestGridDump` DEBUG build
- **THEN** the state dump shows the session activity as running with the running command text during execution, and as succeeded or failed (matching the exit code) afterward

### Requirement: File-link opening end-to-end coverage

The harness SHALL cover file-link click-to-open end-to-end by feeding a synthetic link string through a DEBUG-only trigger that exercises the real app routing pipeline and the focused session's live working directory, then asserting via the DEBUG state dump that a relative path resolves against the live working directory at the given line and that a non-permitted scheme is blocked. The real editor/opener SHALL NOT be launched during tests (the opener executor is a no-op in the DEBUG assertion path), so the test is deterministic and side-effect-free.

#### Scenario: A relative file link resolves against the live working directory

- **WHEN** the tests change to a known directory in an injected shell and then route a synthetic `path:line` link (e.g. `notes.txt:12`) through the DEBUG trigger in a `-UITestGridDump` DEBUG build
- **THEN** the state dump's last link-open action shows the path resolved under that directory at line 12 with action "opened", and no external editor process is launched

#### Scenario: A non-permitted scheme is blocked

- **WHEN** the tests route a synthetic link with a non-permitted scheme (e.g. `x-launch://do-something`) through the DEBUG trigger
- **THEN** the state dump's last link-open action shows the action "blocked" and nothing is opened or executed

