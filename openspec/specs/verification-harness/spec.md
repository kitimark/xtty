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

Because SwiftTerm's terminal view exposes no per-cell text to accessibility, the harness SHALL assert terminal content via a DEBUG-only hook that writes the **focused pane's** headless engine grid to a temp file, plus `XCTAttachment` screenshots for human/vision review. When multiple panes, tabs, or windows exist, the hook SHALL additionally emit a DEBUG state dump describing the multiplexing inventory — at minimum the pane count, the focused pane, the tab count, and (for the focused pane) the name of the profile it was launched with and its working directory — so multiplexing and profile behaviors are deterministically assertable. The state dump SHALL also expose, for the focused pane, the **live working directory** (from OSC 7), whether the pane is on the **alternate screen**, the captured **command-block list** (each with its command text, exit code, state, and whether it currently has a usable jump/copy anchor), the derived **session activity state** (idle/running/succeeded/failed/fullScreen), and the **running command** text when one is in flight — so semantic-capture and session-progress behavior are deterministically assertable. The state dump SHALL also expose the **last resolved link-open action** for the focused pane — the target kind (URL or file), the working-directory-resolved path, the line/column when present, and whether the action was opened, blocked by the scheme guard, or a no-op — so file-link routing and working-directory resolution are deterministically assertable without launching a real editor. The state dump SHALL also expose the **last spatial-block operation** for the focused pane — the **last jump target row** (the display row a jump-to-prompt or a designated-block scroll resolved to, or an indication that it was a no-op) and the **last copied output** text (what copy-command-output placed on the clipboard, or an indication of a no-op) — so jump-to-prompt, designated-block scroll, and copy-command-output are deterministically assertable without inspecting the real clipboard or scroll chrome. The state dump SHALL also expose the **last block-menu action** for the focused pane — its kind (copy-command-text or reveal-working-directory) and its resolved value (the copied command text, or the resolved working directory) — and on the test path the reveal action SHALL record its resolved directory without opening it externally, so the sidebar's per-block copy-command and reveal actions are deterministically assertable without a real clipboard or launching Finder. The state dump SHALL also expose, for the focused pane, a **git-review snapshot** — whether the working directory is a git repository and whether it is remote, the repository-root-relative paths and status categories of the changed files, the active changed-files list **layout** (status-category grouping vs directory tree), and a summary of the currently selected file's diff (added/removed line counts, binary/truncated flags, and the **intra-line emphasis spans** of the selected diff — counts/ranges only, never text) — read from a **cached** snapshot (the dump path SHALL NOT trigger a git query) and **never** including full diff text, so git-review listing, layout, diff selection, and intra-line emphasis are deterministically assertable. The state dump SHALL also expose the active **rendering backend** identifier and the most recent **resident-memory sample** (in bytes) for the key window, so the rendering path and the memory sampler are deterministically assertable (the backend field is retained for report-schema stability and identifies the single CoreGraphics rendering path). The state dump SHALL also expose, in DEBUG builds, the **live-instance census** — a count per lifecycle-bearing type (window controller, pane controller, terminal-view wrapper, git-review controller, quick-terminal accessory controller, and terminal session) — so an out-of-process test can observe App-layer object lifetimes (which it cannot reference directly) and assert they return to baseline after churn. The state dump SHALL also expose the **main-menu top-level titles** — the ordered titles of the installed main menu's top-level items, read as **titles, never object identity** (identity is blind to in-place item mutation) — and the **terminal-window count**, counting one per terminal window **including each window in a native tab group** (a tab is a window) and **excluding the quick-terminal accessory panel**, so main-menu integrity and real window creation are deterministically assertable; the dump path SHALL only **observe** the menu, never modify or repair it. The dump hook's periodic writer SHALL remain live while a modal panel is presented (e.g. a close-confirmation alert) — the state and grid dumps continue to update during the modal session — so tests and post-mortem artifacts observe current state rather than a snapshot frozen at the modal's appearance. The hook MUST be gated by `#if DEBUG` and the `-UITestGridDump` launch argument so it never runs in shipping or non-test builds. Accessibility identifiers SHALL be used only to locate the view/window and route input, never to read cell contents.

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

