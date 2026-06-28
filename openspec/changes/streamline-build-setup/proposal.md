## Why

Setting up and building xtty takes **four ordering-sensitive setup steps across four tools** (`brew install xcodegen`, `sudo xcodebuild -downloadComponent MetalToolchain`, `scripts/bootstrap-swiftterm.sh`, `xcodegen generate`) before any of **four recurring commands** (app build, XCUITests, `XttyCore` build, `XttyCore` test) will work — and the bootstrap/generate steps must be re-run only when specific inputs change. The exact incantations live only as prose in `AGENTS.md → Building`, and that prose has already **drifted**: an adversarially-verified audit found 4 stale sites still describing the superseded SwiftTerm patch mechanism (git *submodule* / `cp` *drop-in* / the deleted raw `XttyAccessors.swift`) as the current one. New contributors (and future sessions) have to reconstruct the workflow from drifted docs.

## What Changes

- **Add a top-level `Makefile`** as the single, self-documenting entry point for setup, build, test, and run. Targets: `help` (default), `doctor`, `setup`, `build`, `run`, `test`, `test-core`, `build-core`, `bootstrap`, `generate`, `clean`, `reset`.
  - The two re-runnable setup steps are modeled as **real Make file-targets** so `make build` self-heals — it re-bootstraps SwiftTerm only when the pin/patch changed, and regenerates the Xcode project only when `project.yml` changed — instead of re-running them blindly or relying on the user to remember.
  - `make doctor` verifies the un-automatable prerequisites (XcodeGen present, full Xcode selected, Metal toolchain installed) and advises rather than running `sudo` itself.
- **Fix the SwiftTerm-mechanism documentation drift** surfaced by the audit: 4 confirmed-stale sites (`patches/swiftterm/UPSTREAM_CONFIG.sh`, `AGENTS.md` ×2, `research/04-design/02-milestones.md`) plus 2 borderline tightenings (`XttyCore/Package.swift`, the `xtty-accessors.diff` header) so every "this is how it works now" surface matches the actual mechanism (gitignored upstream clone + `git apply` of the tracked `.diff`).
- **Refresh `AGENTS.md → Building`** to present `make <target>` as the primary path while keeping the raw commands documented for non-`make` users and for understanding what each target does.
- This is **dev-tooling + documentation only**: no application/runtime behavior, no product capability, no user-facing change.

## Capabilities

### New Capabilities
- `build-workflow`: the project's build/setup contract — reproducible reconstruction of the patched-but-pinned SwiftTerm, generation of the (untracked) Xcode project from `project.yml`, a single-command build/test/run entry point, and a prerequisite check. Records as source-of-truth what currently lives (and drifts) only in `AGENTS.md` prose. Parallels the existing meta `verification-harness` spec.

### Modified Capabilities
- _(none — the audit found no stale references in `openspec/specs/`, and the Makefile changes no existing requirement.)_

## Impact

- **New file:** `Makefile` (top-level).
- **Edited (docs/comments only, no logic):** `AGENTS.md`, `patches/swiftterm/UPSTREAM_CONFIG.sh` (header comment), `XttyCore/Package.swift` (comment), `patches/swiftterm/xtty-accessors.diff` (created-file header comment), `research/04-design/02-milestones.md`, `research/03-analysis/swiftterm-fork-vs-patch-strategy.md` (cross-check), `research/README.md` if a line shifts.
- **No change to:** any Swift source, `project.yml`, `scripts/bootstrap-swiftterm.sh` logic, the build outputs, or any product behavior. The Makefile only *invokes* the already-documented commands.
- **New established spec on archive:** `openspec/specs/build-workflow/spec.md`.
- **Risk:** low — additive tooling over existing commands; the Makefile must stay in sync with `project.yml`/`AGENTS.md` (mitigated by `doctor` + comments), and must use macOS-default GNU make 3.81-compatible syntax.
