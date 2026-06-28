## Context

P4a (`add-semantic-capture`) gave xtty a view-free OSC-133 block model (`Block`/`BlockTracker` in `XttyCore`) carrying command / exit / cwd / timestamps / state — but **deliberately no screen coordinates** (`Block.swift:17-18`), because the trim-invariant cursor row needed to anchor a block is unreachable from outside SwiftTerm's module. This change is the fork-gated half of P4b (P4b-1 file-link opening shipped fork-free); it adds the spatial operations — **jump-to-prompt** and **copy-command-output** — on top of a minimal SwiftTerm fork.

The decisions and the load-bearing facts are recorded in `research/03-analysis/p4b-2-spatial-blocks-decisions.md` (locked via an adversarially-verified research workflow) and refined by a code-grounded spike this session. Key verified facts (SwiftTerm `v1.13.0`, `8e7a1e1`):
- `buffer.yBase`/`buffer.linesTop` are module-internal (`Buffer.swift:32`,`:27`); `buffer` is `public private(set)` (`Terminal.swift:326`). `getScrollInvariantLine(row:)` (`Terminal.swift:743`) is the public precedent for the `linesTop`-based coordinate.
- `scrollTo(row:)` (`AppleTerminalView.swift:1846`) and `getText(start:end:)` (`Terminal.swift:5869`) are already public — the jump *scroll* and the copy *text-extraction* need no fork; only the trim-invariant row does.
- The **only** caller of `terminal.resize` is `AppleTerminalView.resize` (`:1934`), which fires `sizeChanged(source:)` immediately after; in-band DECCOLM resizes fire it too (`Terminal.swift:4048/4276`). Every reflow/resize-trim path therefore reaches `processDelegate.sizeChanged(source:newCols:newRows:)` — which xtty's `PaneController` already receives as a **currently-empty stub** (`PaneController.swift:175`).
- `reflow` is reachable only from `Buffer.resize` (`:503`); `clear`/CSI-3J set `linesTop = 0` (`Buffer.swift:355`, `Terminal.swift:2369`); `scroll()` bumps `linesTop += 1` preserving the invariant (`Terminal.swift:5260`).

## Goals / Non-Goals

**Goals:**
- Jump the focused pane's viewport to the previous/next command prompt, keyboard-native (Cmd+Shift+↑/↓).
- Copy a command block's output to the clipboard (excluding the trailing prompt), engine-only, with a transient confirmation.
- Keep the SwiftTerm fork **minimal (2 read-only accessors), engine-only, and upstreamable** — no edits to existing SwiftTerm files.
- Keep all anchor/invalidation/selection logic **view-free in `XttyCore`**; keep P4a's coordinate-free block invariants and the 134 unit tests green.
- Anchors are **best-effort**: every operation degrades gracefully (no-op + toast) without anchors or shell integration.

**Non-Goals:**
- **Tier-2 view-layer visual on-screen selection** (native select-then-Cmd+C) — deferred; it forks the *view* (`SelectionService` is internal, selection lives on the render layer), gated on the P7 Metal-renderer decision.
- **A clickable per-command-block sidebar** — a separate fork-free follow-up (P4b-3) on P5's Tab▸Pane sidebar.
- Gutter fail-marks (dropped in P5 sequencing; folded into the sidebar).
- Any change to rendering, the config schema, or the engine-via-`XttyCore` seam.

## Decisions

### D1 — Two engine accessors, behind an injectable seam; mechanism deferred
The feature needs two read-only accessors compiled **inside** SwiftTerm's module (they read `internal` `buffer.yBase`/`linesTop`):
```swift
public func getScrollInvariantCursorLocation() -> Position {
    Position(col: buffer.x, row: buffer.yBase + buffer.y + buffer.linesTop)   // pinned to the normal buffer
}
public var scrollbackBase: Int { buffer.linesTop }
```
Accessor #1 is the trim-invariant absolute cursor row; #2 reverse-maps an absolute row to a display row (`displayRow = absoluteRow − scrollbackBase`) and feeds reset detection. The addition is **add-only** (one new file, no edits to existing SwiftTerm files).