The deterministic content assertion SHALL confirm that typed content reached the focused pane's grid **even when the terminal soft-wraps that content across physical rows**. Because the grid dump emits the focused pane's physical rows, a content assertion that an out-of-process test makes about typed text SHALL match that text regardless of soft-wrap row boundaries, while a string that genuinely never reached the grid SHALL still fail the assertion. The focus-typing-on-activate coverage, the find-bar focus-restore coverage, **and the multi-line-paste content coverage** SHALL use this wrap-robust assertion so that each passes when typed or pasted input reaches the focused pane and the terminal wraps it (e.g. behind a long shell prompt), and fails only when the input does not arrive. A dedicated regression guard SHALL exercise this behavior deterministically — independent of the ambient shell prompt width — by typing a marker that is guaranteed to soft-wrap and confirming that the wrap-robust assertion matches it while a strict (wrap-intolerant) match does not.

#### Scenario: A soft-wrapped typed marker is still asserted present

- **WHEN** the app is launched with `-UITestGridDump` in a DEBUG build, the focused pane shows a long prompt, and a unique marker is typed such that the terminal soft-wraps it across two physical rows in the grid dump
- **THEN** the focus-typing-on-activate assertion confirms the marker is present in the focused pane's grid

#### Scenario: A genuinely absent marker still fails the assertion

- **WHEN** the wrap-robust content assertion is used and the asserted string never reached the focused pane's grid
- **THEN** the assertion fails (the wrap tolerance does not fabricate a match)

#### Scenario: Find-bar focus-restore tolerates a wrapped marker

- **WHEN** the find bar is opened and dismissed, focus returns to the terminal, and a unique marker typed afterward is soft-wrapped across two physical rows in the grid dump (e.g. behind a long shell prompt)
- **THEN** the find-bar focus-restore assertion confirms the marker reached the focused pane's grid (focus restoration is verified independent of prompt width)

#### Scenario: A soft-wrapped pasted line is still asserted present

- **WHEN** a multi-line clipboard payload is pasted (bracketed paste, staged and not executed) into the focused pane and a pasted line soft-wraps across two physical rows in the grid dump (e.g. behind a long shell prompt)
- **THEN** the multi-line-paste content assertion confirms the pasted line reached the focused pane's grid (paste insertion is verified independent of prompt width), while the separate not-executed check is unaffected

#### Scenario: The deterministic soft-wrap guard proves the wrap-robust assertion is required and works

- **WHEN** a guard test types a marker constructed to be wider than the focused pane, such that the grid dump splits it across at least two physical rows
- **THEN** the guard confirms the marker genuinely spanned multiple physical rows, the wrap-robust assertion matches it, and a strict (wrap-intolerant) match of the same marker does not

### Requirement: Bracketed-paste mode is observable

The DEBUG state dump SHALL expose, for the focused pane, the terminal's current **bracketed-paste mode** — whether the shell has enabled bracketed paste (`\e[?2004h`) — so a test can read the **true capability predicate** for whether a multi-line paste will be *staged* versus *forwarded for execution*, rather than inferring it from the shell's binary or version. Like every other dump field, it MUST be gated by `#if DEBUG` and the `-UITestGridDump` launch argument, and the dump path SHALL only observe the terminal's mode, never change it.

#### Scenario: The focused pane's bracketed-paste mode is reported

- **WHEN** the app is launched with `-UITestGridDump` in a DEBUG build and the focused pane's shell has reached its first interactive prompt
- **THEN** the state dump reports the focused pane's bracketed-paste mode — true when the shell has enabled bracketed paste (e.g. zsh, or bash ≥ 4.4), false when it has not (e.g. macOS bash 3.2) — so a test can decide which per-shell paste behavior to assert in this environment

### Requirement: Shell-parameterized capability assertion

