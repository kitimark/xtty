# terminal-spatial-blocks Specification

## Purpose

Spatial operations on the captured OSC-133 command blocks (P4b-2): **jump-to-prompt** (scroll the viewport to the previous/next command's prompt, keyboard-native — Cmd+Shift+↑/↓) and **copy-command-output** (copy a block's output to the clipboard, excluding the trailing prompt, with a transient confirmation). Both are engine-only — copy uses the engine's text extraction, never a view-layer selection — so the swappable-renderer seam is preserved. They are enabled by a minimal, engine-only addition to SwiftTerm (a trim-invariant absolute cursor row + the scrollback base) that the project ships **without a fork repo** — a gitignored upstream clone reconstituted from a pinned ref, with an add-only drop-in patch (the means is an implementation choice, not fixed by the spec). Each block carries **optional, best-effort** scroll-invariant anchors captured at the OSC-133 `A`/`C`/`D` marks; the anchors are invalidated on resize/reflow and clear/reset and validated at use, and **every operation degrades gracefully to a no-op** when anchors are absent (no shell integration, provider unavailable, or invalidated). The anchor model, invalidation rules, reverse-mapping, and prev/next selection are view-free in `XttyCore`. Out of scope here: view-layer visual on-screen selection (deferred — it would fork the view) and a clickable per-block sidebar.

## Requirements
### Requirement: Engine-only scroll-invariant coordinate provider
xtty SHALL obtain a stable, scrollback-trim-invariant coordinate for the engine cursor through a minimal addition to the SwiftTerm engine, kept on the headless `Terminal` (never the terminal view), so the swappable-renderer architectural seam is preserved. The addition SHALL provide two read-only values: the cursor's **trim-invariant absolute row** (the buffer-line index plus the monotonic scrollback base) and the **scrollback base** itself (used to reverse-map an absolute row to a current display row and to detect resets). The addition SHALL mirror SwiftTerm's existing public scroll-invariant idiom and SHALL NOT require modifying existing SwiftTerm source files (so it is upstreamable and low-maintenance), and the SwiftTerm dependency SHALL be pinned for reproducibility. The **means** of injecting the addition (e.g. a gitignored upstream clone reconstituted from a pinned ref with an add-only drop-in file, a fork, or vendored source) is an implementation choice and is NOT fixed by this requirement. xtty SHALL access the coordinate behind a seam that tolerates the provider being unavailable: when it is, block anchors SHALL be absent and anchored operations SHALL degrade gracefully (best-effort) rather than fail. An upstream contribution SHALL be pursued so the addition can be retired into upstream SwiftTerm.

#### Scenario: Absolute cursor row is stable across scrollback trim
- **WHEN** output scrolls old lines out of a full scrollback buffer after an absolute cursor row was captured
- **THEN** the captured absolute row still identifies the same logical line (the trim-invariant base compensates for the trimmed lines), so a later reverse-map to a display row is correct

#### Scenario: The coordinate stays on the headless engine
- **WHEN** xtty resolves a block's stored absolute row to a viewport scroll position
- **THEN** it reads the scroll-invariant coordinate from the engine (not from terminal-view internals) and performs the scroll via the engine/view's already-public scroll API, leaving the render layer swappable

#### Scenario: Graceful degradation when the coordinate provider is unavailable
- **WHEN** the scroll-invariant coordinate provider is not available (e.g. the engine addition is not yet wired in)
- **THEN** no block anchors are captured and jump/copy actions no-op gracefully, with no error and no effect on the coordinate-free block model

### Requirement: Best-effort scroll-invariant block anchors
The command-block model SHALL carry **optional, best-effort** scroll-invariant anchors for each block: the prompt row (captured at OSC 133 `A`/prompt-start), the output-start row (captured at `C`/command-start), and the output-end row (captured at `D`/command-end). Anchors SHALL be captured **synchronously inside the OSC 133 handler** (on the engine feed path) so they reflect the cursor position at the mark. The anchors SHALL be additive: a block with no anchors (e.g. shell integration absent, or anchors invalidated) MUST remain a valid block, and the existing coordinate-free block fields (command, exit code, cwd, timestamps, state) and their invariants SHALL be unchanged. The in-flight (running) block SHALL expose its output-start anchor so its output can be copied before it finishes. Anchor capture SHALL be skipped while the alternate screen is active.

#### Scenario: A finished command block carries anchors
- **WHEN** a command runs to completion in a shell with OSC 133 integration active
- **THEN** its block records a prompt row, an output-start row, and an output-end row captured at the `A`/`C`/`D` marks

#### Scenario: Blocks without integration still form
- **WHEN** the shell emits no OSC 133 marks (integration absent, or over tmux/ssh)
- **THEN** blocks degrade to the P4a coordinate-free behavior with no anchors, and nothing in the block model breaks

#### Scenario: Alternate-screen commands capture no anchors
- **WHEN** a full-screen (alternate-screen) program runs
- **THEN** no scroll-invariant anchors are captured for it (consistent with it not becoming a normal scrollable block)

