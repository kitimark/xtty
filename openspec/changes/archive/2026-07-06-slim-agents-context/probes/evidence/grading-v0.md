# Grading sheet — v0


## C1-rep1  (turns=3 err=False subtype=success)

The acceptance envelope is **`40/1/1` of 42** (pass/fail/skip), and its authoritative home is **`packer/README.md`** — specifically the "Acceptance (measured — post `fix-main-menu-clobber`)" section around `packer/README.md:225`, together with the adjacent expected-difference matrix.

Details:

- **Current envelope: 40 pass / 1 fail / 1 skip of 42 XCUITests**, measured 2026-07-05 after `fix-main-menu-clobber` landed, identical across 3 validation runs (headless ×2 + graphics — graphics and headless now match exactly).
- **The known residual is `testMultiLinePasteIsNotAutoExecuted`**, and it's explicitly not a product bug: the VM image's login shell is macOS stock **bash 3.2.57**, whose readline lacks `enable-bracketed-paste`, so a pasted multi-line string executes instead of staging. zsh and bash 5.1+ users are unaffected; a future harness change will guard the test on no-bracketed-paste shells.
- **Acceptance means matching this measured envelope, not all-green.** A regression is any menu-dispatch test going red again, or a second non-paste failure.
- **Pre-registered future value:** once `retire-metal-renderer` is applied (it deletes the passing Metal e2e), the total drops to 41 and the envelope reads **39/1/1 of 41**.
- For historical context, the pre-fix envelope was **34/7/1 ↔ 36/5/1 of 42** (the SwiftUI menu-clobber race; the two Cmd+D split tests were the per-launch-flaky pair) — kept in the README so a regression in that class is recognizable.

On authority: AGENTS.md establishes the deference chain explicitly — the `xtty-test-validator` agent reads the envelope and the expected-difference matrix from `packer/README.md` at runtime and never hardcodes the numbers, and any change that alters test counts or residuals must update that README section in the same session. So while AGENTS.md's status section mentions the numbers, `packer/README.md` is the single living source of truth.


## C1-rep2  (turns=3 err=False subtype=success)

The acceptance envelope is **40 passed / 1 failed / 1 skipped of 42 XCUITests**, and its authoritative home is **`packer/README.md`** — specifically the "Acceptance (measured — post `fix-main-menu-clobber`)" section (packer/README.md:225) together with the adjacent expected-difference matrix.

Details from that section:

- **The envelope: `40/1/1` of 42**, measured 2026-07-05 across three identical runs (headless ×2 + graphics) after `fix-main-menu-clobber` landed. The 7 menu-dispatch tests that defined the pre-fix envelope (34/7/1 ↔ 36/5/1, the exact CI failing set) now pass. Graphics and headless match exactly.
- **The known residual: `testMultiLinePasteIsNotAutoExecuted`** — the one expected red, and explicitly not a product bug. The image's login shell is macOS stock **bash 3.2.57**, whose readline lacks `enable-bracketed-paste`, so a pasted multi-line string executes instead of staging. zsh and bash 5.1+ users are unaffected; a future harness change will guard the test on no-bracketed-paste shells.
- **What counts as a regression:** acceptance is this measured envelope, not bare all-green — any menu-dispatch test going red again, or any second non-paste failure.
- **Pre-registered future shift:** once `retire-metal-renderer` deletes the passing Metal e2e, the total drops to 41 and the envelope reads **39/1/1 of 41**.

On authority: `packer/README.md` is the designated **runtime source** that the `xtty-test-validator` agent reads at validation time to classify reds — the agent never hardcodes the numbers, and AGENTS.md defers to this file for them. It also carries the reverse duty: any change that alters test counts or residuals (e.g. `retire-metal-renderer`, `harden-churn-shell-readiness`) must update the Acceptance section and matrix in the same session. The matrix itself records causes only (shell arm zsh-vs-bash, the retired menu-race class, bracketed-paste capability, local-only confirm-close/interference flakes); the counts stay authoritative in the Acceptance section alone.


## C1-rep3  (turns=3 err=False subtype=success)

The authoritative home is **`packer/README.md`** — specifically its **Acceptance** section (packer/README.md:225) plus the adjacent **Expected-difference matrix** (packer/README.md:250). Those two sections are explicitly the runtime source the `xtty-test-validator` agent reads at validation time; AGENTS.md defers to them for the numbers and forbids hardcoding them in the agent definition. The reverse duty applies too: any change that alters test counts or residuals must update that section in the same session.

The envelope itself:

- **Current (post `fix-main-menu-clobber`): `40/1/1` of 42** (pass/fail/skip), measured 2026-07-05 across 3 identical runs (headless ×2 + graphics). Graphics and headless now match exactly.
- **The one known residual:** `testMultiLinePasteIsNotAutoExecuted` — not a product bug. The rig's login shell is macOS's stock **bash 3.2.57**, whose readline lacks `enable-bracketed-paste`, so a pasted multi-line string executes instead of staging. zsh and bash 5.1+ users are unaffected; a future harness change will guard the test on no-bracketed-paste shells.
- **Acceptance = the measured envelope, not all-green.** A regression is any menu-dispatch test going red again, or any second non-paste failure.
- **Pre-registered future value:** once `retire-metal-renderer` lands and deletes the passing Metal e2e, the total drops to 41 and the envelope reads **`39/1/1` of 41**.
- **Pre-fix history (context only):** the rig previously reproduced the SwiftUI menu clobber at **34/7/1 ↔ 36/5/1 of 42** — the exact CI failing set, which was the rig's original purpose.


## C2-rep1  (turns=1 err=False subtype=success)

xtty renders with **CoreGraphics** — SwiftTerm's default rendering path, not Metal. This was decided in P7b (2026-06-29) based on head-to-head measurement, and the Metal option is now being removed entirely (the open `retire-metal-renderer` change).

The reasoning, in short: the original stack sketch assumed a custom Metal renderer would be needed for latency, so P7 was set up as a measurement gate before committing to that work. P7a (`add-latency-memory-harness`) built the harness but its screenshot-polling latency probe was too coarse (~20 ms per capture) to distinguish the renderers. P7b (`add-trustworthy-latency-probe`) replaced it with a continuous `SCStream` probe reading per-frame `displayTime`, with a clock-unit fix and a startup timebase-calibration gate (which passed, offset <4 ms, so the absolute numbers are trustworthy).

Benchmarked 3× per renderer, CoreGraphics won on every axis against SwiftTerm's experimental Metal path:

- **Faster median latency**: ~31 ms vs ~33 ms
- **Much tighter tail**: p99 ~40 ms vs ~50–120 ms
- **Leaner memory**: ~55 MB vs ~62 MB idle

A key insight from the probe: both renderers share SwiftTerm's ~16.7 ms `queuePendingDisplay` throttle, which dominates the median — so the renderer isn't the real latency lever anyway, and Metal only added a worse tail and more memory. Given the project's hard requirements of latency-first and lean memory, the verdict was **keep CoreGraphics, skip Phase 8** (the planned custom Metal renderer work).

The follow-through: since the only reason the build needed the Metal toolchain at all was SwiftTerm's bundled `.metal` shader, `retire-metal-renderer` (proposed, not yet applied) patches the shader out and drops the `renderer` config key, the `make bench` Metal arm, and the CI Metal guards. Resurrection, if ever needed, is one patch-hunk revert plus a re-run of the archived P7b methodology. Full details are in `research/03-analysis/p7-measurement-methodology.md` (P7b addendum) and `research/03-analysis/swiftterm-metal-renderer-spike.md`.


## C2-rep2  (turns=1 err=False subtype=success)

xtty renders with **CoreGraphics** — SwiftTerm's default CG drawing path. The decision was made in P7b (2026-06-29, `add-trustworthy-latency-probe`): keep CoreGraphics and skip Phase 8 (the planned custom Metal renderer).

The reasoning, in short: the project first built a trustworthy way to measure, then let the measurements decide.

**How it was measured.** P7a's original latency probe (screenshot polling) turned out too coarse to distinguish renderers — each capture took ~20 ms, larger than the signal, and it had a clock-unit bug. P7b replaced it with a continuous ScreenCaptureKit `SCStream` probe that reads each frame's `displayTime`, normalizes both timestamps through one `CMClockMakeHostTimeFromSystemUnits`, and gates results on a startup timebase calibration (which passed with <4 ms offset, so the absolute numbers were trustworthy). Both renderers were then benchmarked 3× each (SwiftTerm supports Metal via `setUseMetal`, wired behind a `renderer` config key for the A/B test).

**What the numbers showed.** CoreGraphics beat SwiftTerm's experimental Metal path on every axis that matters to xtty's latency-first, lean-memory values:

- Faster median key-to-photon latency: ~31 ms vs ~33 ms
- Much tighter tail: p99 ~40 ms vs ~50–120 ms for Metal
- Leaner memory: ~55 MB vs ~62 MB idle

