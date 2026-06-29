# git-review Specification

## Purpose

Defines xtty's read-only **git-review panel** (requirement H2, the "Zed habit" — review changed files and their diffs before committing, including what an agent just edited). Built on the P4a semantic-capture cwd and the P4b-1 click-to-open-in-editor plumbing. It covers the panel's changed-files list grouped by status category (Changes / Untracked / Conflicts) — optionally presented as a collapsible directory tree of the *same* changed files (a presentation toggle, default flat) — with a read-only unified diff of the selected file, opening a changed file in the configured editor (reusing the file/link opener), the read-only scope (no staging/commit/write — the data model stays forward-compatible with a later stage toggle), the view-free git status/diff model in `XttyCore`, and the lean, gated refresh (command-finish + a periodic backstop + focus + manual, debounced and rate-limited, doing no work when collapsed or when the focused session is not a local repository). The full *project* file-tree browser (browsing unchanged files) and write operations are explicitly out of scope (pair with `lazygit`).

## Requirements
### Requirement: Git-review panel

The application SHALL present a toggleable **git-review panel**, hosted as SwiftUI chrome beside the AppKit terminal area (it contains no terminal view) and distinct from the session-progress sidebar. For the focused pane's session, when that session's working directory is a **local git repository**, the panel SHALL list the repository's changed files — **by default grouped by status category** — at minimum **Changes** (tracked modifications and deletions), **Untracked**, and **Conflicts** — each file shown with a status indicator and its path relative to the repository root, and empty groups SHALL be hidden. The panel MAY alternatively present the **same** changed files as a collapsible directory tree (see the **Changed-files tree layout** requirement). Selecting a changed file SHALL show that file's changes as a **read-only unified diff** within the panel. The panel SHALL start **collapsed** and SHALL be toggled by a View-menu command with a default keyboard shortcut. When the focused session's directory is not a local repository (no repository, or a remote/ssh working directory) or git is unavailable, the panel SHALL show an explanatory **empty state** rather than file content.

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

### Requirement: Changed-files tree layout

The git-review panel SHALL be able to present the focused repository's changed files in two layouts: the default **status-category grouping** (flat) and a **collapsible directory tree** of the **same** changed files, and the user SHALL be able to switch between the two layouts. The directory-tree layout SHALL organize the same changed files by their repository-root-relative directory path, with intermediate directories shown as expandable/collapsible nodes and each changed file shown as a leaf with the same status indicator it has in the flat layout. The tree layout SHALL be **presentation only**: it SHALL show exactly the changed files the flat layout shows (no additional files, and in particular no unchanged files — this is not a project file browser), SHALL NOT alter any file's status or diff, and SHALL preserve the panel's **read-only** nature. Selecting a file and opening a file in the editor SHALL behave identically in either layout. The **default** layout SHALL be configurable, defaulting to the flat grouping so existing behavior is unchanged.

#### Scenario: Switching to the tree layout groups files by directory

- **WHEN** the focused repository has changed files in nested directories and the user switches the panel to the directory-tree layout
- **THEN** the panel presents those changed files under expandable/collapsible directory nodes reflecting their repository-root-relative paths, and switching back returns to the status-category grouping

#### Scenario: The tree shows the same changed files as the flat layout

- **WHEN** the panel is in the directory-tree layout
- **THEN** the set of files shown is exactly the changed files reported in the flat layout — no unchanged files and no files beyond those — each with the same status indicator

#### Scenario: Selecting and opening a file work the same in either layout

- **WHEN** the user selects a changed file, or invokes open-in-editor on it, while the panel is in the directory-tree layout
- **THEN** the read-only diff is shown (selection) or the configured editor is launched (open) exactly as in the flat layout, with no write to the repository

#### Scenario: The default layout is configurable

- **WHEN** the configuration selects the directory-tree layout as the default and the git-review panel is shown for a repository with changes
- **THEN** the panel initially presents the directory-tree layout; and when the configuration is absent or invalid, the panel defaults to the flat status-category grouping

