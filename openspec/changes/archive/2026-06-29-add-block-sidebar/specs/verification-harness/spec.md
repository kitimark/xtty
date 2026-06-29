## MODIFIED Requirements

### Requirement: Deterministic content assertion channel

Because SwiftTerm's terminal view exposes no per-cell text to accessibility, the harness SHALL assert terminal content via a DEBUG-only hook that writes the **focused pane's** headless engine grid to a temp file, plus `XCTAttachment` screenshots for human/vision review. When multiple panes, tabs, or windows exist, the hook SHALL additionally emit a DEBUG state dump describing the multiplexing inventory — at minimum the pane count, the focused pane, the tab count, and (for the focused pane) the name of the profile it was launched with and its working directory — so multiplexing and profile behaviors are deterministically assertable. The state dump SHALL also expose, for the focused pane, the **live working directory** (from OSC 7), whether the pane is on the **alternate screen**, the captured **command-block list** (each with its command text, exit code, state, and whether it currently has a usable jump/copy anchor), the derived **session activity state** (idle/running/succeeded/failed/fullScreen), and the **running command** text when one is in flight — so semantic-capture and session-progress behavior are deterministically assertable. The state dump SHALL also expose the **last resolved link-open action** for the focused pane — the target kind (URL or file), the working-directory-resolved path, the line/column when present, and whether the action was opened, blocked by the scheme guard, or a no-op — so file-link routing and working-directory resolution are deterministically assertable without launching a real editor. The state dump SHALL also expose the **last spatial-block operation** for the focused pane — the **last jump target row** (the display row a jump-to-prompt or a designated-block scroll resolved to, or an indication that it was a no-op) and the **last copied output** text (what copy-command-output placed on the clipboard, or an indication of a no-op) — so jump-to-prompt, designated-block scroll, and copy-command-output are deterministically assertable without inspecting the real clipboard or scroll chrome. The state dump SHALL also expose the **last block-menu action** for the focused pane — its kind (copy-command-text or reveal-working-directory) and its resolved value (the copied command text, or the resolved working directory) — and on the test path the reveal action SHALL record its resolved directory without opening it externally, so the sidebar's per-block copy-command and reveal actions are deterministically assertable without a real clipboard or launching Finder. The state dump SHALL also expose, for the focused pane, a **git-review snapshot** — whether the working directory is a git repository and whether it is remote, the repository-root-relative paths and status categories of the changed files, the active changed-files list **layout** (status-category grouping vs directory tree), and a summary of the currently selected file's diff (added/removed line counts, binary/truncated flags, and the **intra-line emphasis spans** of the selected diff — counts/ranges only, never text) — read from a **cached** snapshot (the dump path SHALL NOT trigger a git query) and **never** including full diff text, so git-review listing, layout, diff selection, and intra-line emphasis are deterministically assertable. The state dump SHALL also expose the active **rendering backend** (CoreGraphics or Metal) and the most recent **resident-memory sample** (in bytes) for the key window, so the renderer selection and the memory sampler are deterministically assertable. The state dump SHALL also expose, in DEBUG builds, the **live-instance census** — a count per lifecycle-bearing type (window controller, pane controller, terminal-view wrapper, git-review controller, quick-terminal accessory controller, and terminal session) — so an out-of-process test can observe App-layer object lifetimes (which it cannot reference directly) and assert they return to baseline after churn. The hook MUST be gated by `#if DEBUG` and the `-UITestGridDump` launch argument so it never runs in shipping or non-test builds. Accessibility identifiers SHALL be used only to locate the view/window and route input, never to read cell contents.

#### Scenario: Grid dump enables substring assertions on the focused pane

- **WHEN** the app is launched with `-UITestGridDump` in a DEBUG build and text is typed into the focused pane
- **THEN** the typed text appears in the grid-dump file for the focused pane and the test can assert on it deterministically

#### Scenario: The active renderer and a memory sample are observable

- **WHEN** the app is launched with `-UITestGridDump` in a DEBUG build
- **THEN** the state dump reports the active rendering backend (CoreGraphics or Metal) and a non-negative resident-memory sample, so the test can assert the renderer selection and that the memory sampler is live

#### Scenario: The live-instance census is observable

- **WHEN** the app is launched with `-UITestGridDump` in a DEBUG build
- **THEN** the state dump reports a per-type live-instance count for the lifecycle-bearing types, so a test can read App-layer object lifetimes through the dump

#### Scenario: Per-block anchor usability is observable

- **WHEN** the app is launched with `-UITestGridDump` in a DEBUG build after commands have produced blocks, and the terminal is then resized (invalidating anchors)
- **THEN** the state dump's command-block list reports each block as no longer having a usable jump/copy anchor, so a test can assert the sidebar dims those blocks' scroll/copy-output actions

#### Scenario: A block menu action is observable

- **WHEN** the tests invoke copy-command-text, and separately reveal-working-directory, on a designated block in a `-UITestGridDump` DEBUG build
- **THEN** the state dump's last block-menu action reports the kind and the resolved value (the command text, or the resolved directory), and no Finder window is opened during the test

## ADDED Requirements

### Requirement: Block-sidebar end-to-end coverage

The harness SHALL cover the clickable per-pane block sidebar end-to-end by driving a real shell with shell-integration injection active, then — via a DEBUG-only selection trigger that exercises the real selection path — selecting a captured block and asserting, via the DEBUG state dump, that the focused pane scrolled to that block (the resolved scroll target row) and that copying a designated block's output places that block's output text (excluding the trailing prompt) where the dump can assert it. Coverage SHALL include the **running block** (selecting it resolves to its prompt and copying it captures its output-so-far). Coverage SHALL include **two distinct stale arms**: an **epoch arm** (after a resize invalidates anchors, selecting a block no-ops with no scroll target) and a **trimmed arm** (a block whose row has scrolled out of bounded scrollback while its anchor epoch is still current is reported non-actionable and selecting it no-ops) — the trimmed arm being invisible to a resize-only test. The real clipboard and a real editor SHALL NOT be required for assertions.

#### Scenario: Selecting a block scrolls its pane to it

- **WHEN** the tests run several commands in an injected shell and then select an earlier block via the DEBUG selection trigger in a `-UITestGridDump` DEBUG build
- **THEN** the state dump shows the focused pane and a resolved scroll target row corresponding to that earlier block

#### Scenario: Copying a designated block's output

- **WHEN** the tests select a block with known output and invoke copy-output for that block
- **THEN** the state dump's last copied output contains that block's output and not the following prompt

#### Scenario: Selecting the running block scrolls to it and copies its output so far

- **WHEN** the tests start a long-enough command and, while it runs, select the running block and invoke copy-output via the DEBUG trigger
- **THEN** the state dump shows a resolved scroll target for the running block and a copied output containing its output-so-far

#### Scenario: Selecting an epoch-stale block no-ops

- **WHEN** the tests resize the window (invalidating anchors) and then select a block before any new command runs
- **THEN** the state dump shows each block non-actionable and no scroll target (a graceful no-op) rather than a misaligned scroll

#### Scenario: A trimmed-out block is non-actionable without a resize

- **WHEN** a block's row has scrolled out of the bounded scrollback (its anchor epoch still current) and the tests select it
- **THEN** the state dump reports that block non-actionable and selecting it no-ops (no scroll-to-top, no empty copy), distinct from the resize/epoch case
