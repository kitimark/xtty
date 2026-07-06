# Design: add-xtty-test-image

## Context

Two local VM rigs have already run xtty's full XCUITest suite and reproduced CI run `28472076179` exactly (34/7/1), something bare metal cannot do — the menu-clobber class of per-launch races only loses in a constrained VM (`research/03-analysis/local-macos-vm-ci-reproduction.md` §8/§9). The Tart rig (§9) is the proven tool: its prebuilt `ghcr.io/cirruslabs/macos-tahoe-xcode` image needed zero workarounds — but it is **87 GB**, ~45–50 GB of which is simulators/Android/Flutter/multiple Xcodes xtty never touches, and it is a downloaded artifact, not reproducible from pinned inputs. §10 sized the minimal image at **~40 GB** (the whole win = drop the simulators; OS + macOS-SDK-only Xcode is irreducible) and §11 grounded the build mechanics in cirruslabs' own `macos-image-templates` (Packer + the tart plugin). §11g records the owner decisions this design implements: Packer over a hand-rolled script, a generic image with no xtty source baked in, ghcr push deferred, hard dependency on `retire-metal-renderer`, independence from `fix-main-menu-clobber`.

**Hard dependency:** `retire-metal-renderer` must be applied first. It patches SwiftTerm's bundled `.metal` shader out of the build, which is the *only* reason xtty needs the Metal toolchain (§10b) — without it, the guest cannot compile xtty at all, and fetching the toolchain at arbitrary build time is a deterministic Apple-catalog-rotation trap, not flakiness (§10c, confirmed §11d: cirruslabs downloads it at Xcode *release* time, when the catalog still serves the matching build).

## Goals / Non-Goals

**Goals:**

- A version-controlled, reproducible Packer template that builds a **~40 GB** Tart image: pinned macOS base + Xcode 26.5 (macOS SDK only) + XcodeGen, no simulators, no Metal toolchain.
- Inherit the entire XCUITest session infrastructure (auto-login, automation mode, TCC grants, NOPASSWD sudo, brew) from the cirruslabs base layer instead of re-implementing it (§11b — re-implementing it was the §8 lume pain).
- Zero Apple credentials at image-build time; the one Apple-ID-gated step (downloading the official Xcode `.xip`) is a one-time human prerequisite.
- A documented golden-clone runtime workflow and a `make image` entry point.

**Non-Goals:**

- **No registry (ghcr) push** — deferred until a second consumer exists (§10d). Local image + APFS copy-on-write clones only.
- **No xtty source baked into the image** (owner decision) — the repo arrives at test time in a disposable clone.
- **No CI-workflow change** — `ci.yml` is untouched; the CI-guard cleanup belongs to `retire-metal-renderer`.
- **No all-green suite as acceptance** — see D9; this change does not fix (or wait for) `fix-main-menu-clobber`.
- **No product, test, or harness code.**

## Decisions

### D1 — Packer template (cirruslabs style), not a hand-rolled tart+ssh script

Owner-decided (§11g-2). The template is a strip-down of cirruslabs' `templates/xcode.pkr.hcl` — the exact mechanism that builds the images that already ran xtty's suite natively, with the `github.com/cirruslabs/tart` Packer plugin handling VM boot/SSH/teardown. *Alternatives rejected:* a hand-rolled `tart clone` + `ssh` shell script (re-implements provisioning orchestration, error handling, and cleanup that Packer already does battle-tested); keeping the prebuilt 87 GB `macos-tahoe-xcode` image (works, but non-reproducible, 2× the size, and pins us to whatever cirruslabs bakes); building from a raw IPSW à la the lume rig (re-implements auto-login/TCC/automation mode — the documented §8 pain).

### D2 — Build on `ghcr.io/cirruslabs/macos-tahoe-base` at a **pinned reference**, never a floating `:latest`

`vm_base_name` points at a pinned reference of `macos-tahoe-base`. The base layer is what carries the whole XCUITest infrastructure (§11b): vanilla does kcpassword auto-login + NOPASSWD sudo + screensaver-off; base adds `automationmodetool`, the TCC-database grants, brew, and the runner symlink. Building on base inherits all of it for free — this is precisely why the Tart runs "just worked".

**Apply-time finding (2026-07-04):** the registry publishes **only a `:latest` tag** for `macos-tahoe-base` — no version tags exist — so the pin is the **manifest digest** (`@sha256:a8e1c830…`, upload-time 2026-06-06), which is *stronger* than a tag (immutable by construction). Recorded in the template + README; the README's maintenance section documents re-resolving the digest on a pin bump.

