## 1. XttyCore — result-model provenance fields

- [x] 1.1 Extend the Codable latency model in `XttyCore/Sources/XttyCore/PerformanceModel.swift` with latency-measurement provenance: a `timebaseCalibration` outcome (e.g. `passed`/`failed` + the measured offset) and the achieved capture cadence / frame-quantized resolution. Keep it view-free (no AppKit).
- [x] 1.2 Add a `latencyUntrustworthy` (or reuse/extend `latencyUnavailableReason`) marker so a failed calibration is representable distinctly from a missing-permission unavailable. (Reused `latencyUnavailableReason` + `timebaseCalibration` non-nil to distinguish calibration-fail from missing-permission.)
- [x] 1.3 Unit tests in `XttyCoreTests/PerformanceModelTests.swift`: round-trip the new fields; assert a failed-calibration report serializes with the untrustworthy marker and no absolute latency stats. (226 XttyCore tests green.)

## 2. App — clock reconciliation

- [x] 2.1 Add a host-clock helper: `t = CMClockMakeHostTimeFromSystemUnits(machUnits).seconds` for both t0 (`mach_absolute_time()` at the `CGEvent` post) and t1 (`SCStreamFrameInfo.displayTime`), so both sit in one domain (design D2). Remove the `DispatchTime.uptimeNanoseconds` vs ticks mismatch.
- [x] 2.2 Implement the startup epoch-calibration gate (design D4): capture one steady `.complete` frame, compute `offset = machNow − displayTime` (seconds), assert ~0/stable (tolerance 0.1 s); expose the outcome to the report.

## 3. App — SCStream probe (replace the poll loop)

- [x] 3.1 In `App/LatencyProbe.swift`, build the long-lived `SCStream` from `makeCaptureTarget`'s filter + a probe `SCStreamConfiguration` (design D6: `minimumFrameInterval = CMTime(1,120)`, `queueDepth = 8`, `showsCursor = false`, `32BGRA`). Kept the window-scoped filter (display-scoped is the documented fallback); the precise per-cell `sourceRect` is deferred to the design Open Question (full downscaled window is robust).
- [x] 3.2 Add an `SCStreamOutput` delegate (`FrameSink`) on a sample-handler queue that, per frame, reads status + `displayTime` + a `CVPixelBuffer` FNV-1a hash and returns immediately (no buffer retention, design D7); skips non-`.complete` frames.
- [x] 3.3 Reimplement `measureOnce` against the stream: record t0 + `postKey`, then take the **first `.complete` frame after t0 whose pixels differ from baseline**, blink-guarded by two consecutive changed frames; credit the first differing frame's `displayTime`. Crosses back via `CheckedContinuation`.
- [x] 3.4 Deleted the `SCScreenshotManager.captureImage` poll path. Calibration failure is represented as a **return-value outcome** (`LatencyProbeRun.calibration.passed == false`, no samples) rather than a thrown error — it's a degraded-but-valid run (memory still measured, report still written), not a hard failure.
- [x] 3.5 Preserve from P7a: `postKey` type/undo cadence, caret-hide + first-responder prep, the many-trial loop + `-BenchmarkTrials`, fail-loudly on missing permission/window.

## 4. App — trustworthiness protocol + report wiring

- [x] 4.1 Add the renderer-independent reference-stimulus baseline pass (design D5): a `ProbeOverlay` AppKit/CA strip the probe flips and times the same way → the common capture/compositor floor; surfaced as `BenchResult.noOpBaseline`. (User chose the overlay-stimulus approach over dropping it; spec ADDED requirement + design D5 updated to match.)
- [x] 4.2 In `App/BenchmarkRunner.swift`, write the new report fields (calibration outcome, frame-quantized resolution); when the probe can't run or calibration fails, still write memory + environment and mark latency unavailable/untrustworthy.
- [x] 4.3 Report wiring carries the new fields and builds; `make bench` runs both renderers (the actual run is task 6). Routine `make test` stays prompt-free (benchmark e2e opt-in via `XTTY_RUN_BENCH_E2E`).

## 5. Verification harness

- [x] 5.1 Update the performance-harness e2e (`AppUITests/XttyPerformanceHarnessUITests.swift`) so the benchmark-report assertion covers the timebase-calibration outcome + frame-quantized resolution where latency ran (or the unavailable/untrustworthy marker otherwise). Kept opt-in via `XTTY_RUN_BENCH_E2E`.
- [x] 5.2 No new files added (all edits in-place) → no `xcodegen` needed. `make test-core` green (226); app `make build` SUCCEEDED; `make test` green (31 XCUITests, 1 skipped = the opt-in benchmark e2e).

## 6. Run the A/B + capture the P7 verdict

- [x] 6.1 Ran `XTTY_SIGN_IDENTITY=xtty-dev make bench` 3× per renderer. Calibration **passed** every run (offset 0.7–3.2 ms); latency resolved (no longer floored); overlay baseline ~8.5–9.6 ms. Reports under `build/bench/`. (Display not force-pinned; results stable across 3 runs.)
- [x] 6.2 Wrote the P7b renderer-verdict addendum in `research/03-analysis/p7-measurement-methodology.md`: **keep CoreGraphics, skip Phase 8** (CG faster median + much tighter tail + leaner memory + non-experimental); confirmed the calibration gate passed on macOS 26.2; sharpened the shared-throttle finding (median wash, Metal tail worse). Makefile `bench` caveat updated.

## 7. Reconcile + validate

- [x] 7.1 Reconciled AGENTS **Current open changes**/**Next** (P7b implemented + verdict; Next → P7c) + `research/04-design/02-milestones.md` Phase 7 (decided: keep CoreGraphics) + `research/README.md` (apply result). The `performance-harness` Purpose "Known limitation (P7a)" note is updated at archive (after the spec delta merges).
- [x] 7.2 `openspec validate add-trustworthy-latency-probe` clean; full test suite green (226 XttyCore unit + 31 XCUITests, 1 opt-in skip).