**The mechanism that makes these symbols exist is DEFERRED** (decision: build now against the seam in D1a, light up later). When lit up, the leading mechanism is a **git submodule pinned to `v1.13.0` + the drop-in accessor file + a local-path SPM dependency** (`XttyCore/Package.swift` → `.package(path: …)`) — the Playwright-style patch-in-repo that needs **no fork repo**; vendoring-in-tree or a `kitimark/SwiftTerm` fork remain reversible alternatives. Rationale + tradeoffs: `research/03-analysis/swiftterm-fork-vs-patch-strategy.md`. An upstream PR (mirroring the public `getScrollInvariantLine`) is filed in parallel to retire whatever local mechanism is chosen.

- **Alternatives rejected:** fork-free Tier-0 copy (adversarially **refuted** — silently wrong when scrolled up or after trim, since `getText` clamps rather than throws); `@testable import` (needs `-enable-testing` on the dep — not viable for release); reflection (brittle, breaks on the `linesTop=0` reset); waiting for the P8 own-renderer (far off).
- **Document the trap** on accessor #1: `getCursorLocation().y` is `yBase`-relative despite its "relative to visible display" doc comment (`Terminal.swift:5076`), so future implementers don't reintroduce a scroll-dependent off-by-`(yBase − yDisp)` bug.

### D1a — Injectable accessor seam (build + test now without the mechanism)
All SwiftTerm-internal access funnels through **two reads of plain `Int`s** behind an injectable seam (a closure/protocol owned by the App layer, e.g. `ScrollCoordinateReading { scrollInvariantRow() -> Int?; scrollbackBase() -> Int? }`). XttyCore is **fork-agnostic** — it receives captured `Int` rows and returns `Int` targets; `scrollTo`/`getText`/`getScrollInvariantLine` are already public.
- **Production today:** the seam returns `nil` → anchors absent → jump/copy **no-op gracefully** (exactly the spec's degradation scenarios). The feature ships and passes its degradation tests with **no SwiftTerm change**.
- **Tests today:** inject a **fake** seam returning synthetic rows → the **full happy path** (capture → invalidate → reverse-map → prev/next → jump/copy range) is unit/integration-tested **now**, before any mechanism exists.
- **Light-up later:** swap the production seam body to the real engine reads (~2 lines in one bridging file in `PaneController`) once D1's mechanism is in place, then run a real-zsh e2e + the empirical masking check. `liveTop` rides on accessor #1 (`= accessor#1.row − getCursorLocation().y`, the latter public).
- **Confidence (per the research doc):** the xtty-side swap is ~2 lines/one file (~95%); the injectable seam + fake-engine tests put "no rework at light-up" at ~90% (vs ~70% for a bare-`nil` shim that never exercises the happy path). Budget a short integration + real-zsh validation pass at light-up — that is the honestly-remaining work, not zero.

### D2 — Best-effort anchors captured at OSC-133 marks, epoch-stamped
`Block` (and the in-flight `runningBlock`) gain an **optional** anchor:
```swift
struct BlockAnchor: Sendable { let epoch: Int; let promptRow: Int?; let outputStart: Int?; let outputEnd: Int? }
```
Captured **synchronously inside the OSC-133 handler** (the engine feed path where reading buffer coords is safe): `promptRow` at `A`, `outputStart` at `C`, `outputEnd` at `D`. Each is `getScrollInvariantCursorLocation().row` at that mark, stamped with the current epoch (D3). Anchors are additive — a block with `nil` anchor stays valid, and the coordinate-free fields/invariants are untouched. With the fork the capture is **correct regardless of scroll position** (the engine always writes the cursor to `lines[yBase + y]`), so P4a's "does C fire at bottom?" worry is moot. Capture is skipped while `isCurrentBufferAlternate` (reuse P4a's alt tracking).

### D3 — Conservative invalidation: never silently use a stale anchor
Three layers, in order of cost:
1. **Resize / reflow / scrollback-size change → invalidate ALL anchors.** These shift line indices *without* dropping `linesTop`, so a `linesTop`-based detector misses them (this was the **refuted** naive scheme). Instead, fill the existing empty `PaneController.sizeChanged` stub (`:175`) to bump the session's epoch — every anchor stamped with an older epoch is dead. Verified: every reflow/resize-trim path fires `sizeChanged`, *after* the reflow, *before* any later keypress.
2. **Clear / CSI-3J / reset → liveTop high-water drop.** `liveTop = yBase + linesTop` is monotonic across normal output and drops to ~0 on a reset (`linesTop=0`). Sample it opportunistically (on the `scrolled` delegate, which fires during heavy output) and bump the epoch on a drop below the high-water mark.
3. **Validate at use.** On jump/copy, if `getScrollInvariantLine(absoluteRow) == nil` (trimmed out of bounded scrollback) → clamp to top / no-op. Generation/epoch mismatch → anchor dead → no-op + toast.