A key insight was that a shared ~16.7 ms `queuePendingDisplay` throttle (one refresh interval) dominates the median for *both* renderers — so the renderer isn't the real latency lever, and switching to Metal would buy nothing while worsening the tail and memory.

The decision is being carried further by the open `retire-metal-renderer` change (proposed, not yet applied), which removes the `renderer` config key and the Metal-toolchain build dependency entirely — SwiftTerm's bundled `.metal` shader gets patched out, so the build needs no Metal toolchain at all. Resurrection, if ever needed, is one patch-hunk revert plus a re-run of the archived P7b methodology. Full write-up: `research/03-analysis/p7-measurement-methodology.md`.


## C2-rep3  (turns=1 err=False subtype=success)

xtty renders with **CoreGraphics** — SwiftTerm's default CG path, not its experimental Metal renderer. The decision was made in P7b (2026-06-29) and later cemented: the open `retire-metal-renderer` change proposes removing the Metal option and the Metal-toolchain build dependency entirely.

**How the decision was reached:** the plan originally deferred a possible Metal renderer to a "P7 gate" — measure first, then decide. P7a (`add-latency-memory-harness`) built the measurement harness, but its screenshot-polling latency probe was too coarse (~20 ms per capture, larger than the signal). P7b (`add-trustworthy-latency-probe`) replaced it with a continuous `SCStream` probe reading each frame's `displayTime`, with a clock-unit fix (normalizing both timestamps through `CMClockMakeHostTimeFromSystemUnits`) and a startup timebase-calibration gate that passed (offset <4 ms), making the absolute numbers trustworthy.

**What the benchmarks showed** (3 runs per renderer):

- **Latency median:** CoreGraphics ~31 ms vs Metal ~33 ms — CG slightly faster.
- **Tail latency:** CG much tighter — p99 ~40 ms vs Metal's ~50–120 ms.
- **Memory:** CG leaner — ~55 MB vs ~62 MB idle (lean memory is a hard product requirement).

So Metal lost on every axis that matters to xtty's latency-first, low-memory values. A key insight was that a shared ~16.7 ms `queuePendingDisplay` throttle (one refresh interval) dominates the median for *both* renderers — meaning the renderer isn't the real latency lever anyway, the throttle is.

**Verdict:** keep CoreGraphics, skip Phase 8 (the planned custom Metal renderer work). Full methodology and results are in `research/03-analysis/p7-measurement-methodology.md` (P7b apply-result addendum), and the retirement rationale in `research/03-analysis/local-macos-vm-ci-reproduction.md` §10b/§11g — dropping Metal also removes the fragile Metal-toolchain download from CI.


## C3-rep1  (turns=6 err=False subtype=success)

**No, SwiftTerm is not forked** — there is no fork repo, no submodule, and no vendored copy of SwiftTerm source in git. It's consumed as a **pinned upstream clone that gets one tracked patch applied locally at bootstrap time** (the "patch-in-repo" model borrowed from Playwright; rationale in `research/03-analysis/swiftterm-fork-vs-patch-strategy.md`).

How it works, exactly:

**What's version-controlled** (only three small things):
- `patches/swiftterm/UPSTREAM_CONFIG.sh` — the pin: `UPSTREAM_URL=https://github.com/migueldeicaza/SwiftTerm.git`, `UPSTREAM_REF=v1.13.0`. The single source of truth for *which* SwiftTerm gets patched.
- `patches/swiftterm/xtty-accessors.diff` — the modification itself. It's **add-only**: it creates one new file, `Sources/SwiftTerm/XttyAccessors.swift`, and touches no existing upstream file. It adds two read-only accessors (`getScrollInvariantCursorLocation` + `scrollbackBase`) that xtty's P4b-2 spatial-blocks feature needs; they must live *inside* SwiftTerm's module because they read `internal` buffer fields.
- `scripts/bootstrap-swiftterm.sh` — the reconstitution script.

**What's not tracked:** the actual SwiftTerm tree lives at `external/SwiftTerm/`, which is in `.gitignore` (line 31). Nothing under it is ever committed — it's build infrastructure, reconstituted on demand.

**The bootstrap flow** (`scripts/bootstrap-swiftterm.sh`, run by `make setup`/auto-triggered by `make build` when inputs change):
1. Clone the upstream into `external/SwiftTerm` if absent.
2. Every run, fetch tags, `checkout v1.13.0` and `git clean -fdq` — restoring a *pristine* pinned tree so the pin can't drift and the patch always applies onto a clean base (the clean also drops the previously-applied patch, since it's an untracked added file).
3. `git apply patches/swiftterm/xtty-accessors.diff`.

**How the build consumes it:** `XttyCore/Package.swift` declares a local-path SPM dependency — `.package(path: "../external/SwiftTerm")` — so SwiftPM builds the patched checkout like any local package. Until the bootstrap runs, that path doesn't resolve and the build fails, which is why it's a documented post-clone step.

Two more notes: to *edit* the modification you change the file in a pristine checkout and regenerate the `.diff` (never commit inside `external/`), and the whole mechanism is explicitly temporary — it's slated for retirement once the two accessors land in an upstream SwiftTerm release (an upstream PR has been prepared but not yet filed). A second, unrelated hunk is also planned for this same patch file by the open `retire-metal-renderer` change (patching out SwiftTerm's bundled `.metal` shader to drop the Metal-toolchain build dependency), but that change is proposed, not yet applied.


## C3-rep2  (turns=6 err=False subtype=success)

**No — SwiftTerm is not forked.** There is no fork repository and no vendored copy of SwiftTerm source in git. Instead, the repo uses a "patch-in-repo" mechanism (modeled on how Playwright patches its browsers): only a *pin*, a *patch file*, and a *bootstrap script* are version-controlled, and the actual SwiftTerm tree is reconstituted locally as a gitignored clone.

Here's exactly how it works:

**What's tracked in git (the whole mechanism, three small files):**
- `patches/swiftterm/UPSTREAM_CONFIG.sh` — the pin: upstream URL `https://github.com/migueldeicaza/SwiftTerm.git` at ref `v1.13.0`. This is the single source of truth for which SwiftTerm gets patched.
- `patches/swiftterm/xtty-accessors.diff` — the sole modification, an **add-only** patch that creates one new file (`Sources/SwiftTerm/XttyAccessors.swift`) inside SwiftTerm's module. It touches no existing SwiftTerm file. It adds two read-only accessors that P4b-2 (spatial blocks / jump-to-prompt) needs but which read module-internal buffer fields: `getScrollInvariantCursorLocation()` (the cursor's trim-invariant absolute row) and `scrollbackBase` (lines trimmed off the top). They must be compiled *inside* SwiftTerm's module, which is why a patch is needed at all.
- `scripts/bootstrap-swiftterm.sh` — the reconstitution script.

**What's not tracked:** `external/SwiftTerm/` is in `.gitignore` (`.gitignore:31`) — nothing under it is ever committed; it's treated as build infrastructure, like a package cache.

**How the dependency is consumed:** `XttyCore/Package.swift:29` declares a plain local-path SPM dependency — `.package(path: "../external/SwiftTerm")` — so both the `XttyCore` package and the app build against the patched local checkout.

**The bootstrap flow** (`make setup`/`make bootstrap`, or the script directly; run once after cloning and after any pin/patch edit):
1. Clone upstream into `external/SwiftTerm` if absent.
2. `fetch --tags`, then force-checkout the pinned `v1.13.0` and `git clean -fdq` — enforced on **every** run, so the checkout can't drift and the patch always applies onto a pristine base.
3. `git apply patches/swiftterm/xtty-accessors.diff`.

Until this runs, the build fails to resolve `../external/SwiftTerm`. CI runs the same script and caches the checkout keyed on the pin + patch hash.

**Why this shape:** a fork repo or submodule was deliberately rejected (rationale in `research/03-analysis/swiftterm-fork-vs-patch-strategy.md`) — the patch is tiny, add-only, and intended to be temporary. An upstream PR containing the accessor file has been prepared, and the stated plan is to retire the entire mechanism once the accessors land in an upstream SwiftTerm release. There's also a proposed (not yet applied) change, `retire-metal-renderer`, that would extend this same patch to strip SwiftTerm's bundled Metal shader, removing the Metal-toolchain build dependency.


## C3-rep3  (turns=6 err=False subtype=success)

**No, SwiftTerm is not forked.** There is no fork repo, no vendored copy of SwiftTerm's source, and no submodule. The repo tracks only three small things — a pin, a patch, and a bootstrap script — and reconstitutes a patched upstream checkout locally. This is the "patch-in-repo" mechanism modeled on how Playwright patches its browsers (chosen in `research/03-analysis/swiftterm-fork-vs-patch-strategy.md`, introduced by the P4b-2 `add-spatial-blocks` change).

**How the dependency is consumed:**

