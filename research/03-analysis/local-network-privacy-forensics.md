# macOS Local Network privacy forensics — the hostname reverse-DNS trigger, the probe catalog, and a guideline for proving privacy-gate confounds

> **Provenance:** 2026-07-05. Produced by a live forensic session across **four rigs** — the 26.5 `xtty-verify` clone (the popping rig), an unmodified 26.4 `macos-tahoe-xcode` clone, a fresh clone of the rebuilt bash-shell `xtty-test:26.5`, and the **bare-metal 26.2 dev host** — using unified-log captures, an lldb backtrace, fresh-code-identity probes, NE-store reads, and one-variable-at-a-time A/Bs. Two earlier theories were **retracted mid-investigation** (recorded below with the experiments that killed them). Companion to [`local-macos-vm-ci-reproduction.md`](local-macos-vm-ci-reproduction.md) **§12f** (the compact correction) and the applied change **`test-image-bash-shell`** (the image fix). This doc is the deep record: the machinery, the reproducible probes, and the forward-looking methodology the owner asked to draft.

---

## 1. TL;DR — the settled causal chain

```
zsh login shell (xtty injects OSC 7 integration into zsh ONLY)
  → first prompt emits OSC 7 (kitty-shell-cwd://<host>/<path>)
    → PaneController.localHostNames static initializes          (App/PaneController.swift:92–94)
      → ProcessInfo.processInfo.hostName
        → -[NSHost name] → -[NSHost blockingResolveUntil:]      (CFNetwork; MAIN THREAD BLOCKS on a semaphore)
          → getnameinfo → mdns_hostbyaddr → dnssd               (libsystem_info)
            → reverse-DNS PTR of EVERY local interface address  (~20 requests/launch)
              → mDNSResponder [com.apple.mdns:trust] gate       (locally-scoped reverse zones are mDNS territory)
                → per-app policy 'pending' (no grant recorded)
                  → nehelper raises "Allow 'xtty' to find devices on local networks?"
```

- ✅ **The trigger is xtty's own code**, reachable only under a zsh login shell. bash rigs (GitHub-hosted runners, the §8/§9 VM rigs after their `chsh` delta) never reach the call → never see the dialog.
- ❌ **Not the macOS version** — a fresh code identity prompts on bare-metal **26.2**. (§12b's "26.5 gates where 26.4 did not" retracted.)
- ❌ **Not the XCUITest runner↔app IPC** — plain launches trigger it too; the runner/testmanagerd issue **zero** dnssd requests in every capture. (§12c retracted.)
- ❌ **Not fixable by `scutil --set HostName`** — measured ineffective (still 20 reverse-DNS queries/launch); `NSHost.name` ignores the static key.
- ✅ **Fix classes that work:** (a) don't run the resolver — bash shell (shipped for the test image as `test-image-bash-shell`) or a non-resolving product API (`gethostname(2)`/`SCDynamicStoreCopyLocalHostName` — proposed, **dropped by owner decision**, test-image scope only; source now pinned to **`gethostname`** to match the shell's `$HOST`, confirmed behavior-preserving — **§8d**); (b) satisfy `getnameinfo` before mDNS — `/etc/hosts` entries for **every local address** (proven: 0 gate events; needs per-boot regeneration, superseded by (a)).

## 2. The machinery (internals worth keeping)

### 2a. Local Network privacy architecture (macOS 15+, observed on 26.2/26.4/26.5)

- **Decision + presentation live in `nehelper`** (`/usr/libexec/nehelper`, NetworkExtension). Log lines at the moment of truth: `Local network preference not yet set, prompting for xtty (com.xtty.app)` and `First prompt, starting the queue with TEAMID.<bundle-id> and prompting` — note the **prompt queue**: multiple pending identities queue behind one visible dialog.
- **The gate for DNS-class traffic sits in `mDNSResponder`** under subsystem `com.apple.mdns`, category `trust`: `Local network access to query(<private>) policy 'pending'|'granted' for (<bundle-id>)`. Reverse zones for RFC-1918/link-local/ULA addresses are locally-scoped → answering requires multicast → the trust gate evaluates the **responsible app**.
- **State is the NetworkExtension store, not TCC:** `/Library/Preferences/com.apple.networkextension{,.control,.necp,.uuidcache}.plist` (root-owned, **world-readable** — inspectable without sudo). A per-app record is a keyed-archiver pathRule: `SigningIdentifier = <bundle-id>`, **`DenyMulticast = true` (pending/denied) or `false` (granted)**, `DenyAll = false`. Records are also created **silently** (no prompt) — e.g. `com.xtty.appUITests.xctrunner` on every rig, and a `com.amazon.codewhisperer` record baked into the cirruslabs `-xcode` image.
- ❌ **No supported pre-seed:** `tccutil` doesn't cover LN (not a TCC service); Apple ships no MDM payload (TN3179 states it); hand-editing the NE plists is daemon-reconciled and SIP-adjacent; TN3179's `AllowedEthernet/WiFiLocalNetworkAddresses` exemption arrays were **screenshot-refuted** for this trigger (§12d) — they exempt unicast *addresses*, and this gate fires on *queries*. **The pre-seed refutation is now *measured* end-to-end** (boot-pruning mechanism + a three-tier provenance map: **§8b**); TN3179's *macOS considerations* read in full in **§8a**.
- ❓ **Whether the modal (vs a silent gate) appears for a given launch could not be reduced to one variable**: a fresh identity prompted on bare-metal 26.2 and on the 26.5 VM, but the same fresh identity (`com.xtty.g1`) fired the identical 20-query volley on *both* an unmodified 26.4 guest and the 26.5 guest **without** prompting, while `com.xtty.app` (carrying an older pending record) *did* prompt on 26.5. Prior NE-store state and environment both move the arbiter. **Practical consequence: don't chase the arbiter — remove its input** (§5, G9).

