## Context

xtty is built via a `Makefile` wrapping XcodeGen (which generates the **gitignored** `xtty.xcodeproj`) + `xcodebuild`. Today `make run` = `xcodebuild build` (Debug, no `-configuration`) → `open build/Build/Products/Debug/xtty.app` — an unoptimized build launched in place from the volatile `build/` dir. The signing default is ad-hoc `"-"` ("Sign to Run Locally"); an opt-in self-signed `xtty-dev` cert (env `XTTY_SIGN_IDENTITY`, already threaded through the Makefile's `SIGN_FLAGS`) keeps code identity stable across rebuilds so TCC grants persist. App Sandbox is OFF; Hardened Runtime is OFF; SwiftTerm is a statically-linked local SPM dependency.

This design adds a `make install` that produces a **stable, versioned, optimized** build in `/Applications`, at $0. The approach and every load-bearing assumption were settled in [`research/03-analysis/local-install-workflow-research.md`](../../../research/03-analysis/local-install-workflow-research.md) — a 12-terminal comparator sweep plus three local verification spikes. The recommended shape is **iTerm2's** install target (the only OSS comparator with a real copy-to-`/Applications`) with **Ghostty's** git-derived versioning (the closest Swift/AppKit + Xcode analog).

## Goals / Non-Goals

**Goals:**
- A single `make install` producing an **optimized Release** build, **version-stamped** from git, installed as a **self-contained copy** in `INSTALL_DIR ?= /Applications`, with the previous bundle backed up.
- Reuse the existing `SIGN_FLAGS`/`XTTY_SIGN_IDENTITY` machinery verbatim — creds-free ad-hoc by default; `xtty-dev` for TCC-grant persistence.
- A `make restart` convenience (kill + relaunch).
- Keep `make run`/`make build`/`make bench` exactly as they are (Debug iteration path).

**Non-Goals:**
- DMG packaging, notarization, Developer ID, Homebrew cask/tap, Sparkle/auto-update — all **download-channel** concerns, `$99`-gated, deferred to `add-distribution-signing` / `add-homebrew-distribution`.
- Universal (lipo) builds — build the single native arch; universal is a release-only concern.
- A user-visible About panel / in-app version surface — deferred (would add app runtime behavior and thus a `verification-harness` delta; not needed for a Finder/`Get Info`-visible stamp).
- Any app/product/`XttyCore`/test code change.

## Decisions

**D1 — `make install` builds `-configuration Release`, not Debug.** The core fix: `make build`/`make run` pass no `-configuration` and default to Debug. `make install` invokes `xcodebuild … -configuration Release … $(SIGN_FLAGS) <version overrides>` and installs from `build/Build/Products/Release/xtty.app`. *Verified:* XcodeGen's default `Release` config already optimizes (`SWIFT_OPTIMIZATION_LEVEL = -O`, `SWIFT_COMPILATION_MODE = wholemodule`, `ENABLE_NS_ASSERTIONS = NO`; Debug is `-Onone`) — so **no `configs:` block in `project.yml` is needed**. *Alternative rejected:* pinning explicit Release optimization settings in `project.yml` (Ghostty's `ReleaseLocal` style) — unnecessary since the default already optimizes.

**D2 — Install = backup + `ditto` copy to `INSTALL_DIR ?= /Applications`.** Mirror iTerm2: `mv` any existing `$(INSTALL_DIR)/xtty.app` → `xtty.app.bak` (cheap rollback), then `ditto "$(RELEASE_APP)" "$(INSTALL_DIR)/xtty.app"`. **`ditto`, not `cp -R`** — `ditto` preserves xattrs/ACLs/resource-fork/hardlink fidelity (`cp -R` does not; the two are *not* equivalent). **A copy, never a symlink** into `build/` — kitty's source-bound symlinked bundle breaks on `make clean`; a copy is what lets the install survive cleaning. `INSTALL_DIR` is a make variable so `make install INSTALL_DIR=~/Applications` works with no admin write. *Note:* an admin user's CLI `ditto`/`cp` into `/Applications` does **not** prompt (the dir is group-admin-writable); a non-admin gets `EACCES` (documented escape hatch: `INSTALL_DIR=~/Applications`).

**D3 — No re-sign, no DMG, no notarization.** `xcodebuild` emits a fully-formed, already-signed `.app` (Info.plist synthesized from `project.yml` via `GENERATE_INFOPLIST_FILE`, identity from `SIGN_FLAGS`). So there is **no bundle-stitching and no manual `codesign`** step (and never the deprecated `--deep` that Alacritty/rio/wezterm use). *Verified:* a locally-compiled app carries **no `com.apple.quarantine`** (checked on both Debug and Release builds), so an ad-hoc/`xtty-dev` Release copied to `/Applications` launches clean past Gatekeeper. Ghostty's `disable-library-validation` entitlement is **N/A** — verified SwiftTerm is statically linked (no `Frameworks/`, no dylib) and Hardened Runtime is OFF.

