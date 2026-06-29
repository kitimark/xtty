## Context

P7a's harness is sound except for its latency probe: `App/LatencyProbe.swift` polls `SCScreenshotManager.captureImage` in a loop, and each capture costs ~20 ms — larger than the ~8–16 ms key-to-photon signal — so the first post-keystroke capture already contains the glyph and p50 floored near the capture interval, identical across renderers. The P7 gate (keep CoreGraphics / flip Metal / escalate to Phase 8) needs an instrument that resolves at least whole-frame differences.

The P7b explore session (`research/03-analysis/p7-measurement-methodology.md` → P7b addendum) resolved all the open questions: a continuous `SCStream` reading each frame's presentation timestamp escapes the polling floor fork-free, the clock domains reconcile with one conversion, and — the load-bearing context for the *verdict* — both renderers sit behind a shared ~16.67 ms output-coalescing throttle (`queuePendingDisplay`, SwiftTerm `AppleTerminalView.swift`), so the renderer A/B is expected to be a wash. This change builds the instrument; the verdict it produces is a research output.

## Goals / Non-Goals

**Goals:**
- Replace the polling probe with a continuous `SCStream` + per-frame `displayTime` probe that resolves whole-frame deltas, **fork-free** (no SwiftTerm change), reusing ~90% of P7a.
- Make the timing **correct** (same clock domain) and **trustworthy** (startup calibration gate, many-trial distribution, per-renderer no-op baseline), with the frame-quantized resolution reported honestly.
- Run the CoreGraphics-vs-Metal A/B with the new probe and capture the P7 renderer verdict in `research/`.

**Non-Goals:**
- A custom Metal renderer (Phase 8) — this change *informs* that gate, it doesn't open it.
- An absolute, hardware-grade key-to-photon number — software-on-glass is valid for the renderer *delta* (the omitted tail cancels); a photodiode rig is explicitly not built.
- Reliable cross-app comparator latency — Terminal.app is a best-effort stretch; iTerm2/Warp are out (Secure Event Input).
- Changing the memory sampler, scenario set, renderer toggle, or any user-facing behavior. New user config keys are out of scope.

## Decisions

### D1 — Continuous `SCStream` + per-frame presentation timestamp (not polling, not an engine present-hook)
Set up one long-lived `SCStream`; in `stream(_:didOutputSampleBuffer:of:)` read each frame's timestamp. Frames are produced by the window-server/SCK pipeline and delivered async, so the capture cost no longer serializes into the measurement — the 20 ms floor vanishes.
- *Alternative — keep `SCScreenshotManager` polling:* rejected; that is exactly the floored P7a probe.
- *Alternative — fork SwiftTerm to timestamp at `present(drawable)` / end of `draw(_:)`:* rejected on two grounds — it would **miss** macOS drawable-queue/compositor latency (timestamping before the frame reaches glass), and it breaks the project's fork-free stance. Measuring on-glass *correctly includes* any swap-queue latency a renderer incurs. (Moot regardless: SwiftTerm's Metal path self-limits to one in-flight frame via `DispatchSemaphore(value: 1)`, so there is no triple-buffer inflation to hunt.)

### D2 — Clock: anchor t1 on `SCStreamFrameInfo.displayTime`, t0 on `mach_absolute_time()`, normalize both via `CMClockMakeHostTimeFromSystemUnits`
`displayTime` is a mach-absolute value in **system units (ticks)** — the compositor's scheduled scan-out time, the best photon proxy. The P7a bug is a unit mismatch: it subtracted `displayTime`-style ticks from `DispatchTime.now().uptimeNanoseconds` (nanoseconds) — off by the timebase (125/3 ≈ 41.67× on this M1 Pro). Fix: take `t0 = mach_absolute_time()` at the `CGEvent` post and run **both** t0 and t1 through the identical `CMClockMakeHostTimeFromSystemUnits(_:).seconds` so the domain is provably the same.
- *Alternative — `CMSampleBufferGetPresentationTimeStamp` + `CMTimeSubtract` against `CMClockGetHostTimeClock()`:* acceptable fallback (host-clock CMTimes, no tick math), but PTS is capture/presentation time rather than display time; prefer `displayTime`, cross-check both in the spike.
- *Never* compare `CACurrentMediaTime()` against PTS/`displayTime` (the Forum-785046 epoch anomaly surfaces there).

