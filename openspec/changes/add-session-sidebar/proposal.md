## Why

The at-a-glance per-session progress sidebar (requirements **H1**) is the user's single favorite feature from Warp, and it is the first differentiator that P4a's semantic-capture keystone makes possible. P4a's view-free `Block` model already carries everything the sidebar needs (command / exit code / cwd / timestamps / state) entirely in `XttyCore` — so the sidebar is **100% fork-free** and is the highest-value next step. Sequencing rationale (P5 before P4b) and the resolved design questions are recorded in `research/03-analysis/p5-sidebar-and-p4b-sequencing.md`.

## What Changes

- **New SwiftUI session-progress sidebar** — a `Tab ▸ Pane` tree (scoped to the key window) listing each pane with its live state, last command, and (for a running command) a ticking duration.
- **A session-level activity state** in `XttyCore` — `idle / running / succeeded / failed / fullScreen` — derived from the existing per-session `BlockTracker` (last block's exit/state) plus the alternate-screen flag. This is distinct from the per-block `BlockState`.
- **Expose the in-flight (running) command** from `BlockTracker` — today blocks are appended only at the closing OSC 133 `D` mark, so `BlockState.running` is defined but never produced; the sidebar needs the running command (text + start time) to show "working" and tick a duration. This is a small, fork-free `XttyCore` addition (no screen coordinates are stored — the jump anchor remains a P4b concern).
- **Click a sidebar row to focus that pane** — reusing the existing pane-focus path (`setActivePane`), bringing a background tab/window forward. **No scroll-to-row** (that would require the deferred P4b fork).
- **Event-driven updates** — the sidebar observes an `@Observable` session registry; the OSC handlers already run on the main actor, so state updates are synchronous with no extra threading. A single per-running-row timer drives the live duration display.
- **Harness coverage** — the DEBUG state dump exposes the session activity + running command so an XCUITest can assert the sidebar reflects a running vs. finished vs. failed command.

Out of scope (explicitly deferred): scroll-to-prompt / jump, output selection or copy, gutter fail-marks, OSC 9;4 progress bars, a global cross-window sidebar, and any SwiftTerm fork.

## Capabilities

### New Capabilities
- `session-sidebar`: the per-session progress sidebar — its `Tab ▸ Pane` structure, the session-level activity-state vocabulary and how each state is derived, the displayed fields (last command, live duration), click-to-focus behavior, and the lean/event-driven update model.

### Modified Capabilities
- `terminal-semantics`: the per-session command-block model gains an exposed **in-flight running block** (the `running` state is actually produced and the running command's text/start are readable) so consumers can show live progress; still stores no screen coordinates.
- `verification-harness`: the DEBUG state dump additionally exposes the focused pane's **session activity state** and **running command** so sidebar/progress behavior is deterministically assertable; adds end-to-end coverage that a running command shows as running and a finished/failed command updates the sidebar state.

## Impact

- **`XttyCore`**: `BlockTracker` exposes the running block (state + start); new `SessionActivity` enum + derivation; `SessionRegistry` becomes `@Observable` (or gains an observable revision) and publishes on block transitions. View-free, unit-tested.
- **`App`**: a new SwiftUI sidebar view hosted in the AppKit window; `TerminalWindowController` gains a small public surface (ordered panes / pane ownership / tab title) and a public `focusPane(id)` wrapping `setActivePane`; the coordinator assembles the `Tab ▸ Pane` view-model from `windowControllers` + `tree.leaves()`; state-dump additions.
- **`AppUITests`**: a new XCUITest asserting the sidebar state via the state dump (running → finished/failed).
- **Dependencies**: none added; **no SwiftTerm fork**. Honors the lean-memory / latency-first product values (event-driven, one self-pausing timer).
