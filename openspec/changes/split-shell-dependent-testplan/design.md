## Context

The second half of the two-change plan (`research/03-analysis/shell-dependent-test-partitioning.md`). `add-zsh-test-image` builds the zsh rig and measures the divergence; this change restructures the suite so the divergence is handled honestly. Today the shell-dependent half is dishonest on the bash rig: the 19-method semantic-capture family early-returns before asserting (a `guard waitForSemanticCaptureActive() else { …; return }` degrade arm → vacuous pass), and `testMultiLinePasteIsNotAutoExecuted` (`AppUITests/XttyUITests.swift:62`) asserts unconditionally and hard-fails on bash 3.2's missing bracketed paste. SwiftTerm's paste path already brackets correctly when `terminal.bracketedPasteMode` is true (`MacTerminalView.swift:1180`); the flag is `public private(set)` and readable by the DEBUG dump. Nothing about the *product* is wrong — only the test suite conflates "the shell can't do this" with "pass" or "fail".

## Goals / Non-Goals

**Goals:**
- Two selectable sets: `Intersection` (shell-agnostic) and `ShellInteractive` (shell-dependent), union = the full suite.
- Every shell-dependent test records an honest **skip** (not a vacuous pass, not a red) when its *observed* capability is absent, and its **real assertion** when present.
- The paste test reads the true predicate (`bracketedPasteMode`) from the state dump, sampled after shell readiness.
- The zsh rig becomes a standing validator environment carrying the shell-dependent set's real coverage; a bash-rig skip is the expected, correct outcome.

**Non-Goals:**
- No product/app behavior change (paste bracketing + OSC injection already correct).
- No new shell beyond bash/zsh; no GitHub-Actions zsh job (future).
- No change to `make test`'s default (it still runs the whole suite); plan selection is an added parameter, not a new default.

## Decisions

### D1 — Two `.xctestplan`s wired via the XcodeGen scheme, full suite stays the default

Add `Intersection.xctestplan` + `ShellInteractive.xctestplan` and reference them under the scheme's `testPlans:` in `project.yml` (regenerated, not hand-edited into the `.xcodeproj`). `make test` defaults to the whole suite (both plans / the default plan); a rig or CI job selects one via `-testPlan`. **Why test plans over `-only-testing`/`-skip-testing` lists:** declarative, versioned, and reviewable in-repo — the partition lives with the code, not in a shell script. **Why keep the full-suite default:** avoids a `build-workflow` entry-point change and keeps local `make test` behavior identical. *Alternative rejected:* one plan + pure runtime `XCTSkip` — still needed per-test (below), but without plans a rig can't *select* the shell-agnostic set, and CI can't run just the set it can honor.

### D2 — Honest skip keyed on the *observed* capability, sampled after readiness — never shell identity

- **Semantic-capture family** (semantic capture, session/block sidebar, git-review, spatial-blocks, file-link-open): the silent `guard … else { return }` becomes `guard … else { throw XCTSkip("semantic capture not live under this shell") }`, keyed on the existing `waitForSemanticCaptureActive()`.
- **Paste test:** `XCTSkipUnless(<focused pane's bracketedPasteMode is true>, …)`, read from the state dump (D3), **after** the computed-marker shell-readiness gate (`harden-churn-shell-readiness`) so the predicate isn't sampled before the shell has enabled bracketed paste at its first prompt.

**Why observed capability, not shell binary/version:** the predicate must track what the terminal *actually* negotiated (a user could run bash 5.1, or a future shell); sniffing `$SHELL`/`--version` is brittle and re-introduces the exact fragility we're removing. *Alternative rejected:* skip keyed on an env var like `XTTY_EXPECT_ZSH` — that's the rig asserting a belief, not the test observing reality; a misconfigured rig would then vacuously skip a capable shell.

### D3 — Expose `bracketedPasteMode` as a new DEBUG state-dump field (harness delta)

