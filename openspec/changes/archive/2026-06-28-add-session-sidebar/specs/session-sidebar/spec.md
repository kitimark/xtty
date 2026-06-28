## ADDED Requirements

### Requirement: Session-progress sidebar

The application SHALL present a session-progress sidebar that lists the key window's panes grouped as a two-level **`Tab ▸ Pane`** tree, showing for each pane its current activity state, its most recent command (when known), and — for a running command — a live elapsed duration. The sidebar SHALL be hosted as SwiftUI chrome beside the AppKit terminal area (it contains no terminal view), SHALL be toggleable, and SHALL exclude the quick-terminal scratch session (which lives in a separate private registry). Activating (clicking) a sidebar row SHALL focus that pane — bringing its tab/window forward when it is not frontmost — and SHALL NOT scroll the terminal to any row.

#### Scenario: Sidebar lists tabs and their panes
- **WHEN** the key window has multiple tabs and a tab is split into multiple panes
- **THEN** the sidebar shows each tab with its panes nested beneath it, each pane row showing its activity state and last command

#### Scenario: Clicking a pane focuses it
- **WHEN** the user clicks a pane's row in the sidebar
- **THEN** that pane becomes the active/focused pane, its tab/window is brought forward if needed, and the terminal is not scrolled to any prompt row

#### Scenario: A running command shows live state and duration
- **WHEN** a command is executing in a pane
- **THEN** that pane's row shows the running state and an elapsed duration that advances while it runs

#### Scenario: The quick terminal is not listed
- **WHEN** the quick-terminal panel is open with its scratch session
- **THEN** the sidebar does not list the quick-terminal session among the window's panes

### Requirement: Session activity state derivation

`XttyCore` SHALL expose a view-free session activity state with the values **idle**, **running**, **succeeded**, **failed**, and **fullScreen**, derived from the per-session block model and the alternate-screen flag with a fixed precedence: fullScreen when the session is on the alternate screen; otherwise running when a command is in flight; otherwise failed when the most recent finished command had a non-zero exit; otherwise succeeded when the most recent finished command succeeded; otherwise idle. The derivation SHALL be a pure, unit-testable function that does not launch the app or create a terminal view.

#### Scenario: A failed last command yields a failed session state
- **WHEN** the most recent finished command in a session exited non-zero and the session is not on the alternate screen and nothing is currently running
- **THEN** the session activity state is failed

#### Scenario: A full-screen app overrides other states
- **WHEN** the session is on the alternate screen (e.g. running vim)
- **THEN** the session activity state is fullScreen regardless of the last command's exit code

#### Scenario: A fresh session is idle
- **WHEN** a session has produced no command blocks and nothing is running
- **THEN** the session activity state is idle

#### Scenario: Derivation runs without the app
- **WHEN** the test suite runs
- **THEN** the activity-state derivation (precedence over running/failed/succeeded/fullScreen/idle) is exercised by a unit test that does not launch the app or create a terminal view

### Requirement: Lean, event-driven sidebar updates

The sidebar SHALL update from observable model changes rather than polling: session and block transitions SHALL publish synchronously on the main actor (the semantic-capture handlers already run there), and the only periodic work SHALL be the live elapsed-duration display for running rows, which SHALL do no work when no command is running. The sidebar SHALL NOT introduce a global timer or background polling loop, honoring the lean-memory / latency-first product values.

#### Scenario: Idle sidebar does no periodic work
- **WHEN** no command is running in any listed pane
- **THEN** the sidebar performs no periodic duration updates

#### Scenario: State changes propagate without polling
- **WHEN** a command starts or finishes in a pane
- **THEN** the corresponding sidebar row reflects the new state from an observed model change, not from a poll
