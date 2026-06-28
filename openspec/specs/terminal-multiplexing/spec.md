# terminal-multiplexing Specification

## Purpose

Running multiple terminal sessions arranged within and across native macOS windows and tabs: custom splits/panes (a recursive split tree rendered with `NSSplitView`), native window tabbing (a tab is a window, Ghostty-style), multiple top-level windows, directional pane focus, commands acting on the focused pane via the responder chain, and a unified close/exit-escalation lifecycle (pane → tab/window → quit, with confirm-on-close for a running foreground job). The arrangement is backed by a view-free model in `XttyCore` (pane identity, the split-tree structure, and which pane is focused) that non-view features — the P5 session sidebar, a future agent API — enumerate, keeping the render layer swappable.
## Requirements
### Requirement: Split a pane into multiple panes
The terminal SHALL let the user split the focused pane horizontally or vertically into multiple panes within a single window, where each pane is an independent terminal session running its own shell. A split SHALL inherit the focused pane's profile, so the new pane launches with the same profile (appearance plus launch overrides) as the pane it was split from. Dragging a split divider SHALL resize the adjacent panes and reflow their shells to the new size without display corruption.

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

### Requirement: Close a pane and collapse the layout
The terminal SHALL let the user close the focused pane; the remaining panes SHALL reflow to fill the freed space. When a split is left with a single child, that split level SHALL collapse so its surviving child is promoted, leaving no empty regions.

#### Scenario: Closing a pane reflows the survivors
- **WHEN** the user closes the focused pane while other panes remain in the tab
- **THEN** the closed pane's shell is terminated
- **AND** the remaining panes expand to fill the space with no empty region left behind

### Requirement: Navigate focus between panes
The terminal SHALL let the user move keyboard focus directionally between panes. Exactly one pane in the key window SHALL be focused at a time; the focused pane SHALL show the active cursor and receive keyboard input.

#### Scenario: Directional focus moves the active pane
- **WHEN** the window has multiple panes and the user issues a directional focus command (e.g. focus-right)
- **THEN** keyboard focus moves to the adjacent pane in that direction
- **AND** the newly focused pane shows the active cursor and subsequent typing goes to its shell

### Requirement: Native macOS tabs
The application SHALL support multiple tabs using native macOS window tabbing, where each tab hosts its own pane tree and terminal session(s). Opening a new tab SHALL create a new session using the default profile (or the base profile when none is set). The application SHALL also offer a "New Tab with Profile" selection that opens a new tab using a chosen named profile. macOS native tabbing SHALL group tabs (providing the tab bar and standard tab navigation).

#### Scenario: New tab opens an independent session
- **WHEN** the user opens a new tab
- **THEN** a native macOS tab appears hosting its own pane running the user's shell
- **AND** switching tabs shows that tab's panes and routes input to its focused pane

#### Scenario: New tab uses the default profile
- **WHEN** a `default-profile` is configured and the user opens a new tab
- **THEN** the new tab's pane is launched with the default profile

#### Scenario: New Tab with Profile opens a chosen profile
- **WHEN** the user opens a new tab via the "New Tab with Profile" selection for a named profile
- **THEN** the new tab's pane is launched with that profile

### Requirement: Multiple windows
The application SHALL support opening multiple top-level windows, each with its own tabs and pane tree, independent of one another.

#### Scenario: New window opens independently
- **WHEN** the user opens a new window
- **THEN** a separate top-level window appears hosting its own terminal session
- **AND** closing one window does not affect the sessions in other windows

### Requirement: User-initiated pane close with escalation and confirmation
A user close command (e.g. Cmd+W or a close control) SHALL close the focused pane, escalating: closing the last pane in a tab closes that tab/window, and closing the last window terminates the app. When the focused pane has a running foreground process, the application SHALL ask the user to confirm before closing, unless confirmation is disabled by the `confirm-close` configuration key (default enabled).

#### Scenario: Close escalates from pane to window
- **WHEN** the user issues the close command on the only pane of the only tab in a window
- **THEN** the window closes
- **AND** if it was the last window, the app terminates

#### Scenario: Confirm before closing a running pane
- **WHEN** the user issues the close command on a pane whose shell has a running foreground process and confirmation is enabled
- **THEN** the application asks the user to confirm before terminating the process and closing the pane

#### Scenario: Confirmation can be disabled by configuration
- **WHEN** `confirm-close` is set to false and the user closes a pane with a running foreground process
- **THEN** the pane closes without a confirmation prompt

### Requirement: Commands apply to the focused pane
Pane-scoped commands (such as font-size adjustment, find, copy/paste) SHALL act on the focused pane of the key window, routed through the responder chain rather than a fixed single controller.

#### Scenario: Font-size change targets the focused pane
- **WHEN** the user focuses one pane among several and adjusts the font size
- **THEN** only the focused pane's font size changes
- **AND** focusing a different pane and repeating the command affects that pane instead

### Requirement: View-free multiplexing model in XttyCore
The arrangement of sessions (the split-tree structure, pane identity, and which pane is focused) SHALL be represented in a view-free `XttyCore` model that does not import the app/UI target or a concrete terminal view, and is exercisable by unit tests without launching the app. A pane's identity SHALL include the name of the profile it was launched with (the base profile being unnamed). The model SHALL expose the set of live sessions so non-view features (e.g. a future session sidebar) can enumerate them, including each pane's profile.

#### Scenario: Model tracks structure and focus without views
- **WHEN** panes are split, closed, and focused
- **THEN** the `XttyCore` model reflects the resulting tree structure, the live sessions, and the focused pane
- **AND** these are asserted by a unit test that does not launch the app or instantiate a terminal view

#### Scenario: Model is independent of UI types
- **WHEN** `XttyCore` is built
- **THEN** the multiplexing model does not import the app/UI target or a concrete terminal view type

#### Scenario: Pane identity records its profile
- **WHEN** a pane is launched with a named profile
- **THEN** the model's pane identity reflects that profile name, and a base-profile pane has no profile name

