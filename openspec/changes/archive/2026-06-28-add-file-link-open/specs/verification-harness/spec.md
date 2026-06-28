## MODIFIED Requirements

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

## ADDED Requirements

### Requirement: File-link opening end-to-end coverage

The harness SHALL cover file-link click-to-open end-to-end by feeding a synthetic link string through a DEBUG-only trigger that exercises the real app routing pipeline and the focused session's live working directory, then asserting via the DEBUG state dump that a relative path resolves against the live working directory at the given line and that a non-permitted scheme is blocked. The real editor/opener SHALL NOT be launched during tests (the opener executor is a no-op in the DEBUG assertion path), so the test is deterministic and side-effect-free.

#### Scenario: A relative file link resolves against the live working directory

- **WHEN** the tests change to a known directory in an injected shell and then route a synthetic `path:line` link (e.g. `notes.txt:12`) through the DEBUG trigger in a `-UITestGridDump` DEBUG build
- **THEN** the state dump's last link-open action shows the path resolved under that directory at line 12 with action "opened", and no external editor process is launched

#### Scenario: A non-permitted scheme is blocked

- **WHEN** the tests route a synthetic link with a non-permitted scheme (e.g. `x-launch://do-something`) through the DEBUG trigger
- **THEN** the state dump's last link-open action shows the action "blocked" and nothing is opened or executed
