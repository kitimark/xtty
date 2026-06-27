## Context

P1 left five interactive behaviors verifiable only by hand. This change adds a verification harness. The defining constraint: SwiftTerm's `LocalProcessTerminalView` is custom-drawn (CoreText/Metal into a hand-managed `CALayer`), so AppKit exposes the terminal to accessibility as at most one opaque element — **no per-cell text, cursor, or selection**. Any AX-based tool (XCUITest, Peekaboo, ax-cli) hits this ceiling. The leverage instead: xtty already routes the engine through `XttyCore.TerminalSession` (observe-only handle to SwiftTerm's headless `Terminal`); that grid is the ground-truth content source, reachable in-process without the GUI.

## Goals / Non-Goals

**Goals:**
- A committed, repeatable e2e layer (`xcodebuild test`) that drives the real app and asserts the P1 interactive behaviors deterministically.
- A manual/agent-driven inspection loop (Peekaboo) for exploratory checks and visual regressions.
- Assert terminal *content* reliably despite the AX-content ceiling.

**Non-Goals:**
- Pixel/golden-image rendering regression (font/DPI/AA-fragile) — out of scope; screenshots are for human/vision review, not byte comparison.
- Headless/CI execution of the UI tests (macOS XCUITest needs a real Aqua session + TCC); CI gating is a later concern.
- VT conformance suites (vttest/esctest) — a separate, periodic gate.
- Driving the engine or new product behavior — this change only observes.

## Decisions

- **Assert content via a DEBUG headless grid-dump + screenshots, not the accessibility tree.** SwiftTerm's view exposes no per-cell text, so `XCUIElement.value` is unusable. A `#if DEBUG` hook, gated by the `-UITestGridDump` launch argument, polls the headless `Terminal` grid (`getLine`/`translateToString`) onto a temp file the test runner reads for substring assertions. Screenshots (`XCTAttachment`) are the human/vision record. Accessibility identifiers are used **only** to locate the view/window and route synthetic input.

- **Grid-dump uses a fixed `/tmp` path, cross-process readable because the app is non-sandboxed (P0 posture).** Gated behind `#if DEBUG` **and** the launch arg so it never ships and never runs outside tests. *If the App Sandbox is enabled later, move the dump to an App Group container or the substring assertions silently skip* (degrade to screenshot-only).

- **The UI-test target mirrors the host's ad-hoc/manual signing.** `CODE_SIGN_IDENTITY "-"`, hardened runtime off, no entitlements on the runner; one identity setting covers both the `.xctest` bundle and the auto-generated `xttyUITests-Runner.app`. `TEST_TARGET_NAME` is **auto-derived** by XcodeGen from the `target: xtty` dependency — never set by hand. Distinct bundle id (`com.xtty.appUITests`). Test sources live in a separate `AppUITests/` dir so the app target never compiles XCTest code.

- **Tests degrade gracefully.** Against a Release build (no DEBUG hook) the substring assertions auto-skip and screenshots remain the record. Return is sent via `typeKey(.enter)`; windows are matched by AX id (not the OSC-2-rewritable title).

- **Peekaboo is local tooling, not a committed test target.** It needs a live GUI and interactive TCC grants attributed to the spawning terminal (Warp), so it cannot run deterministically in CI. XCTest is the committed, repeatable e2e layer; Peekaboo is the manual/agent loop (Claude Code shells out to the CLI, optionally via MCP). Peekaboo install + config stay out of git (`.claude/`/Homebrew, already gitignored).
  - **Install/verify:** `brew install steipete/tap/peekaboo` (v3.5.2); `peekaboo permissions status` must show Accessibility + Screen Recording granted to the host terminal (the *spawning* process — Warp — not Peekaboo).
  - **Example commands:** `peekaboo list windows --app xtty` · `peekaboo type "echo hi" --app xtty` · `peekaboo paste --app xtty` · `peekaboo image --app xtty --path shot.png`.
  - **Capture nuance:** because xtty opens on the built-in display (which AppKit positions in an off-main coordinate region), Peekaboo flags that window OFF-SCREEN and `peekaboo image` may come back blank. For a reliable pixel capture, bring xtty frontmost first (or fall back to `screencapture -x -D <n>` of the built-in display) — input (`type`/`paste`) works regardless via background injection to the PID.
  - **Observation (follow-up):** Peekaboo reports ~10 windows for the single xtty process (several tiny off-screen `[Untitled]` ones) — likely SwiftUI auxiliary/offscreen windows from the `Settings` scene. Benign for rendering (the real terminal window is correct); worth a look later against the lean-memory value.

## Risks / Trade-offs

- **macOS XCUITest needs a real Aqua session + TCC for the runner** → first `xcodebuild test` triggers a one-time approval; ad-hoc signing churn can reset it on clean rebuilds (symptom: "typing did nothing"). Document; pre-grant where possible.
- **Typing before the prompt is drawn drops keystrokes** → `setUp` gates on `GridDumpReader.waitForNonEmpty`; slow zsh/dotfiles may need larger timeouts.
- **Grid-dump channel depends on the non-sandboxed posture** → enabling the sandbox later disables deterministic assertions until the path moves to an App Group.
- **Resize-drag can be clamped by Stage Manager / tiling WMs** → the resize test asserts only the real invariant (no crash; terminal + window survive; content persists), so it's weak signal under a window manager.
- **AX-content ceiling is permanent for this view** → all content assertions must stay on the grid-dump + screenshot channels; never `app.terminal.value`.

## Open Questions

- Should a separate non-UI integration test (drive the headless `Terminal` directly in `XttyCore` tests) cover paste-wrapping/reflow deterministically *in addition to* the e2e layer? *Lean:* yes, later — cheaper and CI-able — but out of scope here.
- Worth registering Peekaboo as an MCP server vs shelling out to the CLI? *Lean:* CLI first (zero wiring); add MCP if the agent loop gets heavy.
