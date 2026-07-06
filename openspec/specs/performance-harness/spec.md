# performance-harness Specification

## Purpose

Defines xtty's **performance measurement harness** — the instrument behind the P7 measure-and-decide gate (M1 lean memory, M4 latency-first). It covers a fork-free, in-process **key-to-photon latency probe** (synthetic keystroke → on-screen pixel change; independent of the rendering implementation), a **resident-memory sampler** over a fixed, independently-reset scenario set (idle / multiple panes / saturated scrollback / alt-screen), a DEBUG **benchmark run** that writes a machine-readable results report (a performance-regression baseline; previously also the P7-decision artifact), and a view-free result model in `XttyCore`. The **CoreGraphics↔Metal renderer A/B toggle** the harness once carried was retired with the closed P7b gate (`retire-metal-renderer`, 2026-07-06) — the single rendering path is CoreGraphics, the report's `renderer` field is a retained constant for schema stability, and resurrecting a second backend requires re-running the archived P7b methodology. The measurement results live in `research/` (not this spec). **Latency probe (P7b):** the probe times key-to-photon from the on-screen **presentation timestamp** of the first changed frame (a continuous capture, not per-keystroke screenshots), with the injection and frame clocks reconciled in one domain and a startup **timebase calibration** that marks results untrustworthy rather than fabricating them; resolution is **frame-quantized** (one display-refresh interval) and reported as such, which is sufficient for run-to-run comparison (the omitted hardware tail is constant run-to-run). A reference-stimulus baseline (a known change outside the terminal's rendering path) records the common capture/compositor floor. This replaced P7a's coarse screenshot-polling probe, whose per-capture cost exceeded the signal; with the trustworthy probe the P7 gate closed (CoreGraphics retained — the verdict + numbers live in `research/`). Observability of the harness through the DEBUG state dump is covered by `verification-harness`; the retired `renderer` config key falls under `terminal-configuration`'s forward-compatibility rule.
## Requirements
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

### Requirement: Memory footprint sampling under fixed scenarios

The harness SHALL sample the process's **resident memory footprint** (via the OS process API) under a **fixed, repeatable set of scenarios** so memory is comparable run-to-run and against other terminals. The scenario set SHALL include at minimum: a single idle pane, multiple panes, a pane after a large-output flood that saturates scrollback, and a pane running an alternate-screen program. The scenario **definitions** SHALL live in a view-free, unit-testable component (independent of any view type). The scrollback-flood scenario SHALL confirm that retained scrollback stays bounded by the configured cap (product value M1) — it relies on the existing cap rather than re-implementing it.

#### Scenario: Memory is sampled for each scenario

- **WHEN** the harness runs the scenario set in a benchmark run
- **THEN** it records a resident-memory sample for each scenario in the set

#### Scenario: Scrollback flood stays bounded

- **WHEN** the scrollback-flood scenario produces output far exceeding the configured scrollback
- **THEN** the retained scrollback is bounded by the configured cap, so the memory sample reflects a bounded buffer

#### Scenario: Scenario definitions are unit-testable without the app

- **WHEN** the test suite runs
- **THEN** the scenario-set definitions are exercised by unit tests that do not launch the app or create a terminal view

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

### Requirement: View-free performance model in XttyCore

The benchmark **result model** and the **scenario-set definitions** SHALL live in a view-free `XttyCore` component, exercisable by unit tests without launching the app or creating a terminal view, and SHALL represent the latency distribution, per-scenario memory samples, renderer, the **latency-measurement provenance** (the timebase-calibration outcome and the achieved capture cadence / frame-quantized resolution), and environment as toolkit-independent values. The model SHALL be serializable to the machine-readable report format. It SHALL NOT depend on AppKit view types.

#### Scenario: Result model and scenarios are unit-testable

- **WHEN** the test suite runs
- **THEN** the benchmark result model (including its serialization and the latency-measurement provenance fields) and the scenario-set definitions are exercised by unit tests that do not launch the app or create a terminal view

#### Scenario: Model is independent of UI types

- **WHEN** `XttyCore` is built
- **THEN** the performance model does not import the app/UI target or a concrete terminal view, and carries no AppKit types

### Requirement: Latency measurement trustworthiness safeguards

So the latency numbers are trustworthy rather than plausible-but-wrong, the latency probe SHALL apply measurement-validity safeguards beyond producing a distribution. (1) It SHALL perform a startup **timebase calibration** that confirms the keystroke-injection clock and the frame-presentation-timestamp clock reconcile into one domain; if they do not, it SHALL mark the latency results **untrustworthy** (and emit no absolute key-to-photon numbers) rather than report fabricated values. (2) It SHALL also measure a **reference-stimulus baseline** the same way — a known on-screen change produced outside the terminal's rendering path — so that the capture/compositor/scheduling floor can be identified and the terminal's own contribution distinguished from it, rather than the floor being mistaken for terminal rendering latency. These safeguards exist because the measurement is frame-quantized and the effects being tracked are small (sub-frame to about one frame), so an uncalibrated or un-baselined number could report a plausible-but-wrong absolute latency or misattribute the capture floor to the terminal.

#### Scenario: Timebase calibration gates absolute results

- **WHEN** the probe starts and the injection clock and the frame-presentation-timestamp clock cannot be reconciled into one domain
- **THEN** the run marks the latency results untrustworthy and emits no absolute key-to-photon numbers, rather than reporting plausible-but-wrong values

#### Scenario: A reference-stimulus baseline accompanies the benchmark run

- **WHEN** a latency benchmark run executes
- **THEN** the run also carries a reference-stimulus baseline measured identically, so the common capture/compositor floor can be distinguished from the terminal's own rendering contribution

