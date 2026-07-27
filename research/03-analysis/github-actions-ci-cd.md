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
- **Iteration tax:** the frontmost condition **can't be reproduced locally** — but the env-trigger fixes are frontmost-*independent*, so a local `make test` pass faithfully predicts CI for those; **batch all fixes into one push**; make the repo public first. A faithful local headless mirror would need a **Tart** macOS VM (heavyweight; `act` can't do macOS — source-verified 2026-07-03, see [`local-macos-vm-ci-reproduction.md`](local-macos-vm-ci-reproduction.md) §7, which also plans exactly that VM).
- **Verify-before-acting (critic):** confirm a11y-IDs added to xtty's NSMenuItems actually make `menuItems[id]` resolve on the runner; the quake `NSPanel` may focus differently than a normal window (check `XttyQuickTerminalUITests` separately); DDG's robustness used an `xlarge`+notarized build at 1920×1080 — the delta to xtty's ad-hoc/default-runner posture may matter; the churn "Application not running" is a contention/lifecycle symptom (confirmed from the log) but the exact chain is inferred; re-run `testBasicTypedEcho` N× to confirm its pass is reliable, not itself intermittent.
- **Status:** planned, **not yet proposed** (`add-ci-pipeline` stays open; this is its follow-up).

### 10g. Primary sources for the focus-on-activate / frontmost mechanism (sourced 2026-06-30)

> **Superseded for xtty by §15 (2026-07-03):** the activation/menu-ownership mechanism below turned out not to be xtty's problem — the app was frontmost and key-focused in every failure; the shortcuts died because the custom menu itself had been replaced by SwiftUI's default menu (a product bug). The sources remain valid general background.

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

> **Mechanism re-attributed by §15 (2026-07-03):** the splits didn't happen because the "Split Right"/"New Tab" menu items **didn't exist** (SwiftUI default-menu clobber), not because the session dropped the key-equivalents — and the quit was the **default Window ▸ Close**, not xtty's escalation.

### 11e. REFINES find-bar (§10d/§10g) — xtty **does** own its menu bar

The failure UI hierarchy shows xtty's own `MenuBarItem`s present — **`xtty / View / Window / Help`** — so "the menu bar belongs to the frontmost app / a non-active app's items aren't queryable" is too strong as stated for xtty. What's actually true in the failing snapshot: the whole app element is `Disabled` (not key/active) and there is **no Edit menu**, so the `menuItems["Find…"]` query finds nothing. Still Bucket B (menu-command/activation), but the precise mechanism is "menu won't open / app not key," not "xtty doesn't own the bar."

> **§15 (2026-07-03) completes this:** that bar — `[xtty, View, Window, Help]` with no Edit/Terminal/Debug — **is SwiftUI's scene-synthesized default menu**, not a partially-queryable custom menu. The Edit menu wasn't unqueryable; it was genuinely absent. §11e was the smoking gun, unrecognized because the menu's *contents* were never compared against `MainMenu.swift`.

### 11f. Re-bucketed, evidence-grounded — and the revised `harden-xcuitests-for-ci` sequencing

| Bucket | Tests | Cause | Fix |
|---|---|---|---|
| **A — bash banner grid corruption** (environmental) | `focus-typing` (proven false neg) + grid noise + dead zsh shell-integration | runner login shell = `/bin/bash` | **silence/replace the shell** — fixes focus-typing + de-flakes + re-enables semantic capture; cheapest win |
| **B — Cmd-key menu key-equivalents don't fire on the shared VM session** (genuine, the §10 thesis — now visually confirmed) | paste, truecolor-emoji (both Cmd+V); split, directional, new-tab (Cmd+D/T/Opt-arrow); churn; find-bar (menu click) | a native app can't *reliably* own the shared host session's key-window/menu-bar the instant XCUITest fires (§10a/§10g mechanism) | §10e hybrid: env-triggers through the real handlers + a11y-IDs on NSMenuItems + click-first + `typeKey` |

**Honest correction to the mid-investigation summary:** the dominant factor **by count** is **Bucket B** (6 of 7 failures involve a Cmd-key/menu key-equivalent) — §10's core thesis stands and is now screenshot-confirmed. The bash shell (Bucket A) is a **real but smaller** addition: it cleanly explains exactly **one** hard failure (focus-typing) plus the flaky membership and the inert shell-integration. Earlier in this investigation the bash race was over-credited for truecolor/paste; the test source shows those are Cmd+V (Bucket B).

**Revised sequencing for `harden-xcuitests-for-ci`:** (1) **fix the shell first** — flips focus-typing, kills the flaky membership, restores semantic-capture coverage, removes banner noise from every grid; then (2) the residual is **pure Bucket B** — scope the hybrid hardening to Cmd-key/menu delivery (env-triggers + a11y-IDs), **not** fonts, locale, pasteboard *content*, or menu-bar *ownership* (all three ruled out here). Keep the GUI job non-blocking; `test-core` stays the only required gate.

> **Bucket B's mechanism is overturned by §15 (2026-07-03):** the chords no-oped because xtty's custom menu was **clobbered by SwiftUI's default menu** (a per-launch race, a product bug) — delivery and dispatch on the runner were fine. The §10e/§11f "hybrid delivery hardening" (incl. a11y-ID menu clicks) would **not** have fixed it: the items weren't in the menu to click. See §15e for the reshaped plan.

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

