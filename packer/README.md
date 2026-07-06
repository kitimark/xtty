# xtty test-VM image

A reproducible, minimal (~40 GB) macOS VM image for running xtty's **full test
suite — including the XCUITests — in a local Tart VM**. The per-launch race
class of bugs (see the menu-clobber investigation,
`research/03-analysis/local-macos-vm-ci-reproduction.md` §8/§9) reproduces in a
resource-constrained VM but *not* on bare metal, so this rig is a load-bearing
verification tool, not a curiosity. The image is built the cirruslabs way
(Packer + the `tart` plugin, a strip-down of their `templates/xcode.pkr.hcl`)
from **pinned inputs**, instead of downloading the 87 GB prebuilt
`macos-tahoe-xcode` image (~45–50 GB of which is simulators/Android/Flutter
that xtty never touches).

What's inside: the pinned cirruslabs **base** layer (which carries the entire
XCUITest session infrastructure — kcpassword auto-login, `automationmodetool`,
TCC grants for automation, NOPASSWD sudo, brew) + **Xcode (macOS SDK only)** +
**XcodeGen**. Deliberately absent: all simulator platforms, the Metal
toolchain (xtty builds Metal-free since `retire-metal-renderer`, applied
2026-07-06 — see below), Android/Flutter/fastlane-class tooling, and the
xtty source itself (the repo arrives at *test* time — the image stays generic).

## Current pins

