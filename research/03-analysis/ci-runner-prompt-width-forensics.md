# CI-runner prompt-width forensics — why the find-bar wrap flake is hosted-runner-only, and the one lever that reproduces it

> **Provenance:** 2026-07-06. Produced in an `/opsx:explore` session while triaging the `build-and-test` reds of run `28801860582` (via `xtty-ci-investigator`, twice — the second pass a full `.xcresult` forensic read). Root cause verified from a shallow clone of **`actions/runner-images`** (`git clone --depth 1`, read in `$CLAUDE_JOB_DIR/tmp`) cross-checked against this machine's stock `/etc/bashrc` + `scutil`, the user-supplied live Tart-VM prompt, and the repo's own `AppUITests/`. Companion to [`github-actions-ci-cd.md`](github-actions-ci-cd.md) **§19b** (the `findbar-marker-wrap` bucket this explains) and [`local-macos-vm-ci-reproduction.md`](local-macos-vm-ci-reproduction.md) (the VM rig). **Exploration capture — no code changed.** The reproduction/prevention options in §6 are a captured decision menu, not a decision.

---

## 1. TL;DR — the settled causal chain

The find-bar XCUITest `testFindBarOpensLocatesAndDismisses` fails **only** on the GitHub-hosted runner, never on the local Tart VM or bare metal. It is **not** a product bug and **not** a shell/banner difference. It is a single environment variable — **hostname length** — inside an otherwise byte-identical prompt:

```
stock macOS /etc/bashrc  →  PS1='\h:\W \u\$ '        (identical on runner, VM, bare metal)
  \h = gethostname()   \W = basename(cwd)   \u = user
    │
    ├── GitHub runner:  \h = "sjc22-be105-…-9E54E01C3448"  (~61 chars, runtime-injected)
    │     prompt ≈ 72 cols  →  typed 13-char marker crosses col 80  →  SOFT-WRAPS
    │       grid dump joins physical rows with "\n"  →  "…runner$ A\nFTERFIND####"
    │         strict waitForContains (XttyUITests.swift:192) does haystack.contains(needle)
    │           →  the "\n"-split token never matches  →  ❌ RED  (focus DID return; layout only)
    │
    └── Tart VM:        \h = "Manageds-Virtual-Machine"      (24 chars)
          prompt ≈ 34 cols  →  marker fits well within 80  →  no wrap  →  ✅ PASS
```

