# Design — fix-main-menu-clobber

## Context

Under the SwiftUI `@main App` lifecycle, the real `NSApp.delegate` is SwiftUI's private `AppDelegate`; xtty's `AppDelegate` (via `@NSApplicationDelegateAdaptor`) is only a forwarding target. SwiftUI's `makeMainMenu` → `AppKitMainMenuItem.updateMainMenu` reconciler diffs the current `NSApp.mainMenu` keyed on SwiftUI's own item identifiers — plain `NSMenuItem`s never match — so any later pass strips every xtty item **in place** (the pointer never swaps; `setMainMenu:` fires only on first install). The initial pass is synchronous in `willFinishLaunching` (before xtty's assignment, harmless); the clobber is a second, deferred pass (`scenesDidChange`, by elimination) that slow guests schedule after `applicationDidFinishLaunching` and fast bare metal never fires. Full attribution, probe catalog, and refuted alternatives: `research/03-analysis/swiftui-mainmenu-clobber-forensics.md`; black-box VM proof: `local-macos-vm-ci-reproduction.md` §8/§9; fix-plan history: `github-actions-ci-cd.md` §15/§17.

Everything below was settled by measurement before this change was proposed; the design's job is to record the choices and their evidence.

## Goals / Non-Goals

**Goals:**
- Eliminate the second menu owner so xtty's main menu is durable on every machine speed (fixes the user-facing bug and the 7 CI failures).
- Make menu integrity and window creation observable in the DEBUG state dump (title-based canary + `windowCount`), so the fix — and any future regression — is deterministically assertable.
- Land the Cmd+N `windowCount` assertion as the red→green witness (it passes vacuously today).

**Non-Goals:**
- The broader harness truthing (quake XCTFail-on-missing-Debug-menu, shared `requireStateDump()`, pasteboard instrumentation, always-on diagnostic test) — successor change, kept out to keep the validation diff minimal.
- The `.function` mask strip (`KeybindAdapter.swift`) — its own bisectable commit/change per §15e item 6.
- Any menu *repair* mechanism (vetoed as a masking hazard — see D5).
- `ci.yml` edits (owned by the open `add-ci-pipeline`).

## Decisions

**D1 — `NSApplicationMain` via `App/main.swift` (drop the SwiftUI App lifecycle).**
The only fix that removes the mutating machinery rather than racing or feeding it: both `makeMainMenu` call sites are methods of `SwiftUI.AppDelegate`, which exists only when SwiftUI's `App.main` bootstrap runs; merely linking SwiftUI (for `NSHostingView`) does not instantiate it. Alternatives, all measured (forensics §3): re-assert same instance — no-op by construction; `.commandsRemoved()` — refuted live (probe5); rebuild-on-notification — refuted live (probe6 whack-a-mole + wrong trigger; Ghostty's deleted `CursedMenuManager` is the field record); SwiftUI Commands ownership — viable but a large restructure with swizzling precedent (CodeEdit), kept as the fallback if `NSApplicationMain` ever regresses. Prior art: Ghostty made exactly this migration in 2023 (commit `850bf3e9`) and ships it today with SwiftUI window content — the same hybrid xtty keeps.

**D2 — `main.swift` top-level code, not a `@main` type.**
`let delegate = AppDelegate(); NSApplication.shared.delegate = delegate; _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)`. The top-level `let` provides the strong delegate retention the adaptor used to supply (`NSApplication.delegate` is weak — dropping it would silently kill every delegate callback). Top-level code is MainActor-isolated under Swift 6 (SE-0343), so constructing the `@MainActor` `AppDelegate` compiles; a `@main` type would need `@MainActor static func main()` — more moving parts for no benefit. A `main.swift` cannot coexist with any `@main` in the module, so deleting the struct is mandatory, not stylistic.

**D3 — `AppDelegate` unchanged except one rider: `applicationSupportsSecureRestorableState → true`.**
The only SwiftUI delegate-proxy default we lose that matters; without it pure-AppKit runs log the secure-restorable-state warning. Windows are programmatic and state restoration is unused, so `true` is safe. Everything else in `AppDelegate` (menu build/install in `applicationDidFinishLaunching`, quake hotkey, DEBUG dump timer, benchmark mode, launch args/env triggers) is lifecycle-agnostic — verified file-by-file in the forensics migration map.

**D4 — No project.yml functional change.**
`INFOPLIST_KEY_NSPrincipalClass: NSApplication` is already set and there are no nibs/storyboards, which is exactly what nib-less `NSApplicationMain` needs; the `App/` source glob picks up `main.swift` on regeneration. Only the stale "SwiftUI App lifecycle" comment is refreshed.

