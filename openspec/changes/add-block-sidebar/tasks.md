## 1. XttyCore — bounded block history + epoch-change signal

- [ ] 1.1 Add a fixed-maximum cap to `BlockTracker` so the retained `blocks` list drops its oldest entries beyond the cap (default ~1000), preserving newest-first ordering and never affecting the separately-exposed `runningBlock`.
- [ ] 1.2 Unit tests: history stays ≤ cap under more-than-cap commands; the most-recent blocks + ordering are preserved; the running block is unaffected by trimming; existing block/anchor tests stay green.
- [ ] 1.3 Make epoch invalidation observable to the App: have `noteLiveTop` signal whether it actually bumped the epoch (return a Bool / expose `currentEpoch`) so the App can refresh the sidebar only on a *real* invalidation, not every scroll tick. Unit-test the signal.

## 2. App — PaneController designated-block operations (descriptor-based)

- [ ] 2.1 `scrollToBlock(_ target:)` where `target` is a `running | index(Int)` descriptor — resolve `running` via `tracker.runningBlock` (else `tracker.blocks[index]`), reverse-map `anchor.promptRow` via `BlockNavigation.displayRow(forAbsolute:scrollbackBase:)`, `view.scrollTo(row:)` (viewport only); graceful no-op (recording `lastJumpTargetRow = nil`) when not actionable.
- [ ] 2.2 `copyOutput(of target:)` reusing `BlockNavigation.outputRowRange` (+ `liveEnd: engineScrollRow()` for the running block) + engine `getText` → clipboard + toast; default keyboard `copyCommandOutput` keeps targeting last/running.
- [ ] 2.3 `copyCommand(of target:)` — write the block's `command` to the clipboard; record it for the harness (§5.2).
- [ ] 2.4 `revealWorkingDirectory(of target:)` — open the block's captured `cwd` in Finder via `NSWorkspace`; **disabled when `cwd` is nil**; the `NSWorkspace.open` is **skipped on the DEBUG/test path** (record the resolved dir instead — §5.2) so tests never pop Finder; benign no-op on a missing/remote path.
- [ ] 2.5 `isBlockActionable(_ target:)` — the **live** check (not `validPromptRows`): `anchor != nil && tracker.anchorIsValid(anchor) && anchor.promptRow != nil && displayRow(promptRow, engineScrollbackBase()) == .row`; for copy-output additionally require `outputRowRange`'s start & end to resolve to `.row`. Used by the snapshot + dump.

## 3. App — sidebar block snapshot model + refresh wiring

- [ ] 3.1 Define `SidebarBlockItem` (id, command, state, startedAt, endedAt, **isRunning** discriminator, **isActionable**, **optional** `blockIndex` — nil for the running row) and add `blocks: [SidebarBlockItem]` to `SidebarPaneItem`.
- [ ] 3.2 Build the per-pane block snapshot in `TerminalWindowController`'s tabs provider: fold `session.blocks.blocks` plus the separate `runningBlock` as the newest row, newest-first, with each block's `isActionable` from the owning `PaneController`'s live `isBlockActionable` (§2.5) — event-driven off the existing registry revision (no new observable/timer).
- [ ] 3.3 Wire the snapshot to refresh on anchor-epoch invalidation: call `registry.noteActivityChange()` after `session.blocks.bumpEpoch()` in `PaneController.sizeChanged`, and from the scroll path only when `noteLiveTop` actually bumped (§1.3) — so dimming updates after a resize/clear without thrashing per scroll tick.

## 4. App — sidebar disclosure UI + interactions

- [ ] 4.1 Render a pane row **with ≥1 block** as a `DisclosureGroup` (collapsed-by-default set, per the GitReviewView idiom) revealing the pane's block rows (status glyph + command + duration; live `TimelineView` tick while running); a pane with **no blocks** stays a plain, non-expandable row (no chevron).
- [ ] 4.2 Wire block-row selection at the **coordinator** level (mirroring the existing `onActivate`): `selectBlock(paneID, target)` routes focus through the coordinator's `focusPane(id)` (owning-controller resolution + `makeKeyAndOrderFront`) then `scrollToBlock(target)` on that pane; new closures are `[weak]`.
- [ ] 4.3 Per-block context menu: Copy output / Copy command / Reveal working dir → the PaneController ops; **disable (dim) Scroll-to + Copy-output for non-actionable blocks**, keep Copy-command enabled, and Reveal-working-dir enabled only when `cwd` is non-nil.
- [ ] 4.4 Confirm collapsed-by-default + the no-chevron-when-empty rule mean no visual change until expanded, and the sidebar toggle / quick-terminal exclusion still hold.

## 5. Harness — observability

- [ ] 5.1 Extend the DEBUG state dump's command-block list so each block reports whether it currently has a usable jump/copy anchor (the live `isBlockActionable` result).
- [ ] 5.2 Add a `lastBlockMenuAction` dump field (kind = copy-command/reveal + resolved value); copy-command records the command text, reveal records the resolved directory **without** opening Finder on the test path.
- [ ] 5.3 Add a DEBUG-only "select block N (or the running block) in the focused pane, optionally invoking a menu action" trigger (launch-env / hidden action, mirroring the link-open / quick-terminal DEBUG triggers) routing through the real `selectBlock`/`copyOutput`/`copyCommand`/`reveal` paths so `lastJumpTargetRow`/`lastCopiedOutput`/`lastBlockMenuAction` are set.

## 6. Harness — end-to-end tests

- [ ] 6.1 Block-sidebar e2e (injected zsh): run several commands, select an earlier block via the DEBUG trigger → assert the focused pane + a resolved scroll target row; copy a designated block's output → assert `lastCopiedOutput` contains it without the trailing prompt; select the **running** block → assert a scroll target + copied output-so-far.
- [ ] 6.2 Two stale arms: **epoch** — resize → assert each dumped block non-actionable and selecting one no-ops (no scroll target); **trimmed** — a block whose row scrolled out of bounded scrollback (epoch still valid) → assert non-actionable + no-op, distinct from the resize case.
- [ ] 6.3 Menu actions: copy-command → assert `lastBlockMenuAction` reports the command text; reveal → assert it reports the resolved directory and no Finder window opened.

## 7. Validate, build, verify, reconcile

- [ ] 7.1 `openspec validate add-block-sidebar --strict` passes.
- [ ] 7.2 `make build-core` + `make test-core` green (incl. the new cap + epoch-signal tests).
- [ ] 7.3 `make build` + `make test` green (XCUITests incl. the new block-sidebar e2e); confirm a Release build compiles (DEBUG dump/trigger compile out cleanly).
- [ ] 7.4 Reconcile trackers on completion: AGENTS **Current status** + the milestones P4b-3 bullet (reframed → implemented), per the capture-and-reconcile workflow.
- [ ] 7.5 At archive, hand-edit the two established-spec `Purpose` blocks the deltas can't touch: `session-sidebar` (replace the blanket "focus only, never scroll-to-row" — distinguish pane-row click from block-row select) and `terminal-spatial-blocks` (soften "a clickable per-block sidebar" out-of-scope now that the designated-block scroll primitive serves it).
