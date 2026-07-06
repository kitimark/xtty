# performance-harness — delta for retire-metal-renderer

## REMOVED Requirements

### Requirement: Renderer A/B selection
**Reason**: The P7 renderer gate this A/B toggle existed to feed is closed (P7b, 2026-06-29: keep CoreGraphics, skip Phase 8 — CoreGraphics measured a faster median, much tighter tail, and leaner memory than SwiftTerm's experimental Metal path). With one rendering backend there is nothing to select; keeping a selectable-but-dead backend contradicts the lean bias and forces a Metal-toolchain build dependency.
**Migration**: No user action required — `coregraphics` was already the default, and a legacy `renderer` config key is ignored under `terminal-configuration`'s forward-compatibility rule. If SwiftTerm's Metal path matures, resurrect by reverting the shader-resource patch hunk and re-running the archived P7b methodology (`research/03-analysis/p7-measurement-methodology.md`).

## MODIFIED Requirements

### Requirement: Key-to-photon latency probe

The app SHALL provide a DEBUG-gated, in-process **key-to-photon latency probe** that measures input-to-display latency by injecting a synthetic keystroke and detecting the resulting on-screen change by sampling the **rendered pixels** of the terminal window. The probe SHALL time the interval using the **on-screen presentation timestamp of the captured frame in which the change first appears** — not the wall-clock cost of the capture operation — so that a slow capture path does not floor the measurement; it SHALL be able to resolve at least **whole-frame** (one display-refresh-interval) differences between configurations. The injection time (t0) and the frame presentation time (t1) SHALL be measured or normalized into the **same monotonic clock domain** so that `t1 − t0` is a valid duration. The probe SHALL be independent of the rendering implementation — it observes rendered pixels, not the engine or a renderer API — and SHALL run over many trials to produce a **distribution** (at minimum median and tail percentiles), not a single sample. The probe SHALL NOT require modifying the SwiftTerm engine. It deliberately excludes hardware input/display latency; this is acceptable because the omitted latency is constant run-to-run, so comparisons between runs and configurations remain valid. Because the timing resolution is bounded by the display refresh interval (and is variable on a variable-refresh display), the probe SHALL surface results as **frame-quantized with the achieved time-resolution made explicit**, rather than implying sub-frame precision. When the OS screen-capture permission is unavailable, the probe SHALL fail with a clear error rather than report a bogus measurement.

#### Scenario: Probe produces a latency distribution

- **WHEN** the latency probe runs a configured number of trials in a DEBUG benchmark run
- **THEN** it records one key-to-photon sample per trial and reports aggregate statistics including a median and at least one tail percentile

#### Scenario: Timing comes from the changed frame's presentation timestamp

- **WHEN** a synthetic keystroke is injected and the resulting glyph is drawn
- **THEN** the probe times until the window's rendered pixels change (capturing the full render/composite path) and credits the **presentation timestamp of the first changed frame**, so the measurement is not floored by the cost of the capture operation and resolves to about one display-refresh interval

#### Scenario: Injection and presentation timestamps share a clock domain

- **WHEN** a trial records the keystroke-injection time and the changed-frame presentation time
- **THEN** both are taken or converted in the same monotonic clock domain (correct units), so their difference is a valid duration rather than a unit-mismatched value

#### Scenario: Missing capture permission fails loudly

- **WHEN** the probe runs without the required screen-capture permission
- **THEN** it reports a clear error and does not emit a measurement, rather than recording zero or a fabricated value

### Requirement: Benchmark run and results report

The harness SHALL provide a **benchmark mode**, runnable from a single command, that drives the latency probe and the memory scenarios and writes a **structured, machine-readable results report**. The report SHALL include the active rendering backend, the latency distribution statistics, the per-scenario memory samples, the capture frame rate (so the latency time-resolution is explicit), the **timebase-calibration outcome** (whether the injection and frame-timestamp clocks reconciled, so the latency numbers' trustworthiness is recorded), the **achieved capture cadence and frame-quantized resolution** of the latency measurement, and an environment description (machine, display, OS). When the latency probe cannot run (e.g. the screen-capture permission or a visible display is unavailable) or the timebase calibration fails, the benchmark run SHALL still write the report with the renderer, memory samples, and environment, and SHALL mark the latency section **explicitly unavailable or untrustworthy** rather than omitting the report or aborting the whole run — so memory remains measurable on a headless/permission-less runner. The report SHALL serve as a performance-regression baseline (it was previously also the artifact for the now-closed P7 renderer decision). The benchmark mode SHALL be DEBUG-gated and SHALL NOT run in shipping builds. Producing a pass/fail verdict against comparator baselines is out of scope for this capability.

#### Scenario: Benchmark run writes a results report

- **WHEN** the benchmark mode runs to completion with the latency probe available and the timebase calibration passing
- **THEN** it writes a results report containing the active renderer, the latency distribution statistics, the capture frame rate, the timebase-calibration outcome, the achieved capture cadence / frame-quantized resolution, the per-scenario memory samples, and an environment description

#### Scenario: Benchmark still reports memory when latency is unmeasurable

- **WHEN** the benchmark mode runs where the latency probe cannot run (no screen-capture permission or no visible display) or the timebase calibration fails
- **THEN** the report is still written with the active renderer, the per-scenario memory samples, and the environment, and the latency section is marked explicitly unavailable or untrustworthy

#### Scenario: Benchmark mode is absent from shipping builds

- **WHEN** a non-DEBUG (shipping) build runs
- **THEN** the benchmark mode and the latency probe are not present/active

### Requirement: Latency measurement trustworthiness safeguards

So the latency numbers are trustworthy rather than plausible-but-wrong, the latency probe SHALL apply measurement-validity safeguards beyond producing a distribution. (1) It SHALL perform a startup **timebase calibration** that confirms the keystroke-injection clock and the frame-presentation-timestamp clock reconcile into one domain; if they do not, it SHALL mark the latency results **untrustworthy** (and emit no absolute key-to-photon numbers) rather than report fabricated values. (2) It SHALL also measure a **reference-stimulus baseline** the same way — a known on-screen change produced outside the terminal's rendering path — so that the capture/compositor/scheduling floor can be identified and the terminal's own contribution distinguished from it, rather than the floor being mistaken for terminal rendering latency. These safeguards exist because the measurement is frame-quantized and the effects being tracked are small (sub-frame to about one frame), so an uncalibrated or un-baselined number could report a plausible-but-wrong absolute latency or misattribute the capture floor to the terminal.

#### Scenario: Timebase calibration gates absolute results

- **WHEN** the probe starts and the injection clock and the frame-presentation-timestamp clock cannot be reconciled into one domain
- **THEN** the run marks the latency results untrustworthy and emits no absolute key-to-photon numbers, rather than reporting plausible-but-wrong values

#### Scenario: A reference-stimulus baseline accompanies the benchmark run

- **WHEN** a latency benchmark run executes
- **THEN** the run also carries a reference-stimulus baseline measured identically, so the common capture/compositor floor can be distinguished from the terminal's own rendering contribution
