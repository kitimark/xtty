## ADDED Requirements

### Requirement: Diff line-wrap mode

The git-review panel's read-only unified diff SHALL fill the **full width of the panel** and SHALL support two **line-wrap modes**, selectable by the user **without leaving the panel**: a **wrap** mode in which a diff line longer than the panel folds onto continuation rows — the leading add/remove/context marker remaining in its own leading gutter so continuation rows hang-indent under the line content — and a **no-wrap** mode in which each diff line remains on a single row and the panel scrolls **horizontally** to reveal content wider than the panel, with each line's whole-line styling spanning the full content width. The wrap mode SHALL be **presentation only**: it SHALL NOT alter the diff's classified-line content, the intra-line emphasis, or the panel's read-only nature, and it SHALL apply identically regardless of the changed-files list layout (flat or directory tree). The **default** wrap mode SHALL be configurable (see terminal-configuration's `git-review-diff-wrap` key), defaulting to **wrap**. Switching modes SHALL affect only how the same diff lines are laid out, never which lines are shown.

#### Scenario: The diff fills the panel width

- **WHEN** a changed file's diff is shown in the git-review panel
- **THEN** the diff content occupies the full width of the panel (not a fraction of it), in whichever wrap mode is active

#### Scenario: Wrap mode folds long lines within the panel

- **WHEN** the panel is in wrap mode and a selected file's diff contains a line longer than the panel width
- **THEN** that line folds onto continuation rows within the panel width, its leading marker stays in the marker gutter (continuation rows hang-indent under the content), and no horizontal scrolling is required to read it

#### Scenario: No-wrap mode keeps lines whole and scrolls horizontally

- **WHEN** the panel is in no-wrap mode and a selected file's diff contains a line longer than the panel width
- **THEN** that line stays on a single row, the panel scrolls horizontally to reveal the remainder, and the line's whole-line added/removed styling spans the full content width

#### Scenario: Toggling wrap mode is presentation-only

- **WHEN** the user switches the diff wrap mode via the in-panel control
- **THEN** the set of diff lines, their classification, and the intra-line emphasis are unchanged, no write to the repository occurs, and only the layout of the same lines changes

#### Scenario: The default wrap mode is configurable

- **WHEN** the git-review default wrap mode is configured to `nowrap` and a file's diff is shown
- **THEN** the diff initially renders in no-wrap mode; and when the configuration is absent or invalid, the diff defaults to wrap mode
