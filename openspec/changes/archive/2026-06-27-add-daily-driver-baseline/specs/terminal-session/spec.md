## ADDED Requirements

### Requirement: Find in terminal output
The terminal SHALL support searching its visible screen and scrollback for text, surfaced through a native find bar opened with **Cmd+F**. The user SHALL be able to navigate to the next and previous matches and dismiss the find bar, returning keyboard focus to the terminal. This extends the interactive-terminal behavior set without changing existing input/resize/paste/scrollback/selection behavior.

#### Scenario: Cmd+F opens the find bar
- **WHEN** the terminal is focused and the user presses Cmd+F
- **THEN** a find bar appears and accepts a search query

#### Scenario: Matches are located and navigable
- **WHEN** the user enters a query that occurs in the visible screen or scrollback
- **THEN** a match is located, and next/previous controls move the selection between matches

#### Scenario: Dismissing the find bar restores terminal focus
- **WHEN** the user closes the find bar (e.g. Escape or its close control)
- **THEN** the find bar is hidden and keyboard input is routed to the terminal again
