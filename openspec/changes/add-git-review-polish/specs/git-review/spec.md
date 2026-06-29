## ADDED Requirements

### Requirement: Intra-line diff emphasis

Within a changed line of the read-only unified diff, the panel SHALL emphasize the specific changed portions of the line (distinct from the whole-line added/removed styling), so a reviewer sees *what* changed on the line, not merely that it changed. This emphasis SHALL be computed by a **view-free, unit-testable** component in `XttyCore` that maps a changed line-pair to the changed spans within each line, independent of any view type. The computation SHALL be **bounded and gated**: it SHALL run only on a small, balanced block of changed lines and short lines (so cost stays trivial), and SHALL fall back to plain whole-line styling — never an error and never unbounded work — whenever the gate is not met (an unbalanced or large changed block, an overly long line, or a near-total rewrite of the line). The leading add/remove diff marker on a line SHALL NOT itself be emphasized. Emphasis is presentation only; it SHALL NOT alter the diff's classified-line content or the read-only nature of the panel.

#### Scenario: A changed substring is emphasized within the line

- **WHEN** a tracked file has a line whose content changed only in part (e.g. one identifier or argument), and that file's diff is shown in the panel
- **THEN** the changed span(s) within the line are emphasized distinctly from the unchanged remainder of the same line

#### Scenario: Multiple separate changes on a line are each emphasized

- **WHEN** a line changed in two separate places with an unchanged portion between them, and that file's diff is shown in the panel
- **THEN** each changed portion is emphasized and the unchanged portion between them is not

#### Scenario: Emphasis computation is view-free and unit-testable

- **WHEN** the test suite runs
- **THEN** the intra-line emphasis computation is exercised by unit tests that do not launch the app or create a terminal view

#### Scenario: Large, unbalanced, or rewritten changes fall back to whole-line styling

- **WHEN** a changed block is too large, its lines too long, the changed lines do not pair up one-to-one, or the line is effectively rewritten (most of it changed)
- **THEN** the diff is shown with plain whole-line added/removed styling and no intra-line emphasis, with no error and no unbounded work

## MODIFIED Requirements

### Requirement: Lean, gated refresh

The panel SHALL keep its data current without continuous polling, and SHALL do no work when it is collapsed or when the focused session is not a local repository. It SHALL refresh after a command completes in the focused session (via shell integration), on a low-frequency periodic backstop while visible (so changes made by a still-running foreground process are reflected before it exits), on focus change, and on an explicit manual refresh. The periodic backstop SHALL additionally be **suppressed while the focused session's foreground command is itself a git invocation**, so a read-only poll does not surface a transient mid-operation repository state; the command-finish, focus-change, and manual refreshes SHALL NOT be suppressed (the command-finish refresh reflects the result the instant the git command completes). Refreshes SHALL be debounced and rate-limited so bursts of activity coalesce into at most one git query per quiet interval, and git queries SHALL run off the main thread and never block the UI.

#### Scenario: Refresh after a command finishes

- **WHEN** a command that changes files completes in the focused session and the panel is visible
- **THEN** the changed-file list updates to reflect the new repository state

#### Scenario: Periodic backstop catches mid-command changes

- **WHEN** a long-running foreground process modifies files without yet exiting and the panel is visible
- **THEN** the panel reflects those changes via the periodic backstop rather than waiting for the process to finish

#### Scenario: The poll pauses during the user's own git command

- **WHEN** the user is running a git command in the focused session and the periodic backstop tick fires while that command is in flight
- **THEN** that poll tick performs no git query, while a command-finish, focus-change, or manual refresh still updates the panel normally

#### Scenario: A git-prefixed but different program does not pause the poll

- **WHEN** the focused session's foreground command merely begins with the letters "git" but is a different program (e.g. `github-cli`), and the periodic backstop tick fires
- **THEN** that poll tick still performs its git query — only an actual git invocation suppresses the poll

#### Scenario: No work when collapsed or remote

- **WHEN** the panel is collapsed, or the focused session's directory is remote/non-repository
- **THEN** no git query is performed for the panel

#### Scenario: Bursts of activity coalesce

- **WHEN** several commands finish in rapid succession
- **THEN** the refreshes are debounced/rate-limited into at most one git query per quiet interval rather than one query per command
