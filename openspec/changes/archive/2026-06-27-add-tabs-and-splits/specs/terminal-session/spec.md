## MODIFIED Requirements

### Requirement: Terminal process lifecycle
The application SHALL manage each session's shell process lifecycle correctly: start each session's shell exactly once, keep keyboard focus on the focused pane, and terminate a session's child process when its pane (or the window containing it) closes — leaving no orphaned shells.

#### Scenario: Each session's shell is spawned exactly once
- **WHEN** the UI updates or a window redraws after a pane is created
- **THEN** no additional shell process is spawned for that pane (its shell is started only once, at pane creation)

#### Scenario: Focused pane has keyboard focus
- **WHEN** a window becomes key
- **THEN** the focused pane's terminal is the first responder and receives keystrokes without an extra click

#### Scenario: No orphaned process on close
- **WHEN** a pane is closed, or the window/app is closed
- **THEN** the affected session's shell child process is terminated (no orphaned shell remains)

### Requirement: Shell exit policy
When a session's shell process exits, the application SHALL close that session's pane and record the process exit code on the session. Closing the last pane in a tab SHALL close that tab/window, and closing the last window SHALL terminate the app.

#### Scenario: Pane closes when its shell exits
- **WHEN** a pane's shell exits (e.g. the user types `exit`) while other panes remain in the tab
- **THEN** that pane closes and the remaining panes reflow to fill the space
- **AND** the session's recorded exit status reflects the shell's exit code

#### Scenario: Closing the last pane escalates to the window
- **WHEN** the shell in the only remaining pane of a window exits
- **THEN** the window closes
- **AND** if it was the last window, the app terminates
