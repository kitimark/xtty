## Context

xtty has a fresh GitHub repository but no CI. The build is non-trivial to reproduce: full Xcode + the Metal toolchain (SwiftTerm bundles a `.metal` shader the build compiles), XcodeGen to generate the gitignored `xtty.xcodeproj`, and a `scripts/bootstrap-swiftterm.sh` step that clones the pinned upstream SwiftTerm into the gitignored `external/SwiftTerm` and `git apply`s the accessor patch. Tests come in two tiers: a fast view-free `XttyCore` suite (`swift test`, no app) and app **XCUITests** that drive a real window + inject a real zsh and assert via a DEBUG `/tmp` state dump.

The signing posture is the committed default: App Sandbox OFF, ad-hoc "Sign to Run Locally" (`CODE_SIGN_IDENTITY="-"`), no team — so **build + test need no Apple secrets**. This change is the cheap, fork-free CI slice of the broader distribution work. Full grounding + the multi-agent research (runner reality, XCUITest-on-CI viability, OSS precedent, repo specifics) is in [`research/03-analysis/github-actions-ci-cd.md`](../../../research/03-analysis/github-actions-ci-cd.md); the distribution arc it plugs into is [`distribution-signing-research.md`](../../../research/03-analysis/distribution-signing-research.md).

Two researched unknowns shape the design and must be **verified on the first real runs** (the research critic graded the synthesis *usable-with-caveats* precisely here):
1. **Metal toolchain on the runner** — a genuine 2-2 split in the evidence: likely preinstalled on `macos-26` for *release* Xcode ≥ 26, but excluded for betas/RCs. Not safe to assume.
2. **XCUITest drive-path reliability on hosted runners** — the runner image pre-authorizes the UI-test path (auto-login GUI session + TCC pre-grants), so permission dialogs are not the problem; the synthesized-input *drive* channel (`typeText`/`click`, the two corner-drag tests) is the unproven part.

## Goals / Non-Goals

**Goals:**
- A push/PR CI gate that runs the existing test suites on hosted `macos-26` runners, **$0 and secret-free**.
- Robustness to the two unknowns above: the required gate is the deterministic headless `XttyCore` job; the app/UI job is non-blocking; a Metal guard makes the build succeed whether or not the runner preinstalls the toolchain.
- Fast routine runs via caching the highest-value inputs (the reconstituted SwiftTerm checkout, SPM).
- Enforce the repo's existing Conventional Commits convention on PR titles.
- Keep the canonical build docs accurate (add a short CI section).

**Non-Goals:**
- **No release artifact** (an ad-hoc DMG → GitHub Release is a future `add-ad-hoc-release`).
- **No Developer ID / Hardened Runtime / notarization** (a future `add-release-notarization`; remains $99-gated and deferred).
- **No SwiftLint/SwiftFormat** — net-new tooling + config + violation churn; out of scope.
- **No app source changes** and **no `verification-harness` delta** — CI invokes the existing tests and adds no new observable app behavior.
- Not configuring GitHub branch protection from a committed file (it is a repo setting — a human-gated task, not a workflow file).

## Decisions

**D1 — Fold CI into `build-workflow`, no new capability.** CI is the build/test process formalized, which `build-workflow` already owns (Makefile/XcodeGen/bootstrap/signing). A separate `ci` capability would be overkill for two workflow files. → spec delta = `## ADDED Requirements` on `build-workflow`.

**D2 — Two jobs: required headless gate + non-blocking GUI job.** `test-core` (`swift test --package-path XttyCore`, no app, deterministic) is the required gate; `build-and-test` (`xcodebuild test`, XCUITest) is non-blocking with `-retry-tests-on-failure`. *Why:* the GUI drive-path reliability is unproven on hosted runners; making it non-blocking means it cannot wedge merges, yet it still **exercises the suite on CI so we learn whether it works** — strictly better than deferring it. Alternative (test-core only) was rejected: it never discovers the GUI answer.

**D3 — Pin `macos-26`, not `macos-latest`.** `macos-latest` is mid-flip (macos-15 → macos-26), which would silently change the runner. Xcode selection: prefer the image's release default and only pin a specific `Xcode_26.x.app` if needed — see D4.

**D4 — Idempotent Metal guard + verify-on-first-run, instead of trusting preinstall.** Add `xcrun -f metal >/dev/null 2>&1 || sudo xcodebuild -downloadComponent MetalToolchain` before building. *Why:* the preinstall evidence is a 2-2 split and the preinstall gate excludes RCs, so a pinned RC Xcode could be exactly the gap. The guard makes the build correct under *both* outcomes at near-zero cost (a no-op when Metal is present). First CI run confirms which case holds (an apply-time verification task). Corollary: prefer the unambiguous release default Xcode over pinning an RC; if pinning, keep the guard.

