## 1. Injectable accessor seam (build now, no SwiftTerm mechanism)

- [x] 1.1 Define the accessor seam in the App layer — a protocol/closure `ScrollCoordinateReading { scrollInvariantRow() -> Int?; scrollbackBase() -> Int? }` (or equivalent), with a **production implementation that returns `nil`** (so the feature no-ops gracefully); wire `PaneController` to read through it
- [x] 1.2 Add a **fake** seam for tests returning synthetic rows, so the full happy path (capture → invalidate → reverse-map → prev/next → jump/copy range) is exercisable without any SwiftTerm change; `SwiftTerm` pin stays `from: "1.13.0"` unchanged
- [x] 1.3 Author the eventual `XttyAccessors.swift` content as a committed artifact in xtty (the drop-in file: `public extension Terminal` with `getScrollInvariantCursorLocation()` = `Position(col: buffer.x, row: buffer.yBase + buffer.y + buffer.linesTop)`, doc-noting the `getCursorLocation` yBase-relative trap, + `var scrollbackBase: Int { buffer.linesTop }`) — not yet compiled, ready for Phase 2

## 2. XttyCore — anchor model + invalidation (view-free, unit-tested)

- [x] 2.1 Add `BlockAnchor { epoch; promptRow?; outputStart?; outputEnd? }` (Sendable) and an optional anchor on `Block`; expose the running block's `outputStart`; keep all existing coordinate-free `Block` fields/initializers and invariants unchanged
- [x] 2.2 Extend `BlockTracker` to accept a captured absolute row at each of `A`/`C`/`D` and stamp it with the current epoch onto the block's anchor; skip capture while the alternate screen is active; keep capture optional (nil row → no anchor)
- [x] 2.3 Add the epoch + invalidation API to the per-session model: `bumpEpoch()` (dead-stamps all prior anchors), a `liveTop` high-water tracker that bumps the epoch on a drop, and an `anchorIsValid(_:)` check; all pure/view-free
- [x] 2.4 Add the reverse-map (`displayRow = absoluteRow − scrollbackBase`, with a "trimmed out" result when below the floor) and the previous/next-block target selection over the session block list, as pure functions
- [x] 2.5 Unit tests: anchor capture/skip-on-alt, epoch invalidation (resize bump + liveTop drop), reverse-map incl. trimmed-out, prev/next selection incl. ends and all-invalid; confirm the existing 134 XttyCore tests still pass

## 3. XttyCore — keybinding actions

- [x] 3.1 Add `jumpPrevPrompt` / `jumpNextPrompt` / `copyCommandOutput` to the `KeyAction` enum (raw values `jump-prev-prompt` / `jump-next-prompt` / `copy-command-output`)
- [x] 3.2 Add default chords to both presets: `jump-prev-prompt = Cmd+Shift+Up`, `jump-next-prompt = Cmd+Shift+Down`, and a copy chord; add the `cmdShift(_:KeyToken)` arrow helper as needed; unit-test that the new actions resolve in both presets and honor `keybind-<action>` overrides

## 4. App — anchor capture + invalidation wiring

- [x] 4.1 In the OSC-133 handler in `PaneController`/`TerminalSession`, capture the scroll-invariant cursor row **through the seam** (`scrollInvariantRow()`) synchronously at `A`/`C`/`D` and pass the `Int?` to `BlockTracker` (main-actor); `nil` → no anchor (production today)
- [x] 4.2 Fill the empty `PaneController.sizeChanged(source:newCols:newRows:)` stub to hop to the main actor and `bumpEpoch()` for that session; sample `liveTop` (derived from the seam) on the `scrolled` delegate and bump on a high-water drop
- [x] 4.3 Confirm the `LinkRoutingTerminalDelegate` proxy still forwards `sizeChanged`/`scrolled` unchanged (no regression to P4b-1)

## 5. App — jump-to-prompt

- [x] 5.1 Add `jumpToPrompt(previous:)` on `PaneController`: pick the prev/next target (group 2.4), validate the anchor, reverse-map, and call the public `view.scrollTo(row:)`; no-op gracefully when no valid target; never move cursor/selection
- [x] 5.2 Wire menu items + `@objc` selectors + validate-whitelist for the two jump actions through the existing keybind→menu pipeline; route to the active pane

## 6. App — copy-command-output + toast

- [x] 6.1 Add `copyCommandOutput()` on `PaneController`: resolve the target block (focused/last completed, or running), validate the anchor, reverse-map `[outputStart … outputEnd]` (running → `… currentCursorRow`) to `Position`s, `getText(start:end:)` → `NSPasteboard`; exclude the trailing prompt; no-op on invalid/trimmed anchor
- [x] 6.2 Add a transient non-modal confirmation (flash/toast) shown on copy success and on a no-op indication; ensure it never blocks input
- [x] 6.3 Wire the copy menu item + `@objc` selector + validate-whitelist + active-pane routing

## 7. Harness — DEBUG dump + Phase-1 e2e (degradation)

- [x] 7.1 Add `lastJumpTargetRow` and `lastCopiedOutput` to the DEBUG state dump (`#if DEBUG` + `-UITestGridDump`), set on jump/copy (no-op recorded as such); add the in-process DEBUG trigger to drive jump/copy (mirroring the P4b-1 link trigger)
- [x] 7.2 Phase-1 e2e (seam returns `nil`): assert jump/copy via the trigger record a **graceful no-op** in the dump (no jump target / no copied output), and the post-resize case stays a no-op; run the full `xcodebuild test` UI suite green
- [x] 7.3 Confirm the happy path is covered now at the unit/integration level via the fake seam (group 2.5 / 5 / 6), since the real-zsh happy-path e2e is gated on Phase 2 light-up

## 8. Phase 2 — light up (deferred; the chosen mechanism)

- [x] 8.1 Stand up the leading mechanism: add `migueldeicaza/SwiftTerm` as a submodule pinned to `v1.13.0`; add the prepare step that drops `XttyAccessors.swift` (group 1.3) into its `Sources/SwiftTerm/`; switch `XttyCore/Package.swift:23` to `.package(path: "../external/SwiftTerm")`; `swift package resolve`; reset DerivedData package caches; `xcodegen generate` (or vendor-in-tree / fork as the reversible alternative — finalize per the strategy research doc)
- [x] 8.2 Swap the **production** seam body to the real engine reads (`getScrollInvariantCursorLocation().row` / `scrollbackBase`) — ~2 lines in the `PaneController` bridge
- [x] 8.3 Add the real-injected-zsh happy-path e2e: jump resolves to an earlier prompt; copy captures a known command's output excluding the prompt; **including the scrolled-up correctness case**; run the empirical `clear; <flood>` masking check and decide whether the in-engine `resetGeneration` counter is needed
- [ ] 8.4 File the upstream PR mirroring `getScrollInvariantLine`; link it for later retirement of the local mechanism

## 9. Verification + docs/trackers (pre-archive)

- [x] 9.1 Run `swift test` (XttyCore) and the full app + UI test suites; record the green counts
- [x] 9.2 Update `research/03-analysis/p4b-2-spatial-blocks-decisions.md` (mark spikes 1/3/copy-semantics resolved) and `research/03-analysis/swiftterm-fork-vs-patch-strategy.md` (record the chosen mechanism) and `research/04-design/02-milestones.md` (P4b-2 state); refresh **Current status** in `AGENTS.md`
- [x] 9.3 `openspec validate add-spatial-blocks`; confirm ready to archive (archive only after Phase 2 — the spec'd behavior is live, not just no-opping)
