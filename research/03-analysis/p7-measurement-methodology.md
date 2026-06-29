# P7 measurement methodology & scope — explore findings

> **Provenance:** Explore session 2026-06-29 (`/opsx:explore p7`), grounded by a medium-depth codebase survey (Explore subagent) and read-only environment checks (codesigning identities + installed comparator terminals). **No code was written** — this captures the *measurement methodology* and *scoping* decisions for the **P7 "Polish + MEASURE" gate** before any change is proposed. The renderer's *availability* was already de-risked in the [SwiftTerm Metal renderer spike](swiftterm-metal-renderer-spike.md); this doc is the measurement plan that spike explicitly deferred to "the P7 gate."

> _Topic scope:_ How to measure xtty's input latency + memory footprint for the P7 decision gate (keep CoreGraphics vs. flip SwiftTerm's Metal path vs. escalate to a custom Phase-8 renderer), what *bar* to measure against, and how to split P7 into OpenSpec changes. Background on the latency-vs-throughput tradeoff is in [Performance — Latency vs Throughput](../02-internals/06-performance-latency.md); the staged Level-3→Level-1 renderer decision is in the [stack sketch](../04-design/01-stack-sketch.md).

## Why P7 is a different kind of milestone

Every milestone P0–P6 added **observable behavior**. P7 does not: its deliverable is **numbers + a decision**, and the one thing it gates is the *conditional* Phase 8 (own Metal renderer). Its only real build content is **instrumentation** — a reusable measurement harness — not a user-facing feature.

```
                         ┌──────────────────────────────┐
   the gate logic  ─────▶│ measure CoreGraphics (today)  │
                         └───────────────┬──────────────┘
                            passes bar? ──┴── short?
                              │                    │
                         ✅ DONE            flip setUseMetal(true)
                       (skip P8)            + tune frame pacing
                                                   │
                                            re-measure
                                          passes? ──┴── still short?
                                            │               │
                                       ✅ adopt Metal    ➡ Phase 8
                                       (or stay CG)     (own MTKView)
```

## Finding 1 — the bar is undefined; set it *relative*

- ❓ **M1/M4 are deliberately qualitative.** [Requirements](xtty-requirements.md) say *"Low memory footprint — nowhere near Warp's ~300 MB–1 GB"* (M1) and *"Native macOS + Metal renderer, latency-first"* (M4). **No numeric threshold exists.** So P7's *first* task is to **define** the bar, not just hit it.
- ✅ **Comparators are installed on the dev machine:** Warp, iTerm2, Terminal.app (❌ **no Ghostty** — install later if a GPU-terminal comparator is wanted). Warp is the explicit **memory anti-target**; Terminal.app is the macOS latency reference (Dan Luu measured it among the lowest median key-to-photon on macOS).
- ✅ **Decision: use a *relative* bar, not an absolute ms/MB.** "Lean + fast" is inherently a comparison, and a relative bar sidesteps defending an arbitrary number. Proposed wording: **latency** p50 ≤ Terminal.app on the same display, p99 within ~1 refresh interval of it; **memory** well under iTerm2/Warp at the same workload. Measure all comparators on the *same* MacBook in the same session.

## Finding 2 — latency capture: a fork-free in-process screen-capture probe

