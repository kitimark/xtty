## Context

P4b-2 (`add-spatial-blocks`) added two engine accessors to SwiftTerm via a **git submodule + drop-in copy** (Option B): `external/SwiftTerm` is a submodule pinned to `v1.13.0`; `scripts/bootstrap-swiftterm.sh` copies `patches/swiftterm/XttyAccessors.swift` into the submodule's `Sources/SwiftTerm/`; `XttyCore/Package.swift` uses `.package(path: "../external/SwiftTerm")`. The drop-in is a loose build artifact (tracked only in `patches/`, not at its compile location), and the parent tree is kept clean by `.gitmodules` `ignore = untracked`.

A re-read of Playwright — the model this drew from — showed it does **not** submodule the thing it patches: `browser_patches/firefox/.gitignore` is `/checkout`, i.e. the upstream tree is a **gitignored clone**, and only the patch + pin + scripts are tracked. The insight: *a submodule is the wrong primitive for a patched dependency* (it's a pristine-pointer abstraction that the drop-in leaks). Full analysis + the options comparison: `research/03-analysis/swiftterm-fork-vs-patch-strategy.md` ("B′"). This change migrates B → B′.

This is a **build-mechanism change only** — no app/engine code, no behavior, no test changes. The `terminal-spatial-blocks` requirement already declares the injection mechanism "an implementation choice and … NOT fixed by this requirement," so the only spec touch is updating its illustrative example.

## Goals / Non-Goals

**Goals:**
- Remove the loose-drop-in-inside-a-tracked-submodule wart: make the upstream checkout fully-gitignored build infrastructure, with only the patch + pin + script tracked.
- Keep reproducibility on par with the submodule (a bootstrap that enforces the pinned ref).
- Keep the build path identical (`bootstrap` then build) and the retirement path intact (delete everything when the upstream PR lands).

**Non-Goals:**
- No change to the accessors, the `XttyCore`/App code, or any test.
- Not switching to a fork repo (still avoiding an external repo) and not vendoring in-tree.

## Decisions

### D1 — Gitignored clone, not a submodule
Deinit and remove the `external/SwiftTerm` submodule (drop the gitlink + the `.gitmodules` entry) and add `external/SwiftTerm/` to `.gitignore`. The upstream tree becomes scratch build-infra (like `.build/`), so `git status` is clean by gitignore — no `ignore = untracked` hack, no "untracked file inside a tracked submodule."
- **Alternative rejected — keep the submodule:** the abstraction leaks for a patched dep (the whole reason for this change).
- **Alternative rejected — fork / vendor:** fork needs an external repo (ruled out); vendor commits SwiftTerm's tree into xtty and is the heaviest to later delete (this mechanism is temporary). See the research doc's comparison table.

### D2 — A tracked pin file, enforced by the bootstrap
Add `patches/swiftterm/UPSTREAM_REF` holding the pinned ref (`v1.13.0`) and the upstream URL (a tiny `UPSTREAM_CONFIG`-style file, mirroring Playwright). `scripts/bootstrap-swiftterm.sh`:
1. read `UPSTREAM_REF` (+ URL);
2. `git clone <url> external/SwiftTerm` if absent;
3. **idempotently** `git -C external/SwiftTerm fetch --tags && git checkout <ref> && git clean -fd` — so the pin cannot drift without re-running bootstrap (parity with the submodule gitlink) and the tree is pristine before each apply;
4. `git -C external/SwiftTerm apply patches/swiftterm/xtty-accessors.diff`.
One command does clone + pin + apply (no separate `git submodule update --init`).
- **Why a pin file, not a script constant:** keeps the pin a small, reviewable, single-purpose tracked artifact (the only "what version" source of truth), matching Playwright's `UPSTREAM_CONFIG.sh`.

### D3 — `XttyCore/Package.swift` unchanged (path dep), comment tidied
The dependency stays `.package(path: "../external/SwiftTerm")`; SwiftPM doesn't care that the path is gitignored (it only needs a valid package on disk). Only the explanatory comment changes (submodule → gitignored clone).

### D3a — Patch as a tracked `.diff` applied via `git apply` (review preference)
The accessor is tracked as `patches/swiftterm/xtty-accessors.diff` (a new-file diff) and applied with `git apply` onto the pristine checkout, rather than a raw `.swift` + `cp`. For a pure-add either works; the `.diff` was chosen on review as the canonical patch artifact (it reads as a patch and is Playwright's exact form — `bootstrap.diff`). **Idempotency:** `git apply` refuses if the target already exists, so the bootstrap restores a pristine tree (`checkout <ref>` + `git clean -fd`) before each apply — re-runs are safe. The `.diff` is regenerated from a pristine checkout via `git add -N <file> && git diff` (a tiny "export" step; the accessor is stable, so this is rare).

### D4 — Spec accuracy, not a behavior change
Update only the mechanism *example* in `terminal-spatial-blocks`'s coordinate-provider requirement ("a pinned submodule with a drop-in file" → "a gitignored upstream clone reconstituted from a pinned ref with an add-only drop-in file"). No SHALL clause changes.

## Risks / Trade-offs

- **Pin not git-native (a value in a file vs a gitlink).** → Mitigation: the bootstrap enforces `checkout <ref>` every run, so drift requires actively skipping bootstrap (same risk class as hand-editing `.build/`). Reproducibility ≈ parity.
- **First build clones over the network.** → Same as the submodule's `update --init`; unchanged. (CI caches `external/SwiftTerm/` like any build dir.)
- **Someone builds without bootstrapping.** → Loud failure: `.package(path:)` won't resolve / the accessor won't exist → compile error. AGENTS → Building documents the one-time step (already a prerequisite today).
- **Migration leaves a stale submodule registration.** → Mitigation: `git submodule deinit -f`, remove `.gitmodules` + `.git/config` submodule section + `.git/modules/external/SwiftTerm`, then `rm -rf external/SwiftTerm` and re-bootstrap to a clean clone; verify `git status` shows only the intended tracked changes.

## Migration Plan
1. `git submodule deinit -f external/SwiftTerm`; `git rm --cached external/SwiftTerm`; delete the `.gitmodules` entry (remove the file if it becomes empty); clear the `.git/config` + `.git/modules` submodule remnants; `rm -rf external/SwiftTerm`.
2. Add `external/SwiftTerm/` to `.gitignore`.
3. Add `patches/swiftterm/UPSTREAM_REF` (ref + URL); rewrite `scripts/bootstrap-swiftterm.sh` to clone + enforce-pin + drop-in.
4. Run the bootstrap → confirm `external/SwiftTerm` is a clean clone at `v1.13.0` with the accessor dropped in.
5. `swift build`/`swift test` (XttyCore) + `xcodebuild build` + the spatial e2e to confirm the build path is unaffected; `git status` shows only tracked changes (no `external/` content).
6. Tidy `XttyCore/Package.swift` comment + AGENTS → Building; update the research doc's "Outcome" to B′.
- **Rollback:** re-add the submodule (`git submodule add … external/SwiftTerm` @ the pin) + restore `.gitmodules`/`ignore = untracked`; the bootstrap copy step is identical either way.

## Open Questions
- **Pin-file format** — a 2-line `UPSTREAM_REF`/`UPSTREAM_URL` file vs a sourceable `UPSTREAM_CONFIG.sh` (Playwright-style). Lean: a tiny sourceable shell file, so the bootstrap just `source`s it. Decide during apply.
