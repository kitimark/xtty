# Proposal: harden-churn-shell-readiness

## Why

The lifecycle-census churn test (`testLifecycleChurnReturnsCensusToBaseline`) is flaky on real dev machines — measured locally at fail/fail/pass across three consecutive runs — because it closes a freshly-created pane/tab within ~0.2–0.6 s of registration, while the new shell is still sourcing the user's startup files. A startup child owns the PTY foreground at close time, so the (default-on) confirm-close alert blocks the close and the census never returns to baseline: the leak-regression net reports a leak that doesn't exist. Worse, the alert's modal run loop freezes the DEBUG state/grid dumps (`.default`-mode timer), so the failure surfaces one step removed with misleading artifacts. Root cause, prior art, an empirical foreground-pgid probe, and the decided fix are captured in `research/03-analysis/confirm-close-shell-readiness.md` (design §5, artifact-confirmed §7).

## What Changes

- **Shell-readiness gate in the churn test (test-only):** in **both** churn loops, after the pane/tab registers, the test proves the fresh shell has *executed a command* (a computed-marker roundtrip through the grid dump) before sending ⌘W — so the close exercises the user-default confirm-close path without racing shell startup. `confirm-close` stays at its default; the close stays the real keybinding.
- **Asserted churn steps (test-only):** every churn step's wait becomes a hard assertion (`continueAfterFailure = false`); a step that doesn't materialize fails **at that iteration** with an attached grid dump, and the test never proceeds to a close whose precondition failed — eliminating the timeout-cascade/modal-wedge failure mode.
- **Dump liveness during modals (DEBUG harness, one line):** the state/grid dump timer is scheduled in `RunLoop` **`.common`** modes so dumps keep updating while a modal panel (e.g. the confirm-close `NSAlert`) is running — future alert-class failures produce truthful artifacts instead of frozen pre-alert JSON.
- **Explicitly out of scope** (staged separately per the research): the `hasForegroundJob` state-dump field (pre-planned escalation only if a residual flake is observed), the `fix-main-menu-clobber` CI work (the churn test's *CI* failure mode), and the protocol-ladder product candidates (at-prompt confirm-close gate, bash shell integration, zero-input latch).

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `verification-harness`: the **Lifecycle-census end-to-end coverage** requirement gains the deterministic-churn behavior — churn closes only demonstrably shell-ready panes/tabs (under the default close-confirmation setting), and a churn step that cannot proceed fails at that step rather than cascading. The **Deterministic content assertion channel** requirement gains dump liveness while a modal panel is presented.

## Impact

- **Code:** `AppUITests/XttyLifecycleCensusUITests.swift` (the churn loops); `App/XttyApp.swift` (~1 line, `#if DEBUG` dump-timer scheduling). No product behavior change; no new dependencies; no SwiftTerm patch.
- **Tests:** the churn test becomes deterministic on slow-`~/.zshrc` machines (local baseline: F/F/P → expected 5/5 green). On **CI** the churn test stays red until the separate menu-clobber fix lands (its CI failure mode is different — pre-registered, not a regression of this change).
- **Specs:** one `verification-harness` delta (two MODIFIED requirements). `lifecycle-census` (the product-level census requirements) is unchanged.