A shell-dependent XCUITest — one whose result depends on a capability the login shell might lack, namely OSC 133/7 shell-integration capture or bracketed paste — SHALL assert the behavior expected for the terminal's **observed** capability state, rather than passing vacuously, failing on capability absence, or skipping where a meaningful assertion exists. For the capability-**present** state it SHALL exercise its real assertion; for the capability-**absent** state it SHALL assert the correct alternative behavior where one is observable (e.g. a multi-line paste forwarded line-by-line, or the absence of command boundaries), and SHALL record an explicit **skip** — never a silent no-op, never a spurious failure — only where the capability-absent state admits no meaningful assertion. The predicate SHALL be the terminal's **observed** capability (bracketed-paste mode from the DEBUG state dump; the capture-active signal), evaluated **after** the shell has reached readiness, and SHALL NOT be the shell's identity (binary or version). Because each test asserts on every shell, no test-plan partition is required to keep the suite honest.

#### Scenario: Multi-line paste is asserted staged when bracketed paste is enabled

- **WHEN** a multi-line clipboard payload is pasted into a focused pane whose observed bracketed-paste mode is enabled (e.g. zsh) in a `-UITestGridDump` DEBUG build
- **THEN** the test asserts both pasted lines are present in the grid and that nothing was executed (no `command not found`) — the staged-not-executed guarantee

#### Scenario: Multi-line paste is asserted forwarded line-by-line when bracketed paste is disabled

- **WHEN** the same multi-line payload (a newline-separated pair with no trailing newline) is pasted into a focused pane whose observed bracketed-paste mode is disabled (e.g. macOS bash 3.2)
- **THEN** the test asserts the newline-terminated first line was executed (its `command not found` appears) while the unterminated tail line remains staged — xtty's faithful forwarding of the paste, the correct behavior for that shell — rather than skipping or failing

#### Scenario: The capability-absent state asserts a crisp negative where one exists

- **WHEN** a semantic-capture-dependent test runs on a shell whose observed capture is not live (e.g. bash without OSC injection)
- **THEN** the test asserts the meaningful negative for that state (e.g. no command boundaries are recorded / the semantic sidebar stays empty) rather than passing vacuously, so a regression that unexpectedly activated or broke capture would be caught

#### Scenario: A skip is recorded only as a last resort

- **WHEN** a shell-dependent test runs in the capability-absent state and that state admits no meaningful assertion
- **THEN** the test records an explicit skip (not a pass, not a failure), so the run reports it as skipped rather than vacuously green

### Requirement: Mouse-wheel routing is observable

The DEBUG state dump SHALL expose, for the focused pane, the **last mouse-wheel routing action** — the **branch** taken (a wheel mouse-report to the program, a cursor-key send to the program, or a local-scrollback move) together with the routed detail: for the report branch, the emitted **wheel button** (up/down) and the number of reports, and for the cursor-key branch, the emitted **key form** (application-cursor vs normal) and direction and count; a local-scrollback move is recorded as such. The dump SHALL additionally record, for the routed event, whether it was an **inertial-coast (momentum) frame** (versus a finger-driven frame) and whether it carried **precise (trackpad) deltas** (versus discrete wheel notches), so the momentum-honoring behavior is observable to both the synthetic-injection coverage and a physical-trackpad verify. This lets a test assert which branch a wheel gesture took and what was sent to the program, on xtty's custom-drawn view that exposes no per-cell content or input stream to accessibility. Like every other dump field, it MUST be gated by `#if DEBUG` and the `-UITestGridDump` launch argument, and the dump path SHALL only **observe** the last routing action, never synthesize or replay a gesture.

#### Scenario: The focused pane's last wheel-routing action is reported

- **WHEN** a wheel gesture has been routed in a focused pane in a `-UITestGridDump` DEBUG build
- **THEN** the state dump reports the branch taken (program wheel-report / program cursor-key / local scrollback) and, for a program-directed branch, the emitted button-or-key form, direction, and count — so a test can assert the routing without a real mouse-tracking program parsing the bytes

#### Scenario: The routed event's momentum and precise nature is reported

- **WHEN** a wheel gesture has been routed in a focused pane in a `-UITestGridDump` DEBUG build
- **THEN** the state dump additionally reports whether the routed event was an inertial-coast (momentum) frame and whether it carried precise (trackpad) deltas — so the momentum-honoring behavior is assertable by the synthetic-injection coverage and observable on a physical-trackpad verify

