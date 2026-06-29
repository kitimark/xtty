## MODIFIED Requirements

### Requirement: Deterministic content assertion channel

Because SwiftTerm's terminal view exposes no per-cell text to accessibility, the harness SHALL assert terminal content via a DEBUG-only hook that writes the **focused pane's** headless engine grid to a temp file, plus `XCTAttachment` screenshots for human/vision review. When multiple panes, tabs, or windows exist, the hook SHALL additionally emit a DEBUG state dump describing the multiplexing inventory — at minimum the pane count, the focused pane, the tab count, and (for the focused pane) the name of the profile it was launched with and its working directory — so multiplexing and profile behaviors are deterministically assertable. The state dump SHALL also expose, for the focused pane, the **live working directory** (from OSC 7), whether the pane is on the **alternate screen**, the captured **command-block list** (each with its command text, exit code, and state), the derived **session activity state** (idle/running/succeeded/failed/fullScreen), and the **running command** text when one is in flight — so semantic-capture and session-progress behavior are deterministically assertable. The state dump SHALL also expose the **last resolved link-open action** for the focused pane — the target kind (URL or file), the working-directory-resolved path, the line/column when present, and whether the action was opened, blocked by the scheme guard, or a no-op — so file-link routing and working-directory resolution are deterministically assertable without launching a real editor. The state dump SHALL also expose the **last spatial-block operation** for the focused pane — the **last jump target row** (the display row a jump-to-prompt resolved to, or an indication that the jump was a no-op) and the **last copied output** text (what copy-command-output placed on the clipboard, or an indication of a no-op) — so jump-to-prompt and copy-command-output are deterministically assertable without inspecting the real clipboard or scroll chrome. The state dump SHALL also expose, for the focused pane, a **git-review snapshot** — whether the working directory is a git repository and whether it is remote, the repository-root-relative paths and status categories of the changed files, the active changed-files list **layout** (status-category grouping vs directory tree), and a summary of the currently selected file's diff (added/removed line counts, binary/truncated flags, and the **intra-line emphasis spans** of the selected diff — counts/ranges only, never text) — read from a **cached** snapshot (the dump path SHALL NOT trigger a git query) and **never** including full diff text, so git-review listing, layout, diff selection, and intra-line emphasis are deterministically assertable. The hook MUST be gated by `#if DEBUG` and the `-UITestGridDump` launch argument so it never runs in shipping or non-test builds. Accessibility identifiers SHALL be used only to locate the view/window and route input, never to read cell contents.

#### Scenario: Grid dump enables substring assertions on the focused pane

- **WHEN** the app is launched with `-UITestGridDump` in a DEBUG build and text is typed into the focused pane
- **THEN** the typed text appears in the grid-dump file for the focused pane and the test can assert on it deterministically

### Requirement: Git-review end-to-end coverage
The harness SHALL cover the git-review panel end-to-end by driving a real shell with shell-integration injection active inside a temporary git repository and asserting, via the DEBUG state dump, that the panel lists the repository's changed files with their status categories for a known repository state, that selecting a changed file yields the expected diff summary (including, for a partial single-line change, **non-empty intra-line emphasis spans**), that the open-in-editor action routes through the editor opener — asserted via the existing **resolved link-open action** field, not a real editor — and that the changed-files list **layout** reported by the state dump reflects the configured default (flat vs directory tree). Coverage SHALL include the **non-repository** and **remote/unavailable** empty-state cases. The real editor SHALL NOT be required for assertions.

#### Scenario: Changed files are listed for a known repository state

- **WHEN** the tests create a temporary repository, make a known set of changes (a tracked modification, an untracked file), and show the git-review panel in a `-UITestGridDump` DEBUG build
- **THEN** the state dump's git-review snapshot lists those files with the correct status categories

#### Scenario: Selecting a file yields its diff summary

- **WHEN** the tests select a changed file with known content changes
- **THEN** the state dump's selected-diff summary reports the expected added/removed counts (or binary flag) for that file

#### Scenario: A substring edit produces intra-line emphasis

- **WHEN** the tests modify part of a single line in a tracked file and select it for diff
- **THEN** the state dump's selected-diff summary reports non-empty intra-line emphasis spans for that diff (counts/ranges, without full text)

#### Scenario: Open-in-editor routes through the opener

- **WHEN** the tests invoke the open-in-editor action on a changed file
- **THEN** the state dump's resolved link-open action reports the repository-resolved file path so the test can assert routing without launching a real editor

#### Scenario: The configured list layout is reported

- **WHEN** the tests launch with the git-review default layout configured to `tree` and show the panel for a repository with changed files in a `-UITestGridDump` DEBUG build
- **THEN** the state dump's git-review snapshot reports the directory-tree layout, so the test can assert the configured default was applied

#### Scenario: Empty states are observable

- **WHEN** the focused pane's directory is not a repository, or is remote/unavailable
- **THEN** the state dump's git-review snapshot reports the non-repository / remote flag so the test can assert the empty state
