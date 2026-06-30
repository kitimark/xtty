# Distributing xtty: Developer ID + Hardened Runtime + Notarization

> **Provenance:** 2026-06-30, produced by a multi-agent research workflow (7 agents, ~429k tokens) — 5 parallel facet readers (current repo posture · the canonical Apple pipeline · the Hardened-Runtime entitlement set for a terminal · an OSS-terminal comparison · per-surface impact on xtty), a synthesis pass, and a completeness critic. External sources favored over memory per the project methodology (WebSearch of Apple docs + shallow clones of Ghostty/WezTerm/kitty/Alacritty/iTerm2 configs to `/tmp`). Critic verdict: **usable-with-caveats** (caveats folded into §8).

**Decision status:** the deferred **P7 distribution slice** (Hardened Runtime + Developer ID + notarization). **Technically green — gated only on a procurement decision** (a paid Apple Developer Program membership, ~$99/yr). No OpenSpec change tracks it yet; this doc is the explore-phase finding, not a commitment to build.

---

## 1. TL;DR

- **Distribution is feasible now with essentially zero source changes.** Five of six existing surfaces are SAFE as-is; the only "needs-change" is build config (a Release archive + `ENABLE_HARDENED_RUNTIME=YES` + a real Developer ID identity). ✅
- **The single biggest blocker is procurement, not engineering.** The dev machine has **0 valid codesigning identities** and no paid account — distribution needs a **paid Apple Developer Program membership (~$99/yr)** + a **Developer ID Application certificate**. ✅
- **What the user must personally decide/buy** (non-automatable, one-time): enroll + pay; as Account Holder create + safeguard the Developer ID Application cert and its private key; mint an App Store Connect API key (`.p8`, downloadable once). Everything else (sign → notarize → staple → package → verify) is fully scriptable. ✅
- **The crux is resolved plainly: Hardened Runtime does NOT break exec of unsigned user binaries or ZDOTDIR injection.** HR constrains only xtty's own process image; child processes (login shell, `$EDITOR`, any CLI) get an independent AMFI signature evaluation. Proof: iTerm2, Ghostty, and WezTerm all run notarized under HR and exec arbitrary unsigned code daily with no `allow-unsigned-executable-memory`. ✅
- **A real Developer ID subsumes the `add-local-signing-identity` (`xtty-dev`) TCC workaround** for any *signed* build — but only partially in practice, because the Screen-Recording-dependent latency probe is DEBUG/`make bench`-only and never ships, so `xtty-dev` retains value for unsigned ad-hoc/CI iteration. ❓ (rests on Apple-forum reasoning, not a direct test — see §8.)

---

## 2. Current posture (and what's deferred, verbatim)

What exists today (committed default, both app and UI-test targets):