**D5 — Cache priority: the SwiftTerm checkout first.** Cache `external/SwiftTerm` keyed on `hashFiles('patches/swiftterm/UPSTREAM_CONFIG.sh','patches/swiftterm/xtty-accessors.diff')` (rebuilds only when the pin/patch changes; skips the network clone otherwise), plus SPM keyed on `Package.resolved`. DerivedData caching (e.g. `irgaly/xcode-cache` for mtime correctness) is optional follow-up, not v1. Never cache the generated `xtty.xcodeproj` (gitignored, cheap to regenerate).

**D6 — Call scripts directly, bypass `make doctor`/`make setup` in CI.** `doctor` only *advises* and exits non-zero on a missing prereq (never installs, by design); `setup` depends on it. CI runs `brew install xcodegen` then `scripts/bootstrap-swiftterm.sh` + `xcodegen generate` + the `xcodebuild`/`swift test` commands directly. Calling the bootstrap script directly (not via `make`) also avoids Make's post-cache-restore mtime re-trigger.

**D7 — PR-title lint via `amannn/action-semantic-pull-request`, scoped to pull requests.** One workflow file, no code changes, enforces the repo's hard Conventional Commits rule (allowed types: the ones the repo uses — `feat`, `fix`, `docs`, `chore`, `test`, `refactor`, `perf`, `style`, `ci`, `build`, `revert`; scope optional). It fires on `pull_request` events only — it does not (and need not) gate direct-to-`main` pushes; it is the contributor-PR guard once the repo is public.

**D8 — Ad-hoc, secret-free.** Leave `XTTY_SIGN_IDENTITY` and `XTTY_RUN_BENCH_E2E` unset; do not force `CODE_SIGNING_ALLOWED=NO` (a UI test launches a real app). `make bench` (needs a real display + Screen Recording) and `make audit-leaks` (diagnostic) are **not** CI gates.

## Risks / Trade-offs

- **Metal toolchain absent on the scheduled image** → the D4 guard downloads it (~700 MB, sudo, network; installs into `/System` so not cleanly cacheable). Mitigation: guard is a no-op when present; verify on first run; prefer the release default Xcode.
- **XCUITest flakiness / drive-path failures on the hosted runner** → the GUI job is non-blocking with retries; the required gate is the deterministic `XttyCore` suite, so flakiness never wedges merges. Mitigation: `-resultBundlePath` artifact on failure for diagnosis; the two corner-drag tests are the prime suspects (consider converting them to the `XTTY_TEST_*` env-trigger pattern the rest of the suite uses — a follow-up, not v1).
- **Xcode/image drift** → a hardcoded `/Applications/Xcode_26.x.app` can break silently when GitHub rotates the image; prefer the default or re-verify on bumps. Whether Metal preinstall holds for a brand-new future Xcode is policy-dependent.
- **Runner disk (~14 GB total)** → full Xcode + the SwiftTerm clone + DerivedData should fit (xtty's footprint is small) but watch headroom.
- **PR-title lint doesn't gate direct pushes** → accepted; it's a PR guard, and the current AI workflow commits direct-to-`main`.

## Migration Plan

This adds CI to a repo that has none; nothing to roll back in the app. Sequence:
1. **Human-gated prerequisites (cannot be a committed file):** `git remote add origin git@github.com:kitimark/xtty.git`, push `main`, **make the repository public** (free unlimited macOS minutes).
2. Apply: add `.github/workflows/ci.yml` + `.github/workflows/pr-lint.yml` and the docs note.
3. **Verify on the first real runs (apply-time tasks):** confirm `xcrun -f metal` resolves on the scheduled image for the selected Xcode (else the guard downloads it); confirm the `test-core` job is green; smoke-test the `build-and-test` (XCUITest) job and keep it non-blocking until proven; confirm `pr-lint` fires on a test PR.
4. **Optional:** configure branch protection so `test-core` is a required status check (GitHub setting, not a file).
Rollback = delete the workflow files; the app is unaffected.

## Open Questions

- Is the image's pinned Xcode 26.6 a **release or an RC**? (Determines whether Metal is preinstalled; resolved by the first-run check. If RC, prefer the 26.5 release default.)
- Does `swift test` (test-core) itself invoke the Metal compiler on SwiftTerm's `Shaders.metal` resource? (SwiftTerm's `isGitHubActions` flag gates only the benchmark dep, not the `.metal` resource — so possibly yes; moot on `macos-26` if Metal is present, matters only if a metal-less image is ever used. The D4 guard covers it either way.)
- Will the hosted-runner XCUITest drive-path prove reliable enough to later promote `build-and-test` to a required gate? (Decided empirically after a few runs.)