### Requirement: Anchor invalidation for correctness
Stored anchors SHALL be invalidated whenever the buffer's line indexing changes in a way that would make them resolve to the wrong line, so a stale anchor is never silently used. xtty SHALL invalidate **all** of a session's anchors when the terminal is resized or reflowed or its scrollback size changes (signaled by the engine's size-changed delegate), SHALL detect a screen clear / reset (the scrollback base dropping below its high-water mark) and invalidate anchors captured before it, and SHALL validate an anchor **at use**: if its absolute row has been trimmed out of the buffer (no longer addressable), the operation SHALL clamp or no-op rather than scroll to or copy the wrong content. Invalidation SHALL be conservative (a benign over-invalidation that drops still-valid anchors is acceptable; silently using a stale anchor is not). Reset detection MAY be best-effort (a documented narrow masking window — e.g. a clear immediately followed by a large flood within one feed chunk — is acceptable, consistent with OSC 133 being best-effort).

#### Scenario: Resize/reflow invalidates anchors
- **WHEN** the user resizes the window (changing columns and reflowing, or changing rows and trimming)
- **THEN** all of that session's stored anchors are invalidated, so a subsequent jump or copy does not act on a now-misaligned row

#### Scenario: Screen clear invalidates prior anchors
- **WHEN** the screen is cleared/reset (e.g. `clear` emitting ED 3) after blocks were captured
- **THEN** anchors captured before the clear are treated as invalid

#### Scenario: A trimmed-out anchor degrades gracefully
- **WHEN** a jump or copy targets a block whose anchored row has scrolled out of the bounded scrollback
- **THEN** the operation clamps (e.g. scrolls to the top) or no-ops with a non-destructive indication, and never scrolls to or copies unrelated content

### Requirement: Jump to previous/next prompt
xtty SHALL provide actions to scroll the focused pane's viewport to the **previous** and **next** command block's prompt, ordered by the per-session block list. Jumping SHALL move the viewport only (a scroll), never the cursor or a text selection, and SHALL resolve the target by reverse-mapping the block's prompt anchor to a current display row. When there is no adjacent block with a valid anchor (none captured, all invalidated, or already at the first/last), the action SHALL be a graceful no-op. Jump SHALL function only when shell-integration anchors are present and SHALL degrade gracefully (no-op) otherwise.

#### Scenario: Jump to previous prompt scrolls the viewport back
- **WHEN** the user triggers jump-to-previous-prompt with earlier command blocks present and anchored
- **THEN** the viewport scrolls so the previous block's prompt is visible, without moving the cursor or selecting text

#### Scenario: Jump to next prompt scrolls forward
- **WHEN** the user, scrolled back, triggers jump-to-next-prompt
- **THEN** the viewport scrolls to the next block's prompt

#### Scenario: Jump with no anchored target is a no-op
- **WHEN** the user triggers a jump but no adjacent block has a valid anchor
- **THEN** nothing scrolls and no error or destructive action occurs

### Requirement: Copy command output
xtty SHALL provide an action to copy a command block's **output** to the system clipboard, defaulting to the focused/last completed block (or the running block's output so far). The copied range SHALL be the captured output region (from the output-start anchor to the output-end anchor) and SHALL exclude the trailing prompt that follows the command. The text SHALL be obtained via the engine's public text-extraction API (no on-screen visual selection is created — the operation is engine-only). On success xtty SHALL show a transient, non-modal confirmation (e.g. a brief flash/toast) indicating output was copied; when the target block has no valid anchor, the action SHALL no-op with a non-destructive indication rather than copy wrong or empty content silently.

#### Scenario: Copy the last command's output
- **WHEN** the user triggers copy-command-output after a command completed
- **THEN** that command's output text (excluding the following prompt) is placed on the clipboard and a transient confirmation is shown

#### Scenario: Copy excludes the trailing prompt
- **WHEN** the copied block is followed by a new shell prompt
- **THEN** the clipboard contains only the command's output region, not the subsequent prompt text

#### Scenario: Copy with no valid anchor does not copy wrong content
- **WHEN** the target block's anchor has been invalidated or trimmed out
- **THEN** the action no-ops with a non-destructive indication and does not place mismatched or empty text on the clipboard

### Requirement: View-free spatial logic in XttyCore
The anchor model, the anchor-invalidation rules, the absolute-row-to-display-row reverse mapping, and the previous/next-block target selection SHALL live in view-free `XttyCore` logic, exercisable by unit tests without launching the app or creating a terminal view. The app layer SHALL perform only the engine/view calls (capturing the raw coordinate, scrolling, extracting text, clipboard, toast).

#### Scenario: Anchor and selection logic are unit-testable without the app
- **WHEN** the test suite runs
- **THEN** unit tests exercise anchor capture/invalidation, the reverse-map, and previous/next target selection against in-memory inputs without launching the app or instantiating a terminal view

