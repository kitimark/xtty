## 1. Parameterize the template by login shell

- [ ] 1.1 Add a Packer `shell` variable (default `bash`) to `packer/xtty-test.pkr.hcl`; drive the `chsh` provisioner and the output image tag off it (`bash` → `xtty-test:26.5`, `zsh` → `xtty-test-zsh:26.5`), keeping the `shell=bash` build byte-identical to today's image.
- [ ] 1.2 Wire a `make image` selector for the shell parameter (e.g. `make image SHELL=zsh` or a `make image-zsh` alias) so both variants build from one entry point; leave the default (`make image`) producing the bash image unchanged.
- [ ] 1.3 (verify, inline) `packer validate` the template for both `shell=bash` and `shell=zsh`; confirm the default path is unchanged.

## 2. zsh guest: shell + Local Network gate neutralization

- [ ] 2.1 Add a zsh-only provisioner block gated on `shell=zsh`: `chsh -s /bin/zsh` for the auto-login account (and root, matching the bash block's pattern).
- [ ] 2.2 Install a per-boot `LaunchDaemon` (`RunAtLoad`, root) that regenerates `/etc/hosts` from every local interface address (`ifconfig` inet + inet6, incl. link-local/ULA) as `<addr> <name>` lines, so `getnameinfo` answers the reverse-PTR from the files module before mDNS (design D2 / fix-class (b)). Seed the exact address set empirically (Q2).
- [ ] 2.3 (verify, inline) On a booted zsh clone, confirm the daemon ran (the `/etc/hosts` entries exist for the live addresses) and the auto-login shell is `/bin/zsh`.

## 3. Build the zsh image

- [ ] 3.1 Build `xtty-test-zsh:26.5` via the parameterized template (human-gated prereqs unchanged: Packer + the pre-downloaded Xcode `.xip`); confirm it is Metal-toolchain-free (`xcodebuild -showComponent MetalToolchain` → `uninstalled`) and xtty builds in-guest.

## 4. Verify by effect: the Local Network gate is neutralized under zsh

- [ ] 4.1 (verify — VM graphics tier) Run a graphics UI session on a zsh clone while capturing `log stream` for the LN gate; confirm **zero** "Local network access … policy 'pending'" events and **no** modal appears (design D2 / Risk-1). ⟶ xtty-test-validator (graphics VM, zsh golden — LN-gate verify-by-effect)

## 5. Measure the divergence (the change's acceptance)

- [ ] 5.1 (verify — full acceptance matrix, both rigs) Run the existing, unmodified suite on the **bash** rig (headless ×2 + graphics) and the **zsh** rig (headless ×2 + graphics); capture per-rig counts + failing sets + the `.xcresult` bundles. ⟶ xtty-test-validator (full matrix, both goldens — bash `xtty-test:26.5` + zsh `xtty-test-zsh:26.5`)
- [ ] 5.2 (verify) Confirm the divergence *by effect* (design D3): bash rig = documented `40/1/1` (paste red, family carries `"…capture inactive…"` attachments); zsh rig = paste test green (grid stages both lines, no `command not found`) **and** the semantic family asserting (no `"…capture inactive…"` attachments). A zsh green that still shows capture-inactive attachments FAILS acceptance.
- [ ] 5.3 (verify) Record whatever count the zsh rig lands as its measured envelope; note any new zsh-specific behavior (prompt width, integration load on a fresh guest) and headless-vs-graphics parity (Q3).

## 6. Reverse duty: reconcile the runtime docs (same change)

- [ ] 6.1 Update `packer/README.md`: document the zsh-variant build + the LN-neutralization daemon (with the empirically-settled address recipe from 2.2 and the verify-by-effect from 4.1); add the zsh rig's measured Acceptance envelope alongside the bash envelope; add/repoint the Expected-difference matrix "Shell arm" row to describe bash-vacuous vs zsh-real-coverage.
- [ ] 6.2 Update `research/03-analysis/github-actions-ci-cd.md` §19b to note the `bash32-no-bracketed-paste` residual is bash-rig-specific and green on the zsh rig (the paste guarantee is confirmed, not skipped, here).
- [ ] 6.3 (verify, inline) `openspec validate add-zsh-test-image` passes; the proposal↔specs capability contract holds (build-workflow only).

## 7. On completion (post-verify)

- [ ] 7.1 Reconcile trackers per AGENTS.md "Keep progress current": AGENTS.md Current-status table row + snapshot (a zsh rig now exists; both envelopes), append the narrative to `HISTORY.md`, advance `research/04-design/02-milestones.md` if applicable, and update `research/03-analysis/shell-dependent-test-partitioning.md` from "decided/unbuilt" to "built + measured".
- [ ] 7.2 (verify — coherence, pre-archive) Review the change for coherence against AGENTS.md's rulebook + disk state. ⟶ xtty-openspec-critic (add-zsh-test-image)