**D5 — Canary observes, never repairs; titles, never identity.**
The DEBUG state dump gains `mainMenuTitles` (the top-level menu titles in order). Title-based because the proven mutation is in-place on the same object — the earlier identity sensor (`menuIsBuiltInstance`) read healthy through a 100 % clobber. Observe-only because a repair behind `-UITestGridDump` would green CI while leaving real users broken (§15 panel's masking-hazard veto). Cmd-driving XCUITest suites gain a fatal precondition (xtty-owned menu titles present before driving key equivalents) that attaches `menuBars.debugDescription` on failure — this canary would have named the root cause on CI run 1.

**D6 — `windowCount` + the Cmd+N assert ride along.**
The Cmd+N test currently passes without asserting a second window exists (vacuous, §15c). A state-dump `windowCount` plus the assert converts it into the cleanest red→green witness: red on today's CI (menu missing → Cmd+N no-ops), green with the fix. **Semantics pinned** (three plausible readings exist and the witness flips between them): `windowCount` = the number of live `TerminalWindowController`s — **native tabs included** (in xtty's model a tab *is* an `NSWindow` with its own controller; Cmd+T increments the count), the **quick-terminal accessory panel excluded** (matching every other harness/sidebar exclusion of the quake), never `NSApp.windows.count` (which would count the panel and chrome windows). Note the deferred-release transient: `windowControllerDidClose` removes controllers on the *next* runloop, so a count read immediately after a close may briefly lag — the witness asserts growth after open, which is unaffected.

**D7 — Validation is ×2 full-suite VM runs; bare-metal green is not evidence.**
The race never fires on fast bare metal (one menu pass per launch, pre-assignment), so local green cannot validate. Pre-registered acceptance: host `build-for-testing` → fresh clone of `xtty-test:26.5` constrained per `packer/README.md`'s **Runtime workflow** (`tart set --cpu 3 --memory 7168`, run **headless** — the display mode is outcome-changing: the README's parity runs measured graphics-mode focus-stealing as an extra red) → `test-without-building`, full suite, **no retry flag**, **twice** (the race is per-launch; Tart run 1 proved retry/flaky-pass masking). Expected: **every test passes except the one opt-in bench skip** — 41 pass / 0 fail / 1 skip against today's 42-test suite, or **40/0/1 of 41 if `retire-metal-renderer`'s deletion of the Metal e2e has landed first** (the packer/README envelope's 41-test total; that ordering is live since `add-xtty-test-image` hard-depends on it). Canary field shows xtty titles throughout both runs. Residual reds must map to the §15f second-order matrix (quake bodies newly exercised; confirm-close newly reachable — mitigated if `harden-churn-shell-readiness` lands first, an advisory ordering, not a dependency; ⌘⌥arrow matching on the guest OS is a probe). Anything outside the matrix is a stop-and-investigate. The protocol **consumes the bash-shell golden image** (`test-image-bash-shell`): its degradation arms and absent Local Network modal are part of the expected envelope — do not validate on the zsh-era or big-Tart rigs.

**D8 — Three-way spec-merge reconciliation, made symmetric.**
`retire-metal-renderer` and `harden-churn-shell-readiness` also carry MODIFIED deltas of *Deterministic content assertion channel*. This change's delta edits the **currently established** text; whichever of the three archives last MUST re-paste the block as already merged by the earlier archives (MODIFIED deltas replace the whole block — an unreconciled later archive silently reverts the earlier sentence). A task in this change guards its own archive — **and, because the other two changes' guards don't know about this one** (`retire-metal-renderer`'s reconciliation task is scoped two-way; `harden-churn-shell-readiness` has none), this change also **updates their task lists at apply time** (precedent: `retire-metal-renderer` task 5.2 edits `add-ci-pipeline`'s pending delta the same way). Without that, two of the six archive orderings silently delete this change's merged sentence + scenarios.

## Risks / Trade-offs

- [Swift 6 top-level isolation surprises] → settled by the first `make build` (task 1.3); the forensics migration map already checked SE-0343 semantics.
- [Delegate released → all callbacks silently dead] → the top-level `let` retention is load-bearing; the canary + basic launch tests would catch it immediately (no window, no dump).
- [An overlooked SwiftUI-lifecycle dependency] → the migration map classified every SwiftUI usage in `App/` as view-embedding except the deleted struct; the full local suite plus VM runs are the net.
- [Quake suite turns red post-fix] → pre-registered as NOT a fix failure (§15f: its real body runs on a shared VM session for the first time); excluded from the fix readout, handled in the successor truthing change if red.
- [Churn/split/new-tab hit the newly reachable confirm-close race on CI] → pre-registered; `harden-churn-shell-readiness` (already proposed) is the mitigation — advisory to land first.
- [Losing the inert `Settings` scene] → verified unused (no SettingsLink/openSettings/⌘, anywhere); trade-off accepted: a future Settings window would be a plain AppKit window or a revisit.

## Migration Plan

1. Land product migration + dump fields + test asserts in one commit series on `main` (small, bisectable: product fix commit, then harness commits).
2. Validate per D7 (×2 VM runs); record results in the research docs (a dated addendum, per capture conventions).
3. Push → observe CI `build-and-test` (the 7 expected flips); `add-ci-pipeline`'s archive remains its own change.
4. Rollback: revert the commit series — the migration is one construct plus additive dump fields; no data, config, or persisted state involved.

## Open Questions

- Does the guest OS match ⌘⌥arrow key equivalents post-fix? (§15f probe — settled by the validation runs' directional-focus result.)
- Does the quake suite pass its first real exercise on a shared VM session? (Settled by the same runs; red routes to the truthing change, not here.)