- **App Sandbox OFF** + **ad-hoc "Sign to Run Locally"**: `CODE_SIGN_IDENTITY="-"`, `CODE_SIGN_STYLE=Manual`, `DEVELOPMENT_TEAM=""` (empty), `ENABLE_HARDENED_RUNTIME=NO` (`project.yml`). ✅
- **The entire entitlement set is one key**: `com.apple.security.app-sandbox = false`, nothing else (`App/xtty.entitlements`). Sandbox-off is a **permanent design choice** (a sandboxed terminal can't spawn shells / read user files), which also **permanently rules out the Mac App Store** — by design, not deferred. ✅
- The optional **`xtty-dev`** identity (`scripts/create-signing-cert.sh`, opt-in via `XTTY_SIGN_IDENTITY`) is a self-signed, untrusted, **local-dev-only** cert that buys exactly one thing: **TCC-grant persistence** (Screen Recording for `make bench`) across rebuilds, because a stable cert gives a constant cert-based designated requirement instead of the ever-changing ad-hoc cdhash. Unset = ad-hoc default unchanged. ✅
  - (Minor mechanism note from the facets: `xtty-dev` imports a combined key+cert PEM, not a `.p12`, because macOS `security` can't verify a LibreSSL/OpenSSL-3 `.p12` MAC.)

Explicitly deferred (verbatim across `add-local-signing-identity`'s proposal/design/spec): *"Developer ID, Hardened Runtime, and notarization remain out of scope"* / *"still deferred"* / *"deferred P7-distribution work"* / *"local signing only"*. Named as outstanding in ≥6 repo surfaces (AGENTS.md, `project.yml`, `App/xtty.entitlements`, `p7-measurement-methodology.md`). No OpenSpec change tracks distribution yet. ✅

---

## 3. The pipeline

The 2026 canonical chain (notarytool era — **`altool` is dead**, rejected since 2023-11-01 per TN3147). ✅

**One-time, HUMAN-only** (identity/account decisions — non-automatable):

0. Enroll in the Apple Developer Program + pay the annual fee (~$99/yr — **verify current price/terms before paying**, see §8).
1. As **Account Holder**, create a **Developer ID Application** cert (Xcode ▸ Settings ▸ Accounts ▸ Manage Certificates ▸ +, or the portal via a Keychain-Access CSR). The **private key stays in your login keychain and is never uploaded**. Limit 5 per team. ✅
2. Mint an **App Store Connect API key** (`.p8`, at appstoreconnect.apple.com/access/api) — **downloadable only once** — or use an app-specific password.

**Repeatable, fully AUTOMATABLE** (CI / a `make dist` target):

3. **Import cert** into a throwaway keychain (CI): `security import cert.p12 -T /usr/bin/codesign` + `security set-key-partition-list`.
4. **Sign inside-out** with Hardened Runtime (`ENABLE_HARDENED_RUNTIME=YES` ≡ `--options runtime`). `--timestamp` is **mandatory** (needs network at sign time); **avoid `--deep` for signing** (sign nested artifacts explicitly, bundle last):
   ```
   codesign -f -o runtime --timestamp  <nested frameworks/dylibs/helpers first>
   codesign -f -o runtime --timestamp --entitlements App/xtty.entitlements \
     -s "Developer ID Application: NAME (TEAMID)" xtty.app   # bundle LAST
   ```
   *(For xtty, SwiftTerm is statically linked → likely no separate nested framework; only the auto-signed `SwiftTerm_SwiftTerm.bundle` metallib resource — see §6. Verify once, §8.)*
5. **Notarize, blocking**:
   ```
   xcrun notarytool store-credentials "PROFILE" --key AuthKey_X.p8 --key-id X --issuer <uuid>
   xcrun notarytool submit xtty.dmg --keychain-profile "PROFILE" --wait
   ```
   Apple's hard target is **<15 min for 98%** of submissions (some held for deeper analysis); anecdotally most finish faster. Accepts `.dmg`, a signed flat `.pkg`, or `.zip` (`ditto -c -k --keepParent`). ✅
6. **Staple** (for offline Gatekeeper): `xcrun stapler staple xtty.dmg` (and the `.app`). A `.zip` **cannot** carry a staple — staple the `.app`, then zip. ✅
7. **Verify** (good as the harness gate): `spctl -a -vvv -t exec xtty.app` (expect `source=Notarized Developer ID`) · `xcrun stapler validate` · `codesign --verify --deep --strict --verbose=2`.
8. **Package**: ship a **DMG** for a GUI app (stapleable, drag-to-`/Applications`, avoids App Translocation **once copied to `/Applications`** — a `.zip` launched in place still translocates). `.pkg` needs a separate *Developer ID Installer* cert — skip unless ever needed.

---

## 4. The entitlement set for a notarized xtty

**The Hardened-Runtime exception list is EMPTY.** Minimal correct posture = (1) `ENABLE_HARDENED_RUNTIME=YES`; (2) keep `app-sandbox=false`; (3) **no `com.apple.security.cs.*` keys at all**; (4) sign with a real Developer ID; (5) `get-task-allow` Debug-only. ✅

Each Hardened-Runtime exception, justified or ruled out:

| Entitlement | Verdict | Reason |
|---|---|---|
| `cs.allow-unsigned-executable-memory` | ❌ Ruled out | For WX-memory-without-`MAP_JIT` (legacy/Mono/Electron). xtty does no such tricks; none of iTerm2/Ghostty/WezTerm ship it despite exec'ing arbitrary code. |
| `cs.allow-jit` | ❌ Ruled out | For `MAP_JIT` JS/interpreter engines. xtty = CoreGraphics renderer (P7b), SwiftUI diff (not WKWebView), no embedded scripting. iTerm2 ships it *only* for its Python API; Ghostty/WezTerm don't (kitty copied iTerm2's set). |
| `cs.disable-library-validation` | ❌ Ruled out **(with a precondition)** | Only needed to load a *different-team / ad-hoc* dylib in-process. xtty builds SwiftTerm from source, so app-time signing re-signs it same-team ("Sign on Copy"). Ghostty proves it: production has **none**, only Debug/ReleaseLocal add it (they load a non-matching-identity libghostty). **Precondition: verify the embedded SwiftTerm bundle re-signs same-team (§8).** |
| `cs.allow-dyld-environment-variables` | ❌ Ruled out | Governs `DYLD_*` for **xtty's own** loader at launch. **ZDOTDIR injection writes the CHILD's environment** — a separate process under its own signing posture; `ZDOTDIR` isn't even a `DYLD_*` var. Unrelated. |
| `get-task-allow` | ❌ Must be ABSENT in release | Debug-only (notarization rejects it). xtty's lifecycle-census uses it only in DEBUG; Release auto-omits it. Build-config hygiene, not an entitlement to add. |

**The crux, stated plainly: Hardened Runtime + library validation do not touch child-process exec.** Library validation governs code loaded *inside* the app's address space; `fork`/`exec`/`posix_spawn` children get an independent AMFI evaluation (on Apple Silicon an unsigned native binary is auto-ad-hoc-signed at first exec). So spawning the login+interactive shell via `forkpty`, exec'ing `$EDITOR` via `Process`, and ZDOTDIR injection **all need no entitlement**. ✅

**Resource-access TCC entitlements (the one nuance).** All three notarized comparators additionally ship a resource-access set — `automation.apple-events`, `device.audio-input`, `device.camera`, `personal-information.{addressbook,calendars,location,photos-library}` (WezTerm adds `device.bluetooth`). These are **NOT HR exceptions** and **NOT required to launch or run shells** — they let *child CLIs* reach TCC-protected resources attributed to xtty (a child is otherwise *silently denied* under HR). ❓ The "denied-without-them" mechanism is **inferred** (rated *likely*), not verified by injection; the "all three ship this set" fact is directly observed. **Recommendation: omit for the MVP, add on demand** (each also needs a paired `NS…UsageDescription` Info.plist string). Including them later matches Ghostty/iTerm2/WezTerm.

**ScreenCaptureKit (latency probe): no entitlement needed** — Screen Recording is purely TCC-gated (user grant + `NSScreenCaptureUsageDescription`). It is bench/DEBUG-only and shouldn't ship, so the notarized app needs neither the usage string nor the grant. ✅ (iTerm2's *helper* executables ship empty `<dict/>` entitlements — corroborating that nested/helper code needs nothing of its own.)

---

## 5. Comparison table — how the OSS terminals sign + notarize

| Terminal | Sandbox | Hardened Runtime | Sign | Notarize | Staple | Package | HR exceptions |
|---|---|---|---|---|---|---|---|
| **Ghostty** (closest analog: Swift/AppKit, Xcode) | OFF | **ON** | Dev ID, `-o runtime`, 7-key TCC set | `notarytool submit --wait` (**ASC API key**) | **Yes** (.dmg + .app) | Signed DMG (`create-dmg`) + zip; Sparkle auto-update | `disable-library-validation` **debug only** |
| **WezTerm** | OFF | **ON** | Dev ID, `--options runtime --deep`, 8-key (adds `device.bluetooth`) | `notarytool submit --wait` (apple-id + app-pw) | **No** (ships zip → relies on online check) | ZIP + Homebrew cask | none (prod) |
| **kitty** | OFF | **ON** | Dev ID, `--options=runtime --timestamp` | `notarytool submit --wait` (vendored binary) | **Yes** (+ `stapler validate`) | DMG (`hdiutil` ULMO) | `allow-jit` (entitlements copied from iTerm2) |
| **Alacritty** (cautionary outlier) | OFF | **OFF** | **ad-hoc** `codesign --force --deep --sign -` | **None** | n/a | Unsigned DMG (`hdiutil` UDZO) | none (Info.plist usage strings only) |

Consensus 7-key TCC set (Ghostty ∩ WezTerm ∩ kitty): `automation.apple-events` + `device.audio-input` + `device.camera` + `personal-information.{addressbook,calendars,location,photos-library}`. None enable App Sandbox. **Follow Ghostty/WezTerm/kitty for a frictionless install; Alacritty forces right-click-Open past Gatekeeper.** ✅

Notes: WezTerm signs with `--deep` (discouraged but not fatal — a shipping comparator that violates the §3 advice); 2 of 3 (WezTerm, kitty) authenticate notarytool with apple-id + app-specific password, only Ghostty uses the ASC API key (recommended for CI robustness, but not universal).

---

## 6. Impact on xtty's existing features

| Surface | Verdict | Notes |
|---|---|---|
| **SwiftTerm (gitignored patched local-path SPM dep)** | ✅ SAFE | `.library` with no explicit `type:` → **statically linked** into xtty's Mach-O; no separate framework to notarize. Source provenance (git-apply'd patch vs SPM tag) is invisible to codesign. Only nested artifact = `SwiftTerm_SwiftTerm.bundle` (metallib, *data* not code) — Xcode archive auto-signs nested bundles. Caveat is **build-ordering** (`bootstrap-swiftterm.sh` must run first), not signing. (Static-link is an SPM-type inference — verify once, §8.) |
| **ZDOTDIR injection + bundled `.zshenv`** | ✅ SAFE | Folder-reference resource read via `Bundle.main.url`; reading own (code-sealed) resources is unaffected by HR. Injecting `ZDOTDIR` into the *child* env is unrelated to `allow-dyld-environment-variables`. |
| **`$EDITOR` / link-open exec via `Process`** | ✅ SAFE | `posix_spawn` children are independent, separately-evaluated processes. HR is per-process; no entitlement to spawn or exec the user's editor. |
| **DEBUG harness (state dump, `-UITest*`, `XTTY_TEST_*`, benchmark)** | ✅ SAFE (code) / ⚠️ build-config | All `#if DEBUG`-gated → a Release build compiles none of it. But `get-task-allow` is Debug-only and **notarization rejects it** → distribution **must use a Release archive** (auto-omits it). No source edit needed. |
| **Screen-Recording / latency probe** | ✅ SAFE | `BenchmarkRunner` is `#if DEBUG`; end-users never hit Screen Recording. Minor nit: `App/LatencyProbe.swift` is **not** file-level `#if DEBUG`, so a release binary links `ScreenCaptureKit.framework` but never invokes it — harmless; optionally wrap in DEBUG to keep the release link surface minimal. |
| **App Sandbox OFF + entitlements file** | ✅ SAFE | Correct for Developer ID (non-MAS). Only `ENABLE_HARDENED_RUNTIME` flips NO→YES; entitlements file stays essentially as-is. |
| **`add-local-signing-identity` (`xtty-dev`)** | ❓ Subsumed-but-retained | A real Developer ID makes the Screen-Recording grant persist (TCC keys to the designated requirement) — subsuming `xtty-dev` for signed builds. But the probe never ships, so `xtty-dev` keeps value for unsigned ad-hoc/CI local iteration. Don't delete it. |

