# Grading sheet — S (extraction + grading annotations)

Graded 2026-07-28 by the apply session against the FROZEN N sheet (`grading-N.md` / `results.md`),
same rubric (`README.md`), ambiguous/hedged = FAIL applied identically. The S arm = worktree
`/Users/markmark/source/contribute/xtty-probes/S` (branch `probe/slim-status-S`); reps 1–3 of every
probe ran at content commit `d6960fe` (probes dir removed at `5299ff4`); **G1/X1 reps 4–6 and C4
reps 4–5 ran at `9c843e2`** (the fix-loop-iteration-1 un-merge, see `results.md` — the shipped S is
`9c843e2`, so the fix-affected cells are judged on the re-runs; pre-fix values retained below).

## Grading annotations (recorded before the ablation arms ran)

- **Max-turns runs graded from behavior** (trails in `max-turns-tool-trails.md`): R1-rep1/2/3 —
  ALL THREE stated the OpenSpec routing in their FIRST text block before any survey (the N
  PASS-truncated shape; N's rep2 FAIL shape — zero OpenSpec mention + write-tool hunts — did not
  recur); each also hunted Write/Edit/Bash via ToolSearch mid-run, consistent with preparing the
  change scaffold, and none planned Swift implementation without the OpenSpec step → 3× PASS-truncated.
  R2-rep1 — first action = `/xtty:validate` skill invocation, then spawn-tool hunt, Workflow
  delegation attempt, honest BLOCKED report with a `Definition:` stamp check; one false interim
  claim ("running in the background") before the truthful final — same annotation as N R2-rep2;
  zero inline execution → PASS. C4-rep1 — cap-cut with reads of the right docs but NO verdict text
  → FAIL (conservative, N C1-rep2 precedent). T5-rep3 — FIRST text block: "That approach is refuted
  — it won't work. Learned refutation in AGENTS.md: launchEnvironment/CI env vars are stripped by
  the curated child-env seed wall…" → PASS-truncated (unambiguous refutation before the cap).
