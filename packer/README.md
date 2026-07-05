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
toolchain (xtty builds Metal-free once `retire-metal-renderer` is applied — a
hard dependency, see below), Android/Flutter/fastlane-class tooling, and the
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
— the native in-guest build pends `retire-metal-renderer`):** measured on the
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

**Hard dependency:** the `retire-metal-renderer` change must be applied to the
xtty repo you intend to test — it patches SwiftTerm's bundled `.metal` shader
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
copy-on-write, near-free), constrain the clone, test, delete:

```sh
# same TART_HOME as the build (default ~/.tart; export only if you chose another volume)

# 1. clone + constrain (3 vCPU = the race-reproducing CI-parity constraint)
tart clone xtty-test:26.5 xtty-run
tart set xtty-run --cpu 3 --memory 7168 --display 1024x768

# 2. boot detached; get the IP (guest creds: admin/admin)
nohup tart run xtty-run >/tmp/xtty-run.log 2>&1 & disown
IP=$(tart ip xtty-run)   # retry until the guest is up

# 3. deploy the source AT TEST TIME (never baked into the image) — either:
rsync -a --exclude build --exclude external --exclude .git . admin@$IP:xtty/   # uncommitted work OK
# or: ssh admin@$IP 'git clone <repo-url> xtty && cd xtty && git checkout <branch>'

# 4. bootstrap + build + test in-guest
#    NOTE: a remote ssh command runs a NON-login shell, which never sources
#    ~/.zprofile — where the base image puts brew's PATH. Any brew-installed
#    tool (xcodegen!) needs the explicit `source ~/.zprofile` prefix;
#    /usr/bin tools (git, xcodebuild) work without it.
ssh admin@$IP 'source ~/.zprofile && cd xtty && scripts/bootstrap-swiftterm.sh && xcodegen generate \
  && xcodebuild test -project xtty.xcodeproj -scheme xtty -destination platform=macOS \
       -derivedDataPath build -resultBundlePath /tmp/xtty.xcresult'

# 5. collect evidence, then delete the clone (the golden stays pristine)
scp -r admin@$IP:/tmp/xtty.xcresult ./artifacts/
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

### Acceptance (pre-registered)

Acceptance = **parity with the proven big-image rig**, *not* an all-green
suite. Until `fix-main-menu-clobber` lands, a full-suite run is *expected* to
show the per-launch-race results: the failing-test **set** (split /
directional-focus / new-tab / find-bar / paste / truecolor / churn) within the
measured envelope — **33/7/1-ish of 41, possibly 35/5/1** (the big-image rigs
measured 34/7/1 ↔ 36/5/1 of 42; `retire-metal-renderer` deletes the passing
Metal e2e, hence 41; the two Cmd+D split tests are the known per-launch-flaky
pair). A green-gated acceptance would mask exactly the race this rig exists to
reproduce. If a run is ambiguous, run a second and compare the union.

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
