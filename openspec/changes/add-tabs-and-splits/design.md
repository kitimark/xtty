## Context

xtty's window today is a single god-object: `TerminalWindowController` owns one `LocalProcessTerminalView` as the window's `contentView`, *is* its `LocalProcessTerminalViewDelegate`, and also handles font sizing, the exit policy, the built-in-display placement, and the DEBUG harness dump. `window.tabbingMode = .disallowed`. There is one `XttyCore.TerminalSession` (an observe-only handle on the engine), whose own doc comment already names this milestone: *"the unit that P3 (tabs/splits) will multiply: today one window owns one session; later one window owns N."*

Three findings from reading the SwiftTerm checkout de-risk the structure and shape the decisions below:
1. **Each `LocalProcessTerminalView` owns its own `LocalProcess` (PTY + child + engine + delegate)** — a pane is fully self-contained; nothing is shared between panes.
2. **`setFrameSize → processSizeChange` drives the PTY resize automatically** — panes placed in an `NSSplitView` reflow their shells on divider drag with zero extra wiring.
3. **`becomeFirstResponder → hasFocus=true` / `resignFirstResponder → hasFocus=false`** — per-pane focus (the active caret) follows the first responder for free, even with several panes in one key window.

This change is the **spine** of P3 (layers 1–4: decompose → splits → native tabs/windows → URL links). Quick-Terminal, profiles, and file:line error-matching are a separate follow-up change (`add-shell-ux-extras`); see Non-Goals.

## Goals / Non-Goals

