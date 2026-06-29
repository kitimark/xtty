## Context

P7 is the measure-and-decide gate before the conditional Phase 8 (own Metal renderer). The explore-phase plan is captured in `research/03-analysis/p7-measurement-methodology.md`; this change is **P7a**, the measurement harness it recommends building first. Today xtty has **no** latency/memory instrumentation (confirmed by survey: no `CVDisplayLink`/`mach_absolute_time`/FPS code anywhere), the requirements M1/M4 have no numeric bar, and SwiftTerm's Metal path — proven *functional* in xtty's AppKit host by the [P2 spike](../../../research/03-analysis/swiftterm-metal-renderer-spike.md) — is not wired to anything. The architecture seam holds: all logic talks to the engine via `XttyCore`, the DEBUG state dump (`TerminalWindowController.writeStateDump`) is the established observability channel, and config keys flow through `XttyConfigLoader.resolveSet`.

This change builds the harness; it does **not** run the comparison or pick a renderer (that is P7b) and does **not** touch distribution (deferred — 0 codesigning identities, orthogonal to the gate).

## Goals / Non-Goals

**Goals:**
- A repeatable, automatable **key-to-photon latency probe** that works identically for both renderers, with **no SwiftTerm fork/patch**.
- A repeatable **resident-memory sampler** over fixed scenarios (idle → N panes → scrollback flood → alt-screen).
- A **rebuild-free renderer A/B toggle** (`renderer = coregraphics|metal` + `-UITestRenderer`), default CoreGraphics.
- A **benchmark run** that writes a machine-readable results report (the gate artifact + regression baseline), with the renderer + last memory sample mirrored into the DEBUG state dump for e2e verification.
- A `make bench` entry point.

**Non-Goals:**
- The renderer **decision/verdict** and capturing competitor (Terminal.app/iTerm2/Warp) numbers — that is **P7b**.
- Instruments retain-cycle/leak audit — **P7c**.
- Hardened Runtime + Developer ID + notarization — deferred to a separate change.
- Changing the shipping default renderer (stays CoreGraphics).
- A hardware (light-sensor) latency rig.

## Decisions

### D1 — Latency probe: in-process screen-capture, not a SwiftTerm present-hook (fork-free)
Inject a synthetic keystroke (timestamp `t0`), then watch the terminal window's **rendered pixels** until they change (timestamp `t1`); `latency = t1 − t0`. **Why over a present-timestamp hook in SwiftTerm:** a precise hook would require a *per-renderer* patch to `external/SwiftTerm` (`draw(_:)` for CoreGraphics, present-drawable for Metal) shipped via the `patches/swiftterm/` mechanism — two patches + maintenance — and would *still* miss the compositor. The pixel probe is **fork-free, renderer-agnostic, and captures more of the real stack** (app → compositor → window-server). It omits the constant hardware tail (~20 ms: keyboard/USB/monitor), so **absolute** latencies read systematically ~20 ms low; the CoreGraphics-vs-Metal **delta**, however, is accurate because that tail is identical for both backends — exactly what the gate needs. (This relies on Core Animation/the compositor treating both backends' presented frames the same way; absolute claims in P7b should be hedged accordingly.) Reserve a SwiftTerm patch only if sub-frame precision is ever required.

