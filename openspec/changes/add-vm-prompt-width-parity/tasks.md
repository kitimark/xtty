> **Sequencing:** apply this change **before** `harden-findbar-wrap-assertion`, as a red→green pair — applied alone it reproduces the find-bar red in-guest (proof of parity); `harden-findbar-wrap-assertion` then flips it green on the same image, no rebuild (D5). The final documented envelope (find-bar green) is set after #1.

## 1. Long-hostname provisioner

- [x] 1.1 Add a Packer provisioner to `packer/xtty-test.pkr.hcl` (alongside the existing `chsh` provisioner) that sets a **~60-char single-label hostname** on all three keys — `sudo scutil --set HostName …`, `--set LocalHostName …`, `--set ComputerName …` — mirroring `runner-images`' `configure-hostname.sh`. Choose a name ≥ ~58 chars (single DNS label ≤ 63).
- [x] 1.2 Comment the provisioner: why (reproduce the runner's prompt width so prompt-width flakes surface in-guest), the mechanism parity with `runner-images`, and the safety note (keeps bash; the Local Network reverse-DNS path is OSC-7/zsh-gated and dead under bash, so hostname length can't resurrect the modal) — pointing to `ci-runner-prompt-width-forensics.md`.

## 2. Rebuild the image (human-gated)

- [x] 2.1 Rebuild the test image with `make image` (owner step — prereqs: Packer + the one-time Apple-ID Xcode `.xip`), producing the updated `xtty-test` image carrying the wide prompt.

## 3. Verify by effect + re-establish the envelope (VM, delegated)

- [x] 3.1 On both VM rigs (headless + graphics), (a) **verify by effect** that bash `\h` renders the long name and a marker typed at the prompt soft-wraps across ≥2 physical rows in the grid dump (the D2 precondition — if it does not wrap, adjust the hostname/effective key before trusting counts); (b) re-run the full UI suite and record the interim envelope — confirming `testFindBarOpensLocatesAndDismisses` now **reds in-guest under the wide prompt** (the repro proof; `harden-findbar-wrap-assertion` not yet applied — its green flip is that change's task), recording the `testMultiLinePasteIsNotAutoExecuted` residual's new failing line (`:84` wrap vs `:87`), and flagging any *newly-surfaced* prompt-width wrap in another test. ⟶ xtty-test-validator (headless + graphics VM, full acceptance matrix + prompt-width verify-by-effect)
      - **Validator result (Definition v4, 2026-07-07 full sweep — verbatim):** Tier 0 `232/0/0`, Tier 1 local `40/0/1`, headless run1 `38/2/1`, headless run2 `38/2/1`, graphics `38/2/1` — all VM rigs identical, failing set `testFindBarOpensLocatesAndDismisses` (`:192`) + `testMultiLinePasteIsNotAutoExecuted` (`:87`). **D2 verified by effect** on all 3 clones (`\h` = the 59-char name; marker split `…admin$ AFTERFIND`/`786`; forensics **T6 closed**). find-bar red = intended prompt-width-wrap repro (not a regression). **Paste stayed `:87`, NOT `:84`** — prediction refuted by measurement (recorded in trackers). No newly-surfaced wrap elsewhere. Verdict: OUT-OF-ENVELOPE only vs the pre-update README = the design-predicted interim; PROCEED. Evidence: `~/Downloads/xtty-vm-poc/artifacts/2026-07-06-vm-prompt-width-parity-rebaseline/`.

## 4. Reverse-duty tracker updates (same session)

- [x] 4.1 `packer/README.md` Acceptance + expected-difference matrix: update to reflect that the guest now reproduces the runner's prompt width and the paste residual's failing signature (`:84`) under the wide prompt; remove/adjust the earlier "why the CI find-bar residual isn't in this envelope" note (the gap is now closed). The **final** find-bar-green envelope is documented jointly once `harden-findbar-wrap-assertion` is applied — do **not** record the interim find-bar red as a standing residual.
      - Done: added an **interim-state block** (measured `38/2/1`, find-bar red explicitly transient/not-standing), replaced the "not in this envelope" note with **"gap now CLOSED in-guest"**, made the regression definition interim-aware, added a **Prompt-width wrap** matrix class, and extended the reverse-duty list. **Correction vs the task's `:84` premise:** measurement shows the paste line **stayed `:87`** (not `:84`) — documented as a measured correction rather than transcribed as predicted.
- [x] 4.2 `research/03-analysis/ci-runner-prompt-width-forensics.md` §6: add a dated line recording that Option C (long-`\h` VM parity) landed, with the change name and the measured envelope outcome.
      - Done: §6 landing addendum (2026-07-07, `38/2/1`, D2 verified, `:87` correction, evidence path); §4 **T6** flipped ❓→✅ resolved; §6 option-C row's refuted `:84` prediction struck through.

## 5. Close-out

- [x] 5.1 `openspec validate add-vm-prompt-width-parity` and confirm the `build-workflow` ADDED requirement reads mechanism-neutral (the *how* — scutil/hostname — stays in design/tasks, not the requirement).
- [ ] 5.2 On archive: update the AGENTS.md Current-status snapshot (VM envelope/fidelity note) and append the narrative to HISTORY.md (per Keep-progress-current). The Learned-refutations reproducibility bullet is unaffected.