### D3 — Change detection: first `.complete` frame after t0, blink-guarded, cropped
`minimumFrameInterval` is a rate *cap*, not a cadence — SCK emits a `.complete` frame only when content changes, so the **next `.complete` frame after t0 is the rendered keystroke** (skip `.idle`/`.started`). Reuse P7a's two-consecutive-changed-frame blink guard, now on the `CVPixelBuffer` (the FNV-1a hash logic carries over). Crop a small `sourceRect` to the cell the keystroke paints (tighter signal, cheaper diff) and keep the caret hidden (an independent dirty-rect source).

### D4 — Startup epoch-calibration gate
Before measuring, capture one steady `.complete` frame and compute `offset = (mach now, seconds) − (frame displayTime, seconds)`; assert it is ~0 and stable. On failure (the DTS-acknowledged Forum-785046 epoch anomaly), mark latency **untrustworthy** and emit no absolute numbers — memory still reports. Relative renderer deltas survive a constant offset; absolute key-to-photon does not, so this gate is the must-validate-first item.

### D5 — Trustworthiness protocol: many phase-dithered trials + a renderer-independent overlay-stimulus baseline
The expected delta is sub-frame-to-~1-frame and the measurement is frame-quantized, so a single trial often reads zero. Run many trials (reuse `-BenchmarkTrials`), let t0's phase drift naturally relative to vsync, and compare **percentile distributions**, not means. Additionally measure a **renderer-independent reference-stimulus baseline** the same way: a small AppKit/CoreAnimation overlay strip (`ProbeOverlay`, a full-width strip at the bottom of the window, clear of the prompt and guaranteed visible in the downscaled capture) whose layer color the probe toggles (snap change, implicit animation disabled) with t0 at the toggle and t1 at the changed frame's `displayTime`. Because the overlay is a plain CA layer — not the SwiftTerm renderer — its keystroke-free flip→glass latency is the **capture/compositor/scheduling floor common to both backends**, so it contextualizes how much of the glyph latency is that floor vs. the terminal pipeline (incl. the renderer). *Caveat (chosen with eyes open):* the overlay's own draw path is not identical to the terminal renderer's, so this is a common-path **reference**, not a perfect renderer-isolating subtraction; the in-session two-renderer A/B remains the primary signal, and a renderer-specific dispatch offset is legitimately part of the renderer's user-perceived latency.

### D6 — `SCStreamConfiguration` for a latency probe
`minimumFrameInterval = CMTime(1, 120)` (authorize full refresh; cadence is content-driven anyway), `queueDepth = 8` (deepest pool so no stall masks the trigger frame), `showsCursor = false`, `pixelFormat = kCVPixelFormatType_32BGRA` (CPU-readable, no YUV convert), small `sourceRect` at the target cell (×2 backing), `capturesAudio = false`. Keep P7a's **window-scoped** `SCContentFilter(desktopIndependentWindow:)` (xtty stays on the built-in display); a **display-scoped** `SCContentFilter(display:)` is the documented robustness fallback. For a stable cadence the run pins the built-in display refresh rate (a manual run-condition, not code).

### D7 — Concurrency
Keep the probe `@MainActor`; add an `SCStreamOutput` delegate whose `didOutputSampleBuffer` runs on a sample-handler queue. Inside the callback extract only status + timestamp + pixel hash and **return immediately** (do not retain the `CMSampleBuffer`/IOSurface — that starves the pool and drops the trigger frame). Cross results back to the awaiting trial via a continuation / `AsyncStream`, respecting actor isolation (buffers are non-Sendable).