**D4 — Version stamped via command-line xcodebuild build-setting overrides, in the install path.** Because the `.xcodeproj` is gitignored, the version can't be committed to the pbxproj — inject it at build time: `MARKETING_VERSION="$(VERSION)" CURRENT_PROJECT_VERSION="$(BUILD)"` on the install `xcodebuild` call. *Verified:* the CLI override reaches the **synthesized** `Info.plist` under `GENERATE_INFOPLIST_FILE=YES` (a probe build with `MARKETING_VERSION=9.9.9 CURRENT_PROJECT_VERSION=4242` produced exactly those in `CFBundleShortVersionString`/`CFBundleVersion`) — so **no PlistBuddy post-step**. *Alternatives rejected:* PlistBuddy post-build (more moving parts) and injecting at `xcodegen generate` time (couples versioning to project regeneration).

**D5 — Version values: numeric plist fields, git-tag-anchored, project-version floor.**
- `VERSION` (→ `MARKETING_VERSION` → `CFBundleShortVersionString`) = the latest reachable tag with the `v` prefix stripped, via `git describe --tags --abbrev=0` (**not** `--always`), falling back to `project.yml`'s committed `0.0.1` when no tag is reachable or git is unavailable. Kept **numeric** (Apple requires ≤3 dot-separated integers).
- `BUILD` (→ `CURRENT_PROJECT_VERSION` → `CFBundleVersion`) = `git rev-list --count HEAD` (monotonic), falling back to `1`.
- Cut an annotated **`v0.0.1`** tag as part of this change so `git describe` resolves (0 tags today).
- *Critic-refuted alternative:* `git describe --tags --always --dirty || echo 0.0.1` — `--always` **succeeds** with a bare commit hash when there are no tags, so the `|| echo` floor never fires and the plist field goes non-numeric. Rejected. *(If a commit-hash/dirty descriptive stamp is ever wanted, it goes in a separate custom Info.plist key, never in the two Apple-spec fields — deferred with the About panel.)*

**D6 — Same bundle id `com.xtty.app` as the Debug `make run` build.** One TCC/config/Launch-Services identity set — simplest for a solo daily-driver. *Trade-off:* a Debug `make run` rebuild shares that identity with the installed stable app (a dev rebuild can perturb the stable app's Launch Services/TCC identity). *Alternative rejected for v1:* a distinct id (e.g. `com.xtty.app.stable`, Warp-`Stable`/Wave-`Dev` style) — clean coexistence but doubles TCC grants and needs a `project.yml` config split. Chosen explicitly in the explore session.

**D7 — No `verification-harness` delta.** This is a **build-tooling** capability — it adds no app *runtime* behavior (parallels `add-ci-pipeline` and `add-local-signing-identity`, neither of which carried a harness delta). Acceptance is **build-output verification** (the installed bundle's config, stamped `Info.plist`, install location, absence of quarantine, and a launch smoke), not an XCUITest observation. The version stamp is read via `PlistBuddy`, not via the custom-drawn view's DEBUG dump. Consequently the verify tasks are **cheap/inline** and carry **no `⟶ xtty-test-validator` marker** — no Tier-1 XCUITest suite, VM tier, or full acceptance matrix is required (the change touches only the `Makefile` + docs + a git tag, not the app or test targets).

## Risks / Trade-offs

- **Debug/Release share `build/` DerivedData** → a Release install build and a Debug iteration build interleave in the same derived-data root. *Mitigation:* they land in distinct `…/Products/{Debug,Release}/` subdirs; `make install` reads only the Release product path. No separate derived-data dir needed.
- **Replacing a *running* `/Applications/xtty.app`** → `ditto` over a bundle whose executable is running can fail or leave a half-copied bundle. *Mitigation:* `make restart` (D-restart) terminates the running instance; document "quit xtty (or `make restart`) before reinstalling", and the `.bak` backup gives rollback.
- **Non-admin write to `/Applications`** → `EACCES`, not a prompt. *Mitigation:* documented `INSTALL_DIR=~/Applications` escape hatch.
- **Shared bundle id (D6)** → a Debug `make run` can perturb the stable app's Launch Services/TCC identity. *Mitigation:* accepted for a solo daily-driver; revisit with a distinct id only if dev/stable collision becomes a real annoyance.
- **`git describe` in a shallow/tagless checkout** (e.g. a fresh CI clone) → no reachable tag. *Mitigation:* the `project.yml` floor (D5) guarantees a valid numeric version regardless; `make install` is a local-daily-driver command, not a CI step.

## Migration Plan

Additive and reversible — no existing behavior changes.
1. Add the `install`/`restart` targets + `INSTALL_DIR`/`RELEASE_APP`/`VERSION`/`BUILD` vars to the `Makefile`.
2. Cut the annotated `v0.0.1` tag.
3. Update AGENTS.md → Building (targets table + stable-install note).
- **Rollback:** remove the two targets (and, if desired, the tag). Nothing else references them; `make run`/`build`/`test`/`bench` are untouched. An already-installed `/Applications/xtty.app` is a plain copy the user can delete.

## Open Questions

- **Tag cadence** — who cuts `v0.0.1` and subsequent tags on the solo push-to-main flow, and whether a CHANGELOG rides along. *(Resolution: cut `v0.0.1` in this change; later tags are a manual solo action at the owner's discretion — no automation now.)*
- **CLI shim** — none today (xtty ships no `xtty` CLI); revisit only if a CLI is added (wezterm/Hyper symlink an inner executable into `PATH`).
- **About panel / in-app version surface** — deferred; if added later it reads the same `$(VERSION)` source and pulls in a `verification-harness` delta at that time.
