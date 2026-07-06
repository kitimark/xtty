## Why

`testFindBarOpensLocatesAndDismisses` fails on every hosted-CI run (`build-and-test`, non-blocking) while passing locally and on the Tart VM. Root cause (verified from `actions/runner-images` source — [`ci-runner-prompt-width-forensics.md`](../../../research/03-analysis/ci-runner-prompt-width-forensics.md)): the runner's ~61-char hostname makes the shell prompt soft-wrap the typed focus-restore marker across two physical grid rows, and the `:192` assertion uses the **strict** `waitForContains` while its sibling focus-typing check (`:53`) already uses the wrap-tolerant matcher. Focus **does** return — the marker reaches the grid, it just wraps — so this is a prompt-width-fragile assertion, not a product bug. It is the `findbar-marker-wrap` bucket in the CI expected-difference matrix (§19b).

## What Changes

- Apply the existing wrap-tolerant matcher (`ignoringLineWraps: true`) to the find-bar focus-restore assertion (`AppUITests/XttyUITests.swift:192`), mirroring the shipped `harden-focus-typing-assertion` at `:53`. **Test-only; no product behavior changes.**
- Add a **deterministic soft-wrap regression guard** — a test that types a marker guaranteed to wrap (self-validating: it asserts the marker genuinely spans ≥2 physical rows, that the wrap-tolerant match succeeds, and that a strict match does **not**). This reproduces the wrap class in the fast `make test` tier on bare metal, independent of the runner's hostname, so the class cannot silently respawn.
- Reverse-duty tracker updates in the same session: retire the `findbar-marker-wrap` bucket in `github-actions-ci-cd.md` §19b (residual → fixed), refresh the `packer/README.md` acceptance note, and record the fix in the forensics doc.

Out of scope (deferred): the `bash32-no-bracketed-paste` paste residual (a different, shell-capability fix) and the long-`\h` VM prompt-width parity (its own change, `add-vm-prompt-width-parity`).

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `verification-harness`: extend the **Soft-wrap-robust content assertion** requirement so the find-bar focus-restore coverage (not only focus-typing-on-activate) uses the wrap-robust assertion, and add a deterministic forced-wrap guard that proves the tolerant matcher is required and works while a genuinely absent token still fails.

## Impact

- **Tests:** `AppUITests/XttyUITests.swift` (the `:192` assertion + one new guard test); reuses the existing `GridDumpReader.waitForContains(_:timeout:ignoringLineWraps:)` (`XttyUITestSupport.swift:153`) — no new launch hook or app code.
- **Product code:** none.
- **Trackers (reverse duty, same session):** `research/03-analysis/github-actions-ci-cd.md` §19b, `packer/README.md` Acceptance, `research/03-analysis/ci-runner-prompt-width-forensics.md`, AGENTS.md Current-status + HISTORY.md on completion.
- **CI effect:** `build-and-test` find-bar red flips green on the hosted runner; `test-core` (required gate) unaffected.
