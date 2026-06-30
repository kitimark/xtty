## Why

xtty now has a GitHub repository (`git@github.com:kitimark/xtty.git`) but no automated checks — every regression is caught only by a contributor remembering to run the tests locally. Research ([`github-actions-ci-cd`](../../../research/03-analysis/github-actions-ci-cd.md)) confirmed that **$0, secret-free continuous integration is viable on GitHub-hosted `macos-26` runners today**: the committed ad-hoc "Sign to Run Locally" posture needs no Apple credentials, and standard macOS runners are free and unlimited for public repos. Wiring a CI gate now turns the existing test suites into an automatic regression net before the project takes outside contributions.

## What Changes

- Add a **CI workflow** (`.github/workflows/ci.yml`) that runs on every push and pull request on a pinned `macos-26` runner with no secrets:
  - a **required** fast job that reconstitutes SwiftTerm and runs the view-free `XttyCore` unit tests (headless, deterministic);
  - a **best-effort / non-blocking** job that generates the Xcode project and runs the app build + XCUITests (retry-tolerant), so the suite is exercised on CI without its known hosted-runner flakiness gating merges.
- Make the workflow **robust to two researched unknowns**: an idempotent Metal-toolchain guard (the runner may or may not preinstall it), and treating the XCUITest job as non-blocking until its hosted-runner reliability is proven on the first real runs.
- Cache the highest-value inputs (the reconstituted SwiftTerm checkout keyed on the pin + patch, and Swift package dependencies) so routine runs are fast.
- Add a **PR-title lint workflow** (`.github/workflows/pr-lint.yml`) that enforces the repository's existing Conventional Commits convention on pull-request titles.
- Document the CI gate in the canonical build docs (the entry-point/build documentation), and record the human-gated prerequisites (wire the git remote, make the repo public, optionally mark the fast job a required status check).
- **Out of scope (explicitly deferred):** producing a downloadable release artifact (an ad-hoc DMG → GitHub Release belongs to a future `add-ad-hoc-release`); Developer ID + notarization (a future `add-release-notarization`); and SwiftLint/SwiftFormat (net-new tooling + config, not wiring up an existing setup).

## Capabilities

### New Capabilities

<!-- none — CI is the build/test process formalized, which build-workflow already owns; a separate `ci` capability would be overkill. -->

### Modified Capabilities

- `build-workflow`: adds a requirement that continuous integration run the established build/test entry points on hosted CI for every push and pull request — a required fast core-test gate plus a non-blocking app build + UI-test job — using only the default ad-hoc (secret-free) signing, and that PR titles be linted against Conventional Commits. (No requirement text changes for the existing build/test entry points; CI *invokes* them.)

## Impact

- **New files (at apply time):** `.github/workflows/ci.yml`, `.github/workflows/pr-lint.yml`. No application source changes.
- **Spec:** one `## ADDED Requirement` in the `build-workflow` delta. **No `verification-harness` delta** — CI invokes the existing tests and adds no new observable app behavior.
- **Dependencies / tooling:** GitHub Actions; the runner's full Xcode + Metal toolchain; `brew install xcodegen` on the runner; the `actions/checkout`, `actions/cache`, and `amannn/action-semantic-pull-request` actions. No new app dependencies, **no repository secrets**.
- **Build posture unchanged:** ad-hoc "Sign to Run Locally" (no Developer ID, no Hardened Runtime, no notarization) — consistent with the deferred distribution work.
- **Human-gated prerequisites (cannot be done by a committed file):** add the git remote and push, make the repository public (for free unlimited macOS minutes), and optionally configure branch protection so the fast job is a required check.
- **Docs:** the canonical build documentation gains a short CI section (keeps the "documentation is accurate and current" requirement satisfied).
