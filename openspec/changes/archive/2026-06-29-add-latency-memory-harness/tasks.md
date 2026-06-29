## 1. Config: the `renderer` key (terminal-configuration)

- [x] 1.1 Add a `RendererBackend` enum (`coregraphics`/`metal`, `String`-raw, `CaseIterable`, `Sendable`) to `XttyCore` and a base-only `renderer: RendererBackend` field (default `.coregraphics`) on `XttyConfigSet` + its initializer
- [x] 1.2 Parse `renderer` in `XttyConfigLoader.resolveSet` as a base-only key (profile-ignore warning like `git-review-layout`; invalid value → default `.coregraphics` + `warn`), and pass it to the `XttyConfigSet` init
- [x] 1.3 Unit tests (XttyCore): parses `metal`/`coregraphics`/`METAL` (case-insensitive); defaults to `coregraphics` when absent; invalid value falls back + warns; `renderer` inside a `[profile …]` block is ignored + warns
- [x] 1.4 Document `renderer = coregraphics` (with the `metal` option, marked experimental) in `config.example`

## 2. Renderer A/B toggle (performance-harness)

- [x] 2.1 In `TerminalWindowController`, after the terminal view is hosted in the window, apply the selected backend via SwiftTerm `setUseMetal(_:)` when `.metal` (default `.coregraphics` = no call); pass the backend in through the controller initializer
- [x] 2.2 Plumb `configSet.renderer` through both `TerminalWindowController(...)` creation sites in `XttyApp`, and preserve it in `applyUITestOverrides`' `XttyConfigSet` rebuild
- [x] 2.3 Add a `-UITestRenderer coregraphics|metal` launch override in `applyUITestOverrides` that overrides the config-file value (for rebuild-free A/B)
- [x] 2.4 Verify Metal backend engages: the e2e (`testConfiguredMetalRendererIsReported`) confirms `setUseMetal` engages on Metal-capable hardware (dump reports `metal`) with the grid dump unaffected; pixel-correctness (truecolor/emoji/CJK) stays a documented manual screenshot per the P2 spike (the engine grid is renderer-independent, so e2e can't assert GPU pixels)

## 3. Memory sampler + scenarios (performance-harness)

- [x] 3.1 View-free `XttyCore`: a `BenchScenario` set (`idleOnePane`, `multiPane`, `scrollbackFlood`, `altScreen`) and a `BenchResult` model (renderer, capture frame rate, latency stats + raw samples, per-scenario memory samples, environment), serializable to JSON
- [x] 3.2 App-layer resident-memory sampler reading `phys_footprint` via mach `task_vm_info` (`task_info`), returning bytes
- [x] 3.3 Unit tests (XttyCore): scenario-set definitions and `BenchResult` round-trip serialization are exercised without launching the app or creating a view

## 4. Latency probe (performance-harness)

- [x] 4.1 Synthetic-keystroke injection via `CGEvent` keyDown/keyUp posted to the app's pid; the benchmark focuses the active pane before probing so the keystroke reaches the PTY (design D3)
- [x] 4.2 Pixel-change capture via ScreenCaptureKit's one-shot `SCScreenshotManager.captureImage` in an `async` loop (`CGWindowListCreateImage` is unavailable on the SDK — reconciled in design D2); capture a baseline window hash, inject, and time to the first capture whose hash differs. Guard cursor-blink with a two-frame persistent-change test (`showsCursor = false` on the capture config too). Record the display refresh Hz as the latency time-resolution in the result — latency is frame-quantized (~16 ms at 60 Hz can mask sub-~5 ms differences), mitigated by the median/tail distribution in 4.3
- [x] 4.3 Trial loop producing a distribution (median + p95/p99 via `LatencyStats`) over N trials; on missing Screen-Recording permission or no visible display, throws `LatencyProbeError` with a clear message (no fabricated sample)
- [x] 4.4 Probe failure path covered: the benchmark e2e (`testBenchmarkRunWritesReport`) asserts the report carries latency stats *or* an explicit unavailable marker (the degradation path); `LatencyProbeError` descriptions document the clear-failure contract

## 5. Benchmark run + report (performance-harness)

- [x] 5.1 A `#if DEBUG` `-Benchmark` launch mode (`BenchmarkRunner`) that, for the active renderer, runs the latency probe + the memory scenarios and writes the `BenchResult` JSON report — catching the probe's loud failure so latency degrades to an explicit "unavailable" marker when the capture path can't run (no permission/display), while renderer + per-scenario memory + capture frame rate + environment are still recorded — then terminates the app (`-BenchmarkReport <path>` / `-BenchmarkTrials <n>` overrides)
- [x] 5.2 `make bench` target that builds and launches the benchmark mode once per renderer (CoreGraphics + Metal), writing a report for each; documents the one-time Screen-Recording TCC grant it needs

## 6. Observability + e2e (verification-harness)

- [x] 6.1 Extend `TerminalWindowController.writeStateDump` with the active `renderer` (ground truth from the view) and the most recent resident-memory sample (`memoryFootprintBytes`)
- [x] 6.2 XCUITest: launch with `-UITestRenderer metal` and separately `coregraphics`; assert the state dump reports the matching backend each time (waits for the expected value to avoid a shared-dump race)
- [x] 6.3 XCUITest: assert the state dump reports a positive resident-memory sample for the key window
- [x] 6.4 Benchmark-report coverage: assert a `-Benchmark` run writes a `BenchResult` report containing the active renderer, per-scenario memory samples, and (latency stats or the explicit unavailable marker — the no-capture degradation path). Opt-in via `XTTY_RUN_BENCH_E2E=1` (the only test that drives ScreenCaptureKit → a Screen-Recording prompt; ad-hoc signing re-prompts each rebuild), so routine `make test` stays prompt-free

## 7. Validate, build, reconcile

- [x] 7.1 `swift test --package-path XttyCore` green (224); `make build` green; full XCUITest suite green (31, incl. 4 new performance-harness e2e; the benchmark e2e is opt-in via `XTTY_RUN_BENCH_E2E=1` and skips by default, so routine `make test` is prompt-free)
- [x] 7.2 `openspec validate "add-latency-memory-harness"` clean; `config.example` documents `renderer`
- [x] 7.3 On completion, reconcile trackers per AGENTS.md (AGENTS Current status + milestones Phase 7 → P7a implemented) — done in the archive session
