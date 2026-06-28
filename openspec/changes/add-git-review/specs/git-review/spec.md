## ADDED Requirements

### Requirement: Git-review panel

The application SHALL present a toggleable **git-review panel**, hosted as SwiftUI chrome beside the AppKit terminal area (it contains no terminal view) and distinct from the session-progress sidebar. For the focused pane's session, when that session's working directory is a **local git repository**, the panel SHALL list the repository's changed files grouped by status category — at minimum **Changes** (tracked modifications and deletions), **Untracked**, and **Conflicts** — each file shown with a status indicator and its path relative to the repository root, and empty groups SHALL be hidden. Selecting a changed file SHALL show that file's changes as a **read-only unified diff** within the panel. The panel SHALL start **collapsed** and SHALL be toggled by a View-menu command with a default keyboard shortcut. When the focused session's directory is not a local repository (no repository, or a remote/ssh working directory) or git is unavailable, the panel SHALL show an explanatory **empty state** rather than file content.

#### Scenario: Changed files are listed and grouped by status

- **WHEN** the focused pane's working directory is a local git repository with tracked modifications, untracked files, and a merge conflict, and the git-review panel is shown
- **THEN** the panel lists those files grouped under Changes, Untracked, and Conflicts, each with a status indicator and a repository-root-relative path, and any empty group is hidden

#### Scenario: Selecting a file shows its read-only diff

- **WHEN** the user selects a changed file in the panel
- **THEN** the panel displays that file's changes as a read-only unified diff (added/removed/context lines)

#### Scenario: Non-repository directory shows an empty state

- **WHEN** the focused pane's working directory is not inside any git repository
- **THEN** the panel shows a "not a git repository" empty state instead of a file list

#### Scenario: Remote or unavailable session shows an empty state

- **WHEN** the focused pane's working directory is remote (e.g. over ssh) or git cannot be run
- **THEN** the panel shows an unavailable empty state rather than attempting to read a local repository

#### Scenario: The panel is toggleable and starts collapsed

- **WHEN** a new window opens, and the user later invokes the toggle command
- **THEN** the panel is initially collapsed (taking no terminal width) and the toggle shows it, and invoking the toggle again hides it

### Requirement: Open a changed file in the editor

From the git-review panel the user SHALL be able to open a changed file in their configured editor — the same opener used for terminal file-links — resolved against the focused session's repository, opening at the relevant line when a specific diff line is targeted. This action SHALL reuse the existing file/link opener configuration; the git-review panel SHALL NOT introduce a separate editor-configuration key.

#### Scenario: Opening a changed file launches the editor at the file

- **WHEN** the user invokes the open-in-editor gesture on a changed file (or a diff line) in the panel
- **THEN** the configured editor is launched for that file (at the targeted line when applicable), resolved against the repository, using the existing link-opener configuration

### Requirement: Read-only review (no write operations)

The git-review panel SHALL be **read-only** in this capability: it SHALL NOT stage, unstage, commit, discard, restore, or otherwise modify the repository or working tree. Users perform write operations via their shell or a dedicated git tool; the underlying data model MAY be designed to accommodate a future staging affordance, but no such control SHALL be exposed in this milestone.

#### Scenario: Reviewing never mutates the repository

- **WHEN** the user browses the changed-file list and diffs in the panel
- **THEN** no staging, commit, discard, or other write controls are offered and the repository and working tree are unchanged by the review

### Requirement: View-free git model in XttyCore

The parsing of git status and diff output into the panel's typed data model SHALL live in a view-free `XttyCore` component, exercisable by unit tests without launching the app or creating a terminal view. The model SHALL represent the changed-file list (path + status category) and a file's unified diff (hunks and classified lines) as toolkit-independent values, and SHALL classify the common git states — modified, added, deleted, untracked, renamed, binary, and merge-conflict — without depending on AppKit view types.

#### Scenario: Parser is unit-testable without the app

- **WHEN** the test suite runs
- **THEN** the git status parser and the diff parser are exercised by unit tests that do not launch the app or create a terminal view

#### Scenario: Status output is classified into categories

- **WHEN** git status output containing modified, added, deleted, untracked, binary, and conflicted entries is parsed
- **THEN** each entry resolves to the correct status category (Changes / Untracked / Conflicts) in the toolkit-independent model

#### Scenario: Diff output is parsed into hunks and lines

- **WHEN** a file's unified-diff output is parsed
- **THEN** the model exposes its hunks and per-line classification (context / added / removed) independent of any view type

### Requirement: Lean, gated refresh

The panel SHALL keep its data current without continuous polling, and SHALL do no work when it is collapsed or when the focused session is not a local repository. It SHALL refresh after a command completes in the focused session (via shell integration), on a low-frequency periodic backstop while visible (so changes made by a still-running foreground process are reflected before it exits), on focus change, and on an explicit manual refresh. Refreshes SHALL be debounced and rate-limited so bursts of activity coalesce into at most one git query per quiet interval, and git queries SHALL run off the main thread and never block the UI.

#### Scenario: Refresh after a command finishes

- **WHEN** a command that changes files completes in the focused session and the panel is visible
- **THEN** the changed-file list updates to reflect the new repository state

#### Scenario: Periodic backstop catches mid-command changes

- **WHEN** a long-running foreground process modifies files without yet exiting and the panel is visible
- **THEN** the panel reflects those changes via the periodic backstop rather than waiting for the process to finish

#### Scenario: No work when collapsed or remote

- **WHEN** the panel is collapsed, or the focused session's directory is remote/non-repository
- **THEN** no git query is performed for the panel

#### Scenario: Bursts of activity coalesce

- **WHEN** several commands finish in rapid succession
- **THEN** the refreshes are debounced/rate-limited into at most one git query per quiet interval rather than one query per command
