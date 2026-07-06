> **Sequencing:** apply this change **after** `harden-findbar-wrap-assertion` lands, so the re-baselined envelope carries find-bar green (D5).

## 1. Long-hostname provisioner

- [ ] 1.1 Add a Packer provisioner to `packer/xtty-test.pkr.hcl` (alongside the existing `chsh` provisioner) that sets a **~60-char single-label hostname** on all three keys — `sudo scutil --set HostName …`, `--set LocalHostName …`, `--set ComputerName …` — mirroring `runner-images`' `configure-hostname.sh`. Choose a name ≥ ~58 chars (single DNS label ≤ 63).
- [ ] 1.2 Comment the provisioner: why (reproduce the runner's prompt width so prompt-width flakes surface in-guest), the mechanism parity with `runner-images`, and the safety note (keeps bash; the Local Network reverse-DNS path is OSC-7/zsh-gated and dead under bash, so hostname length can't resurrect the modal) — pointing to `ci-runner-prompt-width-forensics.md`.

## 2. Rebuild the image (human-gated)

- [ ] 2.1 Rebuild the test image with `make image` (owner step — prereqs: Packer + the one-time Apple-ID Xcode `.xip`), producing the updated `xtty-test` image carrying the wide prompt.

## 3. Verify by effect + re-establish the envelope (VM, delegated)

- [ ] 3.1 On both VM rigs (headless + graphics), (a) **verify by effect** that bash `\h` renders the long name and a marker typed at the prompt soft-wraps across ≥2 physical rows in the grid dump (the D2 precondition — if it does not wrap, adjust the hostname/effective key before trusting counts); (b) re-run the full UI suite and re-establish the acceptance envelope — confirming `testFindBarOpensLocatesAndDismisses` stays green (with `harden-findbar-wrap-assertion` present), recording the `testMultiLinePasteIsNotAutoExecuted` residual's new failing line (`:84` wrap vs `:87`), and flagging any *newly-surfaced* prompt-width wrap in another test. ⟶ xtty-test-validator (headless + graphics VM, full acceptance matrix + prompt-width verify-by-effect)

## 4. Reverse-duty tracker updates (same session)

- [ ] 4.1 `packer/README.md` Acceptance + expected-difference matrix: update to the **re-measured** envelope — note the guest now reproduces the runner's prompt width, the paste residual's failing signature under the wide prompt, and remove/adjust the earlier "why the CI find-bar residual isn't in this envelope" note (the gap is now closed).
- [ ] 4.2 `research/03-analysis/ci-runner-prompt-width-forensics.md` §6: add a dated line recording that Option C (long-`\h` VM parity) landed, with the change name and the measured envelope outcome.

## 5. Close-out

- [ ] 5.1 `openspec validate add-vm-prompt-width-parity` and confirm the `build-workflow` ADDED requirement reads mechanism-neutral (the *how* — scutil/hostname — stays in design/tasks, not the requirement).
- [ ] 5.2 On archive: update the AGENTS.md Current-status snapshot (VM envelope/fidelity note) and append the narrative to HISTORY.md (per Keep-progress-current). The Learned-refutations reproducibility bullet is unaffected.