### D3 — File layout: `packer/xtty-test.pkr.hcl` + `packer/README.md`

A new top-level `packer/` directory mirroring cirruslabs' `templates/` idiom: the template plus a README covering prerequisites, build, runtime workflow, and maintenance. *Alternatives:* `scripts/` (wrong — it is a declarative template, not a script; `scripts/` holds executable helpers), a top-level `.pkr.hcl` (clutters the root), `ci/` (this is a local rig, not CI). The README is the canonical doc; AGENTS.md Building gets a short pointer subsection.

### D4 — Xcode 26.5 installed from a pre-downloaded official `.xip` (zero Apple auth in the build)

Per §11c: `brew install xcodes` in-guest, a Packer `file` provisioner copies `~/XcodesCache/Xcode_26.5.xip` host→guest, then `sudo xcodes install 26.5 --experimental-unxip --path … --select --empty-trash` installs from the **local** archive — no Apple authentication during the build. **26.5 is CI parity**: it is the `macos-26` hosted runner's release default and what the proven Tart rig ran (§9a); the lume rig's guest ran Xcode 26.6 (§8b) and reproduced the same results — which strengthens version-insensitivity, but the parity claim rests on CI + the Tart rig. *Alternative rejected:* fully host-free in-guest download via `xcodes install` with `XCODES_USERNAME`/`XCODES_PASSWORD` (puts Apple credentials into the build, adds the `.xip` download to every rebuild; an Apple ID is unavoidable *once* either way — Apple gates all Xcode downloads). *Apply-time finding (2026-07-04):* the Xcode 26.x **Apple-Silicon `.xip` is only ~2.3 GB** (sha1-verified against xcodereleases.com) — Apple slimmed the core distribution; the research's "~10–12 GB" figures are universal-xip era. Consequences: the download prerequisite is far lighter than planned, `xcodes` performs **no integrity check** (a truncated archive ships as "downloaded" — the README adds a mandatory sha1 verification step), and the ~40 GB image estimate is an upper bound (the slim core may expand smaller; measured at task 3.3).

### D5 — What the template runs, and everything removed relative to `xcode.pkr.hcl`

Provisioner sequence (§11e):

