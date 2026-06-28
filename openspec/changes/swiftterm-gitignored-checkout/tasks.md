## 1. Remove the submodule

- [ ] 1.1 `git submodule deinit -f external/SwiftTerm`; `git rm --cached external/SwiftTerm`; remove the `external/SwiftTerm` entry from `.gitmodules` (delete the file if now empty); clear the `.git/config` submodule section + `.git/modules/external/SwiftTerm` remnants
- [ ] 1.2 `rm -rf external/SwiftTerm` (it will be re-cloned by the bootstrap); confirm `git status` no longer references a submodule/gitlink

## 2. Gitignored clone + pin + bootstrap

- [ ] 2.1 Add `external/SwiftTerm/` to `.gitignore`
- [ ] 2.2 Add the tracked pin: `patches/swiftterm/UPSTREAM_CONFIG.sh` (sourceable) with `UPSTREAM_URL=https://github.com/migueldeicaza/SwiftTerm.git` and `UPSTREAM_REF=v1.13.0`
- [ ] 2.3 Rewrite `scripts/bootstrap-swiftterm.sh`: source the pin; clone `external/SwiftTerm` if absent; idempotently `git fetch --tags && git checkout "$UPSTREAM_REF"` (enforce the pin); `cp patches/swiftterm/XttyAccessors.swift` into `external/SwiftTerm/Sources/SwiftTerm/`. Keep it idempotent + `set -euo pipefail`

## 3. Verify the build path is unaffected

- [ ] 3.1 Run `scripts/bootstrap-swiftterm.sh`; confirm `external/SwiftTerm` is a clean clone at `v1.13.0` with `XttyAccessors.swift` present, and `git status` shows no `external/` content (gitignored)
- [ ] 3.2 `swift build` + `swift test` in `XttyCore/` (162 green); `xcodegen generate` + `xcodebuild build`; run the spatial e2e (`-only-testing:xttyUITests/XttySpatialBlocksUITests`) — all green
- [ ] 3.3 Tidy the `XttyCore/Package.swift` comment (submodule → gitignored clone); confirm `Package.resolved` is sane

## 4. Docs + spec

- [ ] 4.1 Update AGENTS → Building: the SwiftTerm step now bootstraps a gitignored clone (no `git submodule update --init`); re-run after editing the patch/pin
- [ ] 4.2 Update `research/03-analysis/swiftterm-fork-vs-patch-strategy.md` Outcome to record B′ shipped
- [ ] 4.3 `openspec validate swiftterm-gitignored-checkout`; confirm ready to archive
