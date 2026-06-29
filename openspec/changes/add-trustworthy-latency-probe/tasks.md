## 1. XttyCore — result-model provenance fields

- [ ] 1.1 Extend the Codable latency model in `XttyCore/Sources/XttyCore/PerformanceModel.swift` with latency-measurement provenance: a `timebaseCalibration` outcome (e.g. `passed`/`failed` + the measured offset) and the achieved capture cadence / frame-quantized resolution. Keep it view-free (no AppKit).
- [ ] 1.2 Add a `latencyUntrustworthy` (or reuse/extend `latencyUnavailableReason`) marker so a failed calibration is representable distinctly from a missing-permission unavailable.
- [ ] 1.3 Unit tests in `XttyCoreTests/PerformanceModelTests.swift`: round-trip the new fields; assert a failed-calibration report serializes with the untrustworthy marker and no absolute latency stats.

## 2. App — clock reconciliation

- [ ] 2.1 Add a host-clock helper: `t = CMClockMakeHostTimeFromSystemUnits(machUnits).seconds` for both t0 (`mach_absolute_time()` at the `CGEvent` post) and t1 (`SCStreamFrameInfo.displayTime`), so both sit in one domain (design D2). Remove the `DispatchTime.uptimeNanoseconds` vs ticks mismatch.
- [ ] 2.2 Implement the startup epoch-calibration gate (design D4): capture one steady `.complete` frame, compute `offset = machNow − displayTime` (seconds), assert ~0/stable; expose the outcome to the report.

## 3. App — SCStream probe (replace the poll loop)

- [ ] 3.1 In `App/LatencyProbe.swift`, build the long-lived `SCStream` from `makeCaptureTarget`'s filter + a probe `SCStreamConfiguration` (design D6: `minimumFrameInterval = CMTime(1,120)`, `queueDepth = 8`, `showsCursor = false`, `32BGRA`, small `sourceRect` at the target cell). Keep the window-scoped filter; leave a display-scoped fallback note.
- [ ] 3.2 Add an `SCStreamOutput` delegate on a sample-handler queue that, per frame, reads status + `displayTime` + a `CVPixelBuffer` FNV-1a hash and returns immediately (no buffer retention, design D7); skip `.idle`/`.started`.
- [ ] 3.3 Reimplement `measureOnce` against the stream: record t0 + `postKey`, then take the **first `.complete` frame after t0 whose pixels differ from baseline**, blink-guarded by two consecutive changed frames; credit that frame's `displayTime`. Cross back to the awaiting trial via continuation/`AsyncStream`.
- [ ] 3.4 Delete the `SCScreenshotManager.captureImage` poll path (or demote it per design Open Question); add the `LatencyProbeError` case for a failed calibration.
- [ ] 3.5 Preserve from P7a: `postKey` type/undo cadence, caret-hide + first-responder prep, the many-trial loop + `-BenchmarkTrials`, fail-loudly on missing permission.

## 4. App — trustworthiness protocol + report wiring

- [ ] 4.1 Add the per-renderer no-op / identical-content baseline pass (design D5) measured the same way; surface it for offset subtraction.
- [ ] 4.2 In `App/BenchmarkRunner.swift`, write the new report fields (calibration outcome, capture cadence / frame-quantized resolution); when the probe can't run or calibration fails, still write memory + environment and mark latency unavailable/untrustworthy.
- [ ] 4.3 Confirm `make bench` runs both renderers and the JSON report carries the new fields; keep the routine `make test` prompt-free (benchmark e2e stays opt-in).

## 5. Verification harness

- [ ] 5.1 Update the performance-harness e2e (`AppUITests/XttyPerformanceHarnessUITests.swift`) so the benchmark-report assertion covers the timebase-calibration outcome and a real latency distribution where the capture path ran (or the unavailable/untrustworthy marker otherwise). Keep it opt-in via `XTTY_RUN_BENCH_E2E`.
- [ ] 5.2 Regenerate the Xcode project if files were added (`xcodegen generate`); run `make test-core` then `make test` green.

## 6. Run the A/B + capture the P7 verdict

- [ ] 6.1 With the built-in display refresh pinned and `XTTY_SIGN_IDENTITY=xtty-dev`, run `make bench` for CoreGraphics and Metal; collect the distributions + calibration outcome + no-op baselines.
- [ ] 6.2 Write the P7b renderer-verdict doc in `research/03-analysis/` (keep CoreGraphics / flip Metal / escalate to Phase 8), grounded in the numbers + the shared-throttle finding; note whether the calibration gate passed on macOS 26.2.

## 7. Reconcile + validate

- [ ] 7.1 Update `performance-harness`'s Purpose "Known limitation (P7a)" note to reflect the trustworthy probe (at archive); reconcile AGENTS **Current status**/**Next** + `research/04-design/02-milestones.md` Phase 7 + `research/README.md`.
- [ ] 7.2 `openspec validate add-trustworthy-latency-probe` clean; full test suite green.
