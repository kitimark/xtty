## ADDED Requirements

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