**Goals:**
- Decompose the controller into a reusable per-pane unit and a window/tab owner of a pane tree.
- Native macOS tabs (window tabbing) + multiple windows + custom splits, feeling native and stable.
- A unified close/exit-escalation lifecycle (pane → tab/window → quit) replacing today's "shell exit closes the window."
- Route pane-scoped commands through the responder chain so "the active pane" needs no central tracking for dispatch.
- Clickable `http(s)`/OSC-8 links with a confirmation guard for other schemes.
- A view-free multiplexing model in `XttyCore` that mirrors structure + identity + focus (the thing P5's sidebar and a future agent API will read), plus a pane-aware harness.

**Non-Goals (this change):**
- Quick-Terminal dropdown (global hotkey + nonactivating panel) — `add-shell-ux-extras`.
- Profiles / sectioned config — `add-shell-ux-extras` (grows `terminal-configuration` + couples to `ShellResolver`).
- **file:line error-matching / open-in-editor** — not free in SwiftTerm (its implicit matcher is a private, URL-only regex) and relative-path resolution soft-depends on **P4 OSC 7 cwd**; deferred to `add-shell-ux-extras` or P4.
- A custom/Metal renderer, OSC 133 blocks, the sidebar itself — later phases.

## Decisions

### D1 — Native NSWindow tabs + custom splits (a tab *is* a window)
Adopt macOS native window tabbing (`tabbingMode = .preferred` + a shared `tabbingIdentifier`); splits are custom (`NSSplitView` trees). Each **tab is a full `NSWindow` + its own window controller + pane tree**, grouped visually by macOS.
- **Why:** matches Ghostty (the project's native-feel benchmark); the tab bar, Cmd+Shift+[/], drag-tab-out, and Merge All come free; drag-a-tab-out-to-a-window needs **no state migration** because each tab already *is* its own window+tree.
- **Alternatives:** a fully custom tab bar (Warp-style, one window owns everything) — rejected for this change: more UI to build/polish, and its main payoff (one sidebar spanning all tabs) is a P5 concern. Consequence accepted: **P5's sidebar will be per-window.**
- New tab via the `newWindowForTab(_:)` responder method (what the "+" button and Cmd+T invoke) calling `addTabbedWindow`; new window (Cmd+N) is a window without a matching tabbing group.

### D2 — `PaneController` as the per-view unit
Extract a `PaneController` that owns one `LocalProcessTerminalView` (+ its PTY + `TerminalSession`) and is its `LocalProcessTerminalViewDelegate`. The window controller owns a tree of `PaneController`s, not a single view.
- **Why:** SwiftTerm already makes a pane self-contained (finding 1); the delegate is per-view, so the per-pane delegate is the natural home for `processTerminated`, title, font sizing, and the DEBUG dump. Layer 1 is a mechanical extraction that keeps the harness green before any feature lands.

### D3 — Responder-chain routing for pane-scoped commands
Move font-size (and the new split/close/focus actions) to `target: nil` menu items that travel the key window's responder chain to the focused pane — the way Find/Copy/Paste already work.
- **Why:** eliminates today's `MainMenu → AppDelegate → the one controller` coupling, which is ambiguous with N panes. AppKit's key-window-first-responder *is* the active pane, so dispatch needs no central "active pane." The `XttyCore` registry's focus field is then only for out-of-band consumers (P5 highlight), not command routing.
- **Alternative:** track an `activePane` centrally and target menus at it — rejected as redundant with the responder chain and more error-prone.

### D4 — Split tree: n-ary nodes; we own structure only
Model a window's content as `PaneNode = leaf(Pane) | split(axis, ratios, [children])`, rendered with one `NSSplitView` per split node (n-ary, so "3 panes across" is one node, not nested pairs).
- Geometry (resize → PTY reflow) and focus (caret) are SwiftTerm/NSSplitView's job (findings 2–3); we own only the tree shape.
- **Collapse rule on close:** a split node dropping to a single child is removed and its survivor promoted to the grandparent (or becomes the tab root). Focus-follow on close = the spatial neighbor (simpler, predictable).

### D5 — One escalation path for close & exit
Both a shell exiting (process-driven) and a user close command (Cmd+W) resolve through the same rule: close the focused/affected pane → collapse → if it was the last pane, close the tab/window → if it was the last window, quit. A configurable `confirm-close` guards a pane running a foreground process (default on, like Terminal.app). This replaces exit policy A. Because a tab is a window (D1), `applicationShouldTerminateAfterLastWindowClosed = true` still yields correct quit-on-last semantics.

### D6 — View-free model in `XttyCore`
Add `Pane` (wraps the existing `TerminalSession`), `PaneNode` (the split tree, view-free), and a `SessionRegistry` (all live panes across windows + the focused pane id). The AppKit tree is the source of truth for geometry; `XttyCore` mirrors structure + identity + focus.
- **Why:** preserves the load-bearing seam (logic talks to the engine via `XttyCore`, never the view) and keeps the L3→L1 escape hatch contained; gives P5/P4/agent-API one model to enumerate; unit-testable without the app.

### D7 — Links: surface SwiftTerm + guard
`http(s)`/OSC-8 detection, hover highlight, and open-on-click are already wired (`requestOpenLink` defaults to `NSWorkspace.open`). Override `requestOpenLink` to add the guard: open `http(s)` directly; for any other scheme, confirm first; never execute clicked text. (SwiftTerm's implicit matcher is URL-only and private — file:line is out of scope, see Non-Goals.)

### D8 — Pane-aware harness
The grid dump follows the **focused pane** (one fixed path, e2e drives the focused pane). The DEBUG state dump gains a multiplexing inventory (pane count, focused pane, tab count, per-pane cols/rows). New XCUITests assert split/close/focus/new-tab/new-window and link resolution; a DEBUG "resolve link at (row,col)" action lets tests check matching without real hit-testing.

## Risks / Trade-offs

- **Native-tab termination accounting** (a tab == a window) → keep `applicationShouldTerminateAfterLastWindowClosed = true`; verify last-tab-closes and last-window-quits in the harness. (Becomes more delicate once `add-shell-ux-extras` adds a quick-term panel, which is why that's deferred.)
- **Split-tree collapse correctness** (orphaned/empty regions, wrong survivor promotion) → keep the model in `XttyCore` with unit tests for split/close/collapse independent of views; harness asserts no empty region.
- **P5 sidebar becomes per-window** (consequence of D1) → accepted and documented now so P5 isn't surprised; the `SessionRegistry` still tracks all sessions globally if a cross-window view is ever wanted.
- **Per-pane focus indication across splits in one key window** relies on SwiftTerm's `hasFocus` (finding 3) → verified in code; covered by a focus-navigation test.
- **Harness determinism with N panes** → the focused-pane grid dump + inventory state dump (D8) keep assertions deterministic; document that the grid dump tracks the focused pane.

## Migration Plan

Incremental, each step buildable and harness-green:
1. **Decompose** → `PaneController` + `XttyCore` model (`Pane`/`PaneNode`/`SessionRegistry`); behavior identical to today (one window, one pane). Re-route font-size to the responder chain (D3).
2. **Splits** → split H/V, close+collapse, directional focus, divider resize; pane-aware harness dump (D8) + unit tests for the tree.
3. **Native tabs + windows** → flip `tabbingMode`, set `tabbingIdentifier`, `newWindowForTab`/Cmd+T/Cmd+N; unify close/exit escalation (D5); harness tab/window tests.
4. **URL links** → `requestOpenLink` guard (D7) + link-resolution test.

Rollback is per-step (each is an isolated commit); no persisted state or data migration is involved.

## Open Questions

- **Default keybindings** (configurable later): proposed Cmd+D = split vertical (side-by-side), Cmd+Shift+D = split horizontal (stacked), Cmd+Opt+arrows = directional focus, Cmd+T/Cmd+N = new tab/window, Cmd+W = escalating close. Confirm at apply time.
- **`confirm-close` config key** name/default — proposed default **on**; the key formally lands with the profiles/config work in `add-shell-ux-extras`, so in this change it can be a built-in default with a constant.
- **n-ary vs strictly-binary split nodes** — design assumes n-ary; revisit only if `NSSplitView` arrangement proves awkward.
