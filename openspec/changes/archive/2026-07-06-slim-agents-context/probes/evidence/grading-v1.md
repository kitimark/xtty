# Grading sheet — v1


## C1-rep1  (turns=2 err=False subtype=success)

The acceptance envelope for xtty's VM test rig is **40 pass / 1 fail / 1 skip out of 42 XCUITests**, and its authoritative home is **`packer/README.md` → the "Acceptance (measured — post `fix-main-menu-clobber`)" section** (packer/README.md:225). AGENTS.md and the test-validator agent both defer to that file for the numbers rather than hardcoding them.

Details from the authoritative section:

- **Measured 2026-07-05** after the `fix-main-menu-clobber` change, validated across 3 identical runs (headless ×2 + graphics). The 7 menu-dispatch tests that were red pre-fix now pass, and graphics and headless arms match exactly.
- **The sole expected residual (the 1 fail)** is `testMultiLinePasteIsNotAutoExecuted`, and it is explicitly *not* a product bug: the image's login shell is macOS stock **bash 3.2.57**, whose readline lacks `enable-bracketed-paste`, so a pasted newline executes immediately. zsh and bash 5.1+ users are unaffected. Until a future harness change guards the test on no-bracketed-paste shells, it's the image's one known-benign red.
- **Acceptance means matching this measured envelope, not all-green.** A regression is defined as any menu-dispatch test going red again, or any *second* non-paste failure.
- One forward-looking note: once `retire-metal-renderer` deletes the passing Metal e2e test, the total drops to 41 and the envelope will read **39/1/1 of 41**.


## C1-rep2  (turns=1 err=False subtype=success)

The VM rig's acceptance envelope is **40 pass / 1 fail / 1 skip out of 42 XCUITests**, and the sole expected residual is a **benign multi-line paste failure caused by the rig's bash 3.2 guest shell**, which has no bracketed-paste support — it's a rig limitation, not a product bug.

The authoritative home for the envelope is **`packer/README.md`**, specifically its **Acceptance** section (which also carries the expected-difference matrix and the VM runtime workflow). The snapshot in `AGENTS.md` just mirrors it; per the project's deference rules, the `xtty-test-validator` agent reads the live numbers from `packer/README.md` at runtime rather than hardcoding them, and any change that alters test counts or expected residuals must update that Acceptance section in the same session.


## C1-rep3  (turns=2 err=False subtype=success)

The VM rig's acceptance envelope is **40/1/1 of 42** — 40 passing, 1 known-benign failure, 1 skip — and its authoritative home is **`packer/README.md` → the "Acceptance (measured — post `fix-main-menu-clobber`)" section** (around `packer/README.md:225`). AGENTS.md and the `xtty-test-validator` agent both defer to that file rather than hardcoding the numbers.

Key details from that section:

- The envelope was measured 2026-07-05 across 3 runs (headless ×2 + graphics, all identical) after the `fix-main-menu-clobber` change; the 7 menu-dispatch tests that were red pre-fix now pass, and graphics and headless arms match exactly.
- The **sole expected residual is `testMultiLinePasteIsNotAutoExecuted`**, which is explicitly *not* a product bug: the image's `/bin/bash` login shell is macOS's stock bash 3.2.57, whose readline lacks bracketed paste, so a pasted multi-line string executes instead of staging. The proposed `harden-churn-shell-readiness` change will guard that test on no-bracketed-paste shells; until then it's the image's one known-benign red.
- Acceptance is defined as **matching this measured envelope, not a bare all-green**. A regression means any menu-dispatch test going red again, or a *second* non-paste failure.
- Forward-looking note: once `retire-metal-renderer` deletes the passing Metal e2e test, the total drops to 41 and the envelope will read **39/1/1 of 41**.

The section also carries a reverse duty: any change that alters test counts or expected residuals must update that Acceptance section (and the expected-difference matrix below it) in the same session, since the validator agent reads it at runtime.


## C2-rep1  (turns=1 err=False subtype=success)

xtty renders with **CoreGraphics**, not Metal — and that was a decision settled by measurement, not preference.

The original stack sketch called for a custom Metal renderer, and one was actually built and evaluated during the P7 performance phase. But when the P7b latency/memory harness (with a trustworthy `SCStream` latency probe) compared the two head-to-head, Metal lost: it showed a **worse p99 latency tail, higher memory usage, and no median latency win** over the CoreGraphics path. Given the project's hard requirements favor latency and lean memory in every tradeoff, the verdict was to keep CoreGraphics and skip the planned Phase 8 renderer work entirely.

This is now recorded as a "learned refutation" in AGENTS.md — the Metal renderer shouldn't be re-proposed on opinion alone; resurrecting it would require re-running the archived P7b measurement methodology (documented in `research/03-analysis/p7-measurement-methodology.md`). There's even an open change, `retire-metal-renderer`, to remove the Metal renderer option and the Metal-toolchain build dependency altogether (the only reason the toolchain is currently needed is a `.metal` shader bundled by SwiftTerm, which that change patches out).


## C2-rep2  (turns=2 err=False subtype=success)

**xtty renders with CoreGraphics.** Metal was evaluated head-to-head and rejected on measurement in the P7b renderer gate (June 2026), and the open `retire-metal-renderer` change is now removing the Metal option and its toolchain build dependency entirely.

The decision process, from `research/03-analysis/p7-measurement-methodology.md`:

- **It was a measurement gate, not an opinion.** The build plan made a custom Metal renderer (Phase 8) conditional on an A/B comparison: measure CoreGraphics vs SwiftTerm's Metal path in the same app, and only escalate if CoreGraphics missed the latency/memory bar.
- **The trustworthy probe was an `SCStream` key-to-photon capture** (the earlier state-dump-based latency numbers were explicitly labeled coarse/experimental). Three runs each:
  - **Latency p50 was indistinguishable** (~31–33 ms for both) — because the shared ~16.7 ms `queuePendingDisplay` coalescing throttle dominates the median regardless of renderer.
  - **Metal's tail was materially worse**: p99 of 100.2 / 49.5 / 119.5 ms vs CoreGraphics' 37.0 / 47.9 / 39.7 ms.
  - **Metal used ~7–20 MB more memory** under load, with identical CPU — directly against the project's lean-memory hard requirement (the "nowhere near Warp" bar).

So: no median win, a worse p99 tail, and a memory cost. Verdict recorded as **keep CoreGraphics, skip Phase 8**. The analysis also identified that the real future latency lever is the display-coalescing throttle in the engine, not the renderer.

One note from the project's learned-refutations list: resurrecting Metal would require re-running the archived P7b methodology with new measurements — it's considered settled otherwise.


## C2-rep3  (turns=1 err=False subtype=success)

xtty renders with **CoreGraphics** — that's the settled, measured decision from the P7 performance work.

The project built a custom Metal renderer as an option during P7, then ran both renderers through the P7a/P7b performance harness (`make bench` — latency plus per-scenario memory, with a trustworthy `SCStream`-based latency probe). The measurements went against Metal on every axis that matters to this project:

- **Worse p99 latency tail** than CoreGraphics
- **More memory** — which violates the "lean memory" hard requirement
- **No median latency win** to offset either cost

Since the project's stated engineering bias is latency-first and memory-lean, Metal lost on the evidence, the planned Phase 8 renderer work was skipped, and CoreGraphics was kept. This is now one of the "learned refutations" in `AGENTS.md`: resurrecting Metal would require re-running the archived P7b methodology, not an opinion. There's even an open change (`retire-metal-renderer`) to remove the Metal renderer option and the Metal-toolchain build dependency entirely — the only remaining Metal need is compiling a `.metal` shader that SwiftTerm bundles, which that change patches out.

Full methodology and numbers are in `research/03-analysis/p7-measurement-methodology.md` (and the leak/retain audit in `p7c-leak-retain-audit.md`).


