# Local install & stable-build workflow: how terminals do `make install`

> **Provenance:** 2026-07-08. Produced by a 12-agent research workflow (10 parallel per-terminal comparator readers over `research/01-terminals/*` + shallow clones of the 8 OSS terminals to `/tmp/xtty-term-research/<name>`, a synthesis pass, and an adversarial completeness critic; ~974k subagent tokens, 0 agent errors) **plus 3 local verification spikes on the dev machine** (Apple Silicon, Xcode 26.6, the committed `project.yml`). External-source-over-memory per the project methodology. Critic verdict: **usable-with-caveats** (every correction folded into §7 Fates). **Scope: the `$0` LOCAL install** (`make install` → `/Applications`) — the complement of, not a substitute for, the `$99` download-channel work in [`distribution-signing-research.md`](distribution-signing-research.md). This doc feeds a **future `add-install-workflow` change** (not yet proposed).

---

## 1. TL;DR

- **Only two OSS comparators ship a first-class copy-to-`/Applications` target** — **iTerm2** (`make install`) and **rio** (`make install-macos`). Every other terminal (Ghostty, kitty, Alacritty, wezterm, Hyper, Wave) stops at an artifact in a build/`dist`/`zig-out` dir and makes the user drag it. So a real `make install` is a genuine improvement over the field, not table stakes. ✅
- **The winning shape for xtty = iTerm2's**, with **Ghostty's git-derived versioning**: build `-configuration Release` → back up the old bundle → `ditto` a self-contained copy into `INSTALL_DIR ?= /Applications`, reusing the existing `SIGN_FLAGS`/`XTTY_SIGN_IDENTITY` machinery. No DMG, no notarization, no auto-updater. ✅
- **A local build is `$0` and launches clean** — verified: xtty's own Debug **and** Release builds carry **no `com.apple.quarantine`** xattr, so an ad-hoc (or `xtty-dev`-signed) `.app` copied to `/Applications` passes Gatekeeper with zero prompts. Quarantine attaches only to *downloaded* files. ✅
- **Three unknowns the critic flagged were spiked locally and all resolved green:** XcodeGen's default `Release` config genuinely optimizes (`-O` + wholemodule); SwiftTerm is statically linked (no embedded framework to re-sign, `disable-library-validation` N/A); and a command-line `MARKETING_VERSION=…` override **reaches the synthesized `Info.plist`** under `GENERATE_INFOPLIST_FILE=YES` (no PlistBuddy post-step). ✅
- **The first version-stamping draft had a real bug** (critic-caught): `git describe --tags --always --dirty || echo 0.0.1` never fires its floor (`--always` succeeds with a bare hash when there are 0 tags) and yields a non-numeric `CFBundleShortVersionString`. Corrected: keep the two Apple-spec plist fields numeric, put the describe stamp in a separate field, and cut a `v0.0.1` tag to anchor it. ❌→✅

---

## 2. The question & scope

The user wants to **daily-drive a stable, versioned build** of xtty from `/Applications`, at `$0`, without the Apple Developer Program. Today `make run` = `xcodebuild build` (**Debug**) then `open build/Build/Products/Debug/xtty.app` — an unoptimized build launched **in place** from the volatile `build/` dir (wiped by `make clean`, not in Spotlight/Dock, ad-hoc identity churns every rebuild). The gap is a `make install` that produces an **optimized Release** build, **stamps a stable version**, and lands a **self-contained copy** in `/Applications`.

**Out of scope (covered elsewhere):** Developer ID + Hardened Runtime + notarization + Homebrew cask — all *download-channel* concerns, `$99`-gated, deferred → [`distribution-signing-research.md`](distribution-signing-research.md) (§9 Homebrew, §10 `$0`). The load-bearing distinction this doc leans on — **local build ⇒ no quarantine ⇒ no Gatekeeper gate** — is that doc's §10 headline, re-verified here on the Release config.

---

## 3. How the field does local install (comparison)

