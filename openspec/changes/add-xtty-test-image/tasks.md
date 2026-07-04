# Tasks: add-xtty-test-image

Dependency gate: **`retire-metal-renderer` must be applied (zero-Metal xtty build) before task group 3+.** Tasks marked **[HUMAN-GATED]** need the owner (Apple ID / tool install / disk); everything else is agent-runnable.

Explicitly out of scope (not blurred into any task): ghcr `tart push` (deferred until a second consumer, design D10); any `ci.yml` change (the Metal-guard cleanup belongs to `retire-metal-renderer`); baking xtty source into the image (design D6); fixing the menu-clobber failures (independent, design D9).

## 1. Prerequisites (one-time, human-gated)

- [ ] 1.1 **[HUMAN-GATED]** Install Packer: `brew install packer` (design D1; Packer is not currently installed). No manual `packer init` here — the `github.com/cirruslabs/tart` plugin can only be pulled once the template's `required_plugins` block exists (task 2.1), and `make image` runs `packer init` + `packer build` itself (design D8)
- [ ] 1.2 **[HUMAN-GATED]** Download the official Xcode 26.5 installer archive with an Apple ID — `xcodes download 26.5` (or manual developer.apple.com) → `~/XcodesCache/Xcode_26.5.xip`; also archive a copy on `/Volumes/savepoint/images/` (design: Prerequisites 2 — the only Apple-authenticated step)
- [ ] 1.3 **[HUMAN-GATED]** Confirm ~45+ GB free disk for the build (base pull + `.xip` + unxipped Xcode) on top of the ~40 GB resulting image — **checked on the volume holding the Tart storage (`TART_HOME`)**, likely the external `savepoint` volume (the internal disk measured only 47–86 GiB free — design: Prerequisites 3)

## 2. Image-build template + docs (build)

- [ ] 2.1 Create `packer/xtty-test.pkr.hcl`: `vm_base_name` = pinned `ghcr.io/cirruslabs/macos-tahoe-base` **version tag** (never `:latest`; record the chosen tag — design D2 + Open Questions), tart plugin block, VM build settings per design D5
- [ ] 2.2 Add the provisioner sequence (design D5): `file` copy of `~/XcodesCache/Xcode_26.5.xip` host→guest → `brew install xcodes` → `sudo xcodes install 26.5 --experimental-unxip --path … --select --empty-trash` → move to `/Applications` + `xcode-select -s` + license → `xcodebuild -runFirstLaunch` (**no** `-downloadPlatform`/`-downloadAllPlatforms`, **no** `-downloadComponent MetalToolchain`) → `brew install xcodegen` → cleanup (delete the in-guest `.xip`, empty trash, purge caches)
- [ ] 2.3 Confirm-by-diff against cirruslabs `xcode.pkr.hcl` that every removal in design D5 is actually absent (simulators/platforms, Android SDK, Flutter, fastlane/cocoapods/rbenv/tuist, libimobiledevice, casks, Metal component, multi-Xcode loop)
- [ ] 2.4 Write `packer/README.md`: prerequisites (the three human-gated steps, incl. **where the Tart storage lives** — the `TART_HOME` volume that must hold the base pull, the build VM, and the golden image; likely the external `savepoint` volume — design: Prerequisites 3), build command, the golden-clone runtime workflow (clone → run at 3 vCPU → deploy source via rsync or git clone → `xcodegen generate` + `xcodebuild build-for-testing`/`test` → collect `.xcresult` → delete the clone; never build in the golden — design D7), maintenance (when to rebuild, pin-bump procedure, tart/lume OCI incompatibility note — design: Maintenance, D10), and the current pins + last-verified parity result
- [ ] 2.5 Add the `make image` target: checks packer + the `.xip` at the expected path and fails with install/download instructions when missing (advise, don't privileged-install), then runs `packer init` + `packer build` (design D8); ensure it appears in the no-target `make` help listing
- [ ] 2.6 Update AGENTS.md → Building with a short "local VM test image" subsection pointing at `packer/README.md` (pins, `make image`, golden-clone workflow, the `retire-metal-renderer` dependency)

## 3. Build the image (verify: the build itself)

- [ ] 3.1 Verify `retire-metal-renderer` is applied: a local xtty build succeeds with no `.metal` compile step (the hard dependency for a Metal-free guest — the gate the tasks header pre-registers for group 3+)
- [ ] 3.2 Run `make image` end-to-end; verify the Packer build completes with **zero Apple authentication** during the build (spec scenario: no Apple credentials at build time)
- [ ] 3.3 Report the resulting image footprint; verify it is ~40 GB (not the 87 GB prebuilt class) and record the number in `packer/README.md`
- [ ] 3.4 Verify the golden image was produced from pinned inputs only (the recorded base tag + Xcode 26.5 `.xip`) and that no xtty source is present in the guest (generic-image check, design D6)

## 4. Verify the guest (spec scenarios)

- [ ] 4.1 Clone the golden image, boot the clone, and verify base-layer inheritance holds: auto-login console session, NOPASSWD sudo, brew present (design D2 — the XCUITest infra)
- [ ] 4.2 In-guest: verify the Metal toolchain component is **not installed** — `xcodebuild -showComponent MetalToolchain` reads `uninstalled` (the check §8 actually used). Do **not** use `xcrun -f metal` as the absence check: it PATH-resolves the stub binary inside Xcode even with the component uninstalled (the proven §8b false positive — expected to *succeed* on a correctly-built image); the positive proof is the successful build in 4.3 (design: Risks)
- [ ] 4.3 In-guest: deploy the xtty source at test time (rsync or git clone), run `scripts/bootstrap-swiftterm.sh`, then verify `xcodegen generate` + `xcodebuild build-for-testing` **succeed with no Metal toolchain** (spec scenario: no Metal toolchain yet builds xtty)
- [ ] 4.4 In-guest: run the **full test suite including the XCUITests** on the 3-vCPU clone and collect the `.xcresult` (spec scenario: full-suite-capable image)

## 5. Acceptance: parity with the big-image rig (pre-registered)

- [ ] 5.1 Compare the 4.4 results against the proven big-image rig / CI envelope. **Pre-registered expectation (design D9): if `fix-main-menu-clobber` has not landed, the run shows the race results — primarily the failing-test SET (split / directional-focus / new-tab / find-bar / paste / truecolor / churn, unchanged by the sibling); counts net of `retire-metal-renderer`'s deletion of the Metal e2e (42 → 41 tests): 33/7/1-ish of 41, possibly 35/5/1 (the big-image rigs measured 34/7/1 ↔ 36/5/1 of 42; the two Cmd+D split tests are the known per-launch-flaky pair, §9d). Acceptance = the failing-test set falls within that envelope (parity), NOT an all-green suite.** If the first run is ambiguous, run a second and compare the union
- [ ] 5.2 Delete the test clone (golden stays pristine); record the parity result + run counts in `packer/README.md` (last-verified section)
- [ ] 5.3 Run `openspec validate add-xtty-test-image`; tick trackers per "Keep progress current" (AGENTS Current status + the research doc already carries §10/§11/§11g — no new research doc needed unless the build surfaces a durable finding). **Archive ordering (pre-registered): archive this change only after — or together with — `retire-metal-renderer`**, whose `build-workflow` delta drops the Metal toolchain from the Prerequisite-check requirement; archiving this change first would merge a `build-workflow` spec that both requires the Metal toolchain and asserts the image needs none