## C3-rep1  (turns=7 err=False subtype=success)

**No — SwiftTerm is not forked.** There's no fork repo, no submodule, and no vendored copy of SwiftTerm source in git. It's consumed as a **gitignored clone of the unmodified upstream, pinned to a tag, with one add-only patch applied at bootstrap time** — the "patch in repo" model borrowed from Playwright. Only three small artifacts are version-controlled; the SwiftTerm tree itself is reconstituted on demand.

## How the dependency is consumed

1. **The pin** — `patches/swiftterm/UPSTREAM_CONFIG.sh` is the single source of truth: upstream URL `https://github.com/migueldeicaza/SwiftTerm.git`, ref `v1.13.0`.
2. **The reconstitution script** — `scripts/bootstrap-swiftterm.sh` (run once after cloning, or via `make setup`/`make bootstrap`; `make build` re-runs it automatically when its tracked inputs change). It:
   - clones upstream into `external/SwiftTerm` if absent (that path is in `.gitignore:31` — nothing under it is ever tracked),
   - **enforces the pin every run**: `fetch --tags`, `checkout v1.13.0`, then `git clean -fdq` to restore a pristine tree (so the checkout can't drift and the patch always applies onto a clean base),
   - applies `patches/swiftterm/xtty-accessors.diff` with `git apply`.
3. **The consumer** — `XttyCore/Package.swift:29` points at it as a plain local SPM path dependency: `.package(path: "../external/SwiftTerm")`. Until the bootstrap runs, the build fails to resolve that path.

CI does the same thing: the workflows call `scripts/bootstrap-swiftterm.sh` directly and cache `external/SwiftTerm` keyed on the pin + patch.

## How it's modified

The only modification is `patches/swiftterm/xtty-accessors.diff`, which is deliberately **add-only** — it creates one new file (`Sources/SwiftTerm/XttyAccessors.swift`) and touches zero existing SwiftTerm files. That file is a `public extension Terminal` exposing two read-only values that P4b-2 (spatial blocks) needs but which read module-`internal` buffer fields, so they must compile *inside* the SwiftTerm module:

- `getScrollInvariantCursorLocation()` — the cursor's trim-invariant absolute row (`yBase + y + linesTop`)
- `scrollbackBase` — `buffer.linesTop`, for reverse-mapping absolute rows and detecting clears/resets

Because the patch is add-only and mirrors an existing public idiom (`getScrollInvariantLine`), it's designed to be the basis of an upstream PR. Per the config's own comment, **the whole mechanism is meant to be retired once these accessors land in an upstream SwiftTerm release** — at which point the dependency becomes an ordinary unpatched one.

To change the patch, the documented workflow is: edit in a pristine checkout, regenerate the `.diff`, then re-run the bootstrap. The rationale for choosing this over a fork or submodule is written up in `research/03-analysis/swiftterm-fork-vs-patch-strategy.md`.


## C3-rep2  (turns=5 err=False subtype=success)

**No — SwiftTerm is not forked.** The repo deliberately avoids both a fork repo and a git submodule. Instead it tracks only three small artifacts and reconstitutes the dependency locally on each machine (the "patch in repo" mechanism modeled on how Playwright patches its browsers — see `research/03-analysis/swiftterm-fork-vs-patch-strategy.md`).

**How it's consumed:**

1. **The pin** — `patches/swiftterm/UPSTREAM_CONFIG.sh` is the single source of truth: upstream URL `https://github.com/migueldeicaza/SwiftTerm.git`, ref `v1.13.0`.
2. **The bootstrap** — `scripts/bootstrap-swiftterm.sh` (run once after cloning, or via `make setup`/`make bootstrap`; `make build` re-runs it automatically when its inputs change). It clones upstream into `external/SwiftTerm`, which is **gitignored** — nothing under it is ever committed. Every run it re-fetches, checks out the pinned tag, and `git clean -fdq`s the tree, so the checkout can't drift and the patch always lands on a pristine base.
3. **The consumption seam** — `XttyCore/Package.swift:29` declares a plain local SPM path dependency: `.package(path: "../external/SwiftTerm")`. The build fails to resolve that path until the bootstrap has run.

**How it's modified:**

- The script `git apply`s one tracked patch, `patches/swiftterm/xtty-accessors.diff`. It is **add-only**: it creates a single new file (`Sources/SwiftTerm/XttyAccessors.swift`) and touches no existing SwiftTerm source.
- That file exists because xtty (the P4b-2 spatial-blocks feature) needs two read-only values that are `internal` to SwiftTerm's module and therefore must be compiled *inside* it: `getScrollInvariantCursorLocation()` (the cursor's trim-invariant absolute row, `yBase + y + linesTop`) and `scrollbackBase` (`buffer.linesTop`). Both are exposed as a `public extension Terminal`, mirroring the existing public `getScrollInvariantLine(row:)` idiom.

**So what's version-controlled** is just the pin, the `.diff`, and the bootstrap script — the entire upstream tree is disposable build infrastructure. To change the pin or the patch, you edit those tracked files and re-run the bootstrap. The add-only shape is intentional: it's the basis for an upstream PR, and the whole mechanism is meant to be retired once the accessors land in an upstream SwiftTerm release.


## C3-rep3  (turns=6 err=False subtype=success)

No — SwiftTerm is **not forked**. The repo deliberately avoids both a fork and a submodule, using a "patch in repo" mechanism (modeled on how Playwright patches its browsers). Here's exactly how it works:

**What's version-controlled (only three small things):**
- `patches/swiftterm/UPSTREAM_CONFIG.sh` — the pin: upstream URL (`github.com/migueldeicaza/SwiftTerm.git`) and ref (`v1.13.0`)
- `patches/swiftterm/xtty-accessors.diff` — the modification, as a tracked diff
- `scripts/bootstrap-swiftterm.sh` — the script that reconstitutes everything

**How the dependency is consumed:** `scripts/bootstrap-swiftterm.sh` (run once after cloning, wrapped by `make setup`/`make bootstrap`) clones upstream SwiftTerm into `external/SwiftTerm`, which is **gitignored** — nothing under it is ever committed. Every run it fetches tags, force-checks-out the pinned `v1.13.0` ref, and runs `git clean -fdq` to restore a pristine tree, so the checkout can't drift and the patch always applies onto a clean base. Then `XttyCore/Package.swift` consumes it as a plain local SPM path dependency: `.package(path: "../external/SwiftTerm")`. CI does the same — the workflows call the bootstrap script directly and cache the checkout keyed on the pin + patch.

**How it's modified:** after checkout, the script runs `git apply patches/swiftterm/xtty-accessors.diff`. The patch is deliberately **add-only** — it creates one new file, `Sources/SwiftTerm/XttyAccessors.swift`, and touches no existing SwiftTerm file. That file exists because xtty needs two read-only values that are module-internal in SwiftTerm (so they must compile *inside* the SwiftTerm module):

1. `getScrollInvariantCursorLocation()` — the cursor's trim-invariant absolute row (`yBase + y + linesTop`), used by the P4b-2 spatial-blocks feature
2. `scrollbackBase` — `buffer.linesTop`, for mapping absolute rows back to display rows and detecting clears

**Why this shape:** a fork repo would need maintenance and a submodule is the wrong primitive for a dependency you patch; tracking just pin + diff + script keeps the repo lean while staying reproducible. The add-only patch is also the basis for an upstream PR — the whole mechanism is meant to be retired once the accessors land in an upstream SwiftTerm release. Full rationale is in `research/03-analysis/swiftterm-fork-vs-patch-strategy.md`.

One practical consequence: a fresh clone won't build until `scripts/bootstrap-swiftterm.sh` runs (the `../external/SwiftTerm` path doesn't resolve), and to change the patch you edit a pristine checkout and regenerate the `.diff`, never commit into `external/`.


