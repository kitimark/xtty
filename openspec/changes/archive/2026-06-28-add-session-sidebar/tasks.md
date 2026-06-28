# Tasks — add-session-sidebar (P5)

> Fork-free; reads P4a's `XttyCore` block model. No SwiftTerm fork, no stored screen coordinates. Verify with `swift test` (XttyCore), `xcodebuild build`, and `xcodebuild test` (XCUITests). Treat SourceKit "No such module"/"Cannot find type" diagnostics as stale false-positives — the command-line builds are authoritative. Re-run `xcodegen generate` after adding/removing App/test target source files (not SPM package files).

## 1. XttyCore — running block + activity state (view-free, unit-tested)

- [x] 1.1 Expose the in-flight running block from `BlockTracker`: add a read-only `runningBlock: Block?` (state `.running`, open command text + cwd + `startedAt`, `endedAt == nil`) populated between `C` and `D` and suppressed while on the alternate screen; cleared on `D`. No `rowAtC` / no coordinates added to `Block`.
- [x] 1.2 Add a view-free `SessionActivity` enum (`idle / running / succeeded / failed / fullScreen`) and a pure derivation over a session's blocks + running block + `isAlternateScreen`, with the precedence from design D1 (fullScreen → running → failed → succeeded → idle).
- [x] 1.3 Expose the derived activity on `TerminalSession` (e.g. `activity: SessionActivity`) plus the running command text, reading existing state — no new engine calls.
- [x] 1.4 Unit tests: `runningBlock` appears between C and D and clears on D; running suppressed on alt-screen; `SessionActivity` precedence (each branch); fresh session = idle. All without launching the app.

## 2. XttyCore — observation seam

- [x] 2.1 Make the session/registry model observable (`@Observable` on `SessionRegistry` or a dedicated sidebar model), bumping a revision on register/unregister/focus changes.
- [x] 2.2 Have `BlockTracker` transitions (C/D, alt-screen) publish so an observing UI re-renders; confirm publication happens on the main actor (handlers already run there — no marshalling). Unit-test that a transition bumps the observable revision.

## 3. App — window plumbing for the sidebar

- [x] 3.1 Add a small public surface to `TerminalWindowController`: ordered panes (`tree.leaves()`), pane→`TerminalSession` access, tab title, and `owns(_ paneID:)`.
- [x] 3.2 Add a public `focusPane(_ id:)` wrapping the existing `setActivePane(_:)` + `window.makeKeyAndOrderFront(nil)` for the background-tab/window case. No scroll-to-row.
- [x] 3.3 App/window coordinator: assemble the `Tab ▸ Pane` view-model for the key window from `windowControllers` + each controller's ordered panes; resolve a clicked pane's owner via `owns(_:)` and call `focusPane`. Exclude the quick-terminal private registry. Hold controllers/sessions weakly (no retain cycle).

## 4. App — the SwiftUI sidebar

- [x] 4.1 Build the SwiftUI sidebar view: `Tab ▸ Pane` tree; each pane row shows activity state (icon/color: idle/running/succeeded/failed/fullScreen), last command, and — for running — a live duration via `TimelineView(.periodic(by: 1))` scoped to running rows (no work when idle).
- [x] 4.2 Host the sidebar as an `NSHostingView`/controller in a collapsible left panel (outer `NSSplitView`) with the terminal pane-tree as the trailing panel; the terminal view stays AppKit (SwiftUI-hosting-black caveat does not apply to plain chrome).
- [x] 4.3 Wire row activation → `focusPane`; add a toggle (menu item + keybinding) for sidebar visibility with a sensible default.

## 5. Harness — DEBUG dump + e2e

- [x] 5.1 Extend the DEBUG state dump (`writeStateDump`) for the focused pane with the derived `sessionActivity` and the `runningCommand` text (gated by `#if DEBUG` + `-UITestGridDump`).
- [x] 5.2 Add an XCUITest (injected zsh) asserting via the state dump: a running command shows `activity == running` + the running command text, then `succeeded` after a passing command and `failed` after a failing one. Degrade gracefully if the hook is absent.
- [x] 5.3 Run `xcodegen generate` if App/test sources were added; confirm `swift test` (XttyCore) and `xcodebuild test` (XCUITests) are green.

## 6. Trackers

- [x] 6.1 Tick these checkboxes as work lands; refresh **Current status** in `AGENTS.md` and the Phase 5 state in `research/04-design/02-milestones.md` when the change is complete.
