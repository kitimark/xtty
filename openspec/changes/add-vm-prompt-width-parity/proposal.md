## Why

The local Tart test image mirrors the hosted runner on the per-launch race class and the bash login shell, but **not on prompt width**: the guest's hostname is short (`Manageds-Virtual-Machine`, 24 chars) while the hosted runner's is a ~61-char datacenter name, so a marker typed at the prompt soft-wraps on the runner but not in-guest ([`ci-runner-prompt-width-forensics.md`](../../../research/03-analysis/ci-runner-prompt-width-forensics.md)). That gap is why the `findbar-marker-wrap` flake was invisible to the VM and only surfaced on CI. Closing it makes the image an honest CI mirror for **any** prompt-width-sensitive test — so the *next* such flake is caught before push, not on a red CI run.

This is a harness-fidelity investment, not a bug fix (the find-bar assertion itself is fixed by `harden-findbar-wrap-assertion`). The two changes form a **red→green pair**, applied #2 → #1: applied **alone**, this change makes `testFindBarOpensLocatesAndDismisses` **red in-guest** — reproducing the CI flake locally and thereby *proving the parity works* — and then `harden-findbar-wrap-assertion` flips it green on the same image (no rebuild; the source is not baked in). The final documented envelope (find-bar green) is set after #1.

## What Changes

- Configure the test-image guest so its interactive login-shell prompt is **as wide as the hosted runner's** — a marker typed at the prompt soft-wraps across physical rows exactly as on the runner. Mechanism (design detail): a long guest hostname set in the Packer image, mirroring `actions/runner-images`' own boot-time hostname provisioning. Keeps the bash login shell and does not resurrect the Local Network privacy prompt.
- **Re-establish the acceptance envelope on the VM rigs** under the wide prompt (validator-delegated, headless + graphics). Expected: prompt-width-fragile assertions now behave in-guest as on the runner — applied **alone**, `testFindBarOpensLocatesAndDismisses` **reds** in-guest (the repro proof); after `harden-findbar-wrap-assertion` it greens; the multi-line-paste residual's failing signature shifts to the wrap (`:84`). The exact envelope is **measured, not predicted**, since a long prompt could surface a previously-hidden wrap in another type-at-prompt assertion.
- Reverse-duty tracker updates in the same session: refresh `packer/README.md` Acceptance + expected-difference matrix to the re-measured envelope, and record Option C landing in the forensics doc.

Out of scope: any application/product code (this is image + docs only); the `bash32-no-bracketed-paste` paste fix (separate); the find-bar assertion fix (its own change).

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `build-workflow`: add a requirement that the test image **reproduces the hosted-runner prompt width** (a typed marker soft-wraps in-guest as on the runner), so prompt-width-sensitive behavior surfaces in-guest before CI — without changing the guest login shell or resurfacing the Local Network prompt.

## Impact

- **Image config:** `packer/xtty-test.pkr.hcl` (a hostname provisioner); the image must be **rebuilt** (`make image`, human-gated: Packer + the one-time Apple-ID Xcode `.xip`).
- **Product code:** none.
- **Acceptance envelope:** re-measured on both VM rigs (validator-delegated) → `packer/README.md` updated to match.
- **Trackers (reverse duty, same session):** `packer/README.md` Acceptance/matrix, `research/03-analysis/ci-runner-prompt-width-forensics.md` §6; AGENTS.md snapshot + HISTORY.md on completion.
- **Sequencing:** applied **before** `harden-findbar-wrap-assertion` as a red→green pair (#2 reds find-bar in-guest, #1 greens it); the final documented envelope is set after #1.
- **CI effect:** none (this changes the local VM image, not `.github/workflows/`).