### 2b. `ProcessInfo.hostName` / `NSHost` resolution internals

- lldb-proven chain (source lines, caught live on the 26.2 host): `ProcessInfo.hostName.getter` → `-[NSHost name]` → `-[NSHost blockingResolveUntil:]` → **`dispatch_semaphore_wait` on the calling thread** while a background block runs `getnameinfo` → `mdns_hostbyaddr` → `DNSServiceCreateConnection` + ~20 `DNSServiceQueryRecord` PTR requests (one per local address: the vmnet IPv4, ~5 × `fe80::` link-locals, an `fdd5::` ULA, loopbacks).
- **The calling thread blocks** — in xtty that was the **main actor** (the OSC 7 delegate), i.e. a UI freeze for the duration of the (gated, unanswered) lookups. Measured: the same single UI test took **7.6 s** where the resolver never ran vs **38–62 s** where it ran gated.
- ❌ `scutil --set HostName x.local` does **not** short-circuit it: `Host.current().name` still returned the mDNS-derived name and the PTR volley still fired (measured on the 26.5 rig, set → 20 queries, unchanged).
- ✅ **Non-resolving alternatives verified:** `gethostname(2)` returns a usable name (`<LocalHostName>.local`) instantly with zero dnssd traffic even when the static `HostName` key is unset; `SCDynamicStoreCopyLocalHostName` likewise. Shells emit OSC 7 authorities from `$HOST` (= `gethostname`), so these are also the *more correct* comparison source (call-site now locked: the injected emitter uses `${HOST}` — **§8d**).
- Public precedent: `-[NSProcessInfo hostName]` triggering the LN prompt is attested back to Sequoia 15.x; the `mdns:trust` gate was publicly logged on 26.2 (eclecticlight). Apple DTS has confirmed undocumented point-release LN enforcement changes hitting the XCTest stack (iPadOS 26.3) — the arbiter's behavior is a moving target; the *trigger removal* is the durable defense.

### 2c. The xtty linkage

`XttyCore`'s `OSC7.decode(_:localHostNames:)` flags a reported cwd remote when its authority isn't in `localHostNames`; `PaneController.localHostNames` (App layer, lazy static) supplies that set — and is the only caller of `ProcessInfo.hostName`. The static initializes on the **first OSC 7 event**, so the whole chain is unreachable when the shell never emits OSC 7: xtty injects shell integration into **zsh only** (`shell-integration` spec). That single fact is why every bash rig was silent and why the discriminating "config difference" between images was the login shell — nothing else.

## 3. The investigation record — theories and their fates