Invalidation is **conservative**: a window *grow* benignly drops still-valid anchors (acceptable). Reset detection is **best-effort**: a `clear; <flood>` within one feed chunk can mask a reset before the next sample (documented narrow corner, consistent with OSC-133 best-effort). Escalate to an in-engine `resetGeneration` counter (folded into the fork) only if observed biting — not pre-optimized.

- **Concurrency:** `PaneController.sizeChanged` is `nonisolated`; anchor capture is main-actor (OSC handler via `assumeIsolated`). The epoch is a single value bumped on the main actor — `sizeChanged` hops to the main actor to bump it, so capture and invalidation are serialized.

### D4 — Jump-to-prompt: viewport scroll only, prev/next over the block list
`jump-prev-prompt` / `jump-next-prompt` pick the adjacent block (relative to the current scroll position / last jump) from the per-session block list whose `promptRow` is valid, reverse-map `displayRow = promptRow − scrollbackBase`, and call the public `view.scrollTo(row: displayRow)`. **Viewport only** — never moves the cursor or creates a selection. No adjacent valid-anchor block (none, all invalidated, or at the end) → graceful no-op. The prev/next target selection is view-free `XttyCore` logic.

### D5 — Copy-output: engine-only `getText`, exclude the prompt, toast
`copy-command-output` defaults to the focused/last completed block (or `runningBlock` for in-flight output). Range = `[outputStart … outputEnd]` (for the running block, `outputStart … currentCursorRow`), reverse-mapped to `Position`s, extracted via the public `getText(start:end:)` → `NSPasteboard`. **Excludes the trailing prompt** (iTerm2's BEFORE_OUTPUT→BEFORE_PROMPT) by ending at `outputEnd` (the `D` mark), not the next `A`. **No on-screen selection is created** — engine-only, so nothing is wiped by streaming output and the render seam is untouched. On success, a transient non-modal toast confirms; invalid/trimmed anchor → no-op + toast (never copy mismatched/empty text silently).

### D6 — Keybindings: three new actions, menu-key-equivalent interception
Add `jumpPrevPrompt` / `jumpNextPrompt` / `copyCommandOutput` to the `KeyAction` enum (`KeyChord.swift`); they inherit `keybind-<action>` overrides for free (the resolver loops `allCases`). Defaults in both presets: `jump-prev-prompt = Cmd+Shift+Up`, `jump-next-prompt = Cmd+Shift+Down` (iTerm2/Ghostty convention; **verified free** — presets use Cmd+Opt+arrows for focus). Wire through the existing action→chord→menu→`@objc` selector→validate-whitelist→`PaneController` pipeline (the path the ~13 existing actions use). Because the chords bind as `NSMenuItem` key equivalents, the menu intercepts them **ahead of** the terminal view's `keyDown` (so the macOS extend-selection-to-doc default never shadows them — the existing Cmd+Opt+arrow focus bindings prove arrow+modifier menu equivalents work). Copy default chord: a free chord (`Cmd+Shift+C` or iTerm2's `Cmd+Shift+A`) — see Open Questions.

### D7 — Defer Tier-2 visual-select on architecture grounds (not fragility)
The research **refuted** "visual-select is fragile/low-value" — SwiftTerm stores selection in absolute coords and preserves it across scroll/focus and (with mouse-reporting off) streaming output. It is deferred anyway because accessor #3 (`setSelection`) reaches into the **view's** internal `SelectionService` (`SelectionService.swift:16`, `Mac/MacTerminalView.swift:151`), puncturing the engine-only seam and adding P7 Metal re-verification surface. The copy *goal* is fully met engine-only (D5); the verification benefit (seeing what you copied) is delivered fork-free by the toast.

