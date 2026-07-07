## Why

`add-zsh-test-image` measures the divergence; this change acts on it. Once we've observed — on real rigs — that ~half the XCUITest suite is shell-dependent (the 19-method semantic-capture family + the paste test), the current suite is dishonest on the bash rig: the family early-returns before asserting (vacuous passes that read as coverage) and `testMultiLinePasteIsNotAutoExecuted` hard-fails on bash 3.2's missing bracketed paste. This change makes the partition **explicit and honest** — a shell-dependent test that can't run on the current shell records a **skip**, never a vacuous pass or a red — and routes real coverage of that half onto the zsh rig. See `research/03-analysis/shell-dependent-test-partitioning.md`.

## What Changes

- **Partition the suite into two Xcode test plans**, wired via the XcodeGen scheme `testPlans:` — `Intersection` (shell-agnostic, ~22 methods that must pass on every shell) and `ShellInteractive` (shell-dependent, ~20 methods). Their union is the full 42-method suite. `make test` keeps running the full suite by default (no build-contract change); a plan is selectable for per-rig runs.
- **Convert graceful degradation into honest skips** (test-only): the semantic-capture family's silent early-`return` becomes `throw XCTSkip(…)` keyed on `waitForSemanticCaptureActive()`; `testMultiLinePasteIsNotAutoExecuted`'s unconditional assertion becomes `XCTSkipUnless(…)` keyed on the terminal's **reported** bracketed-paste mode — sampled **after** the computed-marker shell-readiness gate (`harden-churn-shell-readiness`), never before the first prompt.
- **Expose `terminal.bracketedPasteMode` in the DEBUG state dump** so the paste test reads the true capability predicate rather than sniffing the shell binary/version. This is a **new observable** → a `verification-harness` spec delta + harness task.
- **Make the zsh rig a standing validation environment**: the `xtty-test-validator` runs `ShellInteractive` on the zsh rig for real coverage; a shell-dependent test **skipped** on the bash rig is the *correct* acceptance outcome (the zsh rig covers it), not a gap. Includes the validator agent-definition update.
- **Reverse duty (same change):** `packer/README.md` Acceptance/matrix + `research/03-analysis/github-actions-ci-cd.md` §19b — bash rig: paste **red → skip**; `ShellInteractive` on bash = skips, on zsh = real coverage.
- **Non-goals:** no product behavior change (SwiftTerm's paste bracketing + xtty's OSC injection are already correct); no new shell beyond bash/zsh; no GitHub-Actions zsh job (future).

## Capabilities

### New Capabilities

<!-- none — no new spec is introduced -->

### Modified Capabilities

- `verification-harness`: **ADD** two requirements — (1) the focused pane's **bracketed-paste mode** is observable in the DEBUG state dump; (2) **shell-capability-gated partitioning** — the suite is organized into a shell-agnostic and a shell-dependent set, and a shell-dependent test records a **skip** (never a vacuous pass) when its shell-capability predicate is unmet.
- `test-validation`: **MODIFY** the committed-agent tooling requirement so the enumerated validation environments include the **zsh real-coverage VM rig**, on which the shell-dependent plan runs its real asserting arm — making a shell-dependent test skipped on the bash rig an expected outcome covered elsewhere, not a coverage gap.

## Impact

- **Test target/scheme:** two `.xctestplan` files + `project.yml` scheme `testPlans:` wiring; `AppUITests/` edits converting silent returns → `XCTSkip`/`XCTSkipUnless` (the semantic-capture family + `XttyUITests.swift:62`).
- **App (DEBUG-only harness):** `App/UITestDump.swift` (+ `writeStateDump` in `TerminalWindowController`/`XttyApp`) gains a `bracketedPasteMode` field read from `terminal.bracketedPasteMode` (SwiftTerm `public private(set)`). No shipping-path behavior; `#if DEBUG` + `-UITestGridDump`-gated.
- **Committed tooling:** `.claude/agents/xtty-test-validator.md` learns to run `ShellInteractive` on the zsh golden (with the definition-delivery-lag caveat — verify by report stamp).
- **Docs/trackers:** `packer/README.md`, §19b, and — on completion — AGENTS.md Current-status + `research/04-design/02-milestones.md` + flipping the research doc's status to "built + split".
- **Dependency/ordering:** depends on `add-zsh-test-image` — this change's **apply** follows change 1's measured divergence, and it **archives after** change 1. Proposable now (the partition is known from static analysis); the exact skip-predicate wiring + the zsh envelope numbers are filled in at apply time from change 1's measurement.
