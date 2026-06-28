## Context

Building xtty requires four ordering-sensitive setup steps (XcodeGen install, Metal toolchain download, `scripts/bootstrap-swiftterm.sh`, `xcodegen generate`) plus four recurring commands (app build, XCUITests, `XttyCore` build/test). The exact commands live only in `AGENTS.md → Building` prose, which has drifted from reality — an adversarially-verified audit (14 agents, 9 candidates) found 4 confirmed-stale sites still describing the superseded SwiftTerm patch mechanism (submodule / `cp` drop-in / a deleted raw `XttyAccessors.swift`) as current, plus 2 borderline-loose phrasings.

Two setup steps have well-defined *inputs* and *outputs*, which makes them natural Make file-targets rather than blind re-runs:

```
   patches/swiftterm/{xtty-accessors.diff, UPSTREAM_CONFIG.sh}
                         │  (prerequisite — newer?)
                         ▼
   external/SwiftTerm/Sources/SwiftTerm/XttyAccessors.swift   ◀── scripts/bootstrap-swiftterm.sh
                         │   (sentinel target: the file the patch creates)
        project.yml ──┐  │
          (newer?)    ▼  ▼
   xtty.xcodeproj/project.pbxproj   ◀── xcodegen generate
                         │
                         ▼
              build / run / test
```

The other two setup steps (`brew install xcodegen`, `sudo xcodebuild -downloadComponent MetalToolchain`) cannot be safe file-targets — one needs Homebrew, one needs `sudo` — so they belong in a non-destructive `doctor` check that verifies and advises.

## Goals / Non-Goals

**Goals:**
- One discoverable entry point (`make`) for setup, build, run, and both test paths.
- `make build` self-heals: reconstitute SwiftTerm and regenerate the project *only when their tracked inputs changed*.
- Bring every "how it works now" surface back in sync with the actual SwiftTerm mechanism.
- Keep the raw commands documented — the Makefile wraps them, it does not hide them.

**Non-Goals:**
- No CI pipeline / GitHub Actions (none exists yet; out of scope).
- No change to `project.yml`, `scripts/bootstrap-swiftterm.sh` logic, or any Swift source.
- No new app behavior, DEBUG dump field, or product capability — so **no `verification-harness` delta**; the Makefile targets running green *are* this change's verification.
- Not rewriting the historical record: archived OpenSpec changes and dated `research/` decision snapshots that mention the old mechanism stay as-is.

## Decisions

### D1: Real file-targets for the two re-runnable setup steps (not all-`.PHONY`)
Model `external/SwiftTerm/Sources/SwiftTerm/XttyAccessors.swift` (the file the patch creates — a verified-good sentinel) and `xtty.xcodeproj/project.pbxproj` as real Make targets with their tracked inputs as prerequisites. `make build` then re-bootstraps/regenerates only when stale. Explicit `make bootstrap` / `make generate` remain as `.PHONY` force targets.
- *Alternative considered:* everything `.PHONY`, always re-run. Simpler, but re-clones/re-generates needlessly and loses Make's whole advantage. Rejected.
- *Note:* `bootstrap-swiftterm.sh` already enforces the pin + cleans every run, so even a forced re-run is safe and idempotent — the file-target only avoids the cost.

### D2: Default target is `help`, auto-generated from `##` comments
`make` with no target prints the target list. Self-documenting via a tiny `grep`/`awk` over `## ` trailing comments on each target — the standard portable idiom, satisfies the "self-documenting entry points" requirement.

### D3: `make run` builds into a fixed `-derivedDataPath build/`
Build with `xcodebuild ... -derivedDataPath build/` so the product path is deterministic (`open build/Build/Products/Debug/xtty.app`) and `make clean` is a simple `rm -rf build`.
- *Alternative considered:* parse `xcodebuild -showBuildSettings` for `BUILT_PRODUCTS_DIR`. More robust to config but slower and more fragile to parse. Rejected for the common case.
- *Trade-off:* diverges from Xcode's own DerivedData, so using both `make` and Xcode means two build dirs (mild disk/dup-build cost). Acceptable for a CLI convenience.

### D4: Test split — `test` = UI (heavy), `test-core` = fast `XttyCore` loop
`make test-core` → `swift test` in `XttyCore/` (the fast ~160-unit inner loop, no app build). `make test` → `xcodebuild test -scheme xtty -destination 'platform=macOS'` (the XCUITests). Mirrors how the project is actually developed.

