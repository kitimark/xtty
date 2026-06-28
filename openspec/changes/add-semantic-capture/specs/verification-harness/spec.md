## MODIFIED Requirements

### Requirement: Deterministic content assertion channel

Because SwiftTerm's terminal view exposes no per-cell text to accessibility, the harness SHALL assert terminal content via a DEBUG-only hook that writes the **focused pane's** headless engine grid to a temp file, plus `XCTAttachment` screenshots for human/vision review. When multiple panes, tabs, or windows exist, the hook SHALL additionally emit a DEBUG state dump describing the multiplexing inventory — at minimum the pane count, the focused pane, the tab count, and (for the focused pane) the name of the profile it was launched with and its working directory — so multiplexing and profile behaviors are deterministically assertable. The state dump SHALL also expose, for the focused pane, the **live working directory** (from OSC 7), whether the pane is on the **alternate screen**, and the captured **command-block list** (each with its command text, exit code, and state) — so semantic-capture behavior is deterministically assertable. The hook MUST be gated by `#if DEBUG` and the `-UITestGridDump` launch argument so it never runs in shipping or non-test builds. Accessibility identifiers SHALL be used only to locate the view/window and route input, never to read cell contents.

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

#### Scenario: Graceful degradation without the hook

- **WHEN** the tests run against a build where the grid-dump hook is absent (e.g. Release)
- **THEN** the substring assertions are skipped and the screenshot attachments remain the verification record

## ADDED Requirements

### Requirement: Semantic-capture end-to-end coverage

The harness SHALL cover semantic capture end-to-end by driving a real shell with shell-integration injection active and asserting, via the DEBUG state dump, that command blocks form with their exit codes, that the live working directory updates when the shell changes directory, and that a full-screen (alternate-screen) program does not produce a command block.

#### Scenario: Running commands produces blocks with exit codes

- **WHEN** the tests run a succeeding command and a failing command in an injected shell in a `-UITestGridDump` DEBUG build
- **THEN** the state dump shows a block for each with the correct command-end exit code and a succeeded/failed state

#### Scenario: Changing directory updates the live working directory

- **WHEN** the tests run `cd` to a known directory in an injected shell
- **THEN** the state dump's live working directory updates to that directory

#### Scenario: A full-screen program produces no block

- **WHEN** the tests start a program that switches to the alternate screen (e.g. `vim` or `tput smcup`)
- **THEN** the state dump shows the alternate-screen flag set and no command block created for the full-screen drawing
