## ADDED Requirements

### Requirement: Bracketed-paste mode is observable

The DEBUG state dump SHALL expose, for the focused pane, the terminal's current **bracketed-paste mode** — whether the shell has enabled bracketed paste (`\e[?2004h`) — so a test can read the **true capability predicate** for whether a multi-line paste will be *staged* versus *executed*, rather than inferring it from the shell's binary or version. Like every other dump field, it MUST be gated by `#if DEBUG` and the `-UITestGridDump` launch argument, and the dump path SHALL only observe the terminal's mode, never change it.

#### Scenario: The focused pane's bracketed-paste mode is reported

- **WHEN** the app is launched with `-UITestGridDump` in a DEBUG build and the focused pane's shell has reached its first interactive prompt
- **THEN** the state dump reports the focused pane's bracketed-paste mode — true when the shell has enabled bracketed paste (e.g. zsh, or bash ≥ 4.4), false when it has not (e.g. macOS bash 3.2) — so a test can decide whether the multi-line-paste guarantee is exercisable in this environment

### Requirement: Shell-capability-gated test partitioning

The XCUITest suite SHALL be organized so that **shell-dependent** behaviors — those requiring a capability the login shell may lack, namely OSC 133/7 shell-integration capture or bracketed paste — are **separable** from **shell-agnostic** behaviors that must pass under any shell, such that a runner can select either set. A shell-dependent test SHALL record an explicit **skip** — never a silently-passing no-op and never an assertion failure — when its shell-capability predicate is unmet. The predicate SHALL be the terminal's **observed** capability state (semantic capture live; bracketed-paste mode enabled — from the DEBUG state dump / capture-active signal), evaluated **after** the shell has reached readiness, and SHALL NOT be the shell's identity (binary or version). The two sets' union SHALL be the whole suite (no test is dropped by the partition).

#### Scenario: A shell-dependent test skips when its capability is absent

- **WHEN** a shell-dependent test runs on a shell whose observed capability is absent (bracketed-paste mode reported false, or semantic capture not live) in a `-UITestGridDump` DEBUG build
- **THEN** the test records a skip — not a pass and not a failure — so a run on such a shell reports the shell-dependent set as skipped rather than vacuously green

#### Scenario: A shell-dependent test asserts for real when its capability is present

- **WHEN** the same shell-dependent test runs on a shell whose observed capability is present (bracketed-paste mode enabled, or semantic capture live)
- **THEN** it exercises its real assertion (e.g. a multi-line paste stages both lines without executing; command blocks form) rather than skipping

#### Scenario: The shell-agnostic set is selectable and covers every shell

- **WHEN** a runner selects the shell-agnostic set
- **THEN** it comprises the tests that do not depend on a shell capability (and the shell-dependent set is the complement), so the shell-agnostic set is the one expected to pass on every shell while their union remains the whole suite