### D8 — Reuse vs replace (scope discipline)
Reuse unchanged: the `renderer` A/B toggle + `-UITestRenderer`, `postKey` type/undo cadence, `makeCaptureTarget`'s filter/config base, caret-hide + first-responder prep (`benchmarkPrepareForProbe`), the `BenchResult`/`LatencyStats` model + percentiles, `make bench`, `-Benchmark` wiring, and the whole **memory** half (untouched). Replace only `measureOnce` + `captureHash`. Add the `SCStream` lifecycle, the delegate, the clock conversion, calibration, the no-op baseline, and likely one `LatencyProbeError` case. `XttyCore.PerformanceModel` gains latency-measurement-provenance fields (calibration outcome + capture cadence) — Codable, view-free, unit-tested.

### D9 — Comparators are a stretch, not the gate
Same-app CoreGraphics-vs-Metal A/B is the must-have (no extra grant, no foreign cooperation). Cross-app capture is trivial (match `SCWindow.owningApplication.bundleIdentifier`) but injection needs Accessibility and is blocked by iTerm2's default-on Secure Event Input (silent key drop). Implement Terminal.app-first only if cheap; document iTerm2/Warp as may-be-blocked.

### D10 — The renderer verdict is a research artifact, not a spec
The spec deliverable is the trustworthy instrument + the report fields. Running the A/B and writing the keep-CoreGraphics-or-not verdict is a task that lands in `research/03-analysis/` (and updates `performance-harness`'s Purpose "Known limitation (P7a)" note at archive). Specs record what the harness *is*, not the measured numbers.

## Risks / Trade-offs

- **Epoch anomaly (Apple Forum 785046)** → D4 startup calibration gate; relative deltas survive a constant offset.
- **Frame-quantized resolution + ProMotion VRR** (effective resolution = one refresh interval, variable; `displayTime` is compositor-production not panel photons) → pin the built-in display refresh rate, log inter-frame deltas, report frame-quantized with explicit error bounds; aggregate many trials.
- **Sub-frame delta reads as zero on single trials; full-pipeline jitter > 8 ms** → percentile-distribution comparison + no-op baseline; the verdict is explicitly empirical.
- **Constant scheduling offset masquerading as a renderer delta** (AppKit CA-commit vs MTKView draw) → D5 per-renderer no-op baseline, subtract before attributing.
- **Surface-pool starvation inflating latency** → D7 return immediately from the callback; `queueDepth = 8`.
- **TCC re-prompt on rebuild** (ad-hoc signing) → build with the existing `XTTY_SIGN_IDENTITY=xtty-dev` so the Screen-Recording grant persists.
- **Non-Sendable `SCStream`/buffers across the queue↔trial boundary** → continuation/`AsyncStream`, respect `@MainActor` isolation.
- **Comparator injection blocked silently** (iTerm2 Secure Event Input) → quarantine as best-effort, Terminal.app first, fail loudly if injection can't be confirmed.

## Migration Plan

DEBUG-only, internal to the harness — no shipping or user-facing change. Rewrite `LatencyProbe` internals in place; `BenchmarkRunner`/`make bench`/the report consumers keep their shape (report gains fields). Rollback is reverting `LatencyProbe.swift` + the additive `PerformanceModel` fields; the memory half is independent and unaffected. Validate the calibration gate on macOS 26.2 **before** trusting absolute numbers; if it fails, ship the probe as relative-only and mark absolutes untrustworthy.

## Open Questions

- `displayTime` vs `CMSampleBufferGetPresentationTimeStamp` — which tracks photon emission with lower jitter? Cross-check both on the same frame during the spike; D2 prefers `displayTime`.
- Pixel-change detection source — `CVPixelBuffer` base-address hash vs the `.dirtyRects`/`.status` attachment; confirm a cropped `sourceRect` stays sensitive at stream cadence.
- Keep the old `SCScreenshotManager` path as a no-permission fallback, or drop it once the stream path lands? (Leaning drop; the report already degrades to an explicit unavailable marker.)
