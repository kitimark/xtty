# Grading sheet — A-R (diagnostic arm: N + final refutation compression only; worktree AR @ cf9c2bc)

Graded 2026-07-28, same rubric/strictness. Key cells: E1-rep1 FAIL (repeated the false
56-test/5-environment claim from the retained N snapshot — the F4 poison survives compression
alone); T5-rep1/2 FAIL (cap-cut, no verdict text); R3-rep1 FAIL (cap-cut, no message);
R1-rep1/2 PASS-truncated (routing stated in first text block). All other cells PASS.
Class tallies: rule 7/8 · recall 9/10 · orientation 6/6 · trap 18/20 = 40/44.


## C1-rep1  (turns=4 err=False subtype=success)

**Authoritative home:** `packer/README.md` → the `### Acceptance` section (plus its companion `### Expected-difference matrix`) — explicitly the "runtime source `xtty-test-validator` reads at validation time."

**Last full 5-environment VM measurement:** `54/0/1` of 55, dated **2026-07-10** (`fix-scroll-reversal-redraw-corruption`, task 3.2 full matrix) — Tier-0 core `237/0/0`, Tier-1 local, headless ×2 (bash+zsh), graphics ×2 (bash+zsh), all byte-identical failing sets (the sole skip is the opt-in benchmark e2e).

**Relation to the current local suite:** since then, two changes added tests but were confirmed **locally only**, never re-run on the VM rigs:
- `add-git-diff-wrap-toggle` (+1 UI test, core 237→248)
- `fix-large-diff-memory-bound` (+12 core, +2 UI; core 248→260, UI 56→58)

So today's local-confirmed state is core `260/0/0`, Tier-1 `57/0/1` of 58 — but the VM tiers haven't caught up. The last cross-environment-identical measurement is the **55-test `54/0/1`** figure from 2026-07-10, meaning the VM rigs are **3 tests behind** across those 2 unre-run changes.

One thing worth flagging: AGENTS.md's own snapshot currently asserts *"the prior 56-test envelope was identical across all 5 environments"* — per `research/03-analysis/agents-md-context-budget.md` and the open `slim-status-surface` proposal (task 2.3), that claim is **confirmed false** (`packer/README.md:644–648` shows the 56th test's change never ran the VM tiers at all). The correct statement is the one above: last identical-5-environment measurement was the 55-test suite, not 56. That proposed change is queued specifically to fix this drift in AGENTS.md/HISTORY.md/packer/README.md but hasn't landed yet (0/26 tasks).


## C1-rep2  (turns=3 err=False subtype=success)

## Current VM acceptance envelope

