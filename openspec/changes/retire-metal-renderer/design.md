# Design — retire-metal-renderer

## Context

P7b closed the renderer gate (2026-06-29): **keep CoreGraphics, skip Phase 8** — measured on the trustworthy `SCStream` probe, CG had a faster median (~31 vs ~33 ms), a much tighter tail (p99 ~40 vs ~50–120 ms), and leaner memory (~55 vs ~62 MB idle) than SwiftTerm's experimental Metal path (`research/03-analysis/p7-measurement-methodology.md`, P7b apply-result addendum). The CoreGraphics↔Metal A/B toggle (P7a) existed solely to feed that gate.

The build's Metal-toolchain dependency has exactly one source: SwiftTerm declares its bundled shader as a processed resource — `external/SwiftTerm/Package.swift:83`, `resources: [.process("Apple/Metal/Shaders.metal")]` — and `.process()` invokes the `metal` compiler at build time. xtty never uses that shader on the CoreGraphics path. The toolchain download that guards against its absence (`xcrun -f metal || sudo xcodebuild -downloadComponent MetalToolchain`, in both `ci.yml` jobs and `make doctor`) is a **deterministic Apple-catalog-rotation trap**: the toolchain is a MobileAsset keyed to the OS+Xcode combo, Apple serves one "current" build per audience and rotates it, so the download can 404 at any time (`research/03-analysis/local-macos-vm-ci-reproduction.md` §10c, confirmed §11d). Owner decision §11g (2026-07-04): full retirement, as its own change; the sibling `add-xtty-test-image` depends on the resulting zero-Metal build.

The repo already has the patch-in-repo mechanism for modifying SwiftTerm without a fork: `patches/swiftterm/UPSTREAM_CONFIG.sh` (pin: `v1.13.0`) + `patches/swiftterm/xtty-accessors.diff` applied by `scripts/bootstrap-swiftterm.sh` onto a gitignored clone (`research/03-analysis/swiftterm-fork-vs-patch-strategy.md`).

## Goals / Non-Goals

**Goals:**
- Build xtty with **zero Metal-toolchain requirement** (patch the shader resource out of SwiftTerm's manifest).
- Remove the dead renderer-selection surface end to end: config key, `RendererBackend`, `-UITestRenderer`, `setUseMetal` wiring, the bench Metal arm, both CI guards, the doctor check, and the Metal e2e test.
- Keep the benchmark/report/state-dump **schemas stable** (the `renderer` field stays, constant `coregraphics`).
- Keep the latency probe, memory sampler, and their validity safeguards fully functional (they are the regression harness, not A/B-only infra).

**Non-Goals:**
- No change to the P4b-2 accessor patch hunk (`XttyAccessors.swift`) or to how SwiftTerm is pinned/reconstituted.
- No new renderer work (the custom Metal renderer stays a researched Phase-8 escalation path, currently skipped).
- Not proving the build on a machine with **no** Metal toolchain installed — that end-to-end proof is deferred to `add-xtty-test-image` (this machine has the toolchain; locally we can only assert no Metal compile step runs).
- Not filing the upstream SwiftTerm change to make the shader resource optional (worth doing eventually so the hunk retires; out of scope here).

## Decisions

### D1 — Patch the shader resource out via the existing patch mechanism; the patch stops being add-only

Extend `patches/swiftterm/xtty-accessors.diff` with a second hunk that deletes the `resources:` declaration (the `.process("Apple/Metal/Shaders.metal")` entry and its surrounding brackets, `Package.swift` ~lines 82–84) from SwiftTerm's `SwiftTerm` target. Regenerate the diff the documented way: edit in a pristine checkout, `git diff` → the tracked `.diff`. With no processed resource, SPM compiles no `.metal` file and produces no `default.metallib` for SwiftTerm — the Metal toolchain becomes unnecessary. (SwiftTerm's Metal renderer *source* still compiles as plain Swift — with one consequence discovered at first build, 2026-07-06: SPM synthesizes `Bundle.module` only for targets declaring at least one resource, so with the shader resource stripped, `MetalTerminalRenderer.candidateBundles()`'s `#if SWIFT_PACKAGE` arm referencing `Bundle.module` stopped compiling; the patch carries a third hunk removing that arm, leaving the metallib lookup to return nil, which callers already handle. `setUseMetal(true)` would fail at runtime to find the metallib, but nothing calls it after this change.)

**Call-out: the patch is no longer add-only.** Until now `xtty-accessors.diff` only *added* a new file, and the docs/scripts say so. This change makes it also **modify tracked upstream files** (`Package.swift`, plus the `Bundle.module` arm in `MetalTerminalRenderer.swift` — see above), which has two consequences:

1. **`scripts/bootstrap-swiftterm.sh` needs a one-line idempotency hardening** (verified by reading it): its pristine-restore step is `git checkout <ref>` + `git clean -fdq`, where the `clean` comment says "drop a previously-applied patch (untracked add)". `git clean` removes only untracked files, and `git checkout <ref>` when the checkout is already at that ref preserves a dirty tracked file — so on a second run the modified `Package.swift` would survive and `git apply` would fail. Add a tracked-file restore to the pristine step (e.g. `git -C "$checkout" checkout --quiet "$UPSTREAM_REF" -- .` or a `reset --hard` before `clean`). This keeps the `build-workflow` "Reconstitution is idempotent and pin-enforcing" requirement satisfied — an implementation fix, not a spec change.
2. **Update the "add-only" prose** in the script header, the `.diff` header comment, and `UPSTREAM_CONFIG.sh`'s comment where they describe the patch as add-only (AGENTS.md's Building section likewise — task 5.3). A fifth surface is in the **established `terminal-spatial-blocks` spec** — its Purpose ("an applied add-only patch") and the non-binding "e.g. …" wording in the scroll-invariant-coordinate requirement; specs only change at archive, so that rewording (to "an applied tracked patch") is pre-registered as archive-time cleanup in task 6.3. (The requirement itself stays satisfied: the accessor *addition* is still add-only, and the requirement explicitly does not fix the means.)