- ✅ **The prompt format is stock macOS, identical everywhere.** `/etc/bashrc:6` sets `PS1='\h:\W \u\$ '`; **`grep PS1` across the entire `runner-images` repo returns zero hits** — the image sets no custom prompt. The runner and our VM run the *same* format under the *same* bash 3.2.57 login shell (`chsh -s /bin/bash`, both).
- ✅ **The only differing field is `\h` (hostname), and only its length matters.** Prompt width = `len(\h) + ~11`; the wrap threshold at ~80 cols with a 13-char marker is `len(\h) ≳ 58`.
- ❌ **The long runner hostname is NOT in the image build.** `runner-images` `configure-hostname.sh` sets `\h` to `Mac-<epoch-ms>.local` (~17 chars) via a boot LaunchDaemon — that alone would *not* wrap. The observed `sjc22-be105-…` name is **injected by GitHub's datacenter network at runtime** and appears nowhere in the source. You cannot reproduce this flake by building the runner's own image; you'd get the short name.
- ✅ **The one reproduction lever is hostname length, which we fully control** (`scutil --set` in our packer image). We don't need GitHub's exact name — any `\h ≳ 58` chars reproduces the wrap identically.
- ✅ **The find-bar failure is behaviorally correct** (established §19b + the CI investigator's rep-1 screenshot: the insertion cursor sits after `AFTERFIND####` inside the terminal pane → focus returned; the marker reached the grid, it just wrapped).

## 2. The mechanism (internals worth keeping)

### 2a. How a stock macOS bash login shell builds its prompt

```
login bash  →  /etc/profile             (login shells only)
  /etc/profile:8   [ -r /etc/bashrc ] && . /etc/bashrc
    /etc/bashrc:2  if [ -z "$PS1" ]; then
    /etc/bashrc:6      PS1='\h:\W \u\$ '     ← the ONE true source of the format
```

- `\h` = the hostname up to the first `.`, from `gethostname(3)`. **This is the entire width variable.**
- `\W` = the **basename** of `$PWD` (not `\w`, the full path). At `/` it renders `/`; at `/Users/runner` it renders `runner`. Bounded, small.
- `\u` = username (`runner` on the runner, `admin` on our Tart VM — both short, ~5–6 chars).
- xtty spawns a **login** shell, so `/etc/profile` → `/etc/bashrc` is sourced and this `PS1` applies (the observed `:/` in both prompts means cwd = filesystem root at spawn).

### 2b. Why a long `\h` breaks the strict grid assertion

The DEBUG grid dump (`App/UITestDump.swift`) joins the terminal's **physical rows** with `"\n"`. When the prompt is long enough that a typed marker crosses the right margin, the terminal **soft-wraps** it across two physical rows, so the dump contains the marker split by a `"\n"`:

```
 physical row N:    sjc22-be105-…-9E54E01C3448:/ runner$ A
 physical row N+1:  FTERFIND4215
 dump string:       "…runner$ A\nFTERFIND4215"
```

`GridDumpReader.waitForContains(needle, timeout:)` defaults to `ignoringLineWraps: false` → `haystack.contains(needle)` (`XttyUITestSupport.swift:165–168`), which a `\n`-split token can never satisfy. The **wrap-tolerant** mode strips `"\n"` before matching. The focus-typing test (`XttyUITests.swift:53–54`) already passes `ignoringLineWraps: true` for exactly this reason; the find-bar focus-restore check (`:192`) does **not** — that asymmetry is the whole bug.

### 2c. Where the runner's long hostname actually comes from

`runner-images/images/macos/scripts/build/configure-hostname.sh` installs a `RunAtLoad` LaunchDaemon that, **at every boot**, runs:

```bash
name="Mac-$(python3 -c 'from time import time; print(int(round(time()*1000)))')"
scutil --set HostName "${name}.local"     # → e.g. "Mac-1720304927123.local"  (~17-char \h)
scutil --set LocalHostName $name
scutil --set ComputerName "${name}.local"
```

So the **reproducible image** yields a ~17-char `\h` → prompt ≈ 28 cols → **no wrap**. The live fleet's `sjc22-be105-…-9E54E01C3448` (~61-char single label, no dot) overrides `gethostname()` at runtime from GitHub's datacenter network (DHCP / physical-host propagation). It is a **production-infrastructure artifact, not image config** — which is why the flake is invisible to anyone rebuilding the image and to our short-`\h` Tart VM.

## 3. Reproducible probes — exact commands, what each proves (and cannot)

| # | Probe | Proves | Cannot prove |
| --- | --- | --- | --- |
| P1 | `grep -rniE 'PS1=\|export PS1' runner-images/` → **0 hits** | The runner sets no custom prompt; the format is stock macOS. | The *value* of `\h` at runtime (not in the repo). |
| P2 | `grep -nE 'PS1' /etc/bashrc` → `:6 PS1='\h:\W \u\$ '`; `/etc/profile:8` sources bashrc | The exact stock format + that login shells load it. | That the runner's `/etc/bashrc` is unmodified (inferred from P1's zero hits + same macOS base). |
| P3 | Read `configure-shell.sh:11` → `sudo chsh -s /bin/bash $USERNAME` | Runner login shell = system bash 3.2.57 (same as our VM). | — |
| P4 | Read `configure-hostname.sh` | The image sets `\h = Mac-<epoch>.local` (~17 chars) — **short**, would not wrap. | Why the live `\h` differs (runtime infra, out of source scope). |
| P5 | Live Tart-VM prompt (user-supplied): `Manageds-Virtual-Machine:/ admin$` | Our VM `\h` = 24 chars → no wrap → find-bar passes; consistent with the 39/1/1 envelope (sole residual = paste). | Which macOS hostname key drives the VM's `\h` (see P7 / §5 spike). |
| P6 | `.xcresult` of run `28801860582` (via `xtty-ci-investigator`): 3× find-focus-restored grid dumps show `…runner$ A` / `FTERFIND####`; rep-1 screenshot = cursor after the marker inside the pane | The wrap is real and identical across reps; focus genuinely returned (behaviorally correct). | (Fully explains the red; nothing outstanding.) |
| P7 | This machine: `scutil --get HostName` → **not set**, `LocalHostName` = `Wasutans-MacBook-Pro`, yet `hostname`/`\h` → `Wasutans-MacBook-Pro.local` | On macOS `\h` can resolve from the mDNS/`LocalHostName` name even when `HostName` is unset — so the *effective* key varies. | Which key wins **inside a NAT'd Tart guest** — the open spike before trusting a long-`\h` VM. |