1. `file`: copy `Xcode_26.5.xip` host→guest (into the guest user's Downloads).
2. `shell`: `brew install xcodes` → `sudo xcodes install 26.5 --experimental-unxip --path … --select --empty-trash` → move/rename to `/Applications`, `xcode-select -s`, accept license.
3. `shell`: `xcodebuild -runFirstLaunch` — **and nothing more**: no `-downloadPlatform`/`-downloadAllPlatforms` (that single omission is the ~45 GB simulator saving, §10a) and no `-downloadComponent MetalToolchain` (§10c trap; unnecessary post-`retire-metal-renderer`).
4. `shell`: `brew install xcodegen`.
5. `shell` cleanup: delete the in-guest `.xip`, empty the trash, purge caches — the footprint step.

**Removed relative to cirruslabs `xcode.pkr.hcl`:** all simulator/platform downloads (iOS/watchOS/tvOS/visionOS), the Android SDK/NDK, Flutter, fastlane/cocoapods/rbenv/tuist, libimobiledevice, the codex/claude-code casks, the multiple-Xcode install loop, and the `XCODE_COMPONENTS` Metal-toolchain download.

VM settings: `disk_size` set to **60 GB** — a max, not the footprint (§11a; the built image materializes ~40 GB). *Apply-time adjustment:* 60 rather than the base's nominal 50 gives the install transient headroom (the ~12 GB `.xip` and the expanding `Xcode.app` coexist in the guest until the cleanup provisioner runs); the extra max costs nothing on disk. Build-time CPU/memory follow the cirruslabs template (4 vCPU / 8 GB). **The race-reproducing 3-vCPU constraint is a run-time property of the test clone** (set when running the clone), not baked into the image.

### D6 — Generic image: no xtty source baked in

Owner-stated ("not prefer to copy the source from this host to build image"). The image contains toolchain + infra only; the repo arrives at **test time** — rsync from the host or `git clone` inside a fresh clone of the golden image. Rationale: the image stays valid across repo evolution (no rebuild per commit), the golden never accumulates project state, and one image serves any branch/worktree. Trade-off: each test run pays the source deploy + `bootstrap-swiftterm.sh` + first build (~minutes) — acceptable for a rig used per-investigation, not per-commit. (§11e's optional "warm the checkout" is deliberately not taken.)

### D7 — Runtime workflow: golden-clone per run, never build in the golden

Documented in `packer/README.md` (and summarized in AGENTS.md): `tart clone` the golden image (APFS copy-on-write, near-free) → run the clone (3 vCPU, matching the race-reproducing lume rig (§8a) and CI's ~3 vCPU; §9 does not record the Tart rig's vCPU count) → deploy the source → `xcodegen generate` + `xcodebuild build-for-testing`/`test` in-guest → collect the `.xcresult` → **delete the clone**. The golden image is never booted for work — building in it drifts it (§10d).

### D8 — Makefile integration: a `make image` target wrapping `packer build`

Consistent with the repo's make-wraps-everything idiom (the Makefile is the single entry point; targets are thin wrappers). `make image` checks the prerequisites it cannot install (packer present, the `.xip` present at the expected path) and fails with the install/download instructions — mirroring the `make doctor` philosophy of advising, not privileged-installing — then runs `packer init` + `packer build` on the template. *Alternative rejected:* README-only raw commands (breaks the established discoverability contract — `make` with no target must list everything).

### D9 — Acceptance = parity with the big-image rig; pre-registered pre-menu-fix expectation

This change is **independent of `fix-main-menu-clobber`** (§11g-3). Pre-registered: an in-guest full-suite run on the minimal image **before** the menu fix lands is *expected* to show the per-launch-race results. The **primary** pre-registered expectation is the failing-test **set** (split / directional-focus / new-tab / find-bar / paste / truecolor / churn) — it is unchanged by the hard dependency. The pass/total **counts** shift with `retire-metal-renderer`, which deletes the (passing) Metal A/B e2e `testConfiguredMetalRendererIsReported` (42 → 41 tests): expect **33/7/1-ish of 41, possibly 35/5/1** — the big-image rigs measured 34/7/1 ↔ 36/5/1 of 42 (§9d proved run-to-run variance on an identical VM + binary: the two Cmd+D split tests flaky-pass when a launch wins the race). Therefore the image's acceptance criterion is **parity with the proven big-image rig** (the failing-test set falls within the known race envelope), **not** an all-green suite. A retry-tolerant or green-gated acceptance would mask exactly the race this rig exists to reproduce (§9e).

### D10 — ghcr push: deferred

`tart push` to ghcr only earns its keep with a second consumer (a self-hosted runner or a teammate) — §10d. Also noted there: tart and lume OCI images are **mutually incompatible** (`vnd.cirruslabs.tart.*` vs `vnd.trycua.lume.*` media types), so a pushed image would serve tart consumers only. Local image + clones for now; when a second consumer appears, the push is a thin follow-on (needs a `GITHUB_TOKEN` with `packages: write`, once).

## Prerequisites (human-gated, one-time)

Called out explicitly, like `add-distribution-signing`'s $99 gate — the build cannot proceed without them and no script performs them:

1. **Install Packer** — *apply-time correction (2026-07-04):* plain `brew install packer` no longer exists (Packer left homebrew-core after HashiCorp's 2023 license change); the working command is **`brew tap hashicorp/tap && brew install hashicorp/tap/packer`**. The `github.com/cirruslabs/tart` plugin is pulled by `packer init` — which can only run once the template (with its `required_plugins` block) exists, so it is not a separate manual step: `make image` runs `packer init` + `packer build` (D8).
2. **Download the official Xcode 26.5 `.xip` with an Apple ID** — `xcodes download 26.5 --directory ~/XcodesCache` (*apply-time correction:* the `--directory` flag is required — `xcodes download` defaults to `~/Downloads`; or a manual developer.apple.com download) → `~/XcodesCache/Xcode_26.5.xip`. This is the *only* Apple-authenticated step, done once on the host. **Recommendation:** also archive the `.xip` on `/Volumes/savepoint/images/` — insurance against Apple rotating availability, and it makes future rebuilds fully offline.
3. **~45+ GB free disk during the build** (base image pull ~25 GiB + the `.xip` copy + the unxipped Xcode before cleanup), on top of the ~40 GB resulting image — **on the volume that holds the Tart storage (`TART_HOME`)**, where the base pull, the build VM, and the golden image all live. *Apply-time re-measurement (2026-07-04):* the internal disk now has **210 Gi free** (the proposal-time 47–86 GiB figure was pre-cleanup) — so the **default `~/.tart` works**; the external `savepoint` volume (770 Gi free) is the fallback. The README records the chosen one so the free-space check is made against the right volume.

## Risks / Trade-offs

- **[Pinned base digest disappears]** cirruslabs re-pushes `:latest` and the registry may garbage-collect unreferenced manifests → the already-built local image keeps working regardless (the base is only pulled at build time); on a rebuild, re-resolve `:latest` to the current digest (the README's maintenance section has the command) and record it.
- **[`xcodes` formula drift]** the brew formula could change flags or deprecate `--experimental-unxip` → `xcodes` is needed only inside the image build; fallback documented in the README (Apple's own `xip --expand` + manual move accomplishes the same install).
- **[VZ guest exposes a Metal *device* but no toolchain]** `MTLCreateSystemDefaultDevice()` is non-nil in the guest (§10b) even though the Metal Toolchain *component* is not installed → **fine post-`retire-metal-renderer`**: nothing in the build compiles `.metal` anymore, rendering is CoreGraphics, and the Metal-A/B perf test is retired by that change. **Verifying the absence:** `xcrun -f metal` is *not* a valid absence check — it PATH-resolves the stub binary that ships inside Xcode even when the component reads `uninstalled` (the proven §8b false positive), and the minimal image (clean Xcode from the `.xip`, component never fetched) is exactly that state, so the lookup is expected to *succeed* on a correctly-built image. The reliable checks are `xcodebuild -showComponent MetalToolchain` reading `uninstalled` (what §8 actually used) or a trivial `.metal` compile failing; the positive proof is that the xtty build succeeds.
- **[Apple stops serving the 26.5 `.xip`]** older Xcode versions usually stay downloadable, but the archived copy (prerequisite 2) is the real mitigation.
- **[Acceptance is against a moving target]** the race is non-deterministic per launch (§9d), so a single run's exact counts can vary → acceptance compares the failing-test *set* against the big-image rig's envelope (33/7/1 ↔ 35/5/1 of 41 post-`retire-metal-renderer` — the rigs' measured 34/7/1 ↔ 36/5/1 of 42 minus the retired Metal e2e — with the two Cmd+D tests as the known flaky pair), across at least two runs if the first is ambiguous.
- **[Build duration]** first build pulls ~25 GiB of base + installs Xcode (~tens of minutes to hours) → one-time; rebuilds only on pin bumps (see Maintenance).

## Maintenance

Rebuild the image only when a pinned input changes: a new Xcode pin (e.g. CI's `macos-26` runner default moves), a new macOS base pin, or a template fix. The workflow is: update the pin(s) in `packer/xtty-test.pkr.hcl` → download the new `.xip` if the Xcode pin moved (Apple ID, once per version) → `make image` → delete the old golden after the new one passes acceptance. The README records the current pins and the last-verified parity result.

## Migration Plan

1. `retire-metal-renderer` lands first (hard dependency — the zero-Metal build). **Archive ordering (pre-registered):** its `build-workflow` delta (MODIFYING the Prerequisite-check requirement to drop the Metal toolchain) must be archived **before or together with** this change's archive — otherwise the merged `build-workflow` spec would both require the Metal toolchain and assert the image needs none.
2. This change adds `packer/` + the `make image` target + docs; nothing existing is modified except the Makefile help list and AGENTS.md Building.
3. Rollback: delete `packer/` and the make target — the built images are local artifacts outside the repo; nothing depends on them.

## Open Questions

- ~~**The exact `macos-tahoe-base` tag to pin**~~ — **resolved at apply time (2026-07-04):** no version tags exist upstream (only `:latest`), so the pin is the manifest **digest** `sha256:a8e1c830…` (see D2). The guest's actual macOS build gets recorded in the README's last-verified section at first build.
- **Source-deploy flavor at test time** — rsync from the host (matches the §8 workflow, works for uncommitted work) vs in-guest `git clone` (needs the repo public/reachable). The README documents both; no need to standardize now.
- **Whether `packer init` runs inside `make image` every time or once** — folding it in is idempotent and simpler; measure whether its latency is negligible at apply time.

## Open-change interaction (added 2026-07-05)

- **`test-image-bash-shell`** edits this change's `packer/xtty-test.pkr.hcl` after the fact: it adds a `chsh -s /bin/bash` provisioner (hosted-runner shell parity — and the measured resolution of the Local Network modal seen in 4.4's graphics run; the template's original Local Network comment block is superseded and replaced by it). Both changes ADD distinct `build-workflow` requirements — no delta conflict; archive in any order after both apply.
