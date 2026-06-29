## Context

P7c is the leak/retain pass behind the **lean memory / avoid retain cycles** product value (`AGENTS.md` → Product values), the last hardening before the deferred distribution work. The renderer gate closed in P7b (keep CoreGraphics), so P7c gates nothing downstream.

The research ([`p7c-leak-retain-audit`](../../../research/03-analysis/p7c-leak-retain-audit.md)) established the current state with file:line evidence: xtty's own code is **clean** — both suspected retain cycles (`WindowController⇄GitReviewController`, `PaneController⇄LinkRoutingTerminalDelegate`) were refuted (every stored closure `[weak self]`, every delegate back-reference `weak`, `GitReviewTarget` a transient value type), and an App-layer sweep found zero cycles. Two constraints shape the design: (1) the custom-drawn terminal view exposes nothing to accessibility, and (2) XCUITests run **out-of-process**, so a UI test cannot hold a `weak` reference to an in-app object — App-layer object lifetimes can only be observed through the existing DEBUG state-dump side channel (the same channel P4a/P5/P6/P7 already use).

P7a/P7b precedent: each shipped a reusable, fork-free instrument that rides the 0.15 s DEBUG dump timer and is asserted by an e2e against the state dump. P7c follows that pattern for lifecycle leaks.

## Goals / Non-Goals

**Goals:**
- A deterministic, reproducible regression net that fails when a lifecycle-bearing object leaks (a retain cycle reintroduced by a future change).
- In-process deallocation coverage for the view-free model types, where it's cheap and exact.
- A re-runnable OS-leak-audit entry point for the one-time deep pass (and future spot-checks), targeting what the census can't name (SwiftTerm internals).
- Zero footprint in shipping builds.

**Non-Goals:**
- Footprint-after-churn measurement / a memory ceiling gate (too noisy — see Decisions).
- A `max-memory-mb` config key (no runtime behavior).
- Patching SwiftTerm's unbounded glyph caches (profile, don't fork).
- Distribution (Hardened Runtime / Developer ID / notarization) — separately deferred.
- CI-gating on OS-leak-tool output (false-positive-prone).

## Decisions

### D1 — Census mechanism: `#if DEBUG @MainActor static var liveCount`, plain `Int`, no atomics
Each lifecycle type gets a `#if DEBUG static var liveCount = 0`, `+= 1` in `init`, `-= 1` in `deinit`. The six App-layer/lifecycle types are all already `@MainActor` (`TerminalWindowController`, `PaneController`, `XttyTerminalView`, `GitReviewController`, `QuickTerminalController`), so the counter is touched only on the main actor → a plain `Int` is race-free; **no atomics dependency**. `deinit` is `nonisolated` in Swift, so the decrement uses the same vouched-for main-thread-ownership contract already documented for `GlobalHotKey`'s Carbon refs (these objects are created/destroyed on the main thread). *Alternative considered:* `swift-atomics`/`OSAtomic` — rejected as needless dependency + overhead for serially-accessed counters.

### D2 — `TerminalSession` counted from `PaneController`, to keep `XttyCore` clean
`TerminalSession` lives view-free in `XttyCore` and is intentionally non-isolated. It is created/destroyed **only** inside `PaneController` (on the main actor). Add a `#if DEBUG` static count + `recordInit()/recordDeinit()` to `TerminalSession`, called by `PaneController` from its main-actor context — so `XttyCore` gains no `nonisolated(unsafe)` and no isolation annotation. *Alternative considered:* increment/decrement inside `TerminalSession.init/deinit` directly — rejected to avoid threading/isolation assumptions leaking into the view-free package.

### D3 — Surface via a new `liveInstanceCounts` dict in the existing state dump
Add a `#if DEBUG` `liveInstanceCounts` field (type → count) to `TerminalWindowController.writeStateDump()` alongside `paneCount`/`memoryFootprintBytes`. This is the **only** channel an out-of-process XCUITest can read App-layer object lifetimes through. Additive — existing dump consumers are unaffected. *Alternative considered:* a dedicated census file — rejected; the dump is the established single side channel.

