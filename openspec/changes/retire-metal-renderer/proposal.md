# Retire the Metal renderer option and the Metal-toolchain build dependency

## Why

The P7b renderer gate is **closed** — "keep CoreGraphics, skip Phase 8", decided 2026-06-29 on trustworthy measurements (CG: faster median, much tighter tail, leaner memory than SwiftTerm's experimental Metal path; see `research/03-analysis/p7-measurement-methodology.md`, P7b apply-result addendum). The CoreGraphics↔Metal A/B toggle existed **only** to feed that gate, so it is now dead infrastructure that the specs still describe as live. Meanwhile the **only** reason xtty's build needs the Metal toolchain at all is SwiftTerm's bundled shader (`external/SwiftTerm/Package.swift:83`, `resources: [.process("Apple/Metal/Shaders.metal")]`) — and the toolchain download is a **deterministic Apple-catalog-rotation trap**, not flakiness (`research/03-analysis/local-macos-vm-ci-reproduction.md` §10c/§11d): Apple serves one "current" MobileAsset build per OS+Xcode combo and rotates it, so the CI guard (`xcrun -f metal || sudo xcodebuild -downloadComponent MetalToolchain`) can 404 at any time. Owner-decided 2026-07-04 (§11g): full retirement, as its own change.

Four reasons, in order: (1) **specs record what is true** — post-P7b there is one renderer; (2) **de-fragilize real CI** — both `ci.yml` toolchain guards become unnecessary; (3) **lean bias** — a dead A/B toggle, a dead config key, and dead plumbing contradict the product values; (4) **prerequisite** for the minimal test-VM image (sibling change `add-xtty-test-image`, which needs the zero-Metal build).

## What Changes

- **Patch SwiftTerm's shader resource out** via the existing patch mechanism (`patches/swiftterm/xtty-accessors.diff`, applied by `scripts/bootstrap-swiftterm.sh`), so building xtty requires **no Metal toolchain**. The patch stops being add-only (it now also modifies upstream `Package.swift`) — see design.
- **BREAKING** (fail-soft): remove the `renderer` config key (`coregraphics|metal`). A legacy config carrying `renderer = metal` is covered by the existing forward-compatibility rule — the key is unrecognized and ignored; the app renders with CoreGraphics (which was already the default).
- **Remove the renderer-selection plumbing**: the `RendererBackend` type, config parsing, the `-UITestRenderer` launch override, the `setUseMetal` wiring, and the Metal arm of the benchmark runner. The benchmark report and DEBUG state dump **keep** their `renderer` field (now constant `coregraphics`) for report-schema stability.
- **Drop every Metal-toolchain guard**: both `ci.yml` "Ensure Metal toolchain" steps (+ the header comment), the `make doctor` Metal check, and the `make bench` Metal arm (`make bench` writes the CoreGraphics report only).
- **Delete the Metal e2e arm**: `testConfiguredMetalRendererIsReported` (its behavior no longer exists); adjust the CoreGraphics renderer e2e and the renderer-parsing unit tests.
- **Resurrection path** if SwiftTerm's Metal path matures: revert one patch hunk and re-run the archived P7b methodology (`research/03-analysis/p7-measurement-methodology.md`).

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `terminal-configuration`: the recognized-keys requirement drops `renderer` (and its invalid-value clause); a legacy `renderer` key falls under the existing unrecognized-key rule.
- `performance-harness`: the "Renderer A/B selection" requirement is **removed**; the latency probe, benchmark-report, and measurement-validity-safeguard requirements lose their two-renderer/A/B arms (timebase calibration and the reference-stimulus baseline **stay**, reframed as guarding absolute latency numbers).
- `verification-harness`: the state-dump requirement rewords the rendering-backend field (one backend, field retained); the performance-harness e2e requirement drops the Metal arm and the Metal-pixel-correctness manual-verification clause.
- `build-workflow`: the prerequisite check no longer includes the Metal toolchain (project generator + full Xcode remain).

## Impact

- **SwiftTerm patch mechanism**: `patches/swiftterm/xtty-accessors.diff` (new hunk), `scripts/bootstrap-swiftterm.sh` (idempotency hardening for a now-tracked-file-modifying patch — see design).
- **XttyCore**: `RendererBackend.swift` (deleted), `XttyConfigLoader.swift`, `XttyProfile.swift` (`XttyConfigSet.renderer`), `PerformanceModel.swift` (`BenchResult.renderer` becomes a constant string field); unit tests in `XttyConfigTests.swift` + `PerformanceModelTests.swift`.
- **App**: `XttyApp.swift` (`-UITestRenderer`, renderer threading, bench report path), `TerminalWindowController.swift` (`applyRenderer`/`setUseMetal`/`activeRenderer`, state-dump field), `BenchmarkRunner.swift` (renderer parameter).
- **Tests**: `AppUITests/XttyPerformanceHarnessUITests.swift` (Metal test deleted, CG test adjusted).
- **Tooling/CI/docs**: `Makefile` (doctor + bench, including the `-UITestRenderer` flag on the retained CoreGraphics bench line), `.github/workflows/ci.yml` (both guards), `scripts/audit-leaks.sh` (its dead `-UITestRenderer coregraphics` invocation args), `config.example` (renderer block), AGENTS.md (the Metal Toolchain prerequisite paragraph, the patch "add-only" wording, the `make doctor`/`make bench` table rows, and the CI-section Metal-guard sentence).
- **Open-change interactions** (pre-registered — see design D5 + Risks): **`add-ci-pipeline`** owns `ci.yml` and its pending `build-workflow` delta names the deleted Metal-toolchain guard (requirement clause + scenario) — reconciled in the same session as the guard removal (task 5.2) so its later archive merges no stale text; **`harden-churn-shell-readiness`** also carries a MODIFIED `verification-harness` "Deterministic content assertion channel" — whichever change archives second re-pastes the then-current block and re-applies only its own edit (task 6.3); the sibling **`add-xtty-test-image`** consumes the zero-Metal build.
- **Not affected**: the latency probe and memory sampler themselves (still shipped, still the regression harness); the SwiftTerm accessor patch hunk (P4b-2); anything downstream of the P7 gate (already closed).
- **Deferred proof**: the end-to-end "builds on a machine with **no** Metal toolchain installed" verification belongs to `add-xtty-test-image` (this dev machine has the toolchain; locally we can only assert the build invokes no Metal compile step).