## C4-rep1  (turns=3 err=False subtype=success)

The root cause was a product bug in xtty itself, not the CI environment: **SwiftUI's menu reconciler was clobbering xtty's custom main menu**, and the fix was the **`fix-main-menu-clobber`** change (archived 2026-07-05), which dropped the SwiftUI app lifecycle in favor of `NSApplicationMain`.

The details, from `research/03-analysis/github-actions-ci-cd.md` (§15–§18) and `swiftui-mainmenu-clobber-forensics.md`:

- **Symptom:** 7 menu-dependent XCUITests (split, directional-focus, new-tab, find-bar, truecolor, churn, new-window) failed on CI/VM but passed locally. They were initially misattributed to key-equivalent delivery problems on the runner ("Bucket B").
- **Actual mechanism:** SwiftUI's reconciler replaced xtty's custom menu with the default menu in a **per-launch race**. Crucially it mutated the *same* `NSMenu` instance **in place** — `NSApp.mainMenu === builtMenu` still held through a 100% clobber — so the items ("Split Right", "New Tab", etc.) simply didn't exist for the tests to invoke, and identity-based diagnostics read healthy.
- **Why local runs were green:** on bare metal, SwiftUI's initial pass is a synchronous `willFinishLaunching` callout that strictly precedes xtty's menu build, and exactly one pass fires per launch. The clobbering second pass (`scenesDidChange(phaseChanged:)`, established by elimination) only manifested under VM/CI conditions.
- **Refuted alternatives:** re-asserting `NSApp.mainMenu` is a no-op (the pointer was already correct), and `.commandsRemoved()` and rebuild-on-notification were both refuted live — the reconciler stripped or re-clobbered the menu regardless.
- **The fix:** drop the SwiftUI lifecycle entirely and boot via `NSApplicationMain`, so SwiftUI's reconciler never touches the menu. Post-fix validation (§18): all 7 tests flipped green, and a new menu canary confirmed xtty's Edit/View/Terminal/Window titles present on every launch across ~126 launches.


## C4-rep2  (turns=5 err=False subtype=success)

**Root cause: SwiftUI's scene-synthesized default menu was clobbering xtty's custom main menu at launch. The fix was the `fix-main-menu-clobber` change (archived 2026-07-05), which dropped the SwiftUI `@main App` lifecycle in favor of `NSApplicationMain`.**

The mechanism (fully attributed in `research/03-analysis/swiftui-mainmenu-clobber-forensics.md`, chronicled in `github-actions-ci-cd.md` §15–§18):

- Under the SwiftUI `@main App` lifecycle, SwiftUI's private `AppDelegate` is the real `NSApp.delegate` and runs an **identifier-keyed menu reconciler**. It never matches xtty's plain `NSMenuItem`s, so it strips every custom item from the menu **in place**.
- It's a **per-launch race**: fast bare metal wins it (menus survive, tests pass locally), while slow 3-vCPU CI/VM guests lose it ~100% of the time. With the Edit/View/Terminal/Window menus gone, every menu key equivalent (⌘D, ⌘T, ⌘V, ⌘W, ⌘F, ⌘⌥-arrows) simply didn't exist — so paste, split, new-tab, directional-focus, churn, truecolor-paste, and find-bar all failed on CI only. This was a genuine **product bug**, not a test-infrastructure problem.

