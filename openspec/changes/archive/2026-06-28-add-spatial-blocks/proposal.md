## Why

P4a captures OSC-133 command blocks (command / exit / cwd / timestamps / state) but stores **no screen coordinates**, so a user cannot act *spatially* on them — there is no way to jump the viewport back to a previous prompt or copy a past command's output. These are the core in-terminal-navigation affordances every established terminal offers (iTerm2 marks, Ghostty `jump_to_prompt`, kitty `scroll_to_prompt`), and agent-CLI workflows produce long scrollback where "jump to the last prompt" and "copy that command's output" are daily actions. This is the deliberately deferred, fork-gated half of P4b (P4b-1 file-link opening already shipped fork-free); the explore-phase research has resolved it down to a minimal, engine-only SwiftTerm fork.

## What Changes

- **A minimal 2-accessor SwiftTerm fork** (engine-only, one new in-module file mirroring the existing public `getScrollInvariantLine`): `getScrollInvariantCursorLocation()` (the trim-invariant absolute cursor row) and `scrollbackBase` (= `buffer.linesTop`, for reverse-mapping and reset detection). Pinned by revision to a `kitimark/SwiftTerm` fork of the `v1.13.0` tag, with an upstream PR filed in parallel. No edits to existing SwiftTerm files (lowest rebase cost).
- **Best-effort scroll-invariant anchors on each command block** — optional `promptRow` / `outputStart` / `outputEnd` rows plus an `epoch`, captured synchronously at the OSC-133 `A`/`C`/`D` marks. Additive and view-free; P4a's coordinate-free block invariants are preserved.
- **A robust anchor-invalidation model** (view-free in `XttyCore`, wired in the app): invalidate on the existing (currently no-op) `sizeChanged` delegate (covers window resize + width reflow + scrollback-size change); detect `clear`/reset via a `liveTop` high-water drop; gate capture/jump on the alternate screen; validate at use via `getScrollInvariantLine(row) == nil` (trimmed-out → clamp). Anchors are best-effort — jump/copy degrade gracefully (no-op + toast) when an anchor is dead.
- **Jump-to-prompt** — `jump-prev-prompt` / `jump-next-prompt` actions that scroll the focused pane's viewport to the previous/next command block's prompt row (via the already-public `scrollTo(row:)`), default-bound to **Cmd+Shift+↑ / Cmd+Shift+↓** (the iTerm2 + Ghostty macOS convention; verified free in both xtty presets).
- **Copy-command-output** — a `copy-command-output` action that copies the focused/last block's output text (range `[outputStart … outputEnd]`, excluding the trailing prompt, à la iTerm2) to the clipboard via the public `getText(start:end:)` → `NSPasteboard`, with a transient flash/toast confirming what was copied. No on-screen selection (kept engine-only).
- **Harness coverage** — the DEBUG state dump gains `lastJumpTargetRow` and `lastCopiedOutput`; new injected-zsh e2e asserts jump scroll + copy correctness, **including a scrolled-up case and a post-resize graceful-degradation case**.
- **Explicitly out of scope (deferred):** Tier-2 view-layer visual on-screen selection (forks the *view*, gated on the P7 Metal-renderer decision); a clickable per-command-block sidebar (a separate fork-free follow-up, **P4b-3**, on P5's Tab▸Pane sidebar).

## Capabilities

### New Capabilities
- `terminal-spatial-blocks`: spatial operations on captured OSC-133 command blocks — best-effort scroll-invariant block anchors and their invalidation, jump-to-prompt (previous/next), and copy-command-output; enabled by the minimal engine-only SwiftTerm fork. Engine-only (no view-layer selection), best-effort (degrades gracefully without anchors / shell integration).

### Modified Capabilities
- `terminal-keybindings`: add three bindable actions — `jump-prev-prompt`, `jump-next-prompt`, `copy-command-output` — with default chords (Cmd+Shift+↑/↓ for jump; a free chord for copy) in both presets and `keybind-<action>` overrides (via the existing mechanism).
- `verification-harness`: the DEBUG state dump exposes the last jump-target row and last copied output; e2e coverage for jump + copy including scrolled-up and post-resize degradation.

## Impact

- **Dependency:** `XttyCore/Package.swift` SwiftTerm pin repointed from `from: "1.13.0"` to a revision-pinned `kitimark/SwiftTerm` fork (regenerates `Package.resolved` and the gitignored `xcodeproj`; `project.yml` untouched). First forked dependency in the project — fork is itself the hedge against SwiftTerm's bus-factor-1; an upstream PR is filed to retire it.
- **`XttyCore`:** `Block`/`BlockTracker` gain optional best-effort anchors; new view-free anchor-math + invalidation + jump-target selection logic; new `KeyAction` cases. Existing coordinate-free invariants and unit tests stay green.
- **App:** fills the existing empty `PaneController.sizeChanged` stub (invalidate anchors); captures anchors in the OSC-133 handler; new menu items + `@objc` selectors + validate-whitelist + `PaneController` forwards for jump/copy; `getText → NSPasteboard` + a toast view; per-feed/`scrolled` `liveTop` sampling.
- **Harness:** DEBUG dump fields + a new XCUITest driving an injected zsh.
- **Specs:** new `terminal-spatial-blocks`; deltas to `terminal-keybindings` and `verification-harness`.
- **No change to** `terminal-configuration` (reuses the existing `keybind-<action>` override path), rendering, or the engine-via-`XttyCore` architectural seam (the fork accessors stay on the headless `Terminal`).
