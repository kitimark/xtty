# P7c — leak / retain-cycle audit: methodology & scope

> **Provenance:** Produced 2026-06-29 via `/opsx:explore p7c` (explore mode — read-only, no code written) followed by a 14-agent research workflow (12 agents ran: trace→adversarial-refute on both suspected cycles, 9 parallel investigations, 1 synthesis; ~647 k subagent tokens). Every claim is grounded in `App/`, `XttyCore/`, or `external/SwiftTerm/` file:line evidence, or a cited macOS man page. Hand-verified the two headline cycle claims against source.
>
> _Topic scope:_ How to do P7c — the **leak / retain-cycle pass** named in the [milestones](../04-design/02-milestones.md) Phase 7 ("memory pass: scrollback cap, retain-cycle/leak audit (Instruments)") — in a way that fits xtty's harness-first, fork-free, reproducible philosophy. This is a **distinct concern** from the [P7 measurement methodology](p7-measurement-methodology.md) (which settled the **renderer** gate, now closed). P7c gates nothing downstream; it is pre-distribution hardening.

---

## TL;DR

- ❌ **There is no leak to hunt in xtty's own code.** Both retain cycles flagged in explore — `WindowController ⇄ GitReviewController` and `PaneController ⇄ LinkRoutingTerminalDelegate` — were **refuted** (trace + an independent adversarial-refute pass + hand-verification): every stored closure is `[weak self]`, every delegate back-reference is `weak`, and `GitReviewTarget` is a transient value type that is never stored. A full App-layer sweep found **zero** real cycles.
- ✅ **So P7c reframes** from "find & fix leaks" to **"prove the hygiene holds, leave a reproducible regression net, and profile the one place we can't see — SwiftTerm."**
- ✅ **The durable deliverable is a DEBUG live-instance census**, not the Instruments run. A `liveCount` (init `++` / deinit `--`) on the lifecycle-bearing types, surfaced in the existing state-dump JSON, asserted to return to baseline by a churn XCUITest. Deterministic, cheap, CI-gateable — the permanent net (the same "ship a reusable instrument" pattern as P7a/P7b).
- ✅ **Instruments / `leaks` is a one-time deep pass, not a CI gate.** It is fully CLI-able and needs no special entitlements, but Swift/AppKit pooled memory + intentional caches make leak-count gating false-positive-prone. Its *findings* become the census net.
- ❓ **The only genuinely interesting risk is third-party:** SwiftTerm's **unbounded glyph/font caches** + an incomplete renderer `deinit`. The census can't name these (they aren't xtty instances) → that is exactly what the one-time Instruments pass exists to profile.
- ✅ **Memory footprint stays report-only, never gated** (too noisy: ~14 MB same-scenario variance, lazy page reclaim, autorelease lag). The instance census covers the same risk deterministically.
- ✅ **Recommended scope:** census instrument + churn e2e + XttyCore weak-sentinel tests + a one-time `make audit-leaks` pass + fix the 2 cosmetic nits. **No `max-memory-mb` config key** (see Divergence below). Distribution (Hardened Runtime + Developer ID + notarization) stays deferred.

---

## 1. The suspected cycles — both refuted

The explore phase put two concrete retain-cycle suspects on the hit-list (the classic *stored-closure-on-an-owned-controller* pattern). Both were traced, then adversarially re-checked by an independent agent prompted to **refute** (default to "not a cycle" unless the strong-reference loop is unambiguous), then hand-verified.

| Suspected cycle | Verdict | Evidence |
| --- | --- | --- |
| `TerminalWindowController ⇄ GitReviewController` via `targetProvider` / `isVisible` / `GitReviewTarget.openFile` | ❌ **not a cycle** | `isVisible`/`targetProvider` assigned `[weak self]` (`TerminalWindowController.swift:118-119`); `openFile` captures `[weak pane]` (`:305`); **`GitReviewTarget` is a value-type struct, created transiently and never stored** in the controller (`GitReviewController.swift:82,124,146`); `pollTimer` closure `[weak self]` (`:73`) |
| `PaneController ⇄ LinkRoutingTerminalDelegate` via `onOpenLink` / `onScrolled` | ❌ **not a cycle** | both closures `[weak self]` (`PaneController.swift:112-114, 117-119`); the view holds the proxy **weakly** (`MacTerminalView.swift:96 public weak var terminalDelegate`); the proxy holds `inner` **weakly** (`LinkRoutingTerminalDelegate.swift:24`) |

**App-layer sweep — zero real cycles.** Disciplined `[weak self]` across every stored closure, `Timer`, `NotificationCenter` observer (removed in the idempotent `TerminalWindowController.terminate()` at `:344-345`), `NSEvent` monitor (`:349-351`), and the Carbon hotkey (`GlobalHotKey` uses `Unmanaged.passUnretained` + unregisters in `deinit`). Two **cosmetic nits**, neither a cycle, both DEBUG-only and bounded by immediate app exit:

1. ❓ `AppDelegate.dumpTimer` (`XttyApp.swift:41`, created `:180`) is never `invalidate()`d in `applicationWillTerminate` (`:215-219`). Best-practice slip; mirror `GitReviewController.setPolling`'s pattern.
2. ❓ `BenchmarkRunner` (`:27`) `Task` captures `controller` **strongly** (no `[weak controller]`), unlike `XttyApp:74,:303`. Safe in practice (the benchmark terminates the app) but violates the house pattern.

---

## 2. The census instrument — the durable deliverable ✅

A DEBUG-only **live-instance census**: a per-type counter incremented in `init`, decremented in `deinit`, surfaced in the state dump, asserted to return to baseline by a churn test. This is what survives P7c as the permanent regression net (mirroring how P7b's latency probe became a permanent guard).

- **Counter:** `#if DEBUG @MainActor static var liveCount = 0` directly on each type. **No atomics** — all six lifecycle types are already `@MainActor` (`TerminalWindowController:37`, `PaneController:36`, `GitReviewController:31`, `QuickTerminalController:22`, `XttyTerminalView:36`), so a plain `Int` is race-free. `TerminalSession` lives view-free in `XttyCore` and is created/destroyed only inside `PaneController` on the main actor → count it via `PaneController` calling `TerminalSession.recordInit()/recordDeinit()` (keeps `XttyCore` free of `nonisolated(unsafe)`).
- **Surface:** a new `liveInstanceCounts` dict in `TerminalWindowController.writeStateDump()` (`:688`), alongside the existing `paneCount` / `memoryFootprintBytes` fields. The out-of-process XCUITest reads it via the existing `StateDumpReader.waitForState`.
- **Churn e2e:** open N tabs/splits → close all → poll the dump → assert every count returns to the single-pane baseline. **This is the gated assertion** — deterministic (a count, not a float), cheap (O(1)), and a leaked instance *is* the retain-cycle signature. (`SessionRegistry.panes` is already the source-of-truth for "which panes exist"; the census extends that truth to the AppKit controllers.)

### Two-tier leak testing — weak-sentinel vs census

XCUITests run **out-of-process**, so a test *cannot* hold a `weak` ref to an in-app object. That splits the leak-detection approach cleanly:

| Layer | Runs | Technique |
| --- | --- | --- |
| `XttyCore` (`TerminalSession`, `SessionRegistry`, `Pane`, `PaneNode`) | **in-process** unit tests | ✅ `addTeardownBlock { sut = nil; XCTAssertNil(weakSUT) }` weak-sentinel |
| App layer (`TerminalWindowController`, `PaneController`, …) | **out-of-process** XCUITest | ✅ DEBUG state-dump census (above) — weak-sentinel is impossible across the process boundary |

`XCTMemoryMetric` / `measure(metrics:)` exists but adds nothing over the existing `MemorySampler` → **not adopted**.

---

## 3. The one-time deep pass — `leaks` / Instruments ✅ CLI-able, ❌ not a CI gate

Fully scriptable and headless; **no entitlements beyond the `get-task-allow` that debug builds already carry**, ad-hoc signing sufficient, no SIP exception:

- `MallocStackLogging=1 leaks -atExit -- <app>` — exit-time true-leak detection (+ `-outputGraph` `.memgraph` for run-to-run `-diffFrom`).
- `xcrun xctrace record --instrument Leaks|Allocations --launch -- <app>` — headless Instruments; `xctrace export` to XML for scripting.
- `vmmap --summary` / `heap` / `malloc_history` — VM regions (IOSurface / glyph atlas), heap-by-size, allocation backtraces.

Wrap as `scripts/audit-leaks.sh` + a `make audit-leaks` target for reproducibility. **Do not CI-gate on leak counts** — in complex Swift/AppKit, pooled memory and intentional caches yield more false positives than true leaks; the realistic path is a one-time manual pass whose findings are encoded as the census net + a code-review checklist, with the script available for re-runs and `.memgraph` baselines for diffing.

---

## 4. What the census can't name → SwiftTerm (the real Instruments target) ❓

Pane teardown on xtty's side is **clean**: `LocalProcess.terminate()` closes the PTY fd (`LocalProcess.swift:491`), SIGTERMs the child (`:495`), cancels the `DispatchSourceProcess` monitor, and stops the read loop; all four delegate vectors are `weak`. The black box is SwiftTerm's renderer:

- ❓ **Unbounded glyph/font caches** — `glyphCache`, `scaledFontCache`, `customGlyphCache` (`MetalTerminalRenderer.swift:199-204`) have **no LRU / size cap**, cleared only on atlas reset. A long session with many unique glyphs accumulates entries. (The atlas texture itself *is* bounded — 1024² → max 2048².)
- ❓ **Incomplete renderer `deinit`** (`:296-298`) cancels the cursor-blink timer but does **not** explicitly clear the caches/textures (fine if the renderer is released; a risk if it is retained).
- ❓ **`LocalProcess.swift:187` write handler captures `self` strongly** — must verify it releases when `io?.close()` runs on `terminate()`.

These are **third-party and unnameable by the census** → they are precisely the target of the one-time Instruments/`vmmap` pass: profile glyph-cache growth + texture/write-handler release across open/close churn. The big memory item (scrollback) is already bounded + asserted (P2/P7a). Note: xtty uses the **CoreGraphics** path (P7b verdict), so the Metal-renderer cache observations are an upper bound on what xtty actually exercises; confirm the CG path's equivalent during the pass.

---

## 5. Footprint-after-churn — report-only, never gated ✅

A "does the floor rise after open/close×N?" footprint check is **too noisy to gate**: P7a/P7b measured ~14 MB same-scenario variance (idle 66–69 MB; saturated 122–136 MB), and lazy page reclaim + autorelease-pool lag + OS paging mean freed memory lingers in RSS unpredictably. The **instance census covers the same risk deterministically** (a leaked pane is a `+1`, not a fuzzy delta). So: census **gated**; footprint-churn **optional + informational** only.

---

## 6. Scope, divergence, and the recommended change

**Gates nothing downstream.** P7b closed the renderer gate (keep CoreGraphics, skip Phase 8); distribution is orthogonal. P7c is pure pre-distribution hardening.

**Recommended scope:**
1. The DEBUG live-instance census (6 types) → `liveInstanceCounts` in the state dump.
2. The churn XCUITest (the gated regression net) + weak-sentinel teardown tests for the `XttyCore` model types.
3. `scripts/audit-leaks.sh` + `make audit-leaks`; a one-time `leaks`/Instruments pass focused on SwiftTerm glyph-cache + texture/write-handler release; write up the result here.
4. Fix the 2 nits (`dumpTimer.invalidate()`; `BenchmarkRunner` `[weak controller]`).
5. **Defer:** distribution (Hardened Runtime + Developer ID + notarization).

**Divergence from the raw synthesis — drop the `max-memory-mb` config key.** The scope agent's "Option B" proposed a `max-memory-mb` regression-gate config key (~55 MB). Rejected here: (a) it contradicts §5 (footprint is too noisy to gate); (b) a user-facing knob can't *do* anything at runtime without dropping scrollback; (c) it adds a feature with no real behavior, against the project's "avoid scope creep / not a full IDE" value. The census is the gate; any footprint number is report-only. No config key.

**Name:** **`add-lifecycle-census`** (the census is the durable deliverable; the Instruments run is a one-time step *inside* it) — preferred over the agents' `add-instruments-audit`. Fork-free, harness-first.

---

## Addendum (2026-06-29) — apply result: census shipped, net proven, `leaks` clean

`add-lifecycle-census` implemented (`/opsx:apply`). Outcomes:

- ✅ **Live-instance census shipped** — `#if DEBUG nonisolated(unsafe) static var liveCount` (init `++` / deinit `--`) on `TerminalWindowController`, `PaneController`, `XttyTerminalView`, `GitReviewController`, `QuickTerminalController`, and (via the owning `PaneController`, main-actor) `TerminalSession`; surfaced as `liveInstanceCounts` in the state dump. **Mechanism note:** the design's D1/D2 aimed for a plain `@MainActor static Int` and *no* `nonisolated(unsafe)` in XttyCore, but Swift's `deinit` is **nonisolated** — mutating a `@MainActor` static from it doesn't compile, and a bare nonisolated static is flagged "not concurrency-safe." Resolved by using `nonisolated(unsafe)` with the documented single-owner/main-thread vouch (the same pattern `GlobalHotKey` already uses for its Carbon refs); design D1/D2 updated to match. DEBUG-only, so a worst-case miscount never touches shipping behavior.
- ✅ **The churn net is proven, not just present.** The churn XCUITest (`XttyLifecycleCensusUITests`) drives split×4 + tab×3 create/close cycles and polls the census back to baseline. Sanity-checked by **injecting a deliberate `leakSelf = self` retain into `PaneController`** → the test failed loudly (`PaneController … baseline 1, final 8`, with `XttyTerminalView`/`TerminalSession` dragged along, while `TerminalWindowController` correctly stayed at baseline — per-type granularity works) → reverted. So the guard demonstrably catches a real cycle.
- ✅ **In-process weak-sentinel tests green** — `LifecycleLeakTests` confirms `TerminalSession`, `SessionRegistry`, and `Pane` deallocate once released (229 XttyCore tests, +3).
- ✅ **`leaks` is clean at idle** — `make audit-leaks` (`scripts/audit-leaks.sh`, the diagnostic-not-gate target) + a live snapshot: `Process: 0 leaks for 0 total leaked bytes` (rc 0). The `leaks --atExit` bench path writes a `.memgraph` but its summary is muffled under ad-hoc signing ("process is not in a debuggable environment" limits MallocStackLogging) — the live-`leaks <pid>` snapshot is the trustworthy read here; for full glyph-cache backtraces, a `XTTY_SIGN_IDENTITY=xtty-dev` build is the follow-up.
- ❓ **SwiftTerm glyph/font caches remain the open watch-item** (unbounded, third-party, unnameable by the census) — not patched (fork-free); `vmmap`/`.memgraph` inspection under sustained unique-glyph load is the manual deep-dive when warranted. Bounded scrollback already caps the dominant term, and idle leaks are zero.

Net: xtty's own lifecycle is leak-clean and now has a permanent, deterministic regression guard. Distribution remains the only deferred Phase-7 item.

---

## Sources

- Repo (read-only): `App/{GitReviewController,LinkRoutingTerminalDelegate,PaneController,TerminalWindowController,GlobalHotKey,XttyApp,BenchmarkRunner,MemorySampler,UITestDump}.swift`; `XttyCore/Sources/XttyCore/{SessionRegistry,TerminalSession,Pane}.swift`; `AppUITests/` (`StateDumpReader`); `external/SwiftTerm/Sources/SwiftTerm/{LocalProcess,Terminal,Mac/MacTerminalView,Mac/MacLocalTerminalView,Apple/Metal/MetalTerminalRenderer,Apple/Metal/GlyphAtlas}.swift`.
- macOS man pages: `leaks(1)`, `xctrace(1)`, `vmmap(1)`, `heap(1)`, `malloc_history(1)`; `MallocStackLogging` semantics.
- xtty research: [P7 measurement methodology](p7-measurement-methodology.md) (the closed renderer gate; memory-variance evidence), [milestones Phase 7](../04-design/02-milestones.md), [stack sketch](../04-design/01-stack-sketch.md) (the engine seam), [SwiftTerm fork-vs-patch strategy](swiftterm-fork-vs-patch-strategy.md).
- Workflow: `/opsx:explore p7c` + the 14-agent P7c research workflow (2026-06-29).
