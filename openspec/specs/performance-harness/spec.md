# performance-harness Specification

## Purpose

Defines xtty's **performance measurement harness** — the instrument behind the P7 measure-and-decide gate (M1 lean memory, M4 latency-first). It covers a fork-free, in-process **key-to-photon latency probe** (synthetic keystroke → on-screen pixel change; renderer-agnostic), a **resident-memory sampler** over a fixed, independently-reset scenario set (idle / multiple panes / saturated scrollback / alt-screen), a **CoreGraphics↔Metal renderer A/B toggle** so the two backends can be compared without rebuilding, a DEBUG **benchmark run** that writes a machine-readable results report (the P7-decision artifact + a regression baseline), and a view-free result model in `XttyCore`. The measurement results live in `research/` (not this spec). **Latency probe (P7b):** the probe times key-to-photon from the on-screen **presentation timestamp** of the first changed frame (a continuous capture, not per-keystroke screenshots), with the injection and frame clocks reconciled in one domain and a startup **timebase calibration** that marks results untrustworthy rather than fabricating them; resolution is **frame-quantized** (one display-refresh interval) and reported as such, which is sufficient for the renderer **delta** (the omitted hardware tail cancels). A renderer-independent reference-stimulus baseline records the common capture/compositor floor. This replaced P7a's coarse screenshot-polling probe, whose per-capture cost exceeded the signal; with the trustworthy probe the P7 gate closed (CoreGraphics retained — the verdict + numbers live in `research/`). Observability of the harness through the DEBUG state dump is covered by `verification-harness`; the `renderer` config key by `terminal-configuration`.
## Requirements
### Requirement: Key-to-photon latency probe

The app SHALL provide a DEBUG-gated, in-process **key-to-photon latency probe** that measures input-to-display latency by injecting a synthetic keystroke and detecting the resulting on-screen change by sampling the **rendered pixels** of the terminal window. The probe SHALL time the interval using the **on-screen presentation timestamp of the captured frame in which the change first appears** — not the wall-clock cost of the capture operation — so that a slow capture path does not floor the measurement; it SHALL be able to resolve at least **whole-frame** (one display-refresh-interval) differences between configurations. The injection time (t0) and the frame presentation time (t1) SHALL be measured or normalized into the **same monotonic clock domain** so that `t1 − t0` is a valid duration. The probe SHALL be **renderer-agnostic** — functioning identically whether the CoreGraphics or the Metal backend is active — and SHALL run over many trials to produce a **distribution** (at minimum median and tail percentiles), not a single sample. The probe SHALL NOT require modifying the SwiftTerm engine. It deliberately excludes hardware input/display latency; this is acceptable because, for the renderer comparison, the omitted latency is constant and cancels in the delta. Because the timing resolution is bounded by the display refresh interval (and is variable on a variable-refresh display), the probe SHALL surface results as **frame-quantized with the achieved time-resolution made explicit**, rather than implying sub-frame precision. When the OS screen-capture permission is unavailable, the probe SHALL fail with a clear error rather than report a bogus measurement.

#### Scenario: Probe produces a latency distribution

- **WHEN** the latency probe runs a configured number of trials in a DEBUG benchmark run
- **THEN** it records one key-to-photon sample per trial and reports aggregate statistics including a median and at least one tail percentile

#### Scenario: Probe works under both renderers

- **WHEN** the latency probe runs with the CoreGraphics backend and again with the Metal backend
- **THEN** each run yields a comparable latency distribution measured the same way, so the two backends can be compared

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

### Requirement: Renderer A/B selection

xtty SHALL select its rendering backend — **CoreGraphics** or **Metal** — from configuration so the two can be compared **without rebuilding**, defaulting to CoreGraphics. The selection SHALL be applied to the live terminal view **after** it is hosted in a window (a necessary precondition for the rendering-backend selection to take effect). Selecting the Metal backend SHALL NOT change the correctness of rendered output (truecolor, emoji, and wide/CJK glyphs still render without corruption). A launch-time override SHALL be available so a test or benchmark run can force a backend regardless of the config file.

#### Scenario: Configured renderer is applied to the live view