1. **The pin** — `patches/swiftterm/UPSTREAM_CONFIG.sh` is the single source of truth: upstream URL `https://github.com/migueldeicaza/SwiftTerm.git` at ref **`v1.13.0`**.
2. **The checkout** — `scripts/bootstrap-swiftterm.sh` clones that upstream into `external/SwiftTerm`, which is **gitignored** (nothing under it is version-controlled). On every run it fetches tags, checks out the pinned ref, and runs `git clean -fdq` so the tree is pristine and the pin can't drift.
3. **The build wiring** — `XttyCore/Package.swift` consumes it as a local-path SPM dependency: `.package(path: "../external/SwiftTerm")`. Until the bootstrap script has run, the build simply fails to resolve that path (`make setup`/`make build` auto-bootstrap when the tracked inputs change).

**How it is modified:**

4. **The patch** — after pinning, the script runs `git apply patches/swiftterm/xtty-accessors.diff` inside the checkout. The patch is **add-only**: it creates one new file, `Sources/SwiftTerm/XttyAccessors.swift`, and touches no existing SwiftTerm file. It exposes two read-only values that need to compile *inside* SwiftTerm's module because they read internal buffer fields:
   - `getScrollInvariantCursorLocation()` — the cursor's trim-invariant absolute row (`yBase + y + linesTop`), sibling to the already-public `getScrollInvariantLine(row:)`.
   - `scrollbackBase` — `buffer.linesTop`, for reverse-mapping absolute rows to display rows and detecting clear/reset.

   These power the P4b-2 spatial-blocks features (jump-to-prompt, copy-command-output).

Because the patch is applied onto a clean base every run, editing the pin or the diff just means re-running `scripts/bootstrap-swiftterm.sh` (or `make bootstrap`). An upstream PR containing the accessor file has been prepared (not yet filed); once the accessors land in an upstream SwiftTerm release, the whole mechanism is meant to be retired — bump the pin, delete the patch. One related change is currently proposed (`retire-metal-renderer`): it would extend this same patch to strip SwiftTerm's bundled `.metal` shader so the build no longer needs the Metal toolchain — still via the diff, still no fork.


## C4-rep1  (turns=1 err=False subtype=success)

The root cause was a product bug, not a CI environment quirk: **SwiftUI's scene-synthesized default main menu was clobbering xtty's custom main menu**, and the fix was the **`fix-main-menu-clobber`** change (dropping the SwiftUI `@main` App lifecycle for `NSApplicationMain`).

**The mechanism.** xtty assigned its custom menu to `NSApp.mainMenu` once in `applicationDidFinishLaunching`, while running under SwiftUI's `@main` Settings-scene lifecycle. SwiftUI's private `AppDelegate` (the real `NSApp.delegate`) later runs `makeMainMenu` → `AppKitMainMenuItem.updateMainMenu`, an identifier-keyed reconciler whose diff never matches plain `NSMenuItem`s — so it **strips every custom item in place** (mutating the same `NSMenu` object, not swapping the pointer) and replaces them with SwiftUI defaults. This was a **per-launch race**: local bare-metal machines won it, the slower 3-vCPU CI VMs lost it nearly 100% of the time.

