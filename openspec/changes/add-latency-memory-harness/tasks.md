## 1. Config: the `renderer` key (terminal-configuration)

- [ ] 1.1 Add a `RendererBackend` enum (`coregraphics`/`metal`, `String`-raw, `CaseIterable`, `Sendable`) to `XttyCore` and a base-only `renderer: RendererBackend` field (default `.coregraphics`) on `XttyConfigSet` + its initializer
- [ ] 1.2 Parse `renderer` in `XttyConfigLoader.resolveSet` as a base-only key (profile-ignore warning like `git-review-layout`; invalid value → default `.coregraphics` + `warn`), and pass it to the `XttyConfigSet` init
- [ ] 1.3 Unit tests (XttyCore): parses `metal`/`coregraphics`/`METAL` (case-insensitive); defaults to `coregraphics` when absent; invalid value falls back + warns; `renderer` inside a `[profile …]` block is ignored + warns
- [ ] 1.4 Document `renderer = coregraphics` (with the `metal` option, marked experimental) in `config.example`

## 2. Renderer A/B toggle (performance-harness)

- [ ] 2.1 In `TerminalWindowController`, after the terminal view is hosted in the window, apply the selected backend via SwiftTerm `setUseMetal(_:)` when `.metal` (default `.coregraphics` = no call); pass the backend in through the controller initializer
- [ ] 2.2 Plumb `configSet.renderer` through both `TerminalWindowController(...)` creation sites in `XttyApp`, and preserve it in `applyUITestOverrides`' `XttyConfigSet` rebuild
- [ ] 2.3 Add a `-UITestRenderer coregraphics|metal` launch override in `applyUITestOverrides` that overrides the config-file value (for rebuild-free A/B)
- [ ] 2.4 Verify Metal output correctness: launch with the Metal backend and confirm truecolor + emoji + wide/CJK render without corruption (grid dump unaffected; manual screenshot per the P2 spike method)

## 3. Memory sampler + scenarios (performance-harness)

- [ ] 3.1 View-free `XttyCore`: a `BenchScenario` set (`idleOnePane`, `multiPane(n)`, `scrollbackFlood`, `altScreen`) and a `BenchResult` model (renderer, capture frame rate, latency stats + raw samples, per-scenario memory samples, environment), serializable to JSON
- [ ] 3.2 App-layer resident-memory sampler reading `phys_footprint` via mach `task_vm_info` (`task_info`), returning bytes
- [ ] 3.3 Unit tests (XttyCore): scenario-set definitions and `BenchResult` round-trip serialization are exercised without launching the app or creating a view

## 4. Latency probe (performance-harness)

- [ ] 4.1 Synthetic-keystroke injection via `CGEvent` keyDown/keyUp posted to the app; ensure the active pane's terminal view is first responder and confirm it immediately before each injection (else the key never reaches the PTY)
- [ ] 4.2 Pixel-change capture: ScreenCaptureKit (`SCStream`) primary with `CGWindowListCreateImage` fallback, run at the display's max refresh rate; capture a target cell-region baseline, inject, and time to the first frame whose region differs. Guard cursor-blink with a two-frame persistent-change test and validate it actually rejects single-frame blinks (blink-disable is the fallback). Record the capture frame rate in the result — latency is frame-quantized (~16 ms at 60 Hz can mask sub-~5 ms differences), mitigated by max-rate capture + the distribution in 4.3
- [ ] 4.3 Trial loop producing a distribution (median + p95/p99) over N trials; on missing Screen-Recording permission or no visible display, fail with a clear error (no fabricated sample)
- [ ] 4.4 Verify the probe's failure path: a unit test (or a documented manual procedure) confirming that without capture permission/display the probe returns a clear error and emits no fabricated sample

## 5. Benchmark run + report (performance-harness)

- [ ] 5.1 A `#if DEBUG` `-Benchmark` launch mode that, for the active renderer, runs the latency probe + the memory scenarios and writes the `BenchResult` JSON report — catching the probe's loud failure so latency degrades to an explicit "unavailable" marker when the capture path can't run (no permission/display), while renderer + per-scenario memory + capture frame rate + environment are still recorded — then terminates the app
- [ ] 5.2 `make bench` target that builds and launches the benchmark mode once per renderer (CoreGraphics + Metal), writing a report for each; document the one-time Screen-Recording TCC grant it needs

## 6. Observability + e2e (verification-harness)

- [ ] 6.1 Extend `TerminalWindowController.writeStateDump` with the active `renderer` and the most recent resident-memory sample (bytes)
- [ ] 6.2 XCUITest: launch with `-UITestRenderer metal` and separately `coregraphics`; assert the state dump reports the matching backend each time
- [ ] 6.3 XCUITest: assert the state dump reports a positive resident-memory sample for the key window
- [ ] 6.4 Benchmark-report coverage: assert a `-Benchmark` run writes a `BenchResult` report containing the active renderer, per-scenario memory samples, capture frame rate, and environment description — plus latency distribution stats where the capture path is available, and the explicit unavailable marker otherwise (the no-capture degradation path); latency-present assertions gated like the real-shell e2e

## 7. Validate, build, reconcile

- [ ] 7.1 `swift test --package-path XttyCore` green; `make build` green; targeted XCUITests green
- [ ] 7.2 `openspec validate "add-latency-memory-harness"` clean; confirm `config.example` documents `renderer`
- [ ] 7.3 On completion, reconcile trackers per AGENTS.md (tick these boxes, AGENTS Current status + milestones Phase 7 → P7a implemented) — done in the apply/archive session, not now
