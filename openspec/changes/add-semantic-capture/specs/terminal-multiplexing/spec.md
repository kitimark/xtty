## MODIFIED Requirements

### Requirement: Split a pane into multiple panes
The terminal SHALL let the user split the focused pane horizontally or vertically into multiple panes within a single window, where each pane is an independent terminal session running its own shell. A split SHALL inherit the focused pane's profile, so the new pane launches with the same profile (appearance plus launch overrides) as the pane it was split from. A split SHALL also start in the focused pane's **current (live) working directory** when one is known, falling back to the inherited profile's launch directory and then the default. Dragging a split divider SHALL resize the adjacent panes and reflow their shells to the new size without display corruption.

#### Scenario: Splitting creates a new independent session
- **WHEN** the user splits the focused pane (horizontally or vertically)
- **THEN** the window shows two panes side by side (or stacked)
- **AND** the new pane runs its own shell that independently accepts a typed command

#### Scenario: Dragging a divider reflows the shells
- **WHEN** the user drags the divider between two panes
- **THEN** both panes resize to the new proportions
- **AND** a full-screen program in either pane redraws correctly at its new size

#### Scenario: A split inherits the focused pane's profile
- **WHEN** the focused pane was launched with a non-base profile and the user splits it
- **THEN** the new pane launches with the same profile (same appearance and launch overrides)

#### Scenario: A split opens in the focused pane's current directory
- **WHEN** the focused pane has changed directory (its live working directory differs from its launch directory) and the user splits it
- **THEN** the new pane starts in the focused pane's current working directory
- **AND** when no live working directory is known, the new pane falls back to the inherited profile's launch directory
