## ADDED Requirements

### Requirement: Scroll-region redraw-correctness end-to-end coverage

The harness SHALL cover, end-to-end, that a real full-screen mouse-tracking program's display survives a wheel-driven scroll direction reversal without corruption. The test SHALL drive a real program (not a synthetic escape-sequence injection) through a scroll some distance in one direction and then a reversal, and assert via the existing DEBUG grid-dump content-assertion channel that the program's visible rows show correct, non-duplicated content after the reversal — not merely that a wheel gesture was routed to the program (which the existing mouse-wheel-routing coverage already asserts).

#### Scenario: A real full-screen program's list survives a wheel scroll-then-reversal

- **WHEN** the tests focus a pane running a real full-screen mouse-tracking program in a `-UITestGridDump` DEBUG build, scroll the wheel some distance in one direction, then reverse it
- **THEN** the grid dump shows the program's visible rows with correct, uncorrupted, non-duplicated content — matching what the program's own state should display at that scroll position
