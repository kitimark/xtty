## Context

P5 shipped a `Tab ▸ Pane` session sidebar (`App/SessionSidebar.swift`) showing each pane's current activity + last command, click-to-focus (focus only, never scroll). P4b-2 shipped the spatial-block machinery: optional best-effort `BlockAnchor`s on each `Block`, `BlockNavigation` (reverse-map + prev/next + copy-range), epoch invalidation, and the App-side calls (`PaneController.validPromptRows`, `jumpToPrompt`, `copyCommandOutput`, `view.scrollTo(row:)`) over the engine accessors vendored via the pinned SwiftTerm checkout. P4b-3 is the **random-access invocation surface** over that machinery: a clickable per-command-block list under each pane. The `p4b-3` explore + external research ([P4b-3 addendum](../../../research/03-analysis/p4b-2-spatial-blocks-decisions.md#addendum-2026-06-29--p4b-3-reframe-the-clickable-block-sidebar-the-d3-no-one-does-this-premise-is-overturned)) overturned the "no keyboard-first terminal does this" premise (iTerm2's Toolbelt does), validated xtty's invalidation model as the leaner equivalent of iTerm2's eager recompute, and surfaced two tensions this design must answer: stale targets in a *persistent* list, and the unbounded `blocks` array.

> **Adversarially reviewed (2026-06-29, pre-apply):** a 16-agent review (3 dimensions → per-finding refutation) confirmed 9 findings; all are folded in below. The two majors that reshaped this design: (1) the "usable anchor" predicate had to be a **live engine check**, not `anchorIsValid` alone — a normal scrollback trim grows `scrollbackBase` *without* bumping the epoch, so an epoch-valid anchor can still be trimmed out (D3); (2) the snapshot only refreshes on `SessionRegistry.revision`, which a resize does **not** bump — so dimming must be wired to epoch invalidation (D6).

## Goals / Non-Goals

