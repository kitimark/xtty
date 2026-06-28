## Context

P4a (`add-semantic-capture`, archived) landed a view-free, per-session `BlockTracker` in `XttyCore` producing `Block` values (command / exit / cwd / timestamps / `state ∈ running·succeeded·failed·opaque`) plus a public `isAlternateScreen` flag — all driven by OSC 133 marks, with **no screen coordinates** stored (a deliberate principle: coordinates are unavailable via SwiftTerm's public API and rot on scrollback trim). This change consumes that data to build the H1 session-progress sidebar — the user's favorite Warp feature.

Constraints that shape the design:
- **The seam holds:** all logic reads the `Terminal` engine via `XttyCore`; the sidebar reads `XttyCore` model objects, never `TerminalView` internals. No SwiftTerm fork.
- **SwiftUI hosting caveat:** SwiftTerm renders black inside a SwiftUI `NSViewRepresentable` on macOS 26, which is why the *terminal view* lives in an AppKit `NSWindow`. The sidebar is **plain SwiftUI chrome** (no SwiftTerm view inside it), so it is unaffected — it is hosted alongside the AppKit terminal area via `NSHostingView`.
- **Lean / latency-first:** no global polling; event-driven updates; at most one self-pausing timer for the live duration.
- The existing window already hosts a custom `NSSplitView` pane tree per `TerminalWindowController`; quick-terminal panes live in a separate **private** `SessionRegistry` and must stay out of the sidebar.

Decisions resolved up-front in `research/03-analysis/p5-sidebar-and-p4b-sequencing.md` (states, fork-free viability, grouping, copy-vs-select, refresh cadence) — this design records the implementation-level choices.

## Goals / Non-Goals

**Goals:**
- A per-window `Tab ▸ Pane` sidebar showing each pane's live activity state, last command, and a ticking duration for running commands.
- A view-free, unit-tested session-activity derivation in `XttyCore`.
- Click-to-focus a pane (including bringing a background tab/window forward).
- Event-driven updates that honor the lean/latency values; no fork; no stored coordinates.
- DEBUG state-dump + XCUITest coverage of the activity state and running command.

**Non-Goals (deferred):**
- Scroll-to-prompt / jump-to-output, output selection or copy, gutter fail-marks (all P4b — need the SwiftTerm accessor fork).
- OSC 9;4 progress bars / `.pause` "waiting" state, and best-effort "Copy output" (P5-bonus, deliberately out of this first change).
- A global cross-window "mission control" sidebar (scoped to the key window here; the data path widens later if wanted).
- Any change to the terminal renderer or a Metal switch.

## Decisions

### D1 — Session activity is a derived state distinct from `BlockState`
Add a view-free `SessionActivity` enum in `XttyCore`: `idle / running / succeeded / failed / fullScreen`. Derive it per session with a fixed precedence:
1. `fullScreen` if `isAlternateScreen` is true (vim/htop/less own the screen);
2. else `running` if a command is in flight (see D2);
3. else `failed` if the most recent finished block failed (non-zero exit);
4. else `succeeded` if the most recent finished block succeeded;
5. else `idle` (no blocks yet / fresh prompt).

*Why a separate enum, not reuse `BlockState`:* `BlockState` describes one block; the sidebar wants one *session* summary that folds in the alt-screen flag and "nothing run yet." Keeping them separate avoids overloading the per-block type. *Alternative considered:* compute the state in the view layer — rejected to keep it unit-testable and view-free.

### D2 — Expose the in-flight running block from `BlockTracker` (no coordinates)
Today `BlockTracker` appends to `blocks` only at the closing `D`; the open command sits in private fields and `BlockState.running` is never produced. Add a read-only `runningBlock: Block?` (state `.running`, with the open command text, cwd, and `startedAt`, `endedAt = nil`) surfaced while a command is executing (between `C` and `D`, when not suppressed by alt-screen). This is the **only** model change.

**`rowAtC` is explicitly NOT captured here.** Storing a screen row on `Block` would violate the no-coordinates principle and the `Sendable` value-type design; the jump anchor is a P4b concern and will live in a view-adjacent registry when P4b lands. *(This revises the earlier "two-for-one" research note, which is acceptable for jump-anchoring but wrong for the durable data model.)*

### D3 — Grouping: `Tab ▸ Pane`, key window; VM assembled from controllers + the pane tree
The flat `SessionRegistry` is structure-blind (no tab/window grouping, no ordering), so the sidebar view-model is assembled by the window/app coordinator from the live `TerminalWindowController`s and each controller's pane tree (`tree.leaves()`), not from the registry. Add a small public surface to `TerminalWindowController`: ordered panes, pane→`TerminalSession` access, the tab title, and `owns(paneID)`. The sidebar is **per key window** (its tabs and their panes). *Alternative:* one global cross-window list — deferred (more UI + ordering questions, weaker locality); the assembly code can widen to all windows trivially if wanted.

### D4 — Click focuses the pane (never scroll-to-row)
A sidebar row's click calls a new public `focusPane(_ id:)` that wraps the existing private `setActivePane(_:)` and adds `window.makeKeyAndOrderFront(nil)` for the background-tab/window case. Focus only — **no scroll-to-row**, which would require the deferred P4b anchor fork. The coordinator resolves the owning controller via `owns(paneID)`.

### D5 — Event-driven updates + one self-pausing duration timer
Make session/block state observable (`@Observable` on the registry or a dedicated sidebar model, with a revision bump on register/unregister/focus and on each `BlockTracker` transition). The OSC handlers already run on the main actor (P4a's `MainActor.assumeIsolated`, 17 e2e green), so publishing is synchronous — **no marshalling, no global polling**. The only periodic work is the live duration of *running* rows, via a per-row `TimelineView(.periodic(by: 1))` that does no work when nothing is running. *Why:* honors M1/M4 — the sidebar costs nothing when idle.

### D6 — Sidebar hosting: SwiftUI chrome beside the AppKit terminal area
Host the sidebar as an `NSHostingView`/`NSHostingController` in a collapsible left panel (outer `NSSplitView`) of the existing window; the terminal pane-tree `NSSplitView` becomes the trailing panel. The SwiftTerm-black-on-SwiftUI issue does **not** apply — only the terminal view must stay AppKit, and it does. A toolbar/keybinding toggles sidebar visibility.

### D7 — Quick terminal stays out
The sidebar enumerates only the main `SessionRegistry` inventory (per-window controllers); the quake panel's private registry is not enumerated, so it never appears — consistent with its exclusion from the main inventory and quit accounting.

## Risks / Trade-offs

- **[Retain cycles between the SwiftUI VM and AppKit controllers]** → the VM holds weak references to controllers/sessions and reads snapshots; verified with an Instruments leak pass (M4).
- **[Cross-window/tab focus correctness]** → `focusPane` routes through the existing, tested `setActivePane` + `makeKeyAndOrderFront`; covered by an XCUITest that focuses a pane in a background tab.
- **[Sidebar content invisible to accessibility (custom views)]** → assert via the DEBUG state dump (activity + running command), consistent with the harness's engine-grid pattern; screenshots remain the human record.
- **[Activity flicker on rapid command turnover]** → derivation is a pure function of current state; SwiftUI diffing coalesces; the 1 s duration tick is display-only and never drives the state.
- **[Scope creep toward jump/progress]** → explicitly fenced to data-read + UI; jump and OSC 9;4 are separate later changes.

## Open Questions

- **Is `failed` an acceptable proxy for the user's mental "blocked"?** Adopted (xtty has no native needs-human signal); revisit only if true agent-waiting detection is wanted (separate spike).
- **Per-window vs global sidebar** — shipping per-window; widen later if the user wants cross-window glance. (Non-blocking; the VM assembly is the only thing that changes.)
- **Sidebar default visibility + toggle keybinding** — pick a sensible default (visible) and a toggle; confirm during apply.