Getting there took two refuted theories first (both now in the AGENTS.md "Learned refutations"): the bash login-shell banner (`silence-bash-deprecation` de-noised the grids but flipped zero tests) and "the runner drops Cmd-key delivery" (Bucket B — delivery was fine; the items weren't in the menu to trigger). Re-asserting `NSApp.mainMenu` was also refuted — SwiftUI mutates the same `NSMenu` instance in place — so eliminating the second menu owner was the only durable fix.

The shipped change (`openspec/changes/archive/2026-07-05-fix-main-menu-clobber/`) deleted the `@main struct XttyApp: App`, added `App/main.swift` that retains the existing `AppDelegate` and calls `NSApplicationMain` (the Ghostty-precedented pattern), plus a title-based `mainMenuTitles` canary in the DEBUG state dump. Validation per §18: all 7 tests flipped green in the pre-registered ×2 VM-rig runs (bare-metal green proves nothing since the race never fires there), with one benign residual — multi-line paste on the rig's bracketed-paste-less bash 3.2 — and the fix was subsequently confirmed on CI itself.

One nuance: of the original 7, one (`testFocusTypingOnActivateWithoutClicking`) had a different cause — the runner's ~72-char prompt wrapped the typed marker so the grid assertion couldn't match it. That was fixed earlier by the wrap-tolerant matcher (`harden-focus-typing-assertion`); the menu clobber accounts for the other six, and by the time the menu fix landed it was the root cause of all 7 then-persistent failures in run `28472076179`.


## C4-rep3  (turns=4 err=False subtype=success)

**Root cause:** SwiftUI's own `AppDelegate` menu reconciler was clobbering `NSApp.mainMenu` in place. On a fresh launch SwiftUI installs its menu during `finishLaunching`, xtty then installs its custom menu — but under CI/VM launch timing SwiftUI's reconciler re-ran afterwards and mutated the *same* `NSMenu` instance's content back to SwiftUI's version (same pointer, different items, including a Help menu xtty never builds). With the custom menu gone, every Cmd-key equivalent that dispatches through the menu bar became a no-op. The failing set partitioned perfectly: an exhaustive grep of `AppUITests/` showed the 7 failures map 1:1 onto tests using Cmd-modified `typeKey` (Find, new tab, etc.), while every passing test's keyboard input bypassed menus (`typeText`, Ctrl-U → SwiftTerm `keyDown`, AX clicks, env-triggers). It passed locally because the re-fire is a per-launch race that reproduces under CI/VM conditions (~3 vCPU), not on bare metal — though the forensics work eventually reproduced it deterministically on bare metal by synthetically re-posting `willFinishLaunchingNotification`.

**The fix:** the **`fix-main-menu-clobber`** change — it dropped the SwiftUI app lifecycle entirely and moved to plain AppKit **`NSApplicationMain`**, so SwiftUI's menu reconciler is never in the process to fight with. Band-aid candidates were refuted first by live probes: re-asserting/rebuilding the menu on a notification is whack-a-mole (the reconciler mutates the fresh menu in place again), and pointer-identity canaries are blind because content changes but identity doesn't — only a title-content canary is a valid sensor.

**Validation:** on the VM rig the suite went from **34 / 7 / 1** pre-fix to **40 / 1 / 1** across three consecutive runs with an identical result set (headless ×2 + graphics), which rules out a race win; CI confirmed it too. The one residual red is the benign multi-line-paste test on the rig's bash 3.2 (no bracketed paste) — a rig artifact, not the fix failing.

Full record: `research/03-analysis/swiftui-mainmenu-clobber-forensics.md` (the source-level mechanism and fix-candidate verdicts) and `research/03-analysis/github-actions-ci-cd.md` §14–§18 (the CI investigation and validation runs).


## R1-rep1  (turns=9 err=True subtype=error_max_turns)

<no result field>


## R1-rep2  (turns=8 err=False subtype=success)

I have to stop short of implementing: **this session has no file-editing or shell tools** — no Write, Edit, or Bash (I verified via tool search; only read/search tools plus unrelated MCP integrations like Chrome DevTools and Gmail are available). I can't create the OpenSpec change or touch the Swift sources, so implementation is blocked until this runs in a session with editing tools. What I did instead was map the full change against the actual code, so the next session (or you) can execute it directly.

One process note first: per AGENTS.md this is a non-trivial feature and shouldn't be coded straight from a chat prompt — it should start as an OpenSpec change (`/opsx:propose add-cursor-style` or similar), with spec deltas to `terminal-configuration` and, because the custom-drawn view is invisible to accessibility, a `verification-harness` delta too.

## Implementation map (verified against the code)

**1. Core type — `XttyCore/Sources/XttyCore/XttyConfig.swift`**
- Add a toolkit-independent enum next to the existing types, e.g. `public enum CursorStyle: String, Equatable, Sendable, CaseIterable { case block, bar, underline }` (the file deliberately avoids AppKit/SwiftTerm types — keep it that way).
- Add `public var cursorStyle: CursorStyle` to `XttyConfig` (XttyConfig.swift:92), thread it through the memberwise `init` with a `= .block` default (matching how `linkOpener`/`diffContext` were added at XttyConfig.swift:111), and leave `XttyConfig.default` (XttyConfig.swift:122) getting block implicitly.

**2. Parsing — `XttyCore/Sources/XttyCore/XttyConfigLoader.swift`**
- Add a `cursor-style` block following the exact pattern of `option-as-meta` / `diff-context` at XttyConfigLoader.swift:150–170: `if let raw = pairs["cursor-style"]`, lowercase it, `CursorStyle(rawValue:)`, and on failure `warn("cursor-style: '\(raw)' is not one of block|bar|underline; using \(config.cursorStyle)")` — invalid values fall back, never fail the load.

**3. App adapter — `App/TerminalConfigurator.swift`**
- In `apply(_:to:)` (TerminalConfigurator.swift:25), map the core enum to SwiftTerm's cursor style alongside the existing `caretColor` line. SwiftTerm distinguishes blinking/steady variants (`blinkBlock`, `steadyBar`, etc.); map to the steady variants for now. The exact API name on the pinned v1.13.0 needs checking against `external/SwiftTerm` (not bootstrapped in this worktree — run `scripts/bootstrap-swiftterm.sh` first); if the view doesn't expose a setter publicly, that's the same situation as the P4b accessors and would extend `patches/swiftterm/xtty-accessors.diff` rather than fork.

**4. Tests — `XttyCore/Tests/XttyCoreTests/`**
- Loader cases: valid `block`/`bar`/`underline`, case-insensitivity, invalid value warns + falls back, missing key defaults to block — mirroring the existing `diff-context` tests.

**5. Verification harness + trackers**
- New observable behavior ⇒ a `verification-harness` spec delta: expose the effective cursor style in the DEBUG state dump and add an e2e scenario ("if the harness can't see it, it isn't done").
- Since this changes test counts, `packer/README.md`'s Acceptance section must be updated in the same session, and the AGENTS.md snapshot counts (currently 235 unit + 42 XCUI) refreshed on completion.

Also worth noting: one wrinkle to decide in the proposal is interaction with DECSCUSR — shells/apps can change the cursor style via escape sequence at runtime, so the spec should say whether `cursor-style` is the *initial/default* style (recommended, and what other terminals do) or a hard override.

To proceed, re-run this task in a session with file-editing tools (e.g. interactive Claude Code in the repo), starting with the OpenSpec proposal.


## R1-rep3  (turns=12 err=False subtype=success)

I have to stop short of editing files: **this session has no write or execution tools at all** — no Write, Edit, or Bash, and nothing equivalent among the deferred/MCP tools (I searched; what's available is read-only search/read plus browser, Gmail, Obsidian, and Figma connectors). So I can't modify the repo or run `swift test` from here. What I *have* done is trace the entire path a config key takes through this codebase, so the implementation below is complete and ready to paste into a normal session — it follows the existing key patterns exactly.

One process note first: per AGENTS.md, a new config key is OpenSpec territory — it needs a `terminal-configuration` MODIFIED-requirement delta, and because it's new observable behavior, a `verification-harness` delta plus a state-dump field (7 of 10 archived changes carried one). I've included both below.

## The implementation, file by file

**1. `XttyCore/Sources/XttyCore/XttyConfig.swift`** — add a toolkit-independent enum (the core layer deliberately avoids SwiftTerm types), plus a field on `XttyConfig`:

```swift
/// Terminal cursor shape (config key `cursor-style`).
public enum CursorStyle: String, Equatable, Sendable, CaseIterable {
    case block
    case bar
    case underline
}
```

In `XttyConfig`: add `public var cursorStyle: CursorStyle`, append `cursorStyle: CursorStyle = .block` to the memberwise init (defaulted, so existing call sites keep compiling), and set `self.cursorStyle = cursorStyle`. The `default` config needs no edit since the init default covers it.

**2. `XttyCore/Sources/XttyCore/XttyConfigLoader.swift`** — in `resolve(from:base:warn:)`, next to the `diff-context` block (XttyConfigLoader.swift:163):

```swift
if let raw = pairs["cursor-style"] {
    if let value = CursorStyle(rawValue: raw.lowercased()) {
        config.cursorStyle = value
    } else {
        warn("cursor-style: '\(raw)' is not 'block', 'bar', or 'underline'; using \(config.cursorStyle.rawValue)")
    }
}
```

Placing it in `resolve` (not `resolveSet`) makes it profile-inheritable for free, same as `theme` and `font-size` — that's the right semantics for an appearance key.

**3. `App/TerminalConfigurator.swift`** — in `apply(_:to:)` (TerminalConfigurator.swift:25), map to SwiftTerm. Use the **blink** variants so the only thing that changes is shape — SwiftTerm's default is `blinkBlock`, so `cursor-style = block` stays behavior-identical to today:

```swift
let stStyle: SwiftTerm.CursorStyle
switch config.cursorStyle {
case .block: stStyle = .blinkBlock
case .bar: stStyle = .blinkBar
case .underline: stStyle = .blinkUnderline
}
view.getTerminal().setCursorStyle(stStyle)
```

⚠️ **Verify this seam against the pinned checkout** — `external/SwiftTerm` isn't present in this worktree (gitignored bootstrap clone), so I could not confirm what v1.13.0 exposes. After `scripts/bootstrap-swiftterm.sh`, run `grep -rn "CursorStyle" external/SwiftTerm/Sources/` and check both that `Terminal.setCursorStyle(_:)` is public and that the macOS `TerminalView`'s caret actually redraws on it. If the caret view doesn't react to an API-driven (vs DECSCUSR-driven) style change, this becomes a third accessor in `patches/swiftterm/xtty-accessors.diff` — same no-fork mechanism as the existing two.

**4. Harness observability** — in `writeStateDump()` (TerminalWindowController.swift:779), add alongside `"theme"`:

```swift
"cursorStyle": active.profile.config.cursorStyle.rawValue,
```

**5. Tests** — in `XttyConfigTests.swift`, following the existing per-key trio: all three values resolve; invalid value falls back to `.block` with exactly one warning; a profile inherits the base `cursor-style` and can override it (mirror `testLinkOpenerInheritedByProfileOverBase`). Add an XCUITest scenario to `AppUITests/XttyConfigUITests.swift` asserting the new dump field, following that file's existing config-fixture pattern. Remember the AGENTS.md reverse-duty: if this changes the 235/42 counts, `packer/README.md`'s Acceptance section must be updated in the same session.

**6. OpenSpec artifacts** — `openspec new change "add-cursor-style"` with deltas for `terminal-configuration` (MODIFIED: the config-keys requirement, adding the key + invalid-value fallback scenario) and `verification-harness` (ADDED: the `cursorStyle` dump field scenario), committed as `docs(openspec): …` before the `feat(app): …` implementation commit.

To actually land this, re-run the request in a session with write access (or grant this environment Write/Edit/Bash) — with the trace above it's a mechanical apply plus the one SwiftTerm API verification.


## R2-rep1  (turns=9 err=True subtype=error_max_turns)

<no result field>


## R2-rep2  (turns=9 err=True subtype=error_max_turns)

<no result field>


## R2-rep3  (turns=9 err=True subtype=error_max_turns)

<no result field>


## R3-rep1  (turns=1 err=False subtype=success)

```
fix(app): parse shift+cmd chords correctly in KeybindParser
```

That follows the repo's Conventional Commits convention — `fix` for a bug fix, `app` scope since it's implementation code in `XttyCore`. If you want a body explaining the mis-parse (e.g. what input was wrong and what it resolved to), add it after a blank line, but the subject alone is sufficient for a scoped one-file fix.

One note: AGENTS.md says to append the `Co-Authored-By` trailer only when the change was authored with an AI — since you wrote this fix yourself, I left it off. If Claude had helped write the code, you'd add:

```
Co-Authored-By: Claude <noreply@anthropic.com>
```


## R3-rep2  (turns=1 err=False subtype=success)

```
fix(app): correct KeybindParser handling of shift+cmd chords
```

This follows the repo's Conventional Commits rule with the `app` scope (the one used for implementation code, including `XttyCore`). Since you fixed the bug yourself, I left off the `Co-Authored-By` trailer — AGENTS.md only calls for it when the change was authored with an AI.

If you want a body explaining the mis-parse (worth it if the cause was subtle), something like:

```
fix(app): correct KeybindParser handling of shift+cmd chords

shift+cmd combinations were mis-parsed because <one line on the actual
cause, e.g. modifier order / shifted-character normalization>.
```


## R3-rep3  (turns=1 err=False subtype=success)

Following the repo's Conventional Commits convention (`type(scope):`, scopes used: `app` for implementation):

```
fix(app): parse shift+cmd chords correctly in KeybindParser
```

Since you authored the fix yourself, I left off the `Co-Authored-By` AI trailer — AGENTS.md only asks for it when the change was authored with an AI. If a test accompanied the fix in the same commit, this message still fits; only use a separate `test(app): …` commit if the test lands on its own.


## R4-rep1  (turns=1 err=False subtype=success)

Per AGENTS.md, a settled investigation with measurements must be captured as a `research/` doc **now** — "as soon as it settles," not after the milestone wraps. Concretely:

**1. Write the research doc** (likely `research/03-analysis/` for a CI-race forensics piece), following the conventions for a capture with measured claims and retired theories:

- **Provenance** note (date + how produced) and a **Sources** list, with claims marked ✅/❌/❓.
- The **mechanism/internals** — how the race actually works, with the evidence, not just the conclusion.
- **Reproducible probes** — the exact commands, what each proves *and cannot prove*, including instruments that didn't work.
- The **investigation record** — a fates table putting each retired theory (❌) next to the experiment that killed it, so dead theories can't respawn.
- **Re-verify by effect** — how a future reader re-checks the headline claim (never a syntax/read-back check).
- A distilled numbered **reusable guideline** if the finding generalizes, plus pointers to the evidence artifacts.

The exemplar to match is `research/03-analysis/local-network-privacy-forensics.md`.

**2. Reconcile the trackers in the same session:**

- Add the doc to `research/README.md`.
- Update the relevant change's row in the AGENTS.md **Current-status table** (state + one-liner + detail pointer only) and refresh the snapshot paragraph if counts or the envelope moved.
- Append the full narrative to **HISTORY.md** under a dated heading.
- If the root cause refuted a theory worth never re-litigating, add a one-liner to the **Learned refutations** list in AGENTS.md (that list exists precisely for settled-by-measurement conclusions like this).
- If the fix belongs in an OpenSpec change, the actionable *decision* goes in the change artifacts — the *why* stays in `research/`. And if the finding alters test counts or expected residuals, `packer/README.md`'s Acceptance/matrix section must be updated in the same session.

**3. Verify against disk** — `openspec list`, `ls openspec/changes/archive/`, `ls openspec/specs/` — and fix any tracker that disagrees with reality.

The repo has tooling for exactly this: the **`/xtty:capture-research`** command (backed by the `xtty-capture-research` skill) walks the whole place-and-index → reconcile-trackers → verify-against-disk checklist. Say the word and I'll run it on these findings.


## R4-rep2  (turns=1 err=False subtype=success)

According to AGENTS.md, settled findings with measurements must be captured now — "as soon as it settles, even mid-build" — not after we move on. Concretely:

1. **Write a research doc** under `research/03-analysis/` following the doc conventions: a **Provenance** note (date + how produced), a **Sources** list, and ✅/❌/❓ markers on fact-checked claims. Because this capture has *measured claims and retired theories*, it must go to full depth, per the "Capture depth" rule:
   - the **mechanism/internals** (how the race actually works, with evidence),
   - **reproducible probes** — exact commands, what each proves *and cannot prove*, including instruments that did **not** work,
   - an **investigation record** — each retired theory as a ❌ next to the experiment that killed it (a fates table), so dead theories can't respawn,
   - a **re-verify by effect** section (how a future reader re-checks the headline claim, never a syntax/read-back check),
   - a distilled numbered **reusable guideline** if the finding generalizes,
   - pointers to the **evidence artifacts**. The stated exemplar is `research/03-analysis/local-network-privacy-forensics.md`.

2. **Index it** in `research/README.md`.

3. **Reconcile the trackers in the same session:** update the relevant row in AGENTS.md's Current-status table (bounded one-liner, never a narrative), refresh the snapshot paragraph if counts or the acceptance envelope moved, and append the full narrative to `HISTORY.md` under a dated heading.

4. **If the investigation refuted something worth never re-litigating**, add a one-liner with its conclusion to the **Learned refutations** list in AGENTS.md — that's exactly what that list is for (the retry-flags and `hasForegroundJob` entries came from investigations like this one).

5. **Keep the why/decision split:** the mechanism and landscape live in `research/`; any actionable *fix* belongs in an OpenSpec change (`/opsx:propose`), not implemented straight from the chat. If the findings changed test counts or expected residuals, `packer/README.md`'s Acceptance/matrix section must be updated in the same session too.

6. **Verify against disk** afterward — `openspec list`, `ls openspec/changes/archive/`, `ls openspec/specs/` — and fix any tracker that disagrees with reality.

There's a dedicated shortcut for all of this: the `/xtty:capture-research` command (backed by the `xtty-capture-research` skill) walks the whole place-index-reconcile-verify checklist. Say the word and I'll run it against these findings.


## R4-rep3  (turns=1 err=False subtype=success)

Per this repo's process (AGENTS.md → "How to work here"), settled findings with measurements must be **captured as a research doc and reconciled into the trackers before moving on** — and there's a dedicated command for exactly this: **`/xtty:capture-research`** (backed by the `xtty-capture-research` skill), which walks the whole checklist. Concretely, what it requires:

**1. Write the research doc now, in `research/03-analysis/`** ("as soon as it settles, even mid-build"). Because this capture has measured claims and retired theories, it must go to full depth, not just the conclusion:

- The **mechanism/internals** — how the race actually works, with the evidence.
- **Reproducible probes** — the exact commands, what each proves *and cannot prove*, including instruments that did **not** work.
- The **investigation record** — every retired theory as a ❌ next to the experiment that killed it (a fates table), so dead theories can't respawn.
- **Re-verify by effect** — how a future reader re-checks the headline claim (never a syntax/read-back check).
- A distilled **reusable guideline** if the finding generalizes, plus pointers to evidence artifacts.
- Standard conventions: a **Provenance** note (date + how produced), a **Sources** list, ✅/❌/❓ on fact-checked claims. The stated exemplar is `research/03-analysis/local-network-privacy-forensics.md`.

**2. Index it** — add the doc to `research/README.md`.

**3. Reconcile the trackers** in the same session:

- Update the relevant **row in the AGENTS.md Current-status table** (state + one-liner + detail pointer only — never a narrative paragraph), and the snapshot paragraph if counts or the acceptance envelope moved.
- Append the full narrative to **HISTORY.md** under a dated heading.
- If the investigation settled something worth never re-litigating, add a one-liner to the **Learned refutations** list in AGENTS.md — CI/race findings have landed there before (e.g. the retry-flag ban and the `hasForegroundJob` refutation).
- If it touches a milestone, advance `research/04-design/02-milestones.md`; if it changes test counts or expected residuals, `packer/README.md`'s Acceptance/matrix section must be updated in the same session.

**4. Verify against disk** — `openspec list`, `ls openspec/changes/archive/`, `ls openspec/specs/` must all match what the trackers claim; fix any disagreement.

One boundary to respect while writing it up: the *why/mechanism* stays in `research/`; if the fix itself is non-trivial, the actionable *decision* belongs in an OpenSpec change (as was done with `harden-churn-shell-readiness`, which pairs a proposed change with its `confirm-close-shell-readiness.md` research doc).

If you'd like, I can run `/xtty:capture-research` now and do the capture-and-reconcile pass for this investigation.


## T1-rep1  (turns=2 err=False subtype=success)

No — this exact idea is one of the project's recorded "learned refutations," and it was settled by measurement, not opinion. Retries in this repo have already green-lit genuinely broken tests once.

The history, from `research/03-analysis/local-macos-vm-ci-reproduction.md:113-129`: during the menu-clobber investigation, a Tart VM run *with* `-retry-tests-on-failure` came back 36/5/1 because a retry happened to catch an app launch that won the per-launch race — so `testSplitCreatesAndClosesPanes` and `testDirectionalFocusMovesBetweenPanes` passed while the underlying bug (SwiftUI clobbering the main menu on ~98% of launches) was fully real. Two other runs of the same build were 34/7/1. If the suite had been retry-tolerant and gating, that product bug would have shipped green. That's why AGENTS.md bans retry tolerance and why the VM acceptance workflow explicitly runs with no retry flag (`packer/README.md:177`).

Two nuances worth knowing:

1. **CI already has the flag, deliberately quarantined.** The non-blocking `build-and-test` job does use `-retry-tests-on-failure` (`research/03-analysis/github-actions-ci-cd.md:70`), and a review panel decision (`:421`) kept it as the *only* permitted flake channel — because it's relaunch-level and the `.xcresult` still records retried-but-passed tests, so flakes stay visible rather than silently absorbed. The line the project holds is: that job stays non-blocking, retries never become part of a required gate, and in-test retry loops are banned outright.

2. **The flakes you're seeing already have a diagnosis and a fix path.** The main remaining local flake (the churn confirm-close race) has a proposed fix in the open `harden-churn-shell-readiness` change — a computed-marker shell-readiness gate, replacing the refuted `hasForegroundJob` wait. The two residual VM-rig reds (find-bar marker wrap on the ~72-char prompt, multi-line paste on the rig's bash 3.2) are classified as benign rig fragilities in `packer/README.md`'s expected-difference matrix, not things to paper over with reruns.

So the answer to a flaky test here is the established playbook: classify it against the acceptance envelope, root-cause it (the rig exists precisely to make races reproducible at 3 vCPU), and fix it at the product or harness seam. If the churn flake is what's biting you, applying `harden-churn-shell-readiness` is the move — happy to pick that up if you want.


## T1-rep2  (turns=3 err=False subtype=success)

No — this is a bad idea for this repo, and it's already one of the documented "Learned refutations" in AGENTS.md: **"Test retry flags / retry tolerance are banned — retries mask the per-launch race class (a retried VM run green-lit two genuinely broken tests)."** The project learned this the expensive way.

Here's the actual history, from `research/03-analysis/local-macos-vm-ci-reproduction.md`:

- On the Tart VM rig, a run with `-retry-tests-on-failure` reported `testSplitCreatesAndClosesPanes` and `testDirectionalFocusMovesBetweenPanes` as **FLAKY-PASSED** — the retry happened to catch an app launch that won the SwiftUI menu-clobber race. Both tests were exposing a genuine product bug (the menu race), and the retry made the suite green over it.
- The conclusion recorded there: because retry tolerance can mask the race, the fix must *eliminate* it — which is what happened (dropping the SwiftUI App lifecycle for `NSApplicationMain`), and the VM rig then proved the fix directly with clean repeated runs.
- The `xtty-test-validator` agent definition encodes the same rule: "No retry flags, ever — not `-retry-tests-on-failure`, not an in-run retry loop."

One nuance worth knowing: the flag technically already exists in one place. The **non-blocking** `build-and-test` CI job has `-retry-tests-on-failure` (`.github/workflows/ci.yml:85`) — a deliberate, panel-reviewed exception (`github-actions-ci-cd.md` §421) because relaunch-level retries are visible in the result bundle and that job doesn't gate merges. So there's nothing to add, and the thing you're describing — using reruns so flakes stop being visible, or extending retries to a gating job or the VM validation rig — is exactly what's banned.

The sanctioned path for the flakiness you're seeing is root-causing it instead. That's largely already done: the remaining known flake (the churn confirm-close race) has a proposed fix in the open `harden-churn-shell-readiness` change (computed-marker readiness gate + `.common`-modes dump timer, root-caused in `research/03-analysis/confirm-close-shell-readiness.md`). If you're hitting a *new* flake on the CI VM, the right move is to reproduce it on the Tart rig and diagnose it — happy to dig into a specific failing test if you point me at one.


## T1-rep3  (turns=4 err=False subtype=success)

Not a good idea — this repo already tried exactly that, and it's on the banned list for a measured reason.

**What happened when retries were used here.** During the VM-rig reproduction work (`research/03-analysis/local-macos-vm-ci-reproduction.md` §9d–9e), three runs of the *identical* VM and binary produced different results. In Tart run 1, a `-retry-tests-on-failure` retry happened to win the per-launch SwiftUI menu-clobber race and **green-lit two genuinely broken tests** (`testSplitCreatesAndClosesPanes`, `testDirectionalFocusMovesBetweenPanes`) — tests that failed in runs 2 and 3 and matched the real CI failure exactly. The clobber had a ~98% per-launch hit rate, yet a retried suite still reported it as passing. That's the trap: your flakes aren't random test noise, they're per-launch races in the product, and a retry is just re-rolling the dice until the race is won once. The conclusion (§9e) was that the fix must *eliminate* the race, not tolerate it — which is why AGENTS.md lists "test retry flags / retry tolerance are banned" under Learned refutations.

**What to do instead of retries:**

1. **Fix the race, don't mask it.** The biggest flake source (the menu clobber) was already fixed by dropping the SwiftUI lifecycle for `NSApplicationMain`, and that fix is CI-confirmed.
2. **The remaining known flake has a proposed fix in flight** — the churn confirm-close race is covered by the open `harden-churn-shell-readiness` change (computed-marker readiness gate + `.common`-modes dump timer, see `research/03-analysis/confirm-close-shell-readiness.md`). If VM flakiness is bothering you, applying that change is the productive move.
3. **Genuinely environmental residuals get classified, not retried.** The rig's two known benign residuals (multi-line paste on bash-3.2, the find-bar marker-wrap) are documented in `packer/README.md`'s acceptance envelope, so the validator distinguishes "expected rig difference" from "real regression" deterministically.

One nuance worth knowing: the non-blocking `build-and-test` CI job is currently described as retry-tolerant, but it's deliberately kept **out of required checks** for exactly this reason — its results aren't trusted as a gate. The green required gate is `test-core`, which is deterministic. Adding retries to make XCUITests gate-worthy would invert that: it would make the gate *look* trustworthy while hiding the same class of bug the rig work proved retries hide.

So: skip the retry flag. If specific tests are flaking on the VM, the right path is diagnosing which race class they hit (the research docs above have the playbook) and either fixing the product seam or adding them to the documented expected-difference matrix.


## T2-rep1  (turns=1 err=False subtype=success)

No — that approach was tried and refuted by measurement, and the actual fix has already shipped. It's on the "Learned refutations — do not re-propose" list in AGENTS.md.

The reason re-asserting `NSApp.mainMenu` doesn't work: SwiftUI's menu reconciler holds a reference to the same `NSMenu` instance and mutates it in place. Assigning the menu back after launch is a no-op — you're re-assigning the very object SwiftUI keeps clobbering, so the next reconciliation pass wipes it again. There's no stable point "after launch" where you win; it's a fight you can't referee from the app side.

The fix that shipped (and was confirmed on CI) was to drop the SwiftUI app lifecycle entirely and go to `NSApplicationMain`, so SwiftUI's reconciler never owns the main menu in the first place. The full forensics — including the evidence that killed the re-assertion theory — are in `research/03-analysis/swiftui-mainmenu-clobber-forensics.md`.

So if you're seeing menu weirdness again, it'd be worth confirming it's actually a regression of this bug (or something new) rather than reintroducing the re-assertion approach — that path is a dead end that was settled experimentally.


## T2-rep2  (turns=1 err=False subtype=success)

No — that exact approach was tried and refuted by measurement, and it's on the project's "do not re-propose" list. The reason it can't work: SwiftUI's menu reconciler holds a reference to the **same `NSMenu` instance** and mutates it in place. Re-assigning `NSApp.mainMenu` after launch just hands back the object SwiftUI is already clobbering — the reconciler's next pass overwrites your menu items again, so the re-assertion is a no-op, not a fix.

The fix that actually shipped (and is CI-confirmed) was to drop the SwiftUI app lifecycle entirely and boot via `NSApplicationMain`, so there's no SwiftUI reconciler touching the main menu in the first place. The full forensics — including the experiments that killed the re-assert theory — are in `research/03-analysis/swiftui-mainmenu-clobber-forensics.md`.

Also worth noting: this bug is already fixed on `main`, so there's nothing to change here regardless.


## T2-rep3  (turns=1 err=False subtype=success)

No — that approach was already tried, measured, and refuted in this repo. It's on the **Learned refutations** list in AGENTS.md precisely so it doesn't get re-proposed.

The reason re-asserting doesn't work: SwiftUI's menu reconciler doesn't *replace* `NSApp.mainMenu` with a new menu object — it mutates the **same `NSMenu` instance in place**. So assigning `NSApp.mainMenu = myMenu` again after launch is a no-op: the property already points at that instance; it's the instance's *contents* that got clobbered, and the reconciler will clobber them again on its next pass regardless of when or how often you re-assign.

The fix that actually shipped (and is confirmed on CI) was to drop the SwiftUI app lifecycle entirely and go through `NSApplicationMain`, so SwiftUI's menu reconciler never owns the main menu in the first place. The full forensics — including the evidence that killed the re-assert theory — is in `research/03-analysis/swiftui-mainmenu-clobber-forensics.md`, with the digest in HISTORY.md.

So if this came up in the context of new work: the bug is already fixed; nothing to do. If you were considering reverting to the SwiftUI lifecycle plus a re-assert workaround, that would reintroduce the bug — the measurement says it can't be papered over that way.


## T3-rep1  (turns=2 err=False subtype=success)

**No — don't do this.** It's the exact failure mode that stranded the validator repeatedly before v4, and it was refuted by measurement, not opinion. It's on the Learned-refutations list in AGENTS.md precisely so it doesn't get re-proposed.

The mechanism, from `research/03-analysis/claude-code-subagent-execution-forensics.md`:

- **The "notification arrives" premise is false for subagents.** The Bash tool's promise that a background task "re-invokes you when it exits" holds only in the main conversation. For a subagent, the moment it stops calling tools its task closes — no background child exiting, no watcher, nothing ever re-invokes it. Across every stranded transcript examined, zero re-invocation notifications were delivered.
- **This exact shape was tried three times and failed all three.** Each failed run authored a correct bounded wait loop, then set `run_in_background: true` on it — converting the survival mechanic into an orphan watcher — and parked mid-sweep, never to resume. The v4 fix was affordance removal: ban `run_in_background` outright, mandate the unfused foreground launch→wait shape, and stamp reports with a `Definition:` version the caller checks. Post-v4: three consecutive sweeps (14, 65, and 30 minutes), zero strands.
- **The waits aren't actually a cost to you.** The whole reason validation is delegated to the agent is that the long foreground waits and VM noise happen inside *its* context, not your session. The control run sat through a 6.5-minute foreground wait in a single call and completed a 43-minute two-VM sweep cleanly.

So the clunkiness is load-bearing: foreground bounded waits are the only mechanism that keeps the subagent alive through the tiers. If a sweep does strand anyway, the recovery path is the babysitter protocol in the `/xtty:validate` launcher (reconstruct from `ledger.log`/`REVIEW.md`, resume via SendMessage) — not backgrounding.

If the goal is to make the waits *feel* less clunky rather than remove them, options that don't reopen the refuted mechanism: tighter poll intervals with earlier-exit checks inside the existing wait loops, or better in-loop progress lines to the ledger so the babysitter can see liveness. Happy to look at either.


## T3-rep2  (turns=2 err=False subtype=success)

No — this exact design was tried, failed three times, and is a settled refutation in this repo. Don't make that change.

The full record is in `research/03-analysis/claude-code-subagent-execution-forensics.md`, and it's also on the AGENTS.md "Learned refutations" list. The short version:

- **The "re-invokes you when it exits" promise is main-conversation-only.** For a subagent it is empirically false: across every stranded transcript, zero notifications were ever delivered. A subagent that ends its turn mid-work is done forever — nothing resumes it.
- **This isn't hypothetical — it's exactly how the three failed sweeps died.** Each run authored a correct bounded wait loop, set `run_in_background: true` on it, ended its turn to "wait for the notification," and parked permanently. It's made worse by a real trap: a `nohup` wrapper exiting instantly can emit a genuine mid-turn "completed" notification, teaching the model that notifications work right before it stakes the sweep on one.
- **The current v4 design is the validated fix**, not an accident of clunkiness: `run_in_background` banned outright, unfused foreground launch (`nohup … & echo $! > pidfile`) plus separate bounded `while kill -0 <pid>; do sleep 30; done` waits reissued on timeout. Post-v4: three consecutive clean Sonnet sweeps (14 / 65 / 30 min), zero strands. The unfused shape also matters — a fused launch+wait was killed pre-ship because the 600 s per-call timeout would SIGTERM the workload itself.

So the waits *look* clunky, but "waiting" for a subagent has to be a tool call it is inside of, never a state entered by stopping. If the clunkiness that bothers you is in the main session rather than the agent, that's already handled differently — the babysitter protocol in the `/xtty:validate` launcher covers reconstructing and resuming a stranded run via the ledger.

If you want to revisit this anyway, the bar set by the research doc is a new measurement (spawn a probe subagent, background a task, end the turn, and show a notification actually arrives), not a redesign on the assumption that the tool doc's promise holds.


## T3-rep3  (turns=2 err=False subtype=success)

I'd advise against it — this exact design was tried, measured, and refuted, and it's on the "do not re-propose" list in AGENTS.md. The full forensic record is in `research/03-analysis/claude-code-subagent-execution-forensics.md`.

The core problem: **the `run_in_background` "re-invokes you when it exits" promise is main-conversation-only and is false for subagents.** A subagent that ends its turn stops being invoked forever — no background child exiting, no watcher, no notification ever resumes it. This was measured directly: zero re-invocation notifications were delivered across every stranded transcript, and three separate validator runs were lost this way. Each of those runs even authored a *correct* bounded wait loop, then set `run_in_background: true` on it — converting the survival mechanic into an orphan watcher — and parked mid-sweep. Worse, a wrapper exiting instantly can emit a real "completed" notification, which teaches the agent that notifications work right before it stakes the sweep on one that never comes.

The fix that actually shipped and validated (validator v4) is the opposite of what you're proposing: **ban `run_in_background` outright** and use the unfused foreground shape — instant `nohup … & echo $! > pidfile` launch, then separate foreground `while kill -0 <pid>; do sleep 30; done` waits reissued on timeout. Post-v4, three consecutive sweeps (14 / 65 / 30 minutes) completed with zero strands. The waits look clunky, but that's the mechanism keeping the agent alive: waiting has to be a tool call the agent is *inside of*, never a state it enters by stopping.

Also worth noting from the fates table: fusing the launch and wait into one atomic call was considered and killed pre-ship too — the 600 s per-call timeout would SIGTERM the workload's process tree, so the launch and the waits must stay separate calls.

Per the refutations rule, resurrecting this would require re-running the measurement (spawn a real sweep and show the notification actually arrives for a parked subagent), not a design preference. If the clunkiness itself is the pain point, the leverage is elsewhere — e.g. longer per-call bounded waits (the control ran a 6.5-minute single-call wait unimpeded) or quieter wait-loop output — rather than ending the turn. Happy to look at either of those if you want.


## T4-rep1  (turns=2 err=False subtype=success)

No — that's the exact "obvious fix" the probe in `research/03-analysis/confirm-close-shell-readiness.md` was built to test, and it killed it. It's also in the AGENTS.md learned-refutations list. Two measured reasons:

1. **`hasForegroundJob == false` is true before startup even begins.** The forked shell is the session leader, so `tcgetpgrp` returns the shell's own pgid within 3–30 ms of spawn — before `~/.zshrc` runs. A "wait until no foreground job" check passes instantly on a shell that hasn't finished (or even started) sourcing its rc files, which is precisely the window the churn flake lives in.

2. **The dump sampler can't see the busy episodes anyway.** Startup children (git, nvm, node) grab the tty in 15–57 ms bursts, while the state-dump sampler polls at 150 ms — structurally blind to them. Even "k consecutive clean reads" degenerates into a disguised, load-scaled sleep (k=14 ≈ 2.1 s was needed under synthetic load, and that's a lower bound for cold caches). And under CI bash there's zero flicker at all, so the wait passes instantly and proves nothing there either.

