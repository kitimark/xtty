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

## 7. Addendum (2026-07-03) — ❌ `nektos/act` cannot simulate the macOS runner (source-verified)

> **Provenance:** same day — user question "can act simulate the macOS run?"; shallow-cloned `nektos/act` to `/tmp` and read the runner.

act has exactly **two execution modes**, neither of which reaches a macOS runner environment:

- **Container mode** (`startJobContainer()`, `pkg/runner/run_context.go:672`) — Docker/Podman containers, **Linux-only**; no macOS image type exists anywhere in act (macOS cannot be containerized). The only `darwin` code in the runner is host-side cosmetics: a `:delegated` bind-mount flag for Docker Desktop on Mac hosts (`run_context.go:172`) and an arm64 container-arch default for M-series hosts (`cmd/root.go:417`).
- **Host mode** (`-P macos-26=-self-hosted` → `IsHostEnv` → `startHostEnvironment()`, `run_context.go:186`) — creates temp dirs and runs the job's steps **directly on the host**: no VM, no isolation, no runner image. For this investigation that is worse than useless — it executes `ci.yml`'s steps in exactly the environment that always **wins** the §15 menu race (the fast dev Mac), so a green act run proves nothing about CI.

This source-confirms [`github-actions-ci-cd.md`](github-actions-ci-cd.md) §10f's previously-uncited one-liner ("`act` can't do macOS"). **The faithful "act for macOS" is already in this PoC plan:** Tart's images ship the real `actions/runner` preinstalled, so the VM can register as an ephemeral self-hosted runner and execute the actual `ci.yml` inside an environment that resembles the one that loses the race.

## 8. Addendum (2026-07-03/04) — ✅ PoC EXECUTED: reproduced the CI job EXACTLY, and found the clobber mechanism

