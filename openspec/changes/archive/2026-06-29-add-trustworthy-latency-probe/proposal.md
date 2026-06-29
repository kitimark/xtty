## Why

P7a shipped the measurement harness but proved its **latency probe is too coarse to trust**: the one-shot `SCScreenshotManager.captureImage` costs ~20 ms per capture — larger than the ~8–16 ms key-to-photon signal — so it floored at a meaningless p50 and could not distinguish CoreGraphics from Metal. The **P7 gate cannot conclude** (keep CoreGraphics / flip Metal / escalate to a Phase-8 own-renderer) without a latency instrument that resolves at least whole-frame differences. The P7b methodology research (`research/03-analysis/p7-measurement-methodology.md` → P7b addendum) settled how to build one **fork-free**, so it's ready to propose.

## What Changes

- **Replace the screenshot-polling latency probe with a continuous on-screen-capture probe that times key-to-photon from per-frame _presentation/display timestamps_** — the per-capture cost no longer serializes into the measurement, so it resolves whole-frame (~one refresh interval) differences. Mechanism (design): a long-lived `SCStream` whose first post-keystroke `.complete` frame carries the rendered glyph; read that frame's `displayTime`. Fork-free (no SwiftTerm change).
- **Fix the load-bearing clock bug:** time t0 (`CGEvent` post) and t1 (frame timestamp) in the **same mach host-time domain**, normalized through one conversion (the P7a probe subtracted mach *nanoseconds* from mach *ticks* — off by ~41.67× on Apple Silicon).
- **Add measurement-validity safeguards:** a startup **timebase/epoch calibration** gate (fail loudly / mark latency untrustworthy if t0 and frame timestamps can't be reconciled), **many-trial distribution** aggregation, and a per-renderer **no-op/identical-content baseline** to expose any constant scheduling offset.
- **Extend the benchmark report + view-free result model** to record the calibration outcome and the achieved capture cadence / frame-quantized resolution, so latency trustworthiness and time-resolution are explicit (no more silent coarseness).
- **Honestly bound the result:** the report marks latency **frame-quantized** (resolution = one refresh interval, ProMotion-variable); the comparison is sound for the renderer **delta** (the omitted hardware tail is renderer-independent and cancels).
- **Run the CoreGraphics-vs-Metal A/B with the trustworthy probe and capture the P7 renderer verdict** in `research/` (the gate output; expected: keep CoreGraphics — both backends sit behind a shared ~16.67 ms output-coalescing throttle, so the renderer is a wash).
- **Cross-app comparators** (Terminal.app/iTerm2/Warp) remain a **best-effort stretch**, not a must-have (iTerm2's Secure Event Input silently drops synthetic keys).

## Capabilities

### New Capabilities

_None._ This refines the existing P7a harness.

### Modified Capabilities

- `performance-harness`: the **Key-to-photon latency probe** requirement changes from "sample rendered pixels" to "time from on-screen frame presentation timestamps so the per-capture cost does not floor the measurement, resolving at least whole-frame differences, with the resolution reported honestly"; **add** a measurement-validity-safeguards requirement (timebase calibration + many-trial distribution + no-op baseline); the **Benchmark run and results report** and **View-free performance model** requirements gain the calibration outcome + capture-cadence/quantization metadata.
- `verification-harness`: the **Performance-harness end-to-end coverage** requirement extends the benchmark-report assertion to cover the timebase-calibration outcome (and a real latency distribution, not only an unavailable marker, where the capture path ran).

## Impact

- **App layer:** rewrite `App/LatencyProbe.swift` internals (synchronous poll loop → an `SCStreamOutput` delegate + per-frame change detection + host-clock t0 alignment + calibration + no-op baseline); minor `App/BenchmarkRunner.swift` wiring to emit the new report fields. The blink-guard and `postKey`/`makeCaptureTarget`/caret-hide carry over.
- **XttyCore:** extend the Codable `BenchResult`/latency model in `XttyCore/Sources/XttyCore/PerformanceModel.swift` with latency-measurement provenance (calibration outcome, capture cadence). View-free, unit-tested.
- **No new dependency** (ScreenCaptureKit + CoreMedia are system frameworks) and **no new user config key** (reuses the P7a `renderer` key + `-BenchmarkTrials`; trial count / phase-dither are probe internals).
- **Manual/operational:** for a stable cadence, pin the built-in display refresh rate during a run; the Screen-Recording TCC grant persists via the existing `xtty-dev` signing identity. These are documented run-conditions, not code.
- **Research:** the P7b renderer-verdict doc lands in `research/03-analysis/` (gate output); `performance-harness`'s Purpose "Known limitation (P7a)" note is updated at archive to reflect the trustworthy probe.
- **DEBUG-gated, not shipping** (unchanged from P7a): the probe and benchmark mode stay behind `#if DEBUG`.