- **WHEN** the configuration selects `renderer = metal`
- **THEN** the live terminal view uses the Metal backend; and when the configuration selects `coregraphics` or omits the key, the view uses the CoreGraphics backend

#### Scenario: Switching backend preserves output correctness

- **WHEN** the Metal backend is selected and output exercising truecolor, emoji, and wide/CJK glyphs is produced
- **THEN** that output renders without corruption, the same content as under CoreGraphics

#### Scenario: A launch override forces a backend for A/B

- **WHEN** a benchmark or test run is launched with the renderer override set to a specific backend
- **THEN** that backend is used regardless of the config file value, enabling a rebuild-free A/B comparison

### Requirement: Benchmark run and results report

The harness SHALL provide a **benchmark mode**, runnable from a single command, that drives the latency probe and the memory scenarios for the active renderer and writes a **structured, machine-readable results report**. The report SHALL include the active rendering backend, the latency distribution statistics, the per-scenario memory samples, the capture frame rate (so the latency time-resolution is explicit), the **timebase-calibration outcome** (whether the injection and frame-timestamp clocks reconciled, so the latency numbers' trustworthiness is recorded), the **achieved capture cadence and frame-quantized resolution** of the latency measurement, and an environment description (machine, display, OS). When the latency probe cannot run (e.g. the screen-capture permission or a visible display is unavailable) or the timebase calibration fails, the benchmark run SHALL still write the report with the renderer, memory samples, and environment, and SHALL mark the latency section **explicitly unavailable or untrustworthy** rather than omitting the report or aborting the whole run — so memory remains measurable on a headless/permission-less runner. The report SHALL serve as the artifact for the P7 renderer decision and as a performance-regression baseline. The benchmark mode SHALL be DEBUG-gated and SHALL NOT run in shipping builds. Producing a pass/fail verdict against comparator baselines is out of scope for this capability.

#### Scenario: Benchmark run writes a results report

- **WHEN** the benchmark mode runs to completion for a selected renderer with the latency probe available and the timebase calibration passing
- **THEN** it writes a results report containing the active renderer, the latency distribution statistics, the capture frame rate, the timebase-calibration outcome, the achieved capture cadence / frame-quantized resolution, the per-scenario memory samples, and an environment description

#### Scenario: Benchmark still reports memory when latency is unmeasurable

- **WHEN** the benchmark mode runs where the latency probe cannot run (no screen-capture permission or no visible display) or the timebase calibration fails
- **THEN** the report is still written with the active renderer, the per-scenario memory samples, and the environment, and the latency section is marked explicitly unavailable or untrustworthy

#### Scenario: The report supports the renderer A/B

- **WHEN** the benchmark is run once for each renderer
- **THEN** the two reports carry comparable latency and memory data measured the same way, sufficient to compare the backends

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

So the renderer comparison is trustworthy rather than plausible-but-wrong, the latency probe SHALL apply measurement-validity safeguards beyond producing a distribution. (1) It SHALL perform a startup **timebase calibration** that confirms the keystroke-injection clock and the frame-presentation-timestamp clock reconcile into one domain; if they do not, it SHALL mark the latency results **untrustworthy** (and emit no absolute key-to-photon numbers) rather than report fabricated values. (2) For the renderer A/B it SHALL also measure a **renderer-independent reference-stimulus baseline** the same way — a known on-screen change produced outside the terminal renderer — so that the capture/compositor/scheduling floor common to both renderers can be identified and the renderer's own contribution distinguished, rather than the floor being mistaken for a renderer difference. These safeguards exist because the expected CoreGraphics↔Metal delta is small (sub-frame to about one frame) and the measurement is frame-quantized, so an uncalibrated or un-baselined number could misrank the backends.

#### Scenario: Timebase calibration gates absolute results

- **WHEN** the probe starts and the injection clock and the frame-presentation-timestamp clock cannot be reconciled into one domain
- **THEN** the run marks the latency results untrustworthy and emits no absolute key-to-photon numbers, rather than reporting plausible-but-wrong values

#### Scenario: A reference-stimulus baseline accompanies the renderer comparison

- **WHEN** the latency A/B is run for the two renderers
- **THEN** each renderer also has a renderer-independent reference-stimulus baseline measured identically, so the common capture/compositor floor can be distinguished from a genuine renderer difference

