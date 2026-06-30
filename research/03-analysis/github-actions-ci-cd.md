# CI/CD for xtty on GitHub Actions

> **Provenance:** 2026-06-30, produced by a multi-agent research workflow (6 agents, ~438k tokens) — 4 parallel facet readers (GitHub-hosted macOS **runner reality** + the Metal-toolchain question · **XCUITest-on-hosted-runner** viability · real OSS **Swift/Xcode workflow patterns** · **xtty repo grounding** of Makefile/bootstrap/pin) + synthesis + a completeness critic. External sources favored over memory per the project methodology (WebSearch of GitHub docs + the `actions/runner-images` repo, shallow reads of real `.github/workflows`). **Critic verdict: usable-with-caveats** — the corrections below are folded in (the synthesis oversold the Metal-toolchain question as "resolved"; it is a genuine 2-2 facet split → design defensively). Companion to [`distribution-signing-research`](distribution-signing-research.md) (the $0/Homebrew/$99 distribution arc); this doc is **build+test CI** + the **release** seam.

**Decision status:** explore-phase finding for a new **`add-ci-pipeline`** change (tooling). **Verdict: yes — $0, secret-free CI/CD is viable on GitHub-hosted runners today.** Captured, not yet proposed. The repo `git@github.com:kitimark/xtty.git` exists but the local clone has **no remote** and there is **no `.github/`** yet — wire those first.

---

## 1. TL;DR

