## Why

`add-zsh-test-image` measured — on real rigs — that ~half the XCUITest suite is shell-dependent, and today that half is **dishonest**: the 19-method semantic-capture family early-returns before asserting (vacuous passes that read as coverage) and `testMultiLinePasteIsNotAutoExecuted` hard-fails on bash 3.2's missing bracketed paste. The suite conflates "the shell can't do this" with "pass" or "fail."

The original framing of this change fixed that by **skipping** shell-dependent tests on the wrong shell and **partitioning** the suite into two test plans. On reflection (explore, 2026-07-08) a **skip is a coverage hole** — it asserts nothing, so a regression on that shell goes unseen — whereas the shell behaviors are *known and measured*, so we can do better: **assert the correct behavior for each shell**. The multi-line paste is the exemplar — the exact same paste, forwarded faithfully by xtty, produces a shell-determined result, and both results are correct xtty behavior:

| Observed | zsh (bracketed paste on) | bash 3.2 (no bracketed paste) |
| --- | --- | --- |
| Multi-line paste | both lines **staged**, nothing executed | first newline-terminated line **executed**, tail line **staged** |
| `"command not found"` in grid | **absent** | **present** (the first line ran) |

So this change **pivots**: from *skip-and-partition* to *parameterize-and-assert*. Each shell-dependent test asserts the behavior expected for the terminal's **observed** capability; a skip is a last resort only where the capability-absent case admits no meaningful assertion. This kills the vacuous passes **and** the paste red (the original goals) while giving **real coverage on both shells** — and, because there is nothing left to skip-around, it lets us **drop the two-test-plan partition entirely** (less machinery, no XcodeGen scheme-wiring risk). See `research/03-analysis/shell-dependent-test-partitioning.md`.

> **Name note:** the change keeps the id `split-shell-dependent-testplan` for continuity (it is referenced by AGENTS.md, `packer/README.md`, the research docs, and the in-flight `harden-paste-wrap-assertion`, and by three archived changes). The *strategy* pivoted away from splitting into test plans; the id is historical — see design D1.

## What Changes

- **Parameterize the shell-dependent tests by the terminal's observed capability** (test-only). The paste test asserts per-shell: zsh/bracketed → both lines staged, `"command not found"` absent (the current guarantee, kept wrap-tolerant per `harden-paste-wrap-assertion`); bash-3.2/no-bracketed → first line executed (`"command not found"` present), tail line staged. **Rename** `testMultiLinePasteIsNotAutoExecuted` → a capability-neutral name (e.g. `testMultiLinePasteMatchesShellBracketing`) — "IsNotAutoExecuted" is only the zsh arm.
- **Semantic-capture family:** assert the active-capture behavior when capture is live (the zsh arm); where the capability-absent case has a crisp, valuable negative (e.g. no OSC 133 command boundaries / an empty semantic sidebar), assert **that**; otherwise convert the silent early-`return` to an honest `throw XCTSkip(…)`. No more vacuous passes.
- **Expose `bracketedPasteMode`** in the DEBUG state dump so the paste test reads the true capability predicate rather than sniffing the shell binary/version. New observable → a `verification-harness` spec delta + harness task.
- **Drop the two-`.xctestplan` partition.** With per-shell assertions there is nothing to skip-around, so the full suite runs on **every** rig — the bash rig taking the bash arm (assert, or honest-skip as a last resort), the zsh rig the zsh arm. Removes the `project.yml` scheme `testPlans:` wiring and its XcodeGen-fidelity risk. Honest skips (last resort) surface on the non-blocking `build-and-test` job; the required gate is `test-core`, unaffected.
- **Make the zsh rig a standing validation environment:** the `xtty-test-validator` runs the full suite on the zsh golden for the capability-present arm (with the definition-delivery-lag caveat — verify by report stamp).
- **Reverse duty (same change):** `packer/README.md` Acceptance/matrix + `research/03-analysis/github-actions-ci-cd.md` §19b — bash rig paste **red → asserted bash behavior** (execution arm), not a skip; the semantic family → asserted-or-honest-skip.

**Non-goals:** no product/app behavior change (SwiftTerm's paste bracketing + xtty's OSC injection are already correct); no terminal-level multi-line-paste guard (a future layer-3 feature — see design D2/Open-Questions); no new shell beyond bash/zsh; no GitHub-Actions zsh job (future).

## Capabilities

### New Capabilities

<!-- none — no new spec is introduced -->

### Modified Capabilities

- `verification-harness`: **ADD** two requirements — (1) the focused pane's **bracketed-paste mode** is observable in the DEBUG state dump; (2) **shell-parameterized capability assertion** — a shell-dependent test asserts the correct behavior for the terminal's *observed* capability (e.g. multi-line paste staged when bracketed paste is on; forwarded line-by-line when it is not), asserts a crisp negative where the capability-absent case admits one, and records a skip only as a last resort — never a vacuous pass.
- `test-validation`: **MODIFY** the committed-agent tooling requirement so the enumerated environments include the **zsh real-coverage VM rig**, on which shell-dependent tests take their capability-present assertion arm while the bash rig takes the capability-absent arm (assert-or-skip) — the full suite runs on every rig.

## Impact

- **Test target:** `AppUITests/` edits — the paste test parameterized + renamed (building on `harden-paste-wrap-assertion`'s wrap-tolerant `:82`/`:84`); the semantic-capture family's silent returns → assert-active / crisp-negative / `XCTSkip` (`XttySemanticCaptureUITests`, `XttySessionSidebarUITests`, `XttyBlockSidebarUITests`, `XttyGitReviewUITests`, `XttySpatialBlocksUITests`, `XttyFileLinkOpenUITests`); the i18n-paste half of `testTruecolorEmojiAndWideChars` parameterizes like the paste test. **No `project.yml` / `.xctestplan` changes.**
- **App (DEBUG-only harness):** `App/UITestDump.swift` (+ `writeStateDump` callers) gains a `bracketedPasteMode` field read from `terminal.bracketedPasteMode` (SwiftTerm `public private(set)`). No shipping-path behavior; `#if DEBUG` + `-UITestGridDump`-gated.
- **Committed tooling:** `.claude/agents/xtty-test-validator.md` learns the zsh golden is a standing environment (definition-delivery-lag caveat — verify by report stamp).
- **Docs/trackers:** `packer/README.md`, §19b, and — on completion — AGENTS.md Current-status + `research/04-design/02-milestones.md` + flipping the research doc's status to "built + parameterized."
- **Dependency/ordering:** builds on `harden-paste-wrap-assertion` (the wrap-tolerant zsh paste arm) and `add-zsh-test-image` (archived — the measured divergence grounds the predicates + per-test assert/skip decisions). Apply after both; archive after `harden-paste-wrap-assertion`.
