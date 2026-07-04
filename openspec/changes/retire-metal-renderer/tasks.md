# Tasks — retire-metal-renderer

## 1. Zero-Metal SwiftTerm (patch + bootstrap)

- [ ] 1.1 Extend `patches/swiftterm/xtty-accessors.diff` with a hunk deleting the `resources: [.process("Apple/Metal/Shaders.metal")]` declaration from SwiftTerm's `Package.swift` (regenerate the diff from a pristine checkout per the documented workflow — design D1)
- [ ] 1.2 Harden `scripts/bootstrap-swiftterm.sh`'s pristine-restore for tracked-file modifications (restore tracked files to the pinned ref before `git apply` — design D1 point 1) and update the "add-only" prose in the script header, the `.diff` header comment, and `UPSTREAM_CONFIG.sh`'s comment
- [ ] 1.3 Verify: run `scripts/bootstrap-swiftterm.sh` twice in a row — both runs succeed (idempotent), and `git -C external/SwiftTerm status`/`diff` afterwards shows exactly the two intended patch effects (the added `XttyAccessors.swift`, the modified `Package.swift`)
- [ ] 1.4 Verify (no-Metal-compile proof, local form): a clean full app build succeeds, the `xcodebuild` build log contains **no** Metal compile step (grep the log for `CompileMetalFile` / `metallib` — zero hits), and no `*.metallib` exists in the built products (`find build -name '*.metallib'` is empty). NOTE: the end-to-end "builds on a machine with **no** Metal toolchain installed at all" proof is **deferred to `add-xtty-test-image`** — this machine has the toolchain, so only the absence of any Metal compile step is assertable locally

## 2. XttyCore plumbing removal (config schema + performance model)