**Goals:**
- A per-pane, expandable list of recent command blocks in the existing sidebar (`Tab ▸ Pane ▸ Block`).
- Selecting a block focuses its pane and scrolls the viewport to it (absolute random access — the sibling of P4b-2's relative keyboard jump).
- A per-block context menu: Copy output, Copy command, Reveal working dir.
- Graceful, *visible*, **correct** stale handling: a block whose target is unreachable (epoch-stale or trimmed out) stays an informational record but dims its jump/copy actions.
- Bound the per-session block history so rendering it doesn't depend on an unbounded array (lean-memory).
- Fully fork-free (reuse the already-vendored P4b-2 accessors) and harness-observable.

**Non-Goals:**
- **No command re-run** (no iTerm2-style double-click-to-type) — re-executing a captured command risks a destructive action; deliberately omitted (revisit on demand).
- No Tier-2 on-screen visual selection (still P7/fork-the-view-gated, untouched).
- No new config key in this cut — the history cap + display ordering are fixed constants (configurability is a trivial later add).
- No change to keybindings or the default layout — keyboard stays the primary jump/copy surface; this is a secondary surface inside the already-collapsible sidebar.
- Not a project file browser (that's the rejected P6b Scope B).

## Decisions

### D1 — Per-pane `DisclosureGroup`; a pane with no blocks stays a plain row
Each pane row that **has at least one block** (a finished block or a running one) becomes an expandable `DisclosureGroup` (collapsed by default), revealing that pane's recent blocks — `Tab ▸ Pane ▸ Block`. A pane with **no captured blocks** (a fresh shell, an uncooperative/no-integration host, or one that has only run alt-screen apps) renders as the existing plain P5 pane row with **no disclosure chevron** — so "no visual change until you expand" stays honest and the sidebar stays quiet. **Why disclosure:** consistent with the shipped `GitReviewView` recursive-disclosure pattern and a *collapsed*-set default; any pane's history is reachable without changing focus first. **Alternative rejected:** an "active-pane-only" detail region below the flat pane tree — simpler nesting, but you must focus a pane to see its history and it adds a second layout region.

### D2 — Selection = focus (via the coordinator) + absolute scroll-to-block
Selecting a block invokes a new `selectBlock(paneID, target)` at the **coordinator level**, mirroring the existing sidebar `onActivate` wiring. The focus half routes through the coordinator's `focusPane(id)` (`XttyApp.swift` resolves the **owning** window controller, then that controller's `focusPane`, which does `setActivePane` **and** `window.makeKeyAndOrderFront(nil)`) — **not** `setActivePane` directly, which is private and focus-only and brings nothing forward (review finding). That correctly switches to a background tab/window. Then it scrolls the now-frontmost pane's viewport via that `PaneController`'s new scroll-to-block. The scroll is **absolute scroll-to-a-designated-block**, the new sibling of `jumpToPrompt`'s relative prev/next: resolve the block's `anchor.promptRow` via `BlockNavigation.displayRow(forAbsolute:scrollbackBase:)` and call the already-public `view.scrollTo(row:)`. No cursor move, no selection — viewport only. **No new fork surface** — the engine accessors (`scrollbackBase`, `getScrollInvariantCursorLocation`) already exist.

### D3 — "Actionable" is a LIVE engine check, not `anchorIsValid` alone
A block's *informational* content — command, status glyph, duration, cwd — is durable P4a data needing no anchor. Its *actions* (scroll-to, copy-output) need a target that actually resolves **now**. The naive predicate `anchor != nil && anchorIsValid` is **insufficient** (review finding, high-confidence): a normal scrollback trim advances `scrollbackBase` (`linesTop`) **without** bumping the epoch (`bumpEpoch` fires only on resize/reflow; `noteLiveTop` only on a clear/reset high-water *drop*) — so a block whose prompt has scrolled out of bounded scrollback stays `anchorIsValid == true`, yet at click time `BlockNavigation.displayRow` returns `.trimmedOut` (jump would clamp to row 0, copy would silently no-op). That is exactly the "long agent session" case this feature targets. So **`isActionable` is computed at snapshot time against the live engine**:

```
isActionable(block) =
   block.anchor != nil
   && tracker.anchorIsValid(block.anchor)
   && block.anchor.promptRow != nil
   && displayRow(promptRow, engineScrollbackBase()) == .row       // not .trimmedOut
   // copy-output additionally requires outputRowRange's start & end to resolve to .row
```

This is the App layer's job (`PaneController` already exposes `engineScrollbackBase()`); `validPromptRows` deliberately *omits* the trim check because the keyboard jump *tolerates* trim by clamping — the sidebar's persistent list cannot, so it must dim. The two predicates are intentionally different; the design no longer claims to "reuse validPromptRows's exact predicate."

### D4 — Context menu: Copy output / Copy command / Reveal cwd, with a DEBUG-safe reveal
`copyCommandOutput` currently targets "the running or last completed block." Generalize the engine-only copy (`getText` over `BlockNavigation.outputRowRange`) to a **designated target**, exposed as `copyOutput(of target:)`; it dims when the target isn't actionable (D3). **Copy command** writes the block's `command` string (anchor-free) to the clipboard. **Reveal working dir** opens the block's captured `cwd` (anchor-free); it is **disabled when `cwd` is nil** (no OSC 7 / no profile cwd) and benignly no-ops on a missing/remote path. Because reveal has an external side effect (Finder), it follows the established P4b-1 link-open pattern: the actual `NSWorkspace.open` is **skipped on the DEBUG/test path**, which instead **records** the resolved directory — so tests never pop Finder. Copy-command and reveal both record into a DEBUG `lastBlockMenuAction` dump field (D7). The existing `Cmd+Shift+C` keyboard copy is unchanged.

### D5 — Bound the block history (lean-memory), display newest-first
`BlockTracker` caps its retained `blocks` at a fixed constant (default ~1000; drop oldest beyond it), preserving most-recent ordering and never affecting the separately-exposed `runningBlock`. **Why a cap at all:** rendering history makes the previously-unbounded append load-bearing; bounding it honors the lean-memory product value (symmetric with bounded scrollback). The sidebar renders the stored (already-bounded) blocks for an expanded pane, **newest-first**, via SwiftUI's lazy list — so display count == storage cap (no second cap, no unreachable middle). The cap is a constant for now; exposing it as config is a trivial follow-up.

### D6 — Snapshot extension + refresh on epoch invalidation
The sidebar recomputes a value snapshot when `@Observable SessionRegistry.revision` bumps (P5). Extend `SidebarPaneItem` with `blocks: [SidebarBlockItem]` (id, command, state, started/ended, **isRunning** as the running-block discriminator, **isActionable**, and an **optional** `blockIndex` — nil for the running row). `TerminalWindowController`'s provider folds `session.blocks.blocks` **plus the separate `runningBlock` as the newest row**, newest-first, computing each block's `isActionable` via the owning `PaneController`'s **live** check (D3, reads `engineScrollbackBase()` per block — cheap: only the expanded pane's bounded list renders).

