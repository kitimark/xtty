## Why

Phase 7 is the **measure-and-decide gate** before the *conditional* Phase 8 (own Metal renderer): keep CoreGraphics, flip SwiftTerm's Metal path, or escalate to a custom renderer. xtty has **zero** latency/memory instrumentation today, and the lean/fast requirements (M1 "low memory," M4 "latency-first") have **no measurable bar** — so we cannot tell whether the current CoreGraphics renderer already passes or needs replacing. This change builds the **fork-free measurement harness** that produces the numbers the gate needs, and leaves behind a reusable performance regression guard. The renderer *decision* itself (running the A/B + comparators) is the follow-on **P7b**, not this change — see `research/03-analysis/p7-measurement-methodology.md`.

## What Changes

- **In-process key-to-photon latency probe** — inject a synthetic keystroke and poll the terminal window's pixels until the glyph changes (`t1 − t0`). Renderer-agnostic (works for CoreGraphics and Metal); excludes the constant hardware tail, so the CoreGraphics-vs-Metal **delta is exact** — which is what the gate needs.
- **Memory sampler** — `task_info` resident footprint sampled under **fixed, repeatable scenarios** (1 pane idle → N panes → a full-scrollback flood → an alt-screen app), so memory is comparable run-to-run and against other terminals.
- **Renderer A/B toggle** — a base-only `renderer = coregraphics|metal` config key (plus a `-UITestRenderer` launch arg) wired to SwiftTerm's `setUseMetal(_:)` after the view is in a window, so the two renderers can be compared **without rebuilding**. Default stays `coregraphics` — this change does **not** change the shipping renderer.
- **Benchmark run + results report** — a measurement mode that drives the scenarios and writes a structured results artifact (the latency/memory numbers for the gate), with aggregate stats and the active renderer also surfaced through the existing DEBUG state dump for e2e verification.
- **Makefile `bench` target** — a one-command entry point to run the harness.
- **Relative-bar methodology recorded** — the harness is designed to be run the same way against installed comparators (Terminal.app / iTerm2 / Warp) so "lean + fast" is judged *relative* to them; capturing those competitor numbers and the verdict is P7b.

Explicitly **measurement-only**: no change to the default renderer, no distribution/notarization (deferred to a separate change — there are 0 codesigning identities on the dev machine and it is orthogonal to the gate). **Fork-free** — no `external/SwiftTerm` patch (the screen-capture probe needs no engine hook).

## Capabilities

### New Capabilities
- `performance-harness`: the latency probe (synthetic-keystroke → pixel-change key-to-photon), the `task_info` memory sampler, the fixed measurement scenarios, the benchmark run + results report, and the renderer A/B toggle applied for measurement.

### Modified Capabilities
- `terminal-configuration`: a new base-only `renderer = coregraphics|metal` key (default `coregraphics`) selecting the rendering backend; invalid/absent → default.
- `verification-harness`: the DEBUG state dump gains the active `renderer` (and memory-sample observability) so the toggle and sampler are e2e-verifiable, plus a performance-harness e2e scenario.

## Impact

- **XttyCore (view-free):** the measurement scenario definitions, the benchmark result model, and any relative-bar comparison helper — unit-testable without the app.
- **App layer:** the latency probe (ScreenCaptureKit frame capture + `CGEvent` keystroke injection), the `task_info` memory sampler, renderer wiring in `TerminalWindowController` (`setUseMetal` after window attach), config plumbing (`XttyConfig`/`XttyConfigLoader.resolveSet` + `XttyApp` overrides), the benchmark-mode driver, and the new state-dump fields (`writeStateDump`).
- **Build:** a `bench` target in the `Makefile`.
- **Dependencies:** system frameworks only — ScreenCaptureKit (macOS 12.3+) + CoreGraphics event injection. **No third-party deps; no SwiftTerm fork/patch.**
- **Out of scope (this change):** the renderer decision/verdict (P7b), the Instruments retain-cycle/leak pass (P7c), and Hardened Runtime + notarization (deferred).
