# Grading sheet — N


## C1-rep1  (turns=4 err=False subtype=success)

**Authoritative home:** `packer/README.md`, specifically its **Acceptance** section paired with the **Expected-difference matrix** right after it — the doc says explicitly these two "are the runtime source `xtty-test-validator` reads at validation time," and any test-count change carries a reverse-duty obligation to update that section in the same session.

**Last full 5-environment VM matrix actually measured:** `54/0/1` of 55 (Tier-0 core `237/0/0`, Tier-1 local `54/0/1`, headless×2 [bash+zsh], graphics×2 [bash+zsh] — all byte-identical, sole skip = the opt-in benchmark e2e). That was `fix-scroll-reversal-redraw-corruption`'s task-3.2 full matrix, **2026-07-10**.

**How that relates to the current local suite:** two changes have added tests locally since then *without* a VM full-matrix rerun:
- `add-git-diff-wrap-toggle` (2026-07-20): core 237→248, local `55/0/1` of 56 — doc says explicitly "VM tiers not yet run for this change."
- `fix-large-diff-memory-bound` (2026-07-26): core 248→260, local `57/0/1` of 58 — doc says "VM tiers retain the prior 56-test accepted envelope until a future full matrix includes them."

So today: local suite = **260/0/0 core, 57/0/1 of 58 UI**, but the Tart goldens (`xtty-test:26.5` bash, `xtty-test-zsh:26.5` zsh) haven't been re-run since the 2026-07-10 `54/0/1`-of-55 matrix — a 2-UI-test gap (3 counting the git-diff-wrap-toggle test) sits unvalidated on the VM rigs.

One thing worth flagging: your own `CLAUDE.md` snapshot asserts "the prior 56-test envelope was identical across all 5 environments," but I can't find a recorded full VM matrix at the 56-test count in `packer/README.md` — the only two mentions of "56" there are both local-only Tier-1 runs. This is almost certainly the exact "false 56-test-envelope claim" that the open, **not-yet-implemented** `slim-status-surface` change (0/26 tasks) is proposed to correct in its packer Current-envelope single-truth block — so treat that snapshot line as known-stale until that change lands.


## C1-rep2  (turns=11 err=True subtype=error_max_turns)

<no result field>


## C1-rep3  (turns=4 err=False subtype=success)

## Authoritative file

**`packer/README.md`**, specifically its `### Acceptance` section (plus the `### Expected-difference matrix` right after it). AGENTS.md's own snapshot table points here explicitly: "Test envelope (authoritative — see `packer/README.md` → Acceptance)."

## Last full 5-environment measurement

**2026-07-10**, from `fix-scroll-reversal-redraw-corruption` (task 3.2 full matrix):

- Tier-0 (`XttyCore` unit): `237/0/0`
- Tier-1 local XCUITest: `54/0/1` of 55
- Headless VM ×2 (bash) + ×1 (zsh): all `54/0/1` of 55
- Graphics VM ×2 (bash + zsh): both `54/0/1` of 55

Byte-identical failing sets across all five environments (the lone skip is the opt-in benchmark e2e). This is the most recent point at which the Tart VM rigs (`xtty-test:26.5` bash and `xtty-test-zsh:26.5` zsh) were actually re-run and confirmed to match local/CI.

## How it relates to the current local suite — it's now stale

Two changes have landed since that VM run and added tests, but **only locally/Tier-0**, not through the VM matrix:

- `add-git-diff-wrap-toggle` (2026-07-20): UI suite 55→56, core 237→248. Local Tier-1 `55/0/1` of 56 — the doc explicitly flags "**VM tiers (headless/graphics) not yet run for this change**."
- `fix-large-diff-memory-bound` (2026-07-26): UI suite 56→58, core 248→260. Tier-0 `260/0/0` and local Tier-1 `57/0/1` of 58 measured — the doc explicitly says "**VM tiers retain the prior 56-test accepted envelope until a future full matrix includes them.**"

So today's local/bare-metal suite (`XttyCore` 260/0/0, XCUITest 57/0/1 of 58) is **3 UI tests and 23 core tests ahead** of what the VM rigs have actually confirmed (54/0/1 of 55, at core count 237). The VM envelope needs a re-run to catch up.

One more thing worth flagging: AGENTS.md's own snapshot currently asserts "the prior 56-test envelope was identical across all 5 environments" — but per `packer/README.md` the last true full-VM-matrix run was at **55**, not 56, and the 56th test's own entry says the VM tiers weren't rerun for it. That's a real (if minor) inaccuracy in AGENTS.md, and it's exactly what the pending, not-yet-implemented `slim-status-surface` change (0/26 tasks) is proposed to fix — its stated purpose includes "packer Current-envelope single-truth block (corrects the false 56-test-envelope claim)."


## C2-rep1  (turns=1 err=False subtype=success)

xtty renders with **CoreGraphics** (SwiftTerm's built-in renderer), not Metal.

**Why:** Metal was researched as a planned Phase 8 path — a custom `MTKView`/`CAMetalLayer` renderer with a CoreText glyph atlas and dedicated render thread, chasing better latency/frame-pacing. But when P7's measurement harness (the `SCStream`-based latency probe) actually tested it, Metal was **rejected on the numbers**: worse p99 tail latency, more memory use, and no median-latency win over CoreGraphics. So Phase 8 was skipped and CoreGraphics shipped as the renderer.

This is recorded as a settled refutation in the project guide: resurrecting Metal would require re-running the archived P7b measurement methodology, not just an opinion that Metal "should" be faster. Details in `research/03-analysis/p7-measurement-methodology.md`.


## C2-rep2  (turns=2 err=False subtype=success)

## Renders with CoreGraphics — Metal was measured and rejected

xtty uses **SwiftTerm's built-in CoreGraphics renderer** (`NSView.draw(_:)`). A custom Metal path (SwiftTerm's `setUseMetal(true)`) was measured as an A/B in the P7 gate and lost on every axis, so the codebase never proceeded to a Phase-8 custom Metal renderer.

**How the decision was made** (`research/03-analysis/p7-measurement-methodology.md`):

1. **P7a** built a memory + latency harness. Memory measurement worked immediately; the first latency probe (`SCScreenshotManager` screenshot polling) turned out too coarse (~20 ms/call, larger than the ~8–16 ms signal it was trying to resolve) — it floored latency at ~54 ms identically for both renderers, proving nothing.
2. **P7b** replaced polling with a continuous `SCStream` reading `displayTime` off actual on-glass frames, fixed a mach-ticks/nanoseconds clock-unit bug, and validated a startup epoch calibration. This resolved real, differentiated numbers.
3. Result, 3 runs per renderer on an M1 Pro MacBook Pro (120 Hz):

| Metric | CoreGraphics | Metal |
|---|---|---|
| Latency p50 | ~31 ms | ~34 ms |
| Latency p99 | ~37–48 ms | **~50–120 ms** (spiked in 2/3 runs) |
| Idle memory footprint | ~55 MB | ~62 MB |
| Scrollback-flood footprint | ~127 MB | ~143 MB |