> **⚠️ Superseded in part — see the [2026-06-29 addendum](#addendum-2026-06-29--building-p7a-the-screenshot-polling-latency-probe-is-too-coarse) below.** The screen-capture *approach* shipped fork-free as planned and the **memory** half delivered, but building it disproved the "A/B delta is exact" claim for a *polling* probe: each screenshot costs ~20 ms, exceeding the latency signal. Trustworthy latency is deferred to P7b.

- ❓ **No present-timestamp hook exists today** (survey): no `CVDisplayLink`/`CADisplayLink`/`mach_absolute_time`/FPS/latency code anywhere in `App/` or `XttyCore/`.
- A *precise* present timestamp would require a **per-renderer SwiftTerm patch** — `draw(_:)` for CoreGraphics, present-drawable for the Metal path — shipped via the existing `patches/swiftterm/` mechanism (as the P4b-2 accessors were). That's two patches + maintenance, and it *still* excludes hardware latency.
- ✅ **Decision: primary instrument = inject a synthetic `CGEvent` (t0) → poll the window's pixels (ScreenCaptureKit, fallback `CGWindowListCreateImage`) until the glyph changes (t1); latency = t1 − t0.** This is **fork-free, renderer-agnostic, and automatable**, and it captures *more* of the real stack (app → compositor → window-server) than an internal draw hook would. It excludes the ~20 ms constant hardware tail (keyboard/USB/monitor pixel response) — **acceptable, because that tail is identical for CoreGraphics and Metal, so the A/B *delta* is exact**, which is exactly what the gate needs. Reserve a SwiftTerm patch only if sub-frame precision the capture loop can't deliver is ever required.
- ⚠️ **Two macOS traps the probe must be able to catch** ([performance research](../02-internals/06-performance-latency.md)): (1) a **fixed-rate repaint timer** (the VTE 40 Hz mistake) — if SwiftTerm's CoreGraphics path repaints on a clock rather than per-input, that's a latency bug the probe should expose; (2) **CAMetalLayer drawable depth** — default triple-buffering silently adds 30–50 ms, so if Metal is flipped, check `maximumDrawableCount` / `CVDisplayLink` scheduling *before* concluding "Metal is slow."

## Finding 3 — memory capture is cheap; capture ≠ report

- ✅ **Memory is easy:** sample `task_info` resident footprint under **fixed scenarios** — 1 pane idle → N panes → a full-scrollback flood → an alt-screen app (vim/htop). Cheap enough to ride the existing dump timer.
- ✅ **The DEBUG state-dump seam is for *reporting*, not *capturing*.** `TerminalWindowController.writeStateDump()` (`App/TerminalWindowController.swift:606–659`) runs on a **0.15 s** timer (`AppDelegate.startUITestDump`, `App/XttyApp.swift:156–182`) — far too coarse for key-to-photon. Memory sampling and *aggregate* latency stats (p50/p99) can be surfaced as new dump fields (`memoryMB`, `latencyP50Ms`, …); the latency **capture** needs its own high-res mechanism (Finding 2).
- ✅ **Scrollback cap already enforced:** default 10 000 / hard ceiling 100 000 (`XttyConfigLoader.swift` `scrollbackMax`; applied via `TerminalConfigurator.apply` → `changeScrollback`). The memory pass confirms it saturates rather than re-implements it.

## Finding 4 — the renderer toggle slots in cleanly

- ✅ A **`renderer = coregraphics|metal`** config key fits the existing **base-only** pattern (exactly like `git-review-layout` / `confirm-close`), resolved in `XttyConfigLoader.resolveSet`. Add a `-UITestRenderer` launch arg for **rebuild-free A/B**. Wire it to SwiftTerm's `setUseMetal(_:)` (`Mac/MacTerminalView.swift:247`) **after** the view is in a window (the spike's documented precondition).

## Finding 5 — distribution is blocked *and* orthogonal → defer it

