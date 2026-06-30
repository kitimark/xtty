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

- ✅ **Metal toolchain — RESOLVED: preinstalled** (the 2-2 split collapses to "preinstalled for the release default"). The image's default release Xcode is **26.5** (a release, not an RC); the build used the preinstalled `MetalToolchain-v17.6.42.0` cryptex (`/var/run/com.apple.security.cryptexd/…/Metal.xctoolchain/usr/bin/metal`) and compiled SwiftTerm's `Shaders.metal` → `default.metallib` with **no download** — the idempotent guard was a no-op. (Updates §1/§2/§8: the guard stays as cheap insurance for a future RC-default or metal-less image, but the release default has Metal.)
- ✅ **`test-core` (required gate) — PASSED in 1m6s.** Reconstituted SwiftTerm + `swift test --package-path XttyCore` green on a stock runner. The deterministic gate works; this is the check to require in branch protection.
- ✅ **XCUITest on a hosted runner — the predicted drive-path risk is REFUTED.** **34 of 41** UI tests pass (`build-and-test`, 8m35s). The synthesized-input drive path works on the auto-login runner: typing, key chords, **Cmd+V**, real **zsh injection**, and both the `/tmp` **grid-dump and state-dump** assertions all function (the complex semantic-capture, spatial-blocks, block-sidebar, git-review, profiles, quick-terminal, performance-harness suites are green; `testBasicTypedEcho` passes, proving basic typed input reaches the window).
- ⚠️ **7 deterministic CI-environment failures** (each failed all 3 `-retry-tests-on-failure` attempts, so not flaky): `testTruecolorEmojiAndWideChars`, `testMultiLinePasteIsNotAutoExecuted`, `testFocusTypingOnActivateWithoutClicking`, `testFindBarOpensLocatesAndDismisses`, `testSplitCreatesAndClosesPanes`, `testDirectionalFocusMovesBetweenPanes`, `testLifecycleChurnReturnsCensusToBaseline`. **Hypothesised cluster:** window **focus/key-activation** on the headless auto-login session (focus-on-activate-without-clicking, split-keybind delivery, directional focus, and the churn test that needs splits to form — note basic typing *works*, so it's activation/keybind-delivery, not blanket focus loss), plus two outliers — **clipboard** (`NSPasteboard` likely empty on CI → paste no-op) and **rendering/locale** (truecolor/emoji/wide grid-dump content). All fixable with per-test hardening (explicit window activation, the `XTTY_TEST_*` env-trigger pattern instead of synthesized focus/keybinds, clipboard seeding, a locale env) — but that's **iterative CI debugging** (push → ~8 min → repeat), genuinely separate from standing up CI.
- 🟢 **Net:** the CI pipeline is sound and does its job — `test-core` is the green gate, and the **non-blocking `build-and-test` correctly *surfaced* the CI-sensitivities instead of blocking merges** (exactly its design intent). The 7-test hardening is **follow-up** (a candidate `harden-xcuitests-for-ci` change), not a defect in `add-ci-pipeline`.
- 🔧 **Minor nit:** a run annotation flags `actions/checkout@v4` + `actions/cache@v4` forced onto Node 24 (Node 20 deprecation) — harmless now; bump to `@v5` when convenient.
- **Status:** `add-ci-pipeline` left **OPEN** (per decision) — done: 1.1 (push), 5.1 (Metal), 5.2 (test-core), 5.3 (smoke); remaining: 1.2 (make repo public — and note that while private each ~8-min run burns ~80 metered macOS-minutes at the 10× multiplier), 5.4 (pr-lint — needs a PR to fire), 5.5 (optional branch protection), 6.1 (archive). The 7-test hardening is the open question before promoting `build-and-test` toward a required gate.

---

## Sources

- **xtty repo:** `Makefile`, `project.yml`, `scripts/bootstrap-swiftterm.sh`, `patches/swiftterm/UPSTREAM_CONFIG.sh` + `xtty-accessors.diff`, `.gitignore`, `XttyCore/Package.{swift,resolved}`, `AppUITests/*` (StateDumpReader/GridDumpReader, `XTTY_*` triggers), `AGENTS.md`
- **GitHub:** docs.github.com (Actions billing for public repos, standard vs larger runners, `macos-*` labels), the **`actions/runner-images`** repo (macos-26 README + software manifest, `Install-Xcode.ps1` Metal `-ge 26` gate, runner-image issues #13014 / #13080 / #13094), `actions/cache`, `maxim-lobanov/setup-xcode`, `irgaly/xcode-cache`, `softprops/action-gh-release`, `ncipollo/release-action`, `amannn/action-semantic-pull-request`
- **OSS workflows (read):** Ghostty `.github/workflows/release-tip.yml` (Namespace runners + codesign/notarize), `MrKai77/Loop` `dev-build.yml` (GitHub-hosted full notarize), `FlashSpace` `ci.yml`/`pr.yml` (XcodeGen + Conventional-Commit lint), Americano/Thaw/Mythic/Stats (cache keys + secret-free `CODE_SIGNING_ALLOWED=NO`)
- **Companion:** [`distribution-signing-research.md`](distribution-signing-research.md) (the $0/Homebrew/$99 distribution arc this CI release seam plugs into)
