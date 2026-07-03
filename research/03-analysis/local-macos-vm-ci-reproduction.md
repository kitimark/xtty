# Local macOS-VM reproduction of the CI environment — tool survey, fidelity analysis, and the staged PoC plan

> **Provenance:** 2026-07-03. `/opsx:explore` (user prompt: can we spawn a macOS VM locally to reproduce the CI-only failures? — pointer to `trycua/cua`/lume). Three workflows: **five per-project deep-read agents** (Tart, UTM, macosvm + Apple's VZ sample, VirtualBuddy, Anka + runner-stack verification — each cloned to `/tmp` and read at source level, registries queried live via the ghcr.io API), a **lume deep-read** (same structured schema), and a **fidelity/cost analysis** (IPSW signing status, VZ guest-version rules, race levers, `actions/runner-images` provisioning source, measured host headroom). An earlier combined workflow was interrupted mid-run during user review and relaunched split per-project (better per-project context). **Read-only research — nothing installed, downloaded, or spawned.** Companion to [`github-actions-ci-cd.md`](github-actions-ci-cd.md) §15 (the menu-clobber root cause this rig targets) + §16 and [`confirm-close-shell-readiness.md`](confirm-close-shell-readiness.md).
>
> **STATUS: PoC proposed, awaiting owner review — NOT executed.** Five owner decisions pending (§6).

## 1. Goal

The §15 SwiftUI **menu-clobber race** is locally unreproducible: the GitHub `macos-26` runner (Apple VM, macOS 26.4/25E246, ~3 vCPU, auto-login Aqua session) loses it in ~98 % of app launches; the fast macOS 26.2 dev Mac wins it ~100 %. So the planned `fix-main-menu-clobber` can only be verified today by push-and-read-CI. A local macOS VM would either (a) **reproduce the race** (jackpot: verify the fix against the real failure mode before pushing), or (b) at minimum provide a **CI-parity rig** — the fix's `menuClobberCount`/`mainMenuTitles` diagnostics in a runner-like slow VM, plus a rehearsal stage for the §15f second-order unknowns (quake suite's first real execution on a shared console session; the confirm-close path + the §16 marker roundtrip under a *bash* guest; ⌘⌥-arrow matching on 26.4).

## 2. Tool survey (six candidates, source-level reads 2026-07-03)

| Tool | Guest creation | Xcode preinstalled | Exec-in-guest | Headless + Aqua session | License / cost | Fit |
|---|---|---|---|---|---|---|
| **Tart** (github.com/openai/tart — **OpenAI acquired Cirrus Labs 2026-04**; active, fees dropped) | OCI pulls (`ghcr.io/cirruslabs/macos-tahoe-*`, tags 26.0–26.5) **and** raw IPSW | ✅ `macos-tahoe-xcode:26.x` — **68.8 GB compressed / ~125 GB materialized**; TCC **pre-seeded for SSH-launched XCUITests**; `actions/runner` preinstalled (could run the real `ci.yml` as an ephemeral self-hosted runner) | ✅ `tart exec` (vsock gRPC guest agent) + ssh admin:admin | ✅ `--no-graphics` keeps the auto-login Aqua console session; `--vnc` | $0 — FSL-1.1-ALv2 (internal use unrestricted; → Apache-2.0 after 2 yrs) | **5** |
| **lume** (trycua/cua `libs/lume`; MIT; `brew install lume`) | ghcr.io/trycua pulls (`macos-tahoe-vanilla:26.2`, 23 GB) **and** IPSW with **`--unattended tahoe`** — automates the macOS 26 Setup Assistant (private-API VNC framebuffer + Vision OCR) → user, SSH, **auto-login**, on a 26.x host | ❌ no Tahoe+Xcode image (only `macos-sequoia-xcode:15.2`, Xcode 16-era) | ssh built-in (`lume ssh`, default 60 s timeout — pass `-t 0`); REST API (`lume serve`); no vsock exec | ✅ `--no-display` (VNC server always available, private `_VZVNCServer` API); real Aqua session | $0 MIT — ⚠️ telemetry on by default (disable via `lume config`) | **4.5** for the IPSW route |
| **macosvm** (s-u/macosvm; tiny raw-VZ wrapper, alive 2026-06) | IPSW only; `--ephemeral` clonefile disks | ❌ (~1–2 h hand-provision) | DIY ssh; `--vol` virtiofs | ✅ headless-by-default with real Aqua session | $0 GPL | 4 |
| **UTM** | IPSW only (VZ backend for macOS guests); creation not scriptable end-to-end | ❌ | ❌ `utmctl exec` is QEMU-guest-only → DIY ssh | partial (display-less start; no VNC) | $0 Apache-2.0 | 3 |
| **Anka Develop** (Veertu; closed source; the classic mac-CI stack) | IPSW (incl. exact 25E246); registry is customer-hosted, no public images | ❌ | ✅ `anka run`/`cp` (agent, no ssh) | ✅ | free tier: **MacBook-laptop hosts only, 1 running VM** (this host qualifies) | 3 |
| **VirtualBuddy** | IPSW via built-in Apple catalog — **includes the exact 26.4/25E246 build** | ❌ | ❌ GUI app; no CLI/exec | ❌ no headless/VNC | $0 BSD-2 | 2.5 |

