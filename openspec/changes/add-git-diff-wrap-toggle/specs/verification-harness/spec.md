## MODIFIED Requirements

### Requirement: Deterministic content assertion channel

Because SwiftTerm's terminal view exposes no per-cell text to accessibility, the harness SHALL assert terminal content via a DEBUG-only hook that writes the **focused pane's** headless engine grid to a temp file, plus `XCTAttachment` screenshots for human/vision review. When multiple panes, tabs, or windows exist, the hook SHALL additionally emit a DEBUG state dump describing the multiplexing inventory — at minimum the pane count, the focused pane, the tab count, and (for the focused pane) the name of the profile it was launched with and its working directory — so multiplexing and profile behaviors are deterministically assertable. The state dump SHALL also expose, for the focused pane, the **live working directory** (from OSC 7), whether the pane is on the **alternate screen**, the captured **command-block list** (each with its command text, exit code, state, and whether it currently has a usable jump/copy anchor), the derived **session activity state** (idle/running/succeeded/failed/fullScreen), and the **running command** text when one is in flight — so semantic-capture and session-progress behavior are deterministically assertable. The state dump SHALL also expose the **last resolved link-open action** for the focused pane — the target kind (URL or file), the working-directory-resolved path, the line/column when present, and whether the action was opened, blocked by the scheme guard, or a no-op — so file-link routing and working-directory resolution are deterministically assertable without launching a real editor. The state dump SHALL also expose the **last spatial-block operation** for the focused pane — the **last jump target row** (the display row a jump-to-prompt or a designated-block scroll resolved to, or an indication that it was a no-op) and the **last copied output** text (what copy-command-output placed on the clipboard, or an indication of a no-op) — so jump-to-prompt, designated-block scroll, and copy-command-output are deterministically assertable without inspecting the real clipboard or scroll chrome. The state dump SHALL also expose the **last block-menu action** for the focused pane — its kind (copy-command-text or reveal-working-directory) and its resolved value (the copied command text, or the resolved working directory) — and on the test path the reveal action SHALL record its resolved directory without opening it externally, so the sidebar's per-block copy-command and reveal actions are deterministically assertable without a real clipboard or launching Finder. The state dump SHALL also expose, for the focused pane, a **git-review snapshot** — whether the working directory is a git repository and whether it is remote, the repository-root-relative paths and status categories of the changed files, the active changed-files list **layout** (status-category grouping vs directory tree), the active diff **wrap mode** (wrap vs no-wrap), **DEBUG diff layout-geometry signals for the selected diff — whether its content fills the panel width and whether it overflows the panel horizontally, expressed as derived booleans (never raw pixel coordinates)** — and a summary of the currently selected file's diff (added/removed line counts, binary/truncated flags, and the **intra-line emphasis spans** of the selected diff — counts/ranges only, never text) — read from a **cached** snapshot (the dump path SHALL NOT trigger a git query) and **never** including full diff text, so git-review listing, layout, diff wrap mode, the rendered diff geometry of each mode, diff selection, and intra-line emphasis are deterministically assertable. The state dump SHALL also expose the active **rendering backend** identifier and the most recent **resident-memory sample** (in bytes) for the key window, so the rendering path and the memory sampler are deterministically assertable (the backend field is retained for report-schema stability and identifies the single CoreGraphics rendering path). The state dump SHALL also expose, in DEBUG builds, the **live-instance census** — a count per lifecycle-bearing type (window controller, pane controller, terminal-view wrapper, git-review controller, quick-terminal accessory controller, and terminal session) — so an out-of-process test can observe App-layer object lifetimes (which it cannot reference directly) and assert they return to baseline after churn. The state dump SHALL also expose the **main-menu top-level titles** — the ordered titles of the installed main menu's top-level items, read as **titles, never object identity** (identity is blind to in-place item mutation) — and the **terminal-window count**, counting one per terminal window **including each window in a native tab group** (a tab is a window) and **excluding the quick-terminal accessory panel**, so main-menu integrity and real window creation are deterministically assertable; the dump path SHALL only **observe** the menu, never modify or repair it. The dump hook's periodic writer SHALL remain live while a modal panel is presented (e.g. a close-confirmation alert) — the state and grid dumps continue to update during the modal session — so tests and post-mortem artifacts observe current state rather than a snapshot frozen at the modal's appearance. The hook MUST be gated by `#if DEBUG` and the `-UITestGridDump` launch argument so it never runs in shipping or non-test builds. Accessibility identifiers SHALL be used only to locate the view/window and route input, never to read cell contents.

#### Scenario: Grid dump enables substring assertions on the focused pane

