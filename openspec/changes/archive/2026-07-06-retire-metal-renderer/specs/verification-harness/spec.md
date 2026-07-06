# verification-harness — delta for retire-metal-renderer

## MODIFIED Requirements

### Requirement: Deterministic content assertion channel

Because SwiftTerm's terminal view exposes no per-cell text to accessibility, the harness SHALL assert terminal content via a DEBUG-only hook that writes the **focused pane's** headless engine grid to a temp file, plus `XCTAttachment` screenshots for human/vision review. When multiple panes, tabs, or windows exist, the hook SHALL additionally emit a DEBUG state dump describing the multiplexing inventory — at minimum the pane count, the focused pane, the tab count, and (for the focused pane) the name of the profile it was launched with and its working directory — so multiplexing and profile behaviors are deterministically assertable. The state dump SHALL also expose, for the focused pane, the **live working directory** (from OSC 7), whether the pane is on the **alternate screen**, the captured **command-block list** (each with its command text, exit code, state, and whether it currently has a usable jump/copy anchor), the derived **session activity state** (idle/running/succeeded/failed/fullScreen), and the **running command** text when one is in flight — so semantic-capture and session-progress behavior are deterministically assertable. The state dump SHALL also expose the **last resolved link-open action** for the focused pane — the target kind (URL or file), the working-directory-resolved path, the line/column when present, and whether the action was opened, blocked by the scheme guard, or a no-op — so file-link routing and working-directory resolution are deterministically assertable without launching a real editor. The state dump SHALL also expose the **last spatial-block operation** for the focused pane — the **last jump target row** (the display row a jump-to-prompt or a designated-block scroll resolved to, or an indication that it was a no-op) and the **last copied output** text (what copy-command-output placed on the clipboard, or an indication of a no-op) — so jump-to-prompt, designated-block scroll, and copy-command-output are deterministically assertable without inspecting the real clipboard or scroll chrome. The state dump SHALL also expose the **last block-menu action** for the focused pane — its kind (copy-command-text or reveal-working-directory) and its resolved value (the copied command text, or the resolved working directory) — and on the test path the reveal action SHALL record its resolved directory without opening it externally, so the sidebar's per-block copy-command and reveal actions are deterministically assertable without a real clipboard or launching Finder. The state dump SHALL also expose, for the focused pane, a **git-review snapshot** — whether the working directory is a git repository and whether it is remote, the repository-root-relative paths and status categories of the changed files, the active changed-files list **layout** (status-category grouping vs directory tree), and a summary of the currently selected file's diff (added/removed line counts, binary/truncated flags, and the **intra-line emphasis spans** of the selected diff — counts/ranges only, never text) — read from a **cached** snapshot (the dump path SHALL NOT trigger a git query) and **never** including full diff text, so git-review listing, layout, diff selection, and intra-line emphasis are deterministically assertable. The state dump SHALL also expose the active **rendering backend** identifier and the most recent **resident-memory sample** (in bytes) for the key window, so the rendering path and the memory sampler are deterministically assertable (the backend field is retained for report-schema stability and identifies the single CoreGraphics rendering path). The state dump SHALL also expose, in DEBUG builds, the **live-instance census** — a count per lifecycle-bearing type (window controller, pane controller, terminal-view wrapper, git-review controller, quick-terminal accessory controller, and terminal session) — so an out-of-process test can observe App-layer object lifetimes (which it cannot reference directly) and assert they return to baseline after churn. The state dump SHALL also expose the **main-menu top-level titles** — the ordered titles of the installed main menu's top-level items, read as **titles, never object identity** (identity is blind to in-place item mutation) — and the **terminal-window count**, counting one per terminal window **including each window in a native tab group** (a tab is a window) and **excluding the quick-terminal accessory panel**, so main-menu integrity and real window creation are deterministically assertable; the dump path SHALL only **observe** the menu, never modify or repair it. The hook MUST be gated by `#if DEBUG` and the `-UITestGridDump` launch argument so it never runs in shipping or non-test builds. Accessibility identifiers SHALL be used only to locate the view/window and route input, never to read cell contents.

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

### Requirement: Performance-harness end-to-end coverage

The harness SHALL cover the performance harness end-to-end by asserting, via the DEBUG state dump, that the reported **rendering backend** identifies the CoreGraphics rendering path and that the **memory sampler** reports a positive resident-memory sample. It SHALL also assert that a **benchmark run** produces a results report containing the active renderer, the per-scenario memory samples, the capture frame rate, an environment description, the **timebase-calibration outcome**, and — where the latency probe ran with capture available and calibration passing — the latency distribution statistics (and an explicit unavailable-or-untrustworthy marker otherwise). The real screen-capture permission and a hardware display SHALL NOT be required to assert the rendering-backend and memory-sample behaviors (those are read from the state dump); the latency probe's pixel-capture path MAY be exercised separately where the capture permission is available.

#### Scenario: The rendering backend is reflected in the state dump

- **WHEN** the tests launch the app in a `-UITestGridDump` DEBUG build
- **THEN** the state dump reports the CoreGraphics rendering path, so the test can assert the rendering-backend field is live and correct

#### Scenario: The memory sampler reports a positive sample

- **WHEN** the tests launch the app in a `-UITestGridDump` DEBUG build
- **THEN** the state dump reports a positive resident-memory sample for the key window

#### Scenario: A benchmark run produces a results report

- **WHEN** the benchmark mode is run
- **THEN** a machine-readable results report is written containing the active renderer, the capture frame rate, the per-scenario memory samples, an environment description, the timebase-calibration outcome, and the latency distribution statistics (or an explicit unavailable-or-untrustworthy marker when the capture path could not run or calibration failed)
