## Why

P7c is the Phase-7 leak/retain pass for the **lean memory / avoid retain cycles** product value, before distribution. Research ([`p7c-leak-retain-audit`](../../../research/03-analysis/p7c-leak-retain-audit.md), 2026-06-29) found **no leak to hunt** — both suspected retain cycles were refuted and an App-layer sweep was clean — so P7c is not "find & fix leaks" but **prove the hygiene holds, leave a reproducible regression net, and profile the one place we can't see (SwiftTerm)**. P7a/P7b each shipped a reusable instrument; P7c ships the lifecycle leak guard.

## What Changes

- Add a **DEBUG-only live-instance census** — a per-type live count (created→incremented, destroyed→decremented) on the lifecycle-bearing types (the window controller, pane controller, terminal-view wrapper, git-review controller, quick-terminal controller, and the view-free terminal session). Absent with zero overhead in shipping builds.
- Surface the census as a new `liveInstanceCounts` field in the existing DEBUG state dump (the only way an out-of-process XCUITest can observe App-layer object lifetimes).
- Add the **gated regression net**: a churn XCUITest that creates and destroys panes/splits/tabs/windows and asserts the live counts return to their pre-churn baseline (a count that fails to return = a retained instance = a leak/cycle).
- Add **in-process deallocation (weak-sentinel) tests** for the view-free `XttyCore` model types (`TerminalSession`, `SessionRegistry`, `Pane`) — the in-process complement the out-of-process UI tests can't provide.
- Add a **re-runnable leak/allocation audit command** (`make audit-leaks` + `scripts/audit-leaks.sh`) that runs the OS leak detector headlessly (no privileged install, no entitlement beyond the debug `get-task-allow`); a **diagnostic aid, explicitly NOT a CI gate** (false-positive-prone on Swift/AppKit pooled memory). Run it once against the scenarios, focused on SwiftTerm's unbounded glyph/font caches + incomplete renderer `deinit`; write the findings into the research doc.
- Fix the two cosmetic hygiene nits the sweep found: `AppDelegate.dumpTimer` never `invalidate()`d; `BenchmarkRunner`'s `Task` strong-captures `controller`.

**Out of scope (deliberate):** a footprint-after-churn measurement (too noisy to gate — the deterministic census covers the same risk); a `max-memory-mb` config key (a knob with no runtime behavior, contradicts the noisy-footprint finding); any SwiftTerm fork (the glyph-cache risk is profiled, not patched); distribution (Hardened Runtime + Developer ID + notarization remain deferred).

## Capabilities

### New Capabilities

- `lifecycle-census`: a DEBUG live-instance census of the lifecycle-bearing types, a churn regression assertion that counts return to baseline, in-process deallocation tests for the view-free model types, and a re-runnable (non-gating) OS leak-audit command.

### Modified Capabilities

- `verification-harness`: the DEBUG state dump gains the `liveInstanceCounts` field, and the harness gains end-to-end coverage that lifecycle churn returns the census to baseline.

## Impact

- **New code:** `liveCount` counters on the six lifecycle types (App layer + `XttyCore` `TerminalSession`); a census snapshot in `TerminalWindowController.writeStateDump()`; a new churn XCUITest; new XttyCore deallocation tests; `scripts/audit-leaks.sh` + a `make audit-leaks` target.
- **Changed code:** the state-dump JSON shape (additive); `App/XttyApp.swift` (timer invalidate) and `App/BenchmarkRunner.swift` (`[weak controller]`).
- **No change to:** runtime behavior in shipping builds (all census code is `#if DEBUG`), the renderer decision, the dependency set (fork-free), or the config schema.
- **Gates nothing downstream;** pure pre-distribution hardening.
