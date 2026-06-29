## MODIFIED Requirements

### Requirement: Performance-harness end-to-end coverage

The harness SHALL cover the performance harness end-to-end by asserting, via the DEBUG state dump, that the configured/overridden **rendering backend** is applied (the dump reflects CoreGraphics when CoreGraphics is selected and Metal when Metal is selected) and that the **memory sampler** reports a positive resident-memory sample. It SHALL also assert that a **benchmark run** produces a results report containing the active renderer, the per-scenario memory samples, the capture frame rate, an environment description, the **timebase-calibration outcome**, and — where the latency probe ran with capture available and calibration passing — the latency distribution statistics (and an explicit unavailable-or-untrustworthy marker otherwise). The real screen-capture permission and a hardware display SHALL NOT be required to assert the renderer-applied and memory-sample behaviors (those are read from the state dump); the latency probe's pixel-capture path MAY be exercised separately where the capture permission is available. Because the headless engine grid is renderer-independent and exposes no GPU-render correctness, **Metal pixel-rendering correctness** (truecolor/emoji/CJK without corruption) SHALL be verified **manually** (screenshot/vision, per the P2 spike method), not via the e2e tests, which assert only that the backend selection was applied.

#### Scenario: The selected renderer is reflected in the state dump

- **WHEN** the tests launch with the renderer override set to Metal, and separately to CoreGraphics, in a `-UITestGridDump` DEBUG build
- **THEN** the state dump reports the matching active rendering backend for each launch, so the test can assert the toggle was applied

#### Scenario: The memory sampler reports a positive sample

- **WHEN** the tests launch the app in a `-UITestGridDump` DEBUG build
- **THEN** the state dump reports a positive resident-memory sample for the key window

#### Scenario: A benchmark run produces a results report

- **WHEN** the benchmark mode is run for a selected renderer
- **THEN** a machine-readable results report is written containing the active renderer, the capture frame rate, the per-scenario memory samples, an environment description, the timebase-calibration outcome, and the latency distribution statistics (or an explicit unavailable-or-untrustworthy marker when the capture path could not run or calibration failed)