❓ Unresolved by public sources: what stack GitHub's hosted macOS runners actually run on (the provisioning repo `actions/runner-images` is public; the orchestrator/hypervisor is not — Anka is the community's best guess and our forensics hinted it). All VZ-framework tools present the same guest-visible `Apple Virtual Machine 1` model, so a VZ cousin is close on guest-visible characteristics.

## 3. Fidelity facts (the load-bearing ones)

- ✅ **The exact CI build is still obtainable — time-sensitive.** macOS 26.4 **25E246** is still signed and downloadable today as an ~18 GiB `VirtualMac2,1` IPSW (ipsw.me → Apple CDN; 26.4.1/26.5.x also signed). Signing windows close, and GitHub's image has already moved to 26.5.x — **this IPSW is the only remaining way to ever reproduce the original 26.4 environment. Download and stash it early even if the PoC is deferred.**
- ❓ **Guest-newer-than-host at minor-version granularity is undocumented.** The only confirmed VZ failure is at the *major* boundary (macOS 27 IPSW on a 26.x host dies mid-restore). 26.4-guest-on-26.2-host is the PoC's first checkpoint (`VZMacOSRestoreImage` `isSupported` check before the ~30-min install); fallback = install a ≤26.2 guest, upgrade in-guest with a version-pinned `InstallAssistant.pkg`. (The per-project reads disagreed here — macosvm's README states guest ≤ host, Tart's ecosystem routinely runs newer guests; the documented evidence supports "major boundary fails, minor unknown".)
- ✅ **Speed vs version is perfectly confounded in the existing evidence.** The clobber is per-launch and binary; CI (26.4, slow) loses ~98 % of launches (one flaky pass in ~51 × 3), the dev Mac (26.2, fast) wins ~100 % — the dev Mac has never run 26.4. Consistent with speed as the dominant variable (3 vCPU + xcodebuild/testmanagerd contention exactly at app launch), but a 26.3/26.4 SwiftUI menu-timing change cannot be excluded without the experiment.
- ✅ **Race levers, ranked:** (1) few vCPUs (3) with the full `xcodebuild test` drive running **in-guest** (launch-time core contention); (2) tunable background CPU load in the guest (`yes >/dev/null` per vCPU — the dose-response lever); (3) cold boot/caches + a fresh-built ad-hoc-signed bundle per run (LaunchServices + AMFI first-launch work lands in the launch window); (4) the 26.4 guest (removes the version confound).
- ✅ **The runner provisioning recipe is public and verified from `actions/runner-images` source:** auto-login via `kcpassword` + `loginwindow autoLoginUser`; **`chsh -s /bin/bash` is provisioned** (the §11a bash finding was by design, not accident); and **`automationmodetool enable-automationmode-without-authentication` + TCC.db grants** — the hard prerequisite without which XCUITest synthesizes no events. Our guest replicates exactly this recipe (+ a ~72-char `scutil` hostname for the §12 prompt-wrap, 1024×768, driving `xcodebuild` over SSH while the Aqua session owns the display — the real CI topology).
- ✅ **Measured host constraint (this machine, 2026-07-03):** MacBookPro18,3 (M1 Pro), 8 cores, 16 GiB RAM, **66 GiB free** on the data volume. CPU/RAM fine for a 3 vCPU / 7 GB guest. **Disk rules out the Tart prebuilt-Xcode-image route** (~190+ GB peak); the **IPSW route is marginal** (~63–80 GiB peak: 18 GiB IPSW deletable post-install + ~45–60 GiB real guest usage) — feasible only after freeing ~30–40 GB or placing the VM + IPSW on an external SSD. This neutralizes Tart's headline advantage on this machine.

## 4. The staged PoC plan (gated; ~1 elapsed day, mostly unattended)