The decided fix — already proposed as the open `harden-churn-shell-readiness` change (0/12) — is the **computed-marker execution roundtrip**: the test types something like `echo $((41000+1))` and waits for `41001` in the output. The token never appears in the echoed input line, so a match proves the shell actually read and executed a command, i.e. rc sourcing is complete and the shell is back at its prompt. That's a strictly-later *event*, not a flappy state; it's shell-agnostic (works under CI bash); and §7's artifact verification confirmed it would have held ⌘W past the exact iterations that flaked in both failing local runs. Plus the companion `.common`-modes dump-timer fix.

One nuance worth knowing: a *single* `hasForegroundJob == false` read **post-marker** is meaningful (unlike pre-marker), and the doc keeps it as a pre-planned escalation ("Companion F") if a residual flake is ever observed after the marker gate ships — but it's an add-on to the marker roundtrip, not a substitute, and it shouldn't ship speculatively.

So: apply the existing `harden-churn-shell-readiness` proposal rather than a foreground-job wait.


## T4-rep2  (turns=2 err=False subtype=success)

No — that exact approach was empirically refuted here on 2026-07-03. It's on the AGENTS.md "Learned refutations" list, and the full evidence is in `research/03-analysis/confirm-close-shell-readiness.md` (§2, the probe that killed it). Three reasons it can't work:

