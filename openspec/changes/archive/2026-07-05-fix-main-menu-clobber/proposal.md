# Fix Main Menu Clobber

## Why

xtty has a user-facing product bug: on slow machines (and ~100 % of the time on 3-vCPU CI/VM guests), SwiftUI's scene-synthesized default menu **clobbers xtty's custom main menu** — users lose the Edit/View/Terminal/Window menus and every menu key equivalent (⌘D, ⌘F, ⌘V, ⌘W, ⌘T, ⌘⌥arrows). This is the root cause of all 7 persistent CI XCUITest failures (run `28472076179`, reproduced exactly in two independent local VM rigs). The mechanism is fully attributed at source level (`research/03-analysis/swiftui-mainmenu-clobber-forensics.md`): under the SwiftUI `@main App` lifecycle, SwiftUI's private `AppDelegate` (the *real* `NSApp.delegate`) runs an identifier-keyed menu reconciler that never matches plain `NSMenuItem`s and therefore strips every custom item **in place** — a per-launch race that fast bare metal wins and slow guests lose. Re-asserting the menu, `.commandsRemoved()`, and rebuild-on-notification are all **experimentally refuted**; eliminating the second menu owner is the only durable fix.

## What Changes

- **Drop the SwiftUI App lifecycle for `NSApplicationMain`** (the Ghostty-precedented pattern): delete the `@main struct XttyApp: App` construct (and its inert `Settings` scene, which nothing uses); add an `App/main.swift` that strongly retains the existing `AppDelegate`, sets it as `NSApplication.shared.delegate`, and calls `NSApplicationMain`. `AppDelegate` is otherwise unchanged (one rider, next bullet). SwiftUI remains for embedded views (`NSHostingView`: sidebar, git review) — only the *lifecycle* changes.
- **Rider:** implement `applicationSupportsSecureRestorableState → true` (the one SwiftUI delegate-proxy default we lose).
- **Menu-integrity canary (observe, never repair):** the DEBUG state dump gains a `mainMenuTitles` field (top-level menu titles, **title-based** — identity-based sensors are proven blind to the in-place mutation); Cmd-driving XCUITest suites gain a fatal precondition that xtty's own menus exist before driving key equivalents.
- **Red→green witness:** the state dump gains a `windowCount` field and the Cmd+N test asserts a real second window (this test currently passes **vacuously** on CI; landing the assert with the fix converts it into the cleanest witness that menu dispatch works).
- **Not in scope** (successor truthing change, per the exploration split): quake XCTFail-on-missing-Debug-menu, the shared `requireStateDump()` refactor, pasteboard instrumentation, the always-on diagnostic test, the `.function` mask strip, and **stripping the find-bar test's existing in-test menu-click fallback** (`XttyUITests.swift:157-160` — the one pre-existing in-test retry of this failure class; task 2.3's "never retry" applies to the new canary only) — kept out so the fix's ×2-VM-run validation readout has a minimal diff.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `app-shell`: ADDED requirement — the application SHALL install its own main menu and keep it intact (every xtty-defined top-level menu + key equivalents) for the entire app lifetime regardless of machine speed or launch timing; no framework-synthesized default menu may replace or mutate it.
- `verification-harness`: MODIFIED requirement (*Deterministic content assertion channel*) — the DEBUG state dump additionally exposes the **main-menu top-level titles** (title-based, never object identity) and the **top-level window count**, so menu integrity and window creation are deterministically assertable.

## Impact

- **Code:** `App/XttyApp.swift` (delete the `@main` struct + `import SwiftUI`; add the secure-restorable-state override), new `App/main.swift`, `App/TerminalWindowController.swift`/`App/UITestDump.swift` (dump fields), `AppUITests/` (canary precondition + Cmd+N `windowCount` assert). `project.yml` needs no functional change (`NSPrincipalClass: NSApplication` already set; one stale comment refreshed).
- **Tests:** all 7 CI-failing XCUITests are expected to flip green; validation is **pre-registered** as ×2 full-suite runs in the VM rig (fresh clone of `xtty-test:26.5`, no retry flag) — bare-metal green proves nothing because the race never fires there. Residual reds must map to the pre-registered second-order matrix (research `github-actions-ci-cd.md` §15f: quake bodies newly exercised; confirm-close newly reachable — mitigated if `harden-churn-shell-readiness` lands first, which is advisory sequencing, not a dependency).
- **Open-change interactions (pre-registered):** `retire-metal-renderer` and `harden-churn-shell-readiness` both carry MODIFIED deltas of the same *Deterministic content assertion channel* requirement — whichever of the three changes archives last MUST re-paste the block as already merged by the earlier archives. Protection is made **symmetric at apply time**: this change also updates the *other two changes'* task lists (rewording `retire-metal-renderer`'s two-way reconciliation task to the three-way rule; inserting the missing reconciliation task into `harden-churn-shell-readiness`) so no archive ordering silently reverts merged text (task 5.4). No spec/artifact collision with `add-xtty-test-image`/`test-image-bash-shell`, but the validation protocol **consumes their product** — the bash-shell `xtty-test:26.5` golden image (its bash degradation arms and absent Local Network modal are part of the expected envelope; validating on a different rig invalidates the readout). `ci.yml` stays owned by `add-ci-pipeline`.
- **Users:** menus become reliable on slow/loaded machines; no behavior change otherwise. No config, no migration.
