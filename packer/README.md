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

**Native in-guest build (verified 2026-07-06, `add-xtty-test-image` task 4.3 —
the positive proof the §8b `xcrun -f metal` false positive cannot give):** on a
fresh 3-vCPU clone, the source was rsync'd in (no products), SwiftTerm was
cloned+patched **in-guest** by `bootstrap-swiftterm.sh` (v1.13.0 +
`xtty-accessors.diff`), `xcodegen generate` produced the project, and a **native
`xcodebuild build-for-testing` succeeded** (`** TEST BUILD SUCCEEDED **`, ~43 s,
0 errors) — 158 Swift compile steps, `SwiftTerm.o`/`.swiftmodule` + `xtty.app`
(arm64) + `xttyUITests-Runner.app` + the `.xctestrun` all built fresh, with the
Metal toolchain `uninstalled` and **zero** `.metal`/`Metal.xctoolchain` steps in
the guest log. So the minimal image is a complete self-sufficient **build+test**
environment, not just a test runner. Evidence:
`~/Downloads/xtty-vm-poc/artifacts/2026-07-06-add-xtty-test-image-inguest-build/`.

**Full-suite parity (2026-07-05, host-built products via `test-without-building`
— native in-guest build since verified 2026-07-06, see above;
`retire-metal-renderer` landed 2026-07-06):** measured on the
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

### Login-shell variant (bash / zsh) — `add-zsh-test-image`

The template is **parameterized by login shell** (`shell = bash | zsh`, default
`bash`), so one source produces two goldens from the same pinned inputs:

| Command | Golden | Guest login shell |
| --- | --- | --- |
| `make image` (default) | `xtty-test:26.5` | `/bin/bash` (macOS bash 3.2.57 — hosted-runner parity) |
| `make image-zsh` (= `make image IMAGE_SHELL=zsh`) | `xtty-test-zsh:26.5` | `/bin/zsh` |

The **bash** golden is the CI-parity, acceptance-bearing rig; the **zsh** golden
is a **supplement** that exercises xtty's zsh-only OSC 7/133 shell integration
for real (the shell-dependent family takes its asserting arm instead of the bash
rig's vacuous graceful-degradation arm). Use `IMAGE_SHELL=`, **not** `SHELL=` (a
make built-in). The `shell=bash` build stays byte-identical to today's image.
Built 2026-07-08: `xtty-test-zsh:26.5` (3m37s; `xcodebuild -showComponent
MetalToolchain` → `uninstalled`, same as bash). **Note:** a per-boot
`/etc/hosts`-seeding `LaunchDaemon` (`packer/zsh/`) was built to neutralize the
Local Network gate on the zsh guest and **refuted by effect** (see the Local
Network section) — it ships no acceptance-path machinery; the durable fix is the
product change `fix-osc7-hostname-reverse-dns`.

## Runtime workflow (golden-clone per run)

Never boot or build in the golden image — it drifts. Clone per run (APFS
copy-on-write, near-free), constrain the clone, test, then let the caller
decide when to clean up.

> **Why this recipe host-builds (native in-guest build is verified, not
> required).** `retire-metal-renderer` landed 2026-07-06 and
> `add-xtty-test-image` task 4.3 then **proved a native in-guest
> `build-for-testing` succeeds** on the Metal-toolchain-free guest (see
> Last-verified above). So the host-build detour is now a **deliberate choice,
> not a limitation**: building once on the host and running the *identical*
> binary across every test tier (headless ×2 + graphics) keeps build variance
> out of the cross-tier consistency comparison — the property the
> `xtty-test-validator` relies on — and dodges the in-guest Metal-catalog trap
> (§10c) entirely. The runtime that actually matters (the constrained 3-vCPU
> Aqua session where the per-launch race lives) is still 100% in the guest, on
> that one binary; only the *compile* moves to the host. This **supersedes the
> earlier shared-`/tmp` workaround** (`local-macos-vm-ci-reproduction.md` §8b):
> the `.xctestrun` Xcode emits is **`__TESTROOT__`-relative**, resolved against
> wherever the file lands at test time, so the rsync destination need not match
> the host's absolute path — no path rewriting required. **To build natively
> in-guest instead** (a self-sufficient single-run recipe, now proven): rsync
> the source (excl. `build/ external/ .git`), then in-guest run
> `scripts/bootstrap-swiftterm.sh` → `xcodegen generate` →
> `xcodebuild build-for-testing` (source brew's PATH — the non-interactive SSH
> shell lacks `/opt/homebrew/bin`).

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
#    For a GRAPHICS-arm screenshot, capture the Tart VM WINDOW host-side
#    (`screencapture -l<windowid>`) — NOT guest `screencapture`-over-ssh, which
#    trips the macOS ScreenCaptureKit private-window-picker consent attributed
#    to com.apple.sshd-session (responsible-code attribution). The host already
#    has Screen Recording consent (xtty-dev / make bench); do not pre-seed a
#    guest grant. See research/03-analysis/local-network-privacy-forensics.md §9c.
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

**Update (2026-07-08 — the zsh variant + the durable product fix):** the modal
is now removed at the **product** seam by `fix-osc7-hostname-reverse-dns` —
`PaneController.localHostNames` sourced from `gethostname(2)` (the syscall behind
the shell's injected `${HOST}`) instead of reverse-DNS `ProcessInfo.hostName`,
which removes the reverse-DNS call **entirely**, so no modal arises even under
zsh. Measured on `xtty-test-zsh:26.5` (fixed build, `add-zsh-test-image` task 5.1
headless + graphics pre-check): **0** `mDNSResponder … policy 'pending'` events
and no modal on **both** the headless and graphics arms, and the OSC 7
cwd-classification tests run on the live/passing arm (no 38–62s freeze). The two
reasons the modal is gone are now orthogonal and both true: bash emits no OSC 7,
and the fixed build makes no reverse-DNS call regardless of shell.
**Rig-level neutralization was refuted** (`add-zsh-test-image` task 4.1 / design
D2): the per-boot `/etc/hosts`-seeding `LaunchDaemon` did **not** tame the gate —
macOS answers the IPv6 reverse PTR from the files module but escapes the
**routable-IPv4** PTR to the local nameserver (40 `policy 'pending'` events on
the *unfixed* build), and every remaining rig-level lever (TN3179 `Allowed*`
arrays, NE-store pre-seed, SSH-child auto-grant) was closed (T7–T10). So the zsh
variant's **standalone** shell-divergence is measured **headless** (the modal is
graphics-only); the modal-free **graphics** real-arm run rides the product fix.
Full refutation + fates: `research/03-analysis/local-network-privacy-forensics.md`
§8–§9.