### Requirement: Mouse-wheel routing end-to-end coverage

The harness SHALL cover mouse-wheel routing end-to-end by driving a real wheel gesture over a focused pane in each routing state and asserting, via the DEBUG state dump's last-wheel-routing action, that the correct branch was taken. Coverage SHALL include: an **alternate-screen program with button-event mouse reporting active** (a wheel notch is reported to the program as a wheel button, not swallowed); an **alternate-screen program without mouse reporting** (a wheel notch is delivered as a cursor Up/Down key); a **primary-screen pane with no mouse reporting** (the wheel moves local scrollback); and the **Shift-bypass** (Shift+wheel over a mouse-reporting program moves local scrollback instead of reporting). A real mouse-tracking program's own scroll state SHALL NOT be **required** for these core routing assertions — the routed action is asserted from the state dump, so a program with its own mouse-tracking escape sequences never needs to be installed or its rendering parsed. Coverage additionally SHALL include one integration-level scenario, driven by a **real, unmodified, off-the-shelf mouse-tracking program** (rather than terminal state armed via `printf`), asserting that the program's own visible content genuinely advances in response to the routed reports — this is optional extra assurance beyond the core per-branch routing assertions, not a replacement for them. Because the **real wheel gestures** the harness drives through the automation channel carry **no inertial-coast (momentum) frames**, the harness SHALL assert that such a gesture is recorded as a **non-momentum** routed event (a crisp negative proving the momentum field is wired on the real-gesture path); the **momentum routing logic** is covered separately by the synthetic-injection requirement, and only the real-OS coast **delivery, rate, and consume-side responsiveness** remain a manual physical-trackpad verify (out of automated harness scope).

#### Scenario: Wheel over a mouse-tracking alt-screen pane reports to the program

- **WHEN** the tests focus a pane whose program has button-event mouse reporting active on the alternate screen and scroll the wheel down over it
- **THEN** the state dump's last-wheel-routing action is a program wheel-report with the down button, rather than a local-scrollback move

#### Scenario: Wheel over an alt-screen pane without mouse reporting sends cursor keys

- **WHEN** the tests focus a pane on the alternate screen with no mouse reporting active and scroll the wheel
- **THEN** the state dump's last-wheel-routing action is a program cursor-key send (Up on scroll-up, Down on scroll-down), in the DECCKM-appropriate form

#### Scenario: Shift+wheel over a mouse-tracking pane moves local scrollback

- **WHEN** the tests scroll the wheel while holding Shift over a focused pane whose program has mouse reporting active
- **THEN** the state dump's last-wheel-routing action is a local-scrollback move, not a program wheel-report

#### Scenario: A real synthetic gesture is recorded as a non-momentum event

- **WHEN** the tests drive a real wheel gesture through the automation channel over a focused pane in a `-UITestGridDump` DEBUG build
- **THEN** the state dump's last-wheel-routing action records the event as a non-momentum (finger-driven) frame, since automation-channel gestures carry no inertial coast — proving the momentum field is wired on the real-gesture path (the momentum-true path is covered by synthetic injection)

#### Scenario: A real mouse-tracking program's own content advances

- **WHEN** the tests focus a pane running a real, unmodified program that requests its own button-event mouse tracking (not terminal state armed via `printf`) and scroll the wheel over it
- **THEN** the state dump's last-wheel-routing action is a program wheel-report, and the program's own visible content genuinely changes in response — proving a real off-the-shelf program correctly negotiates mouse tracking and acts on the routed reports, not only that xtty's routing decision was recorded

### Requirement: Scroll-region shift redraw-correctness coverage

The harness SHALL cover, end-to-end against the real running app, that a scroll-region shift within the alternate screen buffer correctly moves every column of the affected rows, not only the first — the defect class this requirement guards against. The test SHALL drive the terminal engine directly with a known escape-sequence sequence (entering the alternate screen, setting a scroll region, writing distinct content into known rows, then scrolling up and back down by the same amount) rather than depending on a specific real full-screen program, because which escape-sequence idiom a given program uses for its own scrolling is a program-internal implementation choice outside this project's control — programs bundled with the test VM image (e.g. `vim`, `less`) do not exercise this scroll-region-shift code path at all regardless of how they are driven, while the program that does (`htop`) is not present in the minimal test VM image. Driving the exact sequence directly is deterministic, needs no additional VM dependency, and targets the defect precisely.

