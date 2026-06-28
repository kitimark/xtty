## 1. Makefile — core targets

- [x] 1.1 Create top-level `Makefile` with `.PHONY` declarations, GNU make 3.81-compatible syntax (D6), and a header comment pointing at `AGENTS.md → Building`.
- [x] 1.2 Add `help` as the default target (auto-generated from `## ` trailing comments on each target) so `make` with no argument lists targets (D2).
- [x] 1.3 Add `doctor`: verify `xcodegen` present, `xcode-select -p` is full Xcode (not CLT), and `xcrun -f metal` succeeds; print the fix for each missing item and exit non-zero; never run `sudo`/`brew` (D5).

## 2. Makefile — file-target dependency graph

- [x] 2.1 Add a real file-target for the SwiftTerm sentinel `external/SwiftTerm/Sources/SwiftTerm/XttyAccessors.swift` with prerequisites `patches/swiftterm/xtty-accessors.diff` and `patches/swiftterm/UPSTREAM_CONFIG.sh`; recipe runs `scripts/bootstrap-swiftterm.sh` (D1).
- [x] 2.2 Add a real file-target for `xtty.xcodeproj/project.pbxproj` with prerequisite `project.yml` (and the SwiftTerm sentinel); recipe runs `xcodegen generate` (D1).
- [x] 2.3 Add `.PHONY` force targets `bootstrap` and `generate` that invoke the script / xcodegen directly regardless of staleness.

## 3. Makefile — build / run / test / clean

- [x] 3.1 Add `build` (depends on the generated project) → `xcodebuild -project xtty.xcodeproj -scheme xtty -derivedDataPath build build` (D3).
- [x] 3.2 Add `run` → build, then `open build/Build/Products/Debug/xtty.app` (D3).
- [x] 3.3 Add `test` (UI) → `xcodebuild test -project xtty.xcodeproj -scheme xtty -destination 'platform=macOS' -derivedDataPath build` (D4).
- [x] 3.4 Add `test-core` and `build-core` → `swift test` / `swift build` run in `XttyCore/` (fast path, no app build) (D4).
- [x] 3.5 Add `setup` (the post-clone combo: `doctor` → bootstrap sentinel → generate) and `clean` (`rm -rf build` + SPM `.build`) and `reset` (remove `external/SwiftTerm`, re-bootstrap, regenerate).

## 4. Fix SwiftTerm-mechanism documentation drift (audit findings)

- [x] 4.1 `patches/swiftterm/UPSTREAM_CONFIG.sh:5` — replace "drops in XttyAccessors.swift" with the `git apply patches/swiftterm/xtty-accessors.diff` wording (matches the script body).
- [x] 4.2 `AGENTS.md` Current-status P4b-2 bullet (~line 23) — replace "pinned submodule + drop-in … `patches/swiftterm/XttyAccessors.swift`" with "gitignored upstream clone + `git apply`'d `patches/swiftterm/xtty-accessors.diff` (pinned via `UPSTREAM_CONFIG.sh`)".
- [x] 4.3 `AGENTS.md` Current-open-changes paragraph (~line 129) — replace "via a pinned submodule + drop-in" with "via a gitignored upstream clone + git-apply patch".
- [x] 4.4 `research/04-design/02-milestones.md:55` — replace "shipped via a pinned submodule + drop-in (no fork repo)" with the gitignored-clone + git-apply'd `.diff` wording (keep "no fork repo" and the trailing reference).
- [x] 4.5 Tighten the 2 borderline spots: `XttyCore/Package.swift` comment ("…accessor file dropped in" → "…applied via `git apply`") and the `patches/swiftterm/xtty-accessors.diff` created-file header (reword the options-list so it does not lead with "submodule + drop-in").
- [x] 4.6 Leave intentional history untouched: `research/03-analysis/p4b-2-spatial-blocks-decisions.md:124` and the archived OpenSpec delta (confirmed historical by the audit).

## 5. Refresh build docs to lead with `make`

- [x] 5.1 Update `AGENTS.md → Building` to present `make <target>` as the primary path (setup/build/run/test/test-core), keeping the underlying raw commands documented for reference.
- [x] 5.2 Cross-check `research/03-analysis/swiftterm-fork-vs-patch-strategy.md` and `research/README.md` for any stale mechanism wording introduced/affected, and align if needed.

## 6. Verify (the targets are the verification — no harness delta)

- [x] 6.1 From a clean state, `make doctor` reports correctly; `make setup` then `make build` builds the app green without manual bootstrap/generate.
- [x] 6.2 `make build` a second time does NOT re-bootstrap or re-generate (file-targets up to date); `touch project.yml` then `make build` re-generates; re-running bootstrap stays idempotent.
- [x] 6.3 `make test-core` runs the `XttyCore` unit suite green without an app build; `make test` runs the XCUITests green; `make run` launches the app.
- [x] 6.4 `git status` shows the generated project and `external/SwiftTerm` remain untracked; `grep` for "submodule"/"drop-in"/"XttyAccessors.swift" on current-truth surfaces returns only intentional-history hits.
- [x] 6.5 `openspec validate streamline-build-setup` passes.

## 7. Tighten the `terminal-spatial-blocks` spec wording (D9 — residual audit miss)

- [x] 7.1 Add a `MODIFIED` requirement delta for `terminal-spatial-blocks` ("Engine-only scroll-invariant coordinate provider"), pasting the full block and changing "add-only drop-in file" → "applied add-only patch" (neutrality preserved, no scenario/behavior change).
- [x] 7.2 Reflect the new capability in `proposal.md` (Modified Capabilities + What Changes + Impact).
- [x] 7.3 Record decision D9 in `design.md` (why tighten, MODIFIED-not-hand-edit, Purpose-at-archive).
- [x] 7.4 `openspec validate streamline-build-setup` still passes with the second delta.
- [ ] 7.5 **At archive only:** hand-fix the merged `openspec/specs/terminal-spatial-blocks/spec.md` **Purpose** line ("add-only drop-in patch" → "add-only applied patch") — deltas don't carry Purpose; this is the "finish the merge by hand" step.