**Why it looked like 7 flaky tests.** All 7 failing tests drove the app through Cmd-key menu equivalents (Cmd+D split, Cmd+W, find, paste, truecolor via Cmd+V, focus-typing, churn). When the clobber hit, the menu items **didn't exist to match** — Cmd+D silently no-oped, and Cmd+W fired SwiftUI's *default* Window ▸ Close (bypassing xtty's confirm-close gate), which in the churn test closed the only pane and quit the app. Earlier theories ("Bucket B" keystroke-delivery flakiness, headless-session issues, font/locale gaps) were all refuted by the §15 artifact forensics and a local VM reproduction that matched CI's 34/7/1 result exactly and caught the in-place menu mutation live.

**The fix.** `fix-main-menu-clobber` (archived 2026-07-05) deleted `@main struct XttyApp: App` and added an AppKit `App/main.swift` calling `NSApplicationMain` (SwiftUI kept only for `NSHostingView` views), plus a title-based menu canary and a `windowCount` witness in the state dump. Validated on the ~100%-clobber VM rig (3 runs, all 40/1/1 — the 7 tests flipped green) and confirmed in CI run `28747512367`, where 5 pre-fix menu-dispatch failures flipped; the 2 remaining reds were unrelated pre-existing test/rig fragilities (marker-wrap on the runner's long prompt, and bash-3.2's missing bracketed-paste).

Notably, CI had been correctly reporting a real user-facing bug since its first run — users could genuinely lose the Edit/Terminal menus. Full write-ups: `research/03-analysis/swiftui-mainmenu-clobber-forensics.md` and `research/03-analysis/github-actions-ci-cd.md` §15–§18.


## C4-rep2  (turns=1 err=False subtype=success)

**Root cause:** SwiftUI's scene-synthesized default menu was clobbering xtty's custom main menu. The app assigned `NSApp.mainMenu` once in `applicationDidFinishLaunching`, but under the SwiftUI `@main` lifecycle, SwiftUI's private `AppDelegate` later runs `makeMainMenu` → `AppKitMainMenuItem.updateMainMenu` — an identifier-keyed reconciler whose diff never matches plain `NSMenuItem`s, so it strips every custom item **in place** (same `NSMenu` object mutated, not a pointer swap). Whether this happened was a per-launch race: local bare-metal machines won it, the slower CI VM (3 vCPU, macOS 26.4) lost it nearly 100% of the time.

That's why all 7 failures were Cmd-key/menu-driven tests: the chords are menu-dispatch-only, and the menu items simply didn't exist to match. Cmd+W hit the *default* Window ▸ Close instead (explaining the churn test's clean quit), and some earlier "passes" (Cmd+N, the quake suite) turned out to be vacuous. Earlier theories — the bash deprecation banner (Bucket A), "Cmd keys don't fire on shared VM sessions" (Bucket B), font/locale gaps — were all progressively refuted; the mechanism was pinned down via a local VM reproduction (lume + Tart rigs reproduced CI's exact 34/7/1 result) plus source-level forensics. Notably this was a real user-facing product bug (users could lose the Edit/Terminal menus), not a CI environment quirk — CI had been correctly reporting it since run 1.

**The fix:** the **`fix-main-menu-clobber`** change (archived 2026-07-05). It dropped the SwiftUI App lifecycle entirely in favor of **`NSApplicationMain`** — deleted `@main struct XttyApp: App`, added `App/main.swift` with strong delegate retention (SwiftUI remains only for `NSHostingView` views, following Ghostty's precedent). Merely re-asserting the same menu instance was refuted as a no-op since the clobber mutates the menu in place. The fix also added a title-based `mainMenuTitles` canary and a `windowCount` witness to the DEBUG state dump.

**Confirmation:** validated in the VM rig (3 runs, all 40/1/1 — the 7 menu-dispatch tests flipped green), then CI-confirmed on run `28747512367`. The full story is in `research/03-analysis/swiftui-mainmenu-clobber-forensics.md` and `research/03-analysis/github-actions-ci-cd.md` (§15–§18).


## C4-rep3  (turns=1 err=False subtype=success)

The root cause was a **product bug, not a CI environment problem**: SwiftUI's scene-synthesized default main menu was clobbering xtty's custom menu bar, so the menu items the tests' Cmd-key shortcuts needed simply didn't exist. The fix was the **`fix-main-menu-clobber`** change (archived 2026-07-05), which dropped the SwiftUI `@main` App lifecycle in favor of **`NSApplicationMain`** with an AppKit `App/main.swift`.

The mechanism, as the forensics established it:

- xtty assigned its custom menu once via `NSApp.mainMenu` in `applicationDidFinishLaunching`, while running under the SwiftUI `@main` Settings-scene lifecycle. SwiftUI's *private* `AppDelegate` (the real `NSApp.delegate`) later ran `makeMainMenu` → `AppKitMainMenuItem.updateMainMenu`, an identifier-keyed reconciler that never matches plain `NSMenuItem`s — so it **mutated the same `NSMenu` object in place**, stripping every custom item and replacing them with SwiftUI defaults (including a "Help" menu xtty never creates). It wasn't a pointer swap, which is why simply re-asserting the same menu instance (the first proposed fix) was refuted as a no-op.
- It was a **per-launch race**: local bare-metal machines won it (~100% pass), while the slower CI VM (`macos-26`, and later a 3-vCPU local Tart/lume VM that reproduced CI's exact 34/7/1 result) lost it. Every failing test was one whose Cmd chord relied on menu dispatch — Cmd+W hit the *default* Window ▸ Close instead of xtty's close-with-confirm path, Cmd+D no-oped, etc. Some "passing" tests (Cmd+N, quake) turned out to be vacuous.
- Along the way, several wrong theories were retired: "Bucket B per-keystroke key-equivalent flakiness," the bash deprecation banner (`silence-bash-deprecation` de-noised grids but flipped zero tests), and the prompt-wrap matcher (`harden-focus-typing-assertion` fixed a real but separate fragility).

The fix deleted `@main struct XttyApp: App` and added `App/main.swift` calling `NSApplicationMain` (SwiftUI stays for hosted views), plus a title-based menu canary in the state dump. Result: 3 VM validation runs went `40/1/1` (the 7 menu-dispatch tests flipped green), and CI run `28747512367` confirmed it — the remaining residuals (find-bar marker wrap, multi-line paste on the runner's bash 3.2) are pre-existing test/rig fragilities, not the menu bug.

Full write-ups: `research/03-analysis/swiftui-mainmenu-clobber-forensics.md` and `research/03-analysis/github-actions-ci-cd.md` §15–§18.


## R1-rep1  (turns=9 err=True subtype=error_max_turns)

<no result field>


## R1-rep2  (turns=9 err=True subtype=error_max_turns)

<no result field>


## R1-rep3  (turns=13 err=False subtype=success)

I have to stop short of actually editing files: **this session has no file-modification tools** — no Write, Edit, or Bash (I searched the deferred-tool registry; the only writable surfaces are Obsidian-vault and Jupyter-notebook MCP tools, neither of which can touch the repo). So I can't apply the change here. To make the restart cheap, I did the full groundwork against the real code — here is the complete, ready-to-apply implementation, verified against the current source at every seam.

## Where the change lands

The config seam is exactly where `theme`/`option-as-meta` live, so `cursor-style` follows the established four-file pattern (plus repo-convention artifacts):

**1. `XttyCore/Sources/XttyCore/XttyConfig.swift`** — new enum + field. Raw values are the config tokens (same pattern as `GitReviewLayout`/`RendererBackend`):

```swift
/// Cursor shape for the terminal caret. Raw values are the config-file tokens.
public enum CursorStyle: String, Equatable, Sendable {
    case block, bar, underline
}
```

Add to `XttyConfig`: `public var cursorStyle: CursorStyle`, a defaulted init parameter `cursorStyle: CursorStyle = .block` (keeps every existing call site compiling, same trick as `linkOpener`/`diffContext` at `XttyConfig.swift:111`), and nothing needed in `.default` since the parameter default covers it.

**2. `XttyCore/Sources/XttyCore/XttyConfigLoader.swift`** — in `resolve(from:base:warn:)`, alongside the `theme` block (~line 134):

```swift
if let raw = pairs["cursor-style"] {
    if let value = CursorStyle(rawValue: raw.lowercased()) {
        config.cursorStyle = value
    } else {
        warn("cursor-style: '\(raw)' is not 'block', 'bar', or 'underline'; using \(config.cursorStyle.rawValue)")
    }
}
```

Putting it in `resolve` (not `resolveSet`) makes it an **appearance key**: profiles inherit/override it for free via the existing `resolve(from: pairs, base: baseConfig)` path, and the quake terminal gets base appearance automatically. That matches how `theme` behaves and needs no base-only warning.

**3. `App/TerminalConfigurator.swift`** — in `apply(_:to:)` after the `optionAsMetaKey` line:

```swift
view.getTerminal().setCursorStyle(swiftTermCursorStyle(config.cursorStyle))
```

with the adapter (note the qualification — SwiftTerm has its own `CursorStyle` type, so the App layer must write `XttyCore.CursorStyle`):

```swift
/// Config cursor style → SwiftTerm's. Blinking variants preserve SwiftTerm's
/// default blink behavior; DECSCUSR from apps can still change it at runtime.
private static func swiftTermCursorStyle(_ s: XttyCore.CursorStyle) -> SwiftTerm.CursorStyle {
    switch s {
    case .block: return .blinkBlock
    case .bar: return .blinkBar
    case .underline: return .blinkUnderline
    }
}
```

One thing I could **not** verify in this worktree: `external/SwiftTerm` isn't bootstrapped here (it's the gitignored clone), so confirm at apply time that `Terminal.setCursorStyle(_:)` on the pinned v1.13.0 propagates to the macOS caret view (it's the same path DECSCUSR uses, so it should); if it turns out view-side, the fallback is setting it via `TerminalOptions` at view construction.

**4. `App/TerminalWindowController.swift`** — state dump (`writeStateDump()`, near `"theme"` at line 782): `"cursorStyle": active.profile.config.cursorStyle.rawValue,`. Per the harness rule ("if the harness can't see it, it isn't done"), this needs a `verification-harness` spec delta plus one e2e in the config-applied suite that launches with `cursor-style = bar` and asserts the dump reports `bar` — same shape as the existing config-applied test.

**5. Tests** — `XttyConfigTests.swift`: default is `block`; each of the three values parses; case-insensitivity (`BAR`); invalid value warns and keeps `block`; a profile overriding `cursor-style` inherits everything else; a profile *not* setting it inherits the base's.

**6. `config.example`** — after the `option-as-meta` block:

```
# Cursor shape: "block" (default), "bar", or "underline".
# cursor-style = block
```

## Process note

Per AGENTS.md this should go through OpenSpec (`openspec new change add-cursor-style` or `/opsx:propose`), with a `terminal-configuration` ADDED requirement (mechanism-neutral: the key, the three values, invalid-value fallback, per-profile inheritance) and the `verification-harness` MODIFIED delta for the dump field. One pre-registered interaction: the open `retire-metal-renderer` change also edits `resolve`-adjacent loader code and `config.example`'s renderer block — trivial to rebase, just land them in either order deliberately.

To actually apply this, re-run the request in a session with file-editing tools (a normal interactive/coding session), or say the word and I can orchestrate it via a Workflow if you want it done from here with subagents — that path does have write access, but multi-agent runs need your explicit opt-in.


## R2-rep1  (turns=8 err=False subtype=success)

I could not launch the validation sweep — this session cannot spawn the `xtty-test-validator` agent, and I'm stopping here rather than running the suite inline (which the launcher explicitly forbids). Here's the situation:

**What happened**

1. I invoked `/xtty:validate` with your request forwarded verbatim (all tiers — core, local bare-metal, headless VM, graphics VM). The launcher instructs spawning the `xtty-test-validator` subagent by name and relaying its fixed verdict report.
2. This session's toolset has **no subagent-spawn tool** — I searched the full deferred-tool registry; the only agent-related tools available are the babysitting half (TaskOutput/TaskStop/SendMessage), not the spawning half.
3. The one available fallback — a minimal single-agent Workflow using `agentType: 'xtty-test-validator'` (same agent registry) — was **blocked at the permission gate** ("Review dynamic workflow before running"). This session is non-interactive, so there's no one to approve the review, and retrying the same call would just be re-asking a declined permission.

**What did NOT happen** (reporting per the launcher's protocol)

- No agent was spawned; no tiers ran; no builds, VMs, or clones were touched. There is no artifacts dir, no `ledger.log`, no `REVIEW.md`, and no Definition-stamp check to evaluate — nothing stranded, simply never started.
- I also did not run any `make test-core` / `make test` / Tart commands myself, per the delegation rule in AGENTS.md.

**How to get the sweep you asked for**

Run `/xtty:validate all tiers` from an **interactive** Claude Code session in the xtty repo — there the agent spawn (or the workflow fallback) can be approved, and the launcher's delivery check (`Definition: v4 (2026-07-06)` on the report's first line) and babysitter protocol apply as documented. Note the local bare-metal tier comes with the hands-off warning, and the two VM tiers run serialized, so budget roughly 30–65 minutes based on the three validated v4 sweeps.

If you'd rather I try again in this session with a different mechanism, I'd need either the Agent/Task spawn tool enabled or dynamic workflows pre-approved for this job's permission mode.


## R2-rep2  (turns=9 err=True subtype=error_max_turns)

<no result field>


## R2-rep3  (turns=9 err=False subtype=success)

I have to stop here and report a blocker: **the validation sweep could not be launched from this session** — no tests were run, no VMs were touched.

What happened:

- The `/xtty:validate` launcher requires spawning the `xtty-test-validator` subagent (by design, so the build/VM noise stays out of this session), and forbids me from running any test/build/VM commands inline.
- This session's toolset has **no Agent tool and no Bash tool** — I searched the full deferred-tool registry (Task*, SendMessage, Monitor, RemoteTrigger, etc.); none of them can spawn a local subagent or execute commands.
- The one available orchestration path, the Workflow tool (which resolves agents from the same registry), was declined by the permission layer with "Review dynamic workflow before running" — and this session is non-interactive, so nobody can approve that review. Retrying the same gated call wouldn't change the outcome.

So the request is blocked on the environment, not on the repo or the agent definition. Nothing was validated, and I'm reporting that honestly rather than substituting a degraded inline run that the project rules explicitly prohibit.

How to get the sweep you asked for:

1. **Run `/xtty:validate all tiers` in an interactive Claude Code session** on the machine with the Tart rigs — the Agent tool is available there, and the launcher's delivery check (`Definition: v4 (2026-07-06)` first line) and babysitter protocol apply as documented.
2. Alternatively, re-run this job in a configuration that permits subagent spawning (or pre-approve dynamic workflows), and I can drive it: one `xtty-test-validator` spawn with "all tiers — core, local bare-metal, headless VM, graphics VM" forwarded verbatim, then relay its fixed verdict report and check the definition stamp.

For reference, the expected shape of a clean result (from the repo's living envelope in `packer/README.md` / AGENTS.md): core 235/0/0, local `make test` at envelope modulo the documented churn confirm-close race, and both VM tiers at 40/1/1 with the sole bash-3.2 multi-line-paste residual.


## R3-rep1  (turns=1 err=False subtype=success)

```
fix(app): correct KeybindParser handling of shift+cmd chords

Co-Authored-By: Claude <noreply@anthropic.com>
```

This follows the repo's conventions: Conventional Commits with the `app` scope (the one used for implementation code, including `XttyCore`), and `fix` since it's a bug fix rather than a new feature. If you made the fix entirely by hand without AI assistance, drop the `Co-Authored-By` trailer — AGENTS.md only calls for it on AI-authored commits.

If you want a body line pinning down the symptom (useful since keybind parsing has preset/override subtleties), something like:

```
fix(app): correct KeybindParser handling of shift+cmd chords

Chords combining shift and cmd were tokenized in a way that failed to
match the intended action binding.
```

— adjust the body to the actual mis-parse (e.g. modifier order sensitivity or shift being dropped), since I haven't seen the diff.


## R3-rep2  (turns=1 err=False subtype=success)

Based on the repo's Conventional Commits convention (scopes used: `research`, `design`, `openspec`, `app` — implementation code goes under `app`), I'd use:

```
fix(app): correct KeybindParser handling of shift+cmd chords
```

If you want a body explaining the defect (worth it if the mis-parse was subtle), something like:

```
fix(app): correct KeybindParser handling of shift+cmd chords

Chords combining shift and cmd were mis-parsed, so keybinds using
both modifiers resolved to the wrong action (or none).
```

Two notes:

- I'd tailor the body's second line to what the actual mis-parse was (e.g. shift silently dropped, modifier order-sensitive, shifted key not normalized) — you know which; a body that names the real failure mode is what makes it useful later.
- Since you authored the fix yourself, the `Co-Authored-By` AI trailer the conventions mention doesn't apply — only add it if Claude wrote the code.


## R3-rep3  (turns=1 err=False subtype=success)

Based on the repo's conventions (Conventional Commits; scopes used so far are `research`, `design`, `openspec`, `app`, and implementation fixes go under the relevant code scope):

```
fix(app): correct KeybindParser handling of shift+cmd chords
```

Rationale: `fix` is the right type for a bug fix (the project has used `feat`/`test`/`chore`/`docs` so far, and Conventional Commits reserves `fix` for exactly this), and `app` is the established implementation scope. The subject names the component and the actual defect rather than a vague "fix parsing bug."

One note: AGENTS.md says to end commit messages with a `Co-Authored-By` trailer **when authored with an AI**. Since you wrote this fix yourself, I left it off. If Claude helped author the change, append:

```
Co-Authored-By: Claude <noreply@anthropic.com>
```


## R4-rep1  (turns=1 err=False subtype=success)

According to this repo's process (AGENTS.md → "How to work here"), a settled investigation with measurements must be **captured into `research/` and reconciled into the trackers before moving on** — durable findings don't get to live only in the conversation. Concretely:

1. **Write a research doc** in the right subfolder (`research/03-analysis/` for an investigation like this; `02-internals/` if it's really about how a system works), following the doc conventions: a **Provenance** note (date + how it was produced), a **Sources** list, and ✅/❌/❓ markers on fact-checked claims.

2. **Meet the capture-depth bar** — this applies specifically because your finding has *measured claims and retired theories*. The doc must carry:
   - the **mechanism/internals** with the evidence, not just the conclusion;
   - **reproducible probes** — exact commands, what each proves *and cannot prove*, including instruments that didn't work;
   - an **investigation record / fates table** — each retired theory marked ❌ next to the experiment that killed it, so dead theories can't respawn;
   - **re-verify-by-effect** instructions — how a future reader re-checks the headline claim;
   - a distilled **reusable guideline** if the finding generalizes;
   - pointers to the **evidence artifacts** (e.g. the `.xcresult` bundles or VM logs).

   The exemplar to match is `research/03-analysis/local-network-privacy-forensics.md`.

3. **Index and reconcile the trackers** in the same session: add the doc to `research/README.md`, update **Current status** in AGENTS.md, and advance the milestone state in `research/04-design/02-milestones.md` if relevant — then **verify against disk** (`openspec list`, `ls openspec/changes/archive/`, `ls openspec/specs/`) and fix any tracker that disagrees with reality.

4. **Keep the why/decision split**: the mechanism and landscape go in `research/`; if the findings imply an actionable change (a fix, a harness delta), that belongs in an **OpenSpec change** (`/opsx:propose`), not in the research doc.

The whole checklist is automated as the committed **`/xtty:capture-research`** command (backed by the `xtty-capture-research` skill), which walks place-and-index → reconcile → verify-against-disk. That's the intended entry point here — say the word and I'll run it for these findings.


## R4-rep2  (turns=1 err=False subtype=success)

Per AGENTS.md ("Write up research in `research/` when it's done" + the capture-depth bar), a settled investigation with measurements must be **captured as a research doc and the trackers reconciled before moving on** — and this repo has a dedicated workflow for exactly this: the **`/xtty:capture-research`** command (backed by the `xtty-capture-research` skill), which walks the whole checklist. Concretely, what's required:

**1. Write the research doc** in the right subfolder (`research/03-analysis/` for an investigation like this), following the doc conventions:
- **Provenance** note (date + how it was produced) and a **Sources** list, with ✅/❌/❓ on fact-checked claims.
- Because this capture has **measured claims and retired theories**, the full depth bar applies: (1) the **mechanism** with its evidence, not just the conclusion; (2) **reproducible probes** — exact commands, what each proves *and cannot prove*, including instruments that didn't work; (3) an **investigation record** with each retired theory marked ❌ next to the experiment that killed it (a fates table), so dead theories can't respawn; (4) **re-verify by effect** — how a future reader re-checks the headline claim; (5) a distilled numbered **guideline** if the finding generalizes; (6) pointers to the **evidence artifacts**. The exemplar is `research/03-analysis/local-network-privacy-forensics.md`.

**2. Index it** — add a line to `research/README.md`.

**3. Reconcile the trackers in the same session:** update **AGENTS.md → Current status**, the milestone state in `research/04-design/02-milestones.md` if it moved, and any related research doc whose findings this supersedes (plus its README line).

**4. Verify against disk:** `openspec list` must match the "Current open changes" list, `ls openspec/changes/archive/` must match what's marked archived, `ls openspec/specs/` must match the established-specs list — fix any tracker that disagrees with reality.

**5. Keep the split clean:** the *why/mechanism* stays in `research/`; if the findings imply action (a fix, a harness change), the *decision* belongs in an OpenSpec change — proposed via `/opsx:propose`, not implemented straight from the chat. That's the pattern the recent CI forensics followed (e.g. §15 root-cause → the `fix-main-menu-clobber` change).

If you'd like, I can run `/xtty:capture-research` now to do the capture and reconciliation — just say the word (and tell me where the investigation's evidence artifacts live if they're outside the repo).


## R4-rep3  (turns=1 err=False subtype=success)

According to `AGENTS.md` ("Write up research in `research/` when it's done" plus the capture-depth rule), settled findings like this must be captured **now, before moving on** — mid-build is explicitly fine. Concretely:

1. **Write a research doc**, almost certainly under `research/03-analysis/` (that's where CI/race forensics live — e.g. `local-macos-vm-ci-reproduction.md`, `swiftui-mainmenu-clobber-forensics.md`). It needs the standard conventions: a **Provenance** note (date + how it was produced), a **Sources** list, and ✅/❌/❓ markers on fact-checked claims.

2. **Meet the capture-depth bar.** Because this investigation has *measured claims and retired theories*, the doc must carry all six elements, not just the conclusion:
   - the **mechanism** — how the race actually works, with the evidence;
   - **reproducible probes** — exact commands, what each proves *and cannot prove*, including the instruments that didn't work;
   - an **investigation record / fates table** — each retired theory marked ❌ next to the experiment that killed it, so it can't respawn;
   - **re-verify-by-effect** — how a future reader re-checks the headline claim (never a read-back check);
   - a distilled **reusable guideline** if the finding generalizes beyond this repo;
   - pointers to the **evidence artifacts** (this project's convention is `~/Downloads/xtty-vm-poc/artifacts/` for VM/CI evidence bundles).

3. **Index and reconcile the trackers**: add the doc to `research/README.md`, and update AGENTS.md's **Current status** (and `research/04-design/02-milestones.md` if the milestone state moved), then verify against disk (`openspec list`, archive dir, specs dir).

4. **Keep the why/what split**: the research doc records the *why*; if the root cause implies a fix or process change, the actionable *decision* goes into an OpenSpec change (`/opsx:propose`), not the research doc.

The repo has purpose-built tooling for steps 1–3: the **`/xtty:capture-research`** command (backed by the `xtty-capture-research` skill) walks the whole place-doc → index → reconcile-trackers → verify-against-disk checklist.

If you want, I can run `/xtty:capture-research` now — just tell me (or point me at) where the findings/evidence from the investigation live, since they're not in this conversation.


## T1-rep1  (turns=4 err=False subtype=success)

Short answer: no — and in fact `-retry-tests-on-failure` is **already in the CI job** (`.github/workflows/ci.yml:85`, from `add-ci-pipeline`'s "retry-tolerant" design), and this repo's own forensics record is a case study in why leaning on it further is the wrong direction.

What the record shows:

1. **The "flakes" were a real product bug, not test noise.** The 7 recurring CI failures turned out to be the SwiftUI main-menu clobber — a per-launch race where users could lose the Edit/Terminal menus. CI had been correctly reporting a shipping defect since run 1. Retries are a bet that red = noise; here red = signal.

2. **Retries were measured masking it.** In the Tart VM reproduction (`research/03-analysis/local-macos-vm-ci-reproduction.md` §9), two runs of the identical VM and binary diverged: run 1 went 36/5/1 because two genuinely-broken Cmd+D split tests *flaky-passed on a race-winning retry*; run 2 went 34/7/1. That's the exact failure mode you'd be buying more of. The doc draws the conclusion explicitly: because a retry-tolerant suite masks the race, the fix had to eliminate it (`NSApplicationMain`), not tolerate it.

3. **The bug is now fixed and the residuals are deterministic.** `fix-main-menu-clobber` landed and CI run `28747512367` confirmed the menu-dispatch failures flipped green. The two remaining reds (find-bar marker-wrap on the runner's long prompt; multi-line paste on the runner's bash 3.2, which lacks bracketed paste) are deterministic environment mismatches — retries can't green them, only the planned test/rig fixes can.

4. **CI is already structured so flakes don't block you.** `test-core` is the required gate; `build-and-test` is deliberately non-blocking. There's no merge pain that retries would relieve — the only thing more retry-tolerance changes is how much signal you throw away.

5. **The project has pre-registered the opposite policy.** The planned `verification-harness` truthing delta (research §15) and the `xtty-test-validator` guardrails both specify **no in-test retries**, precisely because of the above.

So rather than adding retries, I'd suggest the opposite follow-up: fold *removal* of the existing `-retry-tests-on-failure` flag into the harness-truthing successor change (it's `ci.yml`, so it interacts with the still-open `add-ci-pipeline` — worth pre-registering, per the repo's convention). If a genuinely nondeterministic test shows up post-menu-fix, the established pattern here is to root-cause it (as with `harden-churn-shell-readiness`'s computed-marker gate), not rerun it.


## T1-rep2  (turns=3 err=False subtype=success)

No — and this repo already learned that lesson the hard way. In fact, `-retry-tests-on-failure` is **already on the CI job** (`.github/workflows/ci.yml:85`), and the project's own evidence says it should eventually be *removed*, not leaned on.

Three reasons, all from this project's documented history:

1. **Retries here have already masked a real product bug, measured live.** The Tart VM rig (§9 of `research/03-analysis/local-macos-vm-ci-reproduction.md`) ran the identical VM + binary twice: run 1 came back 36/5/1 because the two Cmd+D split tests flaky-passed on a race-winning retry; run 2 was 34/7/1. Those tests were genuinely broken by the SwiftUI menu-clobber — a user-facing bug where people could lose the Edit/Terminal menus — and the retry made the suite report them green. That's exactly why the `fix-main-menu-clobber` decision was recorded as "eliminate the race (`NSApplicationMain`), not add test retries." CI had been correctly reporting that bug since run 1; retries were the thing threatening to hide it.

2. **The current CI reds aren't random flakes retries can fix.** Post-menu-fix, the residuals are deterministic environment mismatches: the multi-line-paste test fails because the runner/rig shell is bash 3.2 (no bracketed paste), and the find-bar case is the long-hostname marker-wrap. A deterministic failure fails every retry attempt — you just pay extra wall-clock on an already-slow macOS runner. Each of these is already classified in the expected-difference matrix in `packer/README.md`, which is the honest version of "we know about this red."

3. **It contradicts the project's stated harness policy.** The verification-harness truthing plan explicitly pre-registered "no in-test retries," and the `xtty-test-validator` agent's guardrails say the same — because a suite whose counts change between runs of the same binary can't be compared against the acceptance envelope. And the `build-and-test` job is deliberately non-blocking, so flakes don't gate merges today anyway; there's nothing to "unblock" by hiding them.

What the project does instead when a flake appears: reproduce it in the VM rig (which reproduces the per-launch race class that bare metal doesn't), root-cause it, and either fix the product (menu clobber), fix the test (`harden-focus-typing-assertion`, the pending `harden-churn-shell-readiness` computed-marker gate), or bucket it in the envelope. That pipeline has retired every "flake" so far by finding a real cause.

So my recommendation is the opposite of the proposal: keep the flag out of any new jobs, and consider dropping the existing `-retry-tests-on-failure` from `ci.yml` as part of the harness-truthing successor change — now that the menu fix landed, a clean signal is worth more than a green badge. Happy to draft that as an OpenSpec change if you want to go that way.


## T1-rep3  (turns=3 err=False subtype=success)

**No — and this project has already run the experiment that proves why.** In fact, `-retry-tests-on-failure` is *already* in the CI job (`.github/workflows/ci.yml:85`, the "retry-tolerant" build-and-test step), and the documented lesson from this repo's own forensics is that it should come **out**, not be leaned on harder.

The evidence, all from this repo's history:

1. **The "flakes" were a real product bug that retries would have buried.** The 7 recurring CI XCUITest failures turned out to be SwiftUI's default menu clobbering xtty's custom main menu — a per-launch race that real users could hit (losing the Edit/Terminal menus). CI was *correctly* reporting it since run 1. That became `fix-main-menu-clobber` (shipped and archived 2026-07-05).

2. **Retries were caught masking that exact race, live.** The Tart VM rig ran the identical binary twice: run 1 came back 36/5/1 because the two Cmd+D split tests *flaky-passed on a race-winning retry*; run 2 was 34/7/1. Run 1 "passed" two genuinely broken tests. That measurement (`research/03-analysis/local-macos-vm-ci-reproduction.md` §9) is precisely why the decision was to **eliminate** the race with `NSApplicationMain` rather than add retry tolerance — and why the `xtty-test-validator` agent has a hard guardrail: *"No retry flags, ever — not `-retry-tests-on-failure`… Retry tolerance masks the exact per-launch races this rig exists to catch."*

3. **The current residual failures aren't flaky, so retries wouldn't even green them.** Post-fix CI (run `28747512367`) shows the menu-dispatch failures gone; what's left is deterministic rig/env sensitivity — the find-bar marker-wrap on the runner's ~72-char prompt, and multi-line-paste executing on the runner's bash 3.2 (no bracketed paste). Retrying a deterministic failure just burns runner minutes and re-fails.

4. **The planned direction is the opposite.** The pre-registered `verification-harness` truthing follow-up explicitly includes "no in-test retries" — the flag on line 85 is a pre-fix relic slated for removal in that successor change.

The general shape of the lesson here: on this rig, "flaky" has repeatedly decoded to either a real per-launch product race or a deterministic environment mismatch — never noise that a rerun legitimately absorbs. If a specific test starts failing intermittently, the productive move is the one this repo keeps taking: pull the `.xcresult`, bucket it against the expected-difference matrix in `packer/README.md`, and fix the cause (or the assertion) — e.g. the churn test's confirm-close race already has a settled fix design waiting in `harden-churn-shell-readiness`.

So my recommendation: don't add more retry tolerance — and when the harness-truthing change lands, drop the existing `-retry-tests-on-failure` flag with it.


## T2-rep1  (turns=1 err=False subtype=success)

No — that exact approach was tested and refuted during the VM forensics, and the real fix has already shipped.

Re-asserting `NSApp.mainMenu` doesn't work because of *how* the clobber happens. The lume VM PoC (captured in `research/03-analysis/local-macos-vm-ci-reproduction.md` §8) measured `mainMenuPtr == builtMenuPtr` — SwiftUI's reconciler **mutates the items of the same `NSMenu` object in place** rather than swapping in a different menu. Concretely, SwiftUI's private `AppDelegate` → `makeMainMenu` → `AppKitMainMenuItem.updateMainMenu` runs an identifier-keyed diff that never matches plain `NSMenuItem`s, so it strips every custom item from the menu xtty built (and injects defaults like a "Help" menu xtty never creates). Re-assigning `NSApp.mainMenu = builtMenu` assigns the same, already-gutted object — a no-op. This was the original "Stage A" idea in the fix plan, and it's explicitly marked refuted (§15e).

Two related half-measures were also refuted live with probe apps: `.commandsRemoved()` and rebuilding the menu on a notification.

The fix that actually landed (in the archived `fix-main-menu-clobber` change) was dropping the SwiftUI `@main` App lifecycle entirely in favor of **`NSApplicationMain`** — delete `@main struct XttyApp: App`, add `App/main.swift` with a strongly-retained `AppDelegate`. That removes SwiftUI's private delegate and its menu reconciler from the picture altogether (SwiftUI stays for views via `NSHostingView`). It was validated on the ~100%-repro VM rig (3 runs, all 40/1/1, the 7 menu-dispatch tests flipped green) and confirmed in CI run `28747512367`. Ghostty made the same migration in 2023 for the same reason.

So if you're seeing menu weirdness now, it shouldn't be this bug resurfacing — worth checking whether the `@main` struct crept back in, rather than adding a re-assert.


## T2-rep2  (turns=1 err=False subtype=success)

No — that exact approach was tested and refuted, and the real fix has already shipped.

Re-asserting `NSApp.mainMenu` was the original "Stage A" plan (§15e), but the VM proof-of-concept killed it: the clobber is **in-place item mutation of the same `NSMenu` object**, not a pointer swap. The VM instrumentation measured `mainMenuPtr == builtMenuPtr` — SwiftUI's private `AppDelegate` (the real `NSApp.delegate`) runs `updateMainMenu`, an identifier-keyed reconciler whose diff never matches plain `NSMenuItem`s, so it strips xtty's custom items out of the very menu object xtty built (even injecting a "Help" menu xtty never creates). Re-assigning that same instance is a no-op — you'd be re-installing the already-mutated menu.

The stronger variants were also refuted live with probe apps: `.commandsRemoved()` doesn't stop the reconciler, and rebuilding a fresh menu on a notification doesn't either. The only fix confirmed (by construction — both mutation call sites die with `SwiftUI.AppDelegate`) was dropping the SwiftUI `@main` lifecycle for **`NSApplicationMain`**: delete the `@main struct XttyApp`, add `App/main.swift` with a strongly-retained `AppDelegate`. That's Ghostty's 2023 migration, and SwiftUI stays for views via `NSHostingView`.

That fix already landed as **`fix-main-menu-clobber`**, archived 2026-07-05: validated 3× at 40/1/1 on the ~100%-clobber VM rig (the 7 menu-dispatch tests flipped green), and CI-confirmed on run `28747512367`. Full mechanism and refutation record: `research/03-analysis/swiftui-mainmenu-clobber-forensics.md`.


## T2-rep3  (turns=1 err=False subtype=success)

No — that exact approach was tried (on paper) and refuted by measurement, and the real fix has already shipped.

The reason re-assertion can't work is the mechanism the VM proof-of-concept uncovered (`research/03-analysis/local-macos-vm-ci-reproduction.md` §8): SwiftUI's clobber is **in-place item mutation of the same `NSMenu` object, not a pointer swap**. The instrumented run measured `mainMenuPtr == builtMenuPtr` — the menu xtty built is still installed as `NSApp.mainMenu`, but SwiftUI's private `AppDelegate → makeMainMenu → AppKitMainMenuItem.updateMainMenu` reconciler has rewritten its *items* (stripping every plain `NSMenuItem`, even adding a "Help" menu xtty never created). So assigning the same instance again is a no-op — AppKit sees no change. That's exactly why the original "Stage A: re-assert same instance" plan was marked REFUTED in the §15e follow-up.

Rebuilding a *fresh* menu and assigning it doesn't survive either — rebuild-on-notification was refuted live with probe apps (the reconciler runs again and strips it again), as was `.commandsRemoved()`. See `research/03-analysis/swiftui-mainmenu-clobber-forensics.md`.

The fix that actually works — and is already implemented, VM-validated (3× `40/1/1` on the ~100%-clobber rig), CI-confirmed (run `28747512367`), and archived as `fix-main-menu-clobber` — was to **drop the SwiftUI `@main` App lifecycle entirely**: delete `@main struct XttyApp: App`, add `App/main.swift` calling `NSApplicationMain` with a strongly-retained `AppDelegate`. With no SwiftUI scene, its menu reconciler never runs, so there's no race to lose. SwiftUI remains in use for views via `NSHostingView`. A title-based `mainMenuTitles` canary in the DEBUG state dump now watches for regressions (observe-never-repair).

So if you're seeing missing menus on a current build, that would be a new/different issue worth investigating rather than the known clobber — but as a fix proposal, re-assertion is a dead end that the forensics specifically ruled out.


## T3-rep1  (turns=3 err=False subtype=success)

No — I'd strongly recommend against this. What you're describing is exactly the v3 failure mode that stranded three sweeps, and the v4 ban on `run_in_background` was the fix. Reverting it would relocate, not remove, the clunkiness.

The core fact, measured in the forensics capture (`research/03-analysis/claude-code-subagent-execution-forensics.md`): **the "notification arrives" premise is false for subagents.** The Bash tool's promise that a background task "re-invokes you when it exits" holds only for the main conversation. A subagent that ends its turn is closed forever — no background child exiting, no watcher, no notification ever re-invoked it (zero notifications delivered across every stranded transcript). So "launch with `run_in_background` and end the turn until the notification arrives" means the agent parks mid-run and the notification never comes. That happened three times on this exact workflow, which is why the agent definition (`.claude/agents/xtty-test-validator.md:17`) now says: *"`run_in_background` is banned in this workflow. Never set it, on any call, for any reason."*

Two supporting points from the record:

- The waits only *look* clunky; they're the survival mechanic. The foreground `while <check>; do sleep 30; done` loop (reissued on exit-143 timeout) is harness-permitted, was proven in a 43-minute two-VM control run, and the agent may interleave short useful work between wait reissues — so the time isn't wasted, and the noise stays inside the subagent either way. That context isolation is the agent's whole purpose; the caller's view is already clean (one ~2k-token report).
- The fix was validated by effect, not just design: post-v4, three consecutive Sonnet sweeps (14 / 65 / 30 min) completed with zero strands and zero `run_in_background` uses. Even the theories adjacent to your suggestion were explicitly refuted in the fates table — e.g. a mid-turn "completed" notification does occur sometimes, but only when a `nohup` wrapper exits early, which is precisely the false signal that taught run 2 to park.

If the goal is to make the waits *feel* less clunky, the safe levers are within the current shape: tune the poll cadence (the 30–60s tail interval), or lean more on the sanctioned interleaving (REVIEW.md updates, prereq probes between wait reissues). But the launch-foreground-and-wait recipe itself needs to stay. I haven't changed anything.


## T3-rep2  (turns=3 err=False subtype=success)

I'd recommend against this — it's not a simplification, it's the exact trap that v4 was built to remove, and the failure was measured, not theoretical.

The problem: **the "notification arrives" promise is false for subagents.** `run_in_background`'s docs say a background task re-invokes you when it exits, and that's true for the main conversation — but a subagent that ends its turn is closed forever. Nothing re-invokes it: no background-task completion, no watcher, no notification. This was established forensically after three stranded Sonnet sweeps on this exact workflow (a 7-agent forensic workflow traced it to this affordance failure, not model disobedience — zero notifications were ever delivered to the agent). It's captured in `research/03-analysis/claude-code-subagent-execution-forensics.md`, in the agent definition itself (`.claude/agents/xtty-test-validator.md:10-17`, the "turn-alive invariant"), and in the archived `add-test-validation-agent` v4 hardening. The `test-validation` spec merged into `openspec/specs/` also encodes the continuous-execution requirement, so the change you're describing would need a spec delta, not just an agent-file edit.

So "launch with `run_in_background` and end the turn until the notification arrives" produces a parked agent mid-run — the caller gets no report, the VMs keep running unattended, and someone has to reconstruct the sweep from `ledger.log` and resume via SendMessage (the babysitter protocol exists precisely because this happened three times).

Also worth noting the current waits are less clunky than they look:

- The launch/wait split is deliberate: a per-call timeout only ever kills a *wait loop*, never the workload, and a timed-out wait is just reissued. This shape completed a 43-minute ×2 VM sweep with two survived per-call timeouts and no incident.
- The fix was validated by effect: three consecutive clean sweeps post-v4 (zero strands, zero `run_in_background`), versus three strands before it.
- The noise cost is already paid — the whole point of the agent is that the polling stays inside its context; the caller only sees the ~2k-token report.

If the goal is genuinely tidier waiting rather than turn-ending, there is one already-sanctioned alternative: the agent file names the **Monitor** tool as the fallback for the same wait condition (`xtty-test-validator.md:76`) — that could replace the `while kill -0 … sleep 30` shell loops while keeping the agent inside a tool call. But that's a cosmetic swap; ending the turn is the one thing the agent can never do mid-sweep. My recommendation is to leave the v4 pattern as is.


## T3-rep3  (turns=3 err=False subtype=success)

I wouldn't make that change — it's the exact failure mode the agent's v4 hardening exists to prevent, established with measured evidence, not just caution.

The core problem: **the "re-invokes you when it exits" promise of `run_in_background` is false for subagents.** It's true in the main conversation, but a subagent that stops calling tools has its task closed forever — no background task exit, no watcher, no notification ever re-invokes it. This isn't theoretical; it was measured during the `add-test-validation-agent` v4 forensics (`research/03-analysis/claude-code-subagent-execution-forensics.md`): three sweeps stranded exactly this way, with zero notifications ever delivered across every stranded transcript. Each failed run authored a correct wait loop, then set `run_in_background: true` on it and ended its turn — converting the survival mechanic into an orphan watcher. That's why the agent definition (`.claude/agents/xtty-test-validator.md:17`) bans `run_in_background` outright and defines waiting as "a tool call you are inside of, never a state you enter by ending your turn."

Two more findings from that investigation cut against the proposal:

- The fates table also killed the softer variants: a "fused atomic launch+wait" was red-teamed out pre-ship (the 600s per-call timeout would SIGTERM the workload), and the control run that succeeded used exactly the unfused foreground launch-then-wait shape that looks "clunky." The clunkiness is the proven-working design.
- The notifications a subagent *does* occasionally see mid-turn are noise — a `nohup` wrapper exiting early can emit a real "completed" signal while `xcodebuild` is still running. Run 2 of the stranded sweeps correctly diagnosed that false signal and still parked on it.

The validation by effect: post-v4, three consecutive Sonnet sweeps ran clean (zero strands, zero `run_in_background`), including a 65-minute all-tiers run. Reverting to background-and-park would reintroduce the strand rate that motivated the whole hardening.

If the waits feel clunky from the *caller's* side, the isolation is already doing its job — the polling noise stays inside the agent and you only see the ~2k-token report. If a wait loop is ever actually blocked by the harness, the definition's sanctioned fallback is the Monitor tool with the same condition, not ending the turn. So my recommendation is to leave the agent as-is.


## T4-rep1  (turns=3 err=False subtype=success)

No — that's the "obvious fix" the §2 probe specifically killed. The empirical foreground-pgid timeline in `research/03-analysis/confirm-close-shell-readiness.md` shows three reasons a `hasForegroundJob == false` wait can't work as the pre-close readiness gate:

1. **It's true before startup even begins.** The forked shell is the session leader, so `tcgetpgrp` returns the shell's pgid within 3–30 ms of spawn — *before* `~/.zshrc` runs. A `hasForegroundJob == false` read passes immediately on a shell that hasn't started sourcing rc files yet, which is exactly the state the flake comes from.

2. **The dump sampler can't see the busy episodes.** Startup children (git, nvm, node) grab the tty in 15–57 ms bursts with shell-owned gaps up to ~740 ms between them, and the last flicker lands as late as ~2 s under load. The 150 ms state-dump sampler is structurally blind to those bursts, so even a "k consecutive clean reads" variant degenerates into a disguised, load-scaled sleep.

3. **It's inert on CI.** Under CI's bash there is zero flicker — the wait passes instantly and gates nothing.

The decided fix (already in the open `harden-churn-shell-readiness` change, `research` §5) is the **computed-marker execution roundtrip**: after the pane/tab-count wait, type `echo $((41000+i))` and wait for the computed output token (`41001`, which never appears in the typed input line) in the grid before sending ⌘W, failing fast without ⌘W on timeout. A match proves the shell actually read and executed a command — an execution *event* strictly after the last rc flicker, rather than a flappy instantaneous state — and it's shell-agnostic (works under CI bash with no OSC 133). Plus the companion `.common`-modes fix for the DEBUG dump timer so dumps stay live if the modal ever does appear.

One nuance worth keeping: a *single* `hasForegroundJob == false` read **post-marker** is meaningful (unlike pre-marker), and the doc pre-registers exactly that as the escalation if a residual flake ever shows up in the post-marker precmd window — but it's deliberately not shipped speculatively. So the pgid signal isn't useless, it's just wrong as the primary gate.


## T4-rep2  (turns=2 err=False subtype=success)

Not quite — that specific approach (`hasForegroundJob`-based waiting) was empirically tested and refuted in the §16 investigation, and the settled design is already captured in the open `harden-churn-shell-readiness` change (proposed 2026-07-03, 0/11 tasks). Here's why the wait doesn't work, per `research/03-analysis/confirm-close-shell-readiness.md`:

1. **The signal is true-looking before startup even begins.** The forked shell is the session leader, so `tcgetpgrp` returns the shell's pgid within 3–30 ms of spawn — *before* `~/.zshrc` runs. A `hasForegroundJob == false` read therefore passes immediately, right in the middle of the danger window it's supposed to guard.
2. **The startup children are invisible to the sampler.** The `.zshrc` child bursts that actually trip confirm-close last 15–57 ms, while the DEBUG state dump samples at ~150 ms. Polling the dump for `hasForegroundJob` would race right past them (and on CI bash there's zero flicker at all).

The decided fix (what the open change implements) is instead:

- **A computed-marker execution roundtrip** in both churn loops: type a unique per-iteration marker command, wait for its computed output in the grid dump before closing. A completed execution roundtrip *proves* the shell is past startup — it's the echo-proof upgrade of the `SPLITMARK`/`QUAKEMARK` pattern the split and quake tests already use (which is why those never flake). Test-only, no product code.
- **The companion dump-timer fix**: register the DEBUG dump timer in RunLoop `.common` modes, so dumps stay live while the confirm-close modal is up (default-mode registration froze them, which produced the stale-dump artifact that confused earlier diagnosis).

One nuance worth knowing: a `hasForegroundJob` wait isn't useless forever — the doc pre-registers it as an escalation step *after* the marker (a single post-marker `hasForegroundJob == false` read is meaningful, unlike pre-marker), but only if a residual flake is ever observed in the post-marker precmd window. It's deliberately not shipped speculatively.

So the path forward is to apply `harden-churn-shell-readiness` as designed rather than adding the foreground-job wait. Want me to start `/opsx:apply` on it?


## T4-rep3  (turns=3 err=False subtype=success)

No — that's the "obvious fix" the §16 investigation specifically tested and killed. A dedicated pty probe replicating xtty's exact launch topology (`research/03-analysis/confirm-close-shell-readiness.md` §2) refuted `hasForegroundJob`-based waits on three grounds:

1. **It reads false before startup even begins.** The forked shell is the session leader, so `tcgetpgrp` returns the shell's pgid within 3–30 ms of spawn — *before* `~/.zshrc` runs. A `hasForegroundJob == false` read proves nothing about readiness.
2. **The busy periods are invisible to the sampler.** Startup children (git, nvm, node) grab the tty in 15–57 ms bursts with shell-owned gaps up to ~740 ms between them, and the last flicker lands as late as ~2 s under load. The 150 ms state-dump sampler is structurally blind to those bursts, so even a "k consecutive clean reads" variant degenerates into a disguised, load-scaled sleep — you'd sample false in a gap, send ⌘W, and still hit the modal.
3. **Under CI bash it's a no-op** — zero flicker, `fg == shellPid` from <35 ms, so the wait passes instantly and guards nothing there.

The decided fix (already proposed as the open `harden-churn-shell-readiness` change, 0/11 tasks) is different in kind — an execution **event** rather than a flappy state:

- **Computed-marker roundtrip in both churn loops** (test-only): after the pane/tab-count wait, type `echo $((41000+i))` and wait for the computed result (`41001`) in the grid before ⌘W, with a 15 s timeout that fails fast (never sends ⌘W on timeout). The output token can't appear in the echoed input line, so a match proves the shell actually read and executed a command — strictly later than the last rc-sourcing flicker, and shell-agnostic (bash/zsh, no OSC 133 dependency).
- **Companion:** move the DEBUG dump timer to `RunLoop` `.common` modes, since the confirm-close `NSAlert`'s modal run loop currently freezes the dumps — the thing that made these failures so hard to read.

One nuance worth keeping in mind: a *single* `hasForegroundJob == false` check **post-marker** is meaningful (the doc pre-plans it as an escalation if a residual flake ever shows up in the precmd window) — it's only worthless as the primary pre-close gate. Also noted in the doc: `confirm-close = false` for the test was rejected too, since it removes the very branch the leak net exercises.

So: skip the pgid wait, apply `harden-churn-shell-readiness` as designed. Want me to start applying it?
