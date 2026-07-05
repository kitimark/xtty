## 1. Set the guest login shell to bash

- [ ] 1.1 In `packer/xtty-test.pkr.hcl`, add a shell provisioner running `sudo chsh -s /bin/bash admin` (mirroring GitHub runner-images `configure-shell.sh`; include `sudo chsh -s /bin/bash root` for closer parity)
- [ ] 1.2 Place it before the footprint-cleanup provisioner and after Xcode/xcodegen setup

## 2. Correct the stale/incorrect Local Network notes

- [ ] 2.1 Replace the template's Local Network comment block (the "XCUITest runner↔app IPC over the routable vmnet address" + refuted TN3179 text) with the measured cause — xtty's OSC 7 → `ProcessInfo.hostName` reverse-DNS on **zsh** — and the bash rationale
- [ ] 2.2 Fix `packer/README.md:44` ("that dialog is now fixed in the template") to state the real mechanism: bash login shell means no OSC 7, so no reverse-DNS, so no dialog

## 3. Build and verify

- [ ] 3.1 `make image` rebuilds the golden image with the shell change
- [ ] 3.2 In a fresh clone: `dscl . -read /Users/admin UserShell` reports `/bin/bash`
- [ ] 3.3 A graphics UI run in the clone shows **0** `client pid … (xtty)` reverse-DNS requests (`log stream` capture) and **no** Local Network modal, while still reproducing the menu-clobber 34/7/1 result (contrast the pre-change capture in `~/Downloads/xtty-vm-poc/artifacts/ln-diagnosis/`)

## 4. Docs / trackers

- [ ] 4.1 Note the shared-template interaction with `add-xtty-test-image` in both changes (apply after that change's template exists; both ADD distinct `build-workflow` requirements)
- [ ] 4.2 On completion, update AGENTS **Current status** and `research/03-analysis/local-macos-vm-ci-reproduction.md` §12 with the measured shell-is-the-factor finding (bash → 0 reverse-DNS; hostname ineffective; GitHub `configure-shell.sh` chsh bash)
