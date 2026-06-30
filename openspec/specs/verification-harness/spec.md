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

### Requirement: Performance-harness end-to-end coverage

The harness SHALL cover the performance harness end-to-end by asserting, via the DEBUG state dump, that the configured/overridden **rendering backend** is applied (the dump reflects CoreGraphics when CoreGraphics is selected and Metal when Metal is selected) and that the **memory sampler** reports a positive resident-memory sample. It SHALL also assert that a **benchmark run** produces a results report containing the active renderer, the per-scenario memory samples, the capture frame rate, an environment description, the **timebase-calibration outcome**, and — where the latency probe ran with capture available and calibration passing — the latency distribution statistics (and an explicit unavailable-or-untrustworthy marker otherwise). The real screen-capture permission and a hardware display SHALL NOT be required to assert the renderer-applied and memory-sample behaviors (those are read from the state dump); the latency probe's pixel-capture path MAY be exercised separately where the capture permission is available. Because the headless engine grid is renderer-independent and exposes no GPU-render correctness, **Metal pixel-rendering correctness** (truecolor/emoji/CJK without corruption) SHALL be verified **manually** (screenshot/vision, per the P2 spike method), not via the e2e tests, which assert only that the backend selection was applied.

#### Scenario: The selected renderer is reflected in the state dump

- **WHEN** the tests launch with the renderer override set to Metal, and separately to CoreGraphics, in a `-UITestGridDump` DEBUG build
- **THEN** the state dump reports the matching active rendering backend for each launch, so the test can assert the toggle was applied

#### Scenario: The memory sampler reports a positive sample

- **WHEN** the tests launch the app in a `-UITestGridDump` DEBUG build
- **THEN** the state dump reports a positive resident-memory sample for the key window

#### Scenario: A benchmark run produces a results report

- **WHEN** the benchmark mode is run for a selected renderer
- **THEN** a machine-readable results report is written containing the active renderer, the capture frame rate, the per-scenario memory samples, an environment description, the timebase-calibration outcome, and the latency distribution statistics (or an explicit unavailable-or-untrustworthy marker when the capture path could not run or calibration failed)

### Requirement: Lifecycle-census end-to-end coverage

The harness SHALL cover the lifecycle census end-to-end by driving the real app through lifecycle churn — creating and destroying panes, splits, tabs, and windows and returning to the starting layout — and asserting, via the DEBUG state dump, that every lifecycle type's live-instance count returns to its pre-churn baseline. Because the controllers and views are out-of-process and custom-drawn (no per-cell accessibility text and no test-process reference to the objects), the assertion SHALL be made against the state-dump census, not the accessibility tree or a weak reference. The assertion SHALL tolerate teardown propagation by waiting for the counts to settle to baseline (with a timeout) rather than reading once.

#### Scenario: Live counts return to baseline after churn

- **WHEN** the tests record the baseline census, then open and close several panes/splits/tabs/windows back to the starting layout in a `-UITestGridDump` DEBUG build
- **THEN** the state dump's live-instance counts settle back to the recorded baseline, so the test can assert no lifecycle object leaked

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

### Requirement: Soft-wrap-robust content assertion

The deterministic content assertion SHALL confirm that typed content reached the focused pane's grid **even when the terminal soft-wraps that content across physical rows**. Because the grid dump emits the focused pane's physical rows, a content assertion that an out-of-process test makes about typed text SHALL match that text regardless of soft-wrap row boundaries, while a string that genuinely never reached the grid SHALL still fail the assertion. The focus-typing-on-activate coverage SHALL use this wrap-robust assertion so that it passes when typed input reaches the focused pane and the terminal wraps it (e.g. behind a long shell prompt), and fails only when the input does not arrive.

#### Scenario: A soft-wrapped typed marker is still asserted present

- **WHEN** the app is launched with `-UITestGridDump` in a DEBUG build, the focused pane shows a long prompt, and a unique marker is typed such that the terminal soft-wraps it across two physical rows in the grid dump
- **THEN** the focus-typing-on-activate assertion confirms the marker is present in the focused pane's grid

#### Scenario: A genuinely absent marker still fails the assertion

- **WHEN** the wrap-robust content assertion is used and the asserted string never reached the focused pane's grid
- **THEN** the assertion fails (the wrap tolerance does not fabricate a match)