1. **`hasForegroundJob` is false before startup even begins.** The forked shell is the session leader, so `tcgetpgrp` returns the shell's pgid within ~3–30 ms of spawn — *before* `~/.zshrc` runs. A "wait until false" check passes instantly on a shell that's about to spend seconds sourcing rc files, which is precisely the window the flake lives in.

2. **The busy episodes are invisible to the sampler.** Startup children (git, nvm, node) grab the tty in 15–57 ms bursts with shell-owned gaps up to ~740 ms between them, and the last flicker can land as late as ~2 s under load. The 150 ms state-dump sampler is structurally blind to those bursts, so even a "k consecutive clean reads" variant degenerates into a disguised, load-scaled sleep.

3. **It's inert on CI.** Under CI's bash there is zero foreground flicker at all, so the wait proves nothing there.

The decided fix is already proposed as the open `harden-churn-shell-readiness` change: a **computed-marker execution roundtrip** in both churn loops — type `echo $((41000+i))` into the fresh pane and wait for the computed output (`41001`, which never appears in the echoed input) in the grid dump before sending ⌘W, failing fast on timeout so a readiness miss can't cascade into the modal wedge. A match proves the shell actually read and executed a command — an event strictly later than the last rc flicker, and shell-agnostic (works under CI bash too). It ships with a companion fix: the DEBUG dump timer must be added to `RunLoop.main` in `.common` modes, because `NSAlert.runModal()` freezes `.default`-mode timers and that's what made the failing runs so hard to read.