| # | Theory | Fate | Killing/confirming experiment |
|---|---|---|---|
| T1 | TN3179 address-exemption defaults suppress it | ❌ refuted (§12d) | write + `defaults read` + reboot → dialog still appeared (screenshot) |
| T2 | macOS version (26.5 gates, 26.4 doesn't) | ❌ retracted | fresh identity `com.xtty.repro1` on bare-metal **26.2**: 26 PTR → `pending` → nehelper "prompting" |
| T3 | XCUITest runner↔app IPC over the routable vmnet address (§12c) | ❌ retracted | plain launch (no XCTest) fires the same volley; runner/testmanagerd = 0 dnssd requests in all captures |
| T4 | Static `HostName` unset is the factor | ❌ retracted | `scutil --set HostName` on the popping rig → volley unchanged (20); host 26.2 has it unset *and* was quiet under the granted identity |
| T5 | The login shell (bash = unreachable trigger) | ✅ confirmed | same rig, same binary: zsh → 20 queries; bash → **0**; GitHub `configure-shell.sh` does `chsh -s /bin/bash` — the hosted-runner config |
| T6 | xtty's `ProcessInfo.hostName` is the call site | ✅ confirmed | lldb breakpoint → full backtrace with `PaneController.swift:92/94/263/265` frames; TextEdit control = 0 dnssd requests |

*2026-07-07 additions (T7–T10 — the build-time / rig-level grant refutations): **§8e**.*

The two mid-course confounds that produced T2/T4 are instructive: the §8/§9 "quiet" rigs carried **two bundled deltas** (`chsh -s /bin/bash` **and** `scutil --set HostName`) applied as one "runner parity" step — so the 26.4-vs-26.5 comparison silently varied three things (OS, shell, hostname) at once. Un-bundling them (T4/T5) took two extra controlled runs on a single rig.

## 4. Reproducible probe catalog

All probes are copy-paste; guest probes assume `ssh admin@$(tart ip <vm>)` with NOPASSWD sudo (cirruslabs images).

**P1 — The LN capture (the 2-minute go/no-go before any fix):**
```bash
sudo log stream --style compact --info --debug \
  --predicate '(subsystem == "com.apple.mDNSResponder") OR (subsystem == "com.apple.networkextension") OR (process == "nehelper") OR (eventMessage CONTAINS[c] "local network")' \
  > ln.log 2>&1 &   # start BEFORE the trigger; sudo needed for full Df/Db visibility
```
**P2 — The verdict greps** (effect, not syntax — expect 0/0/0 after a fix):
```bash
grep -cE "client pid: [0-9]+ \((xtty|<app>)\)" ln.log        # reverse-DNS volley
grep -icE "prompting for|Showing local network" ln.log        # the modal actually raised
grep -icE "policy .pending." ln.log                           # gate evaluations
grep -oE 'client pid: [0-9]+ \([^)]+\)' ln.log | sort | uniq -c | sort -rn   # WHO queried (catches wrong-process attribution)
```
**P3 — Fresh-identity probe** (resets per-app grant state without touching the OS — the arbiter keys on bundle id):
```bash
cp -R <app>.app /tmp/probe.app
plutil -replace CFBundleIdentifier -string com.xtty.probe1 /tmp/probe.app/Contents/Info.plist
codesign --force --deep -s - /tmp/probe.app && open /tmp/probe.app
# leaves an inert NE-store record for com.xtty.probe1; remove via System Settings ▸ Privacy ▸ Local Network
```
**P4 — lldb attribution** (who makes the call; works as the user for own apps):
```bash
xcrun lldb -b -o 'breakpoint set -n DNSServiceCreateConnection' -o run -o 'thread backtrace all' -o 'process kill' <app>.app/Contents/MacOS/<bin>
# 'thread backtrace all' is load-bearing: the dnssd call runs on a dispatch worker; the BLOCKED caller
# (semaphore wait) is on another thread — a single-thread bt hides the true call site.
```
**P5 — NE-store read** (world-readable; no sudo):
```bash
plutil -p /Library/Preferences/com.apple.networkextension.plist | grep -B8 '"<bundle-id>"' | grep -E 'DenyMulticast|DenyAll'
# DenyMulticast=false → granted; true → pending/denied; absence → never evaluated
```
**P6 — Control app** (baseline the environment): launch TextEdit under P1 — 0 dnssd requests expected; a noisy control means the instrument, not the target, is suspect.
**P7 — hosts-file discriminators:** forward mapping (`127.0.0.1 <hostname>`) does **not** stop reverse-PTR volleys (proven inert for this trigger); seeding **every local address** (`<addr> <name>` per `ifconfig` inet/inet6) **does** (getnameinfo hits the files module first) — a valid rig-level fix but per-boot-dynamic; superseded by the bash shell.
**P8 — Known-dead instruments:** `log` private-data plist does **not** unmask mDNS qnames (`<mask.hash: …>` is mDNSResponder's own privacy layer, separate from logd `<private>`; the hashes are stable per name — usable as fingerprints); `tccutil`/MDM/NE-plist hand-seeding — see §2a.

**End-to-end verification recipe** (as used for `test-image-bash-shell`; artifacts in `~/Downloads/xtty-vm-poc/artifacts/bash-image-verify/`): fresh clone → P1 running → full suite via `test-without-building` → P2 expect 0/0/0 → counts + failing set vs the CI envelope → keep the `.xcresult` + `ln.log` as the review bundle.

## 5. The guideline — proving/refuting this class of confound (draft, for future investigations)

**G1 — Verify the effect, never the syntax.** A `defaults read` read-back, a config line, or a doc claim is not evidence; the §12d TN3179 "fix" passed read-back and failed on screen. Acceptance = the observable (log counts, dialog presence, test result), captured by an instrument that was running *before* the trigger.

**G2 — One variable per trial; enumerate bundled deltas first.** Before comparing rigs, list *every* delta between them (shell, hostname, OS build, image lineage, prior grant state, headless-vs-graphics). The 26.4-vs-26.5 comparison was invalidated twice by a two-line "runner parity" step nobody thought of as two variables. If a conclusion rests on a cross-rig comparison, re-derive it as a same-rig A/B (T4/T5 pattern).

**G3 — Reset state with fresh identities, not fresh machines.** Privacy arbiters key on code identity and remember (silently). A granted/pending record makes dialogs non-idempotent — the same trigger can prompt, stay silent, or queue. P3 (bundle-id swap) gives a pristine trial in seconds; deleting VMs does not (image-baked records travel), and note ad-hoc signing churns cdhash but *not* the bundle-id key.

**G4 — Instrument before fixing (the 2-minute gate).** Run P1+P2 once against the failing case before designing anything. Every wrong theory here would have been killed a day earlier by one capture: the log names the *process*, the *query class*, and the *policy verdict* — which is the whole diagnosis.

**G5 — Always run a control.** A stock app (P6) separates "the OS gates everyone" from "our process does something unusual" in one launch.

**G6 — Record retractions in place.** Superseded claims get a dated ❌ with the killing experiment *next to the original claim* (§12b/§12c → §12f pattern), so future readers can't cite the stale version and future sessions don't re-litigate. A retraction with its evidence is a *result*, not an embarrassment.

**G7 — Evidence hierarchy.** Unified-log counts (running before the trigger) > lldb backtraces (attribution) > screenshots (state at an instant; can miss stacked/transient dialogs — two modals stacked here once) > store read-backs (state, not behavior) > docs/memory (hypothesis fuel only). Verify at the highest rung the claim allows.

**G8 — Escalation ladder when the log isn't enough:** P1 capture → P5 store read → P4 lldb (who) → packet capture on 5353 (what, if it reaches the wire — gated queries may not) → P3 fresh identity (state) → same-rig config A/B (which variable). Each rung is minutes; don't skip to theory.

**G9 — When the arbiter is irreducible, remove its input.** Apple's prompt policy shifts across point releases without documentation (DTS-confirmed) and depends on state you can't fully enumerate (§2a ❓). A fix that argues with the arbiter (exemptions, grants, watchers) inherits that instability; a fix that eliminates the gated operation (don't resolve; don't emit) is version-proof. Prefer it even when a grant-shaped fix "works today."

**G10 — Match the reference rig at the source.** When the goal is reproducing CI, copy CI's own provisioning (runner-images scripts are public — `configure-shell.sh` was the answer sitting in plain sight), rather than inventing an equivalent. Fidelity by construction beats fidelity by debugging.

## 6. Residual unknowns

- ❓ The arbiter's modal-vs-silent decision (§2a) — deliberately not chased further; moot for xtty while no gated call exists.
- ❓ The product-side trigger still ships for real zsh users of xtty on every macOS (one first-launch dialog + a main-thread block on first OSC 7). A non-resolving product fix was proposed (`gethostname` + `SCDynamicStoreCopyLocalHostName` in `localHostNames`) and **dropped by owner decision** (test-image scope only). Recorded so it isn't rediscovered from scratch; the trigger will re-surface if xtty is dogfooded under zsh with a fresh identity or on user machines. **(2026-07-07: the fix is behavior-preserving and *more correct* — §8d; and T7/T8/T10 close every build-time / rig-level alternative — §8b/§8c/§8e — so the product `gethostname` swap is the only durable path besides running headless.)**
- ❓ Whether future macOS gates something the *XCTest stack itself* does (the DTS iPadOS-26.3 precedent) — the rig's canary is the P1/P2 zero-count check in the verification recipe; a regression shows up as a named count, not a mystery flake.

## 7. Artifacts

`~/Downloads/xtty-vm-poc/artifacts/` — `ln-diagnosis/` (pre-fix captures: the 20-query volleys, the trust/pending/prompting lines, `run1-modals-and-clobbered-menu.png` with two stacked consent dialogs); `bash-image-verify/` (post-fix: `REVIEW.md`, full-suite `.xcresult`, `ln-suite.log` with 0/0/0, suite log — the 34/7/1 exact CI envelope); `minimal-image-run/` (§12 originals incl. the TN3179 refutation screenshots). VMs kept: `xtty-verify` (pre-fix zsh rig), `xtty-verify2` (post-fix bash rig), both stopped.

## 8. Addendum (2026-07-07) — TN3179 *macOS considerations* read, the build-time-grant refutation (three-tier NE-store provenance map), the SSH-child refutation, and the `$HOST`=`gethostname` call-site lock

> **Provenance:** 2026-07-07 graphics-VM session on the freshly-built goldens `xtty-test-zsh:26.5` (zsh) and `xtty-test:26.5` (bash), plus a full read of TN3179's *macOS considerations* (the JSON behind the SPA) and a repo call-site trace. Method: **by effect throughout** — modal presence in a windowed Tart clone + NE-store `plutil` transitions across cold boots. Extends §2a (no supported pre-seed → now *measured*, with the mechanism) and §1/§2b/§6 (the non-resolving product fix → source pinned). Artifacts in §8h.

### 8a. TN3179 *macOS considerations*, read in full

macOS **auto-allows** local-network access for **(i)** any daemon started by `launchd`, **(ii)** any program running as **root**, **(iii)** command-line tools run from Terminal or over **SSH — and any child processes they spawn**. The exception does **not** extend to `launchd` *agents*. When a process performs a local-network operation, macOS "tracks down the **responsible code**" and "considers **the app** to be the responsible code" — recording the choice per-app.

- The `AllowedEthernet/WiFiLocalNetworkAddresses` keys are **destination-address exemptions**: *"the system treats every address on that network as if it were not a local network address. Every program can access that address, regardless of its Local Network privilege state."* → confirms §2a: they gate *connections to addresses* (unicast-address axis); xtty's trigger is a reverse-DNS **query** (name axis) — orthogonal, which is why baking them in fails (8e/T7).
- *"Device managers aren't able to configure local network privacy using MDM."* — no profile path (confirms §2a).

### 8b. Build-time grant is refuted every way — the three-tier NE-store provenance map

§2a's "no supported pre-seed; hand-editing is daemon-reconciled" is now **measured**. Extracted xtty's *granted* NE-store record, baked it into a fresh golden clone **before first boot** (the faithful pkr.hcl-bake simulation), cold-booted, and read the store:

| Record provenance | Survives cold boot? | Suppresses the prompt? |
|---|---|---|
| **Hand-baked** (build-time injection) | ❌ **pruned on boot** | ❌ re-prompts |
| **Implicit** (prompt timed out, no click) | ✅ survives | ❌ **re-prompts** on next launch |
| **Explicit** (a real *Allow* click) | ✅ survives | ✅ **silent** thereafter |

- **Mechanism:** `nesessionmanager` **rewrites the NE store on every boot and prunes records lacking live-consent provenance.** Apple system-app records (`com.apple.TV`, `com.tcltk.wish`) transplant fine; a hand-baked `com.xtty.app` record is stripped — **even with xtty installed and LaunchServices-registered.** Only a record the OS itself created via the live consent flow persists, and only an **explicit** decision both persists *and* silences.
- **The record is `SigningIdentifier`-keyed, NOT cdhash-keyed:** it carries `SigningIdentifier = com.xtty.app` with an **empty `DesignatedRequirement` + `AllowEmptyDesignatedRequirement = true`** (ad-hoc-signed → no requirement to bind). So a pre-seed *would* match across ad-hoc rebuilds — the killer is **provenance-pruning at boot**, not identity drift (retires the cdhash hypothesis, 8e/T9).
- **By effect:** baked store count `1` (granted, `DenyMulticast=false`) → cold boot → `0` (pruned) → launch xtty → a **new** record appears (`DenyMulticast=true, MulticastPreferenceSet=false`, i.e. fresh/implicit) and the **modal fires** in the graphics VM.

### 8c. The SSH/CLI-child exception does **not** cover xtty (responsible-code attribution)

Hypothesis from 8a(iii): launch xtty as an SSH child → auto-allowed. Tested by `exec`-ing the binary directly over SSH so xtty's parent is `sshd-session: admin@notty` (confirmed via `ps`). **The modal still appeared.** macOS attributes the LN operation to the **app bundle's own identity** (`com.xtty.app` is its own responsible code), not the sshd ancestor — the exception covers CLI tools and their *non-bundled* children, not a GUI app bundle.
- **Corollary — this is *not* why the headless rig is quiet.** Headless is quiet because there is **no interactive WindowServer to raise the modal** (the gated op resolves to the default deny; the semantic tests take their graceful-degradation arms), and the XCUITest runner launches xtty via `testmanagerd` (attributed to the app), *not* as an SSH child. The "SSH exception explains headless" guess is refuted (8e/T10).

### 8d. The product fix, locked: `localHostNames` from `gethostname()` (matches the shell's `$HOST`)

§2b/§6 noted shells emit OSC 7 authorities from `$HOST` (= `gethostname`). The exact injected emitter is now pinned — `App/Resources/shell-integration/zsh/xtty-integration:30`:
```zsh
printf '\e]7;kitty-shell-cwd://%s%s\a' "${HOST}" "${PWD}"
```
zsh's `$HOST` is `gethostname(3)` (no reverse-DNS). The **only** consumer of the hostname is `PaneController.localHostNames` (`App/PaneController.swift:92`), built today from `ProcessInfo.hostName` (**reverse-DNS**) and fed to `OSC7.decode` for the local-vs-remote cwd classification. So the current match-set is sourced from a *different* API than what the shell emits — it works only via the short-form-fallback overlap.

Building `localHostNames` from **`gethostname()`** instead:
- matches the **exact syscall behind `$HOST`** → a guaranteed match, strictly *more correct* than the reverse-DNS source (closes the edge case where a corporate reverse-DNS FQDN diverges from the emitted `$HOST`);
- is **behavior-preserving** in the common case (both APIs return the same name);
- removes the reverse-DNS → **kills the trigger under zsh too.**

**Refinement to §6:** use **`gethostname()`**, *not* `SCDynamicStoreCopyLocalHostName()` — the latter is the Bonjour `LocalHostName`, which can differ from `$HOST`. The fix is a one-call-site swap plus one `localHostNames`-contains-`gethostname` unit test.

### 8e. New theory fates (appends §3)

| # | Theory | Fate | Killing/confirming experiment |
|---|---|---|---|
| T7 | Baking TN3179 `Allowed*` ranges into the image (vs runtime) suppresses it | ❌ refuted | baked `10/8`+`172.16/12`+`192.168/16` (⊇ the VM's `192.168.64.x`) into `xtty-test-zsh:26.5`; modal still fired in the graphics VM |
| T8 | Pre-seed a granted NE-store record at build time | ❌ refuted | baked granted store → cold boot → xtty record **pruned to 0**; only a live *explicit* click is durable+silent (8b) |
| T9 | cdhash-binding is what kills the pre-seed | ❌ retracted | record has empty `DesignatedRequirement`+`AllowEmptyDesignatedRequirement=true` → `SigningIdentifier`-keyed, not cdhash; the real killer is boot provenance-pruning (T8) |
| T10 | The SSH/CLI-child auto-grant exception covers xtty | ❌ refuted | `exec`'d over SSH (parent=`sshd-session`); modal still appeared — app bundle is its own responsible code (8c) |

### 8f. New guideline (appends §5)

**G11 — A privacy grant needs live-consent provenance; you can't fabricate one at build time.** `nesessionmanager` prunes pre-seeded third-party Local-Network records on boot; only OS-created (live-flow) records persist, and only an explicit user decision both persists *and* silences. Corollary for a build-time rig: there is **no grant to bake** — the only levers are removing the trigger (G9: the `gethostname` swap) or running headless (no WindowServer → no modal). Generalizes G9 from "the arbiter is unstable" to "the arbiter's *grant* is unforgeable."

### 8g. Re-verify by effect

- **Pre-seed refutation:** clone the zsh golden → bake a granted `com.apple.networkextension.plist` → `sudo reboot` → `plutil -p …networkextension.plist | grep -c com.xtty.app` **expect 0** (pruned); `open` xtty in graphics → **modal appears**.
- **The product fix:** apply the `gethostname()` swap → run a zsh login shell under **P1/P2** → **expect 0/0/0** (no reverse-DNS volley, no `pending`, no prompt).

### 8h. Artifacts (this session)

Graphics-VM screenshots (bake-refuted zsh modal; SSH-child modal; the Settings ▸ Privacy ▸ Local Network toggle showing xtty ON after an explicit Allow; the clean bash launch), NE-store `plutil` dumps across cold boots, and the TN3179 JSON read — under this session's `$CLAUDE_JOB_DIR/tmp/` (`zsh-manual-capture.png`, `preseed-*.png`, `ne-store-dump.txt`, `sshchild-shot.png`, `ln-now.png`, `bash-xtty-launch.png`). Session clones (stopped, disposable): `zsh-manual`, `zsh-preseed`, `zsh-sshtest`, `bash-manual`; goldens `xtty-test:26.5` + `xtty-test-zsh:26.5` untouched.

## 9. Addendum (2026-07-08) — the product `gethostname` fix measured GREEN on the zsh graphics rig; P5 is not a clean discriminator on a build-used golden; and the instrument's own privacy gate (Screen Capture), refused a pre-seed

Provenance: live by-effect capture on a fresh **graphics** clone of `xtty-test-zsh:26.5` running the `fix-osc7-hostname-reverse-dns` build (HEAD `4ebe0cb`, the `gethostname(2)` swap), via the `xtty-test-validator` agent, 2026-07-08. This executes §8g's "product fix" re-verify line. Evidence: `~/Downloads/xtty-vm-poc/artifacts/2026-07-08-fix-osc7-hostname-lncapture/`.

### 9a. The fix is GREEN by effect — §8g's product-fix line, executed

The `gethostname()` swap (`PaneController.localHostNames = LocalHost.names(from: systemHostName())`) built and launched on a fresh, uniquely-named clone (`xtty-osc7-lncap-0708`) of the **zsh** golden, 3 vCPU, **graphics** boot (live WindowServer — a modal *would* render if the trigger survived), under P1/P2:

| Probe | Pre-fix (the `add-zsh-test-image` 4.1 baseline) | Fixed build (measured) |
| --- | --- | --- |
| P2a reverse-DNS volley `client pid … (xtty)` | ~20/launch | **0** |
| P2b modal raised (`Showing local network`) | 1 | **0** |
| P2c gate `policy 'pending'` | ≥1 | **0** |
| mDNSResponder lines mentioning xtty | — | **0 of 453** |
| modal on screen | present | **absent** (clean zsh prompt) |
| first-prompt UI freeze | 38–62 s | **none** (prompt painted in ≤28 s) |

This is the **GREEN complement** of `add-zsh-test-image` task 4.1's RED baseline (same graphics zsh rig, the *unfixed* build → volley + `pending` + modal). It confirms **G9 by effect**: removing the trigger (don't resolve) is version-proof, where every grant-shaped fix was refuted.

### 9b. New fate + G3 corollary — P5 is not a clean discriminator on a golden that has built xtty

P5 (`plutil … networkextension.plist | grep -c com.xtty.app`) read **1**, not the expected 0 — but it is **benign**, not a gate event. `nesessionmanager` logged a **`UUID cache hit`** for `com.xtty.app` (the UUID *pre-existed* — baked into this golden by prior xtty build/test runs — not minted this launch), enumerated in the same bulk **default-deny** pass as pre-installed `com.tcltk.wish`/`com.apple.TV` (`Policy IDs not present` → `Deny Policy IDs added`), with **no** `local network`/consent/pending/denied-flow semantics (P2c=0 corroborates).

**G3 corollary (appends §5):** the arbiter keys on **bundle-id** and remembers — so a golden that has *ever* built or run xtty carries a `com.xtty.app` NE record into **every** clone. "Fresh clone" ≠ "NE-store-pristine." Therefore **P5 alone is not a clean LN-gate discriminator on a build-used golden**; the decisive signals are **P2a/P2b/P2c + mDNSResponder xtty-absence + the on-screen modal**. For a truly pristine P5 baseline, reset the *identity* (P3 bundle-id swap), not the machine — or use a golden never used to build xtty.

### 9c. The instrument tripped a sibling privacy gate — and we refused to pre-seed it (G9, one gate over)

During the capture, running `screencapture` **over SSH** in the guest raised the macOS 15+/26 **ScreenCaptureKit private-window-picker bypass** consent — *"com.apple.sshd-session is requesting to bypass the system private window picker and directly access your screen and audio."* Note the requester is **`com.apple.sshd-session`**, not `screencapture`: TCC walks up to the **responsible** process (the login session), the same responsible-code attribution as §8c's SSH-child.

A build-time **pre-seed** of this grant was considered — the cirruslabs base ships the `update-tcc-database.sh` TCC-write mechanism (used today for *automation*, `kTCCServiceAppleEvents`) — and **rejected**, for the same reasons this whole doc rejects LN pre-seeds:

1. **Wrong, moving client** — the responsible process is a **system daemon** (`sshd-session`), whose code identity churns across OS updates; a baked grant is cdhash-fragile.
2. **Possibly the wrong gate** — the picker-bypass is a *newer* layer than classic `kTCCServiceScreenCapture`; a Screen-Recording TCC row may not silence it on 26.x at all (unverified — would need its own by-effect spike).
3. **It argues with a churning arbiter (G9/G11)** — Apple's screen-capture consent policy shifts across point releases; a grant-shaped fix inherits that instability, exactly as the LN pre-seeds did.

And it is **unnecessary**: the load-bearing evidence (P1/P2 log counts, P5 store read) is **screen-independent** — it sits at rungs 1 & 4 of the G7 hierarchy, while the screenshot is rung 3 — and the corroborating visual is obtainable **host-side** (a Tart graphics VM is a *window on the host*; the host already has Screen Recording consent via the `xtty-dev`/`make bench` setup). **Convention: capture the graphics-arm visual host-side (`screencapture -l<windowid>`), never guest `screencapture`-over-ssh** (recorded in `packer/README.md` Runtime workflow).

### 9d. New fate (appends §3 / §8e)

| # | Theory / lever | Fate | Reason |
| --- | --- | --- | --- |
| T11 | Pre-seed the guest **Screen-Capture** TCC to silence the `sshd-session` picker-bypass prompt | ❌ **rejected by design** (not spiked) | Wrong/moving client (system daemon), maybe-wrong-gate (picker-bypass ≠ classic `kTCCServiceScreenCapture`), and G9/G11 (argues with a churning arbiter) — *and* unnecessary: the evidence is screen-independent and the visual is host-capturable. §9c. |

### 9e. New guideline (appends §5)

**G12 — Don't pre-seed a privacy grant to rescue *low-rung* evidence; verify at the highest rung and route the instrument around its own gate.** When an *instrument* (here `screencapture`) trips a privacy arbiter, the fix is not to grant it — it is to lean on the rung-1/rung-4 evidence that does not need it (G7), and to take the low-rung corroboration from a context that already has consent (the host), not to bake a fragile guest grant. Generalizes G9 from the *target's* trigger to the *instrument's* trigger.

### 9f. Re-verify by effect (appends §8g)

- **The product fix, on the zsh graphics rig (done 2026-07-08):** fresh clone of a zsh golden → graphics boot → host-build the `gethostname`-fixed app → launch under P1 → grep P2 → **measured 0/0/0** + mDNS xtty-absent + no modal + no freeze. Re-run identically to re-check. **Caveat:** on a build-used golden, P5 may read `1` benignly (§9b) — read P2a/b/c, not P5, as the discriminator.

## Sources

- Live measurements this session (primary): unified-log captures + greps on the four rigs; lldb backtrace (`DNSServiceCreateConnection` → `PaneController.swift:92/94/263/265`); NE-store `plutil` reads on all rigs; the T2 bare-metal 26.2 fresh-identity repro; the T4/T5 same-rig A/B; the `test-image-bash-shell` verification run.
- Repo ground truth: `App/PaneController.swift`, `XttyCore/Sources/XttyCore/OSC7.swift`, `openspec/specs/shell-integration/spec.md`; `packer/xtty-test.pkr.hcl` + `packer/README.md` (post-change).
- External source reads: `actions/runner-images` `images/macos/scripts/build/configure-shell.sh` (+ `configure-hostname.sh`, `configure-tccdb-macos.sh`); `cirruslabs/macos-image-templates` full-repo grep (zero LN/hostname handling; `update-tcc-database.sh` scope).
- §8 addendum (2026-07-07): live graphics-VM by-effect measurements on `xtty-test-zsh:26.5` + `xtty-test:26.5` (modal presence + NE-store `plutil` transitions across cold boots — the three-tier provenance map; the SSH-child `ps`-confirmed parentage repro); the injected-emitter call-site trace (`App/Resources/shell-integration/zsh/xtty-integration:30` → `${HOST}`); TN3179 *macOS considerations* read in full from the doc JSON (`.../tn3179-understanding-local-network-privacy.json` — the daemon/root/SSH-child auto-grant exceptions, responsible-code attribution, the `Allowed*` destination-exemption definition, the no-MDM statement).
- §9 addendum (2026-07-08): live by-effect graphics capture (`xtty-test-validator`) on a fresh `xtty-test-zsh:26.5` clone of the `fix-osc7-hostname-reverse-dns` build (HEAD `4ebe0cb`) — P1/P2 log-stream + P5 NE-store greps (**0/0/0**, mDNSResponder xtty-absent, benign `P5=1` `UUID cache hit`), the no-modal on-screen screenshot, and the `com.apple.sshd-session` ScreenCaptureKit picker-bypass consent observation. Artifacts: `~/Downloads/xtty-vm-poc/artifacts/2026-07-08-fix-osc7-hostname-lncapture/` (`ln.log`, `verdict.txt`, `lncap-shot.png`, `host-build.log`, `REVIEW.md`).
- Prior/companion docs: [`local-macos-vm-ci-reproduction.md`](local-macos-vm-ci-reproduction.md) §12–§12f; Apple TN3179 (exemption semantics; no MDM payload); eclecticlight.co LN-privacy internals (the `mdns:trust`/pathRule log vocabulary, observed on 26.2); Apple DTS forum precedent (XCTest LN change at iPadOS 26.3); Sequoia-era reports of `NSProcessInfo.hostName` triggering the prompt.