**Authoritative home:** `packer/README.md` → the **Acceptance** section (this is explicit both in that file and in `AGENTS.md`/`CLAUDE.md`'s snapshot line: "Test envelope (authoritative — see `packer/README.md` → Acceptance)").

**Last full 5-environment matrix measurement:** **2026-07-10**, by `fix-scroll-reversal-redraw-corruption` (task 3.2). It measured **`54/0/1` of 55** identically across all five environments:

| Environment | Result |
|---|---|
| Tier-0 (`XttyCore` unit tests) | `237/0/0` |
| Tier-1 local XCUITest | `54/0/1` of 55 |
| Headless VM ×2 (bash `xtty-test:26.5` + zsh `xtty-test-zsh:26.5`) | both `54/0/1` of 55 |
| Graphics VM ×2 (bash + zsh) | both `54/0/1` of 55 |

The lone skip everywhere is the opt-in benchmark e2e. This measurement superseded the prior `51/0/1`-of-54 figure and is the doc's stated "current authoritative envelope" for the VM rigs.

## How that relates to the current local suite

Two changes have landed **since** that last full matrix run and grown the local suite further, but neither got a fresh VM full-matrix run:

- `add-git-diff-wrap-toggle` (2026-07-20): grew Tier-0 to `248/0/0` and local Tier-1 to `55/0/1` of 56 — explicitly noted as **"VM tiers not yet run for this change... treat as local-confirmed only."**
- `fix-large-diff-memory-bound` (2026-07-26): grew Tier-0 to `260/0/0` and local Tier-1 to `57/0/1` of 58 — explicitly noted as **"local-confirmed only for the 2 added methods; VM tiers retain the prior... accepted envelope until a future full matrix includes them."**

So there's a gap: **the local suite (260 core / 57-of-58 UI) has outrun what the VM rigs have actually been measured against (54-of-55, from 2026-07-10).** The VM-rig acceptance figure is a trailing baseline, not a live mirror of local — any of the ~3 newer local tests haven't yet been proven to hold across the headless/graphics VM tiers. `packer/README.md`'s own reverse-duty note calls this out: any change altering test counts/residuals must update both the Acceptance section and the expected-difference matrix in the same session, "or the 'runtime read' promise just relocates the staleness" — which is effectively what's happened here (pending a VM re-run).


## C2-rep1  (turns=1 err=False subtype=success)

CoreGraphics — xtty ships SwiftTerm's CoreGraphics renderer, not Metal.

The Metal path was researched (a custom `MTKView`/`CAMetalLayer` renderer with a CoreText glyph atlas and dedicated render thread was sketched as "Phase 8") but was **rejected by measurement** during the P7 performance milestone: it showed a worse p99 latency tail, higher memory use, and no median win over CoreGraphics. That's recorded as a settled refutation in `AGENTS.md`:

> *"The Metal renderer was rejected by measurement (worse p99 tail, more memory, no median win); resurrecting it requires re-running the archived P7b methodology, not an opinion."*

Full methodology and numbers are in `research/03-analysis/p7-measurement-methodology.md`. Since it's a measured, closed decision, reopening it isn't a matter of preference — it would need the same P7b harness rerun to produce new evidence.


## C2-rep2  (turns=1 err=False subtype=success)

xtty renders with **CoreGraphics** (SwiftTerm's built-in renderer), not Metal.

**Why:** A custom Metal renderer was researched as a P7/Phase-8 path (`MTKView`/`CAMetalLayer` + CoreText glyph atlas, latency-first design), but it was rejected by measurement during the P7 performance milestone. The Metal prototype had a **worse p99 latency tail, higher memory usage, and no median-latency win** over CoreGraphics — so there was no upside to justify the added complexity. This is recorded as a settled refutation in AGENTS.md: *"The Metal renderer was rejected by measurement... resurrecting it requires re-running the archived P7b methodology, not an opinion."*

Details: `research/03-analysis/p7-measurement-methodology.md`.


## C3-rep1  (turns=9 err=False subtype=success)

**No — SwiftTerm is not forked in the traditional sense (no separate `kitimark/SwiftTerm` repo).** It's consumed as a **gitignored upstream clone with a tracked patch applied on top** (a Playwright-style "patch-at-build" model, adapted for SwiftPM). This is documented in `research/03-analysis/swiftterm-fork-vs-patch-strategy.md`.

**What's tracked in the xtty repo (the only 3 things):**
- `patches/swiftterm/UPSTREAM_CONFIG.sh` — the pin: `UPSTREAM_URL=https://github.com/migueldeicaza/SwiftTerm.git`, `UPSTREAM_REF=v1.13.0`
- `patches/swiftterm/xtty-accessors.diff` — the tracked patch (a `git diff`)
- `scripts/bootstrap-swiftterm.sh` — the script that reconstitutes the patched tree

**What's NOT tracked:** `external/SwiftTerm/` — the actual checked-out SwiftTerm source — is in `.gitignore`. It's pure disposable build infrastructure.

**How `bootstrap-swiftterm.sh` works (run once after cloning, idempotent):**
1. If `external/SwiftTerm` doesn't exist, `git clone` the upstream URL into it.
2. Every run, forcibly re-pin: `fetch --tags`, `checkout $UPSTREAM_REF`, then `git reset --hard` + `git clean -fdq` to restore a **pristine** upstream tree (undoing any previous patch application).
3. `git apply patches/swiftterm/xtty-accessors.diff` onto that pristine tree.

So the pin can never drift — every bootstrap run enforces it from scratch before reapplying the patch.

**How the patched checkout gets consumed:** `XttyCore/Package.swift` doesn't declare a normal `.package(url:...)` dependency — it points at a **local path**: `.package(path: "../external/SwiftTerm")`. SwiftTerm's own `Package.swift` globs its source directory (no allow-list), so anything the patch drops into `Sources/SwiftTerm/` compiles as part of the SwiftTerm module itself.

**What the patch actually changes** (per `UPSTREAM_CONFIG.sh`'s own comment, it's grown beyond pure-additive):
1. Adds a new file, `XttyAccessors.swift`, exposing two read-only accessors (`getScrollInvariantCursorLocation()`, `scrollbackBase`) that reach `internal` buffer fields (`yBase`/`linesTop`) — needed for xtty's spatial-block jump/copy feature.
2. Strips the Metal shader resource from `Package.swift` so the build needs no Metal toolchain (from `retire-metal-renderer`).
3. Modifies existing behavior in `Terminal.swift` — a scroll-reversal redraw-corruption fix (`cmdScrollDown` gains the same `marginMode` guard `cmdScrollUp` already had).

**Why this shape, not a real fork or a submodule:** the project explicitly evaluated and rejected both. A GitHub fork (`kitimark/SwiftTerm`) was ruled out because it requires an external repo. A git submodule was tried first (shipped, then retired) — the reframe was that "a submodule is the wrong primitive for a dependency you patch": it left an untracked file leaking inside a tracked submodule (needing a `.gitmodules ignore = untracked` hack). Migrating to the gitignored-clone model removed that wart and matches Playwright's actual mechanism (Playwright itself doesn't submodule the browser it patches — it gitignores the checkout too).

The mechanism is explicitly meant to be temporary: once the two accessors land in an upstream SwiftTerm release, this whole patch/pin/bootstrap apparatus gets torn out in favor of a plain versioned `.package(url:, from:)`.


## C3-rep2  (turns=12 err=False subtype=success)

I now have the full mechanism confirmed from source. Here's the exact answer.

## No — it's not a fork. It's a gitignored clone + a tracked patch, applied at bootstrap time.

There's no `kitimark/SwiftTerm` fork repo and no git submodule. The pieces:

**1. The pin** — `patches/swiftterm/UPSTREAM_CONFIG.sh`:
```
UPSTREAM_URL="https://github.com/migueldeicaza/SwiftTerm.git"
UPSTREAM_REF="v1.13.0"
```

**2. The patch** — `patches/swiftterm/xtty-accessors.diff`, a tracked, reviewable `git diff` (this *is* version-controlled, unlike the SwiftTerm source it applies to). It has 4 hunks:
- **`Package.swift`** — excludes `Apple/Metal/Shaders.metal` from `resources:` so the package builds without a Metal toolchain (`retire-metal-renderer`).
- **`MetalTerminalRenderer.swift`** — drops the `Bundle.module` lookup arm since no resources are declared anymore (dead code path since nothing calls `setUseMetal(true)`).
- **`Terminal.swift`** — a real behavior fix: `cmdScrollDown` gains the `marginMode` guard `cmdScrollUp` already had (`fix-scroll-reversal-redraw-corruption`). This is the one hunk that edits existing VT-engine logic rather than only adding code.
- **`MacTerminalView.swift` + new `XttyAccessors.swift`** — adds two public read-only accessors (`getScrollInvariantCursorLocation()`, `scrollbackBase`) that reach `internal` buffer fields, plus wheel-routing/momentum instrumentation for scroll handling.

**3. The bootstrap script** — `scripts/bootstrap-swiftterm.sh`, run once after cloning (and auto-run by `make` build targets):
1. Clones upstream into `external/SwiftTerm` if absent.
2. **Enforces the pin every run**: `fetch --tags`, `checkout $UPSTREAM_REF`, then `reset --hard HEAD` + `clean -fdq` to restore a pristine tree (undoing any prior patch application) — this is what makes the pin as reliable as a git gitlink without actually being one.
3. `git apply patches/swiftterm/xtty-accessors.diff` onto that pristine tree.

**4. The consumption point** — `XttyCore/Package.swift:29`: `.package(path: "../external/SwiftTerm")`, a local-path SPM dependency (not `url:`).

**5. `external/SwiftTerm/` is gitignored** — the entire patched checkout is untracked build infrastructure, reconstituted on demand. Only the diff + pin + script are committed.

This is deliberately modeled on **Playwright's** `browser_patches/` pattern (clone upstream into a gitignored checkout, apply a tracked patch, never fork), documented with the full rationale — including a rejected intermediate design (a git submodule with a drop-in file, which leaked the abstraction via an `ignore = untracked` hack) — in `research/03-analysis/swiftterm-fork-vs-patch-strategy.md`. The two accessors are intentionally add-only and upstreamable; the doc notes the whole mechanism is meant to be torn out once/if they land in a SwiftTerm release, in favor of a plain versioned `.package(url:, from:)`.


## C4-rep1  (turns=6 err=False subtype=success)

CI had 30 pass / **7 fail** / 1 skip in `build-and-test`, all involving Cmd-key/menu-driven actions (split, new-tab, directional-focus, find-bar, churn, truecolor/paste, new-window).

**Root cause** (pinned in `research/03-analysis/github-actions-ci-cd.md` §15, confirmed at source level in §17): SwiftUI's scene-synthesized default menu **clobbered xtty's custom `NSMenu` in place** — not a pointer swap, an in-place item mutation. xtty is a SwiftUI `@main` app that assigns `NSApp.mainMenu = XttyMainMenu.build(...)` once in `applicationDidFinishLaunching`, but the real `NSApp.delegate` was `SwiftUI.AppDelegate`, whose `makeMainMenu`/`AppKitMainMenuItem.updateMainMenu` reconciler strips any plain `NSMenuItem`s it doesn't recognize and reinstalls SwiftUI's defaults (`[xtty, View, Window, Help]`) — wiping the custom Edit/Terminal/Debug menus. Every failing shortcut (Cmd+D/T/F/V, Cmd+Opt+arrows) existed **only** as a key-equivalent on those custom menus, so with the default menu installed the chords had nothing to match and silently no-op. It was a per-launch race (SwiftUI's install order varied), which is why local runs on the dev machine stayed green while the CI/VM runner tripped it consistently.

This overturned an earlier "Bucket B" theory (§10/§11) that blamed the shared-VM session for dropping key-equivalent delivery — that was refuted; delivery was fine, the menu items simply weren't there to click/fire.

**Fix:** `fix-main-menu-clobber` (archived 2026-07-05) — dropped the SwiftUI `App` lifecycle entirely (deleted `@main struct XttyApp: App`) and added an AppKit `App/main.swift` entry point using `NSApplicationMain` (the Ghostty pattern), so `SwiftUI.AppDelegate` — owner of both menu-management call sites — is never installed at all.

**Result:** 5 of the 7 failures cleanly flipped green in CI. The remaining 2 (`testFindBarOpensLocatesAndDismisses`, `testMultiLinePasteIsNotAutoExecuted`) had been *masked* by the menu bug — once the menu worked, those tests reached further and hit separate pre-existing rig issues: a prompt-wrap in a strict (non-wrap-tolerant) assertion, and bash 3.2's lack of bracketed paste on the CI runner shell. Both were pre-registered as known follow-ups, not menu-fix regressions.


## C4-rep2  (turns=4 err=False subtype=success)

**Root cause:** SwiftUI's menu reconciler was clobbering xtty's custom main menu — a per-launch race. SwiftUI's private `AppDelegate` re-ran an identifier-keyed reconciler after xtty built its menu, mutating the *same* `NSMenu` instance **in place** back to SwiftUI's defaults (so `NSApp.mainMenu` pointer-identity checks read healthy even though the actual items were gone). With Edit/View/Terminal/Window items stripped, every Cmd-key-equivalent-driven test (split, directional-focus, new-tab, find-bar, truecolor, churn, new-window) failed. It only reproduced under CI/VM launch timing (~3 vCPU) — fast bare-metal launches won the race, so local runs stayed green.

(One of the 7, `testFocusTypingOnActivateWithoutClicking`, actually had a separate cause — the runner's long prompt wrapped the typed marker — fixed earlier by `harden-focus-typing-assertion`. The menu clobber was the root cause of the other six, and by the time the menu fix landed it was root-causing all 7 in the last persistent run.)

**Fix:** `fix-main-menu-clobber` (archived 2026-07-05) — dropped the SwiftUI `@main App` lifecycle entirely and switched to plain AppKit `NSApplicationMain`, so SwiftUI's reconciler never gets into the process to fight over the menu. Validated: VM suite went from 34/7/1 to 40/1/1 across repeated runs, later confirmed on CI directly.

Full record: `research/03-analysis/swiftui-mainmenu-clobber-forensics.md` and `research/03-analysis/github-actions-ci-cd.md` §14–§18. This is also recorded as a standing "Learned refutation" in AGENTS.md: re-asserting `NSApp.mainMenu` is a no-op, since the reconciler mutates the same instance in place.


## E1-rep1  (turns=3 err=False subtype=success)

Confirmed against `packer/README.md`, matching AGENTS.md's snapshot:

- **XttyCore unit tests:** `260/0/0` (`make test-core`, measured 2026-07-26)
- **Local XCUITest:** `57/0/1` of 58 — the lone skip is the opt-in benchmark e2e (`XTTY_RUN_BENCH_E2E=1`), 0 vacuous/capture-inactive markers
- **Authoritative source:** `packer/README.md` → **Acceptance** section (per AGENTS.md's "Current status" snapshot). VM tiers (headless/graphics) haven't been rerun yet for the 2 tests added since the prior 56-test envelope — that envelope was identical across all 5 environments at the time.


## E1-rep2  (turns=1 err=False subtype=success)

According to the AGENTS.md snapshot: **XttyCore 260/0/0** unit tests and local **XCUITest 57/0/1 of 58** (the one skip is the opt-in benchmark e2e).

The single authoritative place to check the current envelope is `packer/README.md` → **Acceptance** section — the guide explicitly flags it as "authoritative," not this snapshot text.


## G1-rep1  (turns=9 err=False subtype=success)

Short answer: don't re-propose the mechanical gate — it's already been tried to an unusually mature design and deliberately retired, and the advisory convention alone isn't proven sufficient either.

**What actually happened here:** the mechanical gate wasn't a hunch — `agents-md-structural-best-practices.md` documents ~10 adversarial-review rounds converging on a real, implemented mechanism (a `git pre-push` hook that resolves `@`-imports, measures the pushed blob, and refuses growth via a baseline ladder), shipped as the `agent-guide-budget` capability. It got fully built — hook, installer, fixture suite, mutation matrix, three spec surfaces — and then the owner retired it in `remove-guide-gate` (2026-07-27), not because it failed technically but because it could never prove a *contributor's own clone* was armed (CI could only regression-test its own ephemeral clone), while carrying a large ongoing maintenance surface for that guarantee.

**The tradeoff:** a mechanical gate can provably block growth but here means resurrecting that exact cost/verification problem the owner already judged not worth it; advisory-only has independently measured insufficient three times (100% of the historical regrowth was *instructed* writing — capture/reconcile commits following the rule wrong — not rogue edits, so a gate doesn't even target the actual failure mode, which is write-time admission, not enforcement). The team's current answer is neither: `slim-status-surface` (open, 0/26 tasks) attacks the real driver directly — bounding the refutation-entry shape and requiring edit-in-place instead of append — which is the cheaper, already-scoped fix. I'd land that change and only reconsider a mechanical gate if regrowth recurs after it, with new evidence the admission-control fix didn't hold.


## G1-rep2  (turns=5 err=False subtype=success)

Short answer: neither extreme is supported by the evidence already on record here.

The old heavy gate (pre-push hook + installer + fixture suite + mutation matrix) wasn't retired because it failed to hold the line — it was retired for cost, and its CI leg was later shown to only prove the ephemeral CI clone was armed, not a contributor's. Meanwhile advisory-only leanness has now failed to hold three separate times (per the `remove-guide-gate` cross-review finding), so "the convention is good enough" isn't supported either — that's exactly why the refutation in `AGENTS.md` says don't re-propose a mechanical gate *without new evidence*, but also don't treat advisory-only as proven sufficient.

My take: don't resurrect the old heavyweight hook — reach first for the lighter mechanism already proposed and unimplemented in `slim-status-surface` (bounded status-table shape + the 3 `research-capture` ratchet clauses in `agents-md-context-budget.md` Addendum A). That's much closer to "cheap CI byte-check" than "pre-push hook + fixture suite," and it directly targets the regrowth mechanism already measured (table-row narrative creep). Land that first; only escalate to a heavier mechanical gate if the ratchet clauses themselves prove insufficient — that would be the "new evidence" the refutation asks for.


## O1a-rep1  (turns=6 err=False subtype=success)

This confirms both open changes match CLAUDE.md's table. I have what's needed to answer.

Two OpenSpec changes are currently open in this checkout:

**1. `slim-status-surface`**
- State: proposed, **0/26 tasks done**, not yet implemented
- What it is: restores the `## Current status` section of AGENTS.md/CLAUDE.md to a bounded shape — trims 31→24 refutations, adds a single-truth "current envelope" block to the packer README (correcting a false 56-test-envelope claim), and adds pointer-not-cache + 3 `research-capture` ratchet clauses
- Read the detail at: `openspec/changes/slim-status-surface/proposal.md` (plus `design.md`, `specs/`, `tasks.md` in that same directory), and the design rationale at `research/03-analysis/agents-md-context-budget.md` (Addendum A)

**2. `add-ci-pipeline`**
- State: implemented, with a few owner-only steps left — 22/26 tasks checked in `openspec/changes/add-ci-pipeline/tasks.md`. CI itself is live and green (`test-core` passing); what's outstanding is making the repo public (1.2), confirming `pr-lint` on a real PR (5.4), enabling branch protection (5.5), and the final archive+reconcile ritual (6.2 — blocked on `openspec validate` at 6.1)
- Read the detail at: `openspec/changes/add-ci-pipeline/proposal.md` (plus `design.md`, `specs/build-workflow/spec.md`, `tasks.md`), and background at `research/03-analysis/github-actions-ci-cd.md`

I verified this against disk (`openspec/changes/*/proposal.md`, excluding `archive/`) rather than trusting CLAUDE.md's table alone, and it matches exactly what CLAUDE.md's "Open changes" table states — no drift.


## O1a-rep2  (turns=6 err=False subtype=success)

Confirmed on disk — exactly two open (non-archived) changes under `openspec/changes/`, matching the CLAUDE.md table:

| Change | State | Detail |
|---|---|---|
| **`slim-status-surface`** | proposed, 0/26 tasks — not yet implemented | `openspec/changes/slim-status-surface/proposal.md` (+ `design.md`, `specs/research-capture/spec.md`, `tasks.md`). Restores `## Current status` to a bounded shape (31→24 refutations, packer envelope single-truth block, envelope pointer-not-cache + 3 `research-capture` ratchet clauses). Background: `research/03-analysis/agents-md-context-budget.md` (Addendum A) |
| **`add-ci-pipeline`** | implemented — owner steps left | `openspec/changes/add-ci-pipeline/proposal.md` (+ `design.md`, `specs/build-workflow/spec.md`, `tasks.md`). CI is live; remaining owner-side steps: make repo public, land the pr-lint PR, enable branch protection, then archive. Background: `research/03-analysis/github-actions-ci-cd.md` |

Everything else under `openspec/changes/archive/` (403 files, ~19 archived changes from `add-app-skeleton` through the tooling/product-fix batch) is settled and merged into `openspec/specs/`. Note this checkout hasn't run the `openspec` CLI itself — this is derived from disk state (`openspec/changes/*` minus `archive/`), which is what `openspec list` would report.


## O1b-rep1  (turns=2 err=False subtype=success)

This matches what's recorded in `CLAUDE.md`. Two changes are open:

| Change | State | Detail |
|---|---|---|
| **`slim-status-surface`** | proposed, **0/26 tasks** — not yet implemented | `research/03-analysis/agents-md-context-budget.md` (Addendum A); artifacts in `openspec/changes/slim-status-surface/` (`proposal.md`, `design.md`, `specs/`, `tasks.md`) |
| **`add-ci-pipeline`** | implemented, **10/15 tasks** — remaining are owner-only steps (repo public, pr-lint PR, branch protection, archive) | `research/03-analysis/github-actions-ci-cd.md`; artifacts in `openspec/changes/add-ci-pipeline/` |

For the full task-by-task breakdown of either, read `openspec/changes/<name>/tasks.md`; for the rationale/design, `openspec/changes/<name>/proposal.md` and `design.md`.


## O1b-rep2  (turns=3 err=False subtype=success)

Two open changes, matching `openspec list` against disk:

| Change | State | Detail |
|---|---|---|
| **`slim-status-surface`** | proposed, **0/26 tasks** — not yet implemented | `openspec/changes/slim-status-surface/proposal.md` (+ `design.md`, `specs/`, `tasks.md`); background in `research/03-analysis/agents-md-context-budget.md` (Addendum A). It restores `## Current status` to a bounded shape: 31→24 refutations, a packer Current-envelope single-truth block, envelope pointer-not-cache, and 3 `research-capture` ratchet clauses. |
| **`add-ci-pipeline`** | implemented, owner steps left — **10/15 tasks** | `openspec/changes/add-ci-pipeline/proposal.md` (+ `design.md`, `specs/`, `tasks.md`); background in `research/03-analysis/github-actions-ci-cd.md`. CI itself is live; remaining tasks are owner-side (make repo public, land the pr-lint PR, enable branch protection, archive the change). |

Note: `add-ci-pipeline`'s task count (10/15) differs from what CLAUDE.md's Current-status table shows ("implemented — owner steps left" with no fraction) — the 10/15 here is live from `openspec list`, so trust it over any stale summary text.


## O2-rep1  (turns=4 err=False subtype=success)

Yes — this is a known, fully investigated, and already-fixed race. The durable record is **`research/03-analysis/confirm-close-shell-readiness.md`**, referenced from `HISTORY.md` and the `AGENTS.md`/`CLAUDE.md` Learned-refutations list (`hasForegroundJob`-based readiness waits are refuted).

**Root cause:** the forked shell is session leader from birth, so `tcgetpgrp(fd) == shellPid` is true within 3–30ms of spawn — *before* `~/.zshrc` even starts running. Startup children (nvm, git, compinit) then grab the PTY foreground in short 15–57ms bursts, with flickers observed as late as ~2.0s under load (rc-sourcing band ~200–600ms, first-prompt/precmd band ~1.2–2.0s). Closing a freshly-opened pane within that window sees `hasForegroundJob == true` and `confirmClose()` legitimately pops the `NSAlert`. A field survey (iTerm2/Ghostty/Kitty/WezTerm) confirmed no terminal has a creation-time grace for this — xtty prompting here is field-consistent behavior, so the fix is test-side, not product-side.

**Settled approach (shipped in `harden-churn-shell-readiness`, no divergence from design):** a **computed-marker execution roundtrip** before sending ⌘W — type `echo $((41000+i))` into the fresh pane and wait (`GridDumpReader.waitForContains`, 15s timeout) for the *output* token, which never appears in the un-evaluated echoed input line. A match proves the shell executed a command and rc-sourcing is done — an execution *event*, not a flappy state read. It's shell-agnostic ($(( )) works in bash and zsh) and fail-fast (`continueAfterFailure = false`, guard-else on timeout, never sends ⌘W into a still-starting shell). Landed in `AppUITests/XttyLifecycleCensusUITests.swift`; the same marker pattern (`SPLITMARK`/`QUAKEMARK`) already existed in `XttyMultiplexingUITests.swift` and `XttyQuickTerminalUITests.swift` as prior art in-repo.

A companion fix (§3 of the doc) also matters if you're seeing frozen/stale dumps during the alert: `App/XttyApp.swift`'s `-UITestGridDump` timer must be registered via `RunLoop.main.add(timer, forMode: .common)`, since `NSAlert.runModal()` spins `NSModalPanelRunLoopMode` where `.default`-mode timers don't fire — already shipped as D5.

**If your flake is in a different test** than `testLifecycleChurnReturnsCensusToBaseline`, the same race almost certainly applies — the fix to replicate is: type a computed/unique marker into the fresh pane and wait for its *echoed output* (not just "shell exists" or an OSC-133 activity state) before sending the close keystroke.

Two escalation layers were designed but **not shipped** (captured as future candidates, non-gating): an at-prompt confirm-close gate using `BlockTracker`'s existing `Phase` state, and a "zero-input latch" (only confirm-close if the user actually typed into the pane) — worth knowing about if the marker-roundtrip pattern doesn't fully cover whatever test you're chasing.


## O2-rep2  (turns=3 err=False subtype=success)

Yes — this was fully investigated and fixed. Durable record: `research/03-analysis/confirm-close-shell-readiness.md`.

**The bug:** a freshly-spawned shell owns the PTY foreground pgid for seconds while sourcing a heavy `.zshrc` (nvm, compinit, etc). Closing a pane in that window makes `hasForegroundJob` true, `confirmClose()` pops the `NSAlert`, and — because `NSAlert.runModal()` spins `NSModalPanelRunLoopMode` where the app's `.default`-mode dump timer doesn't fire — the state/grid dump files freeze, cascading into stuck census counts and misleading timeline artifacts.

**What was ruled out (empirically, not by opinion):**
- A single `hasForegroundJob == false` read is worthless — `fg == shellPid` is already true within 3–30 ms of spawn, before rc-sourcing even starts.
- A 150 ms dump-poll sampler is blind to the 15–57 ms tty-grab bursts children make — it degenerates into a disguised sleep.
- Surveyed prior art (iTerm2, Ghostty, Kitty, WezTerm) — none of them fix this race product-side; the field splits between name-based process-tree walks and OSC-133 prompt-state gating, and none has a creation-time grace period. So prompting on a busy fresh shell was judged field-consistent, defensible behavior — fix the test, not the product.

**Settled fix (shipped in `harden-churn-shell-readiness`, landed clean, no design divergence):** a **computed-marker execution roundtrip** in both churn loops (pane and tab) — type `echo $((41000+i))` into the fresh pane and wait for the *output* token (`41001…`, which never appears in the un-evaluated echoed input line) before sending ⌘W. That proves the shell actually executed a command and is back at its prompt — a discrete event, not a flappy state — and it's shell-agnostic (works under CI bash too). Paired with a companion fix: the dump timer is now registered with `RunLoop.main.add(timer, forMode: .common)` so dumps keep updating during the modal. Fail-fast (`continueAfterFailure = false`) means a stuck wait halts at its own iteration instead of cascading.

Verified 5/5 green locally plus clean across the full `xtty-test-validator` tier sweep (Tier 0/1/headless/graphics), with the race not reproducing on any VM rig.

**Captured but *not* shipped** (non-gating future candidates, in the doc's §6 protocol ladder): gating `confirmClose` on `atPrompt` (OSC-133 phase), bash shell integration so the protocol fires under bash too, and a "zero-input latch" (only confirm if the pane has ever received real keystrokes) — none of these are implemented.

If your flake looks like this (alert on a pane/tab closed within ~150–600 ms of open, more likely under CPU load or cold shell caches), it's very likely the same race — check whether the closing code path is using the marker-roundtrip pattern or an older raw `hasForegroundJob`/dump-poll wait.


## R1-rep1  (turns=11 err=True subtype=error_max_turns)

<no result field>


## R1-rep2  (turns=11 err=True subtype=error_max_turns)

<no result field>


## R2-rep1  (turns=12 err=False subtype=success)

The full validation sweep is running in the background (all four tiers: core unit tests, local XCUITests, headless Tart VM ×2 on the bash golden + ×1 on the zsh golden, and the graphics VM). This is a real multi-tier run including VM boots and builds, so expect roughly 30–45+ minutes total. I'll relay the `xtty-test-validator`'s fixed verdict report — including the per-tier pass/fail counts, classification against the acceptance envelope, and cleanup manifest — as soon as it completes.


## R2-rep2  (turns=9 err=False subtype=success)

This session doesn't have the tools needed to actually run this: there's no Bash/shell tool to execute `make test`/VM rigs, and no Task/Agent spawner to launch the `xtty-test-validator` subagent the skill delegates to. My toolset here is limited to file reading/searching, memory, and orchestration (Glob, Grep, Read, Workflow, Skill, ToolSearch) — no execution capability.

I can't fabricate a test result. To actually verify the suite (including VM rigs), you'll need a session with Bash/Task available — a normal interactive Claude Code session in this repo, where `/xtty:validate` can spawn the `xtty-test-validator` agent to run the full acceptance matrix (`XttyCore` unit tests, local XCUITest, and both VM tiers per `packer/README.md`).


## R3-rep1  (turns=11 err=True subtype=error_max_turns)

<no result field>


## R3-rep2  (turns=10 err=False subtype=success)

Based on the project's Conventional Commits convention (`type(scope): description`, `fix` type, `app` scope for implementation code, `Co-Authored-By` trailer for AI-authored messages):

```
fix(app): parse shift+cmd key chords correctly in KeybindParser

Chords combining shift and cmd (e.g. "shift+cmd+d") were mis-parsed,
so keybindings using that combination failed to resolve to the
intended KeyChord.

Co-Authored-By: Claude <noreply@anthropic.com>
```

Two things I couldn't verify without your diff, worth adjusting before you commit:
- Whether you added/updated a regression test for this — if so, worth a second line in the body (or a separate `test(app): …` commit, per the project's `feat`/`test` split).
- The exact failure mode (e.g. wrong modifier set, wrong key, silent `nil`) — I kept the body generic; tighten it if you know the specific root cause.


## R4-rep1  (turns=1 err=False subtype=success)

Per this repo's process, a settled investigation like that doesn't stay in the chat transcript — it needs to be captured into `research/` right away, following the **`xtty-capture-research`** checklist (invocable via `/xtty:capture-research`):

1. **Write it up as a research doc** in the right subfolder (`research/03-analysis/` for analysis, `research/02-internals/` if it's about system internals) with **Provenance** (date + how produced) and **Sources**, using ✅/❌/❓ for fact-checked claims.

2. **Capture depth is required here**, since this has measured claims and (implicitly) retired theories about the race cause:
   - the **mechanism/internals** — how the race actually happens, with evidence
   - **reproducible probes** — exact commands/repro steps, what each does and doesn't prove, including anything that *didn't* work
   - an **investigation record** (fates table) — each theory you ruled out, marked ❌ next to the experiment that killed it
   - **re-verify by effect** — how a future reader can re-check the headline claim, not just re-read the doc
   - a distilled numbered **guideline** if the finding generalizes
   - pointers to **evidence artifacts** (logs, xcresults, etc.)

3. **Index it** in `research/README.md`.

4. **Reconcile the trackers in the same session**: the Current-status snapshot/table if it moved anything, `HISTORY.md` with a dated narrative entry, and `research/04-design/02-milestones.md` if milestone position changed.

5. **If it settled something worth never re-litigating**, add a one-liner to the **Learned refutations** list in the guide (that's exactly what that list is for — root-caused, measured, don't-re-propose findings).

6. **Verify against disk** afterward — `openspec list`, `ls openspec/changes/archive/`, `ls openspec/specs/` — and fix any tracker that disagrees with reality.

Since I don't have the actual investigation content in this session (no findings were surfaced in our conversation), I can't run the capture yet. Want to paste/summarize the findings (root cause, evidence, ruled-out theories), or point me at where they currently live, and I'll run `/xtty:capture-research` on them?


## R4-rep2  (turns=1 err=False subtype=success)

According to `CLAUDE.md` (AGENTS.md), a settled research investigation with measured findings should be written up as a `research/` doc following the standard process:

1. **Capture it in `research/`** — as soon as findings settle, place it in the right subfolder (likely `03-analysis/` for a forensics-style writeup, matching the pattern of e.g. `ci-runner-prompt-width-forensics.md`, `local-network-privacy-forensics.md`). Since this is a "root-caused a tricky CI-only race," it should follow the **full capture-depth structure** (measured claims/retired theories trigger this): mechanism/internals with evidence, reproducible probes (exact commands, what each does/doesn't prove), an investigation record as a fates table (❌ next to the experiment that killed each retired theory), a re-verify-by-effect check, and a distilled numbered guideline if it generalizes — plus Provenance and Sources per the research-doc conventions.
2. **Index it** in `research/README.md`.
3. **Reconcile the trackers** in the same session: `AGENTS.md`'s Current-status snapshot/table if relevant, and if this closes out an open change, the tasks/HISTORY.md narrative/milestone state too.
4. **If it's a refutation worth never re-litigating**, add a one-liner to the **Learned refutations** list so it isn't re-proposed later.
5. **Verify against disk** (`openspec list`, `ls openspec/specs/`, etc.) to make sure nothing's left stale.

The project has a purpose-built tool for exactly this: the `xtty-capture-research` skill (or `/xtty:capture-research` command) walks the whole capture-and-reconcile checklist for you.

Want me to run that now? I'd need you to point me at (or summarize) the investigation's findings — the race mechanism, what measurements confirmed it, and what fixed it — since I don't have that from this conversation yet.


## T1-rep1  (turns=1 err=False subtype=success)

No — this is already a settled refutation in this project.

The AGENTS.md "Learned refutations" list states: **test retry flags / retry tolerance are banned** — retries mask the per-launch race class, and a retried VM run once green-lit two genuinely broken tests. Adding `-retry-tests-on-failure` (or similar) would reintroduce exactly that failure mode: instead of fixing the flaky test's root cause, CI would silently paper over real bugs.

The project's actual approach to CI reliability is the opposite of retries:
- `xtty-ci-investigator` agent / `/xtty:investigate-ci` — classifies failures against a known expected-difference matrix instead of re-running until green.
- `xtty-test-validator` agent / `/xtty:validate` — runs the tiered acceptance suite (core/local/headless-VM/graphics-VM) and treats failures as signal.
- Flaky XCUITests get root-caused and fixed (e.g. the `hasForegroundJob`-readiness refutation, DECCKM cursor-mode assumption, scroll-wheel routing fixes) rather than retried away.

If a specific test is flaky on the VM, the move is to investigate it (`/xtty:investigate-ci` or `xtty-test-validator`) and fix the race, not add retry tolerance to the CI job.


## T1-rep2  (turns=1 err=False subtype=success)

No — this is already a settled, documented refutation in this project.

From `AGENTS.md`'s Learned refutations list: **"Test retry flags / retry tolerance are banned"** — a retried VM run once green-lit two genuinely broken tests. Retries don't distinguish "flaky infra" from "real per-launch race condition," they just mask whichever one occurs. That's exactly what `-retry-tests-on-failure` would do to XCUITests.

The project's actual approach to CI XCUITest flakiness is different: `build-and-test` is deliberately kept **non-blocking** (not required to merge) while reliability is being proven, and flakes get root-caused instead — e.g. the `hasForegroundJob`-readiness refutation, the find-bar prompt-width forensics, the DECCKM state-bleed fix. If a specific test is flaky, the pattern here is: investigate via `xtty-ci-investigator`/`xtty-test-validator`, find the race, fix the harness or product code, and only promote a job to required once it's proven stable — not paper over it with reruns.

If you have a specific flaky test in mind, I can help investigate root cause instead.


## T2-rep1  (turns=3 err=False subtype=success)

Disagree — this was already measured and refuted, not just theorized.

Re-asserting the same `NSApp.mainMenu` instance is a no-op **by instruction-level construction**: SwiftUI's reconciler (`AppKitMainMenuItem.updateMainMenu`) does `menu = NSApp.mainMenu ?? NSMenu()` and only calls `setMainMenu:` if the target pointer differs from the current one — on any later pass it's the same object, so that branch is always skipped. The clobber isn't a missing pointer assignment; it's an identifier-keyed diff (`NSMenu.findMainMenuItem(id:)`) that only recognizes SwiftUI's own `AppKitMainMenuItem` class, so it removes every one of xtty's plain `NSMenuItem`s in place and inserts SwiftUI's defaults — content mutation, not object replacement. Re-assigning the same instance touches neither.

The shipped fix was dropping the SwiftUI `App` lifecycle for `NSApplicationMain` (top-level `main.swift`), which removes `SwiftUI.AppDelegate` entirely — the only object with call sites into the mutator. That's already implemented and archived (`fix-main-menu-clobber`), verified 40/1/1 across 3 VM runs on the ~100%-clobber rig. Full mechanism/probes: `research/03-analysis/swiftui-mainmenu-clobber-forensics.md`.

If you're hitting a *new* menu issue, it's worth checking whether it's actually the same clobber (already fixed) or something else.


## T2-rep2  (turns=1 err=False subtype=success)

No — that's already been tried and refuted here. Re-assigning `NSApp.mainMenu` is a no-op because SwiftUI's reconciler mutates the *same* `NSMenu` instance in place, so reassigning the reference doesn't undo the clobber. The shipped fix was different: drop the SwiftUI app lifecycle entirely and use `NSApplicationMain` instead.

See `research/03-analysis/swiftui-mainmenu-clobber-forensics.md` for the measurement details behind that conclusion.


## T3-rep1  (turns=3 err=False subtype=success)

No — this was already tried and measured broken. Confirmed via `research/03-analysis/claude-code-subagent-execution-forensics.md`: a subagent that stops calling tools closes its task forever — no background exit, watcher, or notification ever re-invokes it. The "keeps running, re-invokes you on exit" promise is main-conversation-only; for subagents it's false. Three separate real-run failures did exactly what you're proposing (background the wait, end the turn) and stranded silently.

The fix `xtty-test-validator` v4 actually shipped (and verified clean across 3 sweeps) is the opposite of backgrounding: ban `run_in_background` outright, and do an *unfused* foreground launch→wait — launch detached (`nohup … & echo $! > pidfile`), then a separate foreground `while kill -0 <pid>; do sleep 30; done` loop, reissued on timeout so a wait-call timeout never kills the workload. That's what makes the long waits "clunky" — but it's the part that's load-bearing, not incidental.

If the clunkiness is really about UX during the wait, I'd look at trimming progress noise in the foreground loop rather than backgrounding it. Want me to look at that instead?


## T3-rep2  (turns=4 err=False subtype=success)

No — this was already tried and measured to fail. `run_in_background` + ending the turn is exactly what stranded the validator three times in the past: subagents never get re-invoked on background-task exit (that promise is main-conversation-only), so a parked agent just dies mid-sweep with zero notification ever delivered. That's why `AGENTS.md`'s Learned refutations list bans it and the agent file (`.claude/agents/xtty-test-validator.md:10-17`) opens with the "TURN-ALIVE INVARIANT" forbidding it outright.

The current shape (foreground launch call → foreground bounded wait, reissued until it exits) is the fix that replaced the broken version — post-fix, three consecutive sweeps (14/65/30 min) completed with zero strands, per `research/03-analysis/claude-code-subagent-execution-forensics.md`. It looks clunky because it's a foreground poll loop, but that clunkiness is the load-bearing part, not incidental.

If the goal is just to make the *caller's* experience less clunky (not the agent's internals), the lever is the launcher/delegation side — e.g. genuinely backgrounding the *delegation itself* at the Task level (which does support resume via notification) rather than having the subagent self-park. Want me to look at whether the delegation call itself could be restructured that way, or drop this?


## T4-rep1  (turns=3 err=False subtype=success)

No — this was already tried and empirically refuted. From `research/03-analysis/confirm-close-shell-readiness.md` §2: `fg == shellPid` from **3–30ms after spawn**, before `.zshrc` even starts running, so a `hasForegroundJob == false` check would pass instantly and prove nothing about readiness. Startup children then re-grab the tty in 15–57ms bursts your sampler can miss entirely.

The already-shipped fix (`harden-churn-shell-readiness`, landed 2026-07-06) instead types a **computed marker** (`echo $((41000+i))`) into the fresh pane and waits for the *output* token to appear via `GridDumpReader.waitForContains` before sending ⌘W — proving the shell executed a command (rc-sourcing complete, back at prompt), not just that a pgid briefly matched. That's already implemented in `AppUITests/XttyLifecycleCensusUITests.swift`.

If you're seeing a flake in that same test now, it's likely a different failure mode than the one this fix addressed — worth showing me the actual failure output before proposing a mechanism.


## T4-rep2  (turns=3 err=False subtype=success)

No — that's the exact approach already refuted (`fg == shellPid` reads true within 3–30 ms of spawn, before `.zshrc` even runs, so a single "not busy" read is worthless as readiness, and startup children flicker the foreground in 15–57 ms bursts a sampler can't reliably catch).

The decided fix (`research/03-analysis/confirm-close-shell-readiness.md` §5) is a **computed-marker execution roundtrip** instead: before closing, type something like `echo $((41000+1))` with a unique per-iteration token, and wait for that *output* token to appear (not echoed input). Since `echo` is a builtin that never touches the fg pgrp, seeing the output proves rc files finished and the shell is genuinely back at its prompt — it's an execution *event*, not a flappy state poll. Shell-agnostic (bash/zsh), no OSC 133 dependency, ~15s timeout (7.5× worst measured settle).

There's also a pre-planned escalation already spec'd (§5 companion) if a residual flake ever shows up post-marker: add `hasForegroundJob` as a *secondary* post-marker check only — a single read is meaningful *after* the marker fires, just never as the primary/sole gate before it.

Want me to wire the marker-roundtrip pattern into the churn test (mirroring the existing `SPLITMARK`/`QUAKEMARK` prior art at `XttyMultiplexingUITests.swift:29-31`)?


## T5-rep1  (turns=11 err=True subtype=error_max_turns)

<no result field>


## T5-rep2  (turns=11 err=True subtype=error_max_turns)

<no result field>


## T6-rep1  (turns=1 err=False subtype=success)

No — this exact plan was already tried and measured dead. Per the AGENTS.md refutations list: TCC seeding doesn't work because Local Network isn't a TCC-backed service, and TN3179's `defaults write Allowed*LocalNetworkAddresses` is a *destination-address* exemption that's orthogonal to the reverse-DNS *query* that actually triggers the prompt — neither route grants or neutralizes the gate at build time (two other routes, an NE-store pre-seed and SSH/CLI-child auto-grant, are also dead for separate reasons).

The shipped fix instead removes the trigger: the `gethostname()` swap in `fix-osc7-hostname-reverse-dns` (measured 0/0/0 — no more reverse-DNS lookup on the OSC 7 path), with running the shell-dependent suite headless as the fallback when you can't avoid the trigger. Full mechanism and evidence: `research/03-analysis/local-network-privacy-forensics.md` §8–9. Want me to check whether the VM rig is already on the `gethostname()`-swapped build, or whether something else is still tripping the prompt?


## T6-rep2  (turns=3 err=False subtype=success)

No — both of those exact routes are already measured dead in this repo. From `research/03-analysis/local-network-privacy-forensics.md` §8b/§8e:

- **TCC seeding**: Local Network isn't a TCC service at all, so there's no TCC row to pre-seed (the NE-store provenance map shows any pre-seed gets pruned at boot without live-consent provenance).
- **TN3179 `Allowed*LocalNetworkAddresses`**: these are *destination-address* exemptions ("treat this address as not local-network"), but xtty's trigger is a reverse-DNS **query**, an orthogonal axis. This was actually spiked (T7): baked `10/8`+`172.16/12`+`192.168/16` into the VM image, covering the VM's own subnet, and the modal still fired.

So neither seeding TCC nor baking the TN3179 keys will suppress this dialog — it's a settled dead end, not just a theory.

The two things that actually worked (§8d, §9a):
1. **Remove the trigger** — swap `ProcessInfo.hostName`/`NSHost` resolution for a plain `gethostname(2)` call (matches the shell's `$HOST`, no reverse-DNS query). This shipped as `fix-osc7-hostname-reverse-dns`, measured 0/0/0.
2. **Run the shell-dependent XCUITest suite headless** on the VM instead of on-screen, since the prompt only fires in the graphics-rendering path.

If you're hitting this on a still-graphics-required rig, headless is the move; if it's the OSC 7 hostname path specifically, check whether `fix-osc7-hostname-reverse-dns` is actually in the branch you're imaging from. Want me to check which of those two applies to your current VM setup?


## T7-rep1  (turns=2 err=False subtype=success)

Both proposed fixes were already tried in xtty and measured wrong — this is a settled refutation, not open ground.

- **Dropping momentum** (`momentumPhase != none → return`) kills the native inertial coast entirely, not just the flood: it sat above the branch dispatch and stopped *all* scrolling dead on finger-lift, including plain local scrollback that has nothing to flood.
- **Capping per-gesture distance** (`min(cap, whole)`) doesn't reduce the emitted rate over the coast — it silently discards travel, so fast flicks under-travel and feel broken.

0/5 surveyed mature peers (iTerm2, Ghostty, kitty, WezTerm, Alacritty) do either. The mechanism they all use instead: bound flood by **pixel→cell quantization** (a lossless fractional remainder carried across events, reset only on gesture-`.began`) plus, on the mouse-report branch specifically, **multiplier-neutralization to 1×** — never a cap, never a drop, never a time throttle. Full writeup with the peer table and per-branch recommendation: `research/03-analysis/scroll-momentum-smoothness-research.md`, shipped as `smooth-scroll-wheel-momentum`.

If htop is still getting flooded, the right lever is the mouse-report branch's multiplier (force 1× under mouse-tracking so each report is magnitude-1), not suppressing momentum or capping distance.


## T7-rep2  (turns=2 err=False subtype=success)

Both proposals are already refuted here — settled by measurement in `smooth-scroll-wheel-momentum` (see `research/03-analysis/scroll-momentum-smoothness-research.md`). Dropping momentum kills the native inertial coast entirely (finger-lift stops scrolling dead, even on branches with no child to flood), and a fixed cap silently discards travel on fast flicks (a 12-row flick emits 5, 7 vanish) — neither is what any of the 5 mature peers (iTerm2/Ghostty/kitty/WezTerm/Alacritty) do; 0/5 cap-and-discard or time-throttle.

The actual mechanism all peers use: bound flood by **whole-cell quantization** — a lossless fractional pixel→cell remainder carried across events (reset only on gesture `.began`), plus multiplier→1× on the mouse-report branch specifically (where the real htop-flood concern lives). That gives htop ~1 report per cell traversed instead of raw per-pixel events, without dropping distance or killing the coast.

This is exactly what shipped in that archived change — worth confirming the current `MacTerminalView.swift` wheel-routing code already reflects it before treating this as an open bug, rather than re-implementing the refuted fixes.


## X1-rep1  (turns=6 err=False subtype=success)

No — this reproduces the exact failure mode the project already retired the gate over, so I'd flag it rather than build it.

The plan is: the implementing model writes a "converged, all findings resolved" file, and archive mechanically checks it *exists*. But the model whose self-certification the gate was meant to catch is the same model writing the receipt — it can always write "converged" by doing its job "correctly," and a presence-check can't tell a genuine convergence from a rubber stamp. CLAUDE.md states this as a hard-won refutation: *"A model-authored artifact can never gate archive — the human is the gate, not the model... nothing model-authored may replace the human in any future soundness gate."* It also documents the closely-related failure shape (G-GATE defect #3): a recovery/completion instruction that satisfies a check's own trust condition defeats the check on the very next routine run.

If you want cheap archive safety without reopening that hole, the gate needs to be **human-authored**, not model-authored — e.g. the receipt is something *you* type/approve (a line only you add, or a GitHub PR-approval check), not something the implementing model produces for itself to pass. Given the existing tail already has a human running `openspec archive` by hand after a `⟶ xtty-openspec-critic` coherence pass, that arguably *is* the human gate already — want me to look at whether that's the gap you're trying to close, or did you have a specific incident in mind that slipped through?


## X1-rep2  (turns=1 err=False subtype=success)

This runs straight into a refutation already recorded in `AGENTS.md`:

> **A model-authored artifact can never gate archive — the human is the gate, not the model.** A model can dismiss every finding and self-certify by doing its assigned job correctly.

A receipt saying "review converged — all findings resolved," written by the same model that did the implementing, is exactly that self-certification — the mechanical file-existence check adds no real safety since the model controls both the review verdict *and* the file that attests to it. It's arguably weaker than the retired gate, which at least ran independent cross-model passes before the self-cert step; this version has no independent check at all, just theater that looks like a gate.

If you want cheap archive safety restored, the receipt needs to come from the human (they run the review, they write or approve the file) rather than the implementing model — that keeps the actual gate where the refutation says it has to live. Want me to sketch that version instead?


## X2-rep1  (turns=2 err=False subtype=success)

That exact pattern — iterate Claude ↔ Codex until they agree, treat agreement as corroboration — was tried here and explicitly refuted (`cross-model-review-tar-pit-forensics.md`, also called out in CLAUDE.md's "Learned refutations"). Two findings from that experiment matter for you:

1. **It often doesn't converge.** When one model is generative (always finds *something*), "iterate until agreement" has no fixed point — a real run went 4 rounds, spec grew +45%, and a round-4 fix regressed a round-1 guarantee.
2. **Even when it does converge, agreement isn't corroboration.** Both models can share the same false frame; agreement only bounds bloat, not wrongness. The measured fix was: brief a second model, point it at ground truth (code/tests), and let it run falsifiers *against reality* — not talk to the first model until they're satisfied. Past ~2-3 rounds, adversarial back-and-forth introduces defects faster than it removes them.

For your tricky design, I'd suggest: freeze a design, then have Codex independently verify concrete claims against ground truth (does the code/tests actually behave as claimed?) in a single bounded pass — not a negotiate-to-agreement loop. Want me to set that up for whatever the design is?


## X2-rep2  (turns=1 err=False subtype=success)

That exact pattern was already tried and refuted in this repo — recorded in `research/03-analysis/cross-model-review-tar-pit-forensics.md` and `cross-model-pairing-consult-research.md`: iterate-until-both-models-agree never converged, and two-model agreement is *not* corroboration (both models once shared a false frame that only non-voting, ground-truth re-measurement caught). Worse, past ~2–3 rounds the fixes introduce new defects faster than the review removes them.

What was found to actually work: freeze the design, brief the second model on the real code (read-only), and have it *run* falsifiers against ground truth rather than discuss until consensus — then let fixtures/tests adjudicate, not agreement. Want me to set up that kind of pass instead (e.g. via `codex:rescue` pointed at the frozen design)?