### D5: `doctor` verifies but never installs privileged components
Check `command -v xcodegen`, `xcode-select -p` points at full Xcode (not CLT), and `xcrun -f metal` succeeds. Print the fix for each missing item (`brew install xcodegen`, the Xcode/CLT switch, `sudo xcodebuild -downloadComponent MetalToolchain`) and exit non-zero. Never run `sudo` or `brew` itself — the developer stays in control of privileged/install actions.

### D6: GNU make 3.81-compatible (macOS default), no GNU-only extras
macOS ships GNU make 3.81. Avoid newer-only features; keep recipes POSIX-sh. Use `.PHONY` correctly; one tab-indented recipe style. Keep the file small and readable.

### D7: Drift fix scope — 4 confirmed + 2 borderline tightenings, history untouched
Apply the audit's 4 confirmed-stale edits (`UPSTREAM_CONFIG.sh:5`, `AGENTS.md:23`, `AGENTS.md:129`, `research/04-design/02-milestones.md:55`) and tighten the 2 borderline-loose spots (`XttyCore/Package.swift` "dropped in", the `xtty-accessors.diff` created-file header's options-list lead). Leave the dated `research/03-analysis/p4b-2-spatial-blocks-decisions.md` snapshot and the archived OpenSpec delta as intentional history (the audit's adversarial pass confirmed both are historical, not stale).

### D8: Does this warrant a new established spec? Yes — `build-workflow`
The spec-driven schema requires a spec delta, and the build/setup contract currently lives only in drift-prone prose. A small `build-workflow` capability gives that contract a source of truth — parallel to the existing meta `verification-harness` spec — so the next drift has something authoritative to fail against. The spec stays mechanism-neutral (the *what*: reproducible reconstitution, untracked generated project, one-command entry points, prereq check); the Makefile and its targets (the *how*) live here in design.

### D9: Tighten the `terminal-spatial-blocks` spec too (residual the audit missed)
Verification's residual grep caught "add-only **drop-in** patch/file" still in the established `terminal-spatial-blocks` spec — the audit had reported "no stale refs in specs/", but its specs-region pass missed these. The phrasing sits inside the deliberately mechanism-neutral "means of injecting the addition … is NOT fixed by this requirement" clause (with fork/vendored listed as alternatives), so by the audit verifier's own standard (applied to the identical *archived* copy) it is the least-stale instance — not a current-truth misrepresentation. We tighten it anyway for zero-"drop-in"-on-current-truth consistency, the explicit goal of this change.
- **Mechanism:** a `MODIFIED` requirement delta (the convention forbids hand-editing established specs; they change only via `openspec archive`). The block is pasted whole with only "drop-in file" → "applied add-only patch"; neutrality is preserved (still "an implementation choice … NOT fixed by this requirement", still lists fork/vendored). No behavioral change, so no scenario edits.
- **The Purpose line:** the spec's `## Purpose` also carries "drop-in patch", but deltas don't carry Purpose. Per the "finish the merge by hand" lifecycle step, the Purpose is hand-fixed when this change archives — tracked as an explicit task so it isn't forgotten.
- *Alternative considered:* leave it (defensible — neutral phrasing, verifier-ruled not-stale). Rejected by the user in favor of full consistency; the cost is one wording-only modified capability.

## Risks / Trade-offs

- **[Makefile drifts from `project.yml`/`AGENTS.md` over time]** → Keep the Makefile thin (it only invokes documented commands), reference `AGENTS.md → Building` in a header comment, and have `doctor` be the one place prerequisites are encoded.
- **[Fixed `derivedDataPath` duplicates Xcode's build dir]** → Documented in the `run` target comment; `make clean` removes it; developers who only use Xcode are unaffected.
- **[A future macOS make or a user's `gmake` differs]** → Stick to 3.81-compatible syntax (D6); `doctor` does not assume a make version (the user already ran `make`).
- **[Sentinel file-target could be deleted by `git clean` in the SwiftTerm checkout]** → That is the *correct* trigger to re-bootstrap; the file-target rebuilds it. Harmless.

## Migration Plan

Additive: add `Makefile`, fix the drifted comments/docs, refresh `AGENTS.md → Building` to lead with `make`. No rollback concerns — deleting the Makefile restores the prior (documented) manual workflow. Verify by running each target end-to-end on this machine.

## Open Questions

- None blocking. (Optional future: a `make ci` aggregate or GitHub Actions — deferred until a CI need exists.)