> **Causes re-attributed by §15 (2026-07-03):** every "B" row below traces to the SwiftUI main-menu clobber (the key-equivalent items didn't exist), not to session-level key delivery.

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

> **Update (2026-07-01) — focus-typing (#1) carved out and implemented as `harden-focus-typing-assertion`.** The cheap fix (a) shipped as its own change: a scoped, opt-in wrap-tolerant matcher (`GridDumpReader.gridContains(_,_,ignoringLineWraps:)` + `waitForContains(…, ignoringLineWraps:)`) used only by the focus test; test-only, no product code, no SwiftTerm patch; one `verification-harness` ADDED requirement. Local `make test` confirmed `testFocusTypingOnActivateWithoutClicking` passes (the local prompt is short → trivial path) and no strict-default caller regressed. The 6 **Bucket-B** failures remain the harder follow-up — and that same local run surfaced the concrete mechanics of one of them (the churn test #4) → **§13**. **The CI green-flip is now CONFIRMED → §14a** (run `28472076179`).

---

## 13. Addendum (2026-07-01) — local `make test` of the churn test (#4): the confirm-close race + a multi-monitor recording artifact

> **Provenance:** 2026-07-01. Empirical — ran `make test` locally while implementing `harden-focus-typing-assertion`; `testLifecycleChurnReturnsCensusToBaseline` failed (`baseline 1 → final 2`). Investigated the `.xcresult` (`build/Logs/Test/…xcresult`: `export attachments`, the per-test attachment timeline, the screen-recording `.mp4` via `ffmpeg`) and the source (`AppUITests/XttyLifecycleCensusUITests.swift`, `App/TerminalWindowController.swift`). The user **eyewitnessed** the modal during the run.

### 13a. ✅ Root cause of the churn flake (Bucket-B #4) — a confirm-close modal races the freshly-split shell's startup

The churn test splits then closes immediately, waiting only for `paneCount == 2` (the pane is **registered**), not for the new shell to reach its prompt (`XttyLifecycleCensusUITests.swift:42-46`). When `Cmd+W` fires, the new pane's shell is still **sourcing its startup files**, so `hasForegroundJob` (`TerminalWindowController.swift:474`, `tcgetpgrp(fd) != shellPid`) is **true** — a startup child owns the PTY foreground — and `confirmClose()` (`:483`) puts up an `NSAlert` ("Close this pane? / A process is still running"). `runModal()` **blocks the main thread**, the close never completes, the pane survives → census `final 2` (one extra `PaneController` + `XttyTerminalView` + `TerminalSession`, exactly one pane's worth). Locally the user's `~/.zshrc` makes the startup window wide (`go env $(…)`, `eval "$(zoxide init zsh)"`, `. $(pack completion)`, oh-my-zsh, `compinit`, nvm — each a foreground child). Corroborating artifact evidence: the Synthesized-Event **timeline** shows the early churn ops firing fast (02.35.16-18) then four ~5 s gaps (02.35.24/29/34/40) = four `waitForState(timeout: 5)` timeouts after the app froze behind the modal.

**Relation to CI #4:** on CI the same test fails as "Application not running" — a *different* symptom (there the `Cmd+W` escalation quit the app) but the same family (a synthesized-close drive-path hazard on a not-yet-settled shell). The local run gives the precise modal mechanism. **Update (2026-07-02): the CI mechanism is now pinned too (→ §14b) — dropped Cmd+D (Bucket B), not this modal — so the fix below greens only the *local* flake.** **Update (2026-07-03, §15d): re-attributed again — Cmd+D no-oped because the menu item didn't exist (SwiftUI clobber), and the CI quit was the *default* Window ▸ Close, which bypasses this very confirm-close gate; once the menu fix restores the gated `closePane` path, this race becomes newly reachable on CI in split/new-tab/churn — prefer wait-for-shell-ready over `confirm-close = false`.**

**Fix (test-side, for `harden-xcuitests-for-ci`):** the churn test exercises *lifecycle teardown*, not the confirm dialog, so it should opt out — **`launchConfigured(config: "confirm-close = false")`** (cleanest, deterministic) or wait for the split pane's shell-prompt-ready before `Cmd+W`. A **product** angle exists but is **rejected as the fix**: confirm-close firing during a pane's *own* shell startup is a false positive, but distinguishing a startup child from a real foreground job cleanly is hard — fix the test, not the product.

### 13b. ❓→✅ Why the local `.xcresult` screenshots/recording were useless — built-in-display placement vs. XCUITest recording the *main* display

The screen-recording `.mp4` and the `after-churn` screenshot showed the **editor desktop**, not xtty — so the popup pixel was unobservable locally. Cause: **two independent behaviors collide on a multi-monitor dev machine.** xtty forces every window onto the **built-in** display (`TerminalWindowController.positionOnBuiltInDisplay()` `:152/:657`, via `CGDisplayIsBuiltin`) — the "open on the MacBook screen" preference — while **XCUITest records the *main/primary* display** (the one with the menu bar), which on this desk is the **external** monitor. App on built-in, camera on external → the recording captures the wrong screen.

**This is a dev-machine-only artifact:** CI runners have **one** display (built-in == main), so the *CI* `.xcresult` recordings **do** show xtty (as §11/§12 used). It does **not** affect CI pass/fail and is **not** a cause of any of the 7 failures — only of local artifact blindness. **Local observability fixes:** (1) no-code — set the **built-in display as Primary** (drag the menu bar) or unplug the external; (2) small-code (a companion to the `harden-xcuitests-for-ci` churn fix) — **skip `positionOnBuiltInDisplay()` under test** (DEBUG + a `-UITestGridDump`/`-UITestNoDisplayPlacement` guard) so the app stays on the recorded display; harmless to production.

---

## 14. Addendum (2026-07-02) — `harden-focus-typing-assertion` measured in CI: the green-flip is CONFIRMED; the churn test's CI mode is pure Bucket-B (the §13 fix won't green it there)

> **Provenance:** 2026-07-02. Empirical — read the **post-merge** run **`28472076179`** (head = the `harden-focus-typing-assertion` archive commit `069fd30`, `macos-26`), the first `build-and-test` to carry the wrap-tolerant matcher, via `gh run view --log-failed` (log-level per-test verdicts + failure messages sufficed; no `.xcresult` download this time); diffed against §12's baseline run `28467944762`; cross-read `AppUITests/XttyLifecycleCensusUITests.swift` and `.github/workflows/ci.yml`.

> **Superseded in mechanism by §15 (2026-07-03):** the "Bucket B" attribution below is overturned — the chords no-oped because SwiftUI's default menu had replaced xtty's custom menu (a per-launch race; a product bug), not because the runner dropped key-equivalents. 14a is **softened** (focus-typing is P/FFF/P across runs — run 1 passed *without* the matcher, so this run's pass is consistent-with, not confirmation) and 14b/14c are **re-attributed** (the quit was the *default* Window ▸ Close; the race is per-launch/binary, not per-keystroke).

**Result: the fix works in CI — `testFocusTypingOnActivateWithoutClicking` flipped fail→pass.** Counts: **34 pass / 7 fail / 1 skip** (42 tests now that the 4 in-bundle `GridDumpReaderTests` joined; 56 executions with retries — each of the 7 failed 3/3). `test-core` stays green (the required gate); the run is red only because `build-and-test` has no `continue-on-error` — "non-blocking" is branch-protection policy, by design.

### 14a. ✅ The §12b diagnosis + fix are CONFIRMED end-to-end — focus-typing is green in CI

`testFocusTypingOnActivateWithoutClicking` **passed (5.48 s)** — it was fail-3/3 in `28467944762`. The wrap-tolerant `ignoringLineWraps` matcher greens the test against the runner's ~72-char wrapping prompt, closing the §12 arc: the "wrap" bucket is **retired**. (The pass count moved 30 → 34 because the 4 new no-app-launch `GridDumpReaderTests` also pass.)

### 14b. ✅ The churn test's **CI** failure mode ≠ the **local** §13 race — the §13 fix alone won't green it in CI

The CI log pins the mechanism: all 3 retries fail at `XttyLifecycleCensusUITests.swift:43` (`app.typeKey("d", .command)`) with **"Application com.xtty.app is not running."** Chain: **Cmd+D never registers (Bucket B)** → `paneCount` stays 1 → the test's `Cmd+W` closes the *only* pane → the close-escalation (pane → tab/window → quit) **quits the app** → the next churn iteration finds no app. So the churn test fails **two different ways**: locally via the §13a confirm-close modal (census `final 2`), in CI via dropped Cmd-key delivery (app gone). **Consequence for `harden-xcuitests-for-ci`:** the §13a fix (`confirm-close = false` / wait-for-shell-ready) greens only the **local** flake; in CI the test stays red until **Cmd-key delivery** is fixed (the same fix as the rest of Bucket B). A cheap companion: a `paneCount == 2` **precondition-abort** after the split (fail fast with "split never landed" instead of churning on) would stop the two modes aliasing each other in artifacts.

### 14c. ✅ Bucket B is per-keystroke flaky, not absolute — residual now a clean **7 Bucket-B, 0 wrap**

Two direct observations: (1) in the churn chain, **Cmd+W fired while Cmd+D didn't** — the app quit *because* the close landed; (2) `testSplitCreatesAndClosesPanes` **flaky-passed on its 3rd retry** in `28467944762` (2 fails, then green → counted pass, which is why it's absent from §12c's table) but **failed 3/3** in `28472076179`. Cmd-key delivery on the shared VM session drops keystrokes probabilistically — a test can luck through retries, so retry-tolerance masks rather than fixes. The §12c re-bucket, updated:

| # | Test | Bucket | Cause |
|---|---|---|---|
| 1 | `testDirectionalFocusMovesBetweenPanes` | B | Cmd+D split never fired |
| 2 | `testNewTabOpensAndLastPaneCloseEscalates` | B | Cmd+T never fired |
| 3 | `testSplitCreatesAndClosesPanes` | B | Cmd+D — flaked green in §12's run, 3/3 red here |
| 4 | `testLifecycleChurnReturnsCensusToBaseline` | B | Cmd+D dropped → Cmd+W quits the app → "not running" (→ 14b) |
| 5 | `testMultiLinePasteIsNotAutoExecuted` | B | Cmd+V paste never landed |
| 6 | `testTruecolorEmojiAndWideChars` | B | Cmd+V paste never landed |
| 7 | `testFindBarOpensLocatesAndDismisses` | B | Edit ▸ Find menu item not clickable |

**Net:** `harden-xcuitests-for-ci` is now a **single-bucket** change — the §10e/§11f hybrid (env-triggers through real handlers + a11y-IDs on NSMenuItems + click-first + `typeKey`) for Cmd-key/menu delivery — plus the churn test's §13a local-race opt-out and the 14b precondition-abort as companions. Keep the GUI job non-blocking; `test-core` stays the only required gate.

---

## 15. Addendum (2026-07-03) — ROOT CAUSE: **SwiftUI clobbers xtty's main menu** — "Bucket B" was xtty's own product bug, not the runner

> **Provenance:** 2026-07-02/03. Empirical + adversarially verified — downloaded run `28472076179`'s full `.xcresult` (213 attachments) and ran a **12-agent ultracode workflow**: 5 forensics agents (all six "App UI hierarchy" AX dumps + failure screenshots; paste disambiguation; churn crash-vs-quit via exported diagnostics + ffmpeg video frames; a complete `App/`+`AppUITests/` input-routing source map; cross-run pattern analysis over `28425122861`/`28467944762`/`28472076179`), 3 external-research agents (XCUITest event-synthesis mechanism; a DuckDuckGo `apple-browsers` clone deep-read; peer OSS evidence), a synthesis, and a **3-lens adversarial panel** — evidence-consistency verdict: **sound**; will-it-work + intent-preservation: partially-sound, their required changes folded into 15e/15f.

### 15a. ✅ THE ROOT CAUSE — SwiftUI's scene-synthesized default menu replaces `XttyMainMenu`

> **Mechanism refined by the executed VM PoC ([`local-macos-vm-ci-reproduction.md`](local-macos-vm-ci-reproduction.md) §8d, 2026-07-04):** "replaces the custom menu" is *literally* **in-place item mutation of the same `NSMenu` object** — SwiftUI does **not** swap the `NSApp.mainMenu` pointer (measured `mainMenuPtr == builtMenuPtr` on both host and guest; only the object's *items* differ — default `[xtty, View, Window, Help]` in the clobbered guest vs custom `[Edit, View, Terminal, Window, Debug]` on the host). The AX dumps below couldn't distinguish the two mechanisms; the VM measurement does. This changes the fix (§15e).

xtty is a SwiftUI `@main` app whose only scene is `Settings { EmptyView() }` (`App/XttyApp.swift:15-24`); the custom menu is assigned **exactly once** — `NSApp.mainMenu = XttyMainMenu.build(...)` in `applicationDidFinishLaunching` (`:58`) — and never re-asserted. SwiftUI (re)installs its own scene-synthesized default menu around launch/activation, and on the CI VM (macOS 26.4) SwiftUI's install lands **last**, replacing the custom menu for the app's entire life; locally on 26.2 the custom menu wins. It **is a race**, not a deterministic OS change: `testSplitCreatesAndClosesPanes` flaky-passed on retry 3 of the **same job/VM** in run `28467944762` (8.9 s fail / 8.8 s fail / 4.6 s pass). **The race is now PROVEN live, not just inferred ([`local-macos-vm-ci-reproduction.md`](local-macos-vm-ci-reproduction.md) §9d, 2026-07-04):** two native runs of the *identical* Tart VM + binary gave **different** results — run 1 `36/5/1` (the two Cmd+D split tests flaky-passed) vs run 2 `34/7/1` (they failed), diverging by exactly the race-sensitive tests. Every failing shortcut (Cmd+D/T/F/V, Cmd+Opt+arrows) exists **only** as a key equivalent on the custom Edit/Terminal menus — `grep` over `App/` finds **zero** `performKeyEquivalent`/`keyDown` overrides, and SwiftTerm's `keyDown` handles no plain-Cmd chords (`paste(_:)` is a menu-driven responder action) — so with the default menu installed the chords have **nothing to match** and silently no-op. Evidence:

- **All six "App UI hierarchy" dumps** (3 find-test reps × pids): MenuBarItems exactly **[Apple, xtty, View, Window, Help]**; the app menu carries the SwiftUI-only **"Settings…"** item (identifier `menuAction:` — the Settings-scene fingerprint); **101 MenuItems, all stock; 0 hits** for Find…/Split Right/New Tab/Paste/Edit/Debug. The find-bar failure "No matches found … MenuItem" was **literally correct**.
- **The menu was built, then replaced:** app stderr contains 306 `NSEventModifierFlagFunction … will not be used` warnings = 6 × **51 launches**, per-pid — emitted only inside `XttyMainMenu.build()` (via `KeybindAdapter`), whose sole call site is `XttyApp.swift:58`.
- **Cmd+W fired the DEFAULT Window ▸ Close:** the churn video frame shows the **Window menu-title key-equivalent flash** on the 4-menu default bar; launchd reports exit (0,0,0), **zero crash reports** in the exported diagnostics — a clean `performClose:` quit (no `windowShouldClose`; xtty's confirm-close gate at `TerminalWindowController.swift:466` sits only on the custom `closePane` path and was **bypassed**). This explains churn's "Application is not running" *and* new-tab's `rawValue 1`.
- **Perfect partition (adversarially completeness-checked):** an exhaustive grep of `AppUITests/` for Cmd-modified `typeKey` maps **1:1** onto the failing tests (+ the vacuous Cmd+N, → 15c); every passing keyboard interaction bypasses menus (typeText / `.enter` / Ctrl+U → SwiftTerm `keyDown`; AX clicks; env-triggers). No counterexample exists in the suite.
- **Delivery was intact all along:** the synthesized-event records carry the correct ⌘ flag (0x10); typed halves, Ctrl+U, and the post-⌘V Enter all landed in the very tests whose Cmd chord failed. (Per-chord WindowServer delivery lines are forensics-attributed — the logarchive can't be re-read on a 26.2 machine — but are **non-load-bearing**: the items provably didn't exist to match, and Cmd+W behaviorally proves the dispatch machinery.)
- **Supportive precedent:** DuckDuckGo `apple-browsers` runs Cmd+F/Cmd+V/menu-click XCUITests green on hosted macOS-26 images (`macos-26-xlarge`, notarized, 1920×1080 — same image family, stronger posture; supportive, not a controlled same-conditions proof).

**This is a user-facing product bug, not a CI artifact:** a user whose machine loses the race gets an xtty with **no Edit/Terminal/Debug menus**. CI has been correctly reporting it since run 1.

### 15b. ❌→✅ §10/§11 "Bucket B" REFUTED — the runner/"sandbox" was never the problem

The §10a/§10g mechanism ("a native app can't reliably own the shared session's key-window/menu-bar → key-equivalents don't fire") is **wrong in mechanism and attribution** for xtty: every failure screenshot shows xtty **frontmost with an active window** and the terminal view "Keyboard Focused"; the menu bar xtty "owned" (§11e) was SwiftUI's *default* menu — §11e's "no Edit menu" observation was the smoking gun, unrecognized because nobody compared the installed menu's **contents** against `MainMenu.swift`. §10e's planned a11y-ID menu-click workarounds would **not have worked** — the items aren't in the menu to click. What stands from the prior arc: the §12 marker-wrap diagnosis (artifact-proven for run 2), the bash-banner de-noising, and the env-trigger/grid-dump side channel as the right primitive for custom-drawn content.

### 15c. ❌ The two "healthy Cmd dispatch" datapoints were vacuous tests

- **Cmd+N:** `testNewWindowOpensSecondWindow` asserts `appeared || app.state == .runningForeground` (`XttyMultiplexingUITests.swift:91-94`) — a tautology while the app lives; its own CI screenshot shows **one** window after Cmd+N. The "Cmd+N works" discriminator that kept Bucket B alive was dead.
- **Quake suite:** `toggleQuickTerminal` silently early-returns when the Debug menu is absent — the "no-debug-menu (Release?)" attachment exists **in a DEBUG build**, which is itself independent AX-level proof the custom menu (incl. Debug) was not installed. The truly affected population is **~9–10 tests**, not 7.

### 15d. Corrections to §13/§14 (and one §9/§11 bookkeeping discrepancy)

- **§13:** the `confirm-close = false` churn opt-out would **not** have fixed CI — the CI quit went through the default `performClose:`, which bypasses the confirm-close gate entirely. Inversely, **once the menu fix lands, Cmd+W newly routes through the gated `closePane` path on CI**, so the §13 startup-child race becomes newly reachable in *three* tests (split / new-tab / churn all close a just-created pane) — pre-registered as a second-order exposure (15f); prefer **wait-for-shell-ready** over the config opt-out so the churn still exercises the user-default close path. *(§16 concretized "wait-for-shell-ready": a computed-marker execution roundtrip — dump-state waits were empirically refuted.)*
- **§14a softened:** focus-typing's cross-run record is **P / FFF / P** — run 1's available log shows it **passing without the matcher** (5.618 s) — so run 3's pass is *consistent with* the wrap fix, **not confirmation**; the test is intermittent (as a race-dependent prompt-length/wrap interaction would be). §12's wrap diagnosis remains artifact-proven for run 2.
- **§14b re-attributed:** the chain (Cmd+D no-op → Cmd+W → app gone) is confirmed 3/3 in the activity timelines, but Cmd+D no-oped because **"Split Right" didn't exist in the installed menu**, and the quit was the **default Window ▸ Close**, not xtty's escalation. "Per-keystroke flaky" (§14c) was wrong — the race is **per-launch and binary** (menu installed or not).
- **Bookkeeping discrepancy (unresolved):** the run-1 (`28425122861`) failing-set recorded in §9/§11 lists focus-typing among the 7; the run-1 `gh` log tallied in this investigation shows focus-typing **passing** and `testNewTabOpens…` failing 3/3. Either the earlier capture misrecorded the set, or the job invoked `xcodebuild` more than once and log vs `.xcresult` show different invocations. Noted; doesn't affect the root cause.

### 15e. The fix plan — fix, don't skip (post-adversarial-panel)

> **Reshaped by the executed VM PoC ([`local-macos-vm-ci-reproduction.md`](local-macos-vm-ci-reproduction.md) §8d, 2026-07-04) — the mechanism is in-place item mutation, not a pointer swap:**
> - **Item 1 below (Stage-A re-assert-same-instance) is REFUTED.** `NSApp.mainMenu === builtMenu` **already holds** during a 100 % clobber (measured), so `NSApp.mainMenu !== mainMenu → reassign` never fires and re-asserting the same instance is a **no-op** — the pointer is correct; SwiftUI replaced its *items*.
> - **`NSApplicationMain` (drop the SwiftUI App lifecycle) is now the REQUIRED fix, not the eventual one** — the only option that stops SwiftUI's scene menu management from running at all. (Second choice if that regresses: rebuild/restore the menu's *items* on `didBecomeActive`, accepting possible re-mutation.)
> - **The diagnostic must compare item TITLES (does the menu still contain Edit/Terminal?), not object identity.** The spike's identity-based `menuIsBuiltInstance`/`menuClobberCount` read **healthy (True / 0) through the clobber** — blind to in-place mutation.
> - **2026-07-05 update (source-level forensics, see §17):** the "second choice" in the next bullet is superseded — rebuild/restore on `didBecomeActive` is now **refuted live** (whack-a-mole by mechanism + wrong trigger); the fallback, if `NSApplicationMain` ever regresses, is the SwiftUI **Commands API** ownership model instead.

1. **Product fix (`fix-main-menu-clobber`) — the one that flips all 7.** ~~Retain the built `NSMenu` instance on the AppDelegate and re-assert the same instance…~~ **(Stage-A refuted — see the §8d box above.)** The fix is **`NSApplicationMain`**: a `main.swift` AppKit entry point (the Ghostty pattern) so no SwiftUI scene menu management runs; keep the sole scene inert or drop it. The harness may **observe** clobbers (a **title-based** `mainMenuTitles` / "menu-has-Terminal" field in the DEBUG state dump) but must **never repair** — a repair behind the `-UITestGridDump` flag would green CI while leaving real users broken (the panel's masking-hazard veto).
2. **Menu-integrity canary + a11y-IDs.** `accessibilityIdentifier`s on the custom NSMenuItems (`MainMenu.find`, `MainMenu.splitRight`, …); a **fatal** `menuBarItems["Terminal"].waitForExistence` precondition **only in Cmd-driving suites** ("Terminal" is verifiably absent from the default bar) attaching `menuBars.debugDescription` on failure — env-trigger suites keep their menu-independent diagnostic value. This canary would have named the root cause on run 1.
3. **Vacuous-test truthing (coverage strengthening, no skips):** Cmd+N asserts a real second window via a new state-dump `windowCount` (mirrors paneCount/tabCount; **expected red on CI today** → the cleanest red→green witness, land it with the fix); quake `XCTFail`s when the DEBUG dump exists but the Debug menu doesn't; one shared `requireStateDump()` helper replaces the ~8 silent no-dump early-returns; churn loops assert **every step** (no more `_ =` discards) + `app.state == .runningForeground` after each Cmd+W, `continueAfterFailure = false`.
4. **No in-test keystroke retries** — the panel rejected the proposed bounded Cmd+D re-send as a flake-mask with a third-pane hazard; `xcodebuild -retry-tests-on-failure` (relaunch-level, visible in the result bundle) remains the only flake channel.
5. **Find-bar fallback made anomalous:** `menuItems["MainMenu.find"]` (ID, not the brittle "Find…" title) guarded by `waitForExistence`, recorded loudly when used (eventually `XCTFail` once the menu fix proves stable — its only diagnosed trigger is then gone).
6. **`.function` strip** (`KeybindAdapter.swift:28` inserts it into arrow-chord masks; macOS 26 warns it "will not be used") as its **own bisectable commit**, with a menu-construction unit test asserting the arrow items keep `.option`+`.command` in the effective mask — warning-hygiene, not the CI fix; whether 26.4 matches arrow equivalents post-fix is a CI-settled open question.
7. **Pasteboard instrumentation:** `pasteboardChangeCount` unconditionally in the state dump; clipboard **content** preview only behind an explicit test-set env var (state dumps land in public CI artifacts — privacy).
8. **One always-on diagnostic test** (launch + dump-present as minimal real assertions) attaching menu state over time — every future run self-documents which menu was installed, when, and whether it flapped.

**Change shape:** this **reshapes `harden-xcuitests-for-ci`** — the §10e/§11f "hybrid delivery hardening" scope dissolves into (a) a small **product** change (`fix-main-menu-clobber`, an `app-shell` delta + the durable-menu requirement) and (b) a **`verification-harness`** truthing delta (canary, a11y-IDs, vacuous-test fixes, dump fields). Keep the GUI job non-blocking; `test-core` stays the only required gate.

### 15f. Expected-outcome matrix for the fix run (pre-registered, so residual reds aren't misread)

- **Expected:** the 7 menu-dependent tests flip green, **or** the canary + `menuClobberCount`/timestamp name the residual clobber precisely (single early clobber then stable = race, Stage-A re-assert suffices; repeated clobbers = behavior change → `NSApplicationMain` immediately).
- **Second-order unknowns that are NOT the menu fix failing:** (1) the **quake suite runs its real body on CI for the first time** (non-activating `NSPanel` summon/type/hide on a shared session has no external precedent — exclude from the fix readout); (2) **confirm-close newly reachable** in split/new-tab/churn (§13 race on runner bash — small window, wait-for-shell-ready mitigates); (3) **Cmd+Opt+arrow matching on 26.4** post-`.function`-strip (`testDirectionalFocusMovesBetweenPanes` is the probe).
- **Settled as side effects:** pasteboard propagation (`pasteboardChangeCount` on the first post-fix paste run); race-vs-deterministic (clobber telemetry); whether the dev machine reproduces on a 26.4 update.
- **Non-blocking hygiene noted from the DDG comparison:** display-resolution pinning and per-class VM isolation are available follow-ups as the suite grows, not prerequisites.

---

## 16. Addendum (2026-07-03) — the churn-flake fix design decided → [`confirm-close-shell-readiness.md`](confirm-close-shell-readiness.md)

> **Provenance:** 2026-07-03. `/opsx:explore` split-agent deep-dive (4-agent workflow: code signal probe, terminal prior-art clones, an empirical pty foreground-pgid probe, design synthesis), following a same-day local churn record of **F(47 s)/F(37 s)/P(6.8 s)** — the flake confirmed as a race, not a hard failure. Full capture lives in the companion doc; this section is the pointer + the CI-relevant deltas.

- **The obvious fix is empirically dead:** a `hasForegroundJob`-based wait can't work — `fg == shellPid` from ~3 ms (before `.zshrc` runs), startup children grab the tty in 15–57 ms bursts invisible to the 150 ms dump sampler, last flicker ~2 s under load. Under CI bash: zero flicker, <35 ms — but that just means any pgid wait passes vacuously there.
- **DECIDED fix (test-only, zero product change):** a **computed-marker execution roundtrip** (`echo $((41000+i))` → grid match proves read+execute → rc files done) in **both** churn loops, 15 s timeout, wrap-tolerant, fail-fast before ⌘W. Companion: the DEBUG dump timer moves to `RunLoop` **`.common`** modes — `Timer.scheduledTimer`'s default-mode registration is why the dumps **froze during the confirm-close `runModal`**, producing the stale-dump artifacts that obscured §13/§15. Re-rejected with evidence: `confirm-close = false`, OSC-133-based waits (inert under CI bash), prior-art product mechanisms (no terminal has a creation grace; skip lists don't cover `nvm`/`git`/`brew`).
- **Supersedes §15d/§15e's churn detail:** "wait-for-shell-ready" is now concretely the marker roundtrip (dump-state waits refuted); the second-order confirm-close exposure for split/new-tab remains pre-registered. CI green for churn still requires the §15 menu fix — the marker fix alone greens only the local mode.
- **Future candidates captured (each its own change, none gating the flake fix):** the **at-prompt confirm-close gate** (Ghostty/Kitty model — `BlockTracker` already carries the `atPrompt` phase), **bash shell integration** (`bash-preexec`/`--init-file`, protocol-complete — would retire the marker and light up blocks/sidebar for bash users incl. CI), and the novel **zero-input latch** (`hasForegroundJob && userHasInteracted` — the only fix for the real-user mid-startup ⌘W papercut; empirically grounded, no field precedent). Details + prior-art table: [`confirm-close-shell-readiness.md`](confirm-close-shell-readiness.md).

---

## 17. Addendum (2026-07-05) — the clobber machinery named at source level → [`swiftui-mainmenu-clobber-forensics.md`](swiftui-mainmenu-clobber-forensics.md)

> **Provenance:** 2026-07-05. A 6-agent forensics workflow (SDK/binary extraction + disassembly, live lldb attribution on the real xtty build, Ghostty/CodeEdit/OpenSwiftUI prior art, migration-surface map, adversarial verifier). Full capture — mechanism, probe catalog P1–P8, fates table, F1–F7 guideline — lives in the companion doc; this section is the pointer + the deltas to §15.

- ✅ **§15a's root cause is now attributed to named internals**: `SwiftUI.AppDelegate` (the *real* `NSApp.delegate`; xtty's adaptor delegate is only forwarded-to) → `makeMainMenu(updateImmediately:)` → `AppKitMainMenuItem.updateMainMenu` — an identifier-keyed reconciler whose diff never matches plain `NSMenuItem`s, so it strips every custom item **in place** (the §8d pointer-unchanged finding, now explained at instruction level) and inserts SwiftUI defaults incl. the Help menu. Reproduced **deterministically on bare metal** by synthetically re-firing the trigger.
- ✅ **Launch ordering measured:** SwiftUI's initial pass is a *synchronous* `willFinishLaunching` callout — it strictly precedes `XttyApp.swift:58` and can never clobber; on bare metal exactly one pass fires per launch (that's why local runs are green). ❓ The VM/CI clobber is the second call site, `scenesDidChange(phaseChanged:)`, by elimination — never observed live, immaterial to the fix.
- ❌ **Two §15e alternatives refuted live:** `.commandsRemoved()` (probe5 — reconciler still strips everything) and rebuild-on-notification (probe6 — the next pass clobbers the fresh menu in place; and activation doesn't even fire the pass). Fallback re-ranked: SwiftUI **Commands** ownership (CodeEdit precedent, swizzling costs), not rebuild.
- ✅ **`NSApplicationMain` confirmed by construction + precedent:** both `makeMainMenu` call sites live on `SwiftUI.AppDelegate`, which only SwiftUI's App bootstrap instantiates (linking SwiftUI for `NSHostingView` does not); Ghostty hit this exact fight in 2023 (`CursedMenuManager`, KVO on pointer *and* items), migrated to `main.swift` + `NSApplicationMain`, deleted the hack, and ships that architecture today with SwiftUI window content. xtty's migration surface is **one construct** (delete the `XttyApp` struct, add `App/main.swift`; `project.yml` already correct).
- **Validation protocol pre-registered:** bare-metal green proves nothing; acceptance = full suite ×2 in `xtty-verify2` (3 vCPU), 7 tests flip green both runs, canary compares **titles**. §15e items 2–8 and the §15f matrix stand unchanged.

---

## 18. Addendum (2026-07-05) — `fix-main-menu-clobber` APPLIED + VALIDATED: 7 tests flipped, one benign bash-3.2 residual

> **Provenance:** 2026-07-05. `/opsx:apply fix-main-menu-clobber` (the §17 design). Migration: deleted `@main struct XttyApp: App` + added `App/main.swift` (`NSApplicationMain`, strong `let delegate` retention) + `applicationSupportsSecureRestorableState → true`; DEBUG dump gained `mainMenuTitles` (title-based) + `windowCount`; a `requireXttyMainMenu` canary wired into the Cmd-driving suites; the Cmd+N test now asserts a real second window. Validated on a fresh clone `xtty-fixrun` of the bash `xtty-test:26.5` golden (macOS 26.5, 3 vCPU / 7 GB), host `build-for-testing` → `test-without-building`, no retry flag. Evidence: `~/Downloads/xtty-vm-poc/artifacts/fix-main-menu-clobber-verify/` (`run1/run2/runG` logs + `run1.xcresult` + `KEY/` screenshots + `REVIEW.md`).

- ✅ **The fix works — 3 runs, all `40/1/1`, identical failing set** (headless ×2 + graphics). Pre-fix this rig was **34/7/1**; a per-launch race cannot produce three identical clean results, so the fix is **durable**, not a race win. The ×2 acceptance (§17) is exceeded.
- ✅ **All 7 menu-dispatch tests flipped green** (split, directional-focus, new-tab, find-bar, truecolor, churn — and new-window). The **menu canary** reported xtty's own Edit/View/Terminal/Window titles present on every launch (~126 launches across the 3 runs); pre-fix it would have `XCTFail`'d naming the clobber.
- ✅ **Mechanism confirmed independently** (forensics §7): local lldb on the fixed build — `(Class)[[NSApp delegate] class]` = **`xtty.AppDelegate`**, not `SwiftUI.AppDelegate`. Under `NSApplicationMain`, SwiftUI's app delegate (owner of both `makeMainMenu` call sites) is never installed. The redundant P6 synthetic-trigger re-run was dropped — the at-scale canary is stronger.
- ✅ **Graphics-mode focus-steal red is GONE.** §13b/README documented a graphics-only extra red (`testNewWindowOpensSecondWindow`, focus theft — 32/9/1 vs headless 33/8/1). The fix's new `windowCount` state-dump assertion doesn't use XCUI window enumeration/focus, so graphics now equals headless exactly (both 40/1/1).
- ❌→ℹ️ **The 1 residual is NOT the fix and NOT a product bug — it's macOS bash 3.2.** `testMultiLinePasteIsNotAutoExecuted` pastes `alpha\nbeta` and asserts it stages, not executes. The rig's `/bin/bash` is **GNU bash 3.2.57** (Apple's GPLv2 build), whose readline has **no `enable-bracketed-paste`** — so the pasted `\n` runs (grid: `-bash: alpha4015: command not found`). Its **sibling Cmd+V test** (single-line paste) passed, and the canary passed for it — Cmd+V dispatches; the menu is intact. Real users get bracketed paste (**zsh** default; **bash 5.1+** via Homebrew). Pre-fix, this test was *masked* as a Cmd+V menu failure (Cmd+V no-oped on the clobbered menu, never reaching the assertion); the fix un-masked a **rig-shell limitation**. This is a *new* finding, outside the §15f matrix.
- **Follow-up (harness-truthing change, not this one):** guard/skip the bracketed-paste test on a shell without `enable-bracketed-paste` (or seed a bracketed-paste-capable shell in the injected env). CI (also `/bin/bash`) will show this one test red post-fix for the same benign reason — pre-register it so it isn't misread as the fix failing.
- **§15f matrix outcomes:** quake suite passed (its real body ran on the VM session); confirm-close race did **not** surface on the VM (churn green all 3 runs — the local `make test` churn/new-tab flake the owner eyewitnessed is the separate `harden-churn-shell-readiness` item, per-launch and load-sensitive); ⌘⌥arrow matching worked on 26.5 (directional-focus green). The packer/README acceptance envelope is updated to the measured **40/1/1**.

**CI-measured (2026-07-05, run `28747512367` — the first push carrying the fix; the local clone's `origin` was wired by then):** ✅ **`test-core` green (the required gate)**; **`build-and-test` (non-blocking): the menu clobber is GONE** — the 5 pre-fix menu-dispatch failures **split / directional-focus / new-tab / new-window (Cmd+N) / churn** (and truecolor) all **flipped green** on the `macos-26` runner, mirroring the VM. Two residuals remain, **neither the menu fix** — both are pre-existing test/rig fragilities the clobber was *masking* (the tests used to die at the menu-dispatch step; now they reach the downstream assertion):
  - `testFindBarOpensLocatesAndDismisses` — Cmd+F **works** (the bar opens; the test reaches its final line-192 focus-restore check); it fails on the **§12 marker-wrap**: the runner's ~68-char hostname prompt (`sat12-dp151-…-AAD2184E38BD:/ runner$`) soft-wraps the typed `AFTERFIND####` across two grid rows (`…runner$ A` / `FTERFIND####`), and that assertion uses the **strict** `waitForContains` (the wrap-tolerant matcher from `harden-focus-typing-assertion` was only applied to the focus-typing test). Grid-proven.
  - `testMultiLinePasteIsNotAutoExecuted` — same **bash-3.2 no-bracketed-paste** cause as the VM (CI runner is also `/bin/bash`); the multi-line paste misbehaves (line-84 "second pasted line missing"; grid near-empty at capture). Real users on zsh/bash-5.1+ unaffected.
  - **Both are non-blocking-job residuals with known fixes in the harness-truthing successor change** (extend the wrap-tolerant matcher to the find-bar focus-restore assertion; guard the paste test on a bracketed-paste-capable shell). Pre-registered so they aren't misread as the menu fix regressing. **Net: 5 of the 7 pre-fix CI failures cleanly flipped; the other 2 moved past the now-working menu to a wrap-matcher and a shell-capability gap.**

---

## 19. The CI expected-difference matrix — durable classification target for `xtty-ci-investigator`

> **Provenance:** 2026-07-06. Consolidates the per-addendum residual findings above (esp. §18's CI-measured pair) into a single crisp table + job map for the committed **`xtty-ci-investigator`** agent (`.claude/agents/xtty-ci-investigator.md`) to defer to at run time. This is the CI counterpart to `packer/README.md`'s VM expected-difference matrix. When a narrative addendum above and this matrix disagree, **this matrix wins** (it is the latest consolidation).

This section is the **classification target** for CI-failure investigation: given a failed run, every red maps to exactly one row below (a named benign bucket) **or** is **UNEXPLAINED** — and any UNEXPLAINED red forbids an in-envelope verdict. Re-verified grid-first against run `28801860582` (2026-07-06): both residuals reproduced with the documented causes (the `findbar-marker-wrap` residual has since been **fixed** — §19b below).

### 19a. Job map — which jobs gate merges

| Job (`.github/workflows/`) | Role | A red here means |
| --- | --- | --- |
| `test-core` (`ci.yml`) | **Required gate** | **Stop.** The fast view-free `XttyCore` unit suite is deterministic — a red is a real regression by default, regardless of any bucket. |
| `build-and-test` (`ci.yml`) | **Non-blocking** | Classify each red against §19b; all-benign ⇒ expected, proceed. |
| `pr-lint` (`pr-lint.yml`) | **Non-blocking** (PRs only) | A Conventional-Commit **PR-title** violation — a title fix, not a code failure. |

### 19b. Known-benign residual buckets (hosted `macos-26` runner)

**No known-benign residuals remain** on the **non-blocking** `build-and-test` job as of 2026-07-08. The two former buckets were both retired: `findbar-marker-wrap` was **fixed** (`harden-findbar-wrap-assertion`, 2026-07-07 — see below), and `bash32-no-bracketed-paste` was **converted from a red into an asserted green bash arm** (`split-shell-dependent-testplan`, 2026-07-08 — see below). **A red on this job is now a REGRESSION, not a benign residual.** The two buckets are kept below as *classification targets* so the investigator recognizes a recurrence as a regression.

**`bash32-no-bracketed-paste` — RETIRED (now an asserted arm, was a `:87` red).** The runner's login shell is `/bin/bash` = GNU bash 3.2.57, whose readline has **no `enable-bracketed-paste`**, so a pasted multi-line string forwards line-by-line: the newline-terminated first line **executes** (`-bash: alpha####: command not found`) while the unterminated tail stages. `split-shell-dependent-testplan` renamed `testMultiLinePasteIsNotAutoExecuted` → **`testMultiLinePasteMatchesShellBracketing`** and made it **branch on the observed `bracketedPasteMode`** (a new DEBUG state-dump field), asserting the **bash execution arm** on bash (`command not found` present **exactly once**, tail staged) and the **staged** arm on zsh. So on the (bash) hosted runner the test now **asserts and passes** — the old `:87` not-executed red is gone. **If the old-style red returns** (an unconditional not-executed assertion failing on bash), classify it as a **REGRESSION** of this change, not a benign residual. Grid-proven cause: §11–§18. The zsh cross-check (`add-zsh-test-image`, then `harden-paste-wrap-assertion`) confirmed the divergence is shell-specific — on the zsh VM rig `xtty-test-zsh:26.5` the paste *stages* (zsh has bracketed paste), greened at `41/0/1` after the wrap-tolerant matcher fix at `:82`/`:84`; `split-shell-dependent-testplan` keeps that wrap-tolerance and adds the asserting bash arm, so **neither arm is skipped**.

**Semantic-capture family — asserts per shell, no more vacuous passes.** `split-shell-dependent-testplan` also replaced the 12 silent `guard waitForCaptureActive() else { attach; return }` early-returns (across the semantic-capture / sidebar / block-sidebar / spatial-blocks / git-review / file-link suites) with a **crisp negative** (`assertSemanticCaptureInactive` — asserts no command boundaries / no semantic action on a non-injecting shell). On the (bash) runner these tests now **assert the negative** and pass for real; a `…capture inactive…` attachment WITHOUT an assertion (a vacuous pass) is now itself a **defect**. On the zsh VM rig `xtty-test-zsh:26.5` they assert the capability-present arm (0 capture-inactive attachments; measured `add-zsh-test-image`). The zsh divergence was measured **headless** (the graphics-only Local Network modal is removed at the product seam by `fix-osc7-hostname-reverse-dns` and is moot headless regardless — **0** `policy 'pending'` even headless). Full envelope + matrix: `packer/README.md` → Acceptance (both goldens, expected `41/0/1`) + Expected-difference matrix (the asserted bash-execution arm and the zsh soft-wrap arm).

**Fixed — `findbar-marker-wrap` (shipped 2026-07-07, `harden-findbar-wrap-assertion`):** the find-bar focus-restore assertion now uses the wrap-tolerant `waitForContains(…, ignoringLineWraps: true)` (`XttyUITests.swift:198`, mirroring `:53`), plus a deterministic self-validating soft-wrap guard `testSoftWrapGuardIsWrapTolerant` that reproduces the wrap class in `make test`. Proven **red→green in-guest** on the wide-prompt VM (the `add-vm-prompt-width-parity` pair; `40/1/1` of 42, validator-delegated). **A recurrence of `testFindBarOpensLocatesAndDismisses` failing is now a REGRESSION, not a benign residual.**

**Deferred fix — SHIPPED (`split-shell-dependent-testplan`, 2026-07-08):** the plan was to *guard/skip* the paste test on a non-bracketed shell; the change did **better** — it **asserts the per-shell behavior** (bash executes-first-line / zsh stages) rather than skipping, so both shells get real coverage and CI's bash arm is green-by-assertion, not skipped.

**Mechanism (historical — how `findbar-marker-wrap` arose, now fixed):** verified from `actions/runner-images` source in [`ci-runner-prompt-width-forensics.md`](ci-runner-prompt-width-forensics.md) — stock macOS `PS1='\h:\W \u\$ '` (the image sets **no** `PS1`), so prompt width = `len(\h)`; the runner's ~61-char `\h` is **GitHub-network-injected at runtime** (the image build sets only `Mac-<epoch>.local`). The short-`\h` local Tart VM was blind to it until `add-vm-prompt-width-parity` gave the image a 59-char `\h` (the only reproduction lever is hostname length), reproducing the red in-guest; `harden-findbar-wrap-assertion` then fixed the assertion. Retained as the causal record so a recurrence is classified as a regression.

### 19c. Reverse duty

Any change that **adds or removes a test, fixes a known-benign residual, or changes a job's required-gate status** MUST update this matrix (and the §19a job map) **in the same session** — otherwise the agent's runtime read just relocates the staleness. Mirrors the `packer/README.md` reverse duty for the VM matrix.

## Sources

- **xtty repo:** `Makefile`, `project.yml`, `scripts/bootstrap-swiftterm.sh`, `patches/swiftterm/UPSTREAM_CONFIG.sh` + `xtty-accessors.diff`, `.gitignore`, `XttyCore/Package.{swift,resolved}`, `AppUITests/*` (StateDumpReader/GridDumpReader, `XTTY_*` triggers), `AGENTS.md`
- **§11 artifact evidence (2026-07-01):** the two `.xcresult` artifacts of run `28425122861` (`gh api repos/kitimark/xtty/actions/runs/28425122861/artifacts`, ids `7972842439`/`7987195834`), unpacked + read with `xcrun xcresulttool get test-results summary` and `… export attachments` (screenshots, grid dumps, `App UI hierarchy`, screen recordings); cross-checked against `AppUITests/XttyUITests.swift` + `XttyMultiplexingUITests.swift` + `XttyUITestSupport.swift`
- **§12 artifact evidence (2026-07-01):** the `.xcresult` of the **post-merge** run `28467944762` (head = the `silence-bash-deprecation` archive commit), `gh run download`; `xcrun xcresulttool … summary` + `… export attachments`; `grep` of all 221 attachments for the banner text (0 hits); `focus-typing-grid`/`focus-typing-typed`/`paste-grid` dumps + `GridDumpReader.waitForContains` (`XttyUITestSupport.swift:117–121`)
- **§15 evidence (2026-07-02/03):** the full `.xcresult` of run `28472076179` (`gh run download`, 213 exported attachments — six "App UI hierarchy" AX dumps, failure screenshots, grid dumps, churn screen-recording frames via `ffmpeg`, `StandardOutputAndStandardError-com.xtty.app.txt`, synthesized-event bplists) + `xcresulttool export diagnostics` (zero crash reports); cross-run `gh` logs (`28425122861`/`28467944762`); source: `App/XttyApp.swift` (`:15-24`, `:58`), `App/MainMenu.swift`, `App/KeybindAdapter.swift:28`, `App/TerminalWindowController.swift:466`, `external/SwiftTerm` `MacTerminalView` (keyDown/paste), exhaustive `AppUITests/` Cmd-`typeKey` inventory; external: a DuckDuckGo `apple-browsers` shallow clone (macOS UI-test primitives + workflows), XCUITest/AppKit menu-dispatch research; produced by a 12-agent workflow with a 3-lens adversarial verification (evidence lens: sound)
- **§14 evidence (2026-07-02):** the **log** of the post-merge run `28472076179` (head = the `harden-focus-typing-assertion` archive commit `069fd30`) via `gh run view --log-failed` — per-test verdicts, failure messages, `Failing tests:` summary, `Executed N tests` totals — diffed against run `28467944762`; `AppUITests/XttyLifecycleCensusUITests.swift` (`:42-53` churn loops, `:43` the failing `typeKey`); `.github/workflows/ci.yml` (no `continue-on-error` on `build-and-test`)
- **§13 evidence (2026-07-01):** the **local** `make test` `.xcresult` (`build/Logs/Test/…xcresult`) — `export attachments` + the per-test attachment timeline (Synthesized Events / UI Snapshots) + the churn screen-recording `.mp4` (frames via `ffmpeg`); the user's eyewitness of the modal; `AppUITests/XttyLifecycleCensusUITests.swift`, `App/TerminalWindowController.swift` (`hasForegroundJob`/`confirmClose`/`positionOnBuiltInDisplay`), and `~/.zshrc` startup commands
- **GitHub:** docs.github.com (Actions billing for public repos, standard vs larger runners, `macos-*` labels), the **`actions/runner-images`** repo (macos-26 README + software manifest, `Install-Xcode.ps1` Metal `-ge 26` gate, runner-image issues #13014 / #13080 / #13094), `actions/cache`, `maxim-lobanov/setup-xcode`, `irgaly/xcode-cache`, `softprops/action-gh-release`, `ncipollo/release-action`, `amannn/action-semantic-pull-request`
- **OSS workflows (read):** Ghostty `.github/workflows/release-tip.yml` (Namespace runners + codesign/notarize), `MrKai77/Loop` `dev-build.yml` (GitHub-hosted full notarize), `FlashSpace` `ci.yml`/`pr.yml` (XcodeGen + Conventional-Commit lint), Americano/Thaw/Mythic/Stats (cache keys + secret-free `CODE_SIGNING_ALLOWED=NO`)
- **Companion:** [`distribution-signing-research.md`](distribution-signing-research.md) (the $0/Homebrew/$99 distribution arc this CI release seam plugs into)