| Terminal | Local-install target | Release build | Version stamping | Install location | Local signing | Update story |
|---|---|---|---|---|---|---|
| **iTerm2** (Makefile + xcodebuild — the model) | ✅ **`make install`** (builds `Deployment` → `cp -R` to `/Applications`, backs up old → `.bak`) | `Deployment` config: `-O`, GCC O3, dead-strip (asserts deliberately ON) | committed `version.txt` `3.7.%(extra)s` + build-time **date suffix** via PlistBuddy; **no tags** | `/Applications` (`APPS` var, overridable), **copy** | **fully UNSIGNED** by default (`CODE_SIGNING_ALLOWED=NO`); `SIGNED=1` opts into Dev ID | rebuild-reinstall (`make install` + `make restart`); Sparkle release-only |
| **Ghostty** (Swift/AppKit + Xcode — closest analog) | ❌ none first-class; `zig build -Doptimize=ReleaseFast` → `zig-out/`, user `cp -R` | `ReleaseLocal` Xcode config: `-O`, wholemodule, dead-strip, NS_ASSERTIONS off — **true optimized** | **git-derived, compiled in** (`-Dversion-string=<tag>`; else `X.Y.Z-branch+hash`; else `-dev+0000000`); plist MARKETING_VERSION a stale placeholder | `zig-out/` copy locally; `/Applications` via DMG/cask | ad-hoc `-`, HR **ON** + `disable-library-validation` (embedded frameworks) | Sparkle (official only); local = rebuild + re-copy |
| **rio** (Cargo + Makefile) | ✅ **`make install-macos`** (universal build → assemble → ad-hoc sign → `mv` to `/Applications`) | `cargo --release` (strip, lto, panic=abort); **forces** universal via lipo | Cargo literal in binary; ⚠️ plist ships literal `{{.Version}}` locally (goreleaser fills only at release) | `/Applications`, `mv` (rm -rf old first) | ad-hoc `--force --deep --sign -` (deprecated `--deep`); identity churns each build | rebuild + `make install-macos` |
| **kitty** (Makefile → setup.py) | ❌ `make app` → `kitty.app` in repo root, manual copy | `-O3` default (`--debug` opts out) | hardcoded `constants.py` + `git rev-parse HEAD` build stamp | nowhere auto; manual copy | unsigned / linker-ad-hoc; self-sign optional | rebuild + re-copy; update *checker* (notify-only) |
| **Alacritty** (Cargo + thin Makefile) | ❌ two-step `make app` + manual `cp -r` (`make install` is a **misnomer** — mounts a DMG) | `cargo --release` (lto thin); debug never bundled | ⚠️ two **drifting** sources (Cargo literal + git short-hash); plist hardcoded stale | `/Applications`, manual copy | ad-hoc `--force --deep --sign -`; cdhash churns → TCC re-prompts | manual rebuild-reinstall; no Sparkle |
| **wezterm** (Cargo + `ci/deploy.sh`) | ❌ `ci/deploy.sh` writes a `.app` zip to CWD, manual drag | `cargo --release` (opt-level 3) | commit-date + short-hash (`git show %cd-%h`), **zero tags needed**; plist stale `0.1.0` | `/Applications`, manual copy | none (codesign gated on `$MACOS_TEAM_ID`); linker ad-hoc only | manual rebuild; brew for real |
| **Hyper** (Electron/electron-builder) | ❌ `pnpm run dist` → `dist/` DMG+zip, manual drag | production minify; only `dist` packages | static `package.json` → Info.plist; git-describe dev-only | `/Applications`, manual copy | ad-hoc/unsigned (`CSC_IDENTITY_AUTO_DISCOVERY=false`) | Squirrel.Mac (official); local rebuild + re-drag |
| **Wave** (Electron/go-task) | ❌ `task package` → `make/` DMG+zip, manual drag | electron-vite production; clean full rebuild | static `package.json` (version.cjs) via ldflags | `/Applications`, manual drag | ad-hoc (electron-builder default) | electron-updater S3 (official); local rebuild + re-drag |
| **Warp** (closed) | ❌ (no build-from-source) | optimized release only, internal CI | date/time + channel + counter `0.YYYY.MM.DD.HH.MM.stable_NN` | `/Applications`, **copy** (DMG/cask) | N/A — Dev ID **+ notarized** (bundle is *downloaded*) | in-app auto-updater |
| **Apple Terminal** (closed) | ❌ (OS-delivered) | single Apple-signed platform binary | hardcoded `2.15`/build `466`, coupled to OS train | `/System/Applications/Utilities` on the **sealed SSV** (unwritable) | Apple platform-binary (unreachable) | macOS Software Update |

**Read:** the Rust/Electron terminals hand-stitch a committed `.app` skeleton and re-sign with the deprecated `codesign --deep`; the two Xcode-built comparators (iTerm2, Ghostty) let the toolchain emit a fully-formed signed `.app` — which is exactly xtty's situation. So the mechanics transfer cleanest from **iTerm2** (the install target) and **Ghostty** (the versioning).

---

## 4. Recommended `make install` shape for xtty (mechanism)

Proposal-ready, mechanism-level (not final code):