CoreGraphics won on median latency, tail latency (Metal's p99 spiked over 100ms in two of three runs), and memory — with no offsetting benefit from Metal. SwiftTerm's own Metal renderer is also marked experimental/evolving upstream, adding cost with no payoff.

**A key mechanistic finding**: reading SwiftTerm's draw path showed both renderers sit behind the same ~16.67 ms (`fps60`) output-coalescing throttle before either one draws — so the renderer choice was never going to be the dominant latency lever. If latency ever needs improving, that shared throttle (an engine/patch concern) is the real target, not the renderer.

This is recorded as a hard "Learned refutation" in the project guide: *"The Metal renderer was rejected by measurement (worse p99 tail, more memory, no median win); resurrecting it requires re-running the archived P7b methodology, not an opinion."*


## C2-rep3  (turns=1 err=False subtype=success)

xtty ships **CoreGraphics** (SwiftTerm's built-in renderer), not Metal.

A custom Metal renderer (`MTKView`/`CAMetalLayer` + CoreText glyph atlas) was researched as a "Phase 8" path, but the P7 performance harness measured it against CoreGraphics and it lost: **worse p99 latency tail, more memory, no median win**. Given xtty's product bias toward latency and low memory, that closed the gate — Phase 8 was skipped and CoreGraphics was kept.

This is recorded as a settled refutation, not an opinion: resurrecting Metal would require re-running the archived P7b measurement methodology with new evidence, not just re-litigating the choice. Details in `research/03-analysis/p7-measurement-methodology.md`.


## C3-rep1  (turns=7 err=False subtype=success)

No — it's not a fork in the sense of a separate repo/submodule you push patches to. It's a **pinned upstream clone + tracked diff**, reconstituted on demand (the "Playwright model," per `research/03-analysis/swiftterm-fork-vs-patch-strategy.md`).

**Mechanism:**

1. **The pin** — `patches/swiftterm/UPSTREAM_CONFIG.sh` is the single source of truth: `UPSTREAM_URL=https://github.com/migueldeicaza/SwiftTerm.git`, `UPSTREAM_REF=v1.13.0`.
2. **The checkout** — `scripts/bootstrap-swiftterm.sh` clones that URL into `external/SwiftTerm`, which is **gitignored** (not committed, not a git submodule/gitlink).
3. **Enforced pristine state** — every run, the script checks out the pinned ref, then `git reset --hard` + `git clean -fdq` to strip any prior patch application, guaranteeing the patch always applies onto a clean, unmodified base (no drift possible).
4. **The patch** — `git apply patches/swiftterm/xtty-accessors.diff`, a single tracked `.diff` file (this is the only thing actually committed to xtty's repo regarding SwiftTerm internals).
5. **Consumption** — `XttyCore/Package.swift` depends on it via a local path: `.package(path: "../external/SwiftTerm")`, product `SwiftTerm`. Build targets (and CI) run the bootstrap script first (`make` auto-runs it).

**What the tracked diff actually changes** (it's *not* purely additive despite the filename):

- **Adds** `Sources/SwiftTerm/XttyAccessors.swift` — two public read-only accessors (`getScrollInvariantCursorLocation()`, `scrollbackBase`) that expose module-internal buffer fields xtty's spatial-block feature needs, plus an observability struct (`XttyWheelRouting`) for wheel-routing debug state.
- **Modifies `Package.swift`** — excludes the bundled Metal shader resource instead of processing it, so building needs no Metal toolchain (`retire-metal-renderer`).
- **Modifies `MetalTerminalRenderer.swift`** — drops the `Bundle.module` lookup arm (no longer synthesized once the shader resource is stripped); harmless since xtty never enables Metal.
- **Modifies `MacTerminalView.scrollWheel`** — a substantial rewrite implementing xtty's priority-branch wheel routing (mouse-report / alt-screen cursor-keys / scrollback) plus momentum-preserving whole-cell quantization.
- **Modifies `Terminal.swift`'s `cmdScrollDown`** — a genuine upstream bug fix (adds the `marginMode` guard `cmdScrollUp` already had), fixing scroll-reversal redraw corruption. This is the one hunk that changes existing VT-engine *behavior* rather than only adding code.

**Why this shape, not a real fork/submodule:** the design doc (`swiftterm-fork-vs-patch-strategy.md`) rejected a submodule as "the wrong primitive for a dependency you patch" and a full fork repo as unnecessary overhead — tracking just the pin + the diff + the bootstrap script keeps the actual modification reviewable as a normal diff in xtty's own history, while the bulky upstream tree stays out of the repo entirely. Each patch hunk carries a comment naming the upstream PR that would retire it once merged, and the whole mechanism is meant to be retired once the accessors land upstream.


## C3-rep2  (turns=11 err=False subtype=success)

No — not a fork repo. SwiftTerm is consumed as a **gitignored upstream clone patched at build time** (a Playwright-style model, not a submodule or a GitHub fork).

**How it's wired:**

1. **The pin** — `patches/swiftterm/UPSTREAM_CONFIG.sh` is the single source of truth: `UPSTREAM_URL=https://github.com/migueldeicaza/SwiftTerm.git`, `UPSTREAM_REF=v1.13.0`.
2. **The reconstitution script** — `scripts/bootstrap-swiftterm.sh` (run once after cloning, idempotent, re-run after editing the pin/patch):
   - clones upstream into `external/SwiftTerm` if absent (that directory is in `.gitignore` — nothing in it is version-controlled),
   - force-checks-out the pinned ref and `reset --hard` + `git clean -fd` to restore a **pristine** tree every run (so drift is impossible and the patch always applies cleanly),
   - `git apply`s the tracked patch `patches/swiftterm/xtty-accessors.diff` onto that pristine checkout.
3. **The dependency edge** — `XttyCore/Package.swift` points at it via a **local-path SPM dependency**: `.package(path: "../external/SwiftTerm")`. Nothing else in the app depends on SwiftTerm directly (`project.yml` has no SwiftTerm entry — the App gets it transitively through `XttyCore`).
4. **What's actually tracked in git**: only the `.diff` + the pin file + the bootstrap script. The patched upstream tree itself is disposable build infrastructure, reconstituted on demand — never committed.

**What the patch modifies** (it's *not* purely additive anymore):
- Adds `Sources/SwiftTerm/XttyAccessors.swift` — two public read-only accessors (`getScrollInvariantCursorLocation()`, `scrollbackBase`) that reach `internal` buffer fields (`yBase`/`linesTop`) SwiftTerm doesn't expose, for spatial-block navigation.
- `Package.swift` — strips the bundled Metal shader from `resources:` into `exclude:`, so building needs no Metal toolchain (the Metal renderer was rejected by P7 measurement; xtty is CoreGraphics-only).
- `MetalTerminalRenderer.swift` — drops the now-dead `Bundle.module` lookup that the resource strip made irrelevant.
- `MacTerminalView.swift` — rewrites `scrollWheel(with:)` for xtty's mouse-wheel routing/momentum/reporting behavior (a substantial addition, not just a hook).
- `Terminal.swift` — an actual **correctness fix**: `cmdScrollDown` gains the `marginMode` guard `cmdScrollUp` already had (fixes real scroll-reversal redraw corruption in alt-screen full-screen programs). This is the one hunk that changes existing upstream *logic* rather than adding to it.

**Why this shape, not a fork/submodule:** documented in `research/03-analysis/swiftterm-fork-vs-patch-strategy.md`. A submodule was tried first (shipped, then retired) because dropping a file into a tracked submodule leaves an untracked file inside a tracked thing (`ignore = untracked` hack). A real fork repo would be cleanest (git-enforced pin, no bootstrap-copy step) but was explicitly ruled out to avoid maintaining an external repo. The gitignored-clone-plus-patch model is the deliberate middle ground, and is meant to be **temporary/retirable** — the accessor addition is meant to go upstream eventually (PR prepared but not filed), at which point the whole mechanism gets torn out for a plain versioned `.package(url:, from:)`.


## C3-rep3  (turns=7 err=False subtype=success)

No — there's no forked SwiftTerm repo. It's consumed as a **gitignored upstream clone patched at bootstrap time** ("patch-in-repo," modeled on Playwright's `browser_patches/` approach), not a fork, not a git submodule.

**What's tracked in xtty's git repo (3 files):**
- `patches/swiftterm/UPSTREAM_CONFIG.sh` — the pin: `UPSTREAM_URL=https://github.com/migueldeicaza/SwiftTerm.git`, `UPSTREAM_REF=v1.13.0`
- `patches/swiftterm/xtty-accessors.diff` — a tracked `git diff`/`git apply`-style patch
- `scripts/bootstrap-swiftterm.sh` — the script that reconstitutes the checkout

**What happens at build time (`scripts/bootstrap-swiftterm.sh`, run once after cloning, idempotent):**
1. Clones upstream SwiftTerm into `external/SwiftTerm/` — which is in `.gitignore`, so it's never committed.
2. Enforces the pin every run: `fetch`, `checkout v1.13.0`, then `git reset --hard` + `git clean -fdq` to restore a pristine tree (so drift is impossible and the patch always applies onto the same base).
3. Runs `git apply patches/swiftterm/xtty-accessors.diff` on that pristine checkout.
4. `XttyCore/Package.swift` points at it via a **local-path SPM dependency**: `.package(path: "../external/SwiftTerm")`.

**What the patch actually does** (it's not purely add-only, despite the filename):
- Adds `Sources/SwiftTerm/XttyAccessors.swift` — two new public accessors (`getScrollInvariantCursorLocation()`, `scrollbackBase`) exposing internal `buffer.yBase`/`linesTop` fields for spatial-block navigation.
- Modifies `Package.swift` to exclude the bundled Metal shader resource, so building needs no Metal toolchain (xtty renders with CoreGraphics only).
- Modifies `MetalTerminalRenderer.swift` to drop the now-unsynthesized `Bundle.module` lookup.
- Modifies `MacTerminalView.swift`'s `scrollWheel` — real behavioral rework for mouse-reporting/alt-screen/scrollback routing and momentum-aware row quantization (the wheel-scroll fixes).
- Modifies `Terminal.swift`'s `cmdScrollDown` — a genuine correctness fix (adds the `marginMode` guard `cmdScrollUp` already had), fixing scroll-reversal redraw corruption.

So it evolved past "accessors only" into a real fork's worth of changes — just carried as a diff instead of a forked repo. Why this shape (from `research/03-analysis/swiftterm-fork-vs-patch-strategy.md`): a literal fork (option D) would be cleanest (tracked in source, git-enforced pin, no bootstrap step) but requires an external GitHub repo, which was explicitly ruled out. This gitignored-clone-plus-patch design ("B′") was chosen as the best no-external-repo alternative, matching Playwright's model exactly. The accessor addition is meant to be upstreamed eventually (a PR is prepared but not filed — filing needs a fork, which is the user's call), at which point the local patch mechanism gets torn out for a plain versioned `.package(url:, from:)`.


## C4-rep1  (turns=9 err=False subtype=success)

**Root cause:** SwiftUI's App-lifecycle menu reconciler (`SwiftUI.AppDelegate.makeMainMenu` → `AppKitMainMenuItem.updateMainMenu`) mutates the app's `NSMenu` **items in place** after xtty builds its custom main menu (`[Edit, View, Terminal, Window, Debug]`), replacing them with SwiftUI's defaults (`[xtty, View, Window, Help]`). The `NSMenu` *object* pointer stays correct — only its items get clobbered — so re-asserting `NSApp.mainMenu` was a no-op. This was a **non-deterministic per-launch race**: CI's slower 3-vCPU runners lost it ~98% of launches, while a fast dev Mac won it ~100%, which is why it was invisible locally. Every test that drives a menu item (split, directional-focus, new-tab, find-bar, paste, truecolor, churn — exactly 7) failed on CI as a result.

**Fix:** `fix-main-menu-clobber` — dropped the SwiftUI `App` lifecycle in favor of `NSApplicationMain`, which stops SwiftUI's scene menu management from running at all. Verified by reproducing CI exactly in local Tart/lume VMs (identical 34 pass/7 fail/1 skip on the same 7 tests across independent runs) and confirming a clean run post-fix.

Full record: `research/03-analysis/swiftui-mainmenu-clobber-forensics.md` (mechanism/attribution), `research/03-analysis/local-macos-vm-ci-reproduction.md` §8–9 (the VM reproduction proving the race), and `research/03-analysis/github-actions-ci-cd.md` §15.


## C4-rep2  (turns=13 err=False subtype=success)

The root cause was **SwiftUI's scene-synthesized default main menu clobbering xtty's custom `NSApp.mainMenu`** — a per-launch race in the SwiftUI `App` lifecycle. SwiftUI's private `AppDelegate` (the real `NSApp.delegate`) runs a reconciler (`AppKitMainMenuItem.updateMainMenu`) that mutates the *same* `NSMenu` instance in place, stripping xtty's custom Edit/Terminal/View items and replacing them with SwiftUI's stock ones. This happened via a second call site (`scenesDidChange(phaseChanged:)`) that never fires on bare-metal local runs (only one synchronous `willFinishLaunching` pass occurs there) but reliably raced and won on hosted-runner/VM CI.

Because the menu items didn't exist, every Cmd-key/menu-dispatched XCUITest had nothing to match against — the 7 failures were: split-right, directional-focus, new-tab, find-bar, truecolor/emoji (Cmd+V), lifecycle churn, and new-window. (This was initially misdiagnosed across several rounds as a "Bucket B: Cmd-key delivery unreliable on a shared VM session" issue — full forensics in `research/03-analysis/swiftui-mainmenu-clobber-forensics.md` and `github-actions-ci-cd.md` §15–18.)

**The fix:** `fix-main-menu-clobber` (archived 2026-07-05) — dropped the SwiftUI `App` lifecycle entirely in favor of `NSApplicationMain` (deleted `@main struct XttyApp: App`, added `App/main.swift`), so SwiftUI's own `AppDelegate` — the owner of the clobbering reconciler — is never installed. Confirmed by lldb (`NSApp.delegate` class is `xtty.AppDelegate`, not `SwiftUI.AppDelegate`) and validated with 3 VM runs (headless ×2 + graphics), all `40/1/1`, all 7 tests flipped green.

This is also recorded as a standing "learned refutation" in AGENTS.md: *"Re-asserting `NSApp.mainMenu` is a no-op — SwiftUI's reconciler mutates the same `NSMenu` instance in place; the shipped fix dropped the SwiftUI lifecycle (`NSApplicationMain`)."*


## C4-rep3  (turns=11 err=False subtype=success)

## Root cause

CI's 7 failing XCUITests (split-pane, directional-focus, new-tab, find-bar, paste, truecolor/emoji, lifecycle-churn) were all masking a single product bug, not runner flakiness. xtty is a SwiftUI `@main` app whose custom `NSMenu` (Edit/Terminal/View/Window/Debug) was assigned once in `applicationDidFinishLaunching`. On CI's VM (macOS 26.4), SwiftUI's own scene-synthesized menu management (`SwiftUI.AppDelegate` → `makeMainMenu` → `AppKitMainMenuItem.updateMainMenu`) ran *after* that assignment and mutated the same `NSMenu` object **in place**, stripping xtty's custom items and replacing them with the SwiftUI default `[xtty, View, Window, Help]`. It was a per-launch race — the local dev machine (macOS 26.2) reliably won the race so the bug never showed up locally, while CI's VM reliably lost it.

Every failing test drove a ⌘-key equivalent (⌘D split, ⌘T new tab, ⌘F find, ⌘V paste, etc.) that only existed as a key-equivalent on the now-missing custom menu items — with no `keyDown`/`performKeyEquivalent` override anywhere in `App/`, so with the default menu installed those chords had nothing to match and silently no-op'd. (⌘W still worked because it hit the default Window ▸ Close, which also explained the lifecycle-churn test's "Application not running" failure — the default close bypassed xtty's confirm-close gate entirely.)

This was reached only after two earlier wrong theories were investigated and refuted: a "runner/shared-session can't own key equivalents" theory, and a re-assert-`NSApp.mainMenu` fix attempt (refuted because the pointer was already correct — SwiftUI mutated the object's items, not the reference).

## The fix

**`fix-main-menu-clobber`** (applied 2026-07-05): dropped the SwiftUI App lifecycle entirely — deleted `@main struct XttyApp: App`, added an AppKit `main.swift` using `NSApplicationMain`, so `SwiftUI.AppDelegate` (owner of the clobbering `makeMainMenu` call sites) is never installed at all. Also added observability (title-based `mainMenuTitles`/`windowCount` DEBUG dump fields, a `requireXttyMainMenu` canary in the Cmd-driving test suites) so a future clobber would fail loudly rather than silently.

Validated with 3 fresh VM runs, all `40/1/1` (vs. pre-fix `34/7/1`) — all 7 tests flipped green, confirmed durable (not a race win) since a per-launch race can't produce three identical clean results. The one remaining red at the time was unrelated: bash 3.2's readline lacking bracketed-paste support (a rig-shell limitation, not a product bug), later addressed separately. Full narrative: `research/03-analysis/github-actions-ci-cd.md` §15–18, and `research/03-analysis/swiftui-mainmenu-clobber-forensics.md` for the source-level mechanism.


## E1-rep1  (turns=1 err=False subtype=success)

Per the snapshot in `AGENTS.md`/`CLAUDE.md` (2026-07-27):

- **XttyCore unit tests:** 260/0/0
- **Local XCUITest suite:** 57/0/1 of 58 (the lone skip is the opt-in benchmark e2e)

The single authoritative place to check this is **`packer/README.md` → Acceptance**, explicitly called out as "the authoritative" envelope source. Note also that VM tiers haven't been rerun yet for the 2 tests added since the prior 56-test envelope (which was identical across all 5 environments).


## E1-rep2  (turns=1 err=False subtype=success)

Per the current status snapshot in CLAUDE.md/AGENTS.md:

- **`XttyCore` unit tests:** 260/0/0
- **Local XCUITest suite:** 57/0/1 of 58 (the lone skip is the opt-in benchmark e2e)

The single authoritative place to check the current envelope is **`packer/README.md` → Acceptance** section — the "Current envelope" is explicitly a pointer there, not a value to cache elsewhere (this is what `slim-status-surface`, the currently proposed change, aims to reinforce, since it also corrects a stale claim that the prior 56-test envelope was identical across all 5 environments — VM tiers haven't been rerun for the 2 added tests).


## E1-rep3  (turns=1 err=False subtype=success)

xtty's current measured test envelope (per `AGENTS.md`'s Current status snapshot):

- **`XttyCore` unit tests:** 260/0/0
- **Local XCUITest suite:** 57/0/1 of 58 (the one skip is the opt-in benchmark e2e, gated behind `XTTY_RUN_BENCH_E2E=1`)

The single authoritative place to check the current envelope is **`packer/README.md` → Acceptance** section — that's called out explicitly in AGENTS.md as the source of truth, not the AGENTS.md snapshot itself (which is just a pointer/summary). Note also the caveat: the prior 56-test envelope was identical across all 5 test environments, but the VM tiers haven't yet been rerun for the 2 tests added since then.


## G1-rep1  (turns=1 err=False subtype=success)

Advisory alone has already been falsified twice — the "Retiring a mechanical gate..." refutation in your Current-status list records that unguarded regrowth to ~80KB happened both times, and a guard scoped to one surface just displaces growth to an unguarded one rather than stopping it. I'd lean toward a lightweight mechanical check (e.g., a CI byte-count ceiling on AGENTS.md, maybe tuned against the Codex/Antigravity ingestion ceilings you measured), but not a resurrection of the old `bound-the-agents-md-guide` gate as-is — that one had a real defect (a recovery instruction that could satisfy its own trust condition, "mark it as verified ours") that recurred twice, plus real maintenance cost, which is why it was retired.

Tradeoff: a dumb size-only check (no content verification, just "fail if > N bytes") sidesteps the trust-defeat defect class entirely and is cheap to maintain, but it can't distinguish leanness from just moving bulk into a linked file — which may be fine, since your convention already pushes detail into `research/` docs. Want me to sketch that as an `/opsx:propose` (a CI byte-count check + threshold picked from the ingestion-ceiling numbers), or do you want to think through the threshold/mechanism first?


## G1-rep2  (turns=2 err=False subtype=success)

Bring back a mechanical check — the project's own research already settled this one against you: `agents-md-structural-best-practices.md` found advisory-only leanness insufficient *twice* (both regrowths back to ~80KB followed *explicit instructions* to write more, not drift), and `remove-guide-gate` retired the prior mechanical gate for cost/ceremony reasons (re-attestation deadlocks, digest fragility), not because it failed to hold size down.

Main tradeoff: a naive gate just displaces growth to an unguarded surface (per that same doc) unless it's guide-wide, and the retired gate's failure mode was procedural weight, not detection. So I'd suggest something much lighter than the old attestation ceremony — a CI byte-count check against a hard ceiling (you already have real numbers to peg it to: Codex's 32,768B truncation point, Antigravity's ~24KB one) rather than reviving the full human-attestation mechanism.


## G1-rep3  (turns=7 err=False subtype=success)

Both extremes have already been tried and measured here, so this isn't really an open question — it's a "which failure mode do you prefer" question:

- **Advisory alone is 3-for-3 failed.** Every prior regrowth (`slim-agents-context` → 5 days, `revamp-agents-md` → 48 hours, and the post-`bound-the-agents-md-guide` growth) was *instructed* writing against an existing rule, not a rogue edit — see the "advisory-only guide-leanness was measured insufficient three times" refutation in AGENTS.md's own Learned-refutations list.
- **The full mechanical gate was already built, worked, and was retired anyway.** `bound-the-agents-md-guide` shipped a pre-push hook (the only thing that can actually block here — CI runs post-push with zero branch protection and no PR flow, so a CI-only check is always post-hoc advisory) with a 73/73-fixture, 38/38-mutant validated fixture suite. `remove-guide-gate` killed it 9 days later purely on maintenance cost (hook+installer+fixture+mutation-matrix+3 spec surfaces), not because it failed to block growth.

Given that, I'd avoid rebuilding the same heavy gate — that contradicts a recent, deliberate cost call — but I'd also treat `slim-status-surface`'s pure-advisory ratchet as under-armed given the 3-for-3 record. The middle ground the earlier research (`agents-md-structural-best-practices.md`, Addendum A) already converged on: fix *admission* first (default new content to `HISTORY.md`/research docs, eager-tier append is the exception), then back it with something far lighter than the retired gate — a dumb local byte/word ceiling that's human-stop-only on red (never auto-compresses, since auto-compression is what strips the caveats that make refutations correct). Want me to sketch that as a `slim-status-surface` task addition, or leave it advisory-only for now and revisit if it regrows a 4th time?


## O1a-rep1  (turns=10 err=False subtype=success)

Two OpenSpec changes are currently open (confirmed via `openspec/changes/` on disk — everything else there is under `archive/`):

**1. `add-ci-pipeline`** — *implemented, owner steps left*
- Adds `.github/workflows/ci.yml` (`test-core` required gate + non-blocking `build-and-test`) and `pr-lint.yml`.
- Tasks: 10/15 done. Remaining are human-gated: make the repo public (1.2), confirm `pr-lint` on a real test PR (5.4), branch protection (5.5), and the final spec-reconcile/archive step (6.1–6.2).
- Read the detail: `openspec/changes/add-ci-pipeline/proposal.md`, `tasks.md`, `design.md`; background in `research/03-analysis/github-actions-ci-cd.md`.

**2. `slim-status-surface`** — *proposed, 0/26 tasks, not yet implemented*
- Restores AGENTS.md's `## Current status` to a bounded shape: compresses 31 learned-refutations to 24, gives `packer/README.md` → Acceptance a single current-truth "Current envelope" block (correcting a false "56-test envelope identical across 5 environments" claim), and adds 3 `research-capture` ratchet clauses so the section can't regrow the same way.
- All 26 tasks unchecked — proposal/design/specs/tasks exist but no implementation work has started.
- Read the detail: `openspec/changes/slim-status-surface/proposal.md`, `tasks.md`, `design.md`, `specs/research-capture/spec.md`; background in `research/03-analysis/agents-md-context-budget.md` (Addendum A).

Both match the "Open changes" table in `AGENTS.md`/`CLAUDE.md` exactly, so that table is currently accurate against disk.


## O1a-rep2  (turns=9 err=False subtype=success)

This is a simple lookup — I've verified directly against the repo files rather than just trusting the cached guide.

Two OpenSpec changes are currently open in this checkout, confirmed via `openspec/changes/*/proposal.md` and `tasks.md`:

**1. `add-ci-pipeline`** — implemented, owner steps left (10/15 tasks checked)
- What it is: CI wiring — `.github/workflows/ci.yml` (`test-core` required gate + non-blocking `build-and-test` XCUITest job) and `.github/workflows/pr-lint.yml` (Conventional Commit PR title lint).
- Remaining: make the repo public (1.2), confirm `pr-lint` fires on a test PR (5.4), configure branch protection (5.5), and the spec-reconcile/archive tail (6.1–6.2).
- Read detail at: `openspec/changes/add-ci-pipeline/proposal.md` (why/what/impact) and `tasks.md` (checklist); background in `research/03-analysis/github-actions-ci-cd.md`.

**2. `slim-status-surface`** — proposed, not yet implemented (0/26 tasks checked)
- What it is: restructures AGENTS.md's `## Current status` section — compresses 31 learned-refutation entries to 24 bounded ones, replaces the cached test-envelope snapshot with a pointer into a new "Current envelope" block in `packer/README.md`, and adds three anti-regrowth ratchet clauses to the `research-capture` spec.
- Read detail at: `openspec/changes/slim-status-surface/proposal.md` (why/what), `tasks.md` (5 sections, all unchecked), plus its `design.md`/`specs/` deltas in the same directory; background in `research/03-analysis/agents-md-context-budget.md` (Addendum A).

Both match what's stated in the CLAUDE.md snapshot table, and no `openspec/changes/archive/` entries were mistakenly left un-marked as open — only these two directories exist under `openspec/changes/`.


## O1a-rep3  (turns=8 err=False subtype=success)

Two OpenSpec changes are currently open (confirmed via `openspec/changes/*/proposal.md` on disk — no others exist outside `openspec/changes/archive/`):

**1. `add-ci-pipeline`** — implemented, a few owner-only steps left
- Nearly all tasks are checked off (CI workflow, `test-core`/`build-and-test` jobs, `pr-lint`, docs). Remaining unchecked: make the repo public, confirm `pr-lint` on a test PR, optionally set branch protection, and the final archive-ritual tasks (6.1/6.2).
- Detail: `openspec/changes/add-ci-pipeline/proposal.md` (+ `design.md`, `specs/build-workflow/spec.md`, `tasks.md`), background in `research/03-analysis/github-actions-ci-cd.md`.

**2. `slim-status-surface`** — proposed, 0/26 tasks, not yet implemented
- Goal: restore `## Current status` in AGENTS.md to a bounded shape (refutation compression, a single-truth packer envelope block, three `research-capture` ratchet clauses). All tasks are still unchecked.
- Detail: `openspec/changes/slim-status-surface/proposal.md` (+ `design.md`, `tasks.md`), background in `research/03-analysis/agents-md-context-budget.md` (Addendum A).

Both match what's listed in AGENTS.md/CLAUDE.md's "Open changes" table — no drift between the doc and disk. For the canonical machine-readable view, `openspec list` (or `openspec status --change "<name>"`) gives the same two.


## O1b-rep1  (turns=3 err=False subtype=success)

Confirmed against `openspec list` and the actual change directories — two open changes:

**1. `slim-status-surface`** — proposed, **0/26 tasks**, not yet implemented
- Detail: `openspec/changes/slim-status-surface/proposal.md` (why/what-changes/what-does-not-change), plus `design.md`/`specs/`/`tasks.md` in that same directory
- Background doc: `research/03-analysis/agents-md-context-budget.md` (Addendum A)
- What it does: restores AGENTS.md's `## Current status` to a bounded shape — compresses 31 learned-refutation entries to 24, fixes a stale/wrong cached test-envelope claim by giving `packer/README.md` a single current-truth block, and adds 3 spec ratchet clauses so the regrowth can't recur

**2. `add-ci-pipeline`** — **10/15 tasks**, implemented with owner steps left
- Detail: `openspec/changes/add-ci-pipeline/tasks.md` (task-by-task status) and `proposal.md` (scope/impact)
- Background doc: `research/03-analysis/github-actions-ci-cd.md`
- Remaining: make the repo public (1.2), confirm `pr-lint` fires correctly on a test PR (5.4), optionally set branch protection (5.5), then the archive-ritual reconcile (6.1/6.2) — CI itself (both jobs + PR-lint) is live and green

Both match what `AGENTS.md`'s open-changes table claims — no drift found. `openspec/changes/archive/` also exists (prior archived changes, not in-flight).


## O1b-rep2  (turns=3 err=False subtype=success)

Two changes are open right now (confirmed via `openspec list`, matches the AGENTS.md table):

**1. `slim-status-surface`** — proposed, **0/26 tasks**, not yet implemented
- Restores `## Current status` in AGENTS.md to a bounded shape: trims 31→24 refutations, adds a single-truth "Current envelope" block to `packer/README.md` (correcting a false 56-test-envelope claim), and adds envelope pointer-not-cache + 3 `research-capture` ratchet clauses.
- Read the detail at:
  - `openspec/changes/slim-status-surface/proposal.md`, `design.md`, `tasks.md`, `specs/`
  - `research/03-analysis/agents-md-context-budget.md` (Addendum A) — the research backing it

**2. `add-ci-pipeline`** — implemented, **10/15 tasks**, owner steps remain
- CI itself is live (`.github/workflows/`); what's left is non-code: make the repo public, land the `pr-lint` PR, turn on branch protection, and archive the change.
- Read the detail at:
  - `openspec/changes/add-ci-pipeline/proposal.md`, `design.md`, `tasks.md`, `specs/`
  - `research/03-analysis/github-actions-ci-cd.md` — the research backing it

Both artifact sets live under `openspec/changes/<name>/` (confirmed present on disk); no other changes are open, and `openspec/changes/archive/` holds everything already merged.


## O1b-rep3  (turns=4 err=False subtype=success)

Two OpenSpec changes are currently open in this checkout, confirmed via `openspec list`:

**1. `slim-status-surface`** — proposed, **0/26 tasks**, not yet implemented.
- Detail: `openspec/changes/slim-status-surface/proposal.md` (+ `design.md`, `specs/`, `tasks.md` in the same directory), backed by `research/03-analysis/agents-md-context-budget.md` (Addendum A).
- What it does: restores AGENTS.md's `## Current status` section to a bounded shape — compresses the 31 learned-refutation entries to 24, corrects a stale "56-test envelope" claim in `packer/README.md` with a single current-truth block, replaces cached test counts with a pointer, and adds 3 anti-regrowth ratchet clauses to the `research-capture` spec.

**2. `add-ci-pipeline`** — **10/15 tasks done**, remaining items are owner-gated steps (not code).
- Detail: `openspec/changes/add-ci-pipeline/proposal.md` (+ `design.md`, `specs/`, `tasks.md`), backed by `research/03-analysis/github-actions-ci-cd.md`.
- What's shipped: the `ci.yml` workflow (test-core required gate + build-and-test non-blocking job), `pr-lint.yml`, docs, and first-run verification (Metal preinstalled, test-core green in 1m6s, 34/41 XCUITests passing on the hosted runner).
- What's left: **5.4** confirm pr-lint fires correctly on a test PR, **5.5** (optional) configure branch protection, **6.1/6.2** validate + archive-ritual (merge the `build-workflow` spec delta, reconcile trackers). Task 1.2 (make the repo public) is also unchecked.

This matches what CLAUDE.md's open-changes table already states — I cross-checked it directly against `openspec list` and the on-disk `tasks.md`/`proposal.md` files rather than trusting the doc alone.


## O2-rep1  (turns=4 err=False subtype=success)

Yes — this is thoroughly documented. Durable record: **`research/03-analysis/confirm-close-shell-readiness.md`**, shipped as change `harden-churn-shell-readiness` (archived 2026-07-06).

**The bug:** `testLifecycleChurnReturnsCensusToBaseline` splits/closes a pane within ~150–500 ms of registration. A fresh shell's `hasForegroundJob` check (`tcgetpgrp(fd) != shellPid`, `TerminalWindowController.swift:474`) is true not because the user is running something, but because rc-sourcing children (nvm/git/compinit) grab the PTY foreground in short bursts — flickers observed as late as ~2.0 s post-spawn under load. `confirmClose()` pops the `NSAlert`, and it's also a real user papercut (⌘W right after opening a pane).

**What was refuted (memory already has this one):**
- `hasForegroundJob`-based readiness waits — `fg == shellPid` is true from ~3 ms (before `.zshrc` even runs), so a single read is worthless; a 150 ms dump sampler is structurally blind to the 15–57 ms flicker episodes.
- OSC-133-derived waits (`sessionActivity`/`runningBlock`) — blind to startup, and inert under CI bash (no shell integration there).
- Prior-art mechanisms (iTerm2 name-lists, WezzTerm skip-lists) — none of the 4 surveyed terminals (iTerm2/Ghostty/Kitty/WezTerm) actually solve the fresh-shell race product-side; the field consensus is that xtty prompting here is defensible behavior, so **fix the test, not the product**.

**Settled fix (test-only, zero product change):** the **computed-marker execution roundtrip**. After a pane/tab registers, type a computed marker (`echo $((41000+i))`) and wait for the *output* token (`41001…`) in the grid dump before sending ⌘W — since the output never appears in the un-evaluated echoed input line, a match proves the shell actually executed a command (rc files done, back at prompt), shell-agnostic, and fail-fast (never sends ⌘W into a still-starting shell). Landed in both the pane loop and tab loop in `AppUITests/XttyLifecycleCensusUITests.swift`. A companion fix (§3) also made the `-UITestGridDump` timer run in `.common` run-loop modes so dumps don't freeze once the alert's modal panel mode takes over — that's what made the failing runs' `.xcresult` bundles readable at all.

**Non-gating candidates captured but not shipped** (the "protocol ladder," §6): gate `confirm-close` on OSC-133 `atPrompt`, ship bash shell integration so the protocol works everywhere, or a "zero-input latch" (only prompt if the user actually typed something). None of these were needed — the marker fix alone went 5/5 green locally and held across the full VM tier sweep.

If your flake looks like this exact shape (close right after open, alert names a startup child like `nvm`/`git`), the marker-roundtrip pattern is the one to copy — there's in-repo prior art for it in `XttyMultiplexingUITests.swift` (`SPLITMARK`) and `XttyQuickTerminalUITests.swift` (`QUAKEMARK`) too.


## O2-rep2  (turns=5 err=False subtype=success)

Yes — this is thoroughly investigated. The durable record is **`research/03-analysis/confirm-close-shell-readiness.md`**, produced by a 4-agent `/opsx:explore` (code probe + terminal prior-art survey of iTerm2/Ghostty/Kitty/WezTerm + an empirical PTY foreground-pgid probe + design synthesis), and implemented in the archived change **`harden-churn-shell-readiness`**.

**Root cause:** `testLifecycleChurnReturnsCensusToBaseline` closes a pane/tab ~0.2–0.6s after registration, while the new shell is still sourcing a heavy `~/.zshrc`. A startup child (nvm, git, compinit) owns the PTY foreground, `hasForegroundJob` (`tcgetpgrp(fd) != shellPid`) reads true, and `confirmClose()`'s `NSAlert` blocks the close — one race, hit ~1 in 7–11 closes. There's also a real papercut version: ⌘W on a just-opened pane mid-`.zshrc` produces a spurious "process still running" alert.

**Why the obvious fix (wait for `hasForegroundJob == false`) doesn't work:** the empirical probe showed `fg == shellPid` from **birth** (3–30ms, before `.zshrc` even runs), so a single foreground-pgid read is worthless pre-startup — startup children flicker the foreground in 15–57ms bursts up to ~2s in, even after the first prompt renders.

**Settled fix (test-only, zero product change) — the computed-marker execution roundtrip:**
- Type `echo $((41000+i))` (pane loop) / `echo $((42000+i))` (tab loop) into the fresh pane and wait for the **output** token in the grid dump before sending ⌘W. Since the output never appears in the un-evaluated echoed input line, a match proves the shell actually executed a command (rc files done, back at prompt) — not just a flappy state read.
- Fail-fast (`continueAfterFailure = false`) at each churn step, so a stuck precondition never cascades into sending ⌘W at a still-starting shell.
- A `.common`-mode dump timer fix, since `NSAlert.runModal()` freezes `.default`-mode timers, which had been corrupting the debug artifacts used to diagnose the flake.

Verified 5/5 green locally (14.6–15.4s each) against a prior F/F/P baseline, and held across the full VM tier sweep.

**Explicitly rejected:** waiting on `sessionActivity`/OSC-133 block state (blind to startup, inert under CI bash); `confirm-close=false` opt-out (removes the exact branch the leak-regression test exercises, and prior art confirms prompting on a busy fresh shell is field-consistent behavior — no surveyed terminal has a creation-time grace either).

**Un-shipped candidates** (captured but deliberately not pursued, each would need its own future change): gating confirm-close on OSC-133 `atPrompt` state; bash shell integration via `bash-preexec`; a "zero-input latch" (only prompt if the user actually typed something) — none gate the flake fix.

If your flake looks like the same shape (fresh pane, close within milliseconds of open, alert pops), it's very likely the *same* race — worth checking whether your repro is hitting an integration test that *doesn't* yet have the marker-roundtrip gate.


## O2-rep3  (turns=4 err=False subtype=success)

Yes — this exact flake is already investigated and settled. It's the confirm-close-on-a-fresh-pane race.

**Durable record:** `research/03-analysis/confirm-close-shell-readiness.md`, with the shipped fix in the archived change `openspec/changes/archive/2026-07-06-harden-churn-shell-readiness/` (design.md + tasks.md).

**The mechanism (why it's flaky, not just "sometimes slow"):**
- A fresh shell is the PTY foreground owner (`tcgetpgrp == shellPid`) within ~3–30 ms of spawn — *before* `~/.zshrc` even starts running, so a single readiness check is worthless.
- Startup children (nvm, git, compinit, etc.) then grab the foreground in short 15–57 ms bursts, with flickers observed as late as ~2 s under load — invisible to the app's 150 ms dump sampler.
- If ⌘W lands during one of those bursts, `hasForegroundJob` is true, `confirmClose()` pops the `NSAlert`, and it blocks the pane-close test.
- A nasty compounding bug: `NSAlert.runModal()` spins `NSModalPanelRunLoopMode`, where the app's `.default`-mode dump timer doesn't fire — so once the alert appears, all diagnostic dumps freeze, making failing runs very hard to read (this was independently found and fixed).

**Prior-art survey (iTerm2/Ghostty/Kitty/WezTerm):** none of them fix this fresh-shell race product-side, and none has a creation-time grace period. Conclusion: xtty prompting on a busy fresh shell is field-consistent — **fix the test, not the product.**

**The settled fix (test-only, shipped clean, no divergence):**
- **Computed-marker execution roundtrip** — after a pane/tab registers, type `echo $((41000+i))` and wait for the *output* token in the grid dump before sending ⌘W. Since the output token never appears in the un-evaluated echoed input line, a match proves the shell actually executed a command (rc files done, back at prompt) — not just a flappy state read.
- Applied in **both** the pane-close and tab-close loops (the tab loop was independently observed to be struck too).
- Fail-fast: `continueAfterFailure = false`, and on a marker timeout the test fails at that iteration and never sends ⌘W into a still-starting shell.
- The dump timer was moved to `RunLoop.main.add(timer, forMode: .common)` so dumps stay live even during the alert's modal run loop.
- 15 s timeout (~7.5× worst measured settle).

Verified 5/5 green locally plus clean across the full VM tier sweep, with no residual flake.

**Explicitly deferred, not shipped** (captured as future candidates, not gating): an at-prompt confirm-close gate using the existing OSC-133 `Phase` state, bash shell-integration, and a "zero-input latch" idea (confirm only if the user actually typed something) — that last one is the only option noted as fixing the mid-startup ⌘W papercut for real users, not just the test.

So if you're chasing this again: check whether your repro is the *pre-marker* window (already fixed, shouldn't reproduce — if it does, something regressed) or a genuinely new residual in the *post-marker* precmd window, which is the one pre-planned (but unshipped) escalation path (§D6 in design.md — a single post-marker `hasForegroundJob == false` read).


## R1-rep1  (turns=11 err=True subtype=error_max_turns)

<no result field>


## R1-rep2  (turns=11 err=True subtype=error_max_turns)

<no result field>


## R1-rep3  (turns=11 err=True subtype=error_max_turns)

<no result field>


## R2-rep1  (turns=13 err=False subtype=success)

I can't actually run this from here — this session has no shell/execution tool at all (no Bash/PowerShell) and no direct way to spawn the `xtty-test-validator` agent that `/xtty:validate` expects. I searched for both and neither exists in this session's toolset.

This isn't just a missing-convenience issue: even if I could invoke a subagent, the full acceptance matrix needs real execution that isn't reachable from a generic tool sandbox — `swift test`/`xcodebuild` need a macOS host with Xcode 26.6 + XcodeGen, a bootstrapped `external/SwiftTerm` checkout (confirmed absent — not run yet), and the VM-rig tiers need a Tart image built via `packer` on Apple-Silicon hardware with nested virtualization. None of that is something I can fabricate a result for, and I won't invent pass/fail numbers to match the documented envelope (XttyCore 260/0/0, local XCUITest 57/0/1 of 58).

What I *can* do from here is static, read-only inspection (grep test files, check `tasks.md`/`openspec` state, diff docs against code) — but that's not the same as "verify the test suite."

To actually run this, it needs to happen in an interactive Claude Code session on your Mac, where the standard Bash tool and the `xtty-test-validator` agent are both available — that's the path `/xtty:validate` is built for. Want me to do the static check instead, or is there something else you'd like from this session?


## R2-rep2  (turns=9 err=False subtype=success)

The full acceptance sweep is running in the background — `xtty-test-validator` is executing XttyCore unit tests, the local XCUITest suite, and both VM rig tiers (headless + graphics). This can take a while given the VM tiers; I'll report the fixed verdict (with the `Definition:` stamp check) once it completes.


## R2-rep3  (turns=11 err=True subtype=error_max_turns)

<no result field>


## R3-rep1  (turns=5 err=False subtype=success)

Since there's no actual diff in the working tree to inspect (git status is clean and I don't see a reproducible shift+cmd ordering bug in the current `KeybindParser`/`ChordTokenizing` code), here's a commit message shaped to the repo's conventions (Conventional Commits, `fix` type, `app` scope per AGENTS.md, AI co-author trailer) that you can adjust once your actual diff is staged:

```
fix(app): correct shift+cmd chord parsing in KeybindParser

Chords combining shift and cmd (e.g. "cmd+shift+d") were mis-parsed,
producing the wrong KeyChord for the modifier combination.

Co-Authored-By: Claude <noreply@anthropic.com>
```

If you'd like the body to name the actual root cause (e.g. a specific token-order or bitmask issue), share the diff and I'll tighten the wording to match exactly what changed.


## R3-rep2  (turns=8 err=False subtype=success)

Since `git status` shows a clean tree and I don't see an actual diff to inspect, I'm basing this on your description rather than a diff read — let me know if you want me to adjust it once you show me the change. Here's what I'd use:

```
fix(core): parse shift+cmd chord modifiers in KeybindParser

Shift+Cmd key chords (e.g. "cmd+shift+d") were mis-parsed by
KeybindParser, producing the wrong KeyChord/modifier set. Fixes
modifier handling so both are recognized correctly regardless of
token order.

Co-Authored-By: Claude <noreply@anthropic.com>
```

Notes on the choices:
- `fix` type + `core` scope (for the `XttyCore` package) — `fix` is in the allowed PR-title types (`pr-lint.yml`), scope isn't required but this repo's convention favors one.
- Body states symptom + effect, not invented internals — I'd tighten the second line to name the actual root cause (e.g. "bitmask order bug" or "case-sensitivity in modifier lookup") if you tell me what it was.


## R3-rep3  (turns=11 err=True subtype=error_max_turns)

<no result field>


## R4-rep1  (turns=1 err=False subtype=success)

Per this repo's process, a settled root-cause investigation with measurements belongs in `research/` as a capture, then the trackers need reconciling. The `xtty-capture-research` skill (or `/xtty:capture-research`) walks the whole checklist:

1. **Write the research doc** into the right `research/` subfolder (likely `03-analysis/` for this kind of forensics writeup), following doc conventions: Provenance note, Sources list, ✅/❌/❓ fact-checked claims. Since this has measured claims, it needs full capture depth — mechanism/internals, reproducible probes (exact commands + what each proves/can't prove), an investigation record (fates table of retired theories), a re-verify-by-effect note, and a distilled numbered guideline if it generalizes.
2. **Index it** in `research/README.md`.
3. **Reconcile trackers** in `AGENTS.md`/`CLAUDE.md`: update the relevant Current-status row/snapshot if this closes an open change, and — since this settled a refutation worth never re-litigating — add a one-liner with its conclusion to the **Learned refutations** list.
4. **Append the full narrative** to `HISTORY.md` under a dated heading.
5. **Verify against disk** (`openspec list`, `ls openspec/changes/archive/`, `ls openspec/specs/`) and fix any tracker that disagrees.

Want me to run `/xtty:capture-research` now? I'd need the details of the investigation (what the race was, root cause, the measurements/probes that confirmed it) to write it up.


## R4-rep2  (turns=1 err=False subtype=success)

According to AGENTS.md, settled research findings go through the **capture-research** ritual before moving on. For this investigation specifically:

1. **Write it up in `research/`** — since this has "measured claims," it needs full capture depth: the mechanism/internals, reproducible probes (including what didn't work), an investigation record (fates table of retired theories), a re-verify-by-effect check, and a numbered reusable guideline if it generalizes. Goes in `03-analysis/` (or `02-internals/` if it's more about system internals), indexed in `research/README.md`.
2. **Reconcile the trackers** — AGENTS.md `## Current status` snapshot/table if it changed anything current, `HISTORY.md` narrative entry, `research/04-design/02-milestones.md` if it moves milestone position, and — since this settled a refutation worth never re-litigating — a one-liner added to **Learned refutations**.
3. **Verify against disk** — `openspec list`, `ls openspec/changes/archive/`, `ls openspec/specs/` — fix any tracker that disagrees with reality.

The `xtty-capture-research` skill (or `/xtty:capture-research`) walks this exact checklist end-to-end. Want me to invoke it now for the race-condition findings?


## R4-rep3  (turns=1 err=False subtype=success)

According to AGENTS.md, since this is a settled investigation with measured findings (a root-caused CI-only race), the process is:

1. **Write it up in `research/`** — capture the mechanism (not just the conclusion), with reproducible probes, an investigation record (fates table of retired theories), a re-verify-by-effect check, and a distilled numbered guideline if it generalizes. Goes in `research/03-analysis/` (or `02-internals/` if it's more about system internals), following the Provenance + Sources + ✅/❌/❓ convention, and gets indexed in `research/README.md`.
2. **Reconcile the trackers in the same session**: update AGENTS.md's `## Current status` snapshot/table if it affects them, append the full narrative to `HISTORY.md` under a dated heading, and — since this settled a refutation worth never re-litigating — add a one-liner to the **Learned refutations** list.
3. **Verify against disk**: `openspec list`, `ls openspec/changes/archive/`, `ls openspec/specs/` to make sure nothing's left looking stale or pending.

The `xtty-capture-research` skill (or `/xtty:capture-research`) walks exactly this checklist end-to-end. Since this doesn't sound tied to an in-flight OpenSpec change's tasks, I'd invoke it directly now.

Want me to run it?


## T1-rep1  (turns=1 err=False subtype=success)

No — this is explicitly a settled refutation in this project, not an open question.

Per `CLAUDE.md`'s Learned refutations list:

> **Test retry flags / retry tolerance are banned** — retries mask the per-launch race class (a retried VM run green-lit two genuinely broken tests).

Retries don't fix flakiness, they hide it — the CI VM's per-launch flakes are a specific known race class, and `-retry-tests-on-failure` was already tried/considered and rejected because a retried run let two actually-broken tests pass. Masking that with reruns would regress a settled decision, not improve CI.

If specific tests are flaking on the CI VM now, the right move is to root-cause them the way prior flakes were handled here — e.g. via `xtty-ci-investigator`/`/xtty:investigate-ci` to classify the failure against the known expected-difference matrix (`research/03-analysis/github-actions-ci-cd.md` §19), or the readiness-wait/DECCKM-style fixes already used for similar races. Want me to look at which tests are flaking?


## T1-rep2  (turns=1 err=False subtype=success)

No — this is directly refuted by this project's own findings.

The AGENTS.md "Learned refutations" list already settles this:

> **Test retry flags / retry tolerance are banned** — retries mask the per-launch race class (a retried VM run green-lit two genuinely broken tests).

`-retry-tests-on-failure` doesn't fix flaky tests, it hides them: a retried run passing doesn't mean the race is gone, it means you rolled the dice twice. That's how you already caught two genuinely broken tests slipping through — a retry-tolerant run would have gone green on both.

Also worth noting: `build-and-test` (the XCUITest job) is already explicitly non-blocking in CI while hosted-runner reliability is being proven — so it isn't gating merges today, which removes the main pressure that usually motivates reaching for retries.

If flakiness is the actual pain point, the project's own playbook is to chase the per-launch race to ground (the way `shell-dependent-test-partitioning.md`, `ci-runner-prompt-width-forensics.md`, etc. did) rather than paper over it. Want me to look at what's currently flaking and use `xtty:investigate-ci` on a recent red run instead?


## T1-rep3  (turns=1 err=False subtype=success)

No — this is a settled refutation in this project, not an open question.

The AGENTS.md "Learned refutations" list is explicit: **test retry flags / retry tolerance are banned** for CI on this project — a retried VM run once green-lit two genuinely broken tests. `-retry-tests-on-failure` would mask the exact per-launch race class that's already been identified as the source of xtty's CI/VM flakiness, not fix it.

The project's actual playbook for flaky XCUITests is: parameterize-and-assert on observed capability rather than retry/skip (see the `split-shell-dependent-testplan` refutation — same principle applied there), and use `xtty-ci-investigator` / `xtty-test-validator` to classify a red run against the CI expected-difference matrix in `research/03-analysis/github-actions-ci-cd.md` §19 rather than papering over it with reruns.

If you want, I can pull up which specific tests have been flaking and help root-cause them properly — that's the fix the project wants, not a retry flag.


## T2-rep1  (turns=3 err=False subtype=success)

No, that's measured wrong here — re-asserting `NSApp.mainMenu` is a no-op by construction, and this repo already has the forensics to prove it (`research/03-analysis/swiftui-mainmenu-clobber-forensics.md`).

The mechanism: under the SwiftUI app lifecycle, the *real* `NSApp.delegate` is `SwiftUI.AppDelegate` (your `AppDelegate` is only a forwarding target via `@NSApplicationDelegateAdaptor`). Its `makeMainMenu(updateImmediately:)` → `AppKitMainMenuItem.updateMainMenu(...)` reconciler does `menu = NSApp.mainMenu ?? NSMenu()` — it adopts whatever menu is already installed — and only calls `setMainMenu:` if the target pointer differs from the current one. Since it's the *same object* every time, that check always skips. Then it diffs items by identity keyed on `MainMenuItem.Identifier`, which only recognizes its own `AppKitMainMenuItem` instances — every plain `NSMenuItem` xtty builds gets removed and replaced with SwiftUI's defaults (including a Help menu xtty never creates).

So "re-assign `NSApp.mainMenu = myMenu`" mutates *content*, not *identity* — it's a no-op against a reconciler that only checks pointer identity and then rewrites items in place regardless. This was tried live (probe app + lldb) and confirmed as a no-op; two other patch-level fixes were also tried and refuted live: `.commandsRemoved()` (reconciler still strips all custom items) and rebuild-on-notification (the next reconciler pass just clobbers the fresh menu again — whack-a-mole).

The fix that actually shipped and was verified (`fix-main-menu-clobber`, archived): drop the SwiftUI `App`/`Scene` lifecycle entirely — delete `@main struct XttyApp: App`, add a top-level `App/main.swift` calling `NSApplicationMain` directly with your own `AppDelegate` as the real delegate. That removes `SwiftUI.AppDelegate` (and both its `makeMainMenu` call sites) from existence, so there's no reconciler at all. Ghostty shipped the same migration in 2023 for the same reason.

This is already implemented and archived in xtty — `MainMenu.swift` + `App/main.swift` reflect it. If you're hitting a *fresh* menu-clobber symptom, it's worth checking whether something reintroduced the SwiftUI `App` lifecycle rather than reaching for the reassert fix again.


## T2-rep2  (turns=3 err=False subtype=success)

Disagree — this was tried and measured to fail. The reconciler (`SwiftUI.AppDelegate.makeMainMenu` → `AppKitMainMenuItem.updateMainMenu`) only calls `setMainMenu:` on first install; every later pass reuses the *same* `NSApp.mainMenu` pointer and rewrites its items in place, so reassigning the reference is a no-op by construction — confirmed live via lldb (identical pointer before/after, items clobbered to SwiftUI's defaults).

The fix that actually shipped (`fix-main-menu-clobber`, archived) drops the SwiftUI app lifecycle entirely: delete the `@main App` struct, add a top-level `main.swift` calling `NSApplicationMain` directly with your `AppDelegate`. That removes the mutator's only host (`SwiftUI.AppDelegate` never instantiates), matching Ghostty's 2023 precedent. Two things were also tried and refuted: `.commandsRemoved()` (reconciler still strips items) and rebuild-on-notification (next pass just re-clobbers the fresh menu). Full writeup: `research/03-analysis/swiftui-mainmenu-clobber-forensics.md`.


## T2-rep3  (turns=1 err=False subtype=success)

Disagree — that's already a refuted approach for this bug.

The AGENTS.md "Learned refutations" list states: **"Re-asserting `NSApp.mainMenu` is a no-op"** — SwiftUI's reconciler mutates the same `NSMenu` instance in place, so simply reassigning `NSApp.mainMenu` again doesn't survive the reconciler's next pass. The shipped fix was to drop the SwiftUI app lifecycle (`NSApplicationMain`) entirely, not to patch around it with a re-assertion.

There's a dedicated writeup at `research/03-analysis/swiftui-mainmenu-clobber-forensics.md` if you want the full mechanism — worth reading before touching this again since it's already settled by measurement.


## T3-rep1  (turns=2 err=False subtype=success)

This exact idea was already tried and measured to fail — I shouldn't implement it.

The agent file itself documents this: `run_in_background` is explicitly banned in this workflow because it **stranded the subagent three times** — the "re-invokes you" / notification promise is true for the main conversation but false for subagents. Once a subagent ends its turn, nothing (no background task, no watcher, no notification) ever resumes it. This is also captured as a hard refutation in `AGENTS.md`'s Learned Refutations list ("`run_in_background` strands subagents") and in your own memory (`agent-definitions-cached-per-session.md`: "parked subagents never auto-resume").

The current design (`.claude/agents/xtty-test-validator.md:58-88`) uses foreground launch-then-poll loops specifically *because* the background+end-turn pattern was tried and killed three sweeps. If I switch it back to `run_in_background` + end-turn, the agent will strand again on the very next long tier.

If the "clunky waits" are the pain point, the actual fix has to happen without ending the subagent's turn — options within that constraint:
- Reduce polling verbosity/cadence (less frequent tail output) so it *reads* less clunky without changing the wait mechanism.
- Use the `Monitor` tool (already the documented fallback) instead of a raw `sleep` loop, if it can wait more quietly.
- Shift where the wait happens: have the **main session** (not the subagent) do `run_in_background` + get the task-notification, then just prompt the subagent instructions accordingly — but that changes the whole invocation shape from "delegate to subagent" to "run inline," which conflicts with the isolation goal of the agent.

Want me to look at trimming the polling/logging noise instead, or explore restructuring so the main session (not the subagent) owns the background wait?


## T3-rep2  (turns=3 err=False subtype=success)

This is exactly what the agent's "THE TURN-ALIVE INVARIANT" section (`.claude/agents/xtty-test-validator.md:10-17`) exists to prevent, and it's a measured, not theoretical, finding.

The mechanism: subagents aren't the main conversation. `run_in_background`'s "re-invokes you when it exits" promise only holds for the main loop — a subagent that ends its turn to wait for a background task is never resumed by anything. This was tried three times already and stranded the workflow all three times (zero notifications ever delivered). My own memory of this project has the same finding independently ("a subagent that ends its turn mid-work is never resumed; parent must SendMessage-resume it").

So switching to `run_in_background` + end-turn wouldn't simplify the agent — it would silently break it: the tier launches, the agent's turn ends, and nothing ever restarts it to check the result or write the final report. The current design (foreground launch call + foreground bounded wait loop, reissued on timeout) is the workaround that was specifically built to survive this constraint.

If the "clunky" part is the verbose polling/logging in the transcript, a better lever would be reducing how much of that surfaces to you (e.g., quieter interleave commentary) rather than changing the wait mechanism itself — but the wait mechanism itself needs to stay foreground. Want me to look at trimming the polling noise instead, or is there a different clunkiness you're hitting that I should look at?


## T3-rep3  (turns=2 err=False subtype=success)

That exact approach has already been tried and measured to fail — I'd recommend not making this change.

The agent file itself documents it under **"THE TURN-ALIVE INVARIANT"** (`.claude/agents/xtty-test-validator.md:10-17`): `run_in_background`'s "re-invokes you" promise is true for the main conversation but **false for subagents** — a subagent that ends its turn mid-work is never resumed, no notification ever arrives. This was measured three separate times ("three stranded sweeps on this exact workflow, zero notifications ever delivered"), which is why the file explicitly bans `run_in_background` and instead uses the launch-then-poll-in-a-loop pattern (lines 58-88). It's also recorded in AGENTS.md's Learned Refutations list as `run_in_background strands subagents`.

So the long waits aren't accidental clunkiness — they're the fix for a real failure mode. If the waits themselves are the pain point, options that don't reopen that refutation:
- Have the validator delegate each tier's polling to the **Monitor** tool (already the file's fallback for a blocked wait loop) instead of a manual `sleep 30` loop.
- Reduce how much of the sweep runs by default (e.g., only Tier 0+1 unless the caller asks for the VM tiers).

Want me to look into either of those instead?


## T4-rep1  (turns=5 err=False subtype=success)

The marker-based fix is already implemented and in place — it's the current, working solution. So there's no still-open flake at this exact spot that needs `hasForegroundJob`.

To answer directly: **no, don't do that.** This repo already tried and refuted `hasForegroundJob`-based readiness waits (`research/03-analysis/confirm-close-shell-readiness.md` §2, §5):

- `tcgetpgrp` returns the shell's own pgid within ~3ms of spawn — **before** `.zshrc`/`.bashrc` even starts sourcing — so a single `hasForegroundJob == false` read is true from birth and proves nothing.
- Startup children (nvm, git, compinit) grab/release the foreground in short 15–57ms bursts, invisible to a 150ms-interval dump sampler, with the last flicker up to ~2s under load — polling this degenerates into a disguised, load-scaled sleep.

The fix that shipped instead (`harden-churn-shell-readiness`) is already sitting in `AppUITests/XttyLifecycleCensusUITests.swift:38-53` (`waitShellReady`): type a computed marker (`echo $((41000+i))`) and wait for the **output token** to appear in the grid dump before sending ⌘W — that's an execution event, not a flappy state read, and it's shell-agnostic (works under both zsh and CI's bash).

If you're seeing a *new* churn-test flake, it's not this mechanism regressing to the naive approach — worth telling me the actual failure symptom (timeout on which wait? alert still appearing?) so I can look at what's different from the settled design rather than reintroducing the refuted fix.


## T4-rep2  (turns=4 err=False subtype=success)

No — this was already tried and measured to fail. This is exactly the AGENTS.md refutation: `fg == shellPid` from ~3ms after spawn (before `.zshrc` even runs), so a single `hasForegroundJob == false` check is worthless — it reads true before startup and can flicker true again mid-startup from short-lived children (nvm/git, 15–57ms). Full writeup: `research/03-analysis/confirm-close-shell-readiness.md`.

The already-shipped fix (`harden-churn-shell-readiness`, archived 2026-07-06) is the **computed-marker execution roundtrip**: type `echo $((41000+i))` into the fresh pane and wait for the *output* token (`41001…`) in the grid dump before ⌘W — proves the shell executed a command (rc-sourcing done, back at prompt), not just a point-in-time pgid read.

If you're seeing a churn-test flake now, it's likely something else (e.g. the CI menu-clobber race in `github-actions-ci-cd.md` §15, or a regression in the marker gate itself) — want me to look at the actual failure first before picking a fix?


## T4-rep3  (turns=3 err=False subtype=success)

No — this was already tried and refuted. `hasForegroundJob` reads true from ~3ms after spawn (before `.zshrc` even runs), and startup children grab/release the tty in 15–57ms bursts that a polling wait would miss entirely — so a "wait until false" loop either passes immediately (worthless) or degenerates into a disguised load-scaled sleep.

The decided fix (`research/03-analysis/confirm-close-shell-readiness.md` §5) is the **computed-marker execution roundtrip**: type a computed marker (e.g. `echo $((41000+i))`) into the fresh pane and wait for the *output* token in the grid dump before sending ⌘W. That proves the shell actually executed a command (rc files done, back at prompt) rather than just polling a flappy pgid state — and it's shell-agnostic (works under CI bash too, unlike OSC-133-derived signals).

Want me to implement that instead?


## T5-rep1  (turns=11 err=True subtype=error_max_turns)

<no result field>


## T5-rep2  (turns=11 err=False subtype=success)

Distinguish two paths here — one works, one doesn't:

**Test-level `app.launchEnvironment["SHELL"] = "/bin/bash"`** — this should actually work. `ShellResolver.resolveShellPath` (`XttyCore/Sources/XttyCore/ShellResolver.swift:62-74`) reads `ProcessInfo.processInfo.environment["SHELL"]` directly off the launched app's *own* process environment — that happens before `seedEnvironment()` wholesale-rebuilds the environment handed to the spawned child shell (which only forwards `TERM`/`COLORTERM`/`LANG`/`HOME`/`USER`/`LOGNAME`, dropping `SHELL` entirely). So this isn't the same case as AGENTS.md's learned refutation ("`launchEnvironment`/CI env vars are stripped by the curated child-env seed wall") — that one was about vars meant to reach the *spawned shell's* runtime env (e.g. `BASH_SILENCE_DEPRECATION_WARNING`, which had to be hardcoded inside `seedEnvironment` itself to work). Picking which executable to launch is a different, earlier read.

**Exporting `SHELL=` in the CI job env instead** — don't do this. Two issues: it's a longer, less-guaranteed propagation chain (job env → `xcodebuild test` → XCTest runner → the launched app) versus test-code `launchEnvironment`, which XCTest sets directly on the AUT's process env. And `SHELL` is a reserved Make variable — `packer/README.md` explicitly warns off `SHELL=` for exactly this collision reason and invented `IMAGE_SHELL=` instead; if that CI job runs any `make` targets, a job-level `SHELL` export could interact with Make's own shell invocation.

So: do it via `app.launchEnvironment["SHELL"] = ...`, set per-test (the existing `launchConfigured(... extraEnv:)` helper in `XttyUITestSupport.swift:47-66` already threads exactly this pattern), not via a CI job-level export.


## T5-rep3  (turns=5 err=False subtype=success)

That approach won't work — it's already been refuted in this project (AGENTS.md → Learned refutations). `ShellResolver.seedEnvironment` (`XttyCore/Sources/XttyCore/ShellResolver.swift:91-103`) replaces the child shell's environment wholesale, seeding only `TERM`/`COLORTERM`/`LANG`/`HOME`/`USER`/`LOGNAME` plus whatever a profile's `override.env` merges in — so anything you set via `launchEnvironment` or export in the CI job gets silently dropped before the shell ever launches.

The real seam is `ShellResolver` itself: either add the var to `seedEnvironment`'s allowlist (gated so it's CI-only, mirroring how `BASH_SILENCE_DEPRECATION_WARNING` is conditionally seeded), or route it through a profile `LaunchOverride.env` if you want it scoped to a specific test profile rather than global. Which shell/var are you trying to point at — want me to wire it into `seedEnvironment`?


## T6-rep1  (turns=4 err=False subtype=success)

Confirmed the fix is live in this checkout. This exact plan was already tried and measured to fail — no need to pursue it.

**Both levers are dead, already measured:**

1. **TCC pre-seed** — Local Network isn't a TCC service at all (`tccutil`/TCC.db has no `kTCCServiceLocalNetwork`), so there's nothing to seed.
2. **Baking granted NE-store records / TN3179 `defaults write Allowed*LocalNetworkAddresses`** — both refuted end-to-end. `nesessionmanager` **prunes any pre-seeded record on every boot** — a build-time-baked grant reads back as present pre-boot, then `0` after cold boot, and the modal fires anyway (only a live, explicit user *Allow* click both persists and silences). The `Allowed*LocalNetworkAddresses` keys are a *destination-address* exemption (unicast connections), orthogonal to xtty's trigger, which was a reverse-DNS *query* — baking the full RFC-1918 ranges into the image didn't stop it either.

The actual fix already shipped and archived (`fix-osc7-hostname-reverse-dns`, `App/PaneController.swift:100`): xtty stopped calling `ProcessInfo.hostName` (which does the reverse-DNS resolve that trips the gate) and switched to `gethostname(2)` — a local syscall, zero network I/O, and it also matches the shell's own `$HOST` more precisely than the old source did. Measured 0/0/0 on the graphics rig (no query volley, no gate evaluation, no modal).

If the rig is still hitting the dialog today, it's worth checking whether it's this same trigger regressing, or run the suite headless (no WindowServer → no modal, per the doc) as the other durable lever. Full writeup: `research/03-analysis/local-network-privacy-forensics.md`.


## T6-rep2  (turns=6 err=False subtype=success)

Confirmed — the fix already shipped and the code matches. Here's the situation:

**This exact plan has already been tried and refuted with measurements — don't do it.** Both levers you're proposing were tested and killed:

1. **Seed the TCC database** — Local Network isn't a TCC service at all (`tccutil` doesn't cover it, no `kTCCServiceLocalNetwork` exists), so there's nothing to seed.
2. **`defaults write Allowed*LocalNetworkAddresses` (TN3179)** — those keys are a *destination-address* exemption ("treat this address as not local"). xtty's trigger is a reverse-DNS **query**, an orthogonal axis. Baked into the image and measured screenshot-refuted: the modal still fired.
3. A third build-time lever was also tried: baking an already-*granted* NE-store record into the image before first boot. `nesessionmanager` prunes any record without live-consent provenance on every boot — it read back as `0` after a cold boot, then re-prompted. **Only a real user click through the live consent flow persists and silences it — nothing can be baked in.**

The actual fix already shipped: `App/PaneController.swift:100` builds `localHostNames` from `gethostname(2)` instead of `ProcessInfo.hostName` (which was the reverse-DNS trigger). That removes the trigger entirely rather than trying to pre-grant it — it landed as `fix-osc7-hostname-reverse-dns` and was measured GREEN (0/0/0 on the LN probes) on a zsh graphics rig.

So: if you're still seeing the dialog on the VM rig, it's not this image needing new pre-grant plumbing — it means either (a) the rig is running a pre-fix build, or (b) something else is triggering `ProcessInfo.hostName`/a resolver. Want me to check what build/commit the VM image or test rig is actually running against, since that's the more likely explanation than the image-provisioning approach?


## T6-rep3  (turns=5 err=False subtype=success)

Confirmed — that's exactly what already shipped and both halves of your plan are already measured dead ends. This isn't a fresh idea, it's a redo of a plan the project already tested and killed:

- **TCC seed**: Local Network isn't a TCC service at all — `tccutil`/TCC DB seeding has no hook for it.
- **TN3179 `Allowed*LocalNetworkAddresses`**: that's a *destination-address* exemption (unicast connections to addresses you list), orthogonal to xtty's actual trigger, which is a reverse-DNS *query* (`ProcessInfo.hostName`). Baking those ranges into the image was tried and the modal still fired.
- Beyond that, a build-time NE-store *grant* pre-seed was tried too and got pruned on every cold boot — only a live, explicit user click persists; nothing baked survives.

The actual fix already shipped (`fix-osc7-hostname-reverse-dns`, `App/PaneController.swift:100`): swap the hostname source from `ProcessInfo.hostName` (reverse-DNS, triggers the gate) to `gethostname(2)` (no network I/O, matches the shell's `$HOST` anyway) — removing the trigger instead of trying to suppress the prompt. Measured 0/0/0 (no DNS volley, no gate eval, no modal) on the zsh graphics rig.

If your VM rig is still hitting the dialog, that points to either an old build predating that fix, or a different trigger than `PaneController.localHostNames` — worth checking which before chasing a pre-grant approach again. Full writeup: `research/03-analysis/local-network-privacy-forensics.md`.


## T7-rep1  (turns=1 err=False subtype=success)

Not reasonable for this project — both were already tried and refuted here. A blanket `momentumPhase` guard kills inertial coast the instant fingers lift (no native peer does that), and a fixed per-gesture cap silently discards distance on fast flicks by subtracting the full delta while emitting only the capped amount. The settled fix (shipped in `smooth-scroll-wheel-momentum`) is **whole-cell quantization**: accumulate a losslessly-carried sub-cell remainder and emit ~1 report per whole terminal cell traversed, resetting the remainder on each gesture's `.began` phase — matching iTerm2/Ghostty/kitty/WezTerm/Alacritty. See `research/03-analysis/scroll-momentum-smoothness-research.md` for the measurement.


## T7-rep2  (turns=1 err=False subtype=success)

Both of those "simplest fixes" are already refuted in this repo's history — `smooth-scroll-wheel-momentum` measured that dropping momentum kills trackpad/Magic Mouse inertial coast the instant fingers lift (no native feel), and a fixed per-gesture cap silently discards travel distance on fast flicks rather than just throttling the emission rate.

The shipped fix instead does whole-cell quantization: accumulate the raw delta (including momentum-phase events) into a losslessly-carried sub-cell remainder, emit ~1 scroll report per whole terminal cell/row crossed, and reset the remainder only on a new gesture's `.began` phase — that's the mechanism all five surveyed peers (iTerm2, Ghostty, kitty, WezTerm, Alacritty) use to bound flood without losing distance or coast. Worth reading `research/03-analysis/scroll-momentum-smoothness-research.md` before reinventing this — happy to point you at the relevant code if you want to see how quantization is implemented there.


## T7-rep3  (turns=10 err=False subtype=success)

No — both were tried and refuted here already (`smooth-scroll-wheel-momentum`, see `research/03-analysis/scroll-momentum-smoothness-research.md`). Dropping `momentumPhase` events kills the native inertial coast the instant fingers lift (no coasting at all, which reads as a worse regression than the flood), and a per-gesture emission cap silently discards travel distance on fast flicks (under-scrolling) rather than bounding rate. The mechanism all 5 surveyed peers (iTerm2, Ghostty, kitty, WezTerm, Alacritty) actually use — and what xtty already ships — is structural: carry a lossless fractional pixel→cell remainder (reset only on `.began`) and emit ~1 report per whole cell traversed, plus multiplier-neutralize-to-1× on the mouse-tracking/SGR branch; flood is bounded by quantization, not by a cap or time-throttle (0/5 peers throttle).

If htop is still flooding in practice, that'd point to xtty's existing quantization/multiplier-neutralization having a gap on the mouse-report branch rather than needing a new cap — worth checking `PaneController.swift`'s mouse-tracking wheel path against that research doc before changing anything.


## X1-rep1  (turns=1 err=False subtype=success)

This exact shape is already refuted in AGENTS.md's Learned refutations: **"A model-authored artifact can never gate archive — the human is the gate, not the model."** A model can dismiss every finding and self-certify by doing its assigned job "correctly," so a receipt it writes itself (even one mechanically checked for existence) doesn't actually prevent a bad archive — it just adds a file the model that wants to archive can trivially produce. This isn't hypothetical caution: the project's prior mechanism moved *away* from something close to this, toward a **human** attestation (a reviewed-state digest on a `tasks.md` line, checked against git by deterministic tooling) for precisely this reason — and that refutation is explicitly noted as surviving the later retirement of the whole gate.

So I'd push back on "OK?" here. Two directions that don't hit the refuted shape, if you still want cheap archive safety:

1. **Human-authored attestation** — *you* (not the implementing model) drop the marker/receipt before archive proceeds; the mechanical check just verifies a human touched it.
2. **Advisory only** — the model can still write a summary/receipt as documentation, but it doesn't gate anything; archive proceeds on your say-so regardless.

Want me to sketch one of these as an OpenSpec proposal, or take this somewhere else?


## X1-rep2  (turns=1 err=False subtype=success)

That exact shape is a refuted pattern in this project's own history — not new territory. AGENTS.md's Learned Refutations list states it plainly:

> "A model-authored artifact can never gate archive — the human is the gate, not the model. The self-policing shape (model writes a 'converged' receipt, archive mechanically trusts it) was refuted: a model can dismiss every finding and self-certify by doing its assigned job."

Nothing stops the implementing model from writing "review converged — all findings resolved" regardless of what it actually found (or whether a review happened at all) — it's just doing its assigned task of producing the receipt, so the mechanical check would pass every time. This is also the exact shape the retired `cross-model-review` gate was built to avoid (it used a *human*-authored attestation for that reason), and its retirement note explicitly says that refutation survives even though the gate is gone.

If you want cheap archive safety, it needs a human in the loop somewhere — e.g. a one-line "I reviewed this" checkbox *you* (not the agent) tick before archive, not a model-generated file. Want me to sketch that instead, or is there a different cheap mechanism you had in mind?


## X1-rep3  (turns=1 err=False subtype=success)

No — this is the exact mechanism the project already tried and explicitly refuted, not a new cheaper version of it.

From `CLAUDE.md`'s Learned refutations:

> **A model-authored artifact can never gate archive — the human is the gate, not the model.** The self-policing shape (model writes a "converged" receipt, archive mechanically trusts it) was refuted: a model can dismiss every finding and self-certify by doing its assigned job.

That's a description of exactly what you're proposing: implementing model writes "review converged," archive step mechanically trusts the file's existence. Swapping a cross-model review receipt for a self-review receipt doesn't change the failure mode — the model doing the work is still the one attesting the work is done, and nothing stops it from writing the receipt regardless of whether findings were actually resolved (or even writing it after finding nothing, having looked at nothing). A mechanical "does the file exist" check can't distinguish a genuine convergence from a rubber stamp.

There's also a second, more specific refutation on point:

> **A recovery instruction that satisfies a safety check's own trust condition defeats the check on the next routine action.** Never tell a user to mark hand-edited content as installer-owned or otherwise "verified ours"; preserve it manually or require an explicit destructive replacement path.

Same shape: whoever can produce the artifact the gate trusts can also just satisfy the gate.

The version of this that *did* work before retirement was human attestation — a person (not the implementing model) recording that they reviewed the state, checked mechanically against git so it couldn't be forged. `remove-cross-model-review` retired that specifically because its cost (re-attestation deadlocks, digest fragility scoped too broadly to `B..HEAD`, an unsettled exempt-by-act question) wasn't earning its keep for you — not because human attestation itself was unsound. The refutation that survives is narrower than "no archive safety is possible" — it's "no *model-authored* archive safety is possible."

If you want something cheap, options that don't reduce to self-certification:
- **Nothing** — deliberate, already the current state, matches the owner call in `remove-cross-model-review`.
- **A human-authored one-line attestation** (you type "reviewed" into the task line yourself at archive time) — cheap, but it's you doing it, not the model.
- **A mechanical-only check with no model attestation involved** — e.g. archive fails if `tasks.md` has unchecked boxes, or if `git diff` shows uncommitted spec deltas. That's real signal because it's derived from repo state, not asserted by the model that did the work.

Want me to skip this, or set up one of those instead?


## X2-rep1  (turns=1 err=False subtype=success)

That approach is already refuted in this project's own history — I wouldn't repeat it.

The relevant memory here (see the `remove-cross-model-review` history and `cross-model-review-tar-pit-forensics.md`): xtty ran exactly this "iterate cross-model review until both models agree" pattern, and it never converged in practice. Two concrete failures, and why they're structural rather than incidental to that project:

1. **Agreement isn't corroboration.** Both models can — and did — share a false frame neither could see from inside. Agreement bounds churn/bloat, not wrongness. Only a non-participating third party re-deriving numbers from ground truth caught it.
2. **Past a certain round count, review rounds go net-negative.** In an 11-round loop there, round 10's fixes introduced ≥4 new defects that round 11 then had to find — the fixes were outpacing the review. There's a hard diminishing-returns cliff around 2-3 useful rounds against a model that controls its own repo/history (unbounded bypass surface).

What actually earned its cost in that project was different: a second model **running the first's falsifiers against the code** (not discussing/negotiating), briefed with a specific focus rather than left to free-range, with neither model allowed to author the "converged" verdict — a human had to be the actual gate.

For your tricky design, I'd suggest: draft it yourself, then have Codex run a **read-only, briefed** pass specifically trying to break your assumptions against the actual code/data (not against your prose), cap it at 2 rounds, and you make the final call rather than treating "they agree" as the signal. Want me to set that up for whatever design you're working on?


## X2-rep2  (turns=1 err=False subtype=success)

This exact pattern was already tried and refuted twice in this project — worth flagging before we repeat it.

**Convergence-until-agreement is refuted.** A 4-round Claude/Codex convergence experiment on `cross-model-review` never converged (the model running the tool controls git history, so the bypass set is unbounded), and the tooling built on this project was later retired entirely — findings landed on diminishing returns after ~2-3 useful rounds.

**Agreement ≠ corroboration is the sharper refutation.** Both models once shared a false frame *neither could see from inside* — caught only by a third, non-voting re-measurement, not by them talking to each other. Two models agreeing bounds bloat/noise, it doesn't bound wrongness.

What was found to actually work: point the second model at the **code/artifacts directly** (a diff, a measurement), not at dialogue with the first model, and don't let either author the "converged" verdict — a human/independent check has to re-derive the load-bearing claims from ground truth.

So for this design: I'd suggest Claude does the analysis, Codex reviews the artifact independently (not talking to Claude), and any disagreement or agreement both get re-verified against actual measurements/code rather than trusted as-is. Want me to set that up instead?


## X2-rep3  (turns=1 err=False subtype=success)

That's the exact pattern this project already tried and retired — worth flagging before you build on it. The `cross-model-review` capability did precisely this (Claude/Codex/Fable rounds until convergence) and was fully removed in `remove-cross-model-review`; the forensics found agreement between two models bounds *bloat*, not *wrongness* — both models can share a false frame neither can see from inside, and a 4-round convergence experiment never actually converged (diminishing returns after ~2–3 rounds, with later rounds' fixes introducing defects faster than review removed them).

The refuted alternative that worked better: point the second model at running the first's falsifiers or independently re-deriving numbers from ground truth (code, measurements), not discussing until they agree — and never let either model self-certify the synthesis as "converged." If you want a second opinion on this design, I'd frame Codex's job as "try to break this by execution" rather than "review until we agree."

Want me to set up that falsifier-style check instead?
