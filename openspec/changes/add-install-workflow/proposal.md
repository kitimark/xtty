## Why

Today `make run` builds the **Debug** configuration and launches it **in place** from the volatile `build/` directory — unoptimized, with an ad-hoc code identity that churns on every rebuild (so TCC grants re-prompt), wiped by `make clean`, and absent from Spotlight/Dock. There is no way to install a **stable, versioned, optimized** build for daily-driving. This adds a `make install` that produces an optimized, version-stamped Release build and lands a self-contained copy in `/Applications` — at **$0**, with no notarization and no Apple account. A locally-compiled app is never quarantined, so it launches clean past Gatekeeper. (The `$99` download channel — Developer ID + notarization + Homebrew — is a separate, deferred concern; see [`local-install-workflow-research.md`](../../../research/03-analysis/local-install-workflow-research.md) and [`distribution-signing-research.md`](../../../research/03-analysis/distribution-signing-research.md).)

## What Changes

- **New `make install` entry point** — builds `-configuration Release`, stamps a git-derived version, backs up any existing installed bundle, then copies (not symlinks) a self-contained `xtty.app` into a target applications directory (default `/Applications`, overridable via `INSTALL_DIR`). Reuses the existing `SIGN_FLAGS`/`XTTY_SIGN_IDENTITY` machinery unchanged (ad-hoc default; `xtty-dev` for TCC-grant persistence). No re-sign, no DMG, no notarization.
- **New `make restart` helper** — terminates any running instance and relaunches the freshly installed app, so the build→install→run loop is one command.
- **Version stamping in the install path** — the installed app carries a human-facing short version from the latest release tag (falling back to the committed `project.yml` `MARKETING_VERSION` when no tag is reachable) and a monotonic build number, injected via command-line xcodebuild build-setting overrides (verified to reach the synthesized `Info.plist`). The two Apple-spec plist fields stay numeric.
- **Version anchor** — the first annotated tag `v0.0.1` is cut so `git describe` has something to resolve (0 tags today).
- **Docs** — AGENTS.md → Building table gains the `make install` / `make restart` rows and a short "install a stable build" note.
- **Explicitly out of scope** (no work here): DMG packaging, notarization, Homebrew cask/tap, Sparkle/auto-update, universal (lipo) builds, a user-visible About panel. All are download-channel or later-polish concerns.

## Capabilities

### New Capabilities

<!-- none — this reuses the existing build-workflow capability -->

### Modified Capabilities

- `build-workflow`: add requirements for (1) a stable local install of the optimized Release build into `/Applications` (self-contained copy, backup-before-replace, ad-hoc/opt-in-signed, no notarization), (2) version-stamping the installed build from version control, and (3) a reinstall/relaunch helper.

## Impact

- **`Makefile`** — new `install` and `restart` targets + supporting variables (`INSTALL_DIR`, a Release-config app path, `VERSION`, `BUILD`); the existing `build`/`run`/`test`/`bench` targets are untouched (they stay on Debug).
- **`AGENTS.md`** — the Building section (targets table + a stable-install note).
- **`project.yml`** — no change required (the generated default `Release` config already optimizes: verified `-O` + wholemodule; the version is injected at build time via CLI override, not committed to the gitignored `.xcodeproj`).
- **Git** — one new annotated tag `v0.0.1`.
- **No app/product code, no `XttyCore`, no test code** — this is a build-tooling change (parallels `add-ci-pipeline` / `add-local-signing-identity`), so it adds **no new app runtime behavior** and therefore needs **no `verification-harness` delta**.
- **Signing** — none beyond what already exists; ad-hoc default stays creds-free.
