## MODIFIED Requirements

### Requirement: Deterministic content assertion channel

Because SwiftTerm's terminal view exposes no per-cell text to accessibility, the harness SHALL assert terminal content via a DEBUG-only hook that writes the **focused pane's** headless engine grid to a temp file, plus `XCTAttachment` screenshots for human/vision review. When multiple panes, tabs, or windows exist, the hook SHALL additionally emit a DEBUG state dump describing the multiplexing inventory — at minimum the pane count, the focused pane, the tab count, and (for the focused pane) the name of the profile it was launched with and its working directory — so multiplexing and profile behaviors are deterministically assertable. The state dump SHALL also expose, for the focused pane, the **live working directory** (from OSC 7), whether the pane is on the **alternate screen**, the captured **command-block list** (each with its command text, exit code, and state), the derived **session activity state** (idle/running/succeeded/failed/fullScreen), and the **running command** text when one is in flight — so semantic-capture and session-progress behavior are deterministically assertable. The state dump SHALL also expose the **last resolved link-open action** for the focused pane — the target kind (URL or file), the working-directory-resolved path, the line/column when present, and whether the action was opened, blocked by the scheme guard, or a no-op — so file-link routing and working-directory resolution are deterministically assertable without launching a real editor. The state dump SHALL also expose the **last spatial-block operation** for the focused pane — the **last jump target row** (the display row a jump-to-prompt resolved to, or an indication that the jump was a no-op) and the **last copied output** text (what copy-command-output placed on the clipboard, or an indication of a no-op) — so jump-to-prompt and copy-command-output are deterministically assertable without inspecting the real clipboard or scroll chrome. The hook MUST be gated by `#if DEBUG` and the `-UITestGridDump` launch argument so it never runs in shipping or non-test builds. Accessibility identifiers SHALL be used only to locate the view/window and route input, never to read cell contents.

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

#### Scenario: Spatial-block operations are observable

- **WHEN** a jump-to-prompt or copy-command-output action runs in the focused pane in a `-UITestGridDump` DEBUG build
- **THEN** the state dump reports the last jump target row (or no-op) and the last copied output text (or no-op) so the test can assert jump and copy without inspecting scroll chrome or the real clipboard

#### Scenario: Graceful degradation without the hook

- **WHEN** the tests run against a build where the grid-dump hook is absent (e.g. Release)
- **THEN** the substring assertions are skipped and the screenshot attachments remain the verification record

## ADDED Requirements

### Requirement: Spatial-blocks end-to-end coverage
The harness SHALL cover the spatial-block operations end-to-end by driving a real shell with shell-integration injection active and asserting, via the DEBUG state dump, that jump-to-prompt resolves to an earlier command's prompt row and that copy-command-output captures a known command's output (excluding the trailing prompt). Coverage SHALL include a **scrolled-up** case (the operation is correct when the viewport is not at the bottom) and a **post-resize graceful-degradation** case (after a resize invalidates anchors, a jump or copy no-ops rather than acting on a misaligned row). The real clipboard and editor SHALL NOT be required for assertions (the copied text is asserted from the state dump).

#### Scenario: Jump resolves to an earlier prompt

- **WHEN** the tests run several commands in an injected shell, then trigger jump-to-previous-prompt in a `-UITestGridDump` DEBUG build
- **THEN** the state dump's last jump target row corresponds to an earlier command's prompt, so the test can assert the viewport moved to it

#### Scenario: Copy captures a known command's output

- **WHEN** the tests run a command with known output and trigger copy-command-output
- **THEN** the state dump's last copied output contains that output and not the following prompt

#### Scenario: Operation is correct while scrolled up

- **WHEN** the tests scroll the viewport up and then trigger a jump or copy
- **THEN** the resolved target/copied text is still correct (the scroll-invariant anchor compensates for the scroll position)

#### Scenario: Post-resize jump/copy degrades gracefully

- **WHEN** the tests resize the window (invalidating anchors) and then trigger a jump or copy before any new command runs
- **THEN** the state dump shows the action no-opped (no jump target / no copied output) rather than acting on a misaligned row
