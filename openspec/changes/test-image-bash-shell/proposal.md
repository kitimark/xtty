## Why

The `xtty-test` VM image leaves the guest's default login shell as **zsh**, so xtty injects its OSC 7 shell-integration, the shell reports its cwd, and xtty reads the local machine's name via a call that performs a **reverse-DNS lookup of every local address**. On a stock macOS guest (no static `HostName`) those locally-scoped queries trip macOS **Local Network privacy**, raising an *"Allow '…' to find devices on local networks?"* modal that steals key-window focus and confounds the UI tests. The reference rigs we want to match — **GitHub-hosted macOS runners** and the frozen **tahoe-xcode** image — do not show this, and the reason is now measured: GitHub's runner-images `configure-shell.sh` runs `chsh -s /bin/bash`, so their login shell is **bash**, xtty injects no OSC 7 into bash, the reverse-DNS never runs, and the dialog never appears. Empirically confirmed on the 26.5 rig: bash → **0** reverse-DNS queries; setting a static hostname does **not** help (the reverse-DNS still fires 20×). To make the local test image reproduce the hosted-runner environment faithfully, the image's login shell must be bash.

## What Changes

- `packer/xtty-test.pkr.hcl`: add a provisioner that sets the guest login shell to **bash** (`sudo chsh -s /bin/bash admin`), matching GitHub's `runner-images/images/macos/scripts/build/configure-shell.sh`.
- Replace the template's outdated Local Network comment block (which blamed the "XCUITest runner↔app IPC over the routable vmnet address" and cited the refuted TN3179 pre-suppression) with the correct root cause (xtty's OSC 7 → reverse-DNS on zsh) and the bash rationale.
- Correct the stale `packer/README.md:44` note that claims the dialog "is now fixed in the template" — it is now *actually* addressed, by the bash shell.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `build-workflow`: add a requirement that the local test image's default login shell matches the GitHub-hosted macOS runner (bash), so the in-guest suite reproduces CI's shell environment and does not surface the Local Network prompt confound.

## Impact

- **Code / infra:** `packer/xtty-test.pkr.hcl` (one added provisioner + a corrected comment), `packer/README.md`. **No product code changes.**
- **Behavior:** a guest cloned from the rebuilt image spawns bash as the login shell; xtty emits no OSC 7 there, so the Local Network modal no longer appears during a graphics UI run — the image now reproduces the tahoe-xcode / GitHub-CI rig deterministically.
- **Accepted trade-off:** under bash, xtty's OSC 133 / OSC 7 semantic-capture UI tests fall back to their graceful-degradation arms — which is exactly what happens on GitHub CI (also bash), so this raises CI fidelity rather than lowering it. The `silence-bash-deprecation` product fix already keeps bash's deprecation banner out of the grids.
- **Open-change interaction:** `add-xtty-test-image` (16/20, image already built) owns `packer/xtty-test.pkr.hcl` and its own build-workflow requirement. This change adds a **sibling** requirement and edits the same template; it should be applied **after** `add-xtty-test-image`'s template exists (it does), and both ADDED requirements coexist without conflict.
