## MODIFIED Requirements

### Requirement: Soft-wrap-robust content assertion

The deterministic content assertion SHALL confirm that typed content reached the focused pane's grid **even when the terminal soft-wraps that content across physical rows**. Because the grid dump emits the focused pane's physical rows, a content assertion that an out-of-process test makes about typed text SHALL match that text regardless of soft-wrap row boundaries, while a string that genuinely never reached the grid SHALL still fail the assertion. The focus-typing-on-activate coverage **and the find-bar focus-restore coverage** SHALL use this wrap-robust assertion so that each passes when typed input reaches the focused pane and the terminal wraps it (e.g. behind a long shell prompt), and fails only when the input does not arrive. A dedicated regression guard SHALL exercise this behavior deterministically — independent of the ambient shell prompt width — by typing a marker that is guaranteed to soft-wrap and confirming that the wrap-robust assertion matches it while a strict (wrap-intolerant) match does not.

#### Scenario: A soft-wrapped typed marker is still asserted present

- **WHEN** the app is launched with `-UITestGridDump` in a DEBUG build, the focused pane shows a long prompt, and a unique marker is typed such that the terminal soft-wraps it across two physical rows in the grid dump
- **THEN** the focus-typing-on-activate assertion confirms the marker is present in the focused pane's grid

#### Scenario: A genuinely absent marker still fails the assertion

- **WHEN** the wrap-robust content assertion is used and the asserted string never reached the focused pane's grid
- **THEN** the assertion fails (the wrap tolerance does not fabricate a match)

#### Scenario: Find-bar focus-restore tolerates a wrapped marker

- **WHEN** the find bar is opened and dismissed, focus returns to the terminal, and a unique marker typed afterward is soft-wrapped across two physical rows in the grid dump (e.g. behind a long shell prompt)
- **THEN** the find-bar focus-restore assertion confirms the marker reached the focused pane's grid (focus restoration is verified independent of prompt width)

#### Scenario: The deterministic soft-wrap guard proves the wrap-robust assertion is required and works

- **WHEN** a guard test types a marker constructed to be wider than the focused pane, such that the grid dump splits it across at least two physical rows
- **THEN** the guard confirms the marker genuinely spanned multiple physical rows, the wrap-robust assertion matches it, and a strict (wrap-intolerant) match of the same marker does not
