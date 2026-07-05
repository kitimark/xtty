# Tasks — fix-main-menu-clobber

## 1. Product migration (the fix)

- [ ] 1.1 Delete the `@main struct XttyApp: App` construct and its now-unused `import SwiftUI` from `App/XttyApp.swift`; the `AppDelegate` in the same file is unchanged **except** the added `applicationSupportsSecureRestorableState → true` override (design D3)
- [ ] 1.2 Add `App/main.swift`: `let delegate = AppDelegate()` (top-level `let` = the strong retention, design D2), `NSApplication.shared.delegate = delegate`, `_ = NSApplicationMain(CommandLine.argc, CommandLine.argv)`
- [ ] 1.3 Refresh the stale "SwiftUI App lifecycle" comment in `project.yml` (no functional change — `NSPrincipalClass: NSApplication` already set); `xcodegen generate` && `make build` succeeds (settles the Swift-6 top-level-isolation question, design D2)

## 2. Harness observability (canary + witness fields)

- [ ] 2.1 State dump gains `mainMenuTitles` — the ordered top-level titles of `NSApp.mainMenu`, read as titles (never object identity), observe-only (design D5)
- [ ] 2.2 State dump gains `windowCount` — the number of live `TerminalWindowController`s: **native tabs included** (each tab is an `NSWindow` with its own controller; Cmd+T increments it), the **quake accessory panel excluded**; never `NSApp.windows.count` (design D6; note the next-runloop deferred-release transient on close — the witness asserts growth after open, which is unaffected)
- [ ] 2.3 Every suite that drives menu key equivalents — multiplexing (split + directional-focus + new-tab), find-bar, paste, truecolor, churn, block-menu — gains a shared fatal precondition asserting xtty's own menu titles are present (via the dump's `mainMenuTitles`) before driving Cmd chords, attaching diagnostics on failure — fail loudly with the named cause, never retry (the rule is "any suite sending Cmd chords", design D5). In suites not using `launchConfigured` (`XttyUITests`), reset the state-dump reader in setUp and wait for **this launch's** fresh dump before asserting the canary (the dump path is sticky across launches — a stale prior-instance dump must not mask a clobbered launch)
- [ ] 2.4 The new-tab/window test asserts `windowCount` reflects a real second window after Cmd+N/Cmd+T (both increment under the D6 semantics; converts today's vacuous pass into the red→green witness)

## 3. Local verification (necessary, not sufficient)

- [ ] 3.1 `make test-core` — all `XttyCore` unit tests stay green (the migration touches no core code; this is the regression net)
- [ ] 3.2 `make test` locally — full XCUITest suite green including the new canary preconditions and the `windowCount` assert (bare-metal green does NOT validate the fix — design D7 — but a bare-metal red is a real regression)

## 4. VM validation (the pre-registered acceptance, design D7)

- [ ] 4.1 Host `xcodebuild build-for-testing`; deploy to a **fresh clone** of the bash-shell `xtty-test:26.5` golden image constrained per `packer/README.md`'s **Runtime workflow** (`tart set --cpu 3 --memory 7168`), run **headless** (display mode is outcome-changing — the README measured graphics-mode focus-stealing as an extra red); full suite via `test-without-building`, **no retry flag**. Do NOT substitute the zsh-era or big-Tart rigs — the expected envelope assumes the bash image (design D7)
- [ ] 4.2 Run the full suite **twice** (per-launch race — one green run is not acceptance); expected: **every test passes except the one opt-in bench skip** — 41/0/1 against today's 42-test suite, or **40/0/1 of 41 if `retire-metal-renderer`'s deletion of the Metal e2e landed first** — with `mainMenuTitles` showing xtty's menus throughout both runs; map any residual red to the §15f second-order matrix (quake newly exercised; confirm-close newly reachable; ⌘⌥arrow on the guest OS is a probe) and record verbatim counts + the failing set; anything outside the matrix = stop and investigate before proceeding
- [ ] 4.3 Optional re-verify-by-effect spot-check (forensics §7): on the fixed build, `NSApp.delegate` is xtty's `AppDelegate` (not `SwiftUI.AppDelegate`) and the P6 synthetic trigger leaves the menu intact

## 5. Docs, trackers, and cross-change protection

- [ ] 5.1 **Symmetric merge protection (apply-time, design D8):** reword `retire-metal-renderer` tasks.md's two-way *Deterministic content assertion channel* reconciliation task to the **three-way** rule (naming this change's added sentence + the two new scenarios), and insert the missing matching archive-time reconciliation task into `harden-churn-shell-readiness/tasks.md` — so no archive ordering of the three changes silently reverts merged spec text (precedent: `retire-metal-renderer` task 5.2 edits `add-ci-pipeline`'s pending delta)
- [ ] 5.2 `openspec validate "fix-main-menu-clobber"` passes; record the VM validation results as a dated addendum in `research/03-analysis/github-actions-ci-cd.md` (§18) with a pointer from the forensics doc's §7
- [ ] 5.3 Push and record the first post-fix CI `build-and-test` run number + counts (the 7 expected flips; CI observation only — `ci.yml` stays owned by `add-ci-pipeline`)
- [ ] 5.4 Update `packer/README.md`'s **Acceptance (pre-registered)** section to the measured post-fix envelope (its current envelope is explicitly conditioned on "until fix-main-menu-clobber lands" — left stale, a future image rebuild would accept a menu-broken image); update AGENTS **Current status** + `research/04-design/02-milestones.md`; verify trackers against disk (`openspec list`, archive dir, specs dir)
- [ ] 5.5 **Archive-time reconciliation (pre-registered, design D8):** before `openspec archive`, diff this change's *Deterministic content assertion channel* delta against the then-current established block — if `retire-metal-renderer` or `harden-churn-shell-readiness` archived first, re-paste their merged sentences into this delta so the archive does not revert them