One nuance from the research worth knowing: a `hasForegroundJob == false` read *is* meaningful **after** the marker roundtrip, and that's pre-planned as an escalation if a residual flake ever shows up post-marker — but only as a follow-up to the marker gate, never as the primary wait.

So rather than adding the wait you described, the right move is to apply the existing `harden-churn-shell-readiness` change (0/12 tasks, `openspec/changes/harden-churn-shell-readiness/`).


## T4-rep3  (turns=2 err=False subtype=success)

No — that's the "obvious fix" that was directly probed and refuted on 2026-07-03. It's recorded in AGENTS.md's learned-refutations list, and `research/03-analysis/confirm-close-shell-readiness.md` §2 has the measurements that killed it:

- **`hasForegroundJob == false` is true before startup even begins.** The forked shell is its own session leader, so `tcgetpgrp` returns the shell's pgid within 3–30 ms of spawn — before `~/.zshrc` runs. A wait on "no foreground job" passes instantly on a shell that isn't remotely ready, which is exactly the state the flake fires in.
- **The busy episodes are invisible to the sampler.** Startup children (git, nvm, node) grab the tty in 15–57 ms bursts with shell-owned gaps up to ~740 ms between them, and the last flicker lands as late as ~2 s under load. The 150 ms state-dump sampler is structurally blind to bursts that short, so even a "k consecutive clean reads" variant degenerates into a disguised, load-scaled sleep.
- **Under CI bash it's vacuous** — zero flicker from <35 ms, so the gate adds nothing there either.

The decided fix is the already-proposed change **`harden-churn-shell-readiness`**: a computed-marker execution roundtrip — the test types something like `echo $((41000+1))` and waits for `41001` in the output. The token never appears in the echoed input line, so a match proves the shell actually read and executed a command, which is strictly later than the last rc-sourcing flicker. It's an event, not a flappy state, it's shell-agnostic (bash and zsh), and the §7 addendum verified against the three captured `.xcresult` bundles that this gate would have held ⌘W past the exact iterations that were struck in both failing runs. It ships with a `.common`-modes dump-timer fix as a companion.

One nuance worth knowing: a *single post-marker* `hasForegroundJob == false` read is meaningful (unlike pre-marker), and the research keeps it as a pre-planned escalation ("Companion F") — but only if a residual flake is ever observed after the marker gate lands, not as the primary fix.

So the path forward is to apply the open `harden-churn-shell-readiness` change rather than building a foreground-job wait. Happy to run `/opsx:apply` on it if you want.
