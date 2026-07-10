## ADDED Requirements

### Requirement: Scroll-region shift redraw-correctness coverage

The harness SHALL cover, end-to-end against the real running app, that a scroll-region shift within the alternate screen buffer correctly moves every column of the affected rows, not only the first — the defect class this requirement guards against. The test SHALL drive the terminal engine directly with a known escape-sequence sequence (entering the alternate screen, setting a scroll region, writing distinct content into known rows, then scrolling up and back down by the same amount) rather than depending on a specific real full-screen program, because which escape-sequence idiom a given program uses for its own scrolling is a program-internal implementation choice outside this project's control — programs bundled with the test VM image (e.g. `vim`, `less`) do not exercise this scroll-region-shift code path at all regardless of how they are driven, while the program that does (`htop`) is not present in the minimal test VM image. Driving the exact sequence directly is deterministic, needs no additional VM dependency, and targets the defect precisely.

#### Scenario: A scroll-up-then-down reversal over known content preserves every column

- **WHEN** the tests, in a `-UITestGridDump` DEBUG build, drive the terminal into the alternate screen with a scroll region set, write distinct known content into multiple rows within that region, scroll up by N, then scroll down by the same N
- **THEN** the grid dump shows the affected rows fully restored to their original content in every column — not the buggy state where only the first column of each row is restored and the remaining columns retain stale content left over from the scroll-up
