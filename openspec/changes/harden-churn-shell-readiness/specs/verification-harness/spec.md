# verification-harness — delta for harden-churn-shell-readiness

## MODIFIED Requirements

### Requirement: Deterministic content assertion channel

Because SwiftTerm's terminal view exposes no per-cell text to accessibility, the harness SHALL assert terminal content via a DEBUG-only hook that writes the **focused pane's** headless engine grid to a temp file, plus `XCTAttachment` screenshots for human/vision review. When multiple panes, tabs, or windows exist, the hook SHALL additionally emit a DEBUG state dump describing the multiplexing inventory — at minimum the pane count, the focused pane, the tab count, and (for the focused pane) the name of the profile it was launched with and its working directory — so multiplexing and profile behaviors are deterministically assertable. The state dump SHALL also expose, for the focused pane, the **live working directory** (from OSC 7), whether the pane is on the **alternate screen**, the captured **command-block list** (each with its command text, exit code, state, and whether it currently has a usable jump/copy anchor), the derived **session activity state** (idle/running/succeeded/failed/fullScreen), and the **running command** text when one is in flight — so semantic-capture and session-progress behavior are deterministically assertable. The state dump SHALL also expose the **last resolved link-open action** for the focused pane — the target kind (URL or file), the working-directory-resolved path, the line/column when present, and whether the action was opened, blocked by the scheme guard, or a no-op — so file-link routing and working-directory resolution are deterministically assertable without launching a real editor. The state dump SHALL also expose the **last spatial-block operation** for the focused pane — the **last jump target row** (the display row a jump-to-prompt or a designated-block scroll resolved to, or an indication that it was a no-op) and the **last copied output** text (what copy-command-output placed on the clipboard, or an indication of a no-op) — so jump-to-prompt, designated-block scroll, and copy-command-output are deterministically assertable without inspecting the real clipboard or scroll chrome. The state dump SHALL also expose the **last block-menu action** for the focused pane — its kind (copy-command-text or reveal-working-directory) and its resolved value (the copied command text, or the resolved working directory) — and on the test path the reveal action SHALL record its resolved directory without opening it externally, so the sidebar's per-block copy-command and reveal actions are deterministically assertable without a real clipboard or launching Finder. The state dump SHALL also expose, for the focused pane, a **git-review snapshot** — whether the working directory is a git repository and whether it is remote, the repository-root-relative paths and status categories of the changed files, the active changed-files list **layout** (status-category grouping vs directory tree), and a summary of the currently selected file's diff (added/removed line counts, binary/truncated flags, and the **intra-line emphasis spans** of the selected diff — counts/ranges only, never text) — read from a **cached** snapshot (the dump path SHALL NOT trigger a git query) and **never** including full diff text, so git-review listing, layout, diff selection, and intra-line emphasis are deterministically assertable. The state dump SHALL also expose the active **rendering backend** (CoreGraphics or Metal) and the most recent **resident-memory sample** (in bytes) for the key window, so the renderer selection and the memory sampler are deterministically assertable. The state dump SHALL also expose, in DEBUG builds, the **live-instance census** — a count per lifecycle-bearing type (window controller, pane controller, terminal-view wrapper, git-review controller, quick-terminal accessory controller, and terminal session) — so an out-of-process test can observe App-layer object lifetimes (which it cannot reference directly) and assert they return to baseline after churn. The dump hook's periodic writer SHALL remain live while a modal panel is presented (e.g. a close-confirmation alert) — the state and grid dumps continue to update during the modal session — so tests and post-mortem artifacts observe current state rather than a snapshot frozen at the modal's appearance. The hook MUST be gated by `#if DEBUG` and the `-UITestGridDump` launch argument so it never runs in shipping or non-test builds. Accessibility identifiers SHALL be used only to locate the view/window and route input, never to read cell contents.

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

#### Scenario: Dumps stay live while a modal panel is presented

- **WHEN** a modal panel (e.g. a close-confirmation alert) is presented while the app runs with `-UITestGridDump` in a DEBUG build
- **THEN** the state and grid dumps continue to update during the modal session, so a test or post-mortem artifact observes the current state rather than a snapshot frozen at the modal's appearance

### Requirement: Lifecycle-census end-to-end coverage

The harness SHALL cover the lifecycle census end-to-end by driving the real app through lifecycle churn — creating and destroying panes, splits, tabs, and windows and returning to the starting layout — and asserting, via the DEBUG state dump, that every lifecycle type's live-instance count returns to its pre-churn baseline. Because the controllers and views are out-of-process and custom-drawn (no per-cell accessibility text and no test-process reference to the objects), the assertion SHALL be made against the state-dump census, not the accessibility tree or a weak reference. The assertion SHALL tolerate teardown propagation by waiting for the counts to settle to baseline (with a timeout) rather than reading once. The churn SHALL close only panes/tabs whose fresh shell has demonstrably completed startup — established by observing the shell execute a command — while the close-confirmation setting remains at its default, so the churn exercises the same close path a default-configured user gets without racing shell startup. Each churn step's precondition SHALL be asserted: when a step does not materialize within its timeout, the test SHALL fail at that step with diagnostic artifacts and SHALL NOT drive further churn input (in particular, it SHALL NOT send a close whose readiness precondition was not established).

#### Scenario: Live counts return to baseline after churn

- **WHEN** the tests record the baseline census, then open and close several panes/splits/tabs/windows back to the starting layout in a `-UITestGridDump` DEBUG build
- **THEN** the state dump's live-instance counts settle back to the recorded baseline, so the test can assert no lifecycle object leaked

#### Scenario: Churn closes only shell-ready panes

- **WHEN** the churn creates a fresh pane or tab whose shell is still running its startup files
- **THEN** the churn establishes that the shell has executed a command before sending the close, so the default close-confirmation setting does not race shell startup and the close proceeds without a confirmation alert

#### Scenario: A stuck churn step fails at its own iteration

- **WHEN** a churn step's precondition (pane/tab appeared, shell ready, pane/tab closed) does not materialize within its timeout
- **THEN** the test fails at that step with diagnostic artifacts attached and drives no further churn input, rather than cascading timeouts and surfacing the failure at a later step