### Verifying the Metal-free property

`xcodebuild -showComponent MetalToolchain` in-guest must read **`uninstalled`**.
Do **not** use `xcrun -f metal` as the absence check — it PATH-resolves a stub
binary inside Xcode even with the component uninstalled (a proven false
positive, §8b); on a correctly-built image that lookup *succeeds*. The positive
proof is that the xtty build succeeds without the component.

### Acceptance (measured — post `fix-main-menu-clobber`)

> **The `add-vm-prompt-width-parity` → `harden-findbar-wrap-assertion` red→green pair — CLOSED (2026-07-07).** The image carries a **59-char single-label guest hostname** (`add-vm-prompt-width-parity`, all three `scutil` keys), so bash `\h` reproduces the hosted runner's prompt width and a typed marker **soft-wraps in-guest** exactly as on CI — **verified by effect** on every clone (this also closed the forensics **T6** gethostname spike: setting all three keys makes the NAT'd guest's `\h` read the long name). Applied **alone**, that wide prompt reproduced the CI `findbar-marker-wrap` flake locally — `testFindBarOpensLocatesAndDismisses` red in-guest (the pre-registered `38/2/1`-of-41 interim). `harden-findbar-wrap-assertion` (the pair's second half) then made the `:192` (now `:198`) focus-restore assertion **wrap-tolerant** (mirroring `:53`) and added a deterministic self-validating soft-wrap guard (`testSoftWrapGuardIsWrapTolerant`) — flipping find-bar **red→green on the same image** (no rebuild; source isn't baked in), D2-confirmed against a genuine in-guest soft-wrap. **The pair is closed; the `40/1/1`-of-42 find-bar-green envelope below is the final measured state** — the interim carve-out is retired (see the regression rule). Evidence: `~/Downloads/xtty-vm-poc/artifacts/2026-07-07-findbar-wrap-fix-green-proof/`.

**Envelope: `40/1/1` of 42, measured** (headless ×2 + graphics, all three
byte-identical; 2026-07-07, on the wide-prompt image after the
`add-vm-prompt-width-parity` → `harden-findbar-wrap-assertion` red→green pair
closed. Evidence:
`~/Downloads/xtty-vm-poc/artifacts/2026-07-07-findbar-wrap-fix-green-proof/`.
Lineage: pre-wide-prompt `39/1/1` of 41 (graphics run 2026-07-06 after
`retire-metal-renderer` deleted the always-passing Metal e2e
`testConfiguredMetalRendererIsReported`; from the 2026-07-05 `40/1/1` of 42,
headless ×2 + graphics) → the `38/2/1` of 41 wide-prompt interim (find-bar
reproduced red) → the `40/1/1` of 42 find-bar-green state (paste `:87` still red).

> **`split-shell-dependent-testplan` retired the bash paste red (2026-07-08).** The
> multi-line-paste test — renamed `testMultiLinePasteIsNotAutoExecuted` →
> **`testMultiLinePasteMatchesShellBracketing`** — now branches on the focused
> pane's **observed** `bracketedPasteMode` (a new DEBUG state-dump field) and
> **asserts the correct behavior for each shell**: on the **bash** golden
> (bracketed-paste OFF) it asserts the newline-terminated first line **executed**
> (`command not found` present, exactly once) while the tail line stayed staged —
> xtty's faithful forwarding (design D2). So the former `:87` red is now an
> **asserted green bash arm**, not a residual. Simultaneously the OSC 133/7
> **semantic-capture family** stopped vacuous-passing on bash: each formerly-silent
> `guard waitForCaptureActive else { return }` now asserts a **crisp negative**
> (no command boundaries / no semantic action on a non-injecting shell) — still a
> pass, but now a real one. **Bash-golden envelope: `41/0/1` of 42 — MEASURED**
> (the paste red flipped to green; no test added/removed — the rename + the crisp
> negatives keep the pass count, `+1` from the greened paste). Confirmed by the
> change's full matrix (`split-shell-dependent-testplan` task 6.1, 2026-07-08):
> headless bash ×2 both `41/0/1`, carrying **16** `semantic-capture-absent-arm-asserted`
> crisp-negative attachments and **0** `…capture inactive…` (no vacuous pass),
> paste `bracketed-mode-false` (first line executed once / tail staged). Evidence:
> `~/Downloads/xtty-vm-poc/artifacts/2026-07-08-split-shell-dependent-testplan-fullmatrix/`.

The 7 menu-dispatch tests that made this rig's pre-fix envelope **pass**, and both
`testFindBarOpensLocatesAndDismisses` and the soft-wrap guard are **green**; with
`split-shell-dependent-testplan` the paste test asserts the bash execution arm
**green** too, so the bash golden `xtty-test:26.5` carries **no known-benign
paste red** (the image's `/bin/bash` is macOS **bash 3.2.57**, whose readline
lacks `enable-bracketed-paste` — that shell-specific behavior is now the test's
*asserted* expectation, not a failure).

**zsh rig envelope: `41/0/1` of 42, measured** (headless + graphics on
`xtty-test-zsh:26.5`; 2026-07-08, `harden-paste-wrap-assertion` task 3.3 — evidence
`~/Downloads/xtty-vm-poc/artifacts/2026-07-08-harden-paste-wrap-assertion/`).
`harden-paste-wrap-assertion` greened the former `:82` paste residual; the
`add-zsh-test-image` baseline was `40/1/1` (headless ×2,
`…/2026-07-08-add-zsh-test-image-headless-matrix/`) — the red→green pair's red.
The divergence in **kind** from the bash rig is still the point (design D3,
proven by effect):

- The OSC 133/7 **semantic-capture family asserts for real** — **0**
  `…capture inactive…` attachments (vs 16–17 on the bash rig, which
  vacuous-passes). The live tests (`testChangingDirectoryUpdatesLiveCwd`,
  `testRelativeFileLinkResolvesAgainstCwd`, `testCommandsProduceBlocksWithExitCodes`,
  `testJumpResolvesToEarlierPrompt`, `testCopyCapturesCommandOutput`,
  `testBlockMenuActionsRecorded`) pass fast (3–9s), no main-actor freeze —
  `fix-osc7-hostname-reverse-dns` holds by effect even headless (**0** `policy
  'pending'`).
- **The former single red `testMultiLinePasteIsNotAutoExecuted` at `:82` is now
  FIXED** (`harden-paste-wrap-assertion`, red→green on both arms — headless
  4.77s, graphics 5.11s). zsh HAS bracketed paste, so the paste correctly does
  **not** auto-execute (product behavior is right); the `:82` red was **not** a
  grid-scrape / "staged-highlighted-region" miss as first characterized but the
  **prompt-width soft-wrap** class (find-bar wrap class): the 59-char parity
  `\h` makes the zsh prompt 70 cols, so the 9-char pasted first line `alpha<tag>`
  wraps past the 78-col boundary and the strict matcher couldn't span the `\n`
  the dump inserts between physical rows. The **wrap-tolerant matcher** at
  `:82`/`:84` (mirroring `:53` / `:198`) greens it; a recurrence is now a
  **regression**. This **retires** the residual `split-shell-dependent-testplan`
  was slated to `XCTSkip` — it is **fixed, not skipped**. `split-shell-dependent-testplan`
  then went further and **asserts** (not skips) the **bash `:87`** execution arm
  too, keeping the zsh `:82`/`:84` wrap-tolerance intact — so **neither** arm is
  skipped now; both **assert** their shell's behavior. A zsh run that showed
  `…capture inactive…` attachments would still be a vacuous pass and would **fail**
  acceptance — it did not (0).

The **graphics** zsh run matched headless exactly — `41/0/1`, 0 capture-inactive,
no modal (`harden-paste-wrap-assertion` task 3.3; the earlier `add-zsh-test-image`
graphics pre-check was `40/1/1`, `…/2026-07-08-graphics-both-goldens/`).

**The CI `findbar-marker-wrap` gap is CLOSED — reproduced, then fixed, in-guest.** That flake is a pure **prompt-width** artifact — a long `\h` soft-wraps the typed marker, defeating a strict grid match. `add-vm-prompt-width-parity` gave the image a 59-char single-label `\h` (all three `scutil` keys, mirroring `runner-images`' runtime name), so the marker wraps in-guest and the find-bar red **reproduced here**; `harden-findbar-wrap-assertion` then made the find-bar focus-restore assertion (`:198`) **wrap-tolerant** and it flipped **green** — D2-confirmed against a genuine in-guest soft-wrap (`AFTERFIND####` splitting behind the 58-char `\h` prompt), not trivially. The image now mirrors CI on **race class**, **shell capability**, *and* **prompt width**. **Measured correction:** a long `\h` does **NOT** flip the paste test's failing line `:87`→`:84` as `ci-runner-prompt-width-forensics.md` §6 (option C) predicted — measurement shows it **stays at `:87`** (the `command not found` check). Bash 3.2 executes the pasted newline, so line B (`beta####`) echoes contiguously and fits before col 80, leaving the `:84` `waitForContains(lineB)` still passing; the failure remains the downstream `:87`. Verified mechanism + the gethostname spike (**T6, now closed**) + the options menu: `research/03-analysis/ci-runner-prompt-width-forensics.md`.

Acceptance = **this measured envelope**. With `split-shell-dependent-testplan` the
former bash paste residual is retired (asserted green on both goldens); then
`fix-scroll-wheel-mouse-reporting` added **6 mouse-wheel routing XCUITests**
(`XttyMouseWheelUITests`, suite 42 → **48**); then `smooth-scroll-wheel-momentum`
added **6 more** to the same suite (48 → **54**) — a crisp-negative (a real
automation-channel gesture is recorded `momentum == false`) plus 3
synthetic-injection tests (momentum-not-dropped, lossless-carry,
`.began`-remainder-reset) that drive constructed momentum `NSEvent`s through the
real `scrollWheel(with:)`, plus a byte-level regression
(`testInjectedMomentumFrameProducesRealSGRMouseReportBytes`) that asserts the
real SGR mouse-report bytes reach the child process, plus a real-program
integration test (`testWheelScrollsRealMouseTrackingPager`, task 3.6) — so the
envelope is **`53/0/1` of 54 on _both_ goldens** (the sole skip is the opt-in
benchmark e2e). **MEASURED** (task 4.3 full matrix, 2026-07-09, re-run after
the graphics-tier read-freshness fix below): Tier-0 `237/0/0`, Tier-1 local
`51/0/1`, headless ×2 (bash + zsh) both `51/0/1`, graphics ×2 (bash + zsh) both
`51/0/1` — all five environments identical, all 10 mouse-wheel tests green on
every rig including the previously-failing graphics-bash tier, 0 vacuous
passes. Evidence:
`~/Downloads/xtty-vm-poc/artifacts/2026-07-09-smooth-scroll-wheel-momentum-revalidate/`
(5 `.xcresult` + logs + `REVIEW.md`). The 5th test
(`testInjectedMomentumFrameProducesRealSGRMouseReportBytes`, added after the
manual physical-trackpad verify's step 1 succeeded) is **local Tier-1
confirmed only** (`11/0/0` of the wheel suite alone, red→green-proven against
a reintroduced D1 regression — see the blockquote below); the full VM matrix
above predates it and has **not** been re-run with it included. The 6th test
(`testWheelScrollsRealMouseTrackingPager`, task 3.6) is likewise **local
Tier-1 confirmed only** (`12/0/0` of the wheel suite alone, including both the
5th and 6th tests). The VM full-matrix re-run (task 4.6) measured the 6th test
itself **green on all 5 environments, including both graphics-zsh samples**
(the D9 Risk discriminator — `branch == "report"` vs `after == nil` — never
fired, so the post-review hardening held). The sweep as a whole came back
**OUT-OF-ENVELOPE**, but not from wheel-routing logic: graphics-zsh hit an
unrelated XCUITest runner-level event-delivery stall that cost a *different*
wheel test a short-fixed-timeout casualty in each of two independent samples.
See the "XCUITest runner-level event-delivery stall (graphics-zsh)" row in
the expected-difference matrix below for the full trace. Recorded as a
tracked, open, not-yet-root-caused anomaly — not folded into a clean measured
envelope figure, and not treated as a routing regression.
A regression is now **any test going red** — menu-dispatch,
prompt-width (find-bar included), the paste test on either arm, or a
semantic-capture test that either reds *or* reverts to a **vacuous pass** (a
`…capture inactive…` attachment without an assertion is itself a defect now).
Graphics and headless match exactly (the `windowCount` state-dump assertion
removed the old graphics-mode focus-steal red).

> **`fix-scroll-wheel-mouse-reporting` added the 6 `XttyMouseWheelUITests`
> (2026-07-09).** They assert the wheel-routing branch via the DEBUG
> `lastWheelRouting` state-dump field: report (alt+mouse), cursor-key ×2 (DECCKM
> normal/application arms), local-scrollback, Shift-bypass, and a synthetic-event
> fidelity precheck. All arm terminal state with `printf` escape sequences the
> **engine parses regardless of login shell** (no OSC 133 dependency), and the
> DECCKM form is held deterministically with a foreground `sleep` (so zsh's ZLE
> can't re-toggle application-cursor mode) — so the 6 are **shell-independent and
> expected green on _both_ goldens** (`47/0/1` of 48). The wheel gesture uses
> XCUITest's element-targeted `scroll(byDeltaX:deltaY:)` (Shift via
> `perform(withKeyModifiers:)`) — the automation channel, not a raw CGEvent HID
> post (the runner lacks Post-Event/Accessibility privileges;
> `CGPreflightPostEventAccess=false`). **MEASURED `47/0/1` of 48 on both goldens**
> (task 4.3 full matrix, 2026-07-09): Tier-0 `237/0/0`, Tier-1 local `47/0/1`,
> headless ×2 (bash + zsh) both `47/0/1`, graphics ×2 (bash + zsh) both `47/0/1`
> — all six environments identical, all 6 mouse-wheel tests green on every rig,
> 0 vacuous passes on the zsh rigs, graphics matched headless (no LN modal).
> Evidence: `~/Downloads/xtty-vm-poc/artifacts/2026-07-09-fix-scroll-wheel-fullmatrix/`
> (4 `.xcresult` + logs + `REVIEW.md`).

> **`smooth-scroll-wheel-momentum` added 6 more `XttyMouseWheelUITests`
> (suite 48 → 54).** `testRealGestureIsRecordedAsNonMomentum` is the crisp
> negative (a real `scroll(byDeltaX:deltaY:)` gesture always carries
> `momentumPhase == none`, so `lastWheelRouting.momentum` must read `false`,
> proving the field is wired on the real-gesture path). The other 3 drive the
> **DEBUG synthetic-wheel-event injection hook** (D8) — a test-authored spec
> (`gesturePhase:momentumPhase:precise:deltaY:shift`) that the app turns into a
> faithful `NSEvent` (via the undocumented-but-stable `CGEventField` raw values
> 88/99/123 for is-continuous/scroll-phase/momentum-phase) and drives through the
> **real** `scrollWheel(with:)`, since XCUITest's automation channel carries no
> momentum and posting a raw `CGEvent` is dropped in the runner (the same
> `CGPreflightPostEventAccess=false` constraint as the routing fix's Shift test):
> `testInjectedMomentumFrameIsRoutedNotDropped` (D1 guard-deletion regression
> guard — an injected momentum frame must still route, not vanish),
> `testInjectedFastPreciseGestureDoesNotLoseDistance` (D2 lossless-carry — a
> 10,000px precise gesture must emit more than the old fixed cap of 5 rows),
> and `testAccumulatedRemainderResetsBetweenGestures` (D3 `.began` reset — a
> self-calibrating pair of ~0.6-cell gestures that would sum past a whole cell
> if the remainder leaked across gestures). A 5th test,
> `testInjectedMomentumFrameProducesRealSGRMouseReportBytes` (added
> user-requested, after the manual physical-trackpad verify's step 1
> succeeded), arms `printf '\033[?1002h\033[?1006h'; cat -v` (the same
> technique the human used manually — `cat -v` echoes ESC as literal `^[` text
> instead of xtty's own VT parser silently consuming the unrecognized
> sequence) and injects a momentum frame, then asserts the real SGR wheel-up
> report bytes (`^[[<64;…M`) appear in the **grid dump** — a different
> assertion channel than the other 4 tests (which read only the DEBUG
> `lastWheelRouting` state-dump bookkeeping): it proves the correct bytes
> actually leave xtty and reach the child process, not just that the routing
> field got recorded. It does **not** and cannot automate whether macOS
> actually delivers a real inertial-coast frame during a physical flick, at
> what rate, or child responsiveness under sustained coast — that remains task
> 4.4's manual-only job. All 5 arm terminal state with the same `printf`
> escape sequences as the routing-fix tests (engine-parsed regardless of login
> shell) and the injection hook is itself shell-independent, so they are
> expected green on **both** goldens identically. Verified
> **red→green by effect** before delegating the full matrix, with each of the 3
> guarded regressions reintroduced **in isolation** (D1 guard restored alone, D2
> cap restored alone, D3 reset removed alone) and confirmed restored/green
> again: **D1-only** fails exactly `testInjectedMomentumFrameIsRoutedNotDropped`
> (routing `nil` — silently dropped) with the other two unaffected; **D3-only**
> fails exactly `testAccumulatedRemainderResetsBetweenGestures` (`got 1`, the
> phantom carried-over row) with the other two unaffected; **D2-only** fails
> `testInjectedFastPreciseGestureDoesNotLoseDistance` with the exact expected
> diagnostic (`got 5`, the old cap) **and**, as an honest secondary effect (not a
> test flaw), also fails `testAccumulatedRemainderResetsBetweenGestures`'s setup
> check — its self-calibration step reads the same capped accumulator D2
> guards, so a reintroduced D2 corrupts the derived cell-height estimate too;
> `testInjectedMomentumFrameIsRoutedNotDropped` stays green under D2-only, as
> expected (unrelated code path). Local Tier-1: `10/0/0` of the wheel suite
> alone (all 10 methods, including the pre-existing 6, green). The 5th test
> (`testInjectedMomentumFrameProducesRealSGRMouseReportBytes`) was verified
> **red→green by effect** the same way, against a reintroduced D1 regression
> (the blanket `momentumPhase != [] { return }` guard) — the injected momentum
> frame's SGR bytes never reach `cat -v` (`XCTAssertTrue` on
> `GridDumpReader.waitForContains("^[[<64;", …)` fails) — then restored;
> Local Tier-1 with the 5th test included: **`11/0/0`** of the wheel suite
> alone.

> **The 6th test, `testWheelScrollsRealMouseTrackingPager` (task 3.6), is the
> most end-to-end test in the suite.** Every other wheel test arms mouse mode
> with a `printf`-simulated escape sequence; this one runs `seq 1 500 | less
> --mouse` — a real, unmodified, native macOS command (bundled `/usr/bin/less`
> 668, no Homebrew dependency) that requests its **own** button-event mouse
> tracking. It drives real XCUITest wheel gestures (looping up to 15 times,
> since a single XCUITest-synthesized gesture is "precise" and often doesn't
> cross one whole accumulator cell on its own — spike-measured) and asserts
> **two** things: the DEBUG dump's `lastWheelRouting.branch == "report"` (the
> routing decision) **and** that the terminal's own visible grid content
> actually changes (a real content diff, proving `less`'s own viewport
> genuinely advanced — not just that xtty's internal bookkeeping says it
> routed something). **VM-environment verified**: `less --mouse` requests an
> included mouse mode, not the excluded X10-only mode (spike-measured — a real
> scroll produced `lastWheelRouting.branch == "report"`), and `less 668` with
> `--mouse` support is confirmed present and **identical** on both VM goldens
> (`xtty-test:26.5` bash and `xtty-test-zsh:26.5` zsh) via a direct SSH check
> into stopped-then-resumed clones — not assumed from the local machine's
> version. **Red→green verified**: disabling BRANCH 1's gate in
> `MacTerminalView.scrollWheel(with:)` made the test fail exactly on the
> `branch == "report"` assertion — but the grid content still changed, since
> `less` also responds to BRANCH 2's DECCKM cursor-key fallback (pagers
> conventionally support both mouse wheel and arrow keys) — proving the
> routing check, and not the grid-diff alone, is the assertion that actually
> discriminates this regression. Restored and reconfirmed green. **Hardened
> post-adversarial-review**: two independent reviewers converged on the same
> finding — the readiness wait (`waitForContains("1", …)`) was ambiguous (the
> typed command line itself contains a literal "1" before `less` even
> renders) and the per-tick grid read was a single unguarded synchronous
> `GridDumpReader.read()` racing the app's 150ms async dump-write timer, the
> **same read-freshness race class** that hit `testAccumulatedRemainderResets-
> BetweenGestures` on the graphics VM tier (see below). Fixed: the readiness
> anchor is now `"1\n2\n3"` (a shape only `less`'s line-by-line rendering
> produces, never a single echoed command line), and each tick polls for up to
> 300ms via a `waitForGridChange` helper instead of one synchronous read.
> Re-verified red→green and `12/0/0` locally after hardening. **Confirmed on
> local Tier-1 only so far** — a VM full-matrix re-run (task 4.6) is pending,
> and per design.md's D9 Risk, a red specifically on the `after == nil`
> assertion on a graphics leg would mean this same race class resurfaced
> despite the hardening and needs a longer/re-tuned settle window, not a retry.
> **VM full-matrix measured (task 4.6, 2026-07-09)**: this test passed cleanly
> on all 5 environments including both graphics-zsh samples — the `after ==
> nil` discriminator never fired, so the hardening held under real VM
> conditions. The sweep's OUT-OF-ENVELOPE verdict traces instead to an
> unrelated graphics-zsh XCUITest runner stall costing a *different* wheel
> test a timeout casualty each run — see the new expected-difference-matrix
> row below.

> **Graphics-tier read-freshness race found and fixed (2026-07-09, before the
> full matrix was accepted).** The first `xtty-test-validator` full-matrix run
> came back OUT-OF-ENVELOPE: `testAccumulatedRemainderResetsBetweenGestures`
> failed on the **bash golden, graphics tier only** (4 of 5 environments —
> Tier-1 local, both headless VMs, graphics-zsh — ran it clean). The failure hit
> the test's own setup check, not the D3 assertion it exists to guard: a
> `routing()` call with **no predicate** returns whatever `lastWheelRouting`
> currently holds rather than waiting for a value distinct from the last one
> already observed, and under one graphics-tier (windowed-compositor) launch the
> read for the "first" injected event won the race against the app's dump write
> and returned the **calibration event's own stale, much-larger count** instead.
> This is a **test-synchronization bug, not a product regression** — the same
> "file-consumption implies the dump already reflects it" assumption held on
> Tier-1 + both headless VMs but not once under graphics load. Fixed by giving
> each read a predicate only the fresh event can satisfy: "first" polls for a
> count *different from* the calibration's (orders of magnitude apart), and
> "second" flips scroll direction from "first" (same magnitude, opposite sign)
> so its `direction` field alone disambiguates it even though both correctly
> report `count == 0` and are otherwise byte-identical. Re-verified **red→green**
> against the D3-only isolated regression after the fix (still fails with the
> exact `got 1` diagnostic) and green locally (`10/0/0`) before re-delegating the
> full matrix.

**Confirm-close class (update 2026-07-06):** `harden-churn-shell-readiness`
landed its computed-marker shell-readiness gate; a full sweep (Tier 0 `232/0/0`,
Tier 1 local `40/0/1`, headless ×2 `39/1/1`+`39/1/1`, graphics `39/1/1`) held
this envelope with `testLifecycleChurnReturnsCensusToBaseline` **green in every
tier**. The churn confirm-close race (matrix row below) is now fixed, not a
standing local-only hazard. Evidence:
`~/Downloads/xtty-vm-poc/artifacts/2026-07-06-harden-churn-shell-readiness/`.

**Pre-fix history (for context):** before the fix this rig reproduced the
SwiftUI menu clobber — **34/7/1 ↔ 36/5/1 of 42** (the two Cmd+D split tests
were the per-launch-flaky pair), the exact CI failing set. That was the rig's
whole purpose: to reproduce the per-launch race a green-gated acceptance would
have masked.

> **`fix-scroll-reversal-redraw-corruption` fixed the `cmdScrollDown`
> margin-guard defect and added 1 test (suite 54 → 55).**
> `testScrollRegionReversalDoesNotCorruptOtherColumns` drives the exact
> `SU`/`SD`-inside-a-scroll-region escape sequence directly via `printf`
> (no real full-screen program — `vim`/`less` never invoke `cmdScrollDown`
> regardless of how driven, and `htop`, which does, is brew-only and absent
> from the VM image), so it is shell-independent like the other wheel tests.
> **MEASURED IN-ENVELOPE `54/0/1` of 55 across all 5 environments** (task 3.2
> full matrix, 2026-07-10): Tier-0 `237/0/0`, Tier-1 local `54/0/1`, headless
> ×2 (bash) + ×1 (zsh) all `54/0/1`, graphics ×2 (bash + zsh) both `54/0/1` —
> byte-identical failing sets everywhere (the lone skip is the opt-in
> benchmark e2e). The previously-tracked graphics-zsh runner-level stall
> anomaly did not recur this run. This measurement supersedes the prior
> `51/0/1`-of-54 figure above as the current authoritative envelope; it does
> not attempt to reconcile that figure's own open threads (the runner-stall
> anomaly, the not-yet-re-run 5th/6th wheel tests), which remain
> `smooth-scroll-wheel-momentum`'s own in-flight territory. Evidence:
> `~/Downloads/xtty-vm-poc/artifacts/2026-07-10-fix-scroll-reversal-redraw-corruption/`.

> **`add-git-diff-wrap-toggle` fixed the git-review diff's narrow-wrap bug and
> added 1 test (suite 55 → 56).** The diff panel's unified diff now fills the
> full ~280pt panel width in a configurable **wrap** (new default,
> hang-indented continuation lines) / **no-wrap** (two-axis scroll, every row
> floored to a precomputed diff-wide content-width estimate so tints span the
> full scroll width) mode, toggled by an in-panel button
> (`gitReview.wrapToggle`) and set by a new `git-review-diff-wrap` config key.
> `XttyCore`'s config-loader + `GitReviewStore` unit tests gained **11** (suite
> 237 → **248** — 6 for the config key/store mutator, 5 more from this
> change's own bounded 2-round `/xtty:cross-review` closing geometry-reset
> coverage gaps); `testConfiguredNoWrapModeTogglesAndGeometryMatchesEachMode`
> (`XttyGitReviewUITests`) drives the **real** wrap-toggle button and asserts
> both the routing (`diffWrap` flips) and the rendered layout-geometry
> (`diffFillsWidth`/`diffContentOverflows`, including a short-line negative
> control hardened across both review rounds) via the DEBUG state dump —
> suite 55 → **56**. **MEASURED (2026-07-20, post cross-review): Tier-0
> `248/0/0`, Tier-1 local `55/0/1` of 56** (the lone skip is the pre-existing
> opt-in benchmark e2e) — the toggle test passed non-vacuously (0
> capture-inactive markers in the run log; drove the real button and
> captured 3 distinct DEBUG dump attachments), and all other
> `XttyGitReviewUITests` (layout/emphasis/non-repo/lists-changed-files)
> stayed green. See the ledger for the full finding-by-finding disposition:
> `openspec/changes/add-git-diff-wrap-toggle/cross-review-ledger.md`. Round 1
> fixed a tautological no-wrap overflow signal from a padding/floor ordering
> bug and unified the DEBUG/Release layout paths; round 2 found and fixed a
> more serious defect the round-1 fix itself introduced — a row-count cap that
> silently dropped lines in no-wrap mode for diffs over 500 rows, replaced
> with a laziness-preserving precomputed-width floor that never drops rows in
> either mode.
> **This test is in the same shell-arm class as its `XttyGitReviewUITests`
> siblings, NOT shell-independent** (an earlier note here wrongly claimed the
> opposite, caught by this change's own cross-review Pass B): its
> repo/selection setup depends on the injected shell reporting the live cwd
> via OSC 7 (zsh only), so on the bash VM legs it degrades to the
> capability-absent crisp negative like every other test in this file, never
> reaching the toggle or geometry assertions there. **VM tiers
> (headless/graphics) not yet run for this change**; treat the envelope above
> as local-confirmed only (zsh legs expected to exercise the real assertions,
> bash legs expected to assert the crisp negative per the Shell-arm row below)
> until a full-matrix run updates this note.

### Expected-difference matrix

Differences between environments are not automatically bugs. This table
records the **classes** of legitimate cross-environment difference and their
**causes** — it is the table the `xtty-test-validator` agent (see AGENTS.md)
classifies reds against at runtime. **Counts stay authoritative in Acceptance
above; this table never duplicates a number, only causes.**

| Class | Where it shows up | Cause |
| --- | --- | --- |
| **Shell arm (zsh vs bash)** | Local bare metal (zsh) + the **`xtty-test-zsh:26.5`** VM rig (zsh) vs the bash VM rig `xtty-test:26.5` + hosted CI (bash) | xtty injects OSC 7/133 shell integration into **zsh only** (`ZDOTDIR` redirection). Since `split-shell-dependent-testplan` the semantic-capture family **asserts per shell** (no more vacuous passes): under **zsh** it takes the **capability-present** arm and asserts the real behavior (blocks form, cwd tracks, sidebar populates — 0 capture-inactive attachments); under **bash** it takes the **capability-absent** arm and asserts the **crisp negative** (`assertSemanticCaptureInactive` — no command boundaries / no semantic action, proving OSC 133 did not leak into a non-injecting shell). Both arms are **real assertions and green** — a bash test that *reverts* to a silent early-return (`…capture inactive…` attachment without asserting) is now itself a defect. Also the source of the bash deprecation-banner grid corruption measured (and fixed) in `github-actions-ci-cd.md` §12. |
| **Menu-race sensitivity by machine speed** | Pre-`fix-main-menu-clobber`: ~100% on the constrained 3-vCPU VM, ~0% on unconstrained bare metal | The SwiftUI main-menu clobber (`swiftui-mainmenu-clobber-forensics.md`) was a per-launch race whose odds scale with machine load — the VM's CPU constraint is *why* this rig reproduced it when bare metal didn't. Retired as a live source now that the fix has landed (validated 3× — the counts live in Acceptance above; `github-actions-ci-cd.md` §18); kept here because a **regression** in this class would reproduce the pre-fix menu-dispatch failing pattern recorded in Acceptance's pre-fix history. |
| **Bracketed-paste — bash execution arm (ASSERTED, was a red)** | The bash VM rig `xtty-test:26.5` + hosted CI (both `/bin/bash` 3.2.57); **not** the zsh rig, not local zsh, not Homebrew bash 5.1+ | macOS's stock **bash 3.2.57** readline lacks `enable-bracketed-paste` — a pasted multi-line string forwards line-by-line, so the newline-terminated first line **executes** while the unterminated tail stages. Since `split-shell-dependent-testplan`, `testMultiLinePasteMatchesShellBracketing` (renamed from `testMultiLinePasteIsNotAutoExecuted`) branches on the observed `bracketedPasteMode` and **asserts exactly that** on the bash arm (`command not found` present exactly once; tail staged) — so it is **green**, not the old `:87` red. A recurrence of the *old* red (an unconditional not-executed assertion failing on bash) would be a regression. See `github-actions-ci-cd.md` §19b. |
| **Bracketed-paste — zsh soft-wrap arm (FIXED)** | The zsh VM rig `xtty-test-zsh:26.5` | zsh **has** bracketed paste, so the paste correctly does **not** auto-execute (product behavior is right). The former `:82` red ("first pasted line missing from grid") was **not** a grid-scrape/staged-region miss but the **prompt-width soft-wrap** class (find-bar wrap class): behind the 59-char parity `\h` the 70-col zsh prompt wraps the 9-char pasted first line past the 78-col boundary. **Fixed** by `harden-paste-wrap-assertion` (wrap-tolerant matcher at `:82`/`:84`, mirroring `:53`/`:198`) — zsh rig `40/1/1` → **`41/0/1`**; a recurrence is now a **REGRESSION**. This retires the residual `split-shell-dependent-testplan` was slated to skip — **fixed, not skipped**; that change then **asserts** the bash `:87` execution arm (rather than skipping it) while preserving this zsh wrap-tolerance, so neither paste arm is skipped. |
| **Prompt-width wrap** | Both VM rigs (since `add-vm-prompt-width-parity`) + hosted CI; not local zsh (short bare-metal `\h`) | The guest's 59-char `\h` reproduces the hosted runner's prompt width, so a marker typed at the `\h:\W \u\$ ` prompt **soft-wraps** across physical grid rows; a strict (wrap-intolerant) grid match then reds while a wrap-tolerant one passes. This surfaced `testFindBarOpensLocatesAndDismisses` in-guest — the **intended** fidelity of `add-vm-prompt-width-parity` (`ci-runner-prompt-width-forensics.md`; grid-verified by effect). **The find-bar instance is now fixed** — `harden-findbar-wrap-assertion` shipped the wrap-tolerant matcher on that assertion (`:198`) + a deterministic `testSoftWrapGuardIsWrapTolerant` guard (the red→green pair, proven in-guest); **no current test reds on width**, and a recurrence is a regression. But **the width parity itself is durable**, guarding *future* type-at-prompt assertions. Distinct from the CI-only artifact it reproduces: on the runner the long `\h` is runtime-injected; here it is `scutil`-set in the image. |
| **Mouse-wheel routing (shell-independent)** | All environments identically (local + both VM rigs + CI); NOT a divergence source | `fix-scroll-wheel-mouse-reporting`'s 6 `XttyMouseWheelUITests` arm terminal state (mouse mode / alt screen / DECCKM) with `printf` escape sequences the **engine parses regardless of login shell**, and hold DECCKM deterministically with a foreground `sleep` — so they take the **same** arm on bash and zsh (unlike the semantic-capture family). `smooth-scroll-wheel-momentum`'s 6 additional tests (suite 48 → 54) are equally shell-independent: the crisp negative uses the same real-gesture path, the 3 injection tests drive a DEBUG-constructed `NSEvent` through the real handler with no shell dependency at all, the 5th (`testInjectedMomentumFrameProducesRealSGRMouseReportBytes`, local Tier-1 confirmed — see the blockquote above; VM full-matrix re-run pending) arms `printf`-based SGR mouse tracking + `cat -v` and asserts the real report bytes reach the child, equally shell-independent (engine-parsed), and the 6th (`testWheelScrollsRealMouseTrackingPager`, a real, unmodified `less --mouse` pager rather than a `printf`-armed simulation — confirmed present with identical `less 668`/`--mouse` support on both VM goldens via direct SSH, local-Tier-1-confirmed only, VM full-matrix re-run pending) is likewise shell-independent (the pager's own mouse-tracking request is engine-parsed regardless of login shell). Listed here to record that all 12 are **expected identical (green) everywhere**, not to flag a difference: a red is a real regression on any rig. The wheel gesture rides XCUITest's automation channel (`scroll(byDeltaX:deltaY:)` / `perform(withKeyModifiers:)`) or the DEBUG injection hook, not a raw CGEvent HID post — the runner has no Post-Event/Accessibility grant (`CGPreflightPostEventAccess=false`), so a raw `.cghidEventTap` scroll (or an injection hook that posted instead of constructing) would be silently dropped. |
| **Confirm-close / interference flake sources** | Local bare metal (mouse/keyboard interference); the churn instance was VM-observed pre-fix, now green everywhere; a **second, still-open instance** newly observed on the zsh headless VM (see below) | (a) **live mouse/keyboard interference** during `make test` driving the real GUI (the hands-off requirement the agent surfaces before that tier) — still a live local-only hazard. (b) a **confirm-close race** when a churn test closed a freshly-split pane before its shell settled (a heavier interactive `~/.zshrc` widened the race window locally vs the VM/CI's leaner bash startup) — **fixed** by `harden-churn-shell-readiness` (a computed-marker shell-readiness gate: the churn test proves the fresh shell executed a command before closing it). The churn test now passes green across local **and** both VM rigs (full-sweep-validated 2026-07-06). Root-caused in `github-actions-ci-cd.md` §13; retained here because a regression would reproduce the pre-fix churn-flake pattern. (c) **NEW, still-open (2026-07-09):** `XttyMultiplexingUITests.testNewTabOpensAndLastPaneCloseEscalates` failed **once**, on the zsh headless VM only, during `smooth-scroll-wheel-momentum`'s task-4.5 full-matrix re-run (clean on Tier-1 local, bash headless, both graphics legs) — `XCTAssertEqual failed: ("nil") is not equal to ("Optional(1)") - closing a tab's last pane closes the tab`, i.e. the 5 s poll for `tabCount == 1` after Cmd+W timed out. **Confirmed NOT the retired menu-clobber class**: `requireXttyMainMenu` passed and Cmd+T succeeded moments earlier on the identical menu, so the menu was installed and dispatching. Root-cause-traced instead (read the one failing `.xcresult`, not re-run) to the **same latent class `harden-churn-shell-readiness` fixed for the churn test, but never applied here**: this test opens a tab (Cmd+T) and immediately closes its only pane (Cmd+W) with zero settling wait, and `TerminalWindowController.paneRequestsClose` gates the confirm-close `NSAlert` on `hasForegroundJob()` (`TerminalWindowController.swift:465-472`, a `tcgetpgrp` check) — the exact **refuted** readiness signal (`AGENTS.md` Learned refutations: `fg==shellPid` from ~3 ms; a 15–57 ms zsh-startup child burst can transiently hold the foreground pgrp) that `harden-churn-shell-readiness` replaced with a computed-marker gate **for the churn test only**. A zsh startup burst landing in that window pops a real, undismissed `NSAlert`, so the tab never closes within the poll. **Not caused by, and does not block, `smooth-scroll-wheel-momentum`** (whose own subject — the 11-method wheel suite — is `11/11` green on all 5 environments this run; the diff touches only additive `#if DEBUG` test-injection code, confirmed by inspection). Single-sample (per-launch races are non-deterministic — no retry performed, per the no-retry-flags guardrail); a fix (applying the same shell-readiness gate to this test, or fixing `hasForegroundJob` itself at the product level) is a candidate follow-up change, not yet proposed. |
| **XCUITest runner-level event-delivery stall (graphics-zsh, NEW still-open 2026-07-09)** | The **graphics-zsh** VM tier only, reproduced on **2 of 2** independent samples during `smooth-scroll-wheel-momentum`'s task-4.6 full-matrix re-run (clean on Tier-1 local, both headless legs, and graphics-**bash** — 4 of 5 environments unaffected) | An **unrelated** test (not a wheel test — a different one in each sample) stalled ~930 s inside XCUITest's own `typeText()` keystroke-synthesis internals (the runner's event-delivery path, not xtty's app code), ballooning the whole suite to roughly **3×** its baseline duration (~1300 s vs ~430 s) and starving whichever wheel test happened to be waiting on a short fixed timeout nearby when the stall hit: `testAccumulatedRemainderResetsBetweenGestures`'s `injectWheel` 5 s file-consumption handshake in sample 1, `testInjectedMomentumFrameProducesRealSGRMouseReportBytes`'s SGR-echo wait in sample 2 — a *different* casualty each time, consistent with "whichever short wait happened to be pending," not a deterministic per-test bug. **Not wheel-routing product code**: `testWheelScrollsRealMouseTrackingPager` (task 3.6, the test this run existed to validate) passed cleanly in **both** graphics-zsh samples — the design.md D9 discriminator (`branch == "report"` vs `after == nil`) never fired. **Not caused by `smooth-scroll-wheel-momentum`**: graphics-**bash** ran the identical `#if DEBUG` injection-hook code clean in the same sweep, and the stall site is inside the XCUITest runner's own `typeText()` synthesis — a code path this change's diff never touches. Two independent samples is corroboration, not a retry-until-green (per the no-retry-flags guardrail this is recorded as an open anomaly, not dismissed or laundered into a pass). Root cause not yet identified; a **candidate fix would target the `typeText()` stall itself** (e.g. a re-sample on a quiet host, or graphics-zsh-specific runner diagnostics) — padding the collateral timeouts to survive a 930 s stall was considered and **rejected**: no fixed wait survives an unbounded stall, it would only relocate which test appears to fail, and would ~3× routine graphics-zsh run duration for zero signal. VM clones held stopped-not-deleted; `xtty-r54-gfx-zsh-run2-0709` specifically retained pending further review. Not yet proposed as a follow-up change. |
| **Scroll-reversal redraw corruption (FIXED 2026-07-10)** | Was: real physical trackpad use in a mouse-tracking full-screen app (htop), or the deterministic DEBUG wheel-injection hook / scripted `peekaboo` wheel tick repro. Now: a single deterministic `printf`-driven `AppUITests` regression test, `testScrollRegionReversalDoesNotCorruptOtherColumns` (`XttyMouseWheelUITests.swift`) | Scrolling via xtty's SGR mouse-report path toward the **top** of the list corrupted the redraw — stale characters from earlier rows bled into later ones. Isolated to the mouse-report path specifically: keyboard arrows/Page Down/Page Up clean, the identical wheel recipe against real iTerm2 clean. **Not a `smooth-scroll-wheel-momentum` regression** but **newly reachable** via the wheel→SGR-report feature family (`fix-scroll-wheel-mouse-reporting`). **Root cause found 2026-07-10, fixed same day:** upstream SwiftTerm `cmdScrollDown` (`Terminal.swift:4646`, CSI Ps T/SD) was missing the `if marginMode {…} else {…}` guard its sibling `cmdScrollUp` has; htop's alt-screen buffer never gets `marginRight` raised off its raw `0` default, so `columnCount = marginRight-marginLeft+1 = 1` and every scroll-down shifted only column 0, freezing every other column. **Fixed** by the archived `fix-scroll-reversal-redraw-corruption`: a new hunk in `patches/swiftterm/xtty-accessors.diff` mirrors `cmdScrollUp`'s full-width `splice` path onto `cmdScrollDown`, direction-reversed. A real-program regression test (mirroring the existing `testWheelScrollsRealMouseTrackingPager`) was investigated and rejected — `vim`/`less` (bundled in the test VM) never invoke `cmdScrollDown` regardless of how driven, and `htop` (which does) is brew-only and absent from the VM image — so the test drives the exact `SU`/`SD`-inside-a-scroll-region escape sequence directly via `printf` instead. Confirmed red pre-fix (`"BCCCCCCCCC"` vs expected `"BBBBBBBBBB"`), green post-fix, measured **IN-ENVELOPE `54/0/1` of 55 across all 5 environments** (Tier-0 `237/0/0`; local + headless ×2[bash]/×1[zsh] + graphics ×2, byte-identical failing sets). A recurrence (this test reverting to red) is a regression. Full isolation matrix, mechanism, fates table (T1–T12), and reusable repro recipes: `research/03-analysis/scroll-reversal-redraw-corruption-forensics.md` §7. |

The Acceptance envelope above **and** this matrix are the **runtime source**
`xtty-test-validator` reads at validation time (see `AGENTS.md` → test
validation) — editing either re-tunes the agent's classification without
touching the agent's own definition. **Reverse duty:** any change that alters
test counts or expected residuals (e.g. `retire-metal-renderer`,
`harden-churn-shell-readiness`, `add-vm-prompt-width-parity`, and its pair
`harden-findbar-wrap-assertion`, `add-zsh-test-image` — which added the zsh
rig's envelope + the zsh paste arm — `harden-paste-wrap-assertion`, which
greened that zsh paste arm `:82` `40/1/1` → `41/0/1`, and
`split-shell-dependent-testplan`, which parameterized the shell-dependent tests
per shell — flipping the **bash** paste `:87` red to an **asserted green** arm
(bash golden → expected `41/0/1`) and turning the bash semantic-capture vacuous
passes into **asserted crisp negatives** — `fix-scroll-wheel-mouse-reporting`,
which added the 6 shell-independent `XttyMouseWheelUITests` (suite 42 → 48, both
goldens → expected `47/0/1`) — and `smooth-scroll-wheel-momentum`, which added 6
more shell-independent `XttyMouseWheelUITests` (suite 48 → 54, both goldens;
the wheel suite itself is measured green on all 5 environments including the
6th test, but the task-4.6 sweep as a whole is OUT-OF-ENVELOPE on an
unrelated graphics-zsh XCUITest runner stall — see the expected-difference
matrix row above, not yet folded into a clean `53/0/1` figure)) MUST update
this section — and
Acceptance — in the same session, or the "runtime read" promise just relocates
the staleness.

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