- **WHEN** the app is launched with `-UITestGridDump` in a DEBUG build and text is typed into the focused pane
- **THEN** the typed text appears in the grid-dump file for the focused pane and the test can assert on it deterministically

#### Scenario: The active renderer and a memory sample are observable

- **WHEN** the app is launched with `-UITestGridDump` in a DEBUG build
- **THEN** the state dump reports the active rendering backend (the single CoreGraphics rendering path) and a non-negative resident-memory sample, so the test can assert the rendering path and that the memory sampler is live

#### Scenario: The live-instance census is observable

- **WHEN** the app is launched with `-UITestGridDump` in a DEBUG build
- **THEN** the state dump reports a per-type live-instance count for the lifecycle-bearing types, so a test can read App-layer object lifetimes through the dump

#### Scenario: Per-block anchor usability is observable

- **WHEN** the app is launched with `-UITestGridDump` in a DEBUG build after commands have produced blocks, and the terminal is then resized (invalidating anchors)
- **THEN** the state dump's command-block list reports each block as no longer having a usable jump/copy anchor, so a test can assert the sidebar dims those blocks' scroll/copy-output actions

#### Scenario: A block menu action is observable

- **WHEN** the tests invoke copy-command-text, and separately reveal-working-directory, on a designated block in a `-UITestGridDump` DEBUG build
- **THEN** the state dump's last block-menu action reports the kind and the resolved value (the command text, or the resolved directory), and no Finder window is opened during the test

#### Scenario: Main-menu integrity is observable

- **WHEN** the app is launched with `-UITestGridDump` in a DEBUG build
- **THEN** the state dump reports the main menu's top-level titles, so a test driving menu key equivalents can first assert that xtty's own menus (e.g. Edit, View, Terminal, Window) are installed — and a run where a framework-synthesized default menu replaced them is named precisely instead of failing as an unexplained dropped keystroke

#### Scenario: The window count is observable

- **WHEN** the tests open a new window (or tab) in a `-UITestGridDump` DEBUG build
- **THEN** the state dump's terminal-window count reflects the real number of terminal windows (a native tab counts as a window; the quick-terminal accessory panel never counts), so a window-creation test asserts a window actually appeared rather than passing vacuously

#### Scenario: Dumps stay live while a modal panel is presented

- **WHEN** a modal panel (e.g. a close-confirmation alert) is presented while the app runs with `-UITestGridDump` in a DEBUG build
- **THEN** the state and grid dumps continue to update during the modal session, so a test or post-mortem artifact observes the current state rather than a snapshot frozen at the modal's appearance

### Requirement: Git-review end-to-end coverage
The harness SHALL cover the git-review panel end-to-end by driving a real shell with shell-integration injection active inside a temporary git repository and asserting, via the DEBUG state dump, that the panel lists the repository's changed files with their status categories for a known repository state, that selecting a changed file yields the expected diff summary (including, for a partial single-line change, **non-empty intra-line emphasis spans**), that the open-in-editor action routes through the editor opener — asserted via the existing **resolved link-open action** field, not a real editor — that the changed-files list **layout** reported by the state dump reflects the configured default (flat vs directory tree), that the diff **wrap mode** reported by the state dump reflects the configured default and flips when the **real in-panel wrap control** is driven, and that the DEBUG diff **layout-geometry** signals confirm each mode's rendered layout (wrap fills the panel width without horizontal overflow; no-wrap overflows horizontally for a line longer than the panel). Coverage SHALL include the **non-repository** and **remote/unavailable** empty-state cases. The real editor SHALL NOT be required for assertions.

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

#### Scenario: The configured diff wrap mode is reported and the real toggle flips it

- **WHEN** the tests launch with the git-review default wrap mode configured to `nowrap`, show a selected diff in a `-UITestGridDump` DEBUG build, and then drive the **real in-panel wrap control** (its accessibility element, not a debug-only shortcut)
- **THEN** the state dump's git-review snapshot first reports no-wrap (the configured default) and, after the toggle, reports wrap — so the test asserts the configured default and the real control→store routing without measuring pixels

#### Scenario: Each wrap mode's rendered layout is observable

- **WHEN** a selected diff containing a line longer than the panel is shown in a `-UITestGridDump` DEBUG build, in wrap mode and then in no-wrap mode
- **THEN** the state dump's DEBUG layout-geometry signals report, in wrap mode, that the diff fills the panel width and does not overflow horizontally, and in no-wrap mode that it overflows horizontally — so the test asserts each mode's actual rendered layout (catching a width-collapse regression) without measuring pixels

#### Scenario: Empty states are observable

- **WHEN** the focused pane's directory is not a repository, or is remote/unavailable
- **THEN** the state dump's git-review snapshot reports the non-repository / remote flag so the test can assert the empty state
