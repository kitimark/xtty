## MODIFIED Requirements

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

## ADDED Requirements

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
