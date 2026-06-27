## 1. App — accessibility wiring + DEBUG grid-dump hook

- [x] 1.1 In `TerminalWindowController.init` (after `terminal.processDelegate = self`): set AX identifiers — `terminal.setAccessibilityIdentifier("xtty.terminal")` (+ element/role/label), `window.setAccessibilityIdentifier("xtty.window")`, `window.identifier = "xtty.window"`
- [x] 1.2 Add a `#if DEBUG` grid-dump hook to `TerminalWindowController`: a timer that polls the headless `Terminal` grid (`getLine`/`translateToString`) onto `/tmp/xtty-grid-dump.txt`; invalidate it in `terminate()`
- [x] 1.3 In `XttyApp.AppDelegate.applicationDidFinishLaunching`: start the grid-dump hook when launched with `-UITestGridDump` (`#if DEBUG`)

## 2. XCUITest target

- [x] 2.1 Add `AppUITests/XttyUITestSupport.swift` (helpers: identifiers, `GridDumpReader`, screenshot/grid attach)
- [x] 2.2 Add `AppUITests/XttyUITests.swift` (4 tests: focus-typing, multi-line paste, resize redraw, typed echo)
- [x] 2.3 Edit `project.yml`: add the `xttyUITests` `bundle.ui-testing` target (sources `AppUITests`, dependency `target: xtty`, mirrored ad-hoc signing, distinct bundle id)
- [x] 2.4 Edit `project.yml`: add `scheme.testTargets: [xttyUITests]` to the `xtty` target so the Test action runs the UI tests
- [x] 2.5 `xcodegen generate`; confirm the target + scheme exist

## 3. Verify

- [x] 3.1 `xcodebuild build-for-testing -scheme xtty -destination 'platform=macOS'` compiles the app + UI test target — **TEST BUILD SUCCEEDED**
- [x] 3.2 `xcodebuild test -project xtty.xcodeproj -scheme xtty -destination 'platform=macOS'` runs; the four tests pass — **Executed 4 tests, 0 failures** (grid-dump assertions active, no TCC prompt needed)
- [x] 3.3 `openspec validate add-verification-harness` passes — "Change is valid"

## 4. Peekaboo (local manual tooling)

- [x] 4.1 Install Peekaboo (`brew install steipete/tap/peekaboo`) — v3.5.2; `peekaboo permissions status` → Accessibility + Screen Recording + Event Synthesizing all **Granted**
- [x] 4.2 Smoke-test driving xtty — `peekaboo list windows --app xtty` (finds the window), `peekaboo type "…" --app xtty` (typed into the real terminal, verified on screen). Example commands captured in design.md
- [ ] 4.3 (Optional) Register the Peekaboo MCP server for Claude Code — _deferred; CLI is sufficient for now_