### D8 — Harness: DEBUG state-dump fields + in-process trigger + e2e
Add `lastJumpTargetRow` and `lastCopiedOutput` to the DEBUG state dump (gated by `#if DEBUG` + `-UITestGridDump`), set when a jump/copy runs (a no-op records as such). Drive jump/copy via the established DEBUG action path (mirroring P4b-1's link trigger — the sandboxed runner asserts from the dump, not the real clipboard/scroll chrome). New XCUITest on an injected zsh asserts: jump resolves to an earlier prompt; copy captures a known command's output excluding the prompt; **a scrolled-up case** (correctness off-bottom); **a post-resize case** (graceful no-op after anchor invalidation).

## Risks / Trade-offs

- **Deferred light-up risk** (the seam returns `nil` until the mechanism lands) → the production happy path is unexercised until then. *Mitigation:* the injectable seam (D1a) is fake-tested for the full happy path now; light-up is a ~2-line swap + a bounded real-zsh validation pass.
- **Local-mechanism (submodule/vendor) is non-hermetic** → a fresh clone/CI must init the submodule + run the prepare step + regen the xcodeproj before building. *Mitigation:* a documented one-shot prepare script; the feature still builds (no-op) if skipped, since the seam returns `nil`. (A fork, if chosen instead, is hermetic but needs the external repo.)
- **Reset-detection masking corner** (`clear; <flood>` in one feed chunk) → a stale anchor could be used. *Mitigation:* validate-at-use + `scrolled`-delegate sampling shrink the window to near-nothing; documented best-effort; escalate to an in-engine counter only if observed.
- **`changeScrollback` skips `sizeChanged`** (`Terminal.changeScrollback` → no delegate). *Mitigation:* xtty calls it only at config-application time (`TerminalConfigurator.swift:36`), before any anchors exist → moot; if a live scrollback-change feature is ever added, invalidate at that call site too.
- **Anchor capture on the wrong actor/timing** would record a too-low row. *Mitigation:* capture synchronously inside the OSC-133 handler (main-actor), never deferred.
- **Memory:** copy is **on-demand** `getText` (no eager per-block output retention), honoring lean-memory; anchors are three optional `Int`s + an epoch per block.

## Migration Plan
**Phase 1 — build now (no mechanism):**
1. Define the injectable accessor seam (D1a) in the App layer with a production impl returning `nil`.
2. Implement `XttyCore` (anchors, invalidation, reverse-map, prev/next) + a **fake seam** exercising the full happy path in tests → app (fill `sizeChanged`, capture in OSC handler, keybinds, jump/copy + toast) → harness (degradation scenarios + the in-process trigger).
3. Ship: the feature compiles and no-ops gracefully; `SwiftTerm` pin stays `from: "1.13.0"` (unchanged).

**Phase 2 — light up (chosen mechanism, leading = submodule + drop-in):**
4. Add `migueldeicaza/SwiftTerm` as a submodule pinned to `v1.13.0`; add a prepare step that drops `XttyAccessors.swift` into its `Sources/SwiftTerm/`; switch `XttyCore/Package.swift:23` to `.package(path: "../external/SwiftTerm")`; `swift package resolve`; reset DerivedData package caches; `xcodegen generate`. (`project.yml` untouched; or vendor-in-tree / fork as reversible alternatives.)
5. Swap the production seam body to the real engine reads (~2 lines); run the real-zsh e2e + the empirical masking check.
6. File the upstream PR mirroring `getScrollInvariantLine`; if merged + tagged, drop the local mechanism and repoint to the upstream release.
- **Rollback:** the production seam returns `nil` → spatial features no-op; revert the `Package.swift` path change. Nothing else depends on the mechanism.

## Open Questions
- **Copy default chord** — `Cmd+Shift+C` (mnemonic) vs iTerm2's `Cmd+Shift+A` ("select output of last command"). Both verified free; pick during apply.
- **Default copy scope** — last completed block vs the jump-selected block. Lean: last/running by default; the jump-selected target becomes copyable once P4b-3's sidebar designates arbitrary blocks.
- **Masking empirical check** — once running, confirm whether `clear; <flood>` masking is observable in practice; if so, fold the in-engine `resetGeneration` counter into the local mechanism.
- **Light-up mechanism** — confirm the leading submodule + drop-in + local-path approach at Phase 2 (vs vendor-in-tree / fork); resolved in `research/03-analysis/swiftterm-fork-vs-patch-strategy.md`, finalize when lighting up.
- **Upstream PR latency** — bus-factor-1; do not block on it (the local mechanism is the hedge; repoint later).
