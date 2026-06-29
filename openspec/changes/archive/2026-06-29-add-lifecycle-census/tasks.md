## 1. Live-instance census counters (DEBUG-only)

- [x] 1.1 Add `#if DEBUG static var liveCount = 0` to the App-layer lifecycle types — `TerminalWindowController`, `PaneController`, `XttyTerminalView`, `GitReviewController`, `QuickTerminalController` — incrementing in `init` and decrementing in `deinit` (all already `@MainActor`; plain `Int`, no atomics — design D1).
- [x] 1.2 Add a `#if DEBUG` static count + `recordInit()`/`recordDeinit()` to `XttyCore`'s `TerminalSession`, called by `PaneController` from its main-actor context (keep `XttyCore` free of isolation annotations / `nonisolated(unsafe)` — design D2).
- [x] 1.3 Verify the counters compile out of a Release build (no symbols, no overhead) and change no user-visible behavior.

## 2. Surface the census in the state dump

- [x] 2.1 Add a `#if DEBUG` `liveInstanceCounts` dict (type name → count) to `TerminalWindowController.writeStateDump()`, alongside `paneCount`/`memoryFootprintBytes` (additive; design D3).
- [x] 2.2 Confirm existing state-dump consumers (`StateDumpReader`) tolerate the new field unchanged.

## 3. In-process deallocation tests (XttyCore, weak-sentinel)

- [x] 3.1 Add `XttyCore` unit tests that create `TerminalSession`, `SessionRegistry`, and `Pane`, hold only a weak reference, release the strong reference, and assert the weak ref is nil after teardown (`addTeardownBlock`) — design D5.
- [x] 3.2 Confirm the new tests run via `make test-core` (in-process, no app build) and pass.

## 4. Churn end-to-end coverage (the gated net)

- [x] 4.1 Add a churn XCUITest (e.g. `AppUITests/XttyLifecycleCensusUITests.swift`) that records the baseline census, opens/closes several panes/splits/tabs/windows back to the starting layout, and asserts every type's count settles back to baseline via `StateDumpReader.waitForState` (poll-to-settle with a timeout — design D4, risk mitigation).
- [x] 4.2 Tune the churn counts/cycles so the test is reliable, and confirm it fails when a deliberate retain is introduced (sanity-check the net catches a leak), then remove the deliberate retain.

## 5. Re-runnable OS leak-audit command (diagnostic, not a gate)

- [x] 5.1 Add `scripts/audit-leaks.sh` running `leaks -atExit` (with `MallocStackLogging=1`, optional `-outputGraph` `.memgraph`) and `vmmap`/`xctrace` against the built app, writing reports under `build/` (no privileged install; debug `get-task-allow` only — design D6).
- [x] 5.2 Add a `make audit-leaks` target wrapping the script; confirm `make build`/`make test` do NOT depend on it and a finding does not fail the standard path.
- [x] 5.3 Run the one-time deep pass against idle / multi-pane / saturated-scrollback / alt-screen scenarios; focus on SwiftTerm's unbounded glyph/font caches + renderer `deinit`; record findings (clean vs issues) as a dated addendum in `research/03-analysis/p7c-leak-retain-audit.md`.

## 6. Fix the two sweep nits

- [x] 6.1 Invalidate `AppDelegate.dumpTimer` in `applicationWillTerminate` (`App/XttyApp.swift`) — design D7.
- [x] 6.2 Change `BenchmarkRunner`'s `Task` to `[weak controller]` with a guard after the await boundary, matching `XttyApp`'s pattern (`App/BenchmarkRunner.swift`) — design D7.

## 7. Verify & reconcile

- [x] 7.1 `make test-core` + `make test` green (existing 226 unit + 31 UI tests plus the new census/churn/dealloc tests).
- [x] 7.2 `openspec validate add-lifecycle-census` passes; tick all tasks.
- [x] 7.3 Update trackers per AGENTS "Keep progress current": AGENTS **Current status** + `research/04-design/02-milestones.md` (P7c → implemented), and note the leak-audit result.
