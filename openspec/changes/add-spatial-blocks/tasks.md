## 1. SwiftTerm fork + dependency repoint

- [ ] 1.1 Fork `migueldeicaza/SwiftTerm` → `kitimark/SwiftTerm` from the `v1.13.0` tag; add a new file `Sources/SwiftTerm/XttyAccessors.swift` with `public extension Terminal` exposing `getScrollInvariantCursorLocation() -> Position` (`Position(col: buffer.x, row: buffer.yBase + buffer.y + buffer.linesTop)`, doc-noting the `getCursorLocation` yBase-relative trap) and `var scrollbackBase: Int { buffer.linesTop }`; do not edit any existing SwiftTerm file; push and record the commit SHA
- [ ] 1.2 Repoint `XttyCore/Package.swift` SwiftTerm dependency from `from: "1.13.0"` to `.package(url: "https://github.com/kitimark/SwiftTerm.git", revision: "<sha>")`; run `swift package resolve` (regen `Package.resolved`); reset stale DerivedData package caches; `xcodegen generate`; confirm `swift build` (XttyCore) and an app build pick up the fork
- [ ] 1.3 File an upstream PR to SwiftTerm adding the two accessors (mirroring the public `getScrollInvariantLine`); link it in the change for later retirement of the fork

## 2. XttyCore — anchor model + invalidation (view-free, unit-tested)

- [ ] 2.1 Add `BlockAnchor { epoch; promptRow?; outputStart?; outputEnd? }` (Sendable) and an optional anchor on `Block`; expose the running block's `outputStart`; keep all existing coordinate-free `Block` fields/initializers and invariants unchanged
- [ ] 2.2 Extend `BlockTracker` to accept a captured absolute row at each of `A`/`C`/`D` and stamp it with the current epoch onto the block's anchor; skip capture while the alternate screen is active; keep capture optional (nil row → no anchor)
- [ ] 2.3 Add the epoch + invalidation API to the per-session model: `bumpEpoch()` (dead-stamps all prior anchors), a `liveTop` high-water tracker that bumps the epoch on a drop, and an `anchorIsValid(_:)` check; all pure/view-free
- [ ] 2.4 Add the reverse-map (`displayRow = absoluteRow − scrollbackBase`, with a "trimmed out" result when below the floor) and the previous/next-block target selection over the session block list, as pure functions
- [ ] 2.5 Unit tests: anchor capture/skip-on-alt, epoch invalidation (resize bump + liveTop drop), reverse-map incl. trimmed-out, prev/next selection incl. ends and all-invalid; confirm the existing 134 XttyCore tests still pass

## 3. XttyCore — keybinding actions

- [ ] 3.1 Add `jumpPrevPrompt` / `jumpNextPrompt` / `copyCommandOutput` to the `KeyAction` enum (raw values `jump-prev-prompt` / `jump-next-prompt` / `copy-command-output`)
- [ ] 3.2 Add default chords to both presets: `jump-prev-prompt = Cmd+Shift+Up`, `jump-next-prompt = Cmd+Shift+Down`, and a copy chord; add the `cmdShift(_:KeyToken)` arrow helper as needed; unit-test that the new actions resolve in both presets and honor `keybind-<action>` overrides

## 4. App — anchor capture + invalidation wiring

- [ ] 4.1 In the OSC-133 handler in `PaneController`/`TerminalSession`, capture `view.getTerminal().getScrollInvariantCursorLocation().row` synchronously at `A`/`C`/`D` and pass it to `BlockTracker` (main-actor)
- [ ] 4.2 Fill the empty `PaneController.sizeChanged(source:newCols:newRows:)` stub to hop to the main actor and `bumpEpoch()` for that session; sample `liveTop` on the `scrolled` delegate and bump on a high-water drop
- [ ] 4.3 Confirm the `LinkRoutingTerminalDelegate` proxy still forwards `sizeChanged`/`scrolled` unchanged (no regression to P4b-1)

## 5. App — jump-to-prompt

- [ ] 5.1 Add `jumpToPrompt(previous:)` on `PaneController`: pick the prev/next target (group 2.4), validate the anchor, reverse-map, and call the public `view.scrollTo(row:)`; no-op gracefully when no valid target; never move cursor/selection
- [ ] 5.2 Wire menu items + `@objc` selectors + validate-whitelist for the two jump actions through the existing keybind→menu pipeline; route to the active pane

## 6. App — copy-command-output + toast

- [ ] 6.1 Add `copyCommandOutput()` on `PaneController`: resolve the target block (focused/last completed, or running), validate the anchor, reverse-map `[outputStart … outputEnd]` (running → `… currentCursorRow`) to `Position`s, `getText(start:end:)` → `NSPasteboard`; exclude the trailing prompt; no-op on invalid/trimmed anchor
- [ ] 6.2 Add a transient non-modal confirmation (flash/toast) shown on copy success and on a no-op indication; ensure it never blocks input
- [ ] 6.3 Wire the copy menu item + `@objc` selector + validate-whitelist + active-pane routing

## 7. Harness — DEBUG dump + e2e

- [ ] 7.1 Add `lastJumpTargetRow` and `lastCopiedOutput` to the DEBUG state dump (`#if DEBUG` + `-UITestGridDump`), set on jump/copy (no-op recorded as such); add the in-process DEBUG trigger to drive jump/copy (mirroring the P4b-1 link trigger)
- [ ] 7.2 New XCUITest on an injected zsh: run several commands, assert jump-to-previous resolves to an earlier prompt; assert copy captures a known command's output excluding the prompt
- [ ] 7.3 Add the scrolled-up correctness case and the post-resize graceful-degradation (no-op) case; run the full `xcodebuild test` UI suite green

## 8. Verification + docs/trackers (pre-archive)

- [ ] 8.1 Run `swift test` (XttyCore) and the full app + UI test suites; record the green counts
- [ ] 8.2 Update `research/03-analysis/p4b-2-spatial-blocks-decisions.md` (mark spikes 1/3/copy-semantics resolved) and `research/04-design/02-milestones.md` (P4b-2 state); refresh **Current status** in `AGENTS.md`
- [ ] 8.3 `openspec validate add-spatial-blocks`; confirm ready to archive
