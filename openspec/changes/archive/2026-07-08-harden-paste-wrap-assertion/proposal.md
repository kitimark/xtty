## Why

`testMultiLinePasteIsNotAutoExecuted` fails **deterministically** on the wide-prompt **zsh** VM rig (`xtty-test-zsh:26.5`) while passing locally. Forensic (graphics zsh diagnostic, 2026-07-08 — `local-network-privacy-forensics.md` neighbourhood + the run's `paste-grid.txt`): the `add-vm-prompt-width-parity` 59-char hostname makes the zsh prompt exactly **70 columns**; the pasted first line `alpha<tag>` is **9 chars**, so `70 + 9 = 79 > 78`-column terminal and the 9th glyph **soft-wraps** to the next physical row. `App/UITestDump.swift` joins physical rows with `\n`, so the dump holds `alpha216`⏎`8`, and the `:82` assertion uses the **strict** `waitForContains` while its siblings at `:53` (focus-typing) and `:198` (find-bar) already use the wrap-tolerant matcher. The paste **does** land and is correctly **staged, not executed** (the `:87` negative check is clean) — the marker is present, just wrapped. This is the **exact same class** as `harden-findbar-wrap-assertion`: a prompt-width-fragile assertion, not a product bug. It is misfiled in `packer/README.md` as the "zsh grid-capture arm" whose cause is a "staged/highlighted region" scrape miss — the real cause is prompt-width soft-wrap.

This is **not** the bash paste red. On the bash rig, `testMultiLinePasteIsNotAutoExecuted` reds at `:87` because bash 3.2 has no bracketed paste, so the paste auto-executes — a genuine shell-capability difference owned by `split-shell-dependent-testplan`, which parameterizes the paste test to **assert** that bash execution arm (not skip it). The two arms are independent (see design D4).

## What Changes

- Apply the existing wrap-tolerant matcher (`ignoringLineWraps: true`) to the two **positive** grid-content assertions in `testMultiLinePasteIsNotAutoExecuted` (`AppUITests/XttyUITests.swift:82` and `:84`), mirroring `:53` / `:198`. **Test-only; no product behavior changes.** The tokens are single random words (`alpha<tag>`/`beta<tag>`) that cannot legitimately contain a newline, so wrap-tolerance is safe (the matcher's documented precondition).
- **No new regression guard** — the deterministic forced-wrap guard `testSoftWrapGuardIsWrapTolerant` shipped by `harden-findbar-wrap-assertion` already proves, in the fast `make test` tier and independent of prompt width, that the wrap-tolerant matcher is required and works. This change reuses both the matcher and its guard; it adds neither.
- Leave the `:87` negative "command not found" check **strict** — out of scope (it is not the failure path: on zsh the paste is staged and never executes, and the error phrase begins at column 0 where it does not wrap). See design D3.
- **Reverse-duty tracker updates in the same session:** correct and retire the `packer/README.md` "zsh grid-capture arm" matrix row (cause = prompt-width soft-wrap, find-bar wrap class; residual → fixed) and flip the zsh-rig envelope `40/1/1` → `41/0/1`; update the `github-actions-ci-cd.md` §19b zsh cross-check note; correct `shell-dependent-test-partitioning.md` (the zsh `:82` red is a matcher fix here, not a split-plan skip); add a one-line pointer in `split-shell-dependent-testplan`'s design so the change-set stays coherent.

Out of scope (deferred): the `bash32-no-bracketed-paste` paste residual at `:87` — a different (shell-capability) fix owned by `split-shell-dependent-testplan`; the bash-rig envelope is unchanged by this change.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `verification-harness`: extend the **Soft-wrap-robust content assertion** requirement so the multi-line-paste content coverage (not only focus-typing-on-activate and find-bar focus-restore) uses the wrap-robust assertion, with a scenario for a soft-wrapped pasted line. Reuses the existing deterministic forced-wrap guard requirement unchanged.

## Impact

- **Tests:** `AppUITests/XttyUITests.swift` (the `:82` and `:84` assertions in `testMultiLinePasteIsNotAutoExecuted` + a comment); reuses `GridDumpReader.waitForContains(_:timeout:ignoringLineWraps:)` (`XttyUITestSupport.swift:153`) and the existing `testSoftWrapGuardIsWrapTolerant` — no new launch hook, no app code, no new guard test.
- **Product code:** none.
- **Trackers (reverse duty, same session):** `packer/README.md` Acceptance/matrix, `research/03-analysis/github-actions-ci-cd.md` §19b, `research/03-analysis/shell-dependent-test-partitioning.md`, `openspec/changes/split-shell-dependent-testplan/design.md` (one-line interaction pointer); AGENTS.md Current-status + HISTORY.md on completion.
- **Rig effect:** the **zsh** VM rig paste red at `:82` flips green (`40/1/1` → `41/0/1`); the **bash** VM rig and hosted-CI paste red at `:87` are **unchanged** (owned by `split-shell-dependent-testplan`); local `41/0/1` unchanged; `test-core` unaffected.
