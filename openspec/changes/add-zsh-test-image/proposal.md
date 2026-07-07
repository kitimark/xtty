## Why

The VM/CI test rig runs Apple's bash 3.2.57 on purpose (hosted-runner parity + it dodges the zsh-only Local Network privacy modal), but that shell can't exercise ~half the suite: xtty injects OSC 133/7 shell integration into **zsh only**, and bracketed paste needs a readline bash 3.2 lacks. The result today is a **false-confidence trap** — on the bash rig the 19-method semantic-capture family early-returns before asserting (vacuous passes), and `testMultiLinePasteIsNotAutoExecuted` is the lone shell-dependent test honest enough to hard-fail. Before restructuring the suite, we want to **prove the shell-dependence empirically on real rigs**: build a second image whose guest login shell is zsh (matching real users and local dev), run the *existing, unmodified* suite on both, and observe the divergence. This is the measurement-first first half of a two-change plan (`add-zsh-test-image` → `split-shell-dependent-testplan`); see `research/03-analysis/shell-dependent-test-partitioning.md`.

## What Changes

- **Parameterize the Packer test-image template by login shell** (`shell = bash | zsh`) so one source produces two tags: `xtty-test:26.5` (bash, byte-identical to today) and a new `xtty-test-zsh:26.5`. The zsh variant is a **supplement, not a replacement** — the bash rig remains the CI-parity, acceptance-bearing rig.
- **The zsh variant neutralizes the macOS Local Network privacy gate at the rig level** (no product-code change): a per-boot mechanism that satisfies the reverse-DNS lookups xtty's zsh-only OSC 7 path triggers, so a graphics UI run does not surface the "find devices on local networks?" modal. This is the one genuinely new piece of machinery and the change's front-loaded risk.
- **Run the existing suite on both rigs and record the divergence as the acceptance criterion** (not an all-green): bash → paste red + family vacuous-passing; zsh → paste green + the shell-dependent family **asserting for real** (proven by effect — no "capture inactive" attachments, the paste grid stages both lines). This establishes the zsh rig's acceptance envelope by measurement.
- **Reverse duty (same change):** update `packer/README.md` (Acceptance envelope + Expected-difference matrix + the zsh-image build/runtime docs + the LN-gate verification recipe) and `research/03-analysis/github-actions-ci-cd.md` §19b to record both rigs' envelopes and the reframed shell-arm difference.
- **Non-goals:** no test-code changes (the two `.xctestplan`s + honest `XCTSkip` + the `bracketedPasteMode` state-dump field are the follow-up `split-shell-dependent-testplan`); no product fix to the zsh OSC 7 reverse-DNS trigger (an owner-dropped option, kept only as a documented fallback); no GitHub-Actions zsh job yet (the eventual target, out of scope here).

## Capabilities

### New Capabilities

<!-- none — no new spec is introduced -->

### Modified Capabilities

- `build-workflow`: **ADD** a requirement that the test-image build supports a zsh-login-shell variant (alongside the existing bash variant, from the same pinned inputs) whose guest neutralizes the Local Network privacy gate at the rig level, so a graphics UI run under zsh does not surface the modal, and on which xtty's zsh-only OSC 133/7 integration goes live (the shell-dependent tests exercise their real asserting arm).

<!-- test-validation is intentionally NOT modified here: the validator's existing "runtime deference" requirement already makes it read the updated envelope/matrix from packer/README.md, and the one-time divergence run is delegated by naming the zsh golden clone. Making the zsh rig a *standing* validator environment + the honest-skip interpretation belongs with the follow-up `split-shell-dependent-testplan`, where the split makes the results cleanly interpretable and avoids double agent-definition-delivery churn. -->
- *(none besides `build-workflow`)*

## Impact

- **Build infra:** `packer/xtty-test.pkr.hcl` (new `shell` variable + a zsh-only provisioner block: `chsh -s /bin/zsh` + the per-boot LN-neutralization LaunchDaemon), the `make image` entry point (variant selection), and `packer/README.md` (build + runtime + acceptance + matrix).
- **Docs/trackers:** `packer/README.md`, `research/03-analysis/github-actions-ci-cd.md` §19b, and — on completion — the AGENTS.md Current-status table + `research/04-design/02-milestones.md`.
- **No product/app code, no `XttyCore`, no test code.** SwiftTerm's paste bracketing and xtty's OSC injection are already correct; this change only adds an environment that can exercise them.
- **Prerequisites unchanged and human-gated** (Packer + a one-time Apple-ID Xcode `.xip`); building a second ~40 GB image is mitigated by the parameterized single-source template and APFS CoW clones.
- **Dependency:** none blocking — this change stands alone (the in-guest suite runs via `xcodebuild test-without-building`, no test-plan required). The follow-up `split-shell-dependent-testplan` depends on this change's observed divergence and rig.