### D2 — Capture API: ScreenCaptureKit's one-shot `SCScreenshotManager` (CGWindowListCreateImage is unavailable)
**Reconciled during apply:** `CGWindowListCreateImage` is marked **unavailable** on the current SDK (macOS 26 / Xcode 26.6) — it does not compile — so the probe uses **ScreenCaptureKit**. Rather than an `SCStream` delegate (an async callback machine that complicates a probe whose timing must stay simple), it uses the one-shot **`SCScreenshotManager.captureImage(contentFilter:configuration:)`** (macOS 14+) in an `async` loop: each `await` capture **yields the main runloop**, so the app keeps processing the injected keystroke and rendering between captures (no busy-spin, no blocked main thread). Resolution is frame-granular (D5). Capture needs the **Screen Recording TCC grant** and a visible window; the probe fails loudly with a clear message if denied rather than reporting bogus zeros. (An `SCStream` upgrade for tighter frame timing is a possible future refinement, not needed for P7a's frame-granular A/B.)

### D3 — Input injection: `CGEvent` keyDown/keyUp posted to the app
Synthetic `CGEvent` keystrokes (not XCUITest typing) give deterministic, high-rate, scriptable trials from inside the benchmark mode. The probe **requires the terminal view to be first responder** at injection time (otherwise the key never reaches the PTY and the probe would time garbage); the benchmark setup focuses the active pane and confirms first-responder state immediately before each injection. Each trial: capture a baseline frame of a target cell region → post a printable key → record the first captured frame whose target region differs → `t1`. Many trials → a distribution (p50/p95/p99), because tail latency matters more than the median ([performance research](../../../research/02-internals/06-performance-latency.md)).

### D4 — Pixel-change detection guards against cursor-blink noise
The typed glyph lands at the cursor, where a blinking cursor also toggles pixels. Mitigation: require a *persistent* change across two consecutive captured frames (distinguishing a stable glyph from a one-frame blink) as the **primary, mechanism-agnostic guard**, and take the **median over many trials** so any residual blink coincidence is outlier-rejected. Implementation MUST validate that the two-frame test actually rejects single-frame blinks; disabling cursor blink for the duration of the probe (a view/engine control) is the fallback if it proves unreliable. Surfaced as a risk below.

### D5 — Latency resolution (REVISED after apply: the probe is too coarse)
The original plan assumed frame-quantized resolution (~8 ms at 120 Hz) was acceptable because the deciding differences are frame-granular. **Running the harness disproved this for the screenshot-polling probe:** `SCScreenshotManager.captureImage` costs **~20 ms per call — larger than the ~8–16 ms key-to-photon signal** — so the first post-keystroke capture already contains the rendered glyph, flooring the measurement at roughly one capture interval (the probe reported a nonsensical p50 ≈ 0 ms; crediting the capture-*completion* time lifts the floor but does not restore resolution). **Conclusion:** the screenshot-polling probe cannot resolve key-to-photon latency, so its numbers are **coarse and not trustworthy for the renderer verdict**. A trustworthy probe needs a finer instrument — an `SCStream` delivering per-frame **presentation timestamps** (read the timestamp; don't pay a capture cost per sample), or an engine present-hook — **deferred to P7b** (which owns the renderer decision and was always gated on trustworthy latency). The **memory** half of the harness is unaffected and delivers a real result. See the [P7 methodology research addendum](../../../research/03-analysis/p7-measurement-methodology.md).

### D6 — Memory: `task_info` physical footprint under view-free scenarios
Sample `phys_footprint` (mach `task_vm_info` — what Apple's "Memory" column reports) per scenario. The **scenario set** (idle 1 pane → N panes → scrollback-saturating flood → alt-screen program) is a **view-free, unit-testable** list in `XttyCore`; the app interprets each (spawn panes, emit the flood, start the alt-screen program) and samples after it settles. The scrollback-flood scenario reuses the existing cap (`changeScrollback`) — it confirms boundedness, it does not re-implement it.

### D7 — Renderer toggle: a base-only config key applied after window attach
`renderer = coregraphics|metal` is a **base-only** key (like `git-review-layout`/`confirm-close`), resolved in `XttyConfigLoader.resolveSet`, default `coregraphics`, invalid→default+log. Applied via SwiftTerm's `setUseMetal(_:)` in `TerminalWindowController` **after** the view is in a window (the spike's documented precondition). A `-UITestRenderer coregraphics|metal` launch arg overrides config for rebuild-free A/B (mirrors the existing `-UITest…` override pattern in `XttyApp.applyUITestOverrides`).

### D8 — Benchmark mode: a launch-arg-driven run wrapped by `make bench`
A `-Benchmark` (DEBUG) launch mode runs the latency probe + memory scenarios for the selected renderer, writes a JSON results report (active renderer, capture frame rate, latency p50/p95/p99 + raw samples, per-scenario `phys_footprint`, and an environment block: machine/display/OS), then terminates. `make bench` builds + launches it (twice, once per renderer, for the A/B). The **result model** (and scenario list) is a view-free `XttyCore` type so it is unit-tested and reused by P7b; computing a pass/fail **verdict** against comparator baselines is P7b, but the report's shape is forward-compatible with comparator entries.

### D9 — State-dump additions for e2e
`writeStateDump` gains the active **`renderer`** (`coregraphics`/`metal`) and the most recent **resident-memory sample** (bytes), so XCUITest can deterministically assert the toggle was applied and the sampler produces a positive number — without parsing the bench report. The full latency distribution lives in the report, not the 0.15 s-timer dump (which is too coarse to *capture* latency, only to *report*).

### D10 — Fork-free
No change to `external/SwiftTerm`: the probe uses OS frameworks (ScreenCaptureKit/CoreGraphics), the memory sampler uses mach, and the renderer toggle uses SwiftTerm's **existing public** `setUseMetal`. Nothing here needs an engine accessor (unlike P4b-2).

## Risks / Trade-offs

- **Screen Recording TCC grant required** → the probe fails loudly (not silently zero) when denied; `make bench` documents the one-time grant. Manual/CI runners must have it.
- **Capture needs a visible window on an active display** → ScreenCaptureKit and `CGWindowListCreateImage` cannot capture a minimized/off-screen window or an asleep/headless display; a CI runner needs a real or virtual display. The probe fails loudly and the benchmark then records latency as **unavailable** (still emitting memory + renderer), per the perf-harness spec — never bogus zeros.
- **Cursor-blink false positives in change detection** → disable blink during the probe + require a persistent (two-frame) change + median over many trials (D4).
- **Frame-quantized latency resolution** → acceptable because the deciding differences are frame-granular; the report states the capture frame rate (D5).
- **Synthetic `CGEvent` ≠ real keyboard** → omits the hardware tail; fine for the renderer delta (D1) and for tracking regressions, but absolute "feels instant" claims should be hedged accordingly in P7b.
- **ScreenCaptureKit API churn / `CGWindowListCreateImage` deprecation** → dual path (D2); both are system frameworks, no third-party surface.
- **Benchmark adds DEBUG-only code paths** → all gated `#if DEBUG` + launch args, never in shipping builds (same discipline as the existing `-UITestGridDump` dump).

## Migration Plan

Additive and behind flags. Default renderer unchanged (CoreGraphics); the `renderer` key defaults to CoreGraphics so existing configs are unaffected. The benchmark mode and probe are DEBUG + launch-arg gated. No data migration. Rollback = drop the flagged code; nothing else depends on it yet (P7b/P7c consume the report but are separate changes).

## Open Questions

- **Pass/fail thresholds** are intentionally deferred to P7b (relative bar vs measured comparators); P7a only produces the numbers and the report shape.
- **N for the multi-pane memory scenario** (e.g. 4 vs 8 panes) — pick a representative default in implementation; the scenario list makes it a one-line change.
