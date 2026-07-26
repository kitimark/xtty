## MODIFIED Requirements

### Requirement: Git-review end-to-end coverage
The harness SHALL cover the git-review panel end-to-end by driving a real shell with shell-integration injection active inside a temporary git repository and asserting, via the DEBUG state dump, that the panel lists the repository's changed files with their status categories for a known repository state, that selecting a changed file yields the expected diff summary (including, for a partial single-line change, **non-empty intra-line emphasis spans**), that the open-in-editor action routes through the editor opener — asserted via the existing **resolved link-open action** field, not a real editor — that the changed-files list **layout** reported by the state dump reflects the configured default (flat vs directory tree), that the diff **wrap mode** reported by the state dump reflects the configured default and flips when the **real in-panel wrap control** is driven, and that the DEBUG diff **layout-geometry** signals confirm each mode's rendered layout (wrap fills the panel width without horizontal overflow; no-wrap overflows horizontally for a line longer than the panel). Coverage SHALL also select production-limit many-line and single-overlong-line diffs, assert that each publishes a truncated summary within a bounded time, and drive the real truncated-preview open-in-editor action. For a selected preview process, the DEBUG state dump SHALL expose the exact Git PID, selected path, xtty-owned cutoff reason, reap completion, and an OS-level post-reap absence check; the dump SHALL expose only this bounded process metadata, never diff text. Coverage SHALL include the **non-repository** and **remote/unavailable** empty-state cases. The real editor SHALL NOT be required for assertions.

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

#### Scenario: Large-diff cutoff and cleanup are observable

- **WHEN** the tests select production-limit many-line and single-overlong-line fixtures in a `-UITestGridDump` DEBUG build
- **THEN** each selected-diff summary reports truncation within a bounded time, the real truncated-preview action routes through the opener, and the preview-process observation reports the exact Git PID reaped and absent after xtty's owned cutoff

#### Scenario: The configured list layout is reported

- **WHEN** the tests launch with the git-review default layout configured to `tree` and show the panel for a repository with changed files in a `-UITestGridDump` DEBUG build
- **THEN** the state dump's git-review snapshot reports the directory-tree layout, so the test can assert the configured default was applied

#### Scenario: The configured diff wrap mode is reported and the real toggle flips it

- **WHEN** the tests launch with the git-review default wrap mode configured to `nowrap`, show a selected diff in a `-UITestGridDump` DEBUG build, and then drive the **real in-panel wrap control** (its accessibility element, not a debug-only shortcut)
- **THEN** the state dump's git-review snapshot first reports no-wrap (the configured default) and, after the toggle, reports wrap — so the test asserts the configured default and the real control→store routing without measuring pixels

#### Scenario: Each wrap mode's rendered layout is observable

- **WHEN** a selected diff containing a line longer than the panel is shown in a `-UITestGridDump` DEBUG build, in wrap mode and then in no-wrap mode
- **THEN** the state dump's DEBUG layout-geometry signals report, in wrap mode, that the diff fills the panel width and does not overflow horizontally, and in no-wrap mode that it overflows horizontally — so the test asserts each mode's actual rendered layout (catching a width-collapse regression) without measuring pixels

#### Scenario: Empty states are observable

- **WHEN** the focused pane's directory is not a repository, or is remote/unavailable
- **THEN** the state dump's git-review snapshot reports the non-repository / remote flag so the test can assert the empty state