- [ ] 2.1 Delete `XttyCore/Sources/XttyCore/RendererBackend.swift`; remove `renderer` parsing (base key, invalid-value warn, profile-block base-only warn) from `XttyConfigLoader.swift` and the `renderer` property/init parameter from `XttyConfigSet` in `XttyProfile.swift` (design D2)
- [ ] 2.2 Change `BenchResult.renderer` in `PerformanceModel.swift` from the deleted enum to a `String` (encoded value `"coregraphics"`), preserving the JSON wire format (design D3); adjust `PerformanceModelTests.swift` fixtures
- [ ] 2.3 Replace the 4 renderer-parsing unit tests in `XttyConfigTests.swift` with one test for the new scenario: a config containing `renderer = metal` loads with the key ignored as unrecognized and all recognized settings intact
- [ ] 2.4 Verify: `make test-core` is green (no compile reference to `RendererBackend` remains in the package; `grep -rn "RendererBackend" XttyCore/Sources XttyCore/Tests` is empty — source dirs only, so the gitignored `XttyCore/.build` metadata can't false-fail it; the App/test layers still reference it until section 3 — the repo-wide sweep is task 6.2)

## 3. App-layer removal (selection wiring + state dump + benchmark runner)

- [ ] 3.1 `App/XttyApp.swift`: remove the `-UITestRenderer` launch override and all renderer threading into the window controllers; fix the default benchmark report path to `xtty-bench-coregraphics.json` (name kept for report continuity — design D2)
- [ ] 3.2 `App/TerminalWindowController.swift`: remove the `renderer` property, `applyRenderer()`/`setUseMetal` wiring, and `activeRenderer`; the DEBUG state dump's `"renderer"` field becomes the constant `"coregraphics"` (design D3)
- [ ] 3.3 `App/BenchmarkRunner.swift`: remove the `renderer:` parameter (the result carries the constant); refresh the A/B wording in the `BenchmarkRunner`/`LatencyProbe` doc comments — the `ProbeOverlay` reference-stimulus baseline **stays** (capture/compositor-floor framing per the `performance-harness` delta)
- [ ] 3.4 Verify: the app builds and launches; a `-UITestGridDump` launch's state dump reports `renderer = coregraphics` and a positive memory sample

## 4. Harness / e2e test adjustments

- [ ] 4.1 `AppUITests/XttyPerformanceHarnessUITests.swift`: **delete** `testConfiguredMetalRendererIsReported` (its behavior no longer exists — design D2); drop `import Metal` and the `MTLCreateSystemDefaultDevice` skip
- [ ] 4.2 Adjust `testConfiguredCoreGraphicsRendererIsReported`: no `-UITestRenderer` argument — a plain `-UITestGridDump` launch must report `coregraphics` (the modified verification-harness scenario); confirm the benchmark-report e2e still asserts the retained `renderer` report field
- [ ] 4.3 Verify: `make test` is green (bench e2e stays opt-in via `XTTY_RUN_BENCH_E2E`, unaffected)

## 5. Build workflow, CI, and docs

- [ ] 5.1 `Makefile`: drop the doctor Metal-toolchain check (~50–51) and the Metal header comment (~9); drop the bench Metal arm (~84–86) **and strip the now-dead `-UITestRenderer coregraphics` flag from the retained CoreGraphics bench invocation (~83)** so `make bench` writes `build/bench/coregraphics.json` only, and update the bench echo text that mentions both renderers / the renderer delta (design D4); `scripts/audit-leaks.sh`: drop the now-dead `-UITestRenderer coregraphics` arguments from its app invocation (~47, design D2)
- [ ] 5.2 `.github/workflows/ci.yml`: remove both "Ensure Metal toolchain" steps and the header comment about the RC-Metal risk (design D5); in the same session, reconcile the open **`add-ci-pipeline`** change's pending `build-workflow` delta — generalize its "for example the Metal toolchain" clause and its "CI is resilient to a missing build component" scenario to a component CI still installs (XcodeGen) or drop them — so that change's later archive does not merge stale Metal-guard text (design D5)
- [ ] 5.3 `config.example`: remove the `renderer` key block; AGENTS.md: remove the Building section's "Metal Toolchain (one-time)" prerequisite paragraph (and its §10b "candidate cleanup" note, now shipped) and the patch "add-only" wording, and fix the other now-false Metal statements — the `make doctor` table row ("XcodeGen, full Xcode, Metal toolchain"), the `make bench` table row ("for both renderers"), and the CI-section sentence "Both jobs guard the Metal toolchain (`xcrun -f metal || sudo xcodebuild -downloadComponent MetalToolchain`)"
- [ ] 5.4 Verify: `make doctor` output contains no Metal mention and still checks XcodeGen + full Xcode; `make bench` produces the single CoreGraphics report containing `renderer = "coregraphics"`, per-scenario memory samples, the timebase-calibration outcome, and the reference-stimulus baseline (or the explicit latency-unavailable marker without the Screen Recording grant)
- [ ] 5.5 Verify: after pushing the change, both `ci.yml` jobs run green on its own push/PR without the guard steps (migration step 5 — the CI-side proof that the guard removal is safe)

## 6. Final verification sweep

- [ ] 6.1 Run the full local matrix: `make test-core` green, `make test` green, `make bench` report verified (5.4), no-Metal-compile build-log check re-run on a clean build (1.4)
- [ ] 6.2 Sweep for leftovers: `grep -rn "UITestRenderer\|setUseMetal\|RendererBackend" App/ XttyCore/Sources XttyCore/Tests AppUITests/ scripts/ Makefile .github/` returns nothing (source dirs, not `XttyCore/.build`, so stale build metadata can't false-fail it; `scripts/` included for the audit-leaks.sh invocation); `grep -n "renderer" config.example` returns nothing
- [ ] 6.3 `openspec validate "retire-metal-renderer"` passes; pre-register for archive time, per the repo's post-archive checklist: (a) update the `performance-harness` spec **Purpose** (it describes the A/B toggle); (b) update the `terminal-spatial-blocks` spec's **Purpose** and the non-binding "e.g. … an applied add-only patch" wording in its scroll-invariant-coordinate requirement to "an applied tracked patch" (the patch now also modifies upstream `Package.swift` — design D1); (c) **cross-change collision** (design Risks): whichever of this change and **`harden-churn-shell-readiness`** archives second MUST re-paste the then-current established "Deterministic content assertion channel" requirement from `openspec/specs/verification-harness/spec.md` and re-apply only its own edit (folding the single-backend rewording together with the modal-liveness sentence/scenario) before archiving, so neither edit is silently clobbered
- [ ] 6.4 Out of scope, stated for the record: the no-toolchain end-to-end build proof (deferred to `add-xtty-test-image`); the upstream SwiftTerm optional-shader-resource proposal (revisit with the accessor upstream PR); any new renderer work (Phase 8 remains skipped)