Add the focused pane's `terminal.bracketedPasteMode` to the state-dump JSON (`App/UITestDump.swift` + the `writeStateDump` callers), `#if DEBUG` + `-UITestGridDump`-gated, observe-only. Per the AGENTS.md harness-coupling rule this is a new observable → it carries a `verification-harness` spec delta (the field + an e2e scenario) and a harness task. **Why a dump field rather than an XCUITest-side probe:** the custom-drawn view exposes nothing to accessibility; the state dump is the only deterministic channel, and the predicate must be read out-of-process.

### D4 — The zsh rig is where the shell-dependent set gets real coverage (the deferred half of change 1)

`add-zsh-test-image` deferred "make the validator routinely aware of the zsh rig" to here, because only with honest skips are the two rigs' results cleanly interpretable: bash rig → shell-dependent set **skips** (expected); zsh rig → shell-dependent set **asserts**. This change updates `test-validation` (the environment enumeration + a scenario) and the `xtty-test-validator` agent definition so a full sweep runs `ShellInteractive` on the zsh golden. **Definition-delivery caveat:** agent-definition edits reach spawns with unpredictable lag — bump the `Definition:` stamp and verify by report stamp, never assume delivery (measured on this same agent).

### D5 — Set membership is the OSC-injection / bracketed-paste boundary

`ShellInteractive` = semantic-capture family (19) + `testMultiLinePasteIsNotAutoExecuted` + the i18n-paste half of `testTruecolorEmojiAndWideChars` (it delivers emoji/CJK via Cmd+V). `Intersection` = everything else (multiplexing, quick-terminal, config, profile, lifecycle-census, find-bar, focus-on-activate, resize, GridDumpReader). The truecolor test is the one split-brain case: its ASCII-color half is shell-agnostic but its paste half is shell-dependent — assign it to `ShellInteractive` (the stricter set) and, if worthwhile at apply time, factor the shell-agnostic color assertion into an intersection test. Final membership is reconciled against change 1's measured divergence.

## Risks / Trade-offs

- **A skip is not a pass — the bash rig's green count drops** as ~20 tests move to skipped. → That is the point (honest accounting); `packer/README.md` + §19b are updated so the validator classifies the skips as expected, and the zsh rig supplies the real green.
- **`bracketedPasteMode` sampled too early false-skips a capable shell.** → D2 mandates sampling after the shell-readiness gate; the harness e2e scenario asserts the field is populated post-prompt.
- **Test-plan wiring via XcodeGen may need a `project.yml` schema feature.** → Verify XcodeGen's `testPlans:` support at apply; fallback is a committed `.xctestplan` referenced by the generated scheme, or `-only-testing` lists as a stopgap (documented, not preferred).
- **Validator agent-definition churn** (D4) collides with nothing in change 1 by design (change 1 deliberately did *not* touch the agent) — one delivery here, verified by stamp.

## Migration Plan

Additive and reversible. The plans + skips can land while `make test` still runs everything; a rig opts into a plan when ready. If test-plan wiring proves troublesome, the honest-skip conversion (D2/D3) still stands alone and delivers the core value (no more vacuous passes / no more paste red), with plan selection deferred. Rollback is deleting the plan files + reverting the `XCTSkip` edits — no product surface touched.

## Open Questions

- **Q1 — XcodeGen `testPlans:` fidelity** — does it emit a scheme that selects plans cleanly on `macos-26` `xcodebuild`, or is a committed `.xctestplan` + manual scheme reference needed? Resolve at apply (Risk above).
- **Q2 — Truecolor test split** — factor the ASCII-color assertion into `Intersection`, or keep the whole test in `ShellInteractive`? Decide from change 1's measurement of whether its color half passes under bash.
- **Q3 — Apply ordering** — this change's apply should follow `add-zsh-test-image`'s measured divergence (so predicates/envelopes are grounded); confirm change 1 is applied+measured before applying this. Archive after change 1.
