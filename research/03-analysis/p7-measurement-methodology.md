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

**Decision (revised):** P7a ships as the **memory + renderer-A/B + report-infrastructure** harness; the latency probe is retained but **documented coarse/experimental** (it exercises the full input→render→capture path and is a useful regression smoke-test, not a latency oracle). A **trustworthy** key-to-photon probe — an `SCStream` delivering per-frame **presentation timestamps**, or an engine present-hook (the fork route) — and the actual **CoreGraphics-vs-Metal latency verdict** move to **P7b**, which always owned the renderer decision and was gated on trustworthy latency anyway. The relative-bar method (compare against Terminal.app/iTerm2/Warp) still stands for P7b. The `renderer = coregraphics|metal` config key + `make bench` + the JSON report shape are reusable by P7b as-is.

## Sources

- Explore session 2026-06-29 (`/opsx:explore p7`) + codebase survey (Explore subagent, medium depth).
- [SwiftTerm Metal renderer spike](swiftterm-metal-renderer-spike.md) — Metal path works in xtty's AppKit host; adoption deferred to this gate; `setUseMetal` precondition (view in window).
- [Performance — Latency vs Throughput](../02-internals/06-performance-latency.md) — latency≠throughput; frame pacing is the dominant lever; the VTE 40 Hz fixed-timer bug; CAMetalLayer drawable-depth +30–50 ms; software vs hardware measurement (~20 ms tail).
- [Stack sketch](../04-design/01-stack-sketch.md) — staged Level-3→Level-1 decision; "drop to Level 1 only if measured latency/memory misses M1/M4 — first try `useMetalRenderer` + frame-pacing tuning."
- [Requirements](xtty-requirements.md) — M1 (lean memory, "nowhere near Warp ~300 MB–1 GB"), M4 (Metal, latency-first).
- Environment checks (2026-06-29): `security find-identity -v -p codesigning` → 0 valid identities; installed comparators: Warp, iTerm2, Terminal.app (no Ghostty).
- Code refs: `App/XttyApp.swift:156–182` (`startUITestDump`, 0.15 s timer, `-UITestGridDump`), `App/TerminalWindowController.swift:606–659` (`writeStateDump`), `XttyCore/Sources/XttyCore/XttyConfigLoader.swift` (`resolveSet`, base-only keys), SwiftTerm `Mac/MacTerminalView.swift:247` (`setUseMetal`).
