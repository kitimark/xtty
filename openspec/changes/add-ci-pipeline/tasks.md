## 1. Prerequisites (human-gated — cannot be done by a committed file)

- [x] 1.1 Wire the git remote and push: `git remote add origin git@github.com:kitimark/xtty.git` and push `main` *(done; first CI run `28425122861` triggered)*
- [ ] 1.2 Make the repository **public** (so GitHub-hosted macOS runner minutes are free + unlimited)

## 2. CI workflow (`.github/workflows/ci.yml`)

- [x] 2.1 Create the workflow triggered on `push` and `pull_request`, both jobs `runs-on: macos-26`, no secrets
- [x] 2.2 Add the **`test-core`** job (required gate): checkout → select Xcode (prefer the image release default; pin a specific `Xcode_26.x.app` only if needed) → Metal guard (`xcrun -f metal >/dev/null 2>&1 || sudo xcodebuild -downloadComponent MetalToolchain`) → cache `external/SwiftTerm` (key on `hashFiles('patches/swiftterm/UPSTREAM_CONFIG.sh','patches/swiftterm/xtty-accessors.diff')`) → cache SPM (key on `XttyCore/Package.swift` — no `Package.resolved` is committed) → `scripts/bootstrap-swiftterm.sh` (call directly, not via `make`) → `swift test --package-path XttyCore`. *(Used the image's default release Xcode — no `xcode-select` — to avoid pinning an RC that lacks preinstalled Metal.)*
- [x] 2.3 Add the **`build-and-test`** job (non-blocking / best-effort): same setup + `brew install xcodegen` → `scripts/bootstrap-swiftterm.sh && xcodegen generate` → `xcodebuild test -project xtty.xcodeproj -scheme xtty -destination 'platform=macOS' -derivedDataPath build -retry-tests-on-failure -resultBundlePath build/TestResults.xcresult`; upload the `.xcresult` as an artifact on failure
- [x] 2.4 Ensure `build-and-test` does not block merges (left out of required checks via a documented comment — honest red/green signal, kept non-required in branch protection) while its hosted-runner reliability is unproven; left `XTTY_SIGN_IDENTITY` and `XTTY_RUN_BENCH_E2E` unset (ad-hoc, no bench/Screen-Recording)

## 3. PR-title lint workflow (`.github/workflows/pr-lint.yml`)

- [x] 3.1 Add a `pull_request`-triggered job using `amannn/action-semantic-pull-request` that enforces Conventional Commit PR titles (allowed types: `feat`, `fix`, `docs`, `chore`, `test`, `refactor`, `perf`, `style`, `ci`, `build`, `revert`; scope optional). *(Runs on `ubuntu-latest` — no macOS needed — with the auto-provided `GITHUB_TOKEN`, no custom secret.)*

## 4. Documentation

- [x] 4.1 Add a short **CI** section to the canonical build docs (AGENTS.md → Building): what the two jobs do, the required-vs-non-blocking split, that it's secret-free/ad-hoc, and the human prerequisites — keeping the "build documentation is accurate and current" requirement satisfied

## 5. Verify on the first real runs (resolve the researched unknowns)

- [x] 5.1 Confirm the **Metal** situation — **RESOLVED: preinstalled.** The image's default release Xcode is **26.5** (a release, not an RC); the build used the preinstalled `MetalToolchain-v17.6.42.0` cryptex and compiled SwiftTerm's `Shaders.metal` with no download. The guard was a no-op. (The 2-2 research split resolves to "preinstalled for the release default.")
- [x] 5.2 Confirm the **`test-core`** job is green on CI (the required gate) — **PASSED in 1m6s** (run `28425122861`)
- [x] 5.3 Smoke-test the **`build-and-test`** (XCUITest) job — **DONE: infra works, drive-path risk REFUTED.** 34/41 XCUITests pass on the hosted runner (typing, keys, Cmd+V, zsh injection, grid+state dumps all functional). **7 CI-environment-sensitive tests fail** (each retried 3×): `testTruecolorEmojiAndWideChars`, `testMultiLinePasteIsNotAutoExecuted`, `testFocusTypingOnActivateWithoutClicking`, `testFindBarOpensLocatesAndDismisses`, `testSplitCreatesAndClosesPanes`, `testDirectionalFocusMovesBetweenPanes`, `testLifecycleChurnReturnsCensusToBaseline` (likely cluster: window focus/activation on the auto-login session + clipboard for paste + rendering/locale for truecolor). Job correctly **non-blocking**; hardening these is **follow-up**, not v1.
- [ ] 5.4 Confirm **`pr-lint`** fires correctly on a test PR (rejects a bad title, accepts a Conventional one)
- [ ] 5.5 (Optional) Configure branch protection so `test-core` is a required status check (GitHub repo setting, not a committed file)

## 6. Spec reconcile

- [ ] 6.1 `openspec validate add-ci-pipeline`, then on completion archive and merge the `build-workflow` delta; update trackers (AGENTS.md Current status, milestones) per the repo's keep-progress-current rule