**Crucially, the refresh must fire on epoch invalidation, not only block-state transitions** (review finding, high-confidence): `SessionRegistry.revision` is bumped only by register/unregister/setFocus/`noteActivityChange`, while a resize bumps the anchor epoch in `PaneController.sizeChanged` via `bumpEpoch()` **without** touching the registry — so without wiring, the list would keep showing stale-enabled actions after a resize. Fix: after `session.blocks.bumpEpoch()` in `sizeChanged`, call `registry.noteActivityChange()`; and in the scroll path, call it **only when `noteLiveTop` actually bumped** the epoch (signal it via a return value / epoch comparison — never per scroll tick, which would thrash). A block trimmed purely by output volume *between* marks may briefly show enabled until the next mark or epoch change refreshes the snapshot — acceptable best-effort, and the at-use check still prevents acting on wrong content. No new observable or timer; the per-running-row live duration reuses the existing `TimelineView` tick.

### D7 — Harness: a per-block usability flag, reuse of the spatial fields, a menu-action field, a DEBUG select trigger
The state dump already exposes the focused pane's block list and the `lastJumpTargetRow`/`lastCopiedOutput` spatial fields. Selecting a block routes through the same scroll/copy, so those fields already capture sidebar-triggered scroll (`lastJumpTargetRow` now also covers a designated-block scroll) + copy-output. Add: (a) per dumped block, whether it currently has a **usable jump/copy anchor** (the live D3 check), so stale-dimming is assertable; (b) a **`lastBlockMenuAction`** field recording copy-command (the command text) and reveal (the resolved dir) so those menu actions are observable without a real clipboard/Finder. Drive selection in the e2e through a DEBUG-only "select block N (or the running block) in the focused pane, optionally invoking a menu action" trigger (mirroring the link-open / quick-terminal DEBUG triggers) so the test is deterministic and doesn't hit-test dynamic SwiftUI rows. The e2e asserts the **trimmed arm distinctly from the epoch-stale (resize) arm**, since the trim bug is invisible to a resize-only test.

## Risks / Trade-offs

- **[Resize must dim the whole list]** → Wired in D6 (`noteActivityChange()` on epoch bump). After any resize the snapshot recomputes and every block's jump/copy dims until new commands run; rows stay useful as records. Matching iTerm2's live-across-resize behavior isn't worth a fork-the-engine recompute for a secondary surface.
- **[Trimmed-but-epoch-valid blocks]** → D3's live `displayRow != .trimmedOut` check dims them; without it they'd render enabled and clamp-to-top / silently no-op. A block trimmed between marks may lag one refresh (accepted; at-use check keeps it correct).
- **[Running block addressing]** → The running block is not an element of `blocks`; selection uses a target descriptor (`running | index(Int)`), resolving `running` via `tracker.runningBlock` and copying via `outputRowRange(liveEnd: engineScrollRow())`, mirroring the keyboard copy.
- **[History cap drops old blocks]** → A block older than the cap can't be reached from the sidebar. Acceptable and consistent with bounded scrollback (its anchor would be trimmed out anyway); the cap is generous (~1000).
- **[Empty / long lists]** → Empty panes show no chevron (D1); SwiftUI lazy rendering + collapsed-by-default keeps an idle/most-panes-collapsed sidebar cheap.
- **[Reveal-cwd side effect in tests]** → Guarded DEBUG no-op (D4) records the resolved dir instead of opening Finder.
- **[New sidebar closures]** → must be `[weak self]`/`[weak controller]` (consistent with the just-shipped lifecycle-census pass); covered by a task.

## Migration Plan

Additive only. `BlockTracker` gains a bounded cap (existing block/anchor tests stay green; add cap tests). The sidebar gains disclosure + block rows behind the existing toggle; collapsed-by-default and the no-chevron-when-empty rule mean no visual change until a user expands a pane with blocks. No config migration, no fork change, no keybinding change. **At archive**, hand-edit two established-spec `Purpose` blocks the deltas can't touch: `session-sidebar` (drop the blanket "focus only, never scroll-to-row" — distinguish pane-row click from block-row select) and `terminal-spatial-blocks` (soften "a clickable per-block sidebar" from out-of-scope now that the designated-block scroll primitive serves it).

## Open Questions

- **History cap value** — ~1000 is the starting constant; tune if memory profiling or UX suggests otherwise (report-only, not gated). Resolved-enough to implement.
- **Trimmed-history footer** — whether to show an explicit "older not shown" affordance when the cap was hit; treat as a best-effort nicety, drop if it complicates the disclosure.