#### Scenario: A scroll-up-then-down reversal over known content preserves every column

- **WHEN** the tests, in a `-UITestGridDump` DEBUG build, drive the terminal into the alternate screen with a scroll region set, write distinct known content into multiple rows within that region, scroll up by N, then scroll down by the same N
- **THEN** the grid dump shows the affected rows fully restored to their original content in every column — not the buggy state where only the first column of each row is restored and the remaining columns retain stale content left over from the scroll-up

### Requirement: Mouse-wheel momentum routing coverage via synthetic injection

Because a real inertial-coast (momentum) wheel event cannot be produced through the XCUITest automation channel (synthesized gestures carry no momentum) and a raw event cannot be posted in the test runner, the harness SHALL cover the **momentum routing logic** through a DEBUG-only **synthetic-wheel-event injection** trigger: the test supplies a wheel-event spec (momentum phase, precise-vs-discrete, vertical delta, modifiers) and the app constructs a faithful wheel event carrying that momentum phase and precise-delta state, then drives it through the **real** wheel-routing path on the focused pane (never a reimplementation of the branch logic) — after which the routed action is asserted from the DEBUG state dump or, for the byte-level scenario below, from the terminal's own visible grid content. This exercises the exact fields the router reads (momentum phase, precise-scrolling state, vertical scrolling delta) without depending on the OS delivering a physical coast. The trigger MUST be gated by `#if DEBUG` and the `-UITestGridDump` launch argument. The real-OS coast **delivery, rate, and consume-side responsiveness** are explicitly **out of scope** for this automated coverage — they remain a manual physical-trackpad verify. Coverage SHALL include: an injected momentum frame **is not dropped** (it routes on the same branch as a finger-driven frame, recorded as a momentum event); a fast precise sequence **does not lose distance** (the emitted whole-cell count tracks the accumulated travel rather than being clamped to a fixed per-event cap); the accumulated sub-cell remainder **resets between gestures** (a fresh gesture does not inherit a stale fraction); and an injected momentum frame's routed mouse-report decision **produces a real byte sequence the child process actually receives** (not only a DEBUG-dump bookkeeping update) — a distinct assertion channel (the terminal's visible grid content, via a real unmodified child program) from the other three scenarios' DEBUG-dump-only assertions.

#### Scenario: An injected momentum frame is routed, not dropped

- **WHEN** the tests inject a synthetic wheel event carrying an inertial-coast (momentum) phase over a focused pane in a `-UITestGridDump` DEBUG build
- **THEN** the state dump's last-wheel-routing action records the event on its branch (program wheel-report / program cursor-key / local scrollback per the pane's state) with the momentum flag set — it is not silently dropped

#### Scenario: An injected fast precise gesture does not lose scroll distance

- **WHEN** the tests inject precise (trackpad) wheel input whose accumulated travel exceeds several whole cells
- **THEN** the routed emission count tracks the whole cells traversed (carrying the sub-cell remainder forward), rather than being clamped to a fixed per-event cap that discards the overflow

#### Scenario: The accumulated remainder resets between gestures

- **WHEN** the tests inject one precise gesture that leaves a sub-cell remainder, then begin a new user-driven gesture
- **THEN** the new gesture does not emit a phantom extra cell carried over from the previous gesture's leftover remainder

#### Scenario: An injected momentum frame's mouse report reaches the child as real bytes

- **WHEN** the tests arm SGR-encoded button-event mouse tracking with a child process that echoes its raw stdin as visible text (so an incoming escape sequence is observable instead of being silently consumed by xtty's own terminal engine), then inject a synthetic wheel event carrying an inertial-coast (momentum) phase over the focused pane
- **THEN** the terminal's visible content shows the real wheel-report escape sequence the child actually received — proving the routed decision produced correct bytes on the wire, not only a DEBUG-dump bookkeeping update

