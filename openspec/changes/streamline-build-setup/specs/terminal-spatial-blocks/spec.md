## MODIFIED Requirements

### Requirement: Engine-only scroll-invariant coordinate provider
xtty SHALL obtain a stable, scrollback-trim-invariant coordinate for the engine cursor through a minimal addition to the SwiftTerm engine, kept on the headless `Terminal` (never the terminal view), so the swappable-renderer architectural seam is preserved. The addition SHALL provide two read-only values: the cursor's **trim-invariant absolute row** (the buffer-line index plus the monotonic scrollback base) and the **scrollback base** itself (used to reverse-map an absolute row to a current display row and to detect resets). The addition SHALL mirror SwiftTerm's existing public scroll-invariant idiom and SHALL NOT require modifying existing SwiftTerm source files (so it is upstreamable and low-maintenance), and the SwiftTerm dependency SHALL be pinned for reproducibility. The **means** of injecting the addition (e.g. a gitignored upstream clone reconstituted from a pinned ref with an applied add-only patch, a fork, or vendored source) is an implementation choice and is NOT fixed by this requirement. xtty SHALL access the coordinate behind a seam that tolerates the provider being unavailable: when it is, block anchors SHALL be absent and anchored operations SHALL degrade gracefully (best-effort) rather than fail. An upstream contribution SHALL be pursued so the addition can be retired into upstream SwiftTerm.

#### Scenario: Absolute cursor row is stable across scrollback trim
- **WHEN** output scrolls old lines out of a full scrollback buffer after an absolute cursor row was captured
- **THEN** the captured absolute row still identifies the same logical line (the trim-invariant base compensates for the trimmed lines), so a later reverse-map to a display row is correct

#### Scenario: The coordinate stays on the headless engine
- **WHEN** xtty resolves a block's stored absolute row to a viewport scroll position
- **THEN** it reads the scroll-invariant coordinate from the engine (not from terminal-view internals) and performs the scroll via the engine/view's already-public scroll API, leaving the render layer swappable

#### Scenario: Graceful degradation when the coordinate provider is unavailable
- **WHEN** the scroll-invariant coordinate provider is not available (e.g. the engine addition is not yet wired in)
- **THEN** no block anchors are captured and jump/copy actions no-op gracefully, with no error and no effect on the coordinate-free block model