- ❌ **`security find-identity -v -p codesigning` → 0 valid identities** on the dev machine. Hardened Runtime + Developer ID + notarization is **impossible today** without a paid Apple Developer account (~$99/yr) + a Developer ID cert.
- ✅ Distribution is **orthogonal to the gate** (it doesn't depend on or inform the renderer decision). **Decision: split P7-distribution into its own later change and defer it** until the account exists. P7-the-gate is purely *measure → decide → memory pass*.

## Recommended split into changes

| | Change | Gate-critical? | Notes |
|---|---|---|---|
| **P7a** | `add-latency-memory-harness` | ✅ yes | screen-capture latency probe + `task_info` memory sampler + fixed scenarios + the `renderer` config key/arg + a Makefile `bench` target + new dump fields. **Fork-free.** Reusable regression guard. |
| **P7b** | renderer decision | ✅ yes | run the A/B + comparators (Terminal.app/iTerm2/Warp) → a decision doc → keep CoreGraphics / adopt Metal / escalate to Phase 8 |
| **P7c** | memory / leak pass | partial | Instruments retain-cycle + leak audit; confirm scrollback cap + glyph-atlas behavior |
| — | distribution | ❌ **deferred** | Hardened Runtime + Developer ID + notarization — needs the paid account (Finding 5) |

**Recommendation: scope the first proposal to P7a alone** — it is the only true prerequisite for the gate and the only part with real engineering content. Let the *numbers* P7a produces drive whether P7b concludes "done, skip P8" or "escalate to Phase 8."

## Open questions (to finalize in the P7a proposal/design)

- ❓ **Latency target wording** — leaning *relative* (≤ Terminal.app on the same display) over a hard ms.
- ❓ **Capture API** — leaning **ScreenCaptureKit** (macOS 12.3+, frame callbacks) as primary, with `CGWindowListCreateImage` as a legacy fallback.

## Addendum (2026-06-29) — building P7a: the screenshot-polling latency probe is too coarse

Implementing P7a (`add-latency-memory-harness`) and **running it on the dev machine** (MacBookPro18,3, macOS 26.2, 120 Hz) settled two things the plan had only assumed:

- ✅ **Memory measurement fully delivers — and the M1 goal looks met.** Per-scenario (each measured from a clean single-pane reset): idle **~66–69 MB**, 4 panes ~100–109 MB, a *saturated* 20k-line scrollback ~123–136 MB, alt-screen ~116–136 MB; Metal costs ~10–15 MB more than CoreGraphics. All **far** under Warp's ~300 MB–1 GB (the M1 anti-target) — xtty is squarely lean-native. (`task_info` `phys_footprint`.) An adversarial review caught that the scenarios were initially measured *cumulatively* — flood/alt sampled with `multiPane`'s 4 panes still open — which made `flood` read *lower* than 4-pane; fixed by resetting to one clean pane before each scenario, after which the numbers became monotonic and sensible.
- ❌ **The screenshot-polling latency probe cannot resolve key-to-photon latency.** `SCScreenshotManager.captureImage` costs **~20 ms per call — larger than the ~8–16 ms signal** — so the first post-keystroke capture already contains the rendered glyph; the probe reported a nonsensical p50 ≈ 0 ms. (`CGWindowListCreateImage`, the originally-planned synchronous fallback, is **unavailable** on the macOS 26 SDK — it doesn't compile — forcing the SCK path.) The cursor-blink two-frame guard was also insufficient (captures are faster than the caret's ~500 ms half-period), separately fixed by hiding the caret during the probe — but that didn't rescue the fundamental resolution problem.

### 3× benchmark run (means of 3 iterations per renderer; `make bench` + `/usr/bin/time -l`)

| Metric | CoreGraphics | Metal |
| --- | --- | --- |
| Latency p50 / p95 / p99 (ms) — *coarse* | 54.4 / 60.4 / 126.4 | 54.4 / 109.1 / 129.0 |
| Memory idle 1 pane (`phys_footprint`) | **67.9 MB** | 64.3 MB |
| Memory 4 panes | 99.7 MB | 106.9 MB |
| Memory scrollback flood (saturated 20k) | 122.0 MB | 134.4 MB |
| Memory alt-screen | 114.0 MB | 134.9 MB |
| CPU whole run (user + sys) | 1.66 + 0.23 s | 1.65 + 0.24 s |
| Peak RSS (`time -l` max resident) | 234 MB | 240 MB |
| **Idle** (plain instance, no probe) | **0.0 % CPU**, ~132 MB RSS / ~68 MB footprint | same |

Reads (✅ trustworthy / ⚠️ caveated):
- ✅ **Idle CPU = 0.0 %** — no busy-loop at rest (the Warp complaint); xtty passes.
- ✅ **Lean memory** — ~64–68 MB idle footprint, ≤135 MB even with saturated scrollback; far under Warp's 300 MB–1 GB (M1 met).
- ✅ **CoreGraphics vs Metal:** CPU identical; Metal costs **~7–20 MB more** under load; latency **indistinguishable** → no reason to leave CoreGraphics on these numbers (the real verdict is P7b, with a real latency probe).
- ⚠️ **Two "memory" numbers, different meanings:** *footprint* (`phys_footprint`, ~68 MB idle = Activity Monitor's "Memory", private/dirty pages — the representative figure) vs *peak RSS* (~234 MB — includes shared framework pages **plus the benchmark's own ScreenCaptureKit probe buffers + the flood**; *not* normal-use memory). The plain idle instance (132 MB RSS / 68 MB footprint, no probe) is the realistic resident figure.
- ⚠️ **Latency ~54 ms is the capture floor, not real key-to-photon** (≥2 screenshots × ~20 ms per trial); p50 is identical across renderers because the probe can't resolve the difference — see the coarseness finding above.

### Operational finding — running the latency probe re-prompts for Screen Recording (ad-hoc signing); a stable self-signed identity fixes it

The latency probe calls ScreenCaptureKit, which requires the **Screen Recording** TCC grant. Because xtty is **ad-hoc signed** ("Sign to Run Locally"), its code identity (cdhash) changes on **every rebuild**, so macOS keys the grant to a different identity each time and **re-prompts on every build** — disruptive when iterating on the probe. Fix (a local dev convenience, *not* committed signing config): a **stable self-signed code-signing certificate** (`scripts/create-signing-cert.sh` → `xtty-dev`) plus an opt-in `XTTY_SIGN_IDENTITY` Makefile override. With a stable cert the designated requirement becomes `identifier "com.xtty.app" and certificate leaf = H"…"` (cert-based, not cdhash) — **verified persistent across two rebuilds with zero re-prompts**. Notes from the experiment: macOS `security` can't import a LibreSSL/OpenSSL-3 **PKCS#12** ("MAC verification failed") — import a combined key+cert **PEM** instead; an untrusted self-signed cert (`CSSMERR_TP_NOT_TRUSTED`, excluded from `find-identity -v`) **still signs fine** (trust only affects Gatekeeper verification, not signing). The default build stays ad-hoc/portable (CI + other devs unaffected). This is the lightweight slice of the deferred P7-distribution signing work; full **Hardened Runtime + Developer ID + notarization** remain deferred. The **harness e2e** sidesteps the prompt entirely by gating the benchmark test behind `XTTY_RUN_BENCH_E2E=1`, so routine `make test` is prompt-free without any signing setup. **Formalized as the `add-local-signing-identity` OpenSpec change** (a `build-workflow` spec delta — an opt-in `XTTY_SIGN_IDENTITY` build override + the creation helper, leaving the committed default ad-hoc); see `openspec/changes/.../add-local-signing-identity/` and AGENTS → Building.

**Decision (revised):** P7a ships as the **memory + renderer-A/B + report-infrastructure** harness; the latency probe is retained but **documented coarse/experimental** (it exercises the full input→render→capture path and is a useful regression smoke-test, not a latency oracle). A **trustworthy** key-to-photon probe — an `SCStream` delivering per-frame **presentation timestamps**, or an engine present-hook (the fork route) — and the actual **CoreGraphics-vs-Metal latency verdict** move to **P7b**, which always owned the renderer decision and was gated on trustworthy latency anyway. The relative-bar method (compare against Terminal.app/iTerm2/Warp) still stands for P7b. The `renderer = coregraphics|metal` config key + `make bench` + the JSON report shape are reusable by P7b as-is. **→ P7b's methodology is now researched in full — see the [P7b addendum](#addendum-2026-06-29--p7b-the-trustworthy-probe-methodology-the-renderer-is-a-wash-the-throttle-is-the-lever) below; it adds the SCStream-`displayTime` design, the clock-unit fix, and the headline finding that the renderer choice is dominated by a shared output-coalescing throttle.**

## Addendum (2026-06-29) — P7b: the trustworthy-probe methodology; the renderer is a wash, the throttle is the lever

> **Provenance:** Explore session 2026-06-29 (`/opsx:explore p7b`), grounded by (1) a hands-on read of the pinned SwiftTerm checkout (`external/SwiftTerm` @ `v1.13.0` + xtty's `xtty-accessors.diff`), (2) a 14-agent research workflow over the 7 open questions (parallel research → adversarial verify → synthesis), and (3) two backfill research agents (`promotion`, `hardware-validity`, which the workflow's structured-output stage dropped). **No code was written** — this captures the P7b *measurement methodology* + the renderer reframe before any change is proposed. It resolves all the [Open questions](#open-questions-to-finalize-in-the-p7a-proposaldesign) above and supersedes the P7a apply addendum's "trustworthy probe = TBD" note with a concrete design.

### Headline reframe — the renderer choice is dominated by a shared output-coalescing throttle

Reading the SwiftTerm draw paths settled the gate more than any number will. The keystroke-echo path is:

```
feed(text:)  ← PTY output, incl. the echo of what you typed
  └─ feedFinish() → queuePendingDisplay()      ⏱  ~16.67 ms (1/60 s) COALESCING THROTTLE  (fps60 = 16670000 ns)
        └─ (after up to one throttle window) updateDisplay()
              ├─ Metal on:  requestMetalDisplay() → MTKView.setNeedsDisplay
              └─ Metal off: setNeedsDisplay(region) → NSView.draw(_:)
```

- ✅ **The A/B is symmetric.** No fixed-rate repaint timer (the VTE 40 Hz mistake) — the only `Timer`s are a 15 s OSC-progress one-shot and a drag-autoscroll timer, neither per-keystroke. Both backends sit behind the *same* `queuePendingDisplay` throttle and are poked from inside the same `updateDisplay`, diverging only at the final invalidation dispatch. The throttle is a **constant common term → it cancels in the CoreGraphics↔Metal delta**, exactly like the omitted hardware tail. (`setNeedsDisplay(_:)` override at `MacTerminalView.swift:642` is dead — `#if false`.)
- ⚠️ **But the throttle — not the renderer — is xtty's dominant latency lever.** An isolated keystroke echo waits **0–16.67 ms (avg ~8.3 ms)** in that window before *either* backend draws; the renderer only affects the small render+present tail *after* it. So the expected verdict is not merely "CG ≈ Metal" but "**CG ≈ Metal because both are dominated by a shared ~16.67 ms coalescer.**" If latency ever becomes the priority, the highest-leverage change is that throttle (immediate-draw on small interactive output / a shorter or adaptive window) — an **engine/patch concern, orthogonal to the renderer choice.**

### The instrument — on-glass `SCStream` `displayTime`, not a present-hook, not polling

- ✅ **Replace P7a's polling (`SCScreenshotManager.captureImage`, ~20 ms/call) with a continuous `SCStream`.** Frames arrive async on `stream(_:didOutputSampleBuffer:of:)`, each self-stamped, so the per-capture cost no longer serializes into the measurement — the 20 ms floor vanishes. `minimumFrameInterval` is a *cap, not a cadence*: SCK emits a `.complete` frame **only when on-screen content changes**, so the **next `.complete` frame after t0 *is* the rendered keystroke** (no scanning; `.idle` frames dominate a static terminal and are skipped for free).
- ✅ **Measure on-glass, never at an internal `present()` hook.** On-glass `displayTime` *correctly includes* any renderer-specific swap-queue latency (it would *see* a triple-buffer trap as a larger delta — the right answer); a present-hook would *miss* it. Moot anyway: SwiftTerm's Metal path self-limits to **one in-flight frame** (`DispatchSemaphore(value: 1)` in `MetalTerminalRenderer`), so there is no triple-buffer inflation regardless of `maximumDrawableCount`. This kills the fork/present-hook route on its own merits.
- ❌ **Clock-unit bug to fix (load-bearing).** `SCStreamFrameInfo.displayTime` is mach **ticks** (raw `mach_absolute_time` units); P7a's `DispatchTime.now().uptimeNanoseconds` is **nanoseconds** — off by the timebase (**125/3 ≈ 41.67×** on this M1 Pro), which would dwarf the ~8 ms signal. Fix: run **both** t0 (`mach_absolute_time()` at the `CGEvent` post) **and** t1 (`displayTime`) through the **identical** `CMClockMakeHostTimeFromSystemUnits(_:).seconds` call. (Acceptable alternative: `CMSampleBufferGetPresentationTimeStamp` + `CMTimeSubtract` against a `CMClockGetHostTimeClock()` t0 — host-clock CMTimes, no tick math; but PTS is capture/presentation, `displayTime` is the better scan-out/photon proxy.)
- ❓ **Epoch gate (must validate first).** Apple Forum 785046 reports SCK timestamps occasionally reading in a different epoch (`now − PTS` negative), DTS-acknowledged/unresolved. **Startup self-calibration:** capture one steady `.complete` frame, assert `mach_now − displayTime ≈ 0/stable` on macOS 26.2. If it fails, the probe is still good for *relative* deltas; absolute key-to-photon must be marked untrustworthy.

### Resolution / validity — frame-quantized, but the decision is robust to it

- ❌ **Verify refuted "fine-enough on ProMotion."** Effective resolution = **one refresh interval (~8.33 ms @ 120 Hz), and VRR-variable** (after idle the panel runs slow → the first post-keystroke interval is long + jittery). `displayTime` is compositor *scheduled scan-out*, not panel photons. → can rank "~a frame apart," likely **can't prove a sub-frame win**. Mitigate: **pin the built-in display to a fixed refresh rate** (System Settings ▸ Displays) for the run; crop a small **`sourceRect`** at the target cell; aggregate **many phase-dithered trials** and compare **percentile distributions**, plus a **no-op/identical-content baseline** per renderer to subtract any constant scheduling offset.
- ✅ **Software-only is valid for the *delta*; no hardware rig needed — and the decision is robust to coarseness by construction.** Either the probe resolves a delta ≳1 frame (clear decision; the omitted monitor tail is renderer-independent → cancels, per Fatin's "independent of CPU/GPU"), *or* it can't (delta is sub-frame → below perception → latency is not a differentiator → either renderer is fine). No outcome where missing hardware precision flips the call. A photodiode cross-check is a nice-to-have (validates the *absolute* number + the clock conversion), not decision-critical.
- ✅ **Recommended `SCStreamConfiguration`:** `minimumFrameInterval = CMTime(1, 120)`, `queueDepth = 8`, `showsCursor = false`, `pixelFormat = 32BGRA`, a small `sourceRect` at the cell (×2 backing), `capturesAudio = false`. Window-scoped `SCContentFilter(desktopIndependentWindow:)` (reuses P7a) is fine since xtty stays on the built-in display; display-scoped `SCContentFilter(display:)` is the robustness fallback. **Do not retain the `CMSampleBuffer`/IOSurface past the callback** (starves the pool, drops the trigger frame).

### Comparators + reuse

- ❌ **Verify refuted "all three comparators reliable."** Capture is app-agnostic (swap the window match for `SCWindow.owningApplication.bundleIdentifier`), but *injection* is fragile: foreign-app `CGEvent` needs the **Accessibility** grant, and **iTerm2 ships `EnableSecureEventInput` on by default → silently drops synthetic keys** (Warp unverified). → **Same-app CoreGraphics-vs-Metal A/B is the must-have**; cross-app is a **Terminal.app-first, clearly-flagged stretch**.
- ✅ **~90 % of P7a's harness carries over** (renderer A/B toggle + `-UITestRenderer`, `postKey` type/undo cadence, `makeCaptureTarget`, caret-hide/first-responder prep, `BenchResult`/`LatencyStats` model + percentiles, `make bench`, `-Benchmark` wiring). **Replace only** `measureOnce`/`captureHash` (the synchronous poll + FNV-1a + `DispatchTime` stamping; the hash logic is reusable on the `CVPixelBuffer`, and the two-frame blink guard must move into the new delegate). **Add** the `SCStream` lifecycle + an `SCStreamOutput` delegate (cross back to the awaiting trial via continuation/AsyncStream; buffers are non-Sendable) + the host-clock t0 alignment + likely one `LatencyProbeError` case. **No `XttyCore.PerformanceModel` shape change** (`captureFrameRate` already exists; optionally re-source it from observed inter-frame PTS deltas).

### Go / no-go

**GO**, scoped tight. Both linchpins survived adversarial verification (the clock fix is a single shared conversion; the continuous stream genuinely escapes the 20 ms floor). No hard blockers; the must-validate-first item is the **startup epoch calibration**. The verdict the probe yields is *empirical* — needs many-trial distribution comparison + a no-op baseline — but it's a focused build on ~90 % reuse. **Expected outcome: keep CoreGraphics, skip Phase 8** (no renderer latency win to justify Metal's +7–20 MB and experimental-code cost), with the throttle noted as the real latency lever for any future work. **P7c** (Instruments leak/retain pass) and **distribution** (Hardened Runtime + Developer ID + notarization) remain separately deferred.

## Sources

- Explore session 2026-06-29 (`/opsx:explore p7b`) — 14-agent research workflow (7 questions → adversarial verify → synthesis) + 2 backfill agents + a SwiftTerm-checkout deep-read. Earlier: explore session 2026-06-29 (`/opsx:explore p7`) + codebase survey (Explore subagent, medium depth).
- SwiftTerm checkout (`external/SwiftTerm` @ `v1.13.0`): `Apple/AppleTerminalView.swift` (`queuePendingDisplay`/`queueMetalDisplay` `fps60 = 16670000` ns throttle ~1703–1740; `updateDisplay` renderer branch ~1567–1631; `feedFinish`→`queuePendingDisplay` 1909–1913), `Mac/MacTerminalView.swift` (`draw(_:)` 653, dead `setNeedsDisplay` override 642 `#if false`, MTKView `isPaused`/`enableSetNeedsDisplay` setup 268–286), `Apple/Metal/MetalTerminalRenderer.swift` (`DispatchSemaphore(value: 1)` 211, plain `commandBuffer.present(drawable)` 521).
- ScreenCaptureKit: `SCStreamFrameInfo.displayTime` (mach-ticks attachment) + `.status` (`.complete`/`.idle`), `SCStreamConfiguration.minimumFrameInterval` (rate *cap*) / `queueDepth` (3–8, default 3), `SCContentFilter(desktopIndependentWindow:)` / `(display:…)`, `CMSampleBufferGetSampleAttachmentsArray`, `CMSampleBufferGetPresentationTimeStamp`. WWDC22 "Meet ScreenCaptureKit" (10156) + "Take SCK to the next level" (10155); WWDC21 "Optimize for variable refresh rate displays" (10147); Apple Forums 785046 (displayTime/PTS clock-domain epoch quirk), 720228 (idle/off-screen frame delivery), 105308/698630/23798 (drawable-count/present-at-vsync latency).
- Clock domain: `CMClockMakeHostTimeFromSystemUnits` / `CMClockConvertHostTimeToSystemUnits`, `CMClockGetHostTimeClock`, `mach_absolute_time` + `mach_timebase_info` (125/3 on Apple Silicon; 1/1 under Rosetta), `CGEventGetTimestamp` (mach-absolute).
- Latency-measurement literature (software-relative validity + the omitted ~26 ms constant tail): Pavel Fatin / Typometer (typing-with-pleasure: tail "independent of CPU/GPU performance"), Dan Luu [term-latency](https://danluu.com/term-latency/) (Typometer-style, "a fraction of total end-to-end") + [input-lag](https://danluu.com/input-lag/) (240/1000 fps camera, hardware constants), Tomscii/Zutty typing-latency, bxt.rs GNOME-46 photodiode rig ("screen capture may return pixels a few ms before/after shown").
- [SwiftTerm Metal renderer spike](swiftterm-metal-renderer-spike.md) — Metal path works in xtty's AppKit host; adoption deferred to this gate; `setUseMetal` precondition (view in window).
- [Performance — Latency vs Throughput](../02-internals/06-performance-latency.md) — latency≠throughput; frame pacing is the dominant lever; the VTE 40 Hz fixed-timer bug; CAMetalLayer drawable-depth +30–50 ms; software vs hardware measurement (~20 ms tail).
- [Stack sketch](../04-design/01-stack-sketch.md) — staged Level-3→Level-1 decision; "drop to Level 1 only if measured latency/memory misses M1/M4 — first try `useMetalRenderer` + frame-pacing tuning."
- [Requirements](xtty-requirements.md) — M1 (lean memory, "nowhere near Warp ~300 MB–1 GB"), M4 (Metal, latency-first).
- Environment checks (2026-06-29): `security find-identity -v -p codesigning` → 0 valid identities; installed comparators: Warp, iTerm2, Terminal.app (no Ghostty).
- Code refs: `App/XttyApp.swift:156–182` (`startUITestDump`, 0.15 s timer, `-UITestGridDump`), `App/TerminalWindowController.swift:606–659` (`writeStateDump`), `XttyCore/Sources/XttyCore/XttyConfigLoader.swift` (`resolveSet`, base-only keys), SwiftTerm `Mac/MacTerminalView.swift:247` (`setUseMetal`).
