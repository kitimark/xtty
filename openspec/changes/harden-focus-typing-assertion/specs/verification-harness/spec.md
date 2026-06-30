## ADDED Requirements

### Requirement: Soft-wrap-robust content assertion

The deterministic content assertion SHALL confirm that typed content reached the focused pane's grid **even when the terminal soft-wraps that content across physical rows**. Because the grid dump emits the focused pane's physical rows, a content assertion that an out-of-process test makes about typed text SHALL match that text regardless of soft-wrap row boundaries, while a string that genuinely never reached the grid SHALL still fail the assertion. The focus-typing-on-activate coverage SHALL use this wrap-robust assertion so that it passes when typed input reaches the focused pane and the terminal wraps it (e.g. behind a long shell prompt), and fails only when the input does not arrive.

#### Scenario: A soft-wrapped typed marker is still asserted present

- **WHEN** the app is launched with `-UITestGridDump` in a DEBUG build, the focused pane shows a long prompt, and a unique marker is typed such that the terminal soft-wraps it across two physical rows in the grid dump
- **THEN** the focus-typing-on-activate assertion confirms the marker is present in the focused pane's grid

#### Scenario: A genuinely absent marker still fails the assertion

- **WHEN** the wrap-robust content assertion is used and the asserted string never reached the focused pane's grid
- **THEN** the assertion fails (the wrap tolerance does not fabricate a match)
