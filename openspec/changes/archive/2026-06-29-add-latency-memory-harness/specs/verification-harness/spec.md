## MODIFIED Requirements

### Requirement: Deterministic content assertion channel

Because SwiftTerm's terminal view exposes no per-cell text to accessibility, the harness SHALL assert terminal content via a DEBUG-only hook that writes the **focused pane's** headless engine grid to a temp file, plus `XCTAttachment` screenshots for human/vision review. When multiple panes, tabs, or windows exist, the hook SHALL additionally emit a DEBUG state dump describing the multiplexing inventory — at minimum the pane count, the focused pane, the tab count, and (for the focused pane) the name of the profile it was launched with and its working directory — so multiplexing and profile behaviors are deterministically assertable. The state dump SHALL also expose, for the focused pane, the **live working directory** (from OSC 7), whether the pane is on the **alternate screen**, the captured **command-block list** (each with its command text, exit code, and state), the derived **session activity state** (idle/running/succeeded/failed/fullScreen), and the **running command** text when one is in flight — so semantic-capture and session-progress behavior are deterministically assertable. The state dump SHALL also expose the **last resolved link-open action** for the focused pane — the target kind (URL or file), the working-directory-resolved path, the line/column when present, and whether the action was opened, blocked by the scheme guard, or a no-op — so file-link routing and working-directory resolution are deterministically assertable without launching a real editor. The state dump SHALL also expose the **last spatial-block operation** for the focused pane — the **last jump target row** (the display row a jump-to-prompt resolved to, or an indication that the jump was a no-op) and the **last copied output** text (what copy-command-output placed on the clipboard, or an indication of a no-op) — so jump-to-prompt and copy-command-output are deterministically assertable without inspecting the real clipboard or scroll chrome. The state dump SHALL also expose, for the focused pane, a **git-review snapshot** — whether the working directory is a git repository and whether it is remote, the repository-root-relative paths and status categories of the changed files, the active changed-files list **layout** (status-category grouping vs directory tree), and a summary of the currently selected file's diff (added/removed line counts, binary/truncated flags, and the **intra-line emphasis spans** of the selected diff — counts/ranges only, never text) — read from a **cached** snapshot (the dump path SHALL NOT trigger a git query) and **never** including full diff text, so git-review listing, layout, diff selection, and intra-line emphasis are deterministically assertable. The state dump SHALL also expose the active **rendering backend** (CoreGraphics or Metal) and the most recent **resident-memory sample** (in bytes) for the key window, so the renderer selection and the memory sampler are deterministically assertable. The hook MUST be gated by `#if DEBUG` and the `-UITestGridDump` launch argument so it never runs in shipping or non-test builds. Accessibility identifiers SHALL be used only to locate the view/window and route input, never to read cell contents.

#### Scenario: Grid dump enables substring assertions on the focused pane

- **WHEN** the app is launched with `-UITestGridDump` in a DEBUG build and text is typed into the focused pane
- **THEN** the typed text appears in the grid-dump file for the focused pane and the test can assert on it deterministically

#### Scenario: The active renderer and a memory sample are observable

- **WHEN** the app is launched with `-UITestGridDump` in a DEBUG build
- **THEN** the state dump reports the active rendering backend (CoreGraphics or Metal) and a non-negative resident-memory sample, so the test can assert the renderer selection and that the memory sampler is live

## ADDED Requirements

### Requirement: Performance-harness end-to-end coverage

The harness SHALL cover the performance harness end-to-end by asserting, via the DEBUG state dump, that the configured/overridden **rendering backend** is applied (the dump reflects CoreGraphics when CoreGraphics is selected and Metal when Metal is selected) and that the **memory sampler** reports a positive resident-memory sample. It SHALL also assert that a **benchmark run** produces a results report containing the active renderer, the per-scenario memory samples, the capture frame rate, an environment description, and the latency distribution statistics where the latency probe is available (and an explicit unavailable marker otherwise). The real screen-capture permission and a hardware display SHALL NOT be required to assert the renderer-applied and memory-sample behaviors (those are read from the state dump); the latency probe's pixel-capture path MAY be exercised separately where the capture permission is available. Because the headless engine grid is renderer-independent and exposes no GPU-render correctness, **Metal pixel-rendering correctness** (truecolor/emoji/CJK without corruption) SHALL be verified **manually** (screenshot/vision, per the P2 spike method), not via the e2e tests, which assert only that the backend selection was applied.

#### Scenario: The selected renderer is reflected in the state dump

- **WHEN** the tests launch with the renderer override set to Metal, and separately to CoreGraphics, in a `-UITestGridDump` DEBUG build
- **THEN** the state dump reports the matching active rendering backend for each launch, so the test can assert the toggle was applied

#### Scenario: The memory sampler reports a positive sample

- **WHEN** the tests launch the app in a `-UITestGridDump` DEBUG build
- **THEN** the state dump reports a positive resident-memory sample for the key window

#### Scenario: A benchmark run produces a results report

- **WHEN** the benchmark mode is run for a selected renderer
- **THEN** a machine-readable results report is written containing the active renderer, the capture frame rate, the per-scenario memory samples, an environment description, and the latency distribution statistics (or an explicit unavailable marker when the capture path could not run)