| Stage | What | Gate |
|---|---|---|
| 0 | Free ~30–40 GB (or attach external SSD); **download the 25E246 IPSW now** | disk secured; IPSW stashed |
| 1 | `lume create --ipsw <25E246> --unattended tahoe --cpu 3 --memory 7168` — the **26.4-on-26.2 install checkpoint** (`isSupported` probe first); fallbacks: 26.2 guest → in-guest pinned upgrade; last resort 26.5.x (weakest version parity, still the speed arm) | guest boots, auto-login works |
| 2 | Runner-parity provisioning in-guest (bash shell, automationmodetool + TCC, hostname, resolution) + Xcode 26.x + Metal guard + brew/XcodeGen + xtty `make setup`; **golden APFS clone** | a trivial XCUITest synthesizes an event in-guest |
| 3 | CI-parity smoke: the suite over SSH while the Aqua session owns the display | suite runs end-to-end |
| 4 | **The experiment:** a diagnostics-only build (`mainMenuTitles`/`menuClobberCount`, observe-only — the observability half of `fix-main-menu-clobber`) × {3 vCPU + guest load, 8 vCPU idle}; one suite run ≈ 51 app launches = decent per-run statistics; then the fix build on top | pre-registered readout ↓ |

**Pre-registered interpretation:** `clobberCount > 0` in the slow guest = **jackpot** — local reproduction; the fix's re-assert is verifiable before pushing. `clobberCount == 0` everywhere = **weak** (cannot distinguish "race needs hosted-runner microtiming" from "fixed"); the rig retires to its guaranteed floor: the §15f rehearsals (quake, confirm-close + §16 marker under bash, ⌘⌥-arrow on 26.4) and force-verification of the canary/diagnostics via an injected deliberate clobber.

## 5. Recommendation

**lume primary** (the IPSW route is forced by disk; lume's `--unattended tahoe` is the only hands-free Setup-Assistant path on a 26.x host; brew-installable, MIT; disable telemetry) — **Tart as the drop-in fallback** (one manual Setup-Assistant click-through; stronger exec/clone ergonomics; its prebuilt-image route becomes preferable on any machine with ~200 GB free). macosvm remains the minimal-raw-VZ fallback if both disappoint.

## 6. Owner decisions pending (the PoC does not start until these are ruled on)

1. **Disk**: free 30–40 GB internal, use an external SSD, or defer the PoC.
2. **Approve the 18 GiB 25E246 IPSW download now** (time-sensitive; harmless standalone).
3. **Tool**: lume (recommended) vs Tart.
4. **Sequencing**: the experiment needs the fix's diagnostics implemented first (observe-only build) — fold into `fix-main-menu-clobber`'s implementation order.
5. **Guest scope**: 26.4-only first (one VM answers "does a slow VM clobber"); add a 26.2-slow guest later only if speed-vs-version needs separating.

## Sources

- **Per-project source reads (2026-07-03, `/tmp` clones + live registry/API queries):** openai/tart (Sources/tart/Commands/{Run,Exec}.swift, VM.swift; cirruslabs/macos-image-templates `vanilla-tahoe.pkr.hcl` — auto-login/TCC/GHA-runner provisioning; ghcr.io tag/manifest API for `macos-tahoe-{vanilla,base,xcode}` + `macos-runner:tahoe` sizes), trycua/cua `libs/lume` (CommandRegistry, DarwinVirtualizationService, unattended-presets/tahoe.yml, ghcr.io/trycua tags), utmapp/UTM (utmctl scope, VZ backend), s-u/macosvm, insidegui/VirtualBuddy (incl. its Apple-catalog listing 25E246), Veertu Anka docs/pricing.
- **Fidelity (2026-07-03):** ipsw.me signing status for `VirtualMac2,1` (25E246/25E253/25F71/25F80/25F84); Apple VZ docs + motionbug.com major-boundary restore failure; `actions/runner-images` source (`configure-autologin.sh`, `configure-shell.sh`, `configure-tccdb-macos.sh`, PR #5417); host measurements (`sysctl hw.ncpu hw.memsize`, `df -h`); `/Users/markmark/source/contribute/xtty/.github/workflows/ci.yml` (the parity checklist).
- **Companions:** [`github-actions-ci-cd.md`](github-actions-ci-cd.md) §15 (menu clobber — the target), §15f (second-order matrix — the rehearsal floor), §16 + [`confirm-close-shell-readiness.md`](confirm-close-shell-readiness.md) (the marker roundtrip the bash guest validates).