Alternative rejected: a *second* patch file (`xtty-no-metal.diff`). Two patches double the bootstrap/regeneration surface for no isolation benefit — both are applied unconditionally to the same pin; one diff with two hunks is the same mechanism the repo already documents.

### D2 — Renderer-plumbing removal inventory (each verified by grep/read, 2026-07-04)

| Surface | What goes |
| --- | --- |
| `XttyCore/Sources/XttyCore/RendererBackend.swift` | **delete file** (the enum) |
| `XttyCore/Sources/XttyCore/XttyConfigLoader.swift` | `renderer` base-key parsing + invalid-value warn (~235–243), the profile-block "base-only" warn (~201–203), the `renderer:` arg to `XttyConfigSet` (~250) |
| `XttyCore/Sources/XttyCore/XttyProfile.swift` | `XttyConfigSet.renderer` property + init parameter (~63/71/78) |
| `XttyCore/Sources/XttyCore/PerformanceModel.swift` | `BenchResult.renderer: RendererBackend` (~126/148/158) → becomes a `String` (see D3) |
| `App/XttyApp.swift` | renderer threading into the window controllers (~50/253), the `-UITestRenderer` launch override (~381–396/403), `benchmarkReportPath(renderer:)` (~73–92) → a fixed `xtty-bench-coregraphics.json` default (name kept for report continuity) |
| `App/TerminalWindowController.swift` | the `renderer` property + init param (~48–51/95/99), `applyRenderer()`/`setUseMetal` (~157/596/602–608), `activeRenderer` (~684–685); the state dump's `"renderer"` (~822) becomes the constant `"coregraphics"` |
| `App/BenchmarkRunner.swift` | the `renderer:` parameter (~19/83); the result carries the constant |
| `XttyCore/Tests/XttyCoreTests/XttyConfigTests.swift` | the 4 renderer-parsing unit tests (~344–370) — replaced by one legacy-key-ignored test (the new `terminal-configuration` scenario) |
| `XttyCore/Tests/XttyCoreTests/PerformanceModelTests.swift` | fixtures using `renderer: .metal` / `.coregraphics` (~45/63/84/102/114) → the string constant |
| `AppUITests/XttyPerformanceHarnessUITests.swift` | `testConfiguredMetalRendererIsReported` **deleted** (~23–28; its behavior no longer exists — deleting, not skipping, because a skip would imply the behavior is merely unavailable); `testConfiguredCoreGraphicsRendererIsReported` (~14–17) drops the `-UITestRenderer` arg and asserts the dump reports `coregraphics` on a plain launch; `import Metal` + the `MTLCreateSystemDefaultDevice` skip go |
| `config.example` | the `renderer` key block (~33–36) |
| `scripts/audit-leaks.sh` | the now-dead `-UITestRenderer coregraphics` arguments in its app invocation (~47) |

