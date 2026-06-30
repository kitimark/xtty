## 1. Prerequisites (human-gated — cannot be done by a committed file)

- [ ] 1.1 Wire the git remote and push: `git remote add origin git@github.com:kitimark/xtty.git` and push `main`
- [ ] 1.2 Make the repository **public** (so GitHub-hosted macOS runner minutes are free + unlimited)

## 2. CI workflow (`.github/workflows/ci.yml`)

- [ ] 2.1 Create the workflow triggered on `push` and `pull_request`, both jobs `runs-on: macos-26`, no secrets
- [ ] 2.2 Add the **`test-core`** job (required gate): checkout → select Xcode (prefer the image release default; pin a specific `Xcode_26.x.app` only if needed) → Metal guard (`xcrun -f metal >/dev/null 2>&1 || sudo xcodebuild -downloadComponent MetalToolchain`) → cache `external/SwiftTerm` (key on `hashFiles('patches/swiftterm/UPSTREAM_CONFIG.sh','patches/swiftterm/xtty-accessors.diff')`) → cache SPM (key on `XttyCore/Package.resolved`) → `scripts/bootstrap-swiftterm.sh` (call directly, not via `make`) → `swift test --package-path XttyCore`
- [ ] 2.3 Add the **`build-and-test`** job (non-blocking / best-effort): same setup + `brew install xcodegen` → `scripts/bootstrap-swiftterm.sh && xcodegen generate` → `xcodebuild test -project xtty.xcodeproj -scheme xtty -destination 'platform=macOS' -derivedDataPath build -retry-tests-on-failure -resultBundlePath build/TestResults.xcresult`; upload the `.xcresult` as an artifact on failure
- [ ] 2.4 Ensure `build-and-test` does not block merges (e.g. `continue-on-error: true` or left out of required checks) while its hosted-runner reliability is unproven; leave `XTTY_SIGN_IDENTITY` and `XTTY_RUN_BENCH_E2E` unset (ad-hoc, no bench/Screen-Recording)

## 3. PR-title lint workflow (`.github/workflows/pr-lint.yml`)

- [ ] 3.1 Add a `pull_request`-triggered job using `amannn/action-semantic-pull-request` that enforces Conventional Commit PR titles (allowed types: `feat`, `fix`, `docs`, `chore`, `test`, `refactor`, `perf`, `style`, `ci`, `build`, `revert`; scope optional)

## 4. Documentation

- [ ] 4.1 Add a short **CI** section to the canonical build docs (AGENTS.md → Building): what the two jobs do, the required-vs-non-blocking split, that it's secret-free/ad-hoc, and the human prerequisites — keeping the "build documentation is accurate and current" requirement satisfied

## 5. Verify on the first real runs (resolve the researched unknowns)

- [ ] 5.1 Confirm the **Metal** situation: on the actually-scheduled `macos-26` image for the selected Xcode, verify `xcrun -f metal` resolves (guard is a no-op) — or that the guard's download succeeds; record release-vs-RC of the chosen Xcode
- [ ] 5.2 Confirm the **`test-core`** job is green on CI (the required gate)
- [ ] 5.3 Smoke-test the **`build-and-test`** (XCUITest) job on a real run; keep it non-blocking; capture the `.xcresult` if it fails to judge drive-path reliability
- [ ] 5.4 Confirm **`pr-lint`** fires correctly on a test PR (rejects a bad title, accepts a Conventional one)
- [ ] 5.5 (Optional) Configure branch protection so `test-core` is a required status check (GitHub repo setting, not a committed file)

## 6. Spec reconcile

- [ ] 6.1 `openspec validate add-ci-pipeline`, then on completion archive and merge the `build-workflow` delta; update trackers (AGENTS.md Current status, milestones) per the repo's keep-progress-current rule
