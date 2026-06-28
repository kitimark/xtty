## Why

P4b-2 ships its two SwiftTerm engine accessors via a **git submodule** (`external/SwiftTerm` @ `v1.13.0`) with our add-only `XttyAccessors.swift` **copied into** the submodule's source tree by `scripts/bootstrap-swiftterm.sh`. That copy is a loose build artifact: it is version-controlled only in `patches/`, not at its compile location, and the parent tree stays clean only via a `.gitmodules` `ignore = untracked` hack. A git submodule is the wrong primitive for a dependency we *patch* — a submodule is a pristine pointer to an upstream commit used as-is; dropping a file into it leaks the abstraction.

Playwright (the model we drew from) doesn't submodule the thing it patches — it **gitignores the upstream checkout** (`browser_patches/firefox/.gitignore` → `/checkout`) and tracks only the patch + the pin + a script that reconstitutes the checkout on demand. Adopting that here removes the wart: the upstream tree becomes unambiguous, fully-gitignored build infrastructure, and the only things in version control are our patch, the pin, and the bootstrap. The mechanism is temporary anyway (it is torn out and replaced by a plain version bump once the accessors land upstream), so the goal is *cleanest-to-live-with and easiest-to-delete*. Rationale + the options comparison: `research/03-analysis/swiftterm-fork-vs-patch-strategy.md` (the "B′" follow-up).

## What Changes

- **Drop the git submodule.** `git submodule deinit` + remove the `external/SwiftTerm` gitlink and the `.gitmodules` entry. No more submodule mechanics.
- **Gitignore the upstream checkout.** Add `external/SwiftTerm/` to `.gitignore` so the whole clone is explicit build infrastructure (like `.build/`); `git status` is clean *by gitignore*, not by `ignore = untracked`.
- **Add a tracked pin file.** A small `patches/swiftterm/UPSTREAM_REF` (and the upstream URL) holds the pinned ref (`v1.13.0`), replacing the submodule gitlink as the source of the pin.
- **Bootstrap clones + enforces the pin + applies the patch.** `scripts/bootstrap-swiftterm.sh` becomes self-contained: clone `external/SwiftTerm` if absent, idempotently `fetch && checkout <UPSTREAM_REF> && git clean -fd` (so the pin can't drift and the patch always applies onto a pristine tree), then `git apply patches/swiftterm/xtty-accessors.diff`. One command does everything (no separate `submodule update --init`).
- **Patch as a tracked `.diff`.** The accessor ships as `patches/swiftterm/xtty-accessors.diff` (a new-file diff) applied via `git apply`, replacing the raw `patches/swiftterm/XttyAccessors.swift` + `cp` — the canonical, review-as-a-patch artifact, matching Playwright's `bootstrap.diff` exactly. (For a pure add a `cp` would also work; the `.diff` is a deliberate review preference. Regenerate it from a pristine checkout with `git add -N … && git diff`.)
- **Keep everything else identical.** `XttyCore/Package.swift` still points at `.package(path: "../external/SwiftTerm")`. The build is unaffected: `bootstrap` then build, same as today.
- **Docs:** update AGENTS → Building to describe the gitignored-clone bootstrap; tidy the `Package.swift` comment.
- **Spec accuracy:** update the `terminal-spatial-blocks` mechanism *example* (it currently names "a pinned submodule") to reflect the gitignored clone. The normative requirement is unchanged — it already states the mechanism is not fixed by the spec.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `terminal-spatial-blocks`: a spec-accuracy update only — the engine-coordinate-provider requirement's mechanism *example* changes from "a pinned submodule with an add-only drop-in file" to a gitignored clone reconstituted from a pinned ref. No normative (SHALL) change; the requirement already declares the injection means an implementation choice.

## Impact

- **Build/dependency wiring:** `.gitmodules` removed; `.gitignore` gains `external/SwiftTerm/`; `patches/swiftterm/UPSTREAM_REF` added; `scripts/bootstrap-swiftterm.sh` rewritten to clone + enforce the pin. `XttyCore/Package.swift` path dependency unchanged (comment tidied). `XttyCore/Package.resolved` may re-record the path dep.
- **Onboarding/CI:** fresh clones run `scripts/bootstrap-swiftterm.sh` (now does the clone too) instead of `git submodule update --init` + bootstrap. Documented in AGENTS → Building.
- **No code/behavior change:** `App`, `XttyCore` logic, the accessors, and all tests are untouched; the feature and its e2e are unaffected. The upstream-PR retirement path (task 8.4 of `add-spatial-blocks`) is unchanged — when it lands, the checkout + pin + script are deleted and `Package.swift` reverts to a versioned `url:` dependency.
- **Reproducibility:** the bootstrap-enforced `checkout <ref>` keeps the pin as strong as the submodule gitlink in practice (drift requires not re-running bootstrap, same as editing `.build/`).