### D4 — The gated net is the **instance census**, not a footprint delta
The churn e2e asserts the deterministic count returns to baseline. Memory footprint is **not** gated: P7a/P7b saw ~14 MB same-scenario variance (lazy page reclaim, autorelease lag, OS paging), so a footprint-delta assertion would flake on CI. A leaked instance is a `+1` integer — zero ambiguity, and it *is* the retain-cycle signature (`SessionRegistry.panes` already treats pane existence as a clean count; the census extends that to the AppKit controllers). Footprint-after-churn is therefore not built (out of scope), not merely ungated.

### D5 — Two-tier leak testing: weak-sentinel (in-process) + census (out-of-process)
| Layer | Runs | Technique |
| --- | --- | --- |
| `XttyCore` model (`TerminalSession`, `SessionRegistry`, `Pane`) | in-process unit tests | `addTeardownBlock { sut = nil; XCTAssertNil(weakSUT) }` |
| App layer (window/pane/view/controllers) | out-of-process XCUITest | the `liveInstanceCounts` census + churn assertion |
Weak-sentinel is impossible across the XCUITest process boundary, so each layer uses the technique that fits. *Alternative considered:* `XCTMemoryMetric`/`measure(metrics:)` — rejected; adds nothing over the existing `MemorySampler` and is footprint-noisy.

### D6 — OS leak audit: a re-runnable command, explicitly not a CI gate
`scripts/audit-leaks.sh` + `make audit-leaks` run `leaks -atExit` (with `MallocStackLogging=1`, optional `-outputGraph` for `.memgraph` diffing) and `xcrun xctrace`/`vmmap` against the built app. No privileged install, no entitlement beyond the debug `get-task-allow` xtty already has, ad-hoc signing fine. It is a **diagnostic** — the normal `make build`/`make test` path never depends on it — because Swift/AppKit pooled memory and intentional caches make leak-count gating false-positive-prone. Follows the `make bench`/performance-harness precedent (a domain tool owned by its domain spec, not `build-workflow`). The one-time pass focuses on SwiftTerm's **unbounded glyph/font caches** + incomplete renderer `deinit` (the census can't name third-party allocations); findings are written into the research doc, not the spec.

### D7 — Fix the two sweep nits inline
`AppDelegate.dumpTimer` gains `invalidate()` on `applicationWillTerminate`; `BenchmarkRunner`'s `Task` adopts `[weak controller]` (matching `XttyApp`'s pattern). Both are DEBUG-only hygiene, no behavior change; folded in here rather than spun out.

## Risks / Trade-offs

- **A retain cycle could exist *between* two non-instrumented internals, invisible to the census** → the re-runnable OS-leak audit (D6) is the backstop for anything the per-type counts can't name; the census covers the lifecycle objects that actually churn (panes/tabs/windows).
- **`deinit` decrement runs off the main actor in principle** → mitigated by the single-owner, main-thread create/destroy contract these objects already hold (same basis as `GlobalHotKey`); DEBUG-only, so a worst-case miscount never affects shipping behavior.
- **Churn-test flakiness from teardown timing** (a close not yet propagated when the dump is read) → the test polls the dump via `StateDumpReader.waitForState` for the count to settle to baseline (with a timeout), rather than reading once.
- **SwiftTerm glyph caches stay unbounded** (not patched) → accepted: bounded scrollback already caps the dominant memory term, the caches grow only with *unique* glyphs, and xtty uses the CoreGraphics path; documented as a known third-party characteristic + a watch item for the audit, not a P7c fix.
- **`make audit-leaks` output isn't a gate** → intentional; its value is the one-time pass + spot-checks, with `.memgraph` baselines for diffing, not a flaky CI signal.

## Migration Plan

Additive and DEBUG-gated; no migration. The new `liveInstanceCounts` dump field is optional for consumers. Release builds are byte-for-byte unaffected (all census code under `#if DEBUG`). Rollback = revert the change; no persisted state or schema.

## Open Questions

- None blocking. The exact churn counts (how many tabs/splits/windows, how many cycles) are a test-tuning detail settled during apply; the assertion (return-to-baseline) is fixed.