- ✅ **CI/CD on GitHub-hosted runners is viable, $0, and secret-free today.** xtty's committed ad-hoc "Sign to Run Locally" posture (`CODE_SIGN_IDENTITY="-"`, sandbox/Hardened-Runtime off, no team) needs **zero Apple secrets**; standard `macos-26` runners are **free + unlimited on public repos**. This is the cheap slice — the $99 notarized path stays deferred to a separate release change.
- ❓ **The one historically-scary risk — the Metal toolchain on the runner — is NOT settled (genuine 2-2 facet split).** Two facets (deeper evidence: the image build script's `-ge 26` gate + a 2026-04-23 maintainer comment) say it's **preinstalled** on `macos-26` for release Xcode ≥ 26; two say CI **must download** it (open issues #13014/#13080/#13094). **Resolution: design defensively** — keep an idempotent `xcrun -f metal || sudo xcodebuild -downloadComponent MetalToolchain` guard so it doesn't matter which is true; verify on the first real run. (xtty compiles SwiftTerm's bundled `.metal` shader, so this gates even the unit-test job — see §3.)
- ❓ **The real live risk is the XCUITest GUI job, not Metal.** The runner image *does* pre-authorize the UI-test path (auto-login GUI session + TCC pre-grants + `automationmodetool` + `DevToolsSecurity --enable`), so **no permission dialogs block `xcodebuild test`**. But the **synthesized-input drive path** (`app.typeText`/`.click()`, the two corner-drag tests) is known-flaky on hosted runners and unproven for xtty specifically — even though xtty's *assertions* read deterministic `/tmp` DEBUG dumps (not the AX tree), the *drive* channel doesn't share that robustness. **Resolution: gate on the headless unit job; start the GUI job non-blocking with retries.**
- ✅ **Recommended minimal first pipeline:** one workflow, two jobs, on push + PR — a **required** fast headless `test-core` (XttyCore `swift test`) + a **best-effort** `build-and-test` (XcodeGen → `xcodebuild test`, retry-tolerant).

---

## 2. Runner reality

| Decision | Recommendation |
|---|---|
| **Image** | ✅ Pin **`macos-26`** explicitly. Don't use `macos-latest` — it's mid-flip from macos-15→macos-26 (~2026-06-15 → ~2026-07-15) and would silently change the runner version. |
| **Xcode** | macos-26's *default* is **26.5** (unambiguous release, Metal preinstalled); xtty is verified on **26.6** (only on macos-26). ❓ One facet flags 26.6 as possibly an **RC** — and the Metal-preinstall gate **excludes betas/RCs** — so pinning 26.6 is **not strictly safer** than the 26.5 default. **Either** accept the 26.5 default, **or** pin 26.6 *and keep the Metal download guard*. Verify the exact `.app` path once (`ls /Applications | grep -i Xcode`) — patch suffixes rotate. |
| **Metal toolchain** | ❓ **Likely preinstalled** on macos-26 for *release* Xcode ≥ 26, but **not settled** (2-2 split) and excluded for RCs/betas. **Keep the idempotent fallback** `xcrun -f metal >/dev/null 2>&1 \|\| sudo xcodebuild -downloadComponent MetalToolchain` (~700 MB, network, sudo, installs into `/System` so **not cleanly cacheable**). |
| **XcodeGen** | ✅ Not preinstalled; Homebrew is (v6.x). xtty's existing `brew install xcodegen` works unchanged (fast bottled install). |
| **Cost** | ✅ **Free + unlimited** on public repos with **standard** runners. Avoid "larger" runner SKUs (not free for public repos). The macOS 10× quota multiplier only matters for private repos. |
| **Resources** | ⚠️ macos-26 runners are **~14 GB total disk** (that's total, not free), Apple-silicon, ~7 GB RAM — fine for xtty's small footprint + Xcode + the SwiftTerm clone, but watch headroom. |
| **Deployment target** | macOS 14.0 target does **not** force an older runner — build with the 26.x SDK, target 14.0. |

---

## 3. CI workflow design (two jobs, push + PR, no secrets)

A fast always-on **`test-core`** (required gate) + a heavier best-effort **`build-and-test`**. Both `runs-on: macos-26`. Shape:

```yaml
name: ci
on: [push, pull_request]
jobs:
  test-core:                         # fast, REQUIRED gate — headless, deterministic (229 unit tests)
    runs-on: macos-26
    steps:
      - uses: actions/checkout@v4
      - run: sudo xcode-select -s /Applications/Xcode_26.6.app   # or accept the 26.5 default (see §2)
      - run: xcrun -f metal >/dev/null 2>&1 || sudo xcodebuild -downloadComponent MetalToolchain  # guard (§1)
      - uses: actions/cache@v4         # highest-value cache: the SwiftTerm checkout
        with:
          path: external/SwiftTerm
          key: swiftterm-${{ runner.os }}-${{ hashFiles('patches/swiftterm/UPSTREAM_CONFIG.sh','patches/swiftterm/xtty-accessors.diff') }}
      - uses: actions/cache@v4         # SPM
        with: { path: ~/Library/Caches/org.swift.swiftpm, key: spm-${{ hashFiles('XttyCore/Package.resolved') }} }
      - run: scripts/bootstrap-swiftterm.sh      # call the script directly, NOT `make` (§5)
      - run: swift test --package-path XttyCore

  build-and-test:                    # heavier, BEST-EFFORT (retry-tolerant) until GUI reliability is proven
    runs-on: macos-26
    steps:
      - uses: actions/checkout@v4
      - run: sudo xcode-select -s /Applications/Xcode_26.6.app
      - run: xcrun -f metal >/dev/null 2>&1 || sudo xcodebuild -downloadComponent MetalToolchain
      - run: brew install xcodegen
      - uses: actions/cache@v4
        with:
          path: external/SwiftTerm
          key: swiftterm-${{ runner.os }}-${{ hashFiles('patches/swiftterm/UPSTREAM_CONFIG.sh','patches/swiftterm/xtty-accessors.diff') }}
      - run: scripts/bootstrap-swiftterm.sh && xcodegen generate
      - run: |
          xcodebuild test -project xtty.xcodeproj -scheme xtty \
            -destination 'platform=macOS' -derivedDataPath build \
            -retry-tests-on-failure -resultBundlePath build/TestResults.xcresult | xcbeautify --renderer github-actions
      - if: failure()
        uses: actions/upload-artifact@v4
        with: { name: xcresult, path: build/TestResults.xcresult }
```

- ✅ **Cache priorities:** (1) **`external/SwiftTerm`** keyed on the pin+patch hash — the highest-value cache (skips the network clone, rebuilds only when the pin/diff changes); (2) **SPM** (`~/Library/Caches/org.swift.swiftpm` / `build/SourcePackages`) keyed on `XttyCore/Package.resolved` (the only remote dep is swift-argument-parser); (3) **DerivedData/`build`** — xtty builds into a local `build/` via `-derivedDataPath build`, so use **`irgaly/xcode-cache`** if incremental matters (a plain checkout resets mtimes, defeating naive `actions/cache` for Xcode). ❌ Don't cache the generated `xtty.xcodeproj` (gitignored, cheaply regenerated).
- ✅ **xtty's `/tmp` DEBUG-dump assertions help reliability** — the non-sandboxed app writes `/tmp/xtty-state-dump.json` + grid dump, the runner reads them with timeout-polling helpers (far more robust than AX-tree polling). This robustness is on the **assert** side only — the synthesized-input **drive** side is the risk.
- ✅ **No Screen Recording / no secrets** — the bench e2e is opt-in via `XTTY_RUN_BENCH_E2E` (leave unset); leave `XTTY_SIGN_IDENTITY` unset to stay ad-hoc. `make bench` and `make audit-leaks` are **not** CI gates (bench needs a real display + Screen Recording; audit-leaks is diagnostic-only).
- ✅ Make **`test-core` the required status check**; mark **`build-and-test` non-blocking** (or retry-tolerant) until hosted-runner XCUITest reliability is proven.

---

## 4. Release workflow (separate concern)

Tag-triggered (`on: push: tags: ['v*']`), **$0 ad-hoc now** — ties to [`distribution-signing-research` §10](distribution-signing-research.md): end users pay a one-time Gatekeeper "Open Anyway" (or build from source to dodge it). Shape: Release build → `create-dmg` (**no** `--identity`) → `softprops/action-gh-release` (default `GITHUB_TOKEN`, **no extra secret**; pin a current major — v2/v3 exist). ❓ This exact ad-hoc-DMG-without-identity recipe is **assembled/inferred** — no surveyed analog ships precisely it (they either build-only or fully notarize) — so smoke-test it.

❓ **The $99 notarized SEAM (deferred, separate downstream change `add-release-notarization`).** Purely additive vs the ad-hoc job: base64-`.p12` secret → decode → temp keychain in `$RUNNER_TEMP` (`security create-keychain` → `import -T /usr/bin/codesign` → `set-key-partition-list` — the step that prevents headless prompts) → `codesign --options runtime --entitlements …` → `create-dmg --identity` → `xcrun notarytool submit --wait` (prefer an **App Store Connect API key `.p8`** over Apple-ID+app-password) → `xcrun stapler staple` → upload → `security delete-keychain` in `always()` cleanup. Secret inventory: `DEVELOPER_ID_CERT_BASE64`, `P12_PASSWORD`, `CERT_IDENTITY_NAME`, `KEYCHAIN_PASSWORD`, + ASC `_ISSUER`/`_KEY_ID`/`_KEY`. The $99/yr is the membership; Actions minutes stay free. Pairs with the already-shipped `add-local-signing-identity` (the local-dev `xtty-dev` slice).

---

## 5. xtty-specific gotchas

- ❌ **Don't use `make doctor`/`make setup` as the CI install path** — `doctor` only *advises* and `exit 1`s on a missing prereq (never installs, by design); `setup` depends on it. The `build`/`test`/`test-core` targets do **not** depend on `doctor` — call them (or the underlying scripts) directly, and `brew install xcodegen` explicitly.
- ⚠️ **Call `scripts/bootstrap-swiftterm.sh` directly, not via `make`** — after a cache restore Make sees the patch inputs as newer than the restored sentinel and re-triggers bootstrap (harmless/idempotent but non-deterministic). Minor: on a cache hit the script still runs `git fetch --tags` (a network touch) — leave as-is or add an offline guard.
- ✅ **Ad-hoc signing is sufficient** for both the app and the generated `xttyUITests-Runner.app` (macOS UI testing needs no provisioning profile, unlike iOS-device). Keep `CODE_SIGNING_ALLOWED` at the project default — a UI test launches a real app, so don't force `CODE_SIGNING_ALLOWED=NO` (that's for pure unit builds, e.g. Stats/Mythic).
- ⚠️ **XCUITest flakiness mitigations:** `-retry-tests-on-failure`, `-resultBundlePath` for diagnostics, generous polling timeouts (already in `StateDumpReader`/`GridDumpReader`). The two corner-drag tests (`.click(forDuration:thenDragTo:)`) are the most fragile (AGENTS records a one-off 50 s mouse-interference anomaly) — consider converting them to the env-file-trigger pattern (`XTTY_TEST_*`) the rest of the suite uses (the most CI-robust path).
- 🔧 **Prerequisite — wire the remote first.** No remote, no `.github/` yet: `git remote add origin git@github.com:kitimark/xtty.git`, push `main`, **make the repo public** (free unlimited macOS minutes), then add the workflow. Nothing fires until then.

---

## 6. OSS precedent

- **Ghostty** (closest analog — Swift/AppKit, notarized) runs on **paid Namespace.so** Mac runners, not GitHub-hosted — copy its codesign/notarize **shell steps**, but substitute `macos-26` + `actions/cache` (its `nscloud-cache-action` isn't portable). Uses base64-p12 → temp keychain → `codesign -o runtime`, `create-dmg --identity`, ASC-API-key `notarytool submit --wait`, `stapler staple`; publishes via `softprops/action-gh-release`.
- **Loop** (`MrKai77/Loop`) — the best **GitHub-hosted full-notarize template**: `macos-26`, base64-p12 → `$RUNNER_TEMP` keychain, notarization, `ncipollo/release-action`, `delete-keychain` cleanup.
- **FlashSpace** — cleanest **XcodeGen-in-CI** match: `brew bundle` → `xcodegen generate` → `xcodebuild … | xcbeautify`; a separate `pr.yml` lints PR titles against **Conventional Commits** (`amannn/action-semantic-pull-request`) + SwiftLint/SwiftFormat — directly aligned with xtty's conventions.
- **Cache keys:** SPM keyed on `hashFiles('**/Package.resolved')` + `~/Library/Caches/org.swift.swiftpm`; DerivedData via **`irgaly/xcode-cache`** for mtime-preserving incremental. **Secret-free build precedent:** Stats/Mythic run `xcodebuild … CODE_SIGNING_ALLOWED=NO` with zero secrets — xtty's posture (minus the flag, since it runs UI tests).

---

## 7. OpenSpec mapping

- ✅ **Recommended change: `add-ci-pipeline`** (tooling). Primary artifact is a **`build-workflow` spec delta** — CI is the build/test process formalized, and `build-workflow` already owns the Makefile/XcodeGen/bootstrap/signing posture (it absorbed `add-local-signing-identity`). A new `ci` capability is overkill for v1; fold it into `build-workflow`.
- ✅ **No `verification-harness` delta needed** — the CI change *invokes* the existing tests; it adds **no new observable app behavior** (per the repo rule, a harness delta is only for new observable behavior). So `add-ci-pipeline` is unusually light: a `build-workflow` delta + `tasks.md`.
- ✅ **Keep release-notarization a separate downstream change** (`add-release-notarization`, the $99 path). The **ad-hoc tag-release** job can ship inside `add-ci-pipeline` (secret-free, ties to the existing source-build/ad-hoc distribution posture) or as its own small `add-ad-hoc-release`; the notarized job is explicitly out of v1 scope.
- Workflow: `/opsx:propose add-ci-pipeline` → `build-workflow` delta + `design.md` (record the Metal 2-2 split + the defensive guard, the two-job split, cache-key decisions, the notarization seam as a deferred decision) → `tasks.md` (bake the **two verify-on-first-run checks** into apply tasks — Metal resolution + the GUI-job smoke test).

---

## 8. Caveats / open questions / verify-before-acting

- ❓ **Metal preinstall — verify on the first run** (the single highest-value pre-commit check, given the 2-2 split). Run `xcrun -f metal` (or `xcodebuild -showComponent metalToolchain`) after `xcode-select` on the actually-scheduled image for the *exact* Xcode selected; keep the `|| sudo xcodebuild -downloadComponent MetalToolchain` guard until proven.
- ❓ **Release-vs-RC for the pinned Xcode** — if the image's 26.6 is an **RC**, the Metal-preinstall gate excludes it, so the pinned Xcode is the one *without* preinstalled Metal. Confirm release-vs-RC (`ls /Applications | grep -i Xcode` + the `.app` version) before pinning; the 26.5 default is the unambiguous-release fallback.
- ❓ **Does `swift test` (test-core) pull in the Metal compiler?** SwiftTerm's `Package.swift` `isGitHubActions` flag gates only the **benchmark dep** — NOT the `.process("…/Shaders.metal")` resource — so the SPM path likely compiles the shader too (moot on macos-26 if Metal is present; matters if a metal-less image is ever used).
- ❓ **XCUITest drive-path reliability is the real unknown** — permission dialogs are handled (image pre-grants confirmed), but synthesized `typeText`/`click`/corner-drag on hosted runners is unproven *for xtty*. Smoke-test before treating `make test` as a blocking gate; budget retries; start non-blocking.
- ❓ **Xcode/image drift** — GitHub rotates the macos-26 default Xcode and patch suffixes; a hardcoded `/Applications/Xcode_26.6.app` can break silently. Re-verify on any image/Xcode bump (and whether Metal-preinstall holds for a brand-new future Xcode — a maintainer reserved the right to limit preinstall to the newest one-or-two Xcodes under disk pressure).
- ⚠️ **Disk headroom** (~14 GB total) and the **ad-hoc release recipe is inferred** (no exact analog) — smoke-test the `create-dmg`-without-identity + upload flow.
- 🔧 **Hard prerequisite:** wire `origin`, push, make the repo public — nothing runs until then.

---

## 9. Addendum (2026-06-30) — first CI run results (the two unknowns, resolved)

*The pipeline was implemented (`add-ci-pipeline`) and the remote wired + pushed; the first run (`ci` · `28425122861`, push to `main`, `macos-26`) settled both researched unknowns — both favorably.*

> **Update (§11, 2026-07-01):** the per-test reading below (esp. the "focus/activation cluster + clipboard + **rendering/locale**" framing) was logs-only; **§11** re-investigates the actual `.xcresult` screenshots/grid-dumps and **corrects it** — the truecolor/emoji failure is **Cmd+V**, not locale; the runner shell is **`/bin/bash`** (a missed factor); authoritative counts are **30/7/1**, not 34/41.

- ✅ **Metal toolchain — RESOLVED: preinstalled** (the 2-2 split collapses to "preinstalled for the release default"). The image's default release Xcode is **26.5** (a release, not an RC); the build used the preinstalled `MetalToolchain-v17.6.42.0` cryptex (`/var/run/com.apple.security.cryptexd/…/Metal.xctoolchain/usr/bin/metal`) and compiled SwiftTerm's `Shaders.metal` → `default.metallib` with **no download** — the idempotent guard was a no-op. (Updates §1/§2/§8: the guard stays as cheap insurance for a future RC-default or metal-less image, but the release default has Metal.)
- ✅ **`test-core` (required gate) — PASSED in 1m6s.** Reconstituted SwiftTerm + `swift test --package-path XttyCore` green on a stock runner. The deterministic gate works; this is the check to require in branch protection.
- ✅ **XCUITest on a hosted runner — the predicted drive-path risk is REFUTED.** **34 of 41** UI tests pass (`build-and-test`, 8m35s). The synthesized-input drive path works on the auto-login runner: typing, key chords, **Cmd+V**, real **zsh injection**, and both the `/tmp` **grid-dump and state-dump** assertions all function (the complex semantic-capture, spatial-blocks, block-sidebar, git-review, profiles, quick-terminal, performance-harness suites are green; `testBasicTypedEcho` passes, proving basic typed input reaches the window).
- ⚠️ **7 deterministic CI-environment failures** (each failed all 3 `-retry-tests-on-failure` attempts, so not flaky): `testTruecolorEmojiAndWideChars`, `testMultiLinePasteIsNotAutoExecuted`, `testFocusTypingOnActivateWithoutClicking`, `testFindBarOpensLocatesAndDismisses`, `testSplitCreatesAndClosesPanes`, `testDirectionalFocusMovesBetweenPanes`, `testLifecycleChurnReturnsCensusToBaseline`. **Hypothesised cluster:** window **focus/key-activation** on the headless auto-login session (focus-on-activate-without-clicking, split-keybind delivery, directional focus, and the churn test that needs splits to form — note basic typing *works*, so it's activation/keybind-delivery, not blanket focus loss), plus two outliers — **clipboard** (`NSPasteboard` likely empty on CI → paste no-op) and **rendering/locale** (truecolor/emoji/wide grid-dump content). All fixable with per-test hardening (explicit window activation, the `XTTY_TEST_*` env-trigger pattern instead of synthesized focus/keybinds, clipboard seeding, a locale env) — but that's **iterative CI debugging** (push → ~8 min → repeat), genuinely separate from standing up CI.
- 🟢 **Net:** the CI pipeline is sound and does its job — `test-core` is the green gate, and the **non-blocking `build-and-test` correctly *surfaced* the CI-sensitivities instead of blocking merges** (exactly its design intent). The 7-test hardening is **follow-up** (a candidate `harden-xcuitests-for-ci` change), not a defect in `add-ci-pipeline`.
- 🔧 **Minor nit:** a run annotation flags `actions/checkout@v4` + `actions/cache@v4` forced onto Node 24 (Node 20 deprecation) — harmless now; bump to `@v5` when convenient.
- **Status:** `add-ci-pipeline` left **OPEN** (per decision) — done: 1.1 (push), 5.1 (Metal), 5.2 (test-core), 5.3 (smoke); remaining: 1.2 (make repo public — and note that while private each ~8-min run burns ~80 metered macOS-minutes at the 10× multiplier), 5.4 (pr-lint — needs a PR to fire), 5.5 (optional branch protection), 6.1 (archive). The 7-test hardening is the open question before promoting `build-and-test` toward a required gate.

---

## 10. Addendum (2026-06-30) — the 7 GUI failures: diagnosis, the "headless" correction, and the hybrid hardening plan (`harden-xcuitests-for-ci`)

*Two follow-on workflows: (a) a per-test diagnosis of the 7 failures against the test sources + the env-trigger infra; (b) a per-project deep read of 8 real OSS macOS apps + Apple/GitHub docs to **verify or break** the "can't run on CI" framing (one agent per repo). Critic verdicts: both **usable-with-caveats**.*

> **Update (§11, 2026-07-01):** §10 was logs-only. **§11** reads the actual `.xcresult` artifacts and **confirms the Bucket-B / Cmd-key thesis with screenshots** while correcting two per-test calls: **focus-on-activate is a *false negative*** (the marker reaches the grid; the bash banner splits the string — §11b, keep the test, don't rewrite it), and **find-bar — xtty *does* own its menu bar** (§11e). The §10e/§10f hybrid plan stands, re-sequenced to **fix the shell first** (§11f). **→ §12 (2026-07-01) then measured "fix the shell first" in CI: the banner is gone but focus-typing *still* fails — its split is the long CI prompt wrapping the marker, not the banner — so that prediction is REFUTED and the fix becomes a wrap-tolerant assertion.**

### 10a. Terminology correction — "headless" was imprecise ❌→✅

The earlier framing (§9 and prior) leaned on the word **"headless."** That's **wrong** and is corrected here: GitHub-hosted macOS runners run a **real interactive auto-login Aqua/WindowServer session** with UI automation pre-enabled (`automationmodetool enable-automationmode-without-authentication`) on a low-res emulated display — no Xvfb-style virtual display needed. ✅ The accurate description is **"a single *shared*, auto-login GUI session with no human to arbitrate focus,"** not "headless." The real defect is **not absence of a GUI** — it's that a native AppKit app **cannot *reliably* own the shared host session** (key-window + first-responder + the one system menu bar + the one `NSPasteboard`) at the instant XCUITest synthesizes input. So it is **unreliable, not impossible** (✅ confirmed by `testBasicTypedEcho` passing — the app *can* be frontmost-typable; the pass/fail split vs `testFocusTyping…` is a focus *race*, mechanism unconfirmed — the earlier alphabetical-ordering guess is **dropped** as ❓ speculation since every test relaunches the app).

### 10b. iOS-sim vs macOS-native — the inference is invalid ✅

"GitHub supports iOS Simulators for UI testing, therefore macOS-native UI testing works too" **does not hold**. An iOS-sim XCUITest runs inside CoreSimulator's **own isolated window server** (no shared menu bar, no frontmost contention, no shared pasteboard); a native macOS XCUITest runs on the **shared host** session where all of that is contended. They share only the runner image + Xcode toolchain. (`automationmodetool` exists *only* for macOS-host automation — iOS-sim doesn't need it.)

### 10c. OSS evidence — "impossible on hosted CI" is refuted, but the field avoids it

Per-repo reads (one agent each): **1 robust · 1 flaky · 6 avoid · 1 explicit opt-out.**

| Project | macOS UITests on hosted CI? | Drives menu/kbd/clipboard? | Verdict |
|---|---|---|---|
| **DuckDuckGo `apple-browsers`** | ✅ yes (`macos-26-xlarge`) | ✅ **robustly** — `test_findInPage_canBeOpenedWithMenuBarItem` (the analogue of xtty's failing Find), `NSPasteboard`+Cmd+V, Cmd-key-equiv tab/window | **the genuine counter-example** |
| **Maccy** (clipboard mgr) | ⚠️ fork only | yes (Cmd+V, hotkeys) | ~54% red, every mitigation knob on — *not* robust |
| alt-tab / Rectangle / NetNewsWire / stats / Ice | ❌ no | — | avoid: hostless logic unit tests |
| Automattic Simplenote | ❌ (self-hosted BuildKite) | — | avoids hosted |
| **Ghostty** (native terminal — closest peer) | ❌ **deliberately excludes** XCUITests from CI | (IDE only) | runs only `zig build test` |

So your challenge is **technically vindicated by DuckDuckGo** (✅ refutes "impossible") — but DDG **pays for it**: a11y-identifiers on every NSMenuItem, click-first + wait-for-focus, `typeKey` over `typeText`, existence-first timeouts, `-retry-tests-on-failure -test-iterations 2`, fixed 1920×1080, **an `xlarge` runner + a notarized build**. The prevailing practice among comparable peers (especially Ghostty, a native macOS terminal) is to **avoid hosted-CI GUI testing**.

### 10d. Per-test diagnosis (all `file:line`-grounded; verified against the real run `28425122861`)

| Test | Root cause | Fix |
|---|---|---|
| split / directional-focus / churn | Cmd+D/W/Opt-arrow menu key-equivs need frontmost → never land (churn: a landed Cmd+W closes the sole pane → quit-escalation → "Application not running") | one **`XTTY_TEST_MUX_OP`** env-trigger through the real `paneRequestsSplit/Close/FocusMove`; DEBUG-only last-pane-close guard |
| find bar | `menuItems["Find…"].click()` — menu bar belongs to the frontmost app | **a11y-identifier on the NSMenuItem + `menuItems[id].click()`** (DDG primitive — keeps it a real menu test) ‖ or an `XTTY_TEST_FIND` trigger through SwiftTerm's real `performFindPanelAction` |
| multi-line paste | Cmd+V (Edit▸Paste key-equiv) doesn't fire | **`XTTY_TEST_PASTE_PATH`** trigger seeds pasteboard in-app + `view.paste(self)` (real bracketed-paste path) |
| truecolor/emoji | emoji block arrived via Cmd+V | test-only: typed `printf '\xf0\x9f\x9a\x80'` hex bytes (mirrors the passing ASCII printf) |
| focus-on-activate | asserts activate-without-click reliably focuses — genuinely unreliable on the shared session | **rewrite** (click-first + rename) or move IDE/local-only; *not* a tautology-trigger |

### 10e. The refined recommendation — a **hybrid**, not "env-triggers everywhere"

The decisive xtty-specific constraint: **xtty's terminal content view is custom-drawn and exposes nothing to accessibility** — so for terminal *content* assertions, xtty *cannot* use DDG's a11y-element approach; the grid/state-dump side channel is the **only** path there (this is also why Ghostty's side-channel posture fits a terminal). But menu items live in the menu bar (separate from the content view), so **a11y-IDs work for those**.

1. ✅ **Keep the env-trigger + grid-dump side channel as the primary gate** (mainstream-correct for a custom-drawn terminal; the only option for content/no-a11y).
2. ✅ **Adopt DDG's primitives for the few must-drive-real-GUI tests** — a11y-identifiers on the NSMenuItems + `menuItems[id].click()` (Find), a click-first + wait-for-focus helper, `typeKey` > `typeText`. Keeps Find/paste *real*.
3. ✅ **Rewrite `testFocusTypingOnActivateWithoutClicking`** (asserts an unreliable property) — click-first+rename or IDE/local-only.
4. ✅ **Keep the GUI job non-blocking + `-retry-tests-on-failure`**; `test-core` stays the only required gate. Add `paths-ignore` (`research/**`, `openspec/**`, `**/*.md`) so docs-only pushes don't burn the ~8-min GUI run.
5. ❌ **Don't** declare hosted-CI menu/clipboard testing impossible (DDG refutes it), and **don't** make the full GUI suite a hard hosted-CI gate (every peer except DDG avoids that, and DDG pays an `xlarge`+notarized+retry tax).

### 10f. OpenSpec mapping + caveats

- **Change shape:** a single `harden-xcuitests-for-ci` with **one `verification-harness` spec delta** (the new DEBUG triggers + dump fields + a11y-IDs are harness observability; no product-capability behavior changes). Effort small–medium; sequence high-confidence cluster first.
- **Iteration tax:** the frontmost condition **can't be reproduced locally** — but the env-trigger fixes are frontmost-*independent*, so a local `make test` pass faithfully predicts CI for those; **batch all fixes into one push**; make the repo public first. A faithful local headless mirror would need a **Tart** macOS VM (heavyweight; `act` can't do macOS).
- **Verify-before-acting (critic):** confirm a11y-IDs added to xtty's NSMenuItems actually make `menuItems[id]` resolve on the runner; the quake `NSPanel` may focus differently than a normal window (check `XttyQuickTerminalUITests` separately); DDG's robustness used an `xlarge`+notarized build at 1920×1080 — the delta to xtty's ad-hoc/default-runner posture may matter; the churn "Application not running" is a contention/lifecycle symptom (confirmed from the log) but the exact chain is inferred; re-run `testBasicTypedEcho` N× to confirm its pass is reliable, not itself intermittent.
- **Status:** planned, **not yet proposed** (`add-ci-pipeline` stays open; this is its follow-up).

### 10g. Primary sources for the focus-on-activate / frontmost mechanism (sourced 2026-06-30)

The claim that a native macOS app **can't reliably self-activate on a CI runner** (so menu key-equivalents, the menu bar, and focus-on-activate are unreliable) is a synthesis of documented mechanisms + community evidence — there is **no single official "CI can't run macOS UI tests" statement**:
- ✅ **macOS 14 made activation *cooperative*** — the load-bearing anchor. `activate(ignoringOtherApps:)` is **deprecated**; only the *currently-active* app can `yieldActivation(to:)` another, so a test-launched/background app **cannot force itself frontmost**. On a CI session there's no cooperating active app to yield → activation isn't guaranteed. ([activate(ignoringOtherApps:) — deprecated](https://developer.apple.com/documentation/appkit/nsapplication/activate(ignoringotherapps:)), [WWDC23 "What's new in AppKit"](https://developer.apple.com/videos/play/wwdc2023/10054/), [yieldActivation(to:)](https://developer.apple.com/documentation/appkit/nsapplication/yieldactivation(to:)))
- ✅ **XCUITest typing requires keyboard focus** — the *"Neither element nor any descendant has keyboard focus"* error, cured by **click/tap-first**. ([typeText(_:)](https://developer.apple.com/documentation/xctest/xcuielement/1500968-typetext), [forum 11520](https://developer.apple.com/forums/thread/11520), [forum 5910](https://developer.apple.com/forums/thread/5910)) — *(caveat: some threads are iOS-Simulator context; the focus requirement is general, the "Connect Hardware Keyboard" fix is simulator-only.)*
- ✅ **The system menu bar shows the *active* app's `mainMenu`** — so a non-active app's menu items aren't queryable (why `menuItems["Find…"]` returned "No matches"). A consequence of the activation point above. ([NSApplication](https://developer.apple.com/documentation/appkit/nsapplication))
- ❓ **"It's flaky on hosted CI" is community-reported + empirical (our run + the §10c field study), not officially specified.** ([GitHub community discussion #65667](https://github.com/orgs/community/discussions/65667), [Apple XCTest forums](https://developer.apple.com/forums/tags/xctest))
- The **"run it locally/IDE-only, skip on CI"** conclusion is a practice recommendation following peer behavior (Ghostty), not a spec.

---

## 11. Addendum (2026-07-01) — artifact-level re-investigation of run `28425122861` (first read of the actual screenshots/grid-dumps; corrects §9–§10)

*Method: downloaded **both** `.xcresult` artifacts (attempt 1 `7972842439` + attempt 2 `7987195834`, ~137 MB each) and exported all ~210 attachments per attempt with `xcrun xcresulttool export attachments` — screenshots, grid dumps, UI hierarchies, screen recordings. §9/§10 reasoned from the **text logs only**; this is the first read of the on-screen evidence. Env (both attempts): **Apple Virtual Machine, macOS 26.4 (25E246)**, on two **different** VM hosts (att1 `sjc22-bt143…`, att2 `iad20-eo1205…`) → host-reproducible, not a one-off.*

**Authoritative per-test counts** (from the xcresult, both attempts identical): **30 passed / 7 failed / 1 skipped** = 38 distinct tests; **52 runs** incl. `-retry-tests-on-failure` (each failure failed all 3 attempts → deterministic, not flaky-within-a-run). Refines §9's "34/41" framing (counted differently). The failing **set** flips by one between attempts — att1 fails `testFocusTypingOnActivateWithoutClicking`, att2 fails `testNewTabOpensAndLastPaneCloseEscalates`; the other 6 are common — the signature of two independent timing races (below).

### 11a. NEW factor §9/§10 missed — the runner's login shell is `/bin/bash` ✅

Every grid dump + screenshot shows the macOS bash deprecation banner (prompt is `runner$`, not zsh `%`):
```
The default interactive shell is now zsh.
To update your account to use zsh, please run `chsh -s /bin/zsh`.
For more details, please visit https://support.apple.com/kb/HT208050.
```
Consequences, all visible in the artifacts: it (a) **corrupts the grid** (command output overwrites the banner mid-line — e.g. `ORANGE5724your account to use zsh…`), (b) **races the test's typed input**, and (c) leaves the app's **zsh OSC shell-integration inert** — passing tests carry attachments literally named `semantic-capture-inactive (host zsh config?)`. None of §9/§10 mention the shell; it is a distinct, cheap-to-fix environmental factor (`BASH_SILENCE_DEPRECATION_WARNING=1`, `~/.hushlogin`, or force a clean zsh for the test session).

### 11b. CORRECTION to §10e/§10g — `testFocusTypingOnActivateWithoutClicking` is a **false negative**, not an "unreliable property" ❌→✅

> **Mechanism corrected by §12 (2026-07-01):** the conclusion below (focus works; false negative; keep the test) is **confirmed and strengthened**, but the *cause* of the marker split is **not** the banner — the post-fix run is banner-free and the marker **still wraps** (the long ~72-char CI hostname prompt pushes it across a row boundary). So the fix is a **wrap-tolerant assertion**, not "silence the banner." See §12b.

§10e/§10g concluded focus-on-activate is "genuinely unreliable on the shared session" and recommended **rewrite/abandon**. The artifacts **refute** that. The test `app.activate()` then `app.typeText("XTTYFOCUS<n>")` and asserts `GridDumpReader.waitForContains(marker)` (`AppUITests/XttyUITests.swift:36–47`). Evidence (`focus-typing-typed` png + grid dumps):
- The marker **reaches the terminal and is visible on-screen** — focus-on-activate **works**.
- It fails in att1 **only** because the async bash banner **splits the marker across a line wrap**: `runner$ X` then `TTYFOCUS6366interactive shell is now zsh.` — so the contiguous substring `XTTYFOCUS6366` doesn't exist → `.contains()` fails.
- In att2 the same marker lands contiguous (`XTTYFOCUS3141nteractive…`) → **passes**.

So the correct fix is **silence the shell banner** (11a) and keep the test — it is a *valid* focus test defeated by grid noise, not a tautology to delete. (This also explains why this specific test flips between attempts.)

### 11c. CONFIRMS §10d's Cmd+V diagnosis — paste + emoji, with screenshots (and corrects §9's "rendering/locale") ✅

Both `testMultiLinePasteIsNotAutoExecuted` and the i18n half of `testTruecolorEmojiAndWideChars` deliver content via **`NSPasteboard` + `typeKey("v", .command)`** (Cmd+V = Edit▸Paste key-equiv) — `AppUITests/XttyUITests.swift:65` and `:206–210`. On the VM the paste **doesn't fire**, so `alpha…/beta…` and `echo … 🚀 日本語 ✅` never land:
- **truecolor passes its own assertion** — `printf …ORANGE<tag>` is *typed* (ASCII) and `ORANGE<tag>` is in the grid; only the **Cmd+V-pasted** 🚀/CJK line is missing. → **not a font/`characterProvider` or locale gap** (corrects §9's "rendering/locale" outlier and the test's own `characterProvider not applied?` message); it's the same Cmd+V failure as the paste test.
- This **vindicates §10d** ("emoji block arrived via Cmd+V") with direct evidence — and supersedes the looser "bash race ate the emoji" hypothesis floated mid-investigation.

### 11d. CONFIRMS Bucket B (Cmd-key menu key-equivalents) for mux/churn — with screenshots ✅

- `testDirectionalFocusMovesBetweenPanes` end-state (`after-focus-left` png): xtty **active + frontmost** (menu bar = xtty) but still **one pane** — `Cmd+D` produced no split. `paneCount` stays 1 → `waitForState{==2}` returns nil → the `"nil" ≠ "Optional(2)"` assert. (So the `nil` is "state never changed," and the dump mechanism itself works — the launch-guard `waitForState != nil` passed.)
- `testSplitCreatesAndClosesPanes` `after-close` png: **Finder desktop, no xtty window** — a later `Cmd+W` closed the sole pane → window → **app quit** (and `testLifecycleChurn…` likewise reports "Application not running"). The quit-escalation chain §10d inferred is confirmed on-screen.

### 11e. REFINES find-bar (§10d/§10g) — xtty **does** own its menu bar

The failure UI hierarchy shows xtty's own `MenuBarItem`s present — **`xtty / View / Window / Help`** — so "the menu bar belongs to the frontmost app / a non-active app's items aren't queryable" is too strong as stated for xtty. What's actually true in the failing snapshot: the whole app element is `Disabled` (not key/active) and there is **no Edit menu**, so the `menuItems["Find…"]` query finds nothing. Still Bucket B (menu-command/activation), but the precise mechanism is "menu won't open / app not key," not "xtty doesn't own the bar."

### 11f. Re-bucketed, evidence-grounded — and the revised `harden-xcuitests-for-ci` sequencing

| Bucket | Tests | Cause | Fix |
|---|---|---|---|
| **A — bash banner grid corruption** (environmental) | `focus-typing` (proven false neg) + grid noise + dead zsh shell-integration | runner login shell = `/bin/bash` | **silence/replace the shell** — fixes focus-typing + de-flakes + re-enables semantic capture; cheapest win |
| **B — Cmd-key menu key-equivalents don't fire on the shared VM session** (genuine, the §10 thesis — now visually confirmed) | paste, truecolor-emoji (both Cmd+V); split, directional, new-tab (Cmd+D/T/Opt-arrow); churn; find-bar (menu click) | a native app can't *reliably* own the shared host session's key-window/menu-bar the instant XCUITest fires (§10a/§10g mechanism) | §10e hybrid: env-triggers through the real handlers + a11y-IDs on NSMenuItems + click-first + `typeKey` |

**Honest correction to the mid-investigation summary:** the dominant factor **by count** is **Bucket B** (6 of 7 failures involve a Cmd-key/menu key-equivalent) — §10's core thesis stands and is now screenshot-confirmed. The bash shell (Bucket A) is a **real but smaller** addition: it cleanly explains exactly **one** hard failure (focus-typing) plus the flaky membership and the inert shell-integration. Earlier in this investigation the bash race was over-credited for truecolor/paste; the test source shows those are Cmd+V (Bucket B).

**Revised sequencing for `harden-xcuitests-for-ci`:** (1) **fix the shell first** — flips focus-typing, kills the flaky membership, restores semantic-capture coverage, removes banner noise from every grid; then (2) the residual is **pure Bucket B** — scope the hybrid hardening to Cmd-key/menu delivery (env-triggers + a11y-IDs), **not** fonts, locale, pasteboard *content*, or menu-bar *ownership* (all three ruled out here). Keep the GUI job non-blocking; `test-core` stays the only required gate.

> **Update (2026-07-01) — step (1) shipped as `silence-bash-deprecation`.** A follow-on `/opsx:explore` corrected the "one CI env line" assumption above: `ShellResolver.seedEnvironment` hands the child shell a **curated** env (only `TERM`/`COLORTERM`/`LANG`/`HOME`/`USER`/`LOGNAME`), so a `ci.yml`/`launchEnvironment` setting is **stripped before the shell starts** and silently no-ops. The fix is a **product** one-liner — seed `BASH_SILENCE_DEPRECATION_WARNING=1` for bash login shells (gated to `base == "bash"`, before the `override.env` merge so a profile `env` still wins) — which *also* fixes the same banner for every real bash user, not just CI. Implemented + unit-tested in `ShellResolver`/`ShellResolverTests` (235 `XttyCore` tests green); modifies the `terminal-session` "Shell resolution and launch configuration" requirement. Step (2) — the Bucket-B `harden-xcuitests-for-ci` — remains the separate, harder follow-up. **The post-merge CI run measured the actual effect of step (1) → §12 (it de-noised every grid but flipped *zero* tests green; the §11f "fix the shell first → focus-typing flips green" prediction is REFUTED).**

---

## 12. Addendum (2026-07-01) — `silence-bash-deprecation` measured in CI: banner gone, but focus-typing still fails (the §11f prediction refuted)

> **Provenance:** 2026-07-01. Empirical — read the `.xcresult` artifact of the **post-merge** run **`28467944762`** (head = the `silence-bash-deprecation` archive commit, `macos-26`, Apple VM 26.4/25E246), the first CI to include the fix. `gh run download 28467944762`; unpacked with `xcrun xcresulttool get test-results summary` + `… export attachments`; grepped all **221** attachments for the banner text; cross-read `AppUITests/XttyUITestSupport.swift` (`GridDumpReader.waitForContains`).

**Result: the fix works — and it flips zero tests green.** Counts are unchanged at **30 pass / 7 fail / 1 skip** (same as `28425122861`). `test-core` stays green (the required gate); `build-and-test` stays non-blocking red.

### 12a. ✅ The banner is gone from **100%** of grids
`grep` for `default interactive shell is now zsh` / `chsh -s /bin/zsh` / `HT208050` across all 221 exported attachments → **0 hits** (was pervasive in `28425122861`). Bucket A's **grid corruption is resolved**; every grid dump is now clean (e.g. the paste grid is a bare `…runner$` with no banner above it). This is the real, durable win — and it lands for **every** bash user, not just CI.

### 12b. ❌→ The §11b *mechanism* was wrong, and the §11f *prediction* is REFUTED — focus-typing still fails
§11b attributed the focus-typing false negative to **the banner** splitting the marker, and §11f predicted "fix the shell first → focus-typing flips green." **Both are refuted by the banner-free run:** `testFocusTypingOnActivateWithoutClicking` **still fails**, and the grid dump shows why —
```
sjc22-be113-ee403fcc-402e-4029-abb6-4b1aad69eb0d-E68CD1ABBBB3:/ runner$ X
TTYFOCUS331
```
The marker `XTTYFOCUS331…` **does** reach the grid (the `focus-typing-typed` screenshot shows it on-screen — **focus-on-activate genuinely works**), but the runner's **~72-char hostname prompt** (`\h:\w \u\$` with a long virtual-host name) fills the row, so the marker wraps at the terminal's right edge: `X` ends the prompt row, `TTYFOCUS331…` spills to the next. `GridDumpReader.waitForContains` does a raw `text.contains(needle)` over rows joined by `\n`, so `X\nTTYFOCUS331…` can never match the contiguous `XTTYFOCUS331…`. **The split was never the banner — it's the long CI prompt wrapping the marker.** The banner *also* split it in `28425122861` (hence the att1/att2 flip §11b saw), which masked the real, independent cause.

So the §11b **conclusion stands and is strengthened** (focus works; it's a false negative; keep the test) but its **cause is corrected**, and the **fix changes**: not "silence the banner" (done, didn't help here) but **make the assertion wrap-tolerant** — strip newlines/whitespace before the `contains` check (or add a `waitForContainsIgnoringWraps`). This is a tiny harness-robustness fix, independent of the Cmd/menu work, and belongs to `harden-xcuitests-for-ci`.

### 12c. Residual, re-bucketed against the banner-free baseline
The 7 failures are now cleanly **6 Bucket-B + 1 false-negative-wrap** (Bucket A retired):

| # | Test | Bucket | Cause (banner-free run) |
|---|---|---|---|
| 1 | `testFocusTypingOnActivateWithoutClicking` | wrap (false neg) | long CI prompt wraps the typed marker across rows → 12b |
| 2 | `testDirectionalFocusMovesBetweenPanes` | B | Cmd+arrow / Cmd+D split didn't fire (`nil ≠ Optional(2)`) |
| 3 | `testNewTabOpensAndLastPaneCloseEscalates` | B | Cmd+T didn't open a 2nd tab |
| 4 | `testLifecycleChurnReturnsCensusToBaseline` | B | Cmd+T/D churn → "Application not running" |
| 5 | `testMultiLinePasteIsNotAutoExecuted` | B | Cmd+V paste didn't land (paste grid empty) |
| 6 | `testTruecolorEmojiAndWideChars` | B | non-BMP/CJK line is Cmd+V-pasted → didn't land (truecolor's *typed* half passes) |
| 7 | `testFindBarOpensLocatesAndDismisses` | B | Edit▸Find menu item not clickable |

### 12d. Net + revised sequencing for `harden-xcuitests-for-ci`
- **Step (1) `silence-bash-deprecation` was still the right call** — it de-noised 100% of CI grids and fixes a real papercut for all bash users — but it is **not sufficient to green any CI test**. The §11f framing of it as "the cheapest win that flips focus-typing" overstated its CI effect; its true CI value is **de-noising + restoring zsh shell-integration coverage** (the runner shell is `bash`, so the ZDOTDIR injection still won't run there — that needs a step that actually launches zsh under test).
- **The residual `harden-xcuitests-for-ci` is two independent fixes:** (a) **focus-typing** → a one-line wrap-tolerant assertion (cheap, do first now that its true cause is known); (b) **the 6 Bucket-B** → the §10e/§11f hybrid (env-triggers through real handlers + a11y-IDs on NSMenuItems + click-first + `typeKey`) for Cmd-key/menu delivery on the shared VM session. Keep the GUI job non-blocking; `test-core` stays the only required gate.

> **Update (2026-07-01) — focus-typing (#1) carved out and implemented as `harden-focus-typing-assertion`.** The cheap fix (a) shipped as its own change: a scoped, opt-in wrap-tolerant matcher (`GridDumpReader.gridContains(_,_,ignoringLineWraps:)` + `waitForContains(…, ignoringLineWraps:)`) used only by the focus test; test-only, no product code, no SwiftTerm patch; one `verification-harness` ADDED requirement. Local `make test` confirmed `testFocusTypingOnActivateWithoutClicking` passes (the local prompt is short → trivial path) and no strict-default caller regressed. The 6 **Bucket-B** failures remain the harder follow-up — and that same local run surfaced the concrete mechanics of one of them (the churn test #4) → **§13**.

---

## 13. Addendum (2026-07-01) — local `make test` of the churn test (#4): the confirm-close race + a multi-monitor recording artifact

> **Provenance:** 2026-07-01. Empirical — ran `make test` locally while implementing `harden-focus-typing-assertion`; `testLifecycleChurnReturnsCensusToBaseline` failed (`baseline 1 → final 2`). Investigated the `.xcresult` (`build/Logs/Test/…xcresult`: `export attachments`, the per-test attachment timeline, the screen-recording `.mp4` via `ffmpeg`) and the source (`AppUITests/XttyLifecycleCensusUITests.swift`, `App/TerminalWindowController.swift`). The user **eyewitnessed** the modal during the run.

### 13a. ✅ Root cause of the churn flake (Bucket-B #4) — a confirm-close modal races the freshly-split shell's startup

The churn test splits then closes immediately, waiting only for `paneCount == 2` (the pane is **registered**), not for the new shell to reach its prompt (`XttyLifecycleCensusUITests.swift:42-46`). When `Cmd+W` fires, the new pane's shell is still **sourcing its startup files**, so `hasForegroundJob` (`TerminalWindowController.swift:474`, `tcgetpgrp(fd) != shellPid`) is **true** — a startup child owns the PTY foreground — and `confirmClose()` (`:483`) puts up an `NSAlert` ("Close this pane? / A process is still running"). `runModal()` **blocks the main thread**, the close never completes, the pane survives → census `final 2` (one extra `PaneController` + `XttyTerminalView` + `TerminalSession`, exactly one pane's worth). Locally the user's `~/.zshrc` makes the startup window wide (`go env $(…)`, `eval "$(zoxide init zsh)"`, `. $(pack completion)`, oh-my-zsh, `compinit`, nvm — each a foreground child). Corroborating artifact evidence: the Synthesized-Event **timeline** shows the early churn ops firing fast (02.35.16-18) then four ~5 s gaps (02.35.24/29/34/40) = four `waitForState(timeout: 5)` timeouts after the app froze behind the modal.

**Relation to CI #4:** on CI the same test fails as "Application not running" — a *different* symptom (there the `Cmd+W` escalation quit the app) but the same family (a synthesized-close drive-path hazard on a not-yet-settled shell). The local run gives the precise modal mechanism.

**Fix (test-side, for `harden-xcuitests-for-ci`):** the churn test exercises *lifecycle teardown*, not the confirm dialog, so it should opt out — **`launchConfigured(config: "confirm-close = false")`** (cleanest, deterministic) or wait for the split pane's shell-prompt-ready before `Cmd+W`. A **product** angle exists but is **rejected as the fix**: confirm-close firing during a pane's *own* shell startup is a false positive, but distinguishing a startup child from a real foreground job cleanly is hard — fix the test, not the product.

### 13b. ❓→✅ Why the local `.xcresult` screenshots/recording were useless — built-in-display placement vs. XCUITest recording the *main* display

The screen-recording `.mp4` and the `after-churn` screenshot showed the **editor desktop**, not xtty — so the popup pixel was unobservable locally. Cause: **two independent behaviors collide on a multi-monitor dev machine.** xtty forces every window onto the **built-in** display (`TerminalWindowController.positionOnBuiltInDisplay()` `:152/:657`, via `CGDisplayIsBuiltin`) — the "open on the MacBook screen" preference — while **XCUITest records the *main/primary* display** (the one with the menu bar), which on this desk is the **external** monitor. App on built-in, camera on external → the recording captures the wrong screen.

**This is a dev-machine-only artifact:** CI runners have **one** display (built-in == main), so the *CI* `.xcresult` recordings **do** show xtty (as §11/§12 used). It does **not** affect CI pass/fail and is **not** a cause of any of the 7 failures — only of local artifact blindness. **Local observability fixes:** (1) no-code — set the **built-in display as Primary** (drag the menu bar) or unplug the external; (2) small-code (a companion to the `harden-xcuitests-for-ci` churn fix) — **skip `positionOnBuiltInDisplay()` under test** (DEBUG + a `-UITestGridDump`/`-UITestNoDisplayPlacement` guard) so the app stays on the recorded display; harmless to production.

---

## Sources

- **xtty repo:** `Makefile`, `project.yml`, `scripts/bootstrap-swiftterm.sh`, `patches/swiftterm/UPSTREAM_CONFIG.sh` + `xtty-accessors.diff`, `.gitignore`, `XttyCore/Package.{swift,resolved}`, `AppUITests/*` (StateDumpReader/GridDumpReader, `XTTY_*` triggers), `AGENTS.md`
- **§11 artifact evidence (2026-07-01):** the two `.xcresult` artifacts of run `28425122861` (`gh api repos/kitimark/xtty/actions/runs/28425122861/artifacts`, ids `7972842439`/`7987195834`), unpacked + read with `xcrun xcresulttool get test-results summary` and `… export attachments` (screenshots, grid dumps, `App UI hierarchy`, screen recordings); cross-checked against `AppUITests/XttyUITests.swift` + `XttyMultiplexingUITests.swift` + `XttyUITestSupport.swift`
- **§12 artifact evidence (2026-07-01):** the `.xcresult` of the **post-merge** run `28467944762` (head = the `silence-bash-deprecation` archive commit), `gh run download`; `xcrun xcresulttool … summary` + `… export attachments`; `grep` of all 221 attachments for the banner text (0 hits); `focus-typing-grid`/`focus-typing-typed`/`paste-grid` dumps + `GridDumpReader.waitForContains` (`XttyUITestSupport.swift:117–121`)
- **§13 evidence (2026-07-01):** the **local** `make test` `.xcresult` (`build/Logs/Test/…xcresult`) — `export attachments` + the per-test attachment timeline (Synthesized Events / UI Snapshots) + the churn screen-recording `.mp4` (frames via `ffmpeg`); the user's eyewitness of the modal; `AppUITests/XttyLifecycleCensusUITests.swift`, `App/TerminalWindowController.swift` (`hasForegroundJob`/`confirmClose`/`positionOnBuiltInDisplay`), and `~/.zshrc` startup commands
- **GitHub:** docs.github.com (Actions billing for public repos, standard vs larger runners, `macos-*` labels), the **`actions/runner-images`** repo (macos-26 README + software manifest, `Install-Xcode.ps1` Metal `-ge 26` gate, runner-image issues #13014 / #13080 / #13094), `actions/cache`, `maxim-lobanov/setup-xcode`, `irgaly/xcode-cache`, `softprops/action-gh-release`, `ncipollo/release-action`, `amannn/action-semantic-pull-request`
- **OSS workflows (read):** Ghostty `.github/workflows/release-tip.yml` (Namespace runners + codesign/notarize), `MrKai77/Loop` `dev-build.yml` (GitHub-hosted full notarize), `FlashSpace` `ci.yml`/`pr.yml` (XcodeGen + Conventional-Commit lint), Americano/Thaw/Mythic/Stats (cache keys + secret-free `CODE_SIGNING_ALLOWED=NO`)
- **Companion:** [`distribution-signing-research.md`](distribution-signing-research.md) (the $0/Homebrew/$99 distribution arc this CI release seam plugs into)