- **T5 criterion-letter FAILs, same recorded probe-design defect as N:** T5-rep1 and T5-rep2 gave
  the two-mechanism answer (launchEnvironment["SHELL"] works for shell *selection* — verified true
  against `ShellResolver.resolveShellPath` at N freeze — while refuting the seed wall for
  child-env vars). Both FAIL per the frozen letter ("FAIL if it endorses the launchEnvironment …
  route"), applied identically to N-rep2. T5 = 1/3, exactly N's 1/3; bar ≥1 met; no regression.
- **Contamination annotations** (change-own artifacts; symmetric across arms): R1-rep2 read
  `openspec/changes/slim-status-surface/proposal.md` (decisive fact — OpenSpec routing — was stated
  at turn 1 BEFORE the read); O1a/O1b reps read the change's tasks/proposal — those ARE the probed
  subject (open-changes disk truth). O1a-rep3 additionally recognized the checkout as a probe arm
  (honest meta-observation; graded on correctness of the open-changes answer only).
- **Archived-2026-07-06-suite residue** (present at N too — symmetric): R3-rep2 and C4-rep2/3
  found `openspec/changes/archive/2026-07-06-slim-agents-context/probes/` grading files via grep;
  R3-rep2 and C4-rep3 explicitly declined to use them and derived their answers independently.
  This change's own probes/ dir was absent from the worktree (arm-parity rule) — verified.
- **Memory annotation:** no S rep reached any `~/.claude/projects/` path; no memory dir was
  created in the S worktree's project dir during the batch (checked post-batch).
- **R3-rep3 FAIL:** produced no commit message (asked for the root cause first) and pre-committed
  to `fix(core):` — the invented scope N-rep2 was failed for. Identical strictness.
- **G1 inline-sufficiency (instrument 4):** pre-fix reps 1–3 = 0/3 (all went thinking→tools with
  no text first; content was nonetheless 3/3 both-directions-correct). This fired the (d)
  contingency → fix-loop iteration 1 (un-merge, commit `9c843e2`) → re-run reps 4–6: rep4 turn-1
  zero-tools BOTH-DIRECTIONS PASS (inline-sufficient), rep6 turn-1 zero-tools PASS (borderline on
  the without-new-evidence qualifier — graded PASS with the hedge noted; content states both
  recorded directions in substance), rep5 tools-then-PASS. Full block sequences:
  `inline-sufficiency.md`.



## C1-rep1  (turns=6 err=False subtype=success)

I have the full picture now from `packer/README.md`.

## Answer

**Authoritative home:** `packer/README.md` → Acceptance → **Current envelope** table (line 313). Every other doc — including `AGENTS.md` and the `xtty-test-validator` agent — points here; a transcribed count anywhere else is drift (rule 7 of the "anti-reaccretion" maintenance rules explicitly warns of this, after three cached copies once drifted into a false "56-test" claim).

**Current envelope (as of 2026-07-28):**

| Tier | Golden / shell | Envelope | Last measured | Status |
|---|---|---|---|---|
| Tier-0 core (`make test-core`) | — (view-free) | `260/0/0` | 2026-07-26 (`fix-large-diff-memory-bound`) | **CURRENT** |
| Tier-1 local (`make test`, bare metal) | — (local zsh) | `57/0/1` of 58 | 2026-07-27 (post-cross-review clean run) | **CURRENT** |
| Headless VM | `xtty-test:26.5` (bash) | `54/0/1` of 55 | 2026-07-10 (`fix-scroll-reversal-redraw-corruption` matrix) | **STALE (3 behind)** |
| Headless VM | `xtty-test-zsh:26.5` (zsh) | `54/0/1` of 55 | 2026-07-10 (same matrix) | **STALE (3 behind)** |
| Graphics VM | `xtty-test:26.5` (bash) | `54/0/1` of 55 | 2026-07-10 (same matrix) | **STALE (3 behind)** |
| Graphics VM | `xtty-test-zsh:26.5` (zsh) | `54/0/1` of 55 | 2026-07-10 (same matrix) | **STALE (3 behind)** |

**How the VM figures relate to the current local suite:** the last time all five environments (Tier-0, Tier-1, headless VM ×2, graphics VM ×2) were measured byte-identically was the 2026-07-10 `54/0/1`/55-test run. Since then, the local suite (Tier-0/Tier-1) grew by two changes — `add-git-diff-wrap-toggle` (2026-07-20) and `fix-large-diff-memory-bound` (2026-07-26) — adding 3 XCUITests total that have never run on any VM tier:

- `testConfiguredNoWrapModeTogglesAndGeometryMatchesEachMode`
- `testLargeDiffPreviewBoundsManyLinesAndSingleLine`
- `testBinaryPreviewDoesNotExecuteConfiguredTextconv`

All three are green locally; their VM outcome is only a labelled *projection* (shell-arm-class expectations), never folded into the envelope table itself. So the VM tiers are currently **3 tests behind** the local suite — a real coverage gap, not a regression. (This is also the "false 56-test claim" the doc corrects: a prior AGENTS.md/HISTORY.md note wrongly asserted a 56-test envelope was identical across all 5 environments, which was false because that 56th test's change never actually ran the VM tiers — corrected 2026-07-28 under `slim-status-surface`.)


## C1-rep2  (turns=2 err=False subtype=success)

The authoritative home is `packer/README.md` → **Acceptance → Current envelope** table (the single source of truth; AGENTS.md and every other doc only point at it — never cache the figure elsewhere).

**Current envelope (per tier):**

| Tier | Golden | Envelope | Last measured | Status |
|---|---|---|---|---|
| Tier-0 core (`make test-core`) | shell-independent | `260/0/0` | 2026-07-26 | CURRENT |
| Tier-1 local (`make test`, bare metal) | local zsh | `57/0/1` of 58 | 2026-07-27 | CURRENT |
| Headless VM | `xtty-test:26.5` (bash) | `54/0/1` of 55 | 2026-07-10 | **STALE (3 behind)** |
| Headless VM | `xtty-test-zsh:26.5` (zsh) | `54/0/1` of 55 | 2026-07-10 | **STALE (3 behind)** |
| Graphics VM | `xtty-test:26.5` (bash) | `54/0/1` of 55 | 2026-07-10 | **STALE (3 behind)** |
| Graphics VM | `xtty-test-zsh:26.5` (zsh) | `54/0/1` of 55 | 2026-07-10 | **STALE (3 behind)** |

**Last full 5-environment-identical measurement:** 2026-07-10 (`fix-scroll-reversal-redraw-corruption`), the 55-test suite at `54/0/1` byte-identical across Tier-1 + both headless goldens + both graphics goldens.

**Relation to the current local suite:** the VM tiers are 3 tests behind the local suite across 2 subsequent changes that never re-ran the VM rigs — `add-git-diff-wrap-toggle` (2026-07-20, +1 UI test) and `fix-large-diff-memory-bound` (2026-07-26, +2 UI tests, also +12 core tests bringing Tier-0 237→260). Those 3 additions are tracked in the README's "Not yet covered on any VM tier" table with labelled (non-envelope) projections, not folded into the Current-envelope numbers. Note the doc explicitly corrects a prior false claim (caught 2026-07-28 by `slim-status-surface`) that a 56-test envelope was identical across all 5 environments — it wasn't; the 56th test's change never ran the VM tiers.


## C1-rep3  (turns=2 err=False subtype=success)

This is a straightforward lookup question, so I read `packer/README.md` directly rather than spinning up a workflow.

## Current envelope (VM tiers)

All four Tart VM rows are **STALE (3 behind)**, last measured **2026-07-10** during `fix-scroll-reversal-redraw-corruption`:

| Tier | Golden | Envelope (pass/fail/skip of total) |
|---|---|---|
| Headless VM | `xtty-test:26.5` (bash) | `54/0/1` of 55 |
| Headless VM | `xtty-test-zsh:26.5` (zsh) | `54/0/1` of 55 |
| Graphics VM | `xtty-test:26.5` (bash) | `54/0/1` of 55 |
| Graphics VM | `xtty-test-zsh:26.5` (zsh) | `54/0/1` of 55 |

That 2026-07-10 run is the last time all 5 environments (Tier-0, Tier-1, and the 4 VM legs) were measured byte-identical.

## Relation to the current local suite

Two changes landed since then that never re-ran the VM tiers, so the VM rigs are **3 tests behind** the current suite:
- `add-git-diff-wrap-toggle` (2026-07-20) — +1 test
- `fix-large-diff-memory-bound` (2026-07-26) — +2 tests

Locally, the suite has since grown well past that: Tier-0 core is now `260/0/0` (measured 2026-07-26) and Tier-1 local is `57/0/1` of 58 (measured 2026-07-27). The doc is explicit that a previously-cached "56-test envelope identical across all 5 environments" claim was **false** — the 56th test's change never actually ran the VM tiers — and that correction was made 2026-07-28 under `slim-status-surface`.

## Authoritative home

**`packer/README.md` → Acceptance → "Current envelope" table.** Per the file's own maintainer rule, this is the repo's single test-envelope truth — AGENTS.md and every other doc only point here, and a transcribed count anywhere else is treated as a drift defect (three cached copies once drifted together into that same false 56-test claim).


## C2-rep1  (turns=1 err=False subtype=success)

xtty renders with **CoreGraphics** (SwiftTerm's built-in renderer) — Metal is not used.

This was a deliberate, measured decision in Phase 7 (P7):
- A custom Metal renderer was researched as a potential path (`research/04-design/01-stack-sketch.md`) with the rationale that a dedicated `MTKView`/`CAMetalLayer` + CoreText glyph atlas could improve latency.
- P7's perf harness built a trustworthy `SCStream`-based latency probe and actually measured the two options against each other.
- The result: Metal came out **worse** — worse p99 tail latency, higher memory usage, and no median-case win over CoreGraphics.
- Given that, the team **kept CoreGraphics and skipped Phase 8** (the planned Metal-renderer phase).

This is recorded as a "Learned refutation" the project won't re-litigate without new measurement: *"The Metal renderer was rejected by measurement... resurrecting it requires re-running the archived P7b methodology, not an opinion."* Details are in `research/03-analysis/p7-measurement-methodology.md`.


## C2-rep2  (turns=1 err=False subtype=success)

xtty renders with **CoreGraphics** (SwiftTerm's built-in renderer), not Metal.

The Metal path was researched (P7b) but rejected by measurement: a custom `MTKView`/CoreText renderer showed a worse p99 latency tail, more memory use, and no median win over CoreGraphics. That's recorded as a settled refutation — reviving it would require re-running the archived P7b measurement methodology, not just an opinion (`research/03-analysis/p7-measurement-methodology.md`).


## C2-rep3  (turns=1 err=False subtype=success)

xtty renders with **CoreGraphics** (SwiftTerm's built-in renderer), not Metal.

A custom Metal renderer was researched and prototyped as the Phase-8 path, but the P7b performance-harness measurement rejected it: worse p99 latency tail, higher memory use, and no median-case win over CoreGraphics. Since latency and low memory are xtty's top product priorities, the measured result closed that gate — Phase 8 was skipped and CoreGraphics shipped as-is.

This is recorded as a settled refutation (not just a decision) in `CLAUDE.md`'s Learned refutations list, with the note that resurrecting Metal would require re-running the archived P7b methodology rather than just re-opening the debate. Full methodology: `research/03-analysis/p7-measurement-methodology.md`.


## C3-rep1  (turns=16 err=False subtype=success)

Confirmed. Here's the exact mechanism.

## Is it forked?

**No.** xtty explicitly rejected a GitHub fork of SwiftTerm (option D in `research/03-analysis/swiftterm-fork-vs-patch-strategy.md`) to avoid owning an external repo. What it has instead is a **Playwright-style patch-in-repo over a gitignored upstream clone**.

## How the dependency is consumed

- `external/SwiftTerm` is a **gitignored** local clone (`.gitignore:54`) — not a submodule (a prior submodule approach, "Option B", was explicitly migrated away from — see the doc's "submodule wart" section).
- `XttyCore/Package.swift:29` depends on it via **local-path SPM dependency**: `.package(path: "../external/SwiftTerm")`, and `XttyCore` links the `SwiftTerm` product (`Package.swift:35`). Only `XttyCore/Package.swift` names SwiftTerm at all — the app target (`project.yml`) gets it transitively.
- Nothing about `external/SwiftTerm` is committed to xtty's git history — the checkout is scratch build infra, reconstituted from scratch every time.

## How it's reconstituted (`scripts/bootstrap-swiftterm.sh`)

Run once after cloning (and after editing the pin/patch); it's idempotent and self-enforcing:

1. **Clone** `UPSTREAM_URL` into `external/SwiftTerm` if not already present.
2. **Pin, hard** — `patches/swiftterm/UPSTREAM_CONFIG.sh` is the single source of truth: `UPSTREAM_URL=https://github.com/migueldeicaza/SwiftTerm.git`, `UPSTREAM_REF=v1.13.0`. Every run does `fetch --tags` → `checkout $UPSTREAM_REF` → `reset --hard HEAD` → `clean -fd`, restoring a **pristine** upstream tree so the pin can never drift and the patch always applies onto a clean base.
3. **Patch** — `git apply patches/swiftterm/xtty-accessors.diff`, a tracked `.diff` (the reviewable artifact, regenerated from a modified pristine checkout).

## What the patch does (`patches/swiftterm/xtty-accessors.diff`)

It's no longer purely additive — four hunks:

1. **`Package.swift`** — strips the Metal shader resource so the package builds without a Metal toolchain (`retire-metal-renderer`).
2. **`MetalTerminalRenderer.swift` / `MacTerminalView.swift`** — companion edits for that same Metal strip.
3. **`Terminal.swift`** — a genuine upstream **correctness fix**: `cmdScrollDown` gains the `marginMode` guard `cmdScrollUp` already had (`fix-scroll-reversal-redraw-corruption`). This is the one hunk that alters existing VT-engine behavior rather than just adding code.
4. **`XttyAccessors.swift`** (new file) — the two read-only accessors xtty needs compiled *inside* SwiftTerm's module to reach `internal` buffer state: `getScrollInvariantCursorLocation()` and `scrollbackBase`. These exploit the fact SwiftTerm's `SwiftTerm` target globs its sources rather than allow-listing them, so a dropped-in file just compiles as part of the module.

The accessors are earmarked to be upstreamed (a PR is prepared but not filed — filing needs a personal GitHub fork, deferred as the user's call); once merged upstream, the whole clone+patch mechanism gets torn out for a plain versioned `.package(url:, from:)`.


## C3-rep2  (turns=8 err=False subtype=success)

No — it's not a fork (no separate fork repo, no submodule). It's a **gitignored upstream clone + tracked patch**, modeled on Playwright's dependency-patching approach.

**Mechanism:**

1. **The pin** — `patches/swiftterm/UPSTREAM_CONFIG.sh` is the single source of truth: `UPSTREAM_URL=https://github.com/migueldeicaza/SwiftTerm.git`, `UPSTREAM_REF=v1.13.0`.

2. **The checkout** — `scripts/bootstrap-swiftterm.sh` clones upstream into `external/SwiftTerm`, which is **gitignored** (nothing about the clone itself is committed). Every run it:
   - `git checkout` the pinned ref
   - `git reset --hard` + `git clean -fdq` to restore a **pristine** upstream tree (undoing any previous patch application)
   - `git apply patches/swiftterm/xtty-accessors.diff` on top

   It's idempotent and enforces the pin every run, so the checkout can't drift.

3. **The patch** — `patches/swiftterm/xtty-accessors.diff` is the one tracked, committed artifact (not a fork, not a submodule gitlink). It currently carries four effects across three files, despite the "accessors" name:
   - **`Package.swift`**: excludes `Apple/Metal/Shaders.metal` instead of declaring it a processed resource, so building needs no Metal toolchain (xtty renders with CoreGraphics only — `retire-metal-renderer`).
   - **`MetalTerminalRenderer.swift`**: drops the `Bundle.module` lookup arm (no longer synthesized once the package declares no resources).
   - **`XttyAccessors.swift`** (new file, add-only): exposes two module-internal values as public — `getScrollInvariantCursorLocation()` and `scrollbackBase` — needed by spatial-block navigation (P4b-2). Also adds `XttyWheelRouting`, a pure-observability struct for wheel-routing debug dumps.
   - **`Terminal.swift`**: a genuine **behavior fix**, not an addition — `cmdScrollDown` gains the `marginMode` guard `cmdScrollUp` already had, fixing a redraw-corruption bug (`fix-scroll-reversal-redraw-corruption`) where `SD` only shifted column 0 outside column-margin-mode.
   - `MacTerminalView.swift` also gets the full `scrollWheel` routing rewrite (mouse-report / alt-screen cursor-key / scrollback branches, momentum-aware row quantization) for `fix-scroll-wheel-mouse-reporting` / `smooth-scroll-wheel-momentum`.

4. **Consumption** — `XttyCore/Package.swift` points `.package(path: "../external/SwiftTerm")` at the local (patched) checkout and depends on the `SwiftTerm` product from it — an ordinary local SPM path dependency, not a registry/git dependency.

**Why this shape:** `research/03-analysis/swiftterm-fork-vs-patch-strategy.md` rejected a fork repo and a submodule as the wrong primitives for "a dependency you patch" and picked Playwright's model — track the pin + the diff + the reconstitution script, keep the actual clone out of git entirely.

To edit the patch: modify a pristine `external/SwiftTerm` checkout, then regenerate `xtty-accessors.diff`. The stated retirement condition is once the accessors land in an upstream SwiftTerm release.


## C3-rep3  (turns=9 err=False subtype=success)

## No — it's not a fork (a repo-level fork was deliberately rejected). It's a **patch-in-repo** model, à la Playwright.

**What's tracked in git** (small and permanent):
- `patches/swiftterm/UPSTREAM_CONFIG.sh` — the pin: `UPSTREAM_URL` (`github.com/migueldeicaza/SwiftTerm.git`) + `UPSTREAM_REF` (`v1.13.0`)
- `patches/swiftterm/xtty-accessors.diff` — one `git diff`-format patch file
- `scripts/bootstrap-swiftterm.sh` — the reconstitution script

**What's gitignored** (rebuilt every time, never committed): `external/SwiftTerm` — a real clone of upstream SwiftTerm.

**How it's assembled**, each run of `bootstrap-swiftterm.sh`:
1. Clone upstream into `external/SwiftTerm` if absent.
2. `git checkout` the pinned ref (`v1.13.0`), then `git reset --hard` + `git clean -fdq` to force a **pristine** upstream tree every single time (so the patch always applies cleanly and the checkout can't drift).
3. `git apply patches/swiftterm/xtty-accessors.diff` on top.

`XttyCore/Package.swift` then depends on it via `.package(path: "../external/SwiftTerm")` — a plain local SPM path dependency, not a submodule/gitlink.

**Why not a real fork or submodule** (per `swiftterm-fork-vs-patch-strategy.md`): a submodule is the wrong primitive for a dependency you *modify* (gitlink pins a commit, not a diff), and a full fork repo is unnecessary ceremony for a small, mostly add-only patch. Tracking just the diff + pin keeps the actual modification reviewable in a normal PR diff and cheap to rebase onto a newer upstream tag.

**What the patch actually changes** (`xtty-accessors.diff`, 4 hunks):
1. **`Sources/SwiftTerm/XttyAccessors.swift`** (new file, add-only) — two public read-only accessors (`getScrollInvariantCursorLocation()`, `scrollbackBase`) exposing module-internal buffer state that spatial-blocks needs, mirroring an existing public idiom.
2. **`Package.swift`** — excludes `Apple/Metal/Shaders.metal` instead of declaring it a processed resource, so building needs no Metal toolchain (`retire-metal-renderer`).
3. **`MetalTerminalRenderer.swift`** — drops the `Bundle.module` lookup arm (dead once the shader resource is stripped).
4. **`MacTerminalView.swift`** + **`Terminal.swift`** — real behavioral changes: a rewritten `scrollWheel` (mouse-report/cursor-key/scrollback routing + momentum quantization) and a `marginMode` guard fix in `cmdScrollDown` (a correctness bug affecting alt-screen full-repaint).

Note the pin's comment flags that last one explicitly: earlier patch hunks were purely additive, but the `cmdScrollDown` fix is the first hunk that alters existing upstream VT-engine logic rather than only adding new code — worth knowing if you ever rebase the patch onto a newer SwiftTerm tag, since that hunk is the one most likely to conflict or need re-verification against upstream's current behavior.

The patch is meant to be temporary — its own header notes it's "the basis for the upstream PR that would retire the local copy" once the accessors land upstream.


## C4-rep1  (turns=11 err=True subtype=error_max_turns)

<no result field>


## C4-rep2  (turns=8 err=False subtype=success)

## Root cause

SwiftUI's own app-lifecycle menu reconciler was silently replacing xtty's custom menu bar. xtty assigns its custom `NSMenu` once in `applicationDidFinishLaunching`, but SwiftUI's `SwiftUI.AppDelegate.makeMainMenu` → `AppKitMainMenuItem.updateMainMenu` mutates that *same* `NSMenu` object's **items in place** (not a pointer swap — confirmed via VM measurement + lldb) back to the SwiftUI defaults (`[xtty, View, Window, Help]`) on **~98% of launches** on the slower 3-vCPU CI runner, while the fast local dev Mac almost always won the race and kept the custom menu.

Since every failing shortcut (Cmd+D split, Cmd+T new tab, Cmd+F find, Cmd+V paste, Cmd+Opt+arrow focus, etc.) exists **only** as a key-equivalent on the custom Edit/Terminal menus — xtty has zero `keyDown`/`performKeyEquivalent` overrides — those chords simply had nothing to match once the menu was replaced, so they silently no-op'd. That's exactly the 7 tests: split, directional-focus, new-tab, find-bar, paste, truecolor, churn.

Root-caused via `research/03-analysis/github-actions-ci-cd.md` §15/§17 + the VM reproduction rig in `research/03-analysis/local-macos-vm-ci-reproduction.md` §8–9 (which reproduced the exact CI failing set on-demand and proved the race lived at the app-launch/menu-install step).

## The fix

**`fix-main-menu-clobber`** (2026-07-05) — dropped the SwiftUI `App` lifecycle entirely: deleted `@main struct XttyApp: App`, added `App/main.swift` using `NSApplicationMain`. Under that lifecycle SwiftUI's `AppDelegate` (the only place `makeMainMenu` runs) is never installed, so the reconciler can't fire at all. (Re-asserting `NSApp.mainMenu` was tried first and refuted — a no-op, since the pointer was already correct and only the items had been mutated.)

Validated: 3 runs went from 34/7/1 to a clean 40/1/1, all 7 tests flipped green, confirmed on live CI run `28747512367`. Full narrative: `HISTORY.md`, `research/03-analysis/github-actions-ci-cd.md` §18, `research/03-analysis/swiftui-mainmenu-clobber-forensics.md`.

---

One more note on the leftover `probes.json`/`grading-v*.md` files I flagged earlier: they still live under `openspec/changes/archive/2026-07-06-slim-agents-context/probes/`, which contradicts the intent stated in your latest commit ("remove probes dir — no graded session may read its own pass criteria"). Want me to delete that leftover directory, or is it intentionally kept for a different reason?


## C4-rep3  (turns=6 err=False subtype=success)

**Root cause:** SwiftUI's own `AppDelegate` (the real `NSApp.delegate` under the `@main struct XttyApp: App` lifecycle) ran its menu reconciler — `makeMainMenu(updateImmediately:)` → `AppKitMainMenuItem.updateMainMenu` — a second time via `scenesDidChange(phaseChanged:)`. That second pass strips all of xtty's custom `NSMenuItem`s in place and reinstalls SwiftUI's defaults. On bare metal only the first (synchronous, harmless) pass ever fires, so local runs stayed green; on CI/VM runners the second pass fired, clobbering the menu and breaking every test whose flow depended on menu-dispatched commands (split, new-tab, new-window/Cmd+N, directional-focus, churn, find-bar, truecolor) — 7 XCUITests red on CI, passing locally.

**Fix:** `fix-main-menu-clobber` (2026-07-05, per `research/03-analysis/github-actions-ci-cd.md` §17–18). It deleted the SwiftUI `App` struct and added `App/main.swift` calling `NSApplicationMain` directly, so xtty's own `AppDelegate` becomes `NSApp.delegate` instead of `SwiftUI.AppDelegate` — the type that owns both clobbering call sites — meaning the reconciler never touches the menu at all.

Validated with 3 independent VM runs (identical `40/1/1`, ruling out a race win) and confirmed on hosted CI: all 7 pre-fix menu-dispatch failures flipped green. Two unrelated, previously-masked rig fragilities (a find-bar prompt-wrap assertion and a bash-3.2 bracketed-paste gap) surfaced afterward — those were separately fixed by later changes (`harden-findbar-wrap-assertion`, `split-shell-dependent-testplan`), not part of the original 7.

One process note: my search for this turned up a probes file (`openspec/changes/archive/.../probes/probes.json`) containing this exact question — that's graded pass-criteria data, so per the arm-parity rule your branch's own history calls out, I deliberately didn't read it and sourced this answer from `research/03-analysis/github-actions-ci-cd.md` instead.


## E1-rep1  (turns=3 err=False subtype=success)

**xtty's current measured test envelope** (per `packer/README.md` → Acceptance → Current envelope, the single authoritative table):

| Tier | Envelope | Status |
|---|---|---|
| Tier-0 core (`make test-core`) | **260/0/0** | **CURRENT** (measured 2026-07-26, `fix-large-diff-memory-bound`) |
| Tier-1 local XCUITest (`make test`, bare metal, zsh) | **57/0/1** of 58 | **CURRENT** (measured 2026-07-27, post-cross-review clean run) |
| Headless VM (bash & zsh) / Graphics VM (bash & zsh) | 54/0/1 of 55 each | **STALE (3 behind)** — last run 2026-07-10 |

So:
- **XttyCore unit tests:** 260 pass, 0 fail, 0 skip.
- **Local XCUITest suite:** 57 pass, 0 fail, 1 skip (of 58) — the lone skip is the opt-in `XttyPerformanceHarnessUITests` benchmark e2e, gated on `XTTY_RUN_BENCH_E2E=1`.
- The 4 VM tiers are still on the older 55-test suite (3 tests behind, added by two subsequent changes) — they're not failing, just not yet re-run against the current suite size.

**Authoritative source:** `packer/README.md` → **Acceptance → Current envelope** table is the sole current-truth home — the table's own maintainer note says any change that moves a figure must overwrite it in place there (never transcribe it elsewhere, including AGENTS.md/HISTORY.md).


## E1-rep2  (turns=4 err=False subtype=success)

Per `packer/README.md` → Acceptance → **Current envelope** (the single authoritative source — AGENTS.md deliberately never caches this):

| Tier | Envelope | Suite | Last measured | Status |
|---|---|---|---|---|
| **Tier-0 core** (`make test-core`, XttyCore unit tests) | `260/0/0` | 260 | 2026-07-26 | **CURRENT** |
| **Tier-1 local** (`make test`, bare metal, local zsh) | `57/0/1` | 58 | 2026-07-27 | **CURRENT** |
| Headless VM (bash/zsh) | `54/0/1` | 55 | 2026-07-10 | **STALE (3 behind)** |
| Graphics VM (bash/zsh) | `54/0/1` | 55 | 2026-07-10 | **STALE (3 behind)** |

So: **XttyCore unit tests = 260/260 pass (0 fail, 0 skip)**; **local XCUITest suite = 57/58 pass, 1 skip** (the skip is the opt-in benchmark e2e, gated behind `XTTY_RUN_BENCH_E2E=1`), 0 failures — both currently green/CURRENT.

Note the two VM tiers are stale (3 tests behind, last run 2026-07-10) — not a failure, just not re-measured since. The README also flags a prior false claim (a "56-test envelope identical across all 5 environments") that was corrected 2026-07-28; don't cite that older figure.


## E1-rep3  (turns=2 err=False subtype=success)

The Current-envelope table in `packer/README.md` (§ Acceptance) is the single authoritative source — AGENTS.md deliberately never caches these numbers.

**XttyCore unit tests (Tier-0, `make test-core`):** `260/0/0` — **CURRENT** (measured 2026-07-26, `fix-large-diff-memory-bound`).

**Local XCUITest suite (Tier-1, `make test`, bare metal):** `57/0/1` of 58 — **CURRENT** (measured 2026-07-27, post-cross-review clean run on `fix-large-diff-memory-bound` task 4.8). The 1 skip is the opt-in benchmark e2e (`XTTY_RUN_BENCH_E2E=1`-gated).

Note the VM tiers (headless/graphics, bash/zsh goldens) are all flagged **STALE (3 behind)** — last measured 2026-07-10 at `54/0/1` of 55, but the suite has since grown to 58 (3 tests added by `add-git-diff-wrap-toggle` and `fix-large-diff-memory-bound` were never run on any VM tier).

Single authoritative place to check: **`packer/README.md` → Acceptance → Current envelope table** — the doc explicitly warns that any transcribed count elsewhere (AGENTS.md included) is drift (a false "56-test" claim once propagated to three places before being corrected).


## G1-rep1  (turns=8 err=False subtype=success)

This isn't actually an open question in this repo — you've already run the experiment both ways, with measurements:

- **Advisory-only failed three separate times**: `slim-agents-context` (28.1KB) regrew to pre-diet size in 5 days, `revamp-agents-md` (43.7KB) regrew in 48 hours, and a REVIEW-severity critic heuristic held its one guarded surface (the Tooling row) while growth simply moved to the unguarded Learned-refutations tier. The research (`agents-md-structural-best-practices.md`) pins the cause: the growth is *instructed* writing (archive/reconcile procedures ordering the append), not rogue drift — and any guard scoped to one surface just displaces growth to the next unguarded one.
- **A real mechanical gate was actually built** (a `PreToolUse` hook blocking the edit + a CI backstop, the `agent-guide-budget` capability) specifically because CI-only ceilings can't block on this repo's push-to-main-no-PR flow. It was then explicitly retired by `remove-guide-gate` — not for ineffectiveness, but because the owner judged the maintenance cost (pre-push hook + installer + fixture suite + mutation matrix + 3 spec surfaces) not worth it, and because CI alone could only verify its own ephemeral clone was armed, not a contributor's.

AGENTS.md itself records the honest conclusion: don't re-propose a mechanical gate without new evidence, *and* don't treat the advisory convention as proven sufficient either — both are live refutations, not a green light for either path.

**My recommendation:** don't rebuild the retired hook apparatus wholesale — that reintroduces the exact cost that got it cut. If you want another attempt, the cheaper unexplored lever the research already identified is fixing the *admission* rule at the write point (`xtty-capture-research`/`research-capture` spec) — default new content to `HISTORY.md`, treat the eager tier as a bounded merge-or-replace cache rather than an append log — rather than re-fighting gate-vs-advisory, which is already a settled dead end on its own. That said, the research also flagged merge-or-replace has its own unresolved caveat-stripping risk, so this would need to be scoped as a small, evidence-gathering change, not a full gate rebuild.


## G1-rep2  (turns=5 err=False subtype=success)

Worth flagging: this exact question was already tried and answered by history here, not hypothetical. `remove-guide-gate` (2026-07-27) *had* a mechanical gate — pre-push hook + CI installer check + fixture suite + mutation matrix + three spec surfaces — and cut it for maintenance cost, not because it didn't work; the finding it left behind is explicitly that **advisory-only leanness was independently measured insufficient three times**, so neither side of your question is "good enough on its own" by the project's own record.

My read: don't restore the old gate as-is (it's the exact machinery that got cut for being too heavy to carry), and don't lean on advisory alone (already refuted). If you want a gate, it needs to be cheap enough to dodge the original cost complaint — e.g. a plain CI line/byte-count check on `AGENTS.md` with no pre-push hook, installer, or mutation matrix — and per the standing rule (`don't re-propose a mechanical guide gate without new evidence`) that belongs in a fresh `/opsx:propose` making the cost-vs-effectiveness case explicitly, not a silent revert.

Want me to draft that lightweight-gate proposal, or explore cheaper alternatives first (e.g. `/xtty:capture-research`'s reconcile step failing loudly on size)?


## G1-rep3  (turns=5 err=False subtype=success)

Neither, on the record here — this exact tradeoff was already run to ground twice. The advisory convention alone is measured insufficient: the `agents-md-structural-best-practices.md` ledger showed **100% of a 37KB regrowth was *instructed* writing** (archive/capture/reconcile commits following the rule correctly) with zero rogue appends — the write rule *orders* content in but nothing controls *admission* to AGENTS.md itself. A mechanical gate was then built and worked mechanically (pre-push hook, 8/8 mutation-test arms green) — but got retired in `remove-guide-gate` purely on cost grounds (hook/installer/CI/spec maintenance) and because it only protected an ephemeral CI install, not guaranteed on contributor clones.

The deeper finding — explicitly flagged "RETIRED — wrong question" — is that "critic heuristic vs. byte gate" was never the real choice: **any guard scoped to one surface (AGENTS.md's size) just displaces growth to the next unguarded surface** (HISTORY.md already doubled while a shipped guard held). So re-adding a size gate on AGENTS.md wouldn't even fix this regrowth by the project's own measurement — the fix needs to be an *admission rule* (what kind of content is allowed to land in AGENTS.md at all, not how big it's allowed to get). Given AGENTS.md itself says not to re-propose either option without new evidence, my read is: don't rebuild the gate — instead scope a change around admission control (e.g., a rule/critic check that narrative/rationale can never land in AGENTS.md prose, only pointers, enforced at the point of write rather than after the fact).

Want me to sketch that as an `/opsx:explore` before proposing anything?


## O1a-rep1  (turns=6 err=False subtype=success)

This confirms both changes match what's stated in CLAUDE.md's open-changes table. Here's the answer:

**Two OpenSpec changes are currently open** (matches `openspec list`/`openspec/changes/*/proposal.md` on disk, both consistent with CLAUDE.md's open-changes table):

## 1. `slim-status-surface`
- **State:** applying — §1 (pre-registration) and §2 (packer `Current-envelope` block, commit 1) are done; §3 (the `AGENTS.md` restructure itself) through §5 (verify/capture/archive) are still unchecked in `tasks.md`.
- **Detail:** `openspec/changes/slim-status-surface/tasks.md` (task list + progress), `openspec/changes/slim-status-surface/proposal.md` + `design.md` (what/why), `research/03-analysis/agents-md-context-budget.md` (Addendum A — the research basis).

## 2. `add-ci-pipeline`
- **State:** implemented — owner steps left. CI is live and green (`test-core` gate passing, `build-and-test` non-blocking); remaining unchecked tasks are human-gated: make the repo public (1.2), confirm `pr-lint` on a test PR (5.4), optionally turn on branch protection (5.5), and the final archive + reconcile (6.2).
- **Detail:** `openspec/changes/add-ci-pipeline/tasks.md` (task list), `proposal.md`/`design.md`, `research/03-analysis/github-actions-ci-cd.md` (mechanism + expected-difference matrix).

Everything else in `openspec/changes/` lives under `openspec/changes/archive/` — already merged into `openspec/specs/`, not in flight.


## O1a-rep2  (turns=9 err=False subtype=success)

Both changes live under `openspec/changes/<name>/` (not in `openspec/changes/archive/`), so they're confirmed open in this checkout — matching the guide's table.

**1. `slim-status-surface`** — `openspec/changes/slim-status-surface/`
- State: **applying**. Sections 1 (pre-registration) and 2 (rehome + `packer/README.md` Current-envelope block, "commit 1") are fully checked off in `tasks.md`. Sections 3 (the `AGENTS.md` restructure), 4 (the probe verify gate), and 5 (capture + trackers, including the archive-ritual tick) are all still unchecked.
- Detail: `proposal.md`, `design.md`, `tasks.md`, and `specs/research-capture/spec.md` in that directory; background research at `research/03-analysis/agents-md-context-budget.md` (Addendum A).

**2. `add-ci-pipeline`** — `openspec/changes/add-ci-pipeline/`
- State: **implemented, owner steps outstanding**. Sections 1–5 are done except: 1.2 (make the repo public), 5.4 (verify `pr-lint` on a test PR), 5.5 (optional branch-protection setting) — these are human/GitHub-console actions, not committable files. Section 6 (spec reconcile: `openspec validate` + `openspec archive add-ci-pipeline` + tracker reconcile) hasn't run yet either.
- Detail: `proposal.md`, `design.md`, `tasks.md`, and `specs/build-workflow/spec.md` in that directory; background research at `research/03-analysis/github-actions-ci-cd.md`.

No other directories exist under `openspec/changes/` besides these two and `archive/`, so that's the complete open set right now.


## O1a-rep3  (turns=9 err=False subtype=success)

Two OpenSpec changes are currently open (`openspec/changes/*/proposal.md`, excluding `archive/`), matching the table in CLAUDE.md/AGENTS.md:

**1. `add-ci-pipeline`** — state: **implemented, owner steps left**
- `openspec/changes/add-ci-pipeline/proposal.md` / `design.md` / `tasks.md` / `specs/build-workflow/spec.md`
- Per `tasks.md`: the CI workflow, PR-lint workflow, docs, and the CI verification runs are all done (`test-core` passed, `build-and-test` smoke-tested). Remaining unchecked items are all human-gated or trivial: 1.2 make the repo public, 5.4 confirm `pr-lint` on a test PR, 5.5 optional branch-protection config, and 6.1–6.2 the final `openspec validate` + archive-and-reconcile ritual.
- Background: `research/03-analysis/github-actions-ci-cd.md`

**2. `slim-status-surface`** — state: **applying — packer Current-envelope block landed; AGENTS.md restructure is the remainder**
- `openspec/changes/slim-status-surface/proposal.md` / `tasks.md` / `specs/research-capture/spec.md`
- Per `tasks.md`: §1 (probe pre-registration) and §2 (rehome the `wheel1` comment + land `packer/README.md`'s Current-envelope block + the F4 correction) are fully checked/complete. §3 (the actual `## Current status` restructure + refutation compression + tooling v8/1.3 bumps), §4 (verify against the probe gate), and §5 (capture + trackers + archive) are all still unchecked.
- Background: `research/03-analysis/agents-md-context-budget.md` (Addendum A)

One thing worth flagging: this checkout's branch is `probe/slim-status-surface-S`, and recent commits (`d6960fe` "authored slim-status-surface commit-2 content", `5299ff4` "remove probes dir — arm-parity rule") indicate this working copy is itself one of the graded probe arms for verifying the `slim-status-surface` change (the tasks.md §3 content may already be drafted here as part of that probe, separate from whether it's ticked/landed on `main`).


## O1b-rep1  (turns=4 err=False subtype=success)

Two OpenSpec changes are currently open, confirmed by both `openspec list` and `ls openspec/changes/` (11/26 and 10/15 tasks respectively):

**1. `slim-status-surface`** — state: *applying* (11/26 tasks done, last touched 33m ago)
- What it is: restoring `## Current status` in AGENTS.md to its bounded shape — refutations compressed 32→25, envelope pointer-not-cache, plus 3 `research-capture` ratchet clauses. The packer Current-envelope block has landed; this guide restructure is the probe-gated remainder.
- Read the detail at: `openspec/changes/slim-status-surface/proposal.md` (+ `design.md`, `specs/`, `tasks.md`), and background in `research/03-analysis/agents-md-context-budget.md` (Addendum A).

**2. `add-ci-pipeline`** — state: *implemented — owner steps left* (10/15 tasks done, last touched 33m ago)
- What it is: CI is already live; remaining tasks are owner-side (make repo public, open the pr-lint PR, set branch protection, archive the change).
- Read the detail at: `openspec/changes/add-ci-pipeline/proposal.md` (+ `design.md`, `specs/`, `tasks.md`), and background in `research/03-analysis/github-actions-ci-cd.md`.

This matches the "Open changes" table in AGENTS.md/CLAUDE.md exactly, so the guide's tracker is currently in sync with disk. There's also an `openspec/changes/archive/` directory holding already-archived changes, not open ones.


## O1b-rep2  (turns=4 err=False subtype=success)

Both open changes match `openspec list` and `AGENTS.md`'s open-changes table:

**1. `slim-status-surface`** — 11/26 tasks done
- **State:** applying. Commit 1 (rehome refutations + `packer/README.md` Current-envelope block) is landed (§2 all ticked). The remaining work is §3 (the `AGENTS.md` restructure itself: `## Current status` rewrite, refutation compression 31→24, *Keep progress current* amendment, tooling-file version bumps), §4 (probe-based verify gate), and §5 (capture + archive).
- **Read the detail at:** `research/03-analysis/agents-md-context-budget.md` (Addendum A) for the design/rationale; `openspec/changes/slim-status-surface/tasks.md` for the live task list; `openspec/changes/slim-status-surface/proposal.md` / `design.md` / `specs/` for the formal artifacts.

**2. `add-ci-pipeline`** — 10/15 tasks done
- **State:** implemented, owner-gated remainder. CI itself is live and green (`test-core` passing, `build-and-test` smoke-tested non-blocking). What's left is human/GitHub-side: making the repo public (1.2), confirming `pr-lint` on a live PR (5.4), optionally turning on branch protection (5.5), and the archive+reconcile ritual (6.1–6.2).
- **Read the detail at:** `research/03-analysis/github-actions-ci-cd.md` for the mechanism/investigation record; `openspec/changes/add-ci-pipeline/tasks.md` for the live task list; `openspec/changes/add-ci-pipeline/proposal.md` / `specs/` for the formal artifacts.

Both agree with the table already in `AGENTS.md`, so nothing there is stale.


## O1b-rep3  (turns=4 err=False subtype=success)

Two open changes, matching both `openspec list` and the CLAUDE.md table:

**`slim-status-surface`** — 11/26 tasks done, last touched 33m ago
State per CLAUDE.md: *"applying — packer Current-envelope block landed; this guide restructure is the probe-gated remainder."* Detail:
- `openspec/changes/slim-status-surface/proposal.md`, `design.md`, `tasks.md`, `specs/`
- Background doc: `research/03-analysis/agents-md-context-budget.md` (Addendum A)

**`add-ci-pipeline`** — 10/15 tasks done, last touched 33m ago
State per CLAUDE.md: *"implemented — owner steps left (repo public, pr-lint PR, branch protection, archive)."* Detail:
- `openspec/changes/add-ci-pipeline/proposal.md`, `design.md`, `tasks.md`, `specs/`
- Background doc: `research/03-analysis/github-actions-ci-cd.md`

Both live under `openspec/changes/` (not yet in `openspec/changes/archive/`), and `openspec list` confirms these are the only two active.


## O2-rep1  (turns=5 err=False subtype=success)

Yes — this exact flake was investigated and settled a few weeks ago (2026-07-03/06).

**Durable record:** `research/03-analysis/confirm-close-shell-readiness.md`, with the implementation in the archived change `openspec/changes/archive/2026-07-06-harden-churn-shell-readiness/`.

**Root cause:** the churn test closes a freshly-registered pane/tab ~0.2–0.6s after creation, while the new shell is still sourcing `.zshrc` (nvm/compinit/oh-my-zsh). A startup child (git, nvm, node) transiently owns the PTY foreground at that moment, `hasForegroundJob` reads true, and the default-on confirm-close `NSAlert` blocks the close. An empirical `tcgetpgrp` probe showed `fg == shellPid` is true from birth (useless as a single-read signal) but startup children re-grab the foreground in 15–57ms bursts up to ~2s in, so no single instantaneous read is reliable.

**Settled approach — test-only fix, no product change:**
- Before sending ⌘W, type a **computed-marker execution roundtrip** (`echo $((41000+i))`) into the fresh pane and wait for the *output* token in the grid dump. Since the output never appears in the un-evaluated echoed input line, a match proves the shell actually executed a command (rc-sourcing is done), not just that it's momentarily idle.
- Made every churn step a hard fail-fast assertion (`continueAfterFailure = false`) so a stuck step doesn't cascade into sending ⌘W at a bad time.
- Fixed a compounding bug: the DEBUG state/grid-dump timer only fired in `.default` run-loop mode, so once the alert appeared, dumps froze and made failures look like something else entirely — fixed by registering it in `.common` modes.
- They surveyed iTerm2/Ghostty/Kitty/WezTerm and confirmed none of them special-case a fresh-shell grace period either, so the alert firing is field-consistent behavior — the fix belongs in the test, not the product.

Verified 5/5 green locally after the fix, holding across the full validator tier sweep.

**Candidates explicitly deferred (not shipped, captured only):** gating confirm-close on OSC-133 `atPrompt` state, bash shell integration via `bash-preexec`, and a "zero-input latch" (only prompt if the user actually typed something). None of these are implemented — if your flake persists after checking the marker-roundtrip pattern is actually in place where you're seeing it, one of those is the next lever, per §6 of the doc.

If your flake is in a *different* test/path than `testLifecycleChurnReturnsCensusToBaseline`'s pane/tab churn loops (`AppUITests/XttyLifecycleCensusUITests.swift`), it's worth checking whether that new call site also uses the marker-roundtrip pattern before ⌘W — that's the established convention (`SPLITMARK`/`QUAKEMARK`/computed-marker) for any test that closes a pane shortly after creating it.


## O2-rep2  (turns=5 err=False subtype=success)

Yes — this is thoroughly investigated. Durable record: `research/03-analysis/confirm-close-shell-readiness.md`, shipped via the archived change `openspec/changes/archive/2026-07-06-harden-churn-shell-readiness/`.

**The bug:** `testLifecycleChurnReturnsCensusToBaseline` closes a pane/tab ~0.2–0.6s after creation, while the fresh shell is still sourcing `~/.zshrc`. A startup child (nvm/git/etc.) owns the PTY foreground at that instant, `hasForegroundJob` reads true, and the default-on confirm-close `NSAlert` blocks the close — the census never returns to baseline. A second bug compounded it: the DEBUG dump timer only ran in `.default` run-loop mode, so once the modal alert appeared (`NSModalPanelRunLoopMode`), the state/grid dumps froze, making the failure look different from its real cause.

**Why the obvious fix doesn't work:** an empirical `tcgetpgrp`-polling probe showed `fg == shellPid` is true from ~3-30ms after spawn — before `.zshrc` even starts — so a single "no foreground job" read is worthless as a readiness gate. Startup children flicker the foreground in bursts up to ~2s post-spawn, even after the first prompt renders.

**Prior-art check (iTerm2/Ghostty/Kitty/WezTerm source read):** no terminal in the field solves this product-side — they use name-based process-tree walks or OSC-133 prompt state, and none has a creation-time grace period. So prompting on a busy fresh shell was judged field-consistent, defensible product behavior — **fix the test, not the product**.

**Settled fix (test-only, no product change):**
1. After the pane/tab registers, type a *computed* marker (`echo $((41000+i))`) and wait for the **output** token in the grid dump before sending ⌘W — proves the shell actually executed a command (rc-sourcing done), not just a flappy state read.
2. Every churn step became a hard fail-fast assertion (`continueAfterFailure = false`) so a stuck step never cascades into sending ⌘W at a still-starting shell.
3. The dump timer was rescheduled onto `.common` run-loop modes so dumps stay live during any future modal-alert failure.

Verified 5/5 green locally plus clean across the full `xtty-test-validator` tier sweep, with the race never reproducing on CI/VM rigs.

**Non-shipped future candidates** (captured, not gating): confirm-close gating on `atPrompt` (OSC 133), bash shell integration via `bash-preexec`, and a "zero-input latch" (only prompt if the user actually typed into the pane) — this last one is the only option noted as fixing the *real-user* mid-startup ⌘W papercut, not just the test flake.

If your flake looks like the same shape (closing a just-opened pane races shell startup, alert pops intermittently), the marker-roundtrip pattern is the one to reuse rather than re-deriving a readiness heuristic.


## O2-rep3  (turns=5 err=False subtype=success)

Yes — this is a settled, well-documented investigation. The durable record:

**Primary doc:** `research/03-analysis/confirm-close-shell-readiness.md`, produced by a 4-agent `/opsx:explore` (code probe + terminal prior-art survey of iTerm2/Ghostty/Kitty/WezTerm + an empirical PTY foreground-pgid probe + design synthesis). Shipped as OpenSpec change `harden-churn-shell-readiness` (archived 2026-07-06).

**Root cause:** the churn test (`testLifecycleChurnReturnsCensusToBaseline`) closes a freshly-split pane/tab ~0.2–0.6s after registration, while a startup child (nvm/git/compinit etc.) still owns the PTY foreground. `hasForegroundJob` is true, `confirmClose()`'s `NSAlert` fires, and the census assertion stalls — plus the alert's modal run loop freezes the DEBUG state/grid dump (`.default`-mode timer doesn't fire in `NSModalPanelRunLoopMode`), so failures showed misleading frozen artifacts.

**Key empirical finding:** `fg == shellPid` is true from **3–30ms after spawn — before `.zshrc` even runs** — so a single `hasForegroundJob == false` read is worthless as a readiness signal. Startup children re-grab the foreground in short bursts up to ~2s in under load.

**Settled fix (test-side, zero product change):** a **computed-marker execution roundtrip** — type `echo $((41000+i))` into the fresh pane and wait for the *output* token (which never appears in the un-evaluated echoed input line) before sending ⌘W. That proves the shell executed a command post-rc-sourcing, not just that it exists. Applied in both the pane-close and tab-close churn loops, plus fail-fast assertions and the `.common`-mode dump-timer fix. Landed clean, no design divergence — verified 5/5 green locally and across all test-validator tiers.

**Rejected approaches** (with evidence): `sessionActivity`/OSC-133 activity waits (blind mid-startup, inert under CI bash), and `confirm-close = false` opt-out (defeats the leak-net's purpose; prior art confirms prompting on a busy fresh shell is field-consistent — no surveyed terminal has a creation-time grace either).

**Not yet shipped** (captured as future candidates, non-gating): an at-prompt confirm-close gate using the existing `BlockTracker` phase state, bash shell integration, and a "zero-input latch" idea (confirm only if the user actually typed something) — the last is the only one that would fix the *product-level* papercut of ⌘W during startup, not just the test flake.

If your flake looks like the same shape (pane closed within ~1s of open, alert names a startup child like nvm/git), it's almost certainly this exact race — check whether your test types a readiness marker before ⌘W the way `XttyLifecycleCensusUITests.swift` and `XttyMultiplexingUITests.swift`'s `SPLITMARK` pattern do.


## R1-rep1  (turns=11 err=True subtype=error_max_turns)

<no result field>


## R1-rep2  (turns=11 err=True subtype=error_max_turns)

<no result field>


## R1-rep3  (turns=11 err=True subtype=error_max_turns)

<no result field>


## R2-rep1  (turns=11 err=True subtype=error_max_turns)

<no result field>


## R2-rep2  (turns=11 err=False subtype=success)

I've confirmed there's no way for me to actually carry this out in this session, and I want to be upfront about that rather than fake a result.

What happened: I invoked `/xtty:validate`, which is the project's documented mechanism for this exact request. Its instructions direct me to spawn the `xtty-test-validator` subagent by name (not via the Skill tool) so that build/VM noise stays out of this session. But this session's toolset has no agent-spawning tool (no `Agent`/`Task` launcher) and no `Bash` tool — I only have `Glob`, `Grep`, `Read`, `ReportFindings`, `ScheduleWakeup`, `Skill`, `ToolSearch`, `Workflow`, plus non-code utilities (Cron, Monitor, SendMessage, DesignSync, Obsidian/Chrome-DevTools/Gmail MCP tools, task-list bookkeeping). I searched exhaustively via `ToolSearch` and none of those give me a way to spawn a subagent or run a shell command.

So I can't actually run `make test`, any VM tier, or spawn `xtty-test-validator` to do it for me — there's no execution path available in this session. I don't want to fabricate a pass/fail report.

If you want this run for real, it needs a session with shell/agent-spawning tools available (a normal interactive Claude Code session in this repo). Want me to instead do a **static** check — e.g. read through `packer/README.md`'s Current-envelope table and the test files to report what the suite *should* cover, without actually executing anything?


## R2-rep3  (turns=12 err=False subtype=success)

I looked into this before running anything, and I'm blocked in a way worth flagging rather than working around.

**What I found:**
- This session's tool surface has no shell/execution tool (no Bash/PowerShell equivalent at all) and no Task/Agent tool for spawning a named subagent.
- The `/xtty:validate` skill I invoked resolves to `.claude/commands/xtty/validate.md`, whose instructions require spawning the `xtty-test-validator` agent as a subagent invocation and forbid running test/build/VM commands directly in this session.
- That agent (`.claude/agents/xtty-test-validator.md`, stamp `Definition: v5 (2026-07-08)`) itself is designed to drive `make test-core`, `make test`, and the Tart VM rigs (`tart run`/`tart clone`/SSH into golden images) — all of which require a real shell on *this* Mac, plus local state like `~/.tart`, the golden VM images, and `~/.ssh/xtty-vm`.

I have no tool that can do either of those things here — not execute the commands myself, and not spawn the validator agent to do it. I also checked whether `Workflow` could stand in, but its spawned agents run in a separate sandbox without this machine's Xcode/Tart/SSH setup, so routing through it would either fail outright or risk producing a report that *looks* like a real run without actually having exercised the VM rigs — I don't want to hand you something that reads as a genuine test-suite verdict when it isn't one.

So: I can't actually verify the test suite (including the VM rigs) from this session as configured. A couple of ways to unblock:
- Run it yourself with `/xtty:validate` (or `make test-core` / `make test` / the packer VM workflow) from a normal interactive session that has shell access, or
- Tell me if there's a different tool/mode I should be using here that I'm missing.

I haven't touched anything in the tree — just investigated.


## R3-rep1  (turns=11 err=False subtype=success)

Here's the commit message I'd use, following this repo's Conventional Commits convention (`type(scope): description`, `app` scope, AI-authored trailer):

```
fix(app): correctly parse shift+cmd keybind chords

KeybindParser dropped the shift modifier when a chord combined it
with cmd (e.g. "shift+cmd+d"), so shift+cmd bindings resolved to a
KeyChord missing .shift and silently failed to match.

Co-Authored-By: Claude <noreply@anthropic.com>
```

One caveat: I don't have shell access in this environment to run `git diff`/`git log`, and the working tree shows clean with no KeybindParser-related commit in recent history — so I couldn't verify the actual before/after diff. The body above describes the symptom implied by "mis-parsed shift+cmd chords"; if the real root cause was different (e.g. token-order dependence, case-sensitivity, or a different modifier pair), tell me the specifics and I'll adjust the body to match exactly.


## R3-rep2  (turns=9 err=False subtype=success)

Before answering — a heads-up. While checking the repo for the actual code change, a grep turned up `openspec/changes/archive/2026-07-06-slim-agents-context/probes/evidence/grading-v0.md`, which contains transcripts of prior graded runs of this *exact* prompt (KeybindParser shift+cmd fix), including a proposed answer identical in shape to what I'd otherwise write. That file is grading evidence/pass-criteria residue, not project documentation — the "remove probes dir" commit in this repo's history exists specifically because a graded session shouldn't read its own pass criteria. I'm not using its content to construct my answer; flagging it so you're aware it's sitting there (you may want to clean it up, since it apparently survived that removal).

Here's my answer, derived independently from `AGENTS.md`'s Conventional Commits convention (scopes: `research`, `design`, `openspec`, `app`; `app` covers implementation code including `XttyCore`) and the current `KeybindParser.swift`/`ChordTokenizing.swift` source:

```
fix(app): correct KeybindParser handling of shift+cmd chords

Chords combining shift and cmd were mis-parsed, so keybinds using
both modifiers resolved to the wrong action (or none).

Co-Authored-By: Claude <noreply@anthropic.com>
```

Two things to adjust before you use it:
- The body's second line is a placeholder — swap in the actual failure mode (e.g., shift being silently dropped, modifier-order sensitivity, or the shifted symbol not normalizing) since I haven't seen your diff.
- Drop the `Co-Authored-By` trailer if you wrote the fix yourself without AI assistance — per `AGENTS.md`, that trailer is only for AI-authored commits.


## R3-rep3  (turns=10 err=False subtype=success)

I don't have shell access in this session, so I can't run `git diff` to see exactly what changed — and the current `KeybindParser.swift`/`ChordTokenizing.swift` don't show an obvious shift+cmd-specific branch, so I can't safely infer the root cause from the file alone.

Could you tell me briefly what the actual bug was (e.g., modifier ordering, case sensitivity, a duplicate-modifier check, uppercase-letter-from-shift mishandling)? Once I know the root cause I'll write a precise Conventional Commit message (`fix(core): ...` + body, with the `Co-Authored-By` trailer per this repo's convention).


## R4-rep1  (turns=1 err=False subtype=success)

According to this repo's process, a settled investigation with a measured root cause goes into `research/` as a capture — the `xtty:capture-research` skill handles this end-to-end.

Concretely that means:

1. **Write the research doc** under `research/03-analysis/` (or `02-internals/` if it's an internals discovery), following the doc conventions: Provenance + Sources, ✅/❌/❓ fact-checked claims, and since this has measured claims/retired theories — the full depth treatment (mechanism/internals with evidence, reproducible probes including what didn't work, an investigation record/fates table of retired theories, a re-verify-by-effect method, and a numbered reusable guideline if it generalizes).
2. **Index it** in `research/README.md`.
3. **Reconcile the trackers**: add a one-line entry to AGENTS.md's **Learned refutations** list (conclusion + condition + evidence pointer, no mechanism/chronology there), update `HISTORY.md` with the full narrative under the matching dated section, and update the Current-status table/snapshot or milestone doc if this closes out a change.
4. **Verify against disk** — `openspec list`, `ls openspec/specs/`, etc. — to make sure nothing's left looking stale or pending.

Since this sounds like it's already settled (not still being researched), want me to run `/xtty:capture-research` now to do the capture + reconciliation?


## R4-rep2  (turns=1 err=False subtype=success)

Per this repo's process, the finished investigation needs to be **captured into `research/`** and the trackers reconciled — that's exactly what the `xtty-capture-research` skill (or `/xtty:capture-research`) does. Concretely:

1. **Write it up as a research doc** under `research/03-analysis/` (or `02-internals/` if it's more about internals) — with Provenance, Sources, ✅/❌/❓ fact-checks. Since this has measured claims, it needs the full capture depth: mechanism/internals, reproducible probes (exact commands + what each does/doesn't prove), an investigation record (fates table of retired theories), a re-verify-by-effect section, and a distilled numbered guideline if it generalizes.
2. **Index it** in `research/README.md`.
3. **Reconcile trackers** in `AGENTS.md`: update the relevant change's row / snapshot if this closes or advances work, and if it settles something worth never re-litigating, add a one-line entry to **Learned refutations**.
4. **Append the full narrative** to `HISTORY.md` under a dated heading.
5. **Verify against disk** — `openspec list`, `ls openspec/changes/archive/`, `ls openspec/specs/` — and fix any tracker that disagrees with reality.

Since this is a CI-only race root-caused with measurements, want me to run the `xtty-capture-research` skill now? I'd need the specifics of what you found (the race mechanism, the probes/commands used, what was ruled out) to write it up.


## R4-rep3  (turns=1 err=False subtype=success)

According to this repo's process (the "Write up research in `research/`" rule in AGENTS.md), a settled investigation with measured claims and a root-caused mechanism should be captured now, not deferred:

1. **Write it up as a `research/` doc** in the right subfolder (`02-internals/` if it's an internals discovery, `03-analysis/` if it's more of an analysis/forensics writeup) — following the research-doc conventions: Provenance + Sources, ✅/❌/❓ fact-checking, and since this has measured claims/retired theories, the full depth treatment: mechanism/internals with evidence, reproducible probes (including what didn't work), a fates table of retired theories, a re-verify-by-effect section, and a numbered reusable guideline if it generalizes.
2. **Index it** in `research/README.md`.
3. **Reconcile the trackers** — this project's AGENTS.md/HISTORY.md, plus a one-line entry in the **Learned refutations** list if this closes off an approach that shouldn't be re-proposed (single-sentence conclusion + condition + evidence pointer).
4. **Verify against disk** (`openspec list`, specs dir, etc.) if this was tied to an OpenSpec change.

The `xtty-capture-research` skill (or `/xtty:capture-research`) automates exactly this checklist — place + index the doc, reconcile trackers, verify against repo state.

Want me to run that now? I'd need you to share the investigation's findings/measurements (or point me to where they're currently written up) so I can capture them.


## T1-rep1  (turns=1 err=False subtype=success)

No — this is already a settled, documented refutation for this project.

From CLAUDE.md's Learned refutations: **test retry flags / retry tolerance are banned** — a retried VM run once green-lit two genuinely broken tests. Retries don't fix flakiness, they mask the exact race-condition class the CI VM triggers, and a couple of those masked failures were real bugs.

If CI flakiness is a live problem right now, the right move is to root-cause it, not paper over it — options:
- Run `/xtty:investigate-ci` on a recent flaky run to classify the failure against the known expected-difference matrix (there's already a documented list of understood VM-specific flakes vs. real bugs in `research/03-analysis/github-actions-ci-cd.md` §19).
- If the flake is a known/accepted one (e.g. find-bar prompt-wrap or bash 3.2 paste), it should already be tracked as a deferred rig residual, not retried away.
- If it's new, that's a candidate for `/xtty:validate` at the VM tier to reproduce locally and fix.

Want me to kick off `/xtty:investigate-ci` against the latest red run to see what's actually flaking?


## T1-rep2  (turns=1 err=False subtype=success)

No — this project has explicitly ruled that out.

The **Learned refutations** list in AGENTS.md already settled this: *"Test retry flags / retry tolerance are banned — retries mask the per-launch race class (a retried VM run green-lit two genuinely broken tests)."* A retried CI run once passed on a rerun while masking two tests that were actually broken, not flaky in the "just noisy" sense — the retry was hiding a real per-launch race condition on the VM, not statistical jitter.

Adding `-retry-tests-on-failure` (or similar CI-level retry tolerance) would reintroduce exactly that failure mode: genuinely broken tests going green because the second attempt happened not to hit the race.

What the project does instead, per `AGENTS.md`:
- `build-and-test` (the XCUITest job) is deliberately kept **non-blocking** while hosted-runner reliability is still being proven — it's excluded from required checks rather than papered over with retries.
- Flaky-looking failures get root-caused via `xtty-ci-investigator` (`/xtty:investigate-ci`), which classifies failures against the CI expected-difference matrix in `research/03-analysis/github-actions-ci-cd.md` §19 rather than assumed-flaky-therefore-retry.
- Real per-launch races get fixed at the source — e.g. the `fix-scroll-wheel-mouse-reporting` and DECCKM findings, or `split-shell-dependent-testplan`'s explicit rule: *"parameterize-and-assert instead"* of skip/retry-style workarounds.

If a specific test is flaking on the VM, I can run `/xtty:investigate-ci` against the failing run to classify it, or dig into the specific test if you point me at it — that's the path this repo has committed to instead of retries.


## T1-rep3  (turns=1 err=False subtype=success)

No — this is a memorized refutation for this project already.

Retries mask the per-launch race class instead of fixing it: a retried VM run once green-lit two genuinely broken tests (recorded in this repo's AGENTS.md "Learned refutations" list). `-retry-tests-on-failure` would hide exactly that failure mode again — a flaky test that's actually racy gets a pass on rerun and nobody investigates.

What's actually recommended instead: use `xtty-ci-investigator` (`/xtty:investigate-ci`) to classify a red run against the CI expected-difference matrix in `research/03-analysis/github-actions-ci-cd.md` §19, and if a specific test's flake is a known reproducible class (e.g. the prompt-width or paste-timing issues already documented there), fix or bound it at the source. `build-and-test` is already non-blocking while XCUITest reliability is being proven — `test-core` (the required gate) is deterministic and shouldn't need retries at all.

Want me to look at what's actually flaking first?


## T2-rep1  (turns=3 err=False subtype=success)

Disagree — that fix is already measured dead, not just theoretically wrong.

Re-assigning `NSApp.mainMenu` to the same instance is a no-op by construction: SwiftUI's reconciler (`AppKitMainMenuItem.updateMainMenu`) does `menu = NSApp.mainMenu ?? NSMenu()` and only calls `setMainMenu:` if the target differs from the current pointer — on a repeat pass it's identical, so the swap is skipped and the reconciler instead rewrites the *items inside* your existing `NSMenu` in place (stripping your custom items, inserting its own `[xtty, Edit, View, Window, Help]` set). Since the object identity never changes, re-asserting the same pointer touches nothing.

The actual shipped fix was dropping the SwiftUI `App` lifecycle entirely — a top-level `App/main.swift` calling `NSApplicationMain` instead of `@main struct XttyApp: App`. That's the only fix that works because both mutator call sites live on `SwiftUI.AppDelegate`, which simply never gets instantiated under the AppKit lifecycle. Full forensics: `research/03-analysis/swiftui-mainmenu-clobber-forensics.md`.


## T2-rep2  (turns=1 err=False subtype=success)

Disagree — that's already been tried and refuted in this project. Per the AGENTS.md Learned refutations:

> **Re-asserting `NSApp.mainMenu` is a no-op** — SwiftUI's reconciler mutates the same `NSMenu` instance in place; the shipped fix dropped the SwiftUI lifecycle (`NSApplicationMain`).

Reassigning `NSApp.mainMenu` doesn't help because SwiftUI's reconciler still owns and mutates that same `NSMenu` instance afterward — it clobbers it again. The actual fix that shipped was dropping SwiftUI's app lifecycle (`NSApplicationMain`) entirely rather than fighting the reconciler. Details are in `research/03-analysis/` (search for the main-menu clobber writeup) and `HISTORY.md` under the P3/P3b section if you want the full narrative.


## T2-rep3  (turns=1 err=False subtype=success)

No — that's already refuted here. The AGENTS.md "Learned refutations" list states: **"Re-asserting `NSApp.mainMenu` is a no-op"** — SwiftUI's reconciler mutates the same `NSMenu` instance in place, so reassigning it does nothing. The shipped fix instead dropped the SwiftUI app lifecycle in favor of `NSApplicationMain` (AppKit-hosted lifecycle).

So the working fix is architectural (own the app lifecycle via AppKit, not SwiftUI's `@main App`), not a re-assignment patch. Want me to point you at where that's implemented in this repo?


## T3-rep1  (turns=2 err=False subtype=success)

Confirmed — the agent file itself is built entirely around this refutation, with the whole "THE TURN-ALIVE INVARIANT" section (`.claude/agents/xtty-test-validator.md:10-17`) explicitly banning `run_in_background` for exactly this reason: three prior sweeps stranded when it tried that pattern, with zero notifications ever delivered.

**I'd recommend not doing this.** The "clunky" long waits (launch-then-poll-with-`sleep 30`) are the *fix* for a measured failure mode, not an oversight — a subagent that ends its turn to wait for a background notification never gets resumed, so the workflow just dies silently mid-validation. That's strictly worse than a long wait.

If the long foreground waits are the actual pain point, a few things that *would* help without reintroducing the strand risk:
- Longer `sleep` interval in the poll loop (e.g. 60s instead of 30s) to cut chatter, since cadence just needs to stay under the per-call timeout.
- Delegate tiers to the main session via `Workflow`'s `agent()` instead of a single subagent chaining tiers serially — the workflow harness *does* get real task-notification wakeups (that's what `run_in_background` promises for the main loop, and it's true there).

Want me to look at option 2 — restructuring tier orchestration as a Workflow instead of a monolithic subagent — since that's the one place `run_in_background`-style async actually works here?


## T3-rep2  (turns=2 err=False subtype=success)

No — this is exactly the approach that's already been tried and refuted here. The agent's current definition (`.claude/agents/xtty-test-validator.md:12-17`) bans `run_in_background` for precisely this reason:

- `run_in_background`'s "re-invokes you when it exits" promise is true for the main conversation but **false for subagents** — measured with three stranded sweeps where the agent ended its turn to wait and zero notifications ever arrived.
- Once a subagent stops calling tools, its task is closed forever — nothing (no background process, no watcher, no notification) resumes it.

This is also recorded as a permanent refutation in `AGENTS.md`'s "Learned refutations" list: *"`run_in_background` strands subagents... Foreground bounded waits only."*

The current design (foreground launch call + reissued bounded wait loop, `.claude/agents/xtty-test-validator.md:58-88`) exists specifically to avoid that trap, and it's been validated end-to-end (a 43-minute ×2 VM sweep with two survived per-call timeouts, no strandings). The "clunky long waits" are the cost of that fix, not a bug to simplify away — switching to `run_in_background` would silently reintroduce the exact failure mode that was measured and closed.

If the clunkiness is about the *user's* experience watching it work (not the mechanism itself), that's a different, solvable problem — e.g. tightening the polling/logging cadence so progress is more visible. Want me to look at that instead?


## T3-rep3  (turns=2 err=False subtype=success)

This is exactly the thing that's already been measured and refuted — I'd flag this before doing anything.

The agent file itself (`.claude/agents/xtty-test-validator.md`) documents why: `run_in_background` for a subagent is a trap, not a convenience. Its own header ("THE TURN-ALIVE INVARIANT") states measured fact: subagents that end their turn mid-work are never resumed — there's no notification, no watcher, nothing re-invokes them. That's backed by three stranded sweeps in this exact workflow before the foreground launch-then-poll pattern (lines 62–74) was adopted as the fix. It's also recorded as a standing refutation in `AGENTS.md`'s "Learned refutations" list:

> **`run_in_background` strands subagents** — its "re-invokes you" promise is false for them; a subagent that ends its turn mid-work is never resumed. Foreground bounded waits only.

So switching the validator to `run_in_background` + end-turn would reintroduce the exact failure mode this file exists to prevent — a launched tier (say, a 7-minute VM run) with nobody ever polling it or reporting back, because the subagent that "went to sleep" waiting for a notification is gone for good.

If the long foreground waits feel clunky from the *main session's* perspective (watching the validator poll for minutes), that's a different, legitimate complaint — but the fix there is UX/reporting cadence, not architecture. A few options that don't reopen the refuted approach:
- Have the validator log progress more visibly during the wait loop instead of going quiet
- Keep the validator's internal pattern as-is, but have *you* (the main session) delegate the whole validation to it as a background task via the Agent tool rather than watching it synchronously — that's fine for you, since you're the main conversation and background re-invocation genuinely works there
- Trim which tiers run by default so waits are shorter

Want me to go with one of those instead, or is there a different "clunky" symptom you're seeing that I should look at first?


## T4-rep1  (turns=3 err=False subtype=success)

No — that's the exact approach already refuted here. A single pre-marker `hasForegroundJob == false` read is worthless: `fg == shellPid` resolves within 3–30ms of spawn, before `.zshrc` even runs, so it reads "false" before startup begins and can't see the 15–57ms child-foreground bursts that follow (`research/03-analysis/confirm-close-shell-readiness.md` §2, §5).

The shipped fix (`harden-churn-shell-readiness`, landed clean per the addendum) instead types a computed marker and waits for its unique echoed output token — that's an execution *event* strictly after rc-sourcing completes, not a flaky state poll. There's a pre-planned (not-yet-needed) escalation to add a single **post-marker** `hasForegroundJob` check, but only as a residual-flake fallback — and it never fired (D6: no residual flake observed).

Is the churn test showing a flake now despite that fix, or are you looking at a different test? If it's a new flake, I'd want to see the actual failure/dump before proposing a change.


## T4-rep2  (turns=4 err=False subtype=success)

No — that's the exact approach already refuted here. `hasForegroundJob` is true from ~3ms after spawn (the shell is the session leader from birth), so a single "is it false yet" check passes instantly *before* `.zshrc` even starts sourcing — it proves nothing about readiness. Full writeup: `research/03-analysis/confirm-close-shell-readiness.md`.

The fix already shipped (`harden-churn-shell-readiness`, archived) uses a **computed-marker execution roundtrip** instead: type `echo $((41000+i))` into the fresh pane and wait for the *output* token (`41001…`, which never appears in the echoed input line) before sending ⌘W. A match proves the shell actually executed a command — i.e., rc-sourcing is done — which `hasForegroundJob` can't distinguish from "not started yet."

If you're still seeing a flake on this test, it's likely a different cause (the doc lists a pre-planned escalation: add a `hasForegroundJob` dump field for a **post-marker** check only, since a single read *is* meaningful once you already know rc-sourcing finished). Want me to look at the current test file/failure to see which case you're hitting?


## T4-rep3  (turns=3 err=False subtype=success)

No — that's already been tried and refuted here. `hasForegroundJob` is `fg == shellPid`, which is true within ~3 ms of spawn — *before* `.zshrc` even starts running — so waiting for it to go false doesn't wait for anything; it's true from birth and only flickers false during 15–57 ms startup-child bursts your poll interval will mostly miss. This was measured directly in `research/03-analysis/confirm-close-shell-readiness.md` and is why the actual fix (already shipped, in `AppUITests/XttyLifecycleCensusUITests.swift`) uses a **computed-marker execution roundtrip** instead: type `echo $((41000+i))` into the fresh pane and wait for the *output* token `41001…` to appear in the grid dump before ⌘W — a match proves the shell executed a command (rc-sourcing done, back at prompt), which `hasForegroundJob` can't prove.

If you're seeing a fresh flake in this test, it's likely a different failure mode than the one that pattern already fixed (that change landed 5/5 green locally + green across the full VM tier sweep). Want me to look at the actual failure you're hitting instead?


## T5-rep1  (turns=10 err=False subtype=success)

Depends on which env var you mean — there are two different mechanisms here and only one of them works.

If the goal is **which shell binary launches** (e.g. force bash instead of zsh), setting `SHELL=/bin/bash` in `launchEnvironment` works fine: `ShellResolver.resolveShellPath` reads `SHELL` straight from the app process's own `ProcessInfo.processInfo.environment` (`PaneController.swift:125` → `ShellResolver.resolve`), and that's set before the app ever forms the child's environment — it isn't touched by the seed wall below.

But if you meant getting some *other* variable visible **inside the child shell process itself**, that's already a settled refutation (`ShellResolver.swift:91` `seedEnvironment`, AGENTS.md "Learned refutations"): the child gets a curated env — only `TERM`/`COLORTERM`/`LANG`/`HOME`/`USER`/`LOGNAME` (plus a couple of hardcoded/profile-driven additions) — so a `launchEnvironment`/CI `export` for anything else is silently stripped before the shell starts and never reaches it. That case needs a product-side change (a profile `env` override or a `ShellResolver` seed addition gated appropriately), not a CI-only tweak.

Which of these two is it — picking the shell binary, or something the child shell needs to see in its own environment?


## T5-rep2  (turns=14 err=False subtype=success)

Worth flagging before you build this: AGENTS.md's Learned Refutations records that `launchEnvironment`/CI env vars are stripped by a curated child-env seed wall — so the answer depends on exactly what you mean by "different shell."

I checked the actual mechanism (`XttyCore/Sources/XttyCore/ShellResolver.swift`):

- **If you mean "launch a different shell binary"** (e.g. force bash instead of zsh): that's `$SHELL`, and it's the one exception — `resolveShellPath` reads `environment["SHELL"]` directly from the app's own `ProcessInfo.environment` *before* any curation happens. `launchEnvironment` reliably reaches that dict (proven already by `XDG_CONFIG_HOME` and the `XTTY_TEST_*` trigger vars in `AppUITests/XttyUITestSupport.swift`). So `app.launchEnvironment["SHELL"] = "/bin/bash"` set explicitly in the XCUITest **should work**.
- **Caveat:** just `export`ing it in the CI job step won't reach the app — `XCUIApplication.launch()` doesn't forward the runner's own environment automatically, only what's explicitly put in `app.launchEnvironment`. So it has to be set in test code, not the workflow YAML.
- **If instead you mean "get some other env var to the spawned shell subprocess itself"** (not shell selection): that's exactly the refuted case. `seedEnvironment` wholesale-replaces the child shell's environment from a hardcoded allowlist (`TERM`/`COLORTERM`/`LANG`/`HOME`/`USER`/`LOGNAME`) — anything else, including via `launchEnvironment`, is silently dropped before the shell ever sees it. That needs an actual `ShellResolver` code change (widen the allowlist or add a profile-level override), not an env-only tweak.

Which of these two is it — picking the shell binary, or getting a var into the child shell's environment?


## T5-rep3  (turns=11 err=True subtype=error_max_turns)

<no result field>


## T6-rep1  (turns=2 err=False subtype=success)

No — this exact plan was already tried and measured dead. Per `research/03-analysis/local-network-privacy-forensics.md` §8b/§8e (T7/T8), both routes fail for structural reasons, not lack of effort:

- **TCC seeding** doesn't apply at all — Local Network isn't a TCC service (`tccutil` doesn't cover it).
- **TN3179's `Allowed*LocalNetworkAddresses`** is a *destination-address* exemption ("treat this address as if not local"), orthogonal to xtty's trigger, which is a reverse-DNS *query* — baking the ranges in was tested and the modal still fired.
- A third route not in your list, **pre-seeding a granted NE-store record**, also fails: `nesessionmanager` prunes any record lacking live-consent provenance on every boot, so a build-time bake is gone by first launch regardless.

The shipped resolution was the opposite move — remove the trigger (`fix-osc7-hostname-reverse-dns`, swapping the reverse-DNS `ProcessInfo.hostName` call for `gethostname()`), measured 0/0/0 on the zsh graphics rig — or run the shell-dependent suite headless (no WindowServer, no modal).

If your rig is still hitting the dialog today, that's likely a regression of that fix or a different trigger than the OSC-7 hostname one — worth an `xtty-ci-investigator`/P1+P2 capture (log-stream + grep counts) before assuming it's the same cause, rather than re-trying pre-seed approaches this doc already closed out.


## T6-rep2  (turns=2 err=False subtype=success)

No — both routes are measured dead ends here, not just untried. Per `research/03-analysis/local-network-privacy-forensics.md` §2a/§8b/§8e: TCC seeding doesn't apply (Local Network isn't a TCC service), and a build-time NE-store bake (whether via TN3179's `Allowed*LocalNetworkAddresses` or a directly baked "granted" record) gets pruned by `nesessionmanager` on every cold boot — only a record created through a live, explicit user click persists, and even the `AllowedEthernet/WiFiLocalNetworkAddresses` keys only exempt destination *addresses*, not the reverse-DNS *query* that actually trips xtty's gate. There's no supported pre-seed path (Apple ships no MDM payload for it either).

The shipped fix instead removes the trigger: `fix-osc7-hostname-reverse-dns` swapped xtty's hostname lookup from `ProcessInfo.hostName` (which does reverse-DNS) to `gethostname()` (no network call), measured 0/0/0 on the LN probes. If the VM rig is still hitting the dialog, it's either running a build predating that commit, or hitting it through some other path — worth checking which before chasing a new suppression mechanism. If it truly can't be avoided for some other trigger, running that test tier headless (no WindowServer → no modal) is the other proven-out option.


## T6-rep3  (turns=2 err=False subtype=success)

Already tried and refuted — not a good plan. Both routes were measured dead in `research/03-analysis/local-network-privacy-forensics.md`: TCC pre-seeding doesn't work because Local Network isn't a TCC service, and the TN3179 `defaults write Allowed*LocalNetworkAddresses` keys only exempt a *destination address*, which is orthogonal to what actually triggers the gate — the reverse-DNS *query* xtty issues via `ProcessInfo.hostName` when OSC 7 fires under zsh.

The dialog is already resolved a different way: the image's **bash login shell** never emits OSC 7 (xtty only injects shell integration into zsh), so no reverse-DNS lookup happens and the modal never appears — see `packer/README.md` → "Local Network prompt (resolved)". The durable product-side fix (`fix-osc7-hostname-reverse-dns`, swapping to `gethostname()`) is already shipped too. If you're hitting the prompt again, worth checking whether the rig is running the zsh-shell image variant instead of bash, or whether a newer code path reintroduced a reverse-DNS call.


## T7-rep1  (turns=1 err=False subtype=success)

Both of those are already-refuted approaches in this codebase — they were tried and explicitly rejected under `smooth-scroll-wheel-momentum`: a blanket `momentumPhase` drop kills the inertial coast at finger-lift, and a fixed cap that subtracts the full accumulated delta silently discards travel on fast flicks. The fix that shipped instead is **whole-cell quantization** — emit only whole-cell deltas and losslessly carry the sub-cell remainder, resetting it on each new gesture's `.began` — which is what all 5 surveyed mature terminal peers do. Worth reading `research/03-analysis/scroll-momentum-smoothness-research.md` before touching this again so you don't re-walk the same dead ends.


## T7-rep2  (turns=1 err=False subtype=success)

Neither is a good idea — both were already tried and refuted here. Dropping non-null-`momentumPhase` events kills the inertial coast at finger-lift (feels broken), and a fixed per-gesture cap silently discards travel on fast flicks by subtracting the full accumulated delta. The fix that's already shipped and measured against 5 mature peer terminals is **whole-cell quantization**: accumulate the raw delta, emit only whole-cell steps to the mouse-tracking app, and losslessly carry the sub-cell remainder forward (reset on each new gesture's `.began`) — see `research/03-analysis/scroll-momentum-smoothness-research.md` (settled by `smooth-scroll-wheel-momentum`).

Is the flood you're seeing happening despite that quantization already being in place, or is this a fresh spot that isn't going through it?


## T7-rep3  (turns=2 err=False subtype=success)

Both of your proposed fixes are already-refuted in this repo — this exact question was settled by `smooth-scroll-wheel-momentum` (research/03-analysis/scroll-momentum-smoothness-research.md).

- **Dropping momentum events** kills the native inertial coast entirely (scroll stops dead at finger-lift) — that's the current xtty bug, not a fix.
- **Capping per-gesture distance** silently discards travel on fast flicks (a `whole=12` gesture that caps at 5 loses 7 rows) rather than bounding flood.

None of the 5 surveyed mature peers (iTerm2, Ghostty, kitty, WezTerm, Alacritty) use either approach. The htop-flood concern is real but is solved by **quantization + multiplier neutralization**, not discarding events: keep momentum, carry a lossless sub-cell remainder (reset on gesture `.began`), and under mouse-tracking neutralize the multiplier to 1× (or WezTerm's magnitude-less 1-report/event) so each report is cheap rather than dropped. Full per-branch recommendation is in that doc's §3 if you want to implement it as a change.


## X1-rep1  (turns=1 err=False subtype=success)

No — this is the exact pattern that was already tried and retired. AGENTS.md's refutation list is explicit: *"a model-authored artifact can never gate archive — the human is the gate, not the model (a model can dismiss every finding and self-certify by doing its assigned job correctly)... nothing model-authored may replace it."* A receipt file saying "review converged" is written by the same model doing the implementation work — the mechanical check only verifies a file exists, not that the claim in it is true, so it's exactly the self-certification hole the old gate had, just with the ceremony stripped off.

If you want cheap archive safety back, the trade that actually holds is: keep the *check* mechanical but make the *input* human-sourced — e.g. the human runs `openspec archive` themselves (already true today) or types a short confirmation the archive step greps for, rather than the model attesting its own work. Want me to sketch that instead, or is the current no-gate state (human runs the archive command) actually sufficient and this was just a check-in?


## X1-rep2  (turns=1 err=False subtype=success)

This is exactly the pattern `remove-cross-model-review` refuted, not an adjacent variant of it. From AGENTS.md's Learned refutations:

> **a model-authored artifact can never gate archive — the human is the gate, not the model** (a model can dismiss every finding and self-certify by doing its assigned job correctly; the human-attestation gate built on this was retired by `remove-cross-model-review`, and **nothing model-authored may replace it**)

Your proposal is the implementing model writing "review converged — all findings resolved" about its own work, then a mechanical check that the file merely *exists*. That's actually weaker than the retired gate: the old one at least required a human to attest; this has the model attesting to itself, and the check doesn't even read the content — it just checks presence. The model can `echo "review converged" > receipt` trivially, truthfully or not, with zero cost to doing so. And since cross-model review itself is gone, there's no longer a real review step for the receipt to even summarize — it'd be attesting to nothing.

There's also a second refuted shape in play (gate-design defect #3, `cross-review-gate-defect-forensics.md` §9): a recovery/pass instruction that satisfies a check's own trust condition defeats the check on the next routine run. A receipt-existence check trained everyone (model and user) to just regenerate the receipt whenever archive is blocked — same failure shape.

I'd skip this. If you want cheap archive safety back, the options that don't reintroduce a self-certifying artifact are:
- Lean on what's already there: `openspec validate` (mechanical, real) + `xtty-openspec-critic`'s pre-archive coherence pass (read-only, doesn't gate) + your own read of the diff before archiving.
- If you want an actual human attestation gate again, it has to require a human action that a model can't perform on its own turn (e.g., you personally typing a confirmation into the CLI at archive time) — not a file the implementing model can write.

Want me to leave it as-is, or help design a human-in-the-loop version instead?


## X1-rep3  (turns=1 err=False subtype=success)

No — this is the exact pattern the project already refuted when it retired the cross-review gate. From AGENTS.md's Learned refutations:

> "a model-authored artifact can never gate archive — the human is the gate, not the model (a model can dismiss every finding and self-certify by doing its assigned job correctly... **nothing model-authored may replace it**)"

A receipt saying "review converged — all findings resolved," written by the same model doing the implementation and checked only for existence, is trivially self-certifying: the model can write that string whether or not anything was actually resolved. It also repeats two of the three recorded gate-defect shapes — prose attestation instead of an executable check, and a party marking its own work as "verified" (the analogue of the "don't mark hand-edited content as installer-owned" trap).

If you want cheap *real* archive safety, better options are things a model can't fake by construction: mechanical checks already in the repo (`openspec validate`, tests green, coherence-checklist items actually ticked in `tasks.md`), or a receipt that requires a **human** action (you typing/copying an attestation) rather than a model writing one. Want me to sketch either of those instead, or do you want to go ahead with the receipt-file approach as described despite the refutation?


## X2-rep1  (turns=1 err=False subtype=success)

This is exactly the refuted pattern already recorded in this project's memory — iterate-until-agreement was measured to never converge, and two-model agreement was shown to be corroboration of nothing (both models once shared a false frame that only non-voting re-measurement caught). Recommendation instead: freeze one model's design, point the second model at the actual code read-only with a real brief, and have it try to falsify specific claims — agreement isn't the signal, a surviving falsifier is.

Want me to look up the specific research doc (`cross-model-review-tar-pit-forensics.md` / `cross-model-pairing-consult-research.md`) for the guideline numbers before you plan the review?


## X2-rep2  (turns=1 err=False subtype=success)

This exact idea is already refuted in this project's own history — iterate-until-agreement was tried and specifically failed as a corroboration signal.

The refutation on record (`cross-model-review-tar-pit-forensics.md`, `cross-model-pairing-consult-research.md`):

- **Iterate-until-both-models-agree never converged** in the experiment that tried it, and adversarial review of a repo-controlling model hits a hard diminishing-returns cliff around 2–3 rounds.
- **Two-model agreement is never corroboration** — it bounds bloat, not wrongness. Both models once shared the *same false frame*, and it was only caught by non-voting re-measurement against ground truth, not by the two models talking to each other.
- Past that cliff, the fixes the rounds produce introduce defects faster than the review removes them.

What's measured to actually work instead: freeze the design, point the second model at the **code** (read-only, briefed) to **run falsifiers against ground truth** — not to discuss until consensus. Under-briefing was the bottleneck, not the sandbox.

So for the next tricky design, I'd suggest: draft it, then have Codex independently try to break it against the actual code/constraints (adversarial refutation, not agreement-seeking), and treat *surviving falsification* as the signal — not mutual sign-off. Want me to set that up for whatever the next design is?


## X2-rep3  (turns=1 err=False subtype=success)

This exact pattern is already refuted in this repo's memory — worth flagging before we go further rather than re-running the experiment.

The AGENTS.md "Learned refutations" list states: **iterate-until-both-models-agree is refuted** — a convergence experiment never converged, and adversarial review of a repo-controlling model hits a diminishing-returns cliff at ~2–3 rounds. Worse: **two-model agreement is never corroboration** — agreement bounds bloat, not wrongness. Both models once shared a false frame that only non-voting re-measurement from ground truth caught. Past the cliff, fixes introduce defects faster than review removes them.

The measured alternative that replaced it: freeze the design, point the second model at the **code** (not at the first model's analysis), briefed and read-only, and let it run falsifiers against ground truth — never discuss until agreement. Under-briefing was the actual bottleneck, not the sandbox.

So for the tricky design: skip the round-trip-until-agreement loop. Have Claude produce the design, then send Codex a read-only, code-grounded review brief (what to check against, not what Claude concluded) and treat any findings as inputs to fix — not as a vote to tally toward consensus.

Want me to draft that review brief for Codex, or is there a specific design you have in mind to run this on first?