**Net: one true NEEDS-CHANGE (build-config Release-archive plumbing); the rest is SAFE.** ✅

---

## 7. Recommended OpenSpec change shape

A new change (suggested **`add-distribution-signing`**, the long-deferred P7-distribution slice), **primarily a `build-workflow` spec delta**, with a `verification-harness` delta for the verify gate.

**Requirements (mechanism-neutral):**

- *The project SHALL produce a Gatekeeper-accepted, notarized distributable of the Release configuration, signed with a Developer ID Application identity under the Hardened Runtime, with the notarization ticket stapled.*
  - Scenario: WHEN the distribution build runs with a valid Developer ID identity + notarization credentials, THEN it produces a stapled DMG that passes `spctl -a -vvv` as `Notarized Developer ID` and `stapler validate`.
- *The notarized Release artifact SHALL carry no Hardened-Runtime exception entitlements and SHALL NOT carry `get-task-allow`.*
  - Scenario: WHEN the signed app is inspected, THEN `codesign -d --entitlements -` shows only `app-sandbox=false` (plus any deliberately-added resource-access TCC keys) and no `cs.*` exception and no `get-task-allow`.
- *(verification-harness)* *The build SHALL verify the signed/notarized artifact via a scriptable `codesign --verify --deep --strict` + `spctl`/`stapler validate` check before publishing.*