1. **Close the `-configuration Release` gap** — the core fix. `make install` builds `xcodebuild … -configuration Release … $(SIGN_FLAGS) MARKETING_VERSION=$(VERSION) CURRENT_PROJECT_VERSION=$(BUILD)`. `make run`/`make build`/`make bench` stay on Debug. Introduce `RELEASE_APP := $(DERIVED)/Build/Products/Release/xtty.app`.
2. **No assembly, no re-sign** — xcodebuild emits a fully-formed, already-signed `.app` (Info.plist synthesized from `project.yml` via `GENERATE_INFOPLIST_FILE`, identity from `SIGN_FLAGS`). Unlike Alacritty/rio/wezterm there is **no bundle-stitching and no manual `codesign`** (and never the deprecated `--deep`).
3. **Install = backup + copy** (iTerm2 shape): `mv` any existing `$(INSTALL_DIR)/xtty.app` → `xtty.app.bak` (cheap rollback), then **`ditto "$(RELEASE_APP)" "$(INSTALL_DIR)/xtty.app"`** — a self-contained **copy**, never a symlink into volatile `build/` (kitty's source-bound bundle is the cautionary tale; copying is what lets the install survive `make clean`). `INSTALL_DIR ?= /Applications`, overridable (`make install INSTALL_DIR=~/Applications`).
4. **Reuse `SIGN_FLAGS` verbatim** — already parameterized by `XTTY_SIGN_IDENTITY`. `make install` = ad-hoc (creds-free for anyone); `XTTY_SIGN_IDENTITY=xtty-dev make install` = stable identity so **TCC grants persist across reinstalls**. No new signing machinery.
5. **Version stamped in THIS target** (see §5) via the CLI build-setting overrides on the same xcodebuild call — verified to reach the plist (§6, Probe 3).
6. **`make restart` helper** (iTerm2) — kill the running instance + `open $(INSTALL_DIR)/xtty.app`, for a one-command reinstall loop.
7. **No `make dmg`, no notarization, no auto-updater** — all download-channel machinery; dead weight for a `$0` local install (a locally-built copy is never quarantined). Update = re-run `make install`. Defer DMG/notarization to the `$99` `add-distribution-signing` if a public channel is ever opened.

New Makefile surface: `.PHONY: install restart`; vars `INSTALL_DIR`, `RELEASE_CONFIG := Release`, `RELEASE_APP`, `VERSION`, `BUILD`.

---

## 5. Version strategy for a "stable build" (corrected)

**What "stable build version" should MEAN for a solo daily-driver:** one authoritative, human-visible version that advances monotonically and always ties back to a known commit — so "which build am I running, and from what code?" has an answer. There must be exactly **one** source feeding both the plist and any in-app surface (the plist-vs-binary drift Alacritty and wezterm both ship is the thing to avoid).

**Recommendation — git-tag-anchored, numeric plist, with a manifest floor:**
1. **Cut the first annotated tag `v0.0.1` now** (0 tags today). Both Ghostty and Alacritty note the first tag dissolves the "0 tags → garbage version" problem.
2. **`CFBundleShortVersionString` (`MARKETING_VERSION`) stays numeric** — the latest tag minus `v` (`git describe --tags --abbrev=0`), falling back to `project.yml`'s committed `0.0.1` when git/tags are absent.
3. **`CFBundleVersion` (`CURRENT_PROJECT_VERSION`) = monotonic** `git rev-list --count HEAD` (Ghostty's Sparkle-build-number scheme).
4. **The full `git describe` stamp** (`0.0.1-3-gabc123-dirty`) goes in a **separate** field (a custom Info.plist key and/or an About panel) — **never** in the two Apple-spec fields (Apple requires ≤3 dotted integers).
5. **`project.yml` `MARKETING_VERSION "0.0.1"` stays the committed floor** (iTerm2's `version.txt` / kitty's `constants.py` / Hyper's `package.json` all keep a manifest string authoritative).

**Stamp seam (verified):** command-line xcodebuild build-setting overrides on the `make install` call — no `project.pbxproj` edit (it's gitignored), single build-time value, and **proven to reach the synthesized plist** (§6). Preferred over PlistBuddy-post-build or feeding xcodegen at generate time (fewer moving parts).

---

## 6. Verified probes (re-runnable)

All three run against the committed `project.yml`/generated `xtty.xcodeproj` on the dev machine.

| # | Probe (exact command) | Result | Proves | Cannot prove |
|---|---|---|---|---|
| **1 — Release optimizes** | `awk '/Release \*\/ = {/{f=1} …' xtty.xcodeproj/project.pbxproj` | Release: `SWIFT_OPTIMIZATION_LEVEL=-O`, `SWIFT_COMPILATION_MODE=wholemodule`, `ENABLE_NS_ASSERTIONS=NO`; Debug: `-Onone` | XcodeGen's default `Release` config is genuinely optimized → `-configuration Release` ships a real optimized build, **no `configs:` pin needed** in `project.yml` | that runtime latency measurably improves (not benchmarked — the compile flags are the accepted proxy) |
| **2 — SwiftTerm static** | `ls "$APP/Contents/Frameworks"` (none) + `otool -L "$APP/Contents/MacOS/xtty" \| grep -i swiftterm` (none) | no `Frameworks/`, no SwiftTerm dylib | SwiftTerm is **statically linked** → no embedded dynamic framework to re-sign; Ghostty's `disable-library-validation` is **N/A** to xtty | behavior if Hardened Runtime were turned on (moot — HR is OFF) |
| **3 — Version override → plist** | `xcodebuild -project xtty.xcodeproj -scheme xtty -configuration Release -derivedDataPath build build MARKETING_VERSION=9.9.9 CURRENT_PROJECT_VERSION=4242` then `PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist"` | `9.9.9` / `4242`; `Signature=adhoc`, `Identifier=com.xtty.app` | the CLI build-setting override **reaches the synthesized `Info.plist`** under `GENERATE_INFOPLIST_FILE=YES` — **no PlistBuddy post-step** | — |
| **bonus — no quarantine** | `xattr -l build/Build/Products/{Debug,Release}/xtty.app \| grep -i quarantine` | nothing (only `com.apple.provenance`) | a **locally-compiled** app is never quarantined → ad-hoc/`xtty-dev` Release launches clean from `/Applications` at `$0` | UX of a *downloaded* artifact (that's the `$99` doc's domain) |

---

## 7. Retired-theory / correction fates

| Theory / draft | Fate | Killed by |
|---|---|---|
| `git describe --tags --always --dirty \|\| echo 0.0.1` as the version | ❌ | `--always` **succeeds** with a bare commit hash when there are 0 tags, so the `\|\| echo 0.0.1` floor never fires → non-numeric `CFBundleShortVersionString`. The only real guard is cutting the tag + dropping `--always` (use `--abbrev=0` for the numeric field). (critic Correction 1) |
| git-describe string straight into `CFBundleShortVersionString` | ❌ | Apple spec: ≤3 period-separated integers; `0.0.1-3-gabc123` / `-dirty` are off-spec. Keep the plist numeric; put the describe stamp in a separate field. (Correction 2) |
| Version override needs a PlistBuddy post-build step | ❌ | Probe 3: the xcodebuild CLI override reaches the synthesized plist directly. |
| Ghostty's `disable-library-validation` entitlement needed | ❌ (N/A) | Probe 2: SwiftTerm statically linked + HR OFF → no embedded dynamic framework to validate. |
| `ditto` ≡ `cp -R` | ❌ (imprecise) | `cp -R` drops xattrs/ACLs/resource-fork/hardlink fidelity; prefer `ditto`. Both usually work for a self-contained `.app` but they are not equivalent. (Correction 4) |
| "copying into `/Applications` prompts for admin" | ❌ | An **admin** user's CLI `ditto`/`cp` into `/Applications` does **not** prompt (the dir is group-admin-writable) — it just succeeds; a **non-admin** gets a hard `EACCES`, not a prompt. (Correction 3) |
| `make dmg` / notarization in the local install | ❌ | Local builds are never quarantined (bonus probe) → no Gatekeeper gate to satisfy; DMG/notarization are download-channel-only (`$99`, deferred). |
| Auto-updater (Sparkle/Squirrel/electron-updater) for local install | ❌ | All require Developer ID + a notarized artifact + a hosted signed feed; dead weight for a `$0` ad-hoc build. Update = re-run `make install`. |
| Force a universal (lipo) build for a personal install | ❌ | rio's `install-macos` doubles build time for no local benefit; build the single native arch, reserve universal for a future release-only target. |

---

## 8. Re-verify by effect

- **Version seam still works:** `xcodebuild … -configuration Release … MARKETING_VERSION=X CURRENT_PROJECT_VERSION=Y build`, then `PlistBuddy -c 'Print :CFBundleShortVersionString' <app>/Contents/Info.plist` returns `X`. *(Not a read of `project.yml` — the point is the override reaching the synthesized plist.)*
- **`$0` clean launch:** `xattr -l /Applications/xtty.app | grep quarantine` prints nothing, and double-clicking the installed app raises no Gatekeeper dialog.
- **Release is actually optimized:** the installed build's `Release` config shows `SWIFT_OPTIMIZATION_LEVEL = -O` (not `-Onone`).

---

## 9. Reusable guideline

**G14 — A `$0` local install target (build → copy to `/Applications`) needs no signing ceremony beyond what the toolchain already emits.** Locally-compiled bundles never receive `com.apple.quarantine`, so ad-hoc — or a stable self-signed identity (`xtty-dev`) when TCC-grant persistence matters — launches clean. Reserve DMG / notarization / Homebrew for a **downloaded** artifact; never put them in a local install. Build the optimized Release config (not Debug), stamp the version **in the local build path** (a CLI build-setting override, verified to reach a `GENERATE_INFOPLIST_FILE` plist), keep the two Apple-spec plist fields **numeric**, and copy (`ditto`, not symlink) a self-contained bundle so it survives `make clean`.

---

## 10. Open questions (propose-time)

Two already **decided** in the explore session: **same bundle id** `com.xtty.app` for the stable build (one TCC/config set; dev + stable share Launch Services identity), and **verify-the-seam-first** (done — §6 Probe 3). Remaining for the proposal:

1. **OpenSpec mapping** — home is `build-workflow` (new `make install`/`make restart` requirements + version-stamping). If a user-visible **About panel** is added, it pulls in a `verification-harness` delta + harness task (the custom-drawn view exposes nothing to a11y; a new observable needs a DEBUG dump field + e2e scenario).
2. **Acceptance plan** — criteria proving the installed app is (a) Release-optimized, (b) stamped with the intended version, (c) launches unquarantined from `/Applications`. Verifying the stamped version at runtime is not free (a11y-opaque view) — a plist read or a harness observation.
3. **Tag/version-bump workflow** — who cuts `v0.0.1` and subsequent tags on the solo push-to-main flow; whether a CHANGELOG rides along.
4. **CLI shim?** — only if xtty ever ships a `xtty` CLI (wezterm/Hyper symlink an inner executable into `PATH`). Not today.
5. **`INSTALL_DIR` default** — `/Applications` (the convention; admin-writable, no prompt for an admin user) with `~/Applications` documented as the no-privilege escape hatch.

---

## 11. Antipatterns (do NOT copy)

The download-quarantine-vs-local-build distinction (Antipattern 1) is the spine — Alacritty's DMG Gatekeeper prompt and Warp's mandatory notarization are **download** problems, irrelevant to a local `make install`. Also: don't defer version stamping to a release-only path (rio ships literal `{{.Version}}` locally); don't let the plist drift from the reported version (Alacritty/wezterm); don't drive the version from `git describe --tags` with 0 tags and no fallback (Hyper's warning); don't symlink a source-bound bundle (kitty breaks on `make clean`); don't keep daily-driving the Debug in-place build; don't hand-roll `codesign --deep`; don't force a universal build; don't copy Ghostty's `disable-library-validation`; don't rely on ad-hoc-only for a daily-driver (cdhash churns → TCC re-prompts — use `xtty-dev`); don't couple `make install` to Homebrew/goreleaser/appcast machinery; don't stop at a `dist/` artifact and leave the `/Applications` move manual; don't hardcode `/Applications` with no override, and never target the SSV-sealed `/System/…`.

---

## Sources

- **xtty repo:** `Makefile`, `project.yml`, `scripts/create-signing-cert.sh`, `App/xtty.entitlements`, the generated `xtty.xcodeproj/project.pbxproj`; the 3 local probes (§6) run on this machine (Xcode 26.6, Apple Silicon).
- **Cloned to `/tmp/xtty-term-research/<name>` (shallow):** Ghostty (`ghostty-org/ghostty` — `build.zig`, `src/build/GhosttyXcodebuild.zig`, `macos/`, `.github/workflows/release-tag.yml`), iTerm2 (`gnachman/iTerm2` — `Makefile`, `version.txt`), Alacritty (`alacritty/alacritty` — `Makefile`, `Cargo.toml`), kitty (`kovidgoyal/kitty` — `Makefile`, `setup.py`), wezterm (`wezterm/wezterm` — `ci/deploy.sh`), rio (`raphamorim/rio` — `Makefile`), Hyper (`vercel/hyper`), Wave (`wavetermdev/waveterm`).
- **Closed (research doc + public facts):** Warp, Apple Terminal.
- **xtty research:** [`distribution-signing-research.md`](distribution-signing-research.md) (the `$99` download channel — §9 Homebrew, §10 `$0`, the quarantine mechanism), `research/01-terminals/*.md` (per-terminal deep-dives).
- **Workflow evidence:** run `wf_e6a35c9f-517`, transcript + `journal.jsonl` under `…/subagents/workflows/wf_e6a35c9f-517/` (one `result` line per agent).