> **Provenance:** 2026-07-03/04. **The PoC ran** (§1–§7's "proposed, awaiting review" is superseded — owner approved the recommended defaults: **lume**, **26.4-only** guest, **diagnostics-first**). Empirical — a lume VM built from the verified IPSW, provisioned to runner parity, driving the full `xttyUITests` suite; measurements from an **observe-only** menu-integrity instrumentation (the uncommitted spike branch `spike/menu-clobber-diagnostics`, `55cc8a8` + a sharpened sensor). Evidence bundles at `~/Downloads/xtty-vm-poc/artifacts/`.

### 8a. The rig (build notes)
- **lume 0.3.10** (`brew`, telemetry disabled). Guest **`xtty-ci`** = macOS **26.4 / 25E246** (the exact CI build), **3 vCPU / 7 GB / 1024×768**, restored from the verified IPSW (sha256 `960e6a47…`).
- ✅ **§1 checkpoint resolved — a minor-version-newer guest installs and boots fine on a 26.2 host** (26.4 guest on 26.2 host), refuting the macosvm "guest ≤ host" claim at *minor* granularity (only the *major* boundary fails, per §3).
- **Setup Assistant preset drifted on 26.4** (❌ lesson): lume's `tahoe` preset dies at "Set Up Later" because on 26.4 that affordance is behind a new **"Other Sign-In Options"** step; and `systemsetup -setremotelogin on` is gated behind **Full Disk Access** (TCC), so enabling **Remote Login** took **one manual VNC click** — the *only* non-scriptable step in the whole build. Everything after was SSH-scripted.
- **Runner parity** applied over SSH: `chsh -s /bin/bash`, `automationmodetool enable-automationmode-without-authentication`, NOPASSWD sudo, a ~72-char hostname (the §12 prompt-wrap). **Golden clone** `xtty-ci-osbase` for instant reset; the IPSW archived to an external `savepoint` volume.

### 8b. ❌ The guest Metal-toolchain trap (and the workaround)
- `xcrun -f metal` **resolving a PATH is a FALSE POSITIVE** — the `metal` *binary* exists in Xcode, but the **Metal Toolchain component reads `uninstalled`**; the real test is *compiling a `.metal` file*. The CI guard's `xcrun -f metal || …` check is therefore unreliable as a presence test (it passed while metal was unusable).
- The guest download **fails**: guest Xcode 26.6 requests metal build **17F113**, which Apple's asset catalog won't serve; the metal-toolchain build is **decoupled** from the Xcode build (the host has **17F109** installed and working under the same Xcode). SIP blocks copying the host's installed asset into the guest.
- **Workaround (what actually shipped the run):** `xcodebuild build-for-testing` on the **host** (Metal works) → `rsync` the products to a **shared `/tmp` path** (so the `.xctestrun`'s absolute paths resolve identically on both machines) → `xcodebuild test-without-building` in the guest. The build ran host-side; the *runtime* (where the menu race lives) is 100 % in the guest's Aqua session — the identical arm64 binary. Caveat: **`/tmp` is wiped on guest reboot** — re-rsync the products after any restart.

### 8c. ✅ RESULT — exact CI reproduction (the jackpot)
The full `xttyUITests` suite in the guest (retry-tolerant, CI's flags): **56 executed / 1 skipped / 30 failures → 34 pass / 7 fail / 1 skip** — **identical to CI run `28472076179`**, the **same 7 failing tests** (split / directional-focus / new-tab / find-bar / paste / truecolor / churn), **all of which pass 100 % on the bare-metal host**. The focused 2-test run failed with the **verbatim** CI errors ("Failed to click 'Find…' MenuItem: No matches found …"). Direct launches: **13/13 at 3-vCPU idle showed the default menu** — reproduction is **~100 %**, even more deterministic than CI's ~98 %. The pre-registered "clobberCount > 0 = jackpot" outcome (§4) is met and then some.

### 8d. ✅ MECHANISM — the finding CI could never surface: **in-place item mutation, not a pointer swap**
Directly measured via the sharpened sensor (both host and guest): **`mainMenuPtr == builtMenuPtr` is True** — `NSApp.mainMenu` is *still the object xtty built and installed in ADFL*. Yet on the **guest**, that same object's **own items** now read as the SwiftUI defaults **`[xtty, View, Window, Help]`** — including a **"Help" menu `XttyMainMenu` never creates** — versus the custom **`[Edit, View, Terminal, Window, Debug]`** on the **host**. So SwiftUI **mutates our `NSMenu` object's items in place**; it does **not** swap the `NSApp.mainMenu` pointer. Consequences for `fix-main-menu-clobber` (reconciled into [`github-actions-ci-cd.md`](github-actions-ci-cd.md) §15a/§15e):
- **§15e Stage-A is REFUTED** — re-asserting `NSApp.mainMenu = builtMenu` (same instance) is a **no-op**: the pointer is already correct; the *items* are gone.
- **`NSApplicationMain` (drop the SwiftUI App lifecycle — §15e's "Stage B") is now the REQUIRED fix**, not the eventual one — it's the only option that stops SwiftUI's scene menu management from running at all. (The alternative — rebuild/restore items on `didBecomeActive` — risks re-mutation and is second choice.)
- **The diagnostic must compare item TITLES, not object identity.** My first sensor (`menuIsBuiltInstance`/`menuClobberCount`) read **healthy (True / 0) through a 100 % clobber** — blind to in-place mutation. The fix's harness field must check "does the menu still contain Edit/Terminal?".

### 8e. Evidence
`~/Downloads/xtty-vm-poc/artifacts/`: **`FULL-SUITE-CI-parity.xcresult`** (+ `.log`) — the 34/7/1 run; **`menu-clobber-2tests-FAILED.xcresult`** — the focused split + find-bar failures; **`smoke-testBasicTypedEcho-PASSED.xcresult`** — the drive-path proof; **`FAILED-screenshots/`** — the AX-hierarchy + final-state PNGs showing the clobbered `xtty | View | Window | Help` menu bar. Instrumentation lives on the **uncommitted** spike branch `spike/menu-clobber-diagnostics`.

## 9. Addendum (2026-07-04) — ✅ Tart second rig (native build, no workarounds) + the per-launch race PROVEN live

> **Provenance:** 2026-07-04. A **second, independent rig** on Tart, cross-confirming §8 and settling the race question. The lume-vs-Tart tool tradeoff (§2/§5) is now resolved empirically.

### 9a. The Tart rig — clean, native, no workarounds
Tart 2.32.1 (`brew install cirruslabs/cli/tart`); image `ghcr.io/cirruslabs/macos-tahoe-xcode:latest` pulled to the **external `savepoint` volume** (`TART_HOME` — the ~90–125 GB materialized image can't fit the internal disk's 47–86 GiB free; the owner chose external over internal after the constraint was surfaced). Guest = macOS **26.4 / 25E246** (the exact CI build — the `-xcode` image *tags* are Xcode versions, but the OS is 26.4), with **Xcode 26.5 + a WORKING Metal toolchain** (`Status: installed`, build 17F42), `actions-runner`, brew, auto-login, SSH, and TCC **all preinstalled** → **no Setup Assistant, no Metal fight, no manual VNC click** (contrast §8's lume ordeal). Only deltas applied: `chsh -s /bin/bash`, a long hostname, `brew install xcodegen`. The `ci.yml` build-and-test job ran **natively in-guest** (`xcodebuild test` — build *and* test, **no host-build/`test-without-building` workaround**, unlike §8b).

### 9b. ❌→✅ Download-speed + monitoring lessons
- **Per-connection throttle, beaten by concurrency:** the 64 GiB pull ran at ~2 MiB/s single-stream (ghcr per-connection throttle — the same ceiling Apple's CDN imposed on the §3 IPSW), but **`tart pull --concurrency 64` aggregated to ~25 MiB/s** (the real link ceiling, ~2 h total). The external USB-SSD (measured 908 MB/s write) was never the bottleneck — the connection was.
- **`du` is blind during sparse-fill:** tart assembles all 263 layers into **one pre-sized 140 GB sparse `disk.img`**, so `du` plateaus (filling already-allocated blocks) while `nettop` shows active download. Progress must be measured by **`nettop` bytes, not `du`** — a `du`-based monitor produced false "0.0 MiB/s / stalled" alarms mid-pull.

### 9c. ⚠️ VM-lifecycle lesson
**`tart run` *is* the VM's lifetime.** Running it as a harness background task means a task-kill stops the VM (and drops any SSH build-test with it — observed once). Launch the VM **detached** (`nohup … & disown`) and run the build-test as a **guest-side `nohup` process** writing to a guest log + `resultBundlePath`; then host-side task kills can't lose progress — just reconnect and read the log.

### 9d. ✅ THE HEADLINE — the per-launch race PROVEN by run-to-run variance on the IDENTICAL VM + binary
Two native runs of the same Tart VM, same binary, nothing changed between them:
- **Tart run 1: 36 pass / 5 fail / 1 skip** — `testSplitCreatesAndClosesPanes` + `testDirectionalFocusMovesBetweenPanes` **FLAKY-PASSED** (a `-retry-tests-on-failure` retry caught an app-launch that *won* the menu race).
- **Tart run 2: 34 / 7 / 1** — those **same 2 tests FAILED** (all seven down), an **exact match to CI run `28472076179` and lume §8**.

Same VM, same binary, **different result** → the SwiftUI main-menu clobber is a **NON-DETERMINISTIC per-launch race, proven live** — not merely inferred from CI's single flaky pass (as §15a had to). Five results, all macOS 26.4/25E246 (a **third** Tart run — watched live in the graphics-window VM — landed 34/7/1, confirming the base rate):

| Run | Result | The 2 Cmd+D split tests |
|---|---|---|
| CI `28472076179` | 34 / 7 / 1 | failed |
| lume (host-built) | 34 / 7 / 1 | failed |
| **Tart run 1** (native) | **36 / 5 / 1** | **flaky-passed** (retry won the race) |
| **Tart run 2** (native) | **34 / 7 / 1** | failed |
| **Tart run 3** (native, watched live) | **34 / 7 / 1** | failed |

Base rate across the 3 Tart runs: **2× fully clobbered (34/7/1) + 1× a race-winning retry (36/5/1)** — consistent with CI's ~98 % per-launch clobber. Run 3 was driven in a `tart run` **graphics window**, visually confirming the clobber (Cmd+D produced no split, Cmd+T no tab, the find bar never opened).

### 9e. Fix implication reinforced
Because a **retry-tolerant suite can MASK the race** (Tart run 1 *passed* two genuinely-broken tests), the fix must **eliminate** the race — **`NSApplicationMain` / drop the SwiftUI App lifecycle** (§15e / §8d) — **not** add test retry tolerance. The reproduction rig also makes the fix **directly provable**: build the fix branch, re-run, expect a clean 42/0/1 across repeated runs.

### 9f. Tool verdict for the rig
**Tart (prebuilt `-xcode` image → native build, zero workarounds) is the cleaner, more-reproducible rig than lume** — at the cost of a **64 GiB download + the external disk**. **lume is viable on the internal disk** but needs the Setup-Assistant OCR wrangling + the Metal-toolchain host-build workaround. For repeated CI-parity work, Tart-on-external wins; for a one-off on a full internal disk, lume works.

Evidence: `~/Downloads/xtty-vm-poc/artifacts/` — `TART-native-CI-parity.xcresult` (run 1) + `TART-native-run2.xcresult` (run 2) + `TART-native-run3-visible.xcresult` (run 3) + the lume `FULL-SUITE-CI-parity.xcresult`, all with `.log`s, and README.txt with the full comparison. The Tart VM `xtty-tart` (external `TART_HOME`) and all VM artifacts are **external to the repo**; only the spike branch `spike/menu-clobber-diagnostics` carries the instrumentation.

### 9g. Disk footprint — Tart vs lume (measured 2026-07-04)
| | Tart | lume |
|---|---|---|
| Download | **64 GB** image (~2 h with `--concurrency 64`) | **18 GB** IPSW (~hours single-stream) |
| Actual disk consumed | **~81 GB** (image); the running clone is **near-free** | ~62 GB for **2 VMs** (full copies) + 18 GB IPSW |
| Extra VMs | **~free** — APFS copy-on-write clones | **full copy** (the lume golden clone cost a real 24 GB) |
| Fits internal disk? | **No** — the ~90–125 GB image needs the external volume | **Yes** — ~38 GB per VM |
| Setup effort | **none** (Xcode/Metal/runner preinstalled) | Setup-Assistant OCR + Xcode + Metal + host-build workarounds |

⚠️ **`du` double-counts Tart's CoW clones:** `du -sh $TART_HOME` reported **165 GB**, but the clone shares blocks with the image, so the **actual** consumption was **~81 GB** (savepoint free dropped 851 → 770 GiB = 81 GiB). Measure Tart real usage by `df` delta, not `du`. Net: similar total (~80 GB) but opposite shape — Tart front-loads a big download + external disk then extra VMs are ~free (CoW); lume is a small download that fits internal but every clone is a full copy and every VM pays the setup tax.

### 9h. ❌ lume has NO prebuilt macOS-26 + Xcode image (the structural reason lume was painful)
Queried `ghcr.io/trycua` (lume's registry) 2026-07-04: `macos-tahoe-xcode` **does not exist**; only `macos-tahoe-vanilla:26.2` / `macos-tahoe-cua:26.2` (Tahoe, **no Xcode**) and `macos-sequoia-xcode:15.2` (macOS **15.2** + Xcode-16 era — too old for xtty's Xcode-26-on-macOS-26 need). So there is no lume analog to Tart's `macos-tahoe-xcode` — which is *why* the lume path had to install Xcode by hand and hit the §8b Metal trap. Two mitigations that stop short of a real prebuilt: (a) lume's `macos-tahoe-vanilla:26.2` *does* ship auto-login + SSH, so it would have skipped the Setup Assistant — we only hit that because we chose the exact-26.4 **IPSW** over the 26.2 image for CI-build fidelity; (b) you can bake your own lume Xcode image once (`vanilla` → install Xcode → `lume push` to your ghcr) — but the bake still has to solve Metal once, and it's a real upfront cost. **For a "spawn VM → build+test, zero setup" experience today, Tart's prebuilt Xcode image is the only option** (cirruslabs maintains a CI-focused image catalog; trycua's images are agent-sandbox desktops).

## Sources

- **Per-project source reads (2026-07-03, `/tmp` clones + live registry/API queries):** openai/tart (Sources/tart/Commands/{Run,Exec}.swift, VM.swift; cirruslabs/macos-image-templates `vanilla-tahoe.pkr.hcl` — auto-login/TCC/GHA-runner provisioning; ghcr.io tag/manifest API for `macos-tahoe-{vanilla,base,xcode}` + `macos-runner:tahoe` sizes), trycua/cua `libs/lume` (CommandRegistry, DarwinVirtualizationService, unattended-presets/tahoe.yml, ghcr.io/trycua tags), utmapp/UTM (utmctl scope, VZ backend), s-u/macosvm, insidegui/VirtualBuddy (incl. its Apple-catalog listing 25E246), Veertu Anka docs/pricing.
- **Fidelity (2026-07-03):** ipsw.me signing status for `VirtualMac2,1` (25E246/25E253/25F71/25F80/25F84); Apple VZ docs + motionbug.com major-boundary restore failure; `actions/runner-images` source (`configure-autologin.sh`, `configure-shell.sh`, `configure-tccdb-macos.sh`, PR #5417); host measurements (`sysctl hw.ncpu hw.memsize`, `df -h`); `/Users/markmark/source/contribute/xtty/.github/workflows/ci.yml` (the parity checklist).
- **§7 act verification (2026-07-03):** `nektos/act` shallow-cloned to `/tmp` — `pkg/runner/run_context.go` (`:172` darwin bind-mount flag, `:186` `startHostEnvironment`, `:672` `startJobContainer`, `:675-679` `IsHostEnv`/`-self-hosted`), `cmd/root.go:417`.
- **§8 PoC execution (2026-07-03/04):** lume 0.3.10 VM `xtty-ci` (macOS 26.4/25E246, 3 vCPU) from the verified IPSW; runner-parity provisioning over SSH; host-built products (`build-for-testing`) run in-guest via `test-without-building`; the full-suite `.xcresult` (34/7/1) + 2-test + smoke bundles + failure screenshots at `~/Downloads/xtty-vm-poc/artifacts/`; menu-integrity measurements from the spike branch `spike/menu-clobber-diagnostics` (`55cc8a8` + sharpened sensor). Guest verifications: `sw_vers` 25E246; `xcodebuild -showComponent MetalToolchain` (uninstalled, build 17F113 request fails); `mainMenuPtr`/`builtMenuPtr`/`builtMenuTitlesNow` state-dump fields.
- **§9 Tart rig (2026-07-04):** Tart 2.32.1 (`brew cirruslabs/cli`); `ghcr.io/cirruslabs/macos-tahoe-xcode:latest` (64 GiB / 263 layers) on external `savepoint` (`TART_HOME`); guest `sw_vers` 25E246, `xcodebuild -showComponent MetalToolchain` = installed (17F42); native `xcodebuild test -retry-tests-on-failure` run **three times** (run 3 in a graphics window); `TART-native-CI-parity.xcresult` (run 1, 36/5/1) + `TART-native-run2.xcresult` (run 2, 34/7/1) + `TART-native-run3-visible.xcresult` (run 3, 34/7/1) at `~/Downloads/xtty-vm-poc/artifacts/`; `tart pull --concurrency 64` + `nettop` (vs `du`) + detached-`nohup` lifecycle notes; **§9g** disk `df`-delta measurement (Tart ~81 GB actual, `du` 165 GB CoW-double-count); **§9h** `ghcr.io/trycua` registry query (no `macos-tahoe-xcode`; only vanilla-26.2 + sequoia-xcode-15.2).
- **Companions:** [`github-actions-ci-cd.md`](github-actions-ci-cd.md) §15 (menu clobber — the target; §15a/§15e reconciled with §8d's mechanism + §9d's live race proof), §15f (second-order matrix — the rehearsal floor), §16 + [`confirm-close-shell-readiness.md`](confirm-close-shell-readiness.md) (the marker roundtrip the bash guest validates).