Not touched (prose-only "renderer" mentions, verified): `XttyCore/Sources/XttyCore/XttyConfig.swift:7`, `XttyCore/Sources/XttyCore/GitDiff.swift:34`, and `App/LatencyProbe.swift`'s comments — the probe and its `ProbeOverlay` baseline **stay** (reframed per the `performance-harness` delta: the baseline identifies the capture/compositor floor for absolute latency numbers). Doc comments that describe the A/B (e.g. `BenchmarkRunner` header, `LatencyProbe` header) get their wording refreshed in passing.

### D3 — Keep the `renderer` field in `BenchResult` and the state dump, hardcoded `"coregraphics"`

Keep, don't remove. Rationale: **report-schema stability** — the archived P7b reports under `research/` and any future `make bench` output stay directly comparable (same keys); the bench e2e's `report["renderer"]` assertion and the state-dump readers keep working; and the field documents *which* rendering path a regression baseline was measured on, which stays meaningful if a different renderer ever exists again. Mechanically: `BenchResult.renderer` changes type from the deleted `RendererBackend` enum to `String` (encoded value `"coregraphics"`), preserving the JSON wire format exactly; the state dump's `"renderer"` key emits the same constant. The `verification-harness` delta words the dump field as a retained single-backend identifier.

### D4 — Makefile

- **doctor** (~50–51): drop the Metal-toolchain check (the spec delta removes it from the prerequisites; project generator + full Xcode remain). Also the header comment (~9) naming the Metal toolchain.
- **bench** (~80–91): drop the Metal arm (~84–86) **and strip the now-dead `-UITestRenderer coregraphics` flag from the retained CoreGraphics invocation (~83)** (after D2 removes the launch-override parsing it would be an inert unparsed argument, and the 6.2 leftover sweep would trip on it) — `make bench` runs once and writes `build/bench/coregraphics.json` only; update the echo'd report list and the trailing notes that mention "both renderers"/"the renderer delta".

### D5 — ci.yml

Remove both "Ensure Metal toolchain (no-op when preinstalled)" steps (~24–25 and ~55–56) and the header comment block explaining the RC-Metal risk (~9–11). Nothing else in the workflow references Metal. This deletes the catalog-rotation trap from CI entirely (the guard was a live download on any runner image whose Xcode lacked the component).

**Coordination with the open `add-ci-pipeline` change (which owns `ci.yml`).** Its pending `build-workflow` delta's CI requirement and its "CI is resilient to a missing build component" scenario name the Metal toolchain as the example component CI must "ensure … is present before building" — text that becomes untrue the moment these guard steps are deleted, and that would merge stale into `openspec/specs/build-workflow` when `add-ci-pipeline` archives. Reconcile that pending delta **in the same session as task 5.2** (pre-registered there): generalize the example to a component CI still actually installs (XcodeGen, via `brew install xcodegen`) and reword the scenario to match — or drop the missing-build-component clause + scenario entirely — so only one truth about the Metal guard reaches the established spec. `add-ci-pipeline`'s design D4 (which mandated the guard) is likewise annotated as superseded by this change.

### D6 — Alternatives considered (from research §10/§11g)

