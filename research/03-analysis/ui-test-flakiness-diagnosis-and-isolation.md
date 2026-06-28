# UI-test flakiness: tracing, human-vs-automation attribution, and isolation

> **Provenance:** Drafted 2026-06-28 after a real flake — one `XttyMultiplexingUITests` failure in a full-suite run that passed on isolated re-run and in two other full runs; the developer reported it was caused by their own mouse movement / mis-click during the run. Produced by **three research workflows**, each with an adversarial-verifier phase, grounded in this repo + live `xcrun xcresulttool`/`xcodebuild -help` runs on this machine (Xcode 26.6, `xcresulttool` 24757, macOS 26.2) + targeted web lookups: (1) *flaky-trace-research* (what's captured, synthetic-vs-human events, app instrumentation, ops/retry); (2) *flaky-differential-research* (diff a failing run vs passing runs to classify); (3) *isolated-uitest-research* (VM / separate session / in-process driving). Load-bearing claims carry ✅ verified / ❓ uncertain / ❌ false. Builds on [native-app-testing-tooling](native-app-testing-tooling.md) (the AX-content ceiling that forces engine/state-dump assertions) and the [Peekaboo input-reliability](../../) memory (synthetic typing drops chars under contention).

## TL;DR

- **Tracing the *automation's* actions needs nothing new.** `xcrun xcresulttool get test-results activities` already records every XCUITest step with an epoch `startTime` and an `isAssociatedWithFailure` flag that pins the failing step. ✅
- **A trace diff *localizes* a flake but cannot *attribute* it.** "Something weird" (stolen focus, a `waitForState` timeout, a no-op assertion) is produced **identically** by a human mis-click *and* by a real internal race. ✅ (adversarially confirmed). Differential analysis answers *where/when*, never *why*.
- **Attributing a failure to a human needs an out-of-band input signal.** The strongest one on macOS: a hardware event carries `kCGEventSourceUnixProcessID == 0`; XCUITest-synthesized events carry a non-zero (Runner) PID. A bare `mouseMoved` is the cheapest tripwire (XCUITest warps the cursor and never streams moves). Heuristic, not guaranteed — **calibrate once**. ✅ (verified against WindowServer's own sender-PID gate; posting via the HID tap does **not** zero the PID).
- **The classification is asymmetric.** A hardware event in the failure window ⇒ HIGH-confidence *human → re-run*. A *clean* trace never proves *not-human* (a human move that misses the app's windows is invisible to a local monitor). So *real-bug, high confidence* only comes from **reproduction across clean reruns**, and the honest default is **INCONCLUSIVE → re-run** — which `-retry-tests-on-failure` automates.
- **You cannot isolate XCUITest from the real cursor on the dev's own session.** ❌ macOS has no per-app virtual HID for host apps. Real isolation comes from a **VM** (its own WindowServer + virtual HID — *works but heavy*) or from **not using OS event synthesis at all** (drive the app **in-process** via a DEBUG channel — *highest ROI*). A second **login session is a trap** (the only config that frees your input — a backgrounded fast-user-switch session — is Apple-unsupported and flaky).
- **Recommended primary fix: a layered pyramid driven by in-process testing**, not a VM. Shrink how many tests need the real-event path; run the small remainder isolated with auto-retry.

---

## Part 1 — What is already captured (the automation trace)

The `.xcresult` (in `~/Library/Developer/Xcode/DerivedData/xtty-*/Logs/Test/Test-*.xcresult` — we pass no `-resultBundlePath`) records a complete, queryable action timeline. ✅ Verified live:

```bash
B=$(ls -dt ~/Library/Developer/Xcode/DerivedData/xtty-*/Logs/Test/Test-*.xcresult | head -1)

# which test failed
xcrun xcresulttool get test-results tests --path "$B" | grep -B2 '"result" : "Failure"'

# full ordered action timeline; jump to the failing step
xcrun xcresulttool get test-results activities --test-id "<Suite/test()>" --path "$B" \
  | grep -nA1 '"isAssociatedWithFailure" : true'

# failure-tied screenshots/attachments (if any were captured)
xcrun xcresulttool export attachments --path "$B" --output-path /tmp/att --only-failures
```

- Every activity node carries `startTime` (epoch seconds), a human `title` (`"Type 'd' key with modifiers '⌘'"`, `"Wait for com.xtty.app to idle"`, `"Synthesize event"`), and `isAssociatedWithFailure` (flips `true` on the failing leaf + ancestors). ✅
- The XCUITest **event spine is deterministic per test** (the test body is fixed Swift), so the activity list is identical run-to-run — the basis for the Part-2 diff. ✅
- **Screenshots:** this repo keeps **only manual** `XCTAttachment`s (the `attachScreenshot()` helper, `AppUITests/XttyUITestSupport.swift:76`); there are **no automatic per-step screenshots and no video** because the scheme uses no test plan. ✅ Attachments are tagged with `isAssociatedWithFailure` (so `--only-failures` works). To get auto-capture/video you must add an `.xctestplan` (wired via `project.yml`, since the `.xcodeproj` is generated). ❓ exact test-plan keys not verified.
- Bonus flag for triage: `-collect-test-diagnostics on-failure` collects a sysdiagnose-style bundle on failure. ✅

**This already covers "trace back what the automation did and where it failed."** What it does *not* contain is any record of *human* input — that's Part 2.

---

## Part 2 — Telling human interference from a real bug

### 2a. The differential approach (localizes, does not attribute)

Diff the failing run against ≥1 passing run **of the same test, ideally from the same bundle** (a `-retry-tests-on-failure` pass+fail pair is the ideal dataset — same build, same machine). The diff reliably finds the **first step `N` whose app-state diverges** from the passing baseline, giving a wall-clock window `W = [startTime(N) − δ, end(N) + δ]`, `δ ≈ 0.30s` (2× the 0.15s dump-timer period). Useful divergence signals (each from the activity tree + the `/tmp/xtty-state-dump.json` time series):

| Signal | passing | human-interference | real-bug |
|---|---|---|---|
| `app.state` (`XttyMultiplexingUITests.swift:79`) | `.runningForeground` | **`.runningBackground`** (deactivated by a click) ✅ strong | `.runningForeground` |
| failing assert's actual value | expected | the **unchanged prior** value (keystroke went elsewhere → no-op) | a **different wrong** value (app mis-handled) |
| `"Wait for app to idle"` duration | tens of ms | **abnormally long** (focus theft) | usually short |
| the failed `waitForState`/`waitForExistence` | resolves fast | runs to full timeout | full timeout *or* fast |
| key window / focused pane | the test's window | a **foreign** key window | the test's window |

**Hard caveat (adversarially confirmed ❌ for the naive hypothesis):** every one of these channels — focus loss, timeout, "no-op", wrong state — is produced **equally** by an internal race (e.g. a window-key race, the quake panel stealing key, a dropped event). *"Weird ⇒ human" is a fallacy.* The diff is a **localizer, not an attributor**.

### 2b. The attributor (an out-of-band input signal)

The only thing that proves *external cause* is an event the test never synthesized:

- **Primary:** `CGEventGetIntegerValueField(e, kCGEventSourceUnixProcessID)` — **`0` ⇒ genuine hardware (human)**; non-zero ⇒ posted/synthetic (XCUITest Runner). This is the exact field WindowServer keys on (it logs *"Dropping … event because sender's PID (899) isn't 0 or self"*), and posting through `kCGHIDEventTap` does **not** zero it. ✅ Heuristic, version-dependent → **calibrate the Runner PID once** during a known-clean pass.
- **Cheapest tripwire:** any **`mouseMoved`/`mouseDragged`** during a test — XCUITest teleports the cursor and never streams moves, so a move burst = a human hand. ❓ strong in practice.
- **Useless:** `kCGEventSourceStateID` (`hidSystemState` is a state *table*, not an origin flag — a synthetic event built on a HID-state source reports `1` too). ❌ The undocumented `0x20000000` "posted" bit is folklore. ❌
- **Observation channel without a TCC prompt:** `NSEvent.addLocalMonitorForEvents(matching:)` sees events delivered to *this* app and reads `NSEvent.cgEvent` source fields — no Accessibility grant, and it sidesteps that xtty can't override SwiftTerm's `public` (not `open`) `mouseDown`. A system-wide `CGEventTap`/global monitor needs Accessibility and may be blocked for the sandboxed runner. ✅

### 2c. The sound combined protocol

A verdict is **sound** only with: (1) a **localized divergence** (2a) + (2) an **out-of-band input trace** on the same epoch clock (2b) + (3) **rerun reproducibility**. Decision tree (first match wins):

1. **Hardware-sourced event (PID 0 / bare `mouseMoved`) in `W` with no overlapping XCUITest injecting activity** → **HUMAN → re-run.** Confidence HIGH. (A `resignKey` *alone* → at most MEDIUM — a race can also drop key.)
2. **Divergence in `W` but every event is Runner-PID-synthetic overlapping its activity**, and it **reproduces across clean reruns** → **REAL BUG → investigate.** (single occurrence → MEDIUM.)
3. **Anything ambiguous** (synthetic-but-late; `resignKey` coincident with a focus-changing action; flag unavailable; human move that missed the window) → **INCONCLUSIVE → re-run.** This is the honest default.

Asymmetry: *presence* of a hardware event strongly implies human; *absence* never proves not-human. So REAL-BUG-high-confidence is earned by **reproduction on a quiet machine**, not by a clean single trace.

---

## Part 3 — Isolating tests from the developer's hardware

### Hard constraints (don't fight them)

- ❌ **No host-session XCUITest without driving the real cursor/keyboard.** macOS synthesizes input through the active session's real WindowServer; there is no iOS-Simulator-style virtual HID for host apps.
- ❌ **"Keyboard-only" is not isolation** — `typeText`/`typeKey` still post to the *focused* app in the shared session (xtty's suite has **40** such call sites — the current flakiness source).
- ❌ **XCUITest needs an unlocked, GUI-rendering session** — a locked screen / screensaver / lidless-headless Mac breaks it. `caffeinate` mitigates sleep, doesn't create a session.
- ❌ **The AX tree will never carry terminal text** (custom-drawn view) — which is *why* the DEBUG grid/state dumps exist; "assert via AX" is not an escape hatch.

### The three avenues

| Dimension | **A. macOS VM** (Tart/UTM/VZ) | **B. Separate login session** | **C. In-process DEBUG driving** |
|---|---|---|---|
| Setup cost | High (50–90 GB image, full Xcode + Metal Toolchain *inside* guest) | Low–med | **Low** (pattern already exists) |
| Tests the real event path? | ✅ full fidelity | ✅ (only when frontmost) | ❌ bypasses OS events |
| Flakiness reduction | ✅ high (own HID) | ⚠️ low (FUS fragility) | ✅✅ highest (deterministic) |
| Lets dev keep working? | ✅✅ yes | ❌ no | ✅✅ yes |
| Solo Apple-Silicon fit | ⚠️ works but **heavy** (secondary tier) | ❌ **trap** | ✅✅ excellent |

- **A — VM ✅ but heavy.** A VZ guest (leanest: **Tart**) has its own WindowServer + virtual HID, so the host cursor is free and XCUITest runs unbothered — the proven Mac-CI pattern. The 2-macOS-guest-per-host cap is a non-issue for one dev. Building needs only the offline **Metal Toolchain** (no runtime GPU), and xtty runs fine under paravirtual graphics today (AppKit/Core-Text grid path, not the deferred Metal renderer — re-validate if/when P8 lands the own-renderer). Real tax: image size, a full in-guest Xcode install, golden-image upkeep, cold-build slowness, and **guest-OS/IPSW matching** to host 26.2 (prebuilt Tart images lag the host). → *secondary isolation tier for a small E2E suite, not the daily loop.*
- **B — separate session ❌ trap.** Only one Aqua session owns the physical display/HID. The robust shape (test user **frontmost**) takes over your screen (defeats the goal); the goal-satisfying shape (test user **backgrounded** via fast-user-switching) keeps its WindowServer alive but isn't compositing → App-Nap pauses, black screenshots, unreliable interaction, and is **Apple-unsupported**. Don't invest.
- **C — in-process driving ✅✅ highest ROI.** xtty already does this in two spots: `toggleQuickTerminalForTest` (`App/XttyApp.swift:92`, calls `toggle()` directly) and `routePendingTestLink` (`:101`, reads a path from the `XTTY_TEST_LINK_PATH` launch env — solving the sandboxed-runner-can't-write-`/tmp` problem — and routes through the *real* pipeline). Generalize these into **one DEBUG command channel**: the runner writes a JSON command queue to its own writable temp dir, passes the path via launch env, the existing 0.15s timer drains it and dispatches to the **same internal entry points** the responder chain uses (`PaneController.splitPane/closePane/moveFocus`, `TerminalWindowController.focusPane`, feed bytes to the engine for "type"), echoing an applied-`seq` into the state dump as a sleep-free happens-before barrier. No synthesized OS events → no cursor, no focus races, deterministic, and the dev keeps working. **Coverage hole (named + bounded):** it bypasses NSEvent delivery, first-responder resolution, `validateUserInterfaceItem`, keybinding-chord→action parsing, the Carbon global hotkey, and mouse hit-testing — so a thin true-E2E slice must retain those.

---

## Part 4 — Recommendation (layered pyramid, ordered by ROI)

1. **Cheap wins now (no code):** wrap UI runs in `caffeinate -dimsu` and add auto-retry so single human blips self-heal:
   ```bash
   caffeinate -dimsu xcodebuild -project xtty.xcodeproj -scheme xtty test \
     -only-testing:xttyUITests \
     -retry-tests-on-failure -test-iterations 3 -test-repetition-relaunch-enabled YES
   ```
   ✅ flags verified (Xcode 26.6): re-runs only failed tests, fresh process each attempt, eventual-pass ⇒ green exit; the `.xcresult` still records the flake (mine it for retried-but-passed tests so retries don't hide creeping flakiness ❓).
2. **Layer 1 — keep growing `XttyCore` SPM unit tests** (already hardware-free; the bulk of logic). ✅
3. **Layer 2 (the structural fix, highest ROI) — a DEBUG in-process command channel.** Generalize the three existing back-doors; migrate the model/behavior-level coverage (multiplexing model, semantic capture, sidebar activity, link resolution, config-applied) off synthesized `typeKey`/`typeText` onto it. Deterministic, hardware-independent, sandbox-correct, zero new infra.
4. **Layer 3 — trim true-E2E XCUITests to ~6–8** whose whole point *is* the real OS path: real typed echo, multi-line paste, live resize, the find bar, one chord→responder smoke, one menu-validation smoke, one real-zsh OSC smoke. Run them with the Step-1 wrapper.
5. **Diagnosis instrumentation (enables Part 2):** add a DEBUG, `-UITestGridDump`-gated `NSEvent` local monitor + reuse the focus seams (`didBecomeKey`/new `didResignKey`, `setActivePane`) → a bounded ring buffer flushed by the existing timer to `/tmp/xtty-event-trace.jsonl` with `{epoch, type, locationInWindow, sourceUnixPID, sourceStateID, keyWindow}` per event; and add a `dumpTime`/`seq` field to the state dump so app state aligns to the xcresult `startTime`. Then the Part-2c protocol becomes runnable: cross-reference the failing step's `W` against the event trace. Calibrate the Runner PID once. (Lean: `#if DEBUG`, bounded ring, no shipping cost.)
6. **VM (Avenue A) is optional icing** — stand up a Tart guest only if you later want a small E2E suite to run truly unattended while you work; not the primary loop.

**On the original flake:** it passed on isolated re-run + 2 clean full runs and the dev reports a mis-click — consistent with HUMAN-interference. With Step 5's instrumentation it would have been *provable* (expect a PID-0 / `mouseMoved` event in `W`); without it, Step 1's auto-retry already makes it a non-event. The actionable decision (what to build) belongs in a future OpenSpec change against the `verification-harness` capability.

---

## Sources

- **Workflows** (2026-06-28, this session): *flaky-trace-research*, *flaky-differential-research*, *isolated-uitest-research* — each with an adversarial-verifier phase, over local source + live `xcrun xcresulttool`/`xcodebuild -help` on this machine + web.
- **Live tooling:** `xcrun xcresulttool get test-results {tests,activities,test-details}` + `export attachments [--only-failures]` (v24757); `xcodebuild -help` (Xcode 26.6) for `-retry-tests-on-failure` / `-test-iterations` / `-test-repetition-relaunch-enabled` / `-collect-test-diagnostics` / `-skip-testing`.
- **macOS events:** WindowServer sender-PID synthesis gate ([nick-liu.com](https://www.nick-liu.com/posts/tahoe-hotkey-dead-end/)); [CGEventSourceStateID](https://developer.apple.com/documentation/coregraphics/cgeventsourcestateid) / [eventSourceUserData](https://developer.apple.com/documentation/coregraphics/cgeventfield/eventsourceuserdata); [Quartz Event Services Ref]; XCUITest "Failed to synthesize event" ([Apple Forums 125551](https://developer.apple.com/forums/thread/125551)).
- **VM / sessions:** [Tart](https://github.com/cirruslabs/tart) + [quick-start](https://tart.run/quick-start/); [Apple — Virtualize macOS on a Mac](https://developer.apple.com/documentation/virtualization/virtualize-macos-on-a-mac); [Eclectic Light — how Apple limits VMs](https://eclecticlight.co/2022/08/04/virtualisation-on-apple-silicon-macs-8-how-apple-limits-vms/) + [Fast User Switching](https://eclecticlight.co/2023/03/22/fast-user-switching-how-it-works-and-when-to-use-it/); [aahlenst — macOS GUI in automation contexts](https://aahlenst.dev/blog/accessing-the-macos-gui-in-automation-contexts/); [Veertu — XCUITest in macOS VMs](https://veertu.com/ios-simulator-tests-in-macos-vms-xcuitest-simulator-tests-on-anka-build-macos-cloud/).
- **In-repo:** `App/XttyApp.swift` (DEBUG hooks + dump timer), `App/UITestDump.swift`, `App/TerminalWindowController.swift` (state dump, focus seams), `App/XttyTerminalView.swift` (responder selectors), `AppUITests/XttyUITestSupport.swift` (StateDumpReader, attachScreenshot), [native-app-testing-tooling](native-app-testing-tooling.md).