| Input | Pin |
| --- | --- |
| Base image | `ghcr.io/cirruslabs/macos-tahoe-base@sha256:a8e1c8305758643f513fdccdd829c2243687c60791083dea42f73f0b7aeb435c` (only a `:latest` tag exists upstream, so the pin is the manifest digest; resolved 2026-07-04, upload-time 2026-06-06) |
| Xcode | `26.5` — CI parity: the `macos-26` hosted runner's release default and what the proven big-image rig ran |
| Guest disk | 60 GB **max** (annotation, not footprint — the built image materializes ~40 GB; the extra over the base's nominal 50 is unxip-transient headroom) |

**Last verified:** built 2026-07-05 (`make image`, 41 min 17 s incl. the
~25 GiB base pull) → golden **`xtty-test:26.5`, 35 GB** (vs 87 GB prebuilt;
guest-internal usage ~12 Gi of 55). Guest: **macOS 26.5 (25F71)**, Xcode 26.5
(17F42) at `/Applications/Xcode_26.5.app`, xcodegen 2.45.4, brew 5.1.15.
Verified in a 3-vCPU clone: auto-login console (owner `admin`), NOPASSWD sudo,
`xcodebuild -showComponent MetalToolchain` → `uninstalled` (and `xcrun -f
metal` *succeeds* on the stub — the documented false positive, do not use it),
no xtty source in the guest, zero Apple auth during the build.

**Full-suite parity (2026-07-05, host-built products via `test-without-building`
— the native in-guest build now pends only `add-xtty-test-image`'s in-guest
verification; `retire-metal-renderer` landed 2026-07-06):** measured on the
first (zsh-shell) image build: headless run = **33 passed / 8 failed / 1 skipped
of 42**; graphics run = 32 / 9 / 1 (the 1 extra was
`testNewWindowOpensSecondWindow`, inflated by the Local Network modal stealing
focus — it passes headless; the modal is eliminated by the image's **bash login
shell** — see the Local Network section below). **All 8 headless failures are
the menu-clobber class** (split / directional-focus / new-tab / find-bar /
block-menu / churn / paste / truecolor — every one Cmd/menu-driven; zero
non-menu tests failed) → the image reproduces the `fix-main-menu-clobber` race,
which is the parity criterion. With the bash shell (CI's own configuration) the
semantic-capture tests take their graceful-degradation arms exactly as on CI,
so the expected envelope is the hosted-runner one (§8/§9: the 34/7/1 ↔ 36/5/1
failing *set*); the race is non-deterministic per launch (§9d), so run 2–3× to
establish the distribution — the failing *set*, not the exact count, is the
parity signal.

## Prerequisites (human-gated, one-time)

The build cannot proceed without these, and no script performs them:

1. **Packer** — `brew tap hashicorp/tap && brew install hashicorp/tap/packer`
   (plain `brew install packer` no longer exists — Packer left homebrew-core
   after HashiCorp's 2023 license change). The `github.com/cirruslabs/tart`
   plugin is fetched by `packer init`, which `make image` runs for you.
   Tart itself: `brew install cirruslabs/cli/tart`.
2. **The official Xcode installer archive** — the *only* Apple-authenticated
   step, done once on the host with an Apple ID:
   `xcodes download 26.5 --directory ~/XcodesCache` (the `--directory` flag
   matters — `xcodes download` defaults to `~/Downloads`; or download manually
   from developer.apple.com and move it) → `~/XcodesCache/Xcode_26.5.xip`.
   **Size + integrity:** the Xcode 26.x Apple-Silicon `.xip` is only **~2.3 GB**
   (Apple slimmed the core distribution — simulators ship separately; older
   "~12 GB" expectations are universal-xip lore and cause false "truncated!"
   alarms). Verify the download against the published checksum before use —
   `shasum -a 1 ~/XcodesCache/Xcode_26.5.xip` must match the `sha1` for your
   version at <https://xcodereleases.com/data.json> (26.5.0+17F42:
   `a6d5be1576f29c6cade29c4caea5efa1473c072c`). Note `xcodes` itself performs
   **no integrity check** and will happily ship a truncated archive as
   "downloaded" — the checksum is the only real gate. **Also archive a copy on
   `/Volumes/savepoint/images/`** — insurance against Apple rotating
   availability, and it makes future rebuilds fully offline. The image build
   itself never talks to Apple auth.
3. **Disk space on the Tart volume** — ~45+ GB free *during* the build (the
   ~25 GiB base pull + the `.xip` copy + the unxipped Xcode before cleanup) on
   top of the ~40 GB resulting image, **on the volume holding `TART_HOME`**
   (default `~/.tart`). Measured at apply time (2026-07-04): the internal disk
   had **210 Gi free** — comfortably enough, so the default location works;
   the external `savepoint` volume (770 Gi free) is the alternative if
   internal space tightens (`export TART_HOME=/Volumes/savepoint/tart`).
   Record the chosen volume here so future free-space checks target the right
   one. **Chosen:** default `~/.tart` (internal), unless noted otherwise.

**Hard dependency (satisfied on `main` since 2026-07-06):** the
`retire-metal-renderer` change must be applied to the xtty repo you intend to
test — only pre-retire checkouts are affected. It patches SwiftTerm's bundled `.metal` shader
out of the build, which is the *only* reason xtty ever needed the Metal
toolchain. Without it, nothing built from this image can compile xtty (and
fetching the toolchain in-guest is a deterministic Apple-catalog-rotation trap
— see `research/03-analysis/local-macos-vm-ci-reproduction.md` §10c).

## Build

```sh
# optional: pick the Tart volume (default ~/.tart on the internal disk — see prereq 3)
# export TART_HOME=/Volumes/savepoint/tart
make image
```

`make image` checks the prerequisites (advises, never installs), then runs
`packer init` + `packer build` on `packer/xtty-test.pkr.hcl`. First build pulls
the ~25 GiB base image and installs Xcode in-guest — expect tens of minutes to
a couple of hours depending on the network. The result is a local Tart VM named
**`xtty-test:26.5`** — the **golden image**.

## Runtime workflow (golden-clone per run)

Never boot or build in the golden image — it drifts. Clone per run (APFS
copy-on-write, near-free), constrain the clone, test, then let the caller
decide when to clean up.

> **Interim recipe.** `retire-metal-renderer` landed 2026-07-06, so the guest
> *can* now compile xtty in principle — but this recipe stays until
> `add-xtty-test-image` verifies the in-guest build (its remaining tasks).
> The image is deliberately Metal-toolchain-free, and
> fetching the toolchain in-guest is the deterministic Apple-catalog-rotation
> trap documented above (§10c). So today's workflow **builds on the host**
> (where Metal exists), **rsyncs the built products** to the guest, and runs
> **`test-without-building`** in-guest — the runtime that actually matters (the
> constrained 3-vCPU Aqua session where the per-launch race lives) is still
> 100% in the guest, on the identical binary; only the *compile* step moves to
> the host. This **supersedes the earlier shared-`/tmp` workaround**
> (`local-macos-vm-ci-reproduction.md` §8b): the `.xctestrun` Xcode emits is
> **`__TESTROOT__`-relative**, resolved against wherever the file lands at
> test time, so the rsync destination does not need to match the host's
> absolute path — no path rewriting required. **Flip back to a real in-guest
> build** (drop this whole host-build detour) belongs to `add-xtty-test-image`
> (`retire-metal-renderer`'s half landed 2026-07-06).

```sh
# same TART_HOME as the build (default ~/.tart; export only if you chose another volume)

# 1. clone + constrain (3 vCPU = the race-reproducing CI-parity constraint).
#    Use a UNIQUE clone name per run if you keep clones around for review
#    (tart clone fails on an existing name) — e.g. suffix -1/-2 or a date.
tart clone xtty-test:26.5 xtty-run
tart set xtty-run --cpu 3 --memory 7168 --display 1024x768

# 2. boot detached + HEADLESS; get the IP (guest creds: admin/admin).
#    --no-graphics is load-bearing: it is what makes this the headless
#    (acceptance-bearing) arm. For the GRAPHICS arm, drop --no-graphics —
#    a VM window opens on the host. Plain `tart run` is the windowed mode,
#    NOT headless.
nohup tart run --no-graphics xtty-run >/tmp/xtty-run.log 2>&1 & disown
IP=$(tart ip xtty-run)   # retry until the guest is up

# 3. inject your SSH key into the fresh clone — the golden only has password
#    auth (admin/admin), so this happens once per clone, not once per image
#    (-i attaches host stdin; flags come BEFORE the VM name, no `--` separator
#    — Tart 2.32.1 syntax)
tart exec -i xtty-run sh -c 'mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys' \
  < ~/.ssh/xtty-vm.pub
# every fresh clone has a new host key — accept-new keeps the later
# ssh/rsync/scp non-interactive (a strict first contact would hang a
# backgrounded run on the "authenticity of host" prompt)
SSH="ssh -i ~/.ssh/xtty-vm -o StrictHostKeyChecking=accept-new"

# 4. build on the HOST — the guest has no Metal toolchain (interim, see above)
xcodebuild build-for-testing -project xtty.xcodeproj -scheme xtty \
  -destination 'platform=macOS' -derivedDataPath build

# 5. rsync the built products + the .xctestrun to the guest — no path
#    rewriting needed (see the interim-recipe note above). Both live under
#    build/Build/Products/; they must land SIDE BY SIDE at the destination,
#    because __TESTROOT__ = the directory containing the .xctestrun, and the
#    .xctestrun references __TESTROOT__/Debug/…
rsync -a -e "$SSH" \
  build/Build/Products/Debug build/Build/Products/*.xctestrun \
  admin@$IP:~/xtty-build/

# 6. test in the guest — NO retry flag (retry tolerance masks the per-launch race)
$SSH admin@$IP \
  'cd ~/xtty-build && xcodebuild test-without-building -xctestrun *.xctestrun \
     -destination "platform=macOS" -resultBundlePath ~/xtty-build/result.xcresult'

# 7. collect evidence (the convention is ~/Downloads/xtty-vm-poc/artifacts/<run>/).
#    Deleting the clone here is a human's optional last step, not an automated
#    one — a caller like the xtty-test-validator agent lists the clone in its
#    cleanup manifest instead, so a red result stays up for follow-on review.
DEST=~/Downloads/xtty-vm-poc/artifacts/my-run; mkdir -p "$DEST"
scp -r -i ~/.ssh/xtty-vm -o StrictHostKeyChecking=accept-new \
  admin@$IP:~/xtty-build/result.xcresult "$DEST/"
tart delete xtty-run
```

### Local Network prompt (resolved — the image's bash login shell)

The modal *"Allow '&lt;app&gt;' to find devices on local networks?"* seen on the
first (zsh-shell) image build is **eliminated by the image's bash login shell**
(the `chsh -s /bin/bash` provisioner — the same configuration GitHub's
runner-images applies via `configure-shell.sh`).

**Measured root cause (2026-07-05, lldb backtrace + per-config log captures —
supersedes the earlier "XCUITest IPC over the routable vmnet address" theory
and the macOS-version framing):** xtty reads its own host name via
`ProcessInfo.hostName`, which runs `NSHost` → a **reverse-DNS lookup of every
local interface address** (~20 dnssd queries/launch); on a stock guest those
locally-scoped queries hit the Local Network privacy gate. The call runs only
when the shell emits **OSC 7** — i.e. under **zsh** (xtty injects shell
integration into zsh only), never bash. Hence: bash → no OSC 7 → zero reverse
DNS → no dialog — on any macOS version (the trigger reproduces on bare-metal
26.2 with a fresh code identity; version is not the variable). Two refuted
non-fixes, kept on record: a static `HostName` (`scutil --set HostName …`) does
**not** stop the reverse lookups (still 20/launch, measured), and Apple's
TN3179 `AllowedEthernet/WiFiLocalNetworkAddresses` defaults were
screenshot-refuted. Trade-off: under bash the semantic-capture tests take their
graceful-degradation arms — exactly as they do on the (bash) hosted runners, so
this is higher CI fidelity, not a loss. Full investigation:
`research/03-analysis/local-macos-vm-ci-reproduction.md` §12.

### Verifying the Metal-free property

`xcodebuild -showComponent MetalToolchain` in-guest must read **`uninstalled`**.
Do **not** use `xcrun -f metal` as the absence check — it PATH-resolves a stub
binary inside Xcode even with the component uninstalled (a proven false
positive, §8b); on a correctly-built image that lookup *succeeds*. The positive
proof is that the xtty build succeeds without the component.

### Acceptance (measured — post `fix-main-menu-clobber`)

**Envelope: `39/1/1` of 41, measured** (graphics-rig validation run,
2026-07-06, after `retire-metal-renderer` deleted the always-passing Metal
e2e `testConfiguredMetalRendererIsReported` — the churn census test passed
on the same run, re-confirming the confirm-close class as local-only.
Lineage: the 2026-07-05 measured `40/1/1` of 42, 3 runs — headless ×2 +
graphics — all identical. Evidence:
`~/Downloads/xtty-vm-poc/artifacts/2026-07-06-graphics-retire-metal-renderer/`). The 7
menu-dispatch tests that made this rig's pre-fix envelope now **pass**; the
single expected residual is **`testMultiLinePasteIsNotAutoExecuted`**, and it
is **NOT a product bug** — the image's `/bin/bash` login shell is macOS **bash
3.2.57**, whose readline lacks `enable-bracketed-paste`, so a pasted newline
executes (grid-proven; zsh + bash 5.1+ users are unaffected). A future harness
change guards that test on a no-bracketed-paste shell; until then it is the
image's one known-benign red.

Acceptance = **this measured envelope**, *not* a bare all-green (the paste
residual is inherent to the bash rig). A regression is any menu-dispatch test
going red again, or a *second* non-paste failure. Graphics and headless now
match exactly (the fix's `windowCount` state-dump assertion removed the old
graphics-mode focus-steal red).

**Pre-fix history (for context):** before the fix this rig reproduced the
SwiftUI menu clobber — **34/7/1 ↔ 36/5/1 of 42** (the two Cmd+D split tests
were the per-launch-flaky pair), the exact CI failing set. That was the rig's
whole purpose: to reproduce the per-launch race a green-gated acceptance would
have masked.

### Expected-difference matrix

Differences between environments are not automatically bugs. This table
records the **classes** of legitimate cross-environment difference and their
**causes** — it is the table the `xtty-test-validator` agent (see AGENTS.md)
classifies reds against at runtime. **Counts stay authoritative in Acceptance
above; this table never duplicates a number, only causes.**

| Class | Where it shows up | Cause |
| --- | --- | --- |
| **Shell arm (zsh vs bash)** | Local bare metal (zsh) vs both VM rigs + hosted CI (bash) | xtty injects OSC 7/133 shell integration into **zsh only** (`ZDOTDIR` redirection). Under bash, semantic-capture-dependent tests take their documented graceful-degradation arm instead of exercising the real path — parity with the (also-bash) hosted runner, not a regression. Also the source of the bash deprecation-banner grid corruption measured (and fixed) in `github-actions-ci-cd.md` §12. |
| **Menu-race sensitivity by machine speed** | Pre-`fix-main-menu-clobber`: ~100% on the constrained 3-vCPU VM, ~0% on unconstrained bare metal | The SwiftUI main-menu clobber (`swiftui-mainmenu-clobber-forensics.md`) was a per-launch race whose odds scale with machine load — the VM's CPU constraint is *why* this rig reproduced it when bare metal didn't. Retired as a live source now that the fix has landed (validated 3× — the counts live in Acceptance above; `github-actions-ci-cd.md` §18); kept here because a **regression** in this class would reproduce the pre-fix menu-dispatch failing pattern recorded in Acceptance's pre-fix history. |
| **Bracketed-paste capability** | Both VM rigs + hosted CI (all `/bin/bash`); not local zsh, not Homebrew bash 5.1+ | The rig/CI's `/bin/bash` is macOS's stock **bash 3.2.57**, whose readline lacks `enable-bracketed-paste` — a pasted multi-line string executes instead of staging. One known-benign residual, `testMultiLinePasteIsNotAutoExecuted` (`github-actions-ci-cd.md` §18). |
| **Confirm-close / interference flake sources** | Local bare metal only (not observed on either VM rig) | Two local-only hazards: (a) **live mouse/keyboard interference** during `make test` driving the real GUI (the hands-off requirement the agent surfaces before that tier); (b) a **confirm-close race** when a churn test closes a freshly-split pane before its shell settles — more likely locally because a heavier interactive `~/.zshrc` widens the race window than the VM/CI's leaner bash startup. Root-caused in `github-actions-ci-cd.md` §13; the fix is the not-yet-applied `harden-churn-shell-readiness` change. |

The Acceptance envelope above **and** this matrix are the **runtime source**
`xtty-test-validator` reads at validation time (see `AGENTS.md` → test
validation) — editing either re-tunes the agent's classification without
touching the agent's own definition. **Reverse duty:** any change that alters
test counts or expected residuals (e.g. `retire-metal-renderer`,
`harden-churn-shell-readiness`, the harness-truthing successor) MUST update
this section — and Acceptance — in the same session, or the "runtime read"
promise just relocates the staleness.

## Maintenance

Rebuild **only** when a pinned input changes (a new Xcode pin — e.g. CI's
`macos-26` default moves — a new base pin, or a template fix):

1. Update the pin(s) in `packer/xtty-test.pkr.hcl` (+ the table above).
   Re-resolve the base digest with:
   ```sh
   TOKEN=$(curl -s "https://ghcr.io/token?scope=repository:cirruslabs/macos-tahoe-base:pull" | python3 -c "import sys,json;print(json.load(sys.stdin)['token'])")
   curl -sI -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.oci.image.manifest.v1+json" \
     "https://ghcr.io/v2/cirruslabs/macos-tahoe-base/manifests/latest" | grep -i docker-content-digest
   ```
2. If the Xcode pin moved: `xcodes download <new>` (Apple ID, once per
   version) → `~/XcodesCache/` (+ archive to `savepoint`).
3. `make image` → run the acceptance comparison → delete the old golden only
   after the new one passes → update **Current pins** + **Last verified**.

Notes:

- **Pinned digest disappears upstream?** The already-built local golden keeps
  working (the base is only pulled at build time). On rebuild, re-resolve to
  the current digest and record it.
- **`xcodes` formula drift** (flags change / `--experimental-unxip` goes away):
  Apple's own `xip --expand Xcode_<v>.xip` + `mv Xcode.app /Applications/…` +
  `xcode-select -s` accomplishes the same install.
- **tart ↔ lume images are mutually incompatible** (different OCI media
  types); this image serves Tart only.
- **Registry (ghcr) push is deliberately deferred** until a second consumer
  (a self-hosted runner or a teammate) exists; local golden + clones only.