**Dead / inapplicable instruments:** building `runner-images` yourself to reproduce (P4 — yields the short `Mac-<epoch>` name, no wrap); reading the image source for the datacenter hostname (P1 — it isn't there). `scutil --set HostName` is *also* known-inert for the Local-Network reverse-DNS path (measured, `local-network-privacy-forensics.md` §2b) — a **different** subsystem from bash `\h`; do not conflate the two.

## 4. Retired theories — fates table

| # | Theory | Verdict | Killed by |
| --- | --- | --- | --- |
| T1 | "Copy the runner's hostname from `runner-images` to reproduce the wrap locally." | ❌ | P1/P4 — the source only ever sets `Mac-<epoch>.local`; the long `sjc22-…` name is nowhere in the repo (runtime-infra-injected). |
| T2 | "The local Tart VM already mirrors CI faithfully, so it would catch this find-bar flake." | ❌ | P5 + the measured `39/1/1` envelope — the VM's short `\h` means find-bar **passes** on the VM; the sole residual is paste. The VM reproduces the race class and shell-capability gap, **not** prompt width. |
| T3 | "It's a shell or zsh-deprecation-banner difference between the VM and the runner." | ❌ | P2/P3 — both are bash 3.2.57 with the identical stock `PS1='\h:\W \u\$ '`; the banner was already retired (`silence-bash-deprecation`). The only differing field is `\h` length. |
| T4 | "Lengthening the VM hostname will resurrect the Local-Network privacy modal." | ❌ | The modal is `ProcessInfo.hostName` → reverse-DNS, **OSC-7/zsh-gated and dead under the image's bash shell**; `scutil --set HostName` measured inert for it (`local-network-privacy-forensics.md`). Hostname length is decoupled from that gate under bash. |
| T5 | "The find-bar red is a focus-restoration (product) bug." | ❌ | P6 — rep-1 screenshot shows the cursor after the marker **inside the terminal pane**; the marker reached the grid, it just wrapped. Behaviorally correct (§19b). |
| T6 | "Bash `\h` in the Tart guest will reflect `scutil --set HostName` (so a long-`\h` VM is trivial)." | ❓ | **Unverified** — P7 shows on bare metal `\h` tracked `LocalHostName`+`.local` while `HostName` was unset; the effective key varies. This is the one open spike (§5). `runner-images` sets all three keys defensively for this reason. |

## 5. Re-verify by effect (never a read-back)

To re-confirm the headline claim, **change the width and observe the wrap** — do not grep `PS1`:

1. In a Tart guest, set a long single-label hostname on all three keys (mirror `runner-images`), ≥ ~58 chars:
   `sudo scutil --set HostName / --set LocalHostName / --set ComputerName xtty-ci-parity-runner-sjc22-be105-9E54E01C3448`
2. Open a **fresh bash login shell** and type a ≥13-char token at the `:/` prompt.
3. Read the grid dump: the token must appear **split across two physical rows** (`…$ A` / `FTERFIND####`), and `testFindBarOpensLocatesAndDismisses` must go **red under the strict matcher** at `:192`.
4. Conversely, applying `ignoringLineWraps: true` at `:192` (as at `:53`) must turn it **green** while the token still wraps — proving the fix is layout-tolerance, not a behavior change.

If step 3 does **not** wrap, resolve the P7 spike first: the guest's `\h` is reading a different hostname key than the one you set (or the guest's window is wider than 80 cols — read back the dump's row width).

## 6. Reproduction / prevention options (captured menu — NOT a decision)

| Option | What it is | Cost / caveat |
| --- | --- | --- |
| **A. Wrap-tolerant fix** (`:192` → `ignoringLineWraps: true`) | The actual **prevention** — mirrors `:53`; environment-independent (any `\h` length). | The real fix. Keeps the test's teeth: a focus failure still routes the marker to the search field → absent from the grid → still fails. Needs the §19b/`packer/README.md` reverse-duty tracker updates. |
| **B. Narrow-column guard test** | A dedicated test that shrinks the terminal to force *any* prompt to wrap, asserts the strict matcher reds pre-fix / greens post-fix. | Deterministic repro in the fast `make test` tier, on bare metal — **no VM, no envelope churn.** Open spike: pin an exact column count in XCUITest (font-metric dependent). |
| **C. Long-`\h` VM fidelity** | Give the Tart image a ~60-char hostname so it faithfully reproduces the runner's prompt width (and *all* prompt-width flakes, not just find-bar). | Makes the VM an honest CI mirror, but **re-baselines the acceptance envelope**: a long `\h` shifts every prompt-typing test's failure *signature* (e.g. paste flips its failing line `:87`→`:84` like the runner; find-bar newly reds). Plus the P7 gethostname spike. This *is* the "harness-truthing successor" §19b names. |

Making the VM reproduce the red (B or C) does **not** fix anything by itself — it only surfaces the failure pre-push; option A is still required to go green.

**Addendum (2026-07-07) — the options crystallized into a red→green change pair.** Owner chose **A + B + C**, split across two proposed OpenSpec changes applied in a deliberate order:

1. **`add-vm-prompt-width-parity`** (option **C**) — applied **first**. With the wide prompt in place but the fix not yet applied, `testFindBarOpensLocatesAndDismisses` **reds in-guest** — reproducing the CI flake locally. That red *is* C's acceptance signal (the VM now mirrors the runner's prompt width).
2. **`harden-findbar-wrap-assertion`** (options **A + B**) — applied **second**, on the same rebuilt image (no rebuild; source isn't baked in). The wrap-tolerant matcher **greens** find-bar in-guest → the fix is proven **red→green** against the live repro; B's deterministic guard locks the class in `make test`.

So the earlier framing "A vs C" became "C then A" — reproduce, then fix — turning the two changes into a self-verifying pair. The final documented VM envelope (find-bar green) is set after step 2; the interim red is transient, not a standing residual. B's column-pinning spike is **dissolved** by the guaranteed-wrap-marker design (`harden-findbar-wrap-assertion` design D2).

## 7. Reusable guideline (generalizes to any hosted-CI-only red)

1. **A hosted-CI-only failure with no local/VM repro is often a single environment *variable*, not a product bug or "flaky runner."** Identify the one differing field before proposing a fix — here, `\h` length inside a byte-identical prompt.
2. **Distinguish image-derivable config from runtime-infra-injected values.** `grep` the runner's own image source: if the triggering value isn't there (the long hostname), it's injected by the fleet at runtime and cannot be reproduced by rebuilding the image — only its *shape* (length) can, and you control that.
3. **A local rig only reproduces the failure classes whose triggers it actually recreates.** Enumerate them explicitly (xtty's Tart VM: race class ✓, shell capability ✓, **prompt width ✗**) rather than assuming "the VM mirrors CI." A green on the rig for an un-recreated trigger is *false confidence*.
4. **Prefer making the test environment-robust (A) over reproducing the hostile environment (C)** when the assertion couples to incidental layout; reserve environment-reproduction for when you specifically want the rig to be a faithful mirror — and price the envelope re-baseline it forces.

## 8. Evidence artifacts

- `runner-images` shallow clone (read this session): `images/macos/scripts/build/configure-hostname.sh`, `configure-shell.sh`, `templates/macOS-26.arm64.anka.pkr.hcl` (the `vm_username` sensitive var); repo-wide `PS1` grep = 0 hits.
- This machine (P2/P7): `/etc/bashrc:6`, `/etc/profile:8`, `hostname`, `scutil --get {HostName,LocalHostName,ComputerName}`.
- Live Tart-VM prompt (P5, user-supplied): `Manageds-Virtual-Machine:/ admin$`.
- Run `28801860582` `.xcresult` (P6, via `xtty-ci-investigator`): `find-focus-restored-grid` dumps ×3 + the rep-1 final-state screenshot; consolidated in `github-actions-ci-cd.md` §19b.
- Repo source: `AppUITests/XttyUITests.swift` (`:53–54`, `:152–196`), `AppUITests/XttyUITestSupport.swift` (`:148–168`), `App/UITestDump.swift`; `packer/xtty-test.pkr.hcl` (`:113–136` the bash-shell provisioner), `packer/README.md` Acceptance (`39/1/1`).

## Sources

- **`actions/runner-images`** (github.com/actions/runner-images, `--depth 1`, 2026-07-06): `images/macos/scripts/build/{configure-hostname.sh, configure-shell.sh}`, `images/macos/templates/*.anka.pkr.hcl`.
- **Stock macOS** (this host, macOS 26): `/etc/bashrc`, `/etc/profile`, `scutil`, `hostname`, bash `PROMPT` escape semantics (`\h`, `\W`, `\u`).
- **xtty repo:** `AppUITests/XttyUITests.swift`, `AppUITests/XttyUITestSupport.swift`, `App/UITestDump.swift`, `packer/xtty-test.pkr.hcl`, `packer/README.md`.
- **Companion research:** [`github-actions-ci-cd.md`](github-actions-ci-cd.md) §19 (the CI expected-difference matrix), [`local-macos-vm-ci-reproduction.md`](local-macos-vm-ci-reproduction.md) (the VM rig + provisioning), [`local-network-privacy-forensics.md`](local-network-privacy-forensics.md) (the `scutil --set HostName`-inert reverse-DNS path — a distinct subsystem from bash `\h`).