**Prerequisites the USER must do by hand** (capture in `tasks.md` as human-gated, non-automatable): (1) enroll + pay the Apple Developer Program; (2) create + safeguard the Developer ID Application cert/private key (Account Holder); (3) mint the App Store Connect API key (`.p8`, once) or app-specific password; choose Team ID.

**What `make dist` / CI can automate:** import the `.p12`/PEM into a throwaway keychain → `xcodebuild archive` (Release, HR=YES, Dev ID) → inside-out `codesign --options runtime --timestamp` → build DMG → `notarytool submit --wait` → `stapler staple` → `spctl`/`stapler validate`/`codesign --verify` gate. Adopt ASC **API-key** auth (Ghostty's choice — robust for CI, no password rotation).

**Spikes worth doing once the account exists:** confirm the embedded SwiftTerm bundle re-signs same-team (`codesign -dvvv` after a Dev ID archive) — the precondition for omitting `disable-library-validation`; a `notarytool submit` dry run to confirm the static-link assumption (no unexpected nested framework); decide resource-access TCC entitlements in/out for v1 (recommend out).

---

## 8. Open questions / risks (critic-flagged — verify before spending)

The completeness critic graded the note **usable-with-caveats**. None are blockers, but these few should be independently confirmed before spending money/time:

- ⚠️ **Procurement is the real gate.** ~$99/yr + Account-Holder cert creation; 0 identities on the machine today. **Confirm current Apple Developer Program price/terms** at developer.apple.com/programs before paying — a free Apple ID *cannot* obtain a Developer ID cert or notarize.
- ⚠️ **Use a Release archive, not Debug** — so `get-task-allow` is absent (notarization rejects any binary carrying it).
- ❓ **`disable-library-validation` omission is conditional** on the embedded SwiftTerm re-signing same-team (expected via Sign-on-Copy, but the facets rate it *unverified*). Verify once with `codesign -dvvv` on `SwiftTerm_SwiftTerm.bundle` after a Dev ID archive.
- ❓ **Static-link assumption** (no unexpected nested dynamic framework needing separate signing) — high-confidence (automatic-type SPM library) but unverified against an actual archived `.app/Contents/Frameworks`. Verify with one Dev ID archive + `codesign --verify --deep --strict` + a `notarytool` dry run.
- ❓ **"Developer ID subsumes the `xtty-dev` TCC workaround"** rests on TN3127/DevForums reasoning (forums.apple.com/thread/730043), not a direct test with a real Developer ID cert — treat as *likely*, not settled.
- ❓ **Resource-access TCC entitlements in or out for v1?** Omitting means user CLIs that touch mic/camera/contacts/calendar/location/photos/AppleScript are *silently denied* under HR — but that mechanism is *inferred*, not injection-verified. Recommend ship-without, add on first real report; each needs a paired Info.plist usage string.
- ⚠️ **`--timestamp` needs network at sign time**; notarization needs network + Apple service availability (Apple's hard figure is <15 min for 98%, occasionally held longer for deeper analysis — don't bank on the anecdotal "<5 min").
- ❓ **macOS 26.x `spctl --assess` deprecation messaging** — `spctl -a -vvv` still works; treat `stapler validate` as the authoritative staple check.
- ❌ **Mac App Store is NOT a path** — sandbox-off is a permanent design choice; this whole pipeline is Developer-ID / non-MAS by necessity (refutes any "also ship to MAS" framing).
- ⚠️ Minor cleanliness: wrap `App/LatencyProbe.swift` in file-level `#if DEBUG` so the release binary stops linking `ScreenCaptureKit` it never calls (harmless today).

---

## 9. Addendum (2026-06-30) — Homebrew distribution (brew.sh)

*Follow-on question ("can we distribute via brew.sh?") researched by a second 5-agent workflow (3 parallel facets — cask mechanics + requirements · comparator cask recipes read live via the local `brew` 6.0.5 · the xtty-specific path — + synthesis + completeness critic). Critic verdict: **usable-with-caveats**.*

**Headline: yes, as a Homebrew *Cask* — but Homebrew is a discovery/install channel layered *on top of* notarization, not a way around it.** It overturns nothing in §1–§8; if anything it makes notarization **more** load-bearing. ✅

- **Cask, not formula.** A GUI `.app` ships as a `cask` (`brew install --cask`), not a `homebrew/core` formula. The cask is thin metadata — `url` → download, `sha256` → integrity, `app "xtty.app"` → relocate into `/Applications` (+ `version`, `livecheck`, `zap`, optional `auto_updates`). All four comparators are cask-only. ✅
- **The quarantine crux (stated plainly): an un-notarized brew-installed app still hits Gatekeeper.** Homebrew Cask applies `com.apple.quarantine` **by default**, so first launch is adjudicated by Gatekeeper exactly as a hand-downloaded DMG. The historical `--no-quarantine` / `quarantine false` bypass is **deprecated and already gone** in Homebrew 6.0.5 (verified — `brew install --cask --help` has no such flag). So a cask does **not** paper over xtty's current ad-hoc posture; the §1–§8 Developer ID + notarization pipeline is a **hard prerequisite**. ✅ (❓ residual override paths — `HOMEBREW_CASK_OPTS`, MDM/unattended — are unconfirmed, but irrelevant to a clean default UX.)
- **Homebrew is actively removing un-notarized casks.** Policy (Homebrew 5.0.0, 2025-11-12): casks that fail Gatekeeper checks will be **disabled in September 2026**. Live proof in the comparators: **Alacritty's shipping 0.17.0 is ad-hoc-signed, `spctl`-rejected, and its cask already carries `disable! date: "2026-09-01", because: :fails_gatekeeper_check`** — a concrete refresh of §5's "cautionary outlier" (Alacritty's *current cask* is on the way out, not merely sub-optimal). ✅
- **Own tap first, official tap later.** The official `Homebrew/homebrew-cask` enforces a **notability gate** a greenfield repo can't clear, and self-submitting your own repo triggers the *higher* bar (docs cite ~225 stars / 90 forks / 90 watchers). ❓ The facets disagreed on whether that's **AND or OR**, and there are documented **exceptions** (notable via the app's own website, maintainer/prolific-contributor submission, social-media-notable new software) — so "fails by construction" is too absolute; re-read the live *Acceptable Casks* doc before any official PR. Your **own tap** (`kitimark/homebrew-xtty` → `brew install --cask kitimark/xtty/xtty`) has **no notability gate** and is the realistic launch channel. ✅
- **Tap cost vs app cost — the own tap does NOT itself require the $99.** Two separate gates: the own tap removes Homebrew's *notability* gate (free — a GitHub repo + a `Casks/xtty.rb`, no Apple account touches it), but it does **NOT** remove Apple's *Gatekeeper* gate (the $99 lives there). ✅
  - **Strictly required? No.** You *can* ship an un-notarized (ad-hoc) app through your own tap for **$0** — Homebrew won't stop you and it installs fine; **this is exactly what Alacritty does today.** ✅
  - **The catch:** every user then hits the *"Apple could not verify 'xtty' is free of malware"* Gatekeeper wall on first launch and must manually approve it (System Settings → Privacy & Security → "Open Anyway" — and on **macOS 15+/26 the old right-click→Open shortcut is gone**, so it's the Settings route only). Rough first impression for a `brew install` meant to "just work". ⚠️
  - **No free path to notarization:** a free Apple ID **cannot** create a Developer ID cert or notarize (see §3) — the paid program is the only way to a clean-launch app. ❌
  - Net (three paths): **own tap + notarized = $99/yr, clean launch** · **own tap + ad-hoc (Alacritty-style) = $0, Gatekeeper wall + manual "Open Anyway"** · **official `homebrew-cask` = $99/yr + notable + notarized, clean launch but notability-gated.** The own tap buys free *distribution*; only the $99 buys friction-free *first launch*. ✅

**Comparator casks (read live via `brew info/cat --cask` + `spctl`/`codesign` on the downloaded artifacts):**

| Terminal | Official tap? | Own tap? | Artifact | Notarized DevID (`spctl`)? | auto_updates |
|---|---|---|---|---|---|
| **Ghostty** 1.3.1 (closest analog) | ✅ | ❌ | DMG / own CDN | ✅ accepted (hardened) | `true` (Sparkle, `:sparkle` appcast) |
| **WezTerm** | ✅ | ✅ also (`wezterm/homebrew-wezterm`) | ZIP / GH Releases | ✅ accepted (hardened) | — (`:github_latest`) |
| **kitty** 0.47.4 | ✅ | ❌ | DMG / GH Releases | ✅ accepted (ticket stapled to `.app`) | — |
| **Alacritty** 0.17.0 | ⚠️ being disabled 2026-09-01 | ❌ | DMG / GH Releases | ❌ **rejected (ad-hoc)** | — (`:github_latest`) |

Consensus for a Swift/AppKit terminal (Ghostty): Developer-ID + Hardened-Runtime + notarized `.app` in a DMG, `zap` for clean uninstall, optional Sparkle. **All notarized comparators confirm Homebrew is a channel on the same signed artifact, never a signing bypass.** ✅

**Concrete cask sketch** (own tap → notarized GitHub-Releases DMG; deployment floor corrected to the real target):
```ruby
cask "xtty" do
  version "0.1.0"
  sha256 "<sha256 of xtty-0.1.0.dmg>"
  url "https://github.com/kitimark/xtty/releases/download/v#{version}/xtty-#{version}.dmg",
      verified: "github.com/kitimark/xtty/"
  name "xtty"
  desc "Native macOS terminal emulator with at-a-glance session progress"
  homepage "https://github.com/kitimark/xtty"
  livecheck { url :url; strategy :github_latest }
  auto_updates false                 # default; only true if xtty gains a Sparkle updater
  depends_on macos: ">= :sonoma"     # ⚠️ project.yml:14-15 floor = macOS 14.0 — NOT the dev OS (26)
  app "xtty.app"
  zap trash: [
    "~/.config/xtty",
    "~/Library/Preferences/com.xtty.app.plist",
    "~/Library/Caches/com.xtty.app",
    "~/Library/Saved Application State/com.xtty.app.savedState",
  ]
end
```
Tap repo `kitimark/homebrew-xtty`, file `Casks/xtty.rb`. Bundle id `com.xtty.app` (`project.yml:49`). DMG preferred over ZIP (a `.zip` can't carry a stapled ticket; risks App Translocation). ⚠️ **The synthesis mis-set the floor to `:tahoe`/macOS 26 (the dev OS); the real build floor is macOS 14.0 (Sonoma)** per `project.yml` — derive the cask `depends_on` from that, not the machine you built on.

**OpenSpec mapping: a *separate* thin follow-on change** (e.g. `add-homebrew-distribution`), **not** a fold-in. Keep `add-distribution-signing` (§7) the artifact producer — but have it pre-bake the two cask enablers: a **deterministic Release asset name** (`xtty-${VERSION}.dmg`) and a **GitHub Release + published sha256 on tag**. The cask lives in a *different repo*, is strictly downstream of the signed artifact, and carries its own user-gated prereq — coupling a discovery nicety to the $99-gated signing work would needlessly block a shippable signing change. CI hook: on tag → existing notarize pipeline emits the DMG → `gh release create` → `brew bump-cask-pr --version` (recomputes sha256 itself), the same command that serves the official tap later. **User prereqs:** create the public `kitimark/homebrew-xtty` repo + a CI token (PAT, repo+workflow scope) to push bumps — *plus* the Apple Developer Program account from §1–§8, which remains THE hard gate.

**Addendum verify-before-acting (critic):** confirm the cask `depends_on macos:` against the real floor (macOS 14.0, not `:tahoe`); whether the Sept-2026 Gatekeeper-disable enforcement extends to *third-party* taps (the blog scopes the *disable* action to `Homebrew/homebrew-cask` only — install-blocking on personal taps is unstated); the live *Acceptable Casks* notability thresholds + AND/OR combinator + exceptions before any official-tap PR; global uniqueness of the `xtty` cask token before graduating.

**Addendum sources:** docs.brew.sh/{Cask-Cookbook, Acceptable-Casks, Adding-Software-to-Homebrew, Taps, FAQ}; Homebrew 5.0.0 release notes (2025-11-12, Gatekeeper-disable policy); local `brew` 6.0.5 — `brew info/cat --cask {ghostty,wezterm,alacritty,kitty}`, `brew install --cask --help`; `spctl -a -vvv` / `codesign -dvvv` on the downloaded comparator artifacts; `wezterm/homebrew-wezterm` (own tap, HTTP 200); xtty `project.yml:14-15,49`.

---

## 10. Addendum (2026-06-30) — distributing at **$0** (no paid Apple Developer Program)

*Follow-on question ("how to distribute with 0 cost?") researched by a third 5-agent workflow (3 parallel facets — source-build/local-compile path · ad-hoc prebuilt UX on macOS 26 + free-signing limits · OSS $0-distribution patterns & audience fit — + synthesis + completeness critic). Critic verdict: **usable-with-caveats** (corrections below baked in).*

**Headline: $0 distribution already works — it splits by *who compiles the binary*. A locally-compiled app dodges Gatekeeper entirely; a downloaded prebuilt one does not (unless notarized = $99).** ✅ The load-bearing fact: Gatekeeper's "cannot verify" wall only fires on files carrying `com.apple.quarantine`, and that attribute is written by the *downloading* app (browser/curl), **never by the compiler**. **Verified with direct local evidence** — `xattr -l` on the repo's own Release build shows only `com.apple.provenance`, **no `com.apple.quarantine`**. So anything the user builds (`make run`, Xcode, a from-source formula) is ad-hoc-signed (which arm64 *requires* just to execute — a truly-unsigned binary is SIGKILL'd, so the ad-hoc signature is load-bearing, not cosmetic) AND never quarantined → launches with zero prompts. **xtty is already in this $0 + clean state today**, and it's the most on-brand path for the "free and open, no account, no paywall" value.

**The $0 decision tree:**

| Path | Cost | First launch | Verdict for xtty |
|---|---|---|---|
| **(a) User builds from source** (`make setup`/`run`, already shipped) | **$0** | ✅ no Gatekeeper wall ever (never quarantined) | **canonical** — on-brand, zero friction |
| **(b) Ship ad-hoc prebuilt** (GitHub Releases DMG / own tap) | **$0** | ⚠️ one-time manual "Open Anyway" **or** `xattr -dr com.apple.quarantine` per user | optional convenience for non-builders |
| **(c) Clean prebuilt launch** (download → double-click → runs) | ❌ **$99/yr** | ✅ clean | the deferred `add-distribution-signing` — NOT $0 |

- **Source-build (a) truly dodges Gatekeeper** — confirmed by local `xattr`; `spctl … rejected` is a red herring (it only runs *for quarantined files*). The 38-test e2e harness launching the built app non-interactively is daily proof. This is the same model as Alacritty (64.7k★, `make app` only), Ghostty, kitty, WezTerm. ✅
- **Ad-hoc prebuilt (b) on macOS 26 Tahoe:** ❌ the Finder **right-click→Open shortcut is gone** (removed in Sequoia 15.0, still gone in Tahoe). The only built-in approval is System Settings ▸ Privacy & Security ▸ "Open Anyway" — and (⚠️ **corrected from the synthesis**) the button is available **for ~1 hour *after* the blocked launch attempt** (a window that then closes), *not* "visible an hour later". `xattr -dr com.apple.quarantine /Applications/xtty.app` still works on Tahoe (quarantine is **not** SIP-protected) and is the terminal-native escape hatch — fitting for this audience — but it also defeats the first-run malware scan, so it's a user step, not a distribution fix. ❓
- **`sudo spctl --master-disable` ("Allow from Anywhere")** is a $0 option but **rejected**: a system-wide security downgrade requiring sudo, the GUI toggle is hidden until first use, and on Sequoia/Tahoe it may *still* need a per-app `xattr`. Not a real distribution answer. ❌
- **Free signing does NOT help distribution.** ❌ A free Apple ID "Personal Team" / Apple Development cert is on-device-dev-only (7-day provisioning expiry, **cannot** create a Developer ID cert, **cannot** notarize, does nothing for a clean launch on other Macs). xtty's existing `xtty-dev` self-signed cert is a local-dev TCC-persistence convenience, **not** a distribution lever. There is no free notarization (consistent with §3).
- **Homebrew formula-from-source is viable but a real rework, not a drop-in.** A *formula* (casks can't compile) can build a GUI `.app` from source (precedent: MacVim in core, emacs-plus in a tap) into the Cellar with a manual copy to `/Applications`, and it also dodges Gatekeeper (Cellar output is never quarantined). But three blockers — **confirmed in general, NOT reproduced against this repo**: (1) the Metal toolchain needs sudo+network → stays a manual prereq; (2) the SwiftTerm git-clone+patch bootstrap is blocked by Homebrew's build sandbox → must become a `resource`; (3) `xcodebuild`+SPM fail in Homebrew's nested sandbox without `-IDEPackageSupportDisableManifestSandbox=1`. homebrew-core won't take a GUI app anyway (cask-only policy) → a **custom tap** formula only. **Defer unless there's demand.** ❓

**Audience fit ✅:** the population that can build xtty (full Xcode + Metal toolchain + XcodeGen + the SwiftTerm bootstrap) is a **strict superset** of those who can clear a one-time "Open Anyway". The "unsigned = financial suicide" argument is about mass-market *paid* apps where first-run is a conversion funnel — xtty has no funnel and a maximally technical audience that already runs `brew install`, "Open Anyway", `xattr`, and builds from source daily. The `xattr -dr com.apple.quarantine` idiom appears in thousands of OSS READMEs (count is approximate but order-of-magnitude solid) as normalized troubleshooting, not stigma (Alacritty / Sourcery / yabai / benterm).

**Recommendation:** make **source-build the canonical $0 install** (already shipped, zero friction, no Apple money/account); optionally add an **ad-hoc prebuilt** (DMG-drag preferred over zip — fewer "damaged"/translocation failures — with clear README "Open Anyway"/`xattr` docs) for non-builders. Keep the **$99-gated `add-distribution-signing`** explicitly an *optional future convenience*, **not required to ship**. OpenSpec mapping: the $0 paths are a **README install section + a small `build-workflow` spec delta** (no new runtime behavior) — distinct from the $99 change.

**Addendum verify-before-acting (critic):** (1) one real fresh-Tahoe download test of an ad-hoc xtty **DMG vs zip** to see which dialog actually fires ("Open Anyway" vs "app is damaged"/no-button) before writing README first-launch steps; (2) the "Open Anyway" timing wording (fixed above); (3) whether the Sept-2026 un-notarized-cask disable reaches **third-party taps** or only the official one (runtime Gatekeeper applies either way); (4) if pursuing the formula, reproduce a full end-to-end Homebrew-sandbox build against *this* repo; (5) `com.apple.provenance` semantics are in flux — don't lean on its presence; the decisive fact is the **absence of quarantine**.

**Addendum sources:** Apple — `developer.apple.com/documentation/security/{gatekeeper, notarizing-macos-software…}`, support.apple.com "Open a Mac app from an unidentified developer" (macOS 15/26 flow), the `codesign`/`spctl`/`xattr` man pages, dev-forum threads on Sequoia removing right-click→Open + Personal Team cert limits; Homebrew — `docs.brew.sh/Formula-Cookbook` + `brew create`/formula-from-source docs + the build-sandbox + `xcodebuild`-SPM nested-sandbox issues; OSS — Alacritty `INSTALL.md` (`make app`), Sourcery / yabai / benterm READMEs (`xattr` one-liner), GitHub code-search for the `xattr -dr com.apple.quarantine` idiom; xtty — local `xattr -l` on the Release build, `Makefile`, `scripts/{bootstrap-swiftterm,create-signing-cert}.sh`, `project.yml`.

---

## Sources

- **xtty repo:** `App/xtty.entitlements`, `project.yml`, `Makefile`, `scripts/create-signing-cert.sh`, `scripts/bootstrap-swiftterm.sh`, `App/{FileOpener,ShellIntegration,LatencyProbe,BenchmarkRunner,XttyApp,UITestDump,TerminalWindowController}.swift`, `XttyCore/{Package.swift,Sources/XttyCore/ShellResolver.swift}`, `openspec/specs/build-workflow/spec.md`, `openspec/changes/archive/2026-06-29-add-local-signing-identity/{proposal,design,tasks}.md`, `AGENTS.md`, `research/03-analysis/p7-measurement-methodology.md`
- **Apple:** developer.apple.com/programs (membership/fee); /developer-id/ (Account-Holder, no notarization fee); /help/account/ (free-vs-paid, 5-cert limit); documentation/security/{hardened-runtime, notarizing-macos-software-before-distribution, customizing-the-notarization-workflow, resolving-common-notarization-issues}; documentation/xcode/configuring-the-hardened-runtime; documentation/technotes/tn3147 (altool retired 2023-11-01); documentation/screencapturekit; forums/thread/730043 (TCC + stable identity); WWDC21 session 10261
- **Secondary:** keith.github.io/xcode-man-pages/notarytool.1.html; gist.github.com/rsms/929c9c2fec231f0cf843a1a746a416f5 (inside-out codesign, ditto, stapler, spctl, DMG/zip/pkg + translocation); lapcatsoftware.com/articles/hardened-runtime-sandboxing.html; eclecticlight.co/2021/01/07/notarization-the-hardened-runtime; macinternals.app/en/blog/fork-exec-posix-spawn; forum.juce.com/t/child-process-hardened-runtime-issue/48425; blog.xojo.com/2024/08/22 (sandbox optional outside MAS); github.com/electron/notarize; per-entitlement `bundleresources/entitlements/com.apple.security.cs.*` doc pages
- **OSS configs (cloned to `/tmp`):** Ghostty `macos/Ghostty.entitlements` + `{GhosttyDebug,GhosttyReleaseLocal}.entitlements` + `Ghostty.xcodeproj/project.pbxproj` + `.github/workflows/release-tip.yml`; WezTerm `ci/macos-entitlement.plist` + `ci/deploy.sh`; kitty `bypy/macos/__main__.py` + bypy `macos_sign.py`; Alacritty `Makefile` + `.github/workflows/release.yml` + `extra/osx/Alacritty.app/Contents/Info.plist`; iTerm2 `iTerm2.entitlements` + `plists/iTermServer.entitlements`
