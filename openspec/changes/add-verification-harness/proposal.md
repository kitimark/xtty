## Why

P1 (`integrate-swiftterm`) gave xtty a live terminal window, but there is **no repeatable way to verify its interactive behavior** — the P1 checks (focus-typing, multi-line paste, resize redraw, scrollback/selection) are all manual. We need (a) a committed, deterministic end-to-end test layer and (b) a manual/agent-driven inspection loop.

The hard constraint that shapes the design: SwiftTerm's `LocalProcessTerminalView` draws its grid to a CoreText/Metal canvas and exposes **no per-cell text to accessibility**. So neither XCUITest nor a GUI-automation tool can read terminal *contents* from the accessibility tree — the harness must assert content another way.

## What Changes

- Add a macOS **XCUITest target** (`xttyUITests`, `bundle.ui-testing`) that drives the real app via `XCUIApplication`, wired into the `xtty` scheme's Test action so `xcodebuild test -scheme xtty` runs it.
- Add minimal **accessibility identifiers** to the terminal view (`xtty.terminal`) and window (`xtty.window`) so tests can locate the view and route synthetic input — explicitly **not** exposing per-cell text.
- Add a **DEBUG-only headless grid-dump hook** (gated by the `-UITestGridDump` launch argument) that writes the engine grid to a temp file for deterministic substring assertions, paired with `XCTAttachment` screenshots for human/vision review.
- Cover four behaviors as e2e tests: focus-typing-on-activate (no click), multi-line paste staged-not-executed, window-resize redraw smoke, basic typed echo.
- Adopt **Peekaboo** as **local (uncommitted) tooling** for manual/agent-driven inspection (screenshot + vision, type/click/resize) — documented here, not part of the build.

## Capabilities

### New Capabilities
- `verification-harness`: how xtty's terminal behavior is verified — a committed XCUITest e2e layer, the DEBUG grid-dump assertion channel, and the local Peekaboo inspection loop.

### Modified Capabilities
<!-- none: no existing spec's requirements change -->

## Impact

- **Build:** `project.yml` gains a `xttyUITests` target + a `scheme.testTargets` entry on `xtty` (regenerate with `xcodegen generate`). New `AppUITests/` source dir.
- **App code:** small additive edits to `App/TerminalWindowController.swift` (AX identifiers + DEBUG grid-dump hook) and `App/XttyApp.swift` (launch-arg gate). No behavior change in non-test builds.
- **Tooling:** Peekaboo installed locally via Homebrew; optional MCP registration. Requires interactive macOS TCC grants (Accessibility + Screen Recording) attributed to the host terminal — cannot be scripted.
- **Dependencies:** no new app dependencies; XCTest/XCUITest ship with Xcode.