- **Env-flagged optional strip** (patch applied only when e.g. `XTTY_NO_METAL=1`): rejected — two build flavors mean CI/the VM image diverge from local dev builds (test-what-you-ship drift), and the A/B toggle it would preserve feeds a gate that is closed.
- **Bake the toolchain into the VM image (Path A)**: rejected — +~1.5 GB, host-coupled (copies the host's rotated MobileAsset), and leaves the fragile CI guard in place; it fixes only the image, not xtty's real CI.
- **Keep the `renderer` key as a recognized-but-deprecated no-op with a warning**: rejected — the loader's existing forward-compat rule already handles the legacy key, and a permanent deprecation shim for a key that only ever fed a benchmark gate contradicts the lean bias.

## Risks / Trade-offs

- **[Upstream pin bump breaks the new hunk]** The `Package.swift` hunk depends on upstream context lines; a future `UPSTREAM_REF` bump can make it fail to apply (the add-only hunk was immune to this). → Acceptable and loud: `bootstrap-swiftterm.sh` fails at `git apply`, and the existing rule ("re-verify the patch applies after editing the pin") already covers it; regenerating the hunk against the new ref is minutes of work.
- **[A user config with `renderer = metal` silently gets CoreGraphics]** Verified in `XttyConfigLoader`: unrecognized keys are **silently ignored — not logged** (no unknown-key warning path exists; recognized keys are consumed by explicit lookups). So after retirement the legacy key produces no warning at all. → Acceptable: the resulting behavior (CoreGraphics) is exactly the documented default, the key was documented as benchmark-only ("leave as coregraphics unless you are benchmarking"), and the spec's forward-compat scenario now records this outcome truthfully. No deprecation shim (D6).
- **[Losing the ability to measure Metal]** The resurrection path is cheap and documented: revert the one `Package.swift` hunk, re-add the ~7-file plumbing (this change's diff is the recipe), and re-run the archived P7b methodology. Nothing downstream depends on Metal.
- **[`setUseMetal` becomes a latent runtime trap in the patched checkout]** SwiftTerm's API remains callable but its metallib no longer exists. → Nothing in xtty calls it after this change; the deleted e2e was the only caller-by-config. No guard added (dead-code guard for a dead path).
- **[Archive-time prose drift in established specs]** Delta files carry only requirements, so two specs' prose goes stale at archive: the `performance-harness` **Purpose** (describes the A/B toggle), and the `terminal-spatial-blocks` **Purpose** plus the non-binding "e.g. … an applied add-only patch" wording in its scroll-invariant-coordinate requirement (after D1 the tracked patch also modifies upstream `Package.swift` — reword to "an applied tracked patch"). Verified: `terminal-configuration`'s Purpose never mentions `renderer`, so it needs no prose fix (its `renderer` text lives in the requirement this change's delta already modifies). → Handled by the repo's standard post-archive checklist (make the merged text reflect what shipped) — tracked as task 6.3.
- **[Delta collision with the open `harden-churn-shell-readiness` change]** Both open changes carry a MODIFIED **"Deterministic content assertion channel"** (`verification-harness`) pasted from today's established block with divergent edits: this change rewords the rendering-backend sentence + the renderer scenario; that change adds the modal-dump-liveness sentence + a "Dumps stay live while a modal panel is presented" scenario (and still carries the "(CoreGraphics or Metal)"/"renderer selection" wording). Because a MODIFIED body replaces the whole requirement at archive, whichever change archives second would silently clobber the first's merged edit. → Pre-registered in task 6.3: **whichever of the two archives second re-pastes the then-current established block and re-applies only its own edit** (folding both — the single-backend rewording *and* the modal-liveness sentence/scenario) before archiving. Deliberately *not* fixed by pre-merging the other change's unarchived sentence into this delta: MODIFIED must paste from the current established spec, and the other change could still be revised or abandoned.

## Migration Plan

1. Patch + bootstrap hardening first (D1), so every subsequent build/test runs on the shader-free checkout.
2. `XttyCore` removals + unit tests (D2/D3) — `make test-core` green.
3. App-layer removals (D2) — app builds; state dump emits the constant.
4. e2e adjustments (D2) — `make test` green.
5. Makefile/CI/docs (D4/D5) — `make doctor`, `make bench` verified; CI proves itself on the change's own PR (both jobs run without the guard steps — verify task 5.5); `add-ci-pipeline`'s pending `build-workflow` delta reconciled in the same session (D5).

Rollback: revert the commit(s) and re-run `scripts/bootstrap-swiftterm.sh` (the checkout is reconstituted from the tracked pin + patch, so the mechanism rolls back atomically with the tree).

## Open Questions

- None blocking. (Non-goal noted above: proposing the shader resource as optional upstream — e.g. a package trait — would let the new hunk retire alongside the accessor hunk's upstream PR; revisit when that PR is filed.)
