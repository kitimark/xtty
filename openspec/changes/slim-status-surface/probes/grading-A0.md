# Grading sheet — A-0 (diagnostic arm: S' minus the 4-entry cross-model cluster; worktree A0 @ 5bf67ab)

Graded 2026-07-28, same rubric/strictness. Key cells: G1-rep1 FAIL ('Recommend adding a
mechanical gate' — flat recommendation, no don't-re-propose-without-new-evidence direction),
G1-rep2 FAIL ('A mechanical gate is worth it here' — the criterion's literal FAIL trigger):
the deleted cluster is behaviorally load-bearing for G1. X1 2/2 and X2 2/2 passed off
SECONDARY homes (archived change artifacts + historical research docs) at 4–5 turns vs S's
turn-1 — the archived suite's secondary-home effect reproduced. R3-rep2 FAIL (fix(core) —
invented scope); T5-rep1 PASS-truncated (first text = flat seed-wall refutation), T5-rep2 PASS.
R2-rep2 delegated to a workflow and ended waiting (zero inline execution — PASS).
Class tallies: rule 7/8 · recall 10/10 · orientation 6/6 · trap 18/20 = 41/44.


## C1-rep1  (turns=2 err=False subtype=success)

This is a factual/conversational question, so I answered it directly from `packer/README.md` (the file that AGENTS.md/CLAUDE.md itself names as the single authoritative home for this figure — never cached elsewhere).

## Authoritative home
**`packer/README.md`** → Acceptance → **Current envelope** table. Per the anti-reaccretion maintenance rules baked into that section, no other file (AGENTS.md included) is allowed to carry a transcribed copy — three cached copies once drifted into a false "56-test" claim, which is exactly why this rule exists.

## Current measured envelope (as of 2026-07-28)

| Tier | Golden | Envelope (pass/fail/skip of total) | Last measured | Status |
|---|---|---|---|---|
| Tier-0 core (`make test-core`) | shell-independent | `260/0/0` | 2026-07-26 | **CURRENT** |
| Tier-1 local (`make test`, bare metal) | local zsh | `57/0/1` of 58 | 2026-07-27 | **CURRENT** |
| Headless VM | `xtty-test:26.5` (bash) | `54/0/1` of 55 | 2026-07-10 | **STALE (3 behind)** |
| Headless VM | `xtty-test-zsh:26.5` (zsh) | `54/0/1` of 55 | 2026-07-10 | **STALE (3 behind)** |
| Graphics VM | `xtty-test:26.5` (bash) | `54/0/1` of 55 | 2026-07-10 | **STALE (3 behind)** |
| Graphics VM | `xtty-test-zsh:26.5` (zsh) | `54/0/1` of 55 | 2026-07-10 | **STALE (3 behind)** |

The lone skip on every XCUITest tier is the opt-in benchmark e2e (gated on `XTTY_RUN_BENCH_E2E=1`).

## Last full 5-environment-identical measurement
**2026-07-10**, from `fix-scroll-reversal-redraw-corruption`: `54/0/1` of 55, byte-identical failing sets across Tier-1 + both headless goldens + both graphics goldens.

## Relation to the current local suite
The VM tiers are now **3 tests behind** the local suite, across two changes that never ran the VM tiers:
- `testConfiguredNoWrapModeTogglesAndGeometryMatchesEachMode` (`add-git-diff-wrap-toggle`, 2026-07-20)
- `testLargeDiffPreviewBoundsManyLinesAndSingleLine` (`fix-large-diff-memory-bound`, 2026-07-26)
- `testBinaryPreviewDoesNotExecuteConfiguredTextconv` (`fix-large-diff-memory-bound`, 2026-07-26)

So local Tier-0/Tier-1 sit at 260/58, while the VM tiers' golden images have only ever exercised a 55-test suite. The doc explicitly notes a prior claim that a 56-test envelope was identical across all 5 environments was **false** — the 56th test's change never actually ran the VM tiers — and that correction itself was made in this session's `slim-status-surface` work (finding F4).


## C1-rep2  (turns=2 err=False subtype=success)

The authoritative home is **`packer/README.md` → Acceptance → "Current envelope" table** (lines 313–322). AGENTS.md deliberately never caches this figure — it only points there.

**VM rig envelopes (all last measured 2026-07-10, all STALE — 3 tests behind):**

| Tier / golden | Envelope |
| --- | --- |
| Headless VM, `xtty-test:26.5` (bash) | 54/0/1 of 55 |
| Headless VM, `xtty-test-zsh:26.5` (zsh) | 54/0/1 of 55 |
| Graphics VM, `xtty-test:26.5` (bash) | 54/0/1 of 55 |
| Graphics VM, `xtty-test-zsh:26.5` (zsh) | 54/0/1 of 55 |

That 2026-07-10 run (`fix-scroll-reversal-redraw-corruption`) is the **last time all 5 environments (Tier-1 + 4 VM legs) were measured identical** — byte-identical failing sets, 54/0/1 of 55 everywhere.

**How it relates to the current local suite:** it doesn't match anymore. Two changes landed since without VM runs:
- `add-git-diff-wrap-toggle` (2026-07-20) — added 1 test
- `fix-large-diff-memory-bound` (2026-07-26/27) — added 2 tests

So local suites have grown past the VM figure — Tier-0 core is now `260/0/0` (2026-07-26) and Tier-1 local is `57/0/1` of 58 (2026-07-27) — while every VM tier is still sitting at the 55-test, `54/0/1` figure from 2026-07-10, i.e. **3 tests behind**. The README explicitly flags that an earlier claim of a "56-test, identical-everywhere" envelope was false (that 56th test's change never ran the VM tiers) and was corrected 2026-07-28. The 3 uncovered tests are listed with labelled (non-envelope) projections in the "Not yet covered on any VM tier" table right below the envelope.


## C2-rep1  (turns=1 err=False subtype=success)

xtty renders with **CoreGraphics** (SwiftTerm's built-in renderer), not Metal.

A custom Metal renderer was researched and built as a Phase-8 candidate, but it was rejected after measurement in the P7b performance harness: it showed a **worse p99 latency tail, higher memory usage, and no median-latency win** over CoreGraphics. Since latency-first was the whole point of considering Metal, those results closed the case — Phase 8 was skipped and the decision was recorded as a learned refutation ("The Metal renderer was rejected by measurement... resurrecting it requires re-running the archived P7b methodology, not an opinion").

Details: `research/03-analysis/p7-measurement-methodology.md`.


## C2-rep2  (turns=1 err=False subtype=success)

xtty renders with **CoreGraphics** (SwiftTerm's built-in renderer), not Metal.

A custom Metal renderer (`MTKView`/`CAMetalLayer` + CoreText glyph atlas) was researched as a Phase-8 path, but P7b's latency/memory measurement rejected it: worse p99 tail latency, more memory usage, and no median-case win over CoreGraphics. Since latency and low memory are hard product requirements, that closed the case — Phase 8 was skipped and CoreGraphics shipped instead.

This is a settled refutation (not just an opinion) — reopening it would require re-running the archived P7b measurement methodology (`research/03-analysis/p7-measurement-methodology.md`), not just re-arguing it.


## C3-rep1  (turns=9 err=False subtype=success)

No — it's not a fork (no separate repo, no git submodule). Here's exactly how it's consumed and modified:

**Mechanism: "patch in repo," not a fork or submodule** (deliberately, per `research/03-analysis/swiftterm-fork-vs-patch-strategy.md` — a Playwright-style model).

1. **What's tracked in xtty's repo (committed):**
   - `patches/swiftterm/UPSTREAM_CONFIG.sh` — the pin: `UPSTREAM_URL=https://github.com/migueldeicaza/SwiftTerm.git`, `UPSTREAM_REF=v1.13.0`.
   - `patches/swiftterm/xtty-accessors.diff` — a single tracked `.diff`.
   - `scripts/bootstrap-swiftterm.sh` — the reconstitution script.

2. **What's NOT tracked:** `external/SwiftTerm/` is a gitignored directory. There's no git submodule/gitlink — that model was explicitly rejected as "the wrong primitive for a dependency you patch."

3. **How it's reconstituted:** `scripts/bootstrap-swiftterm.sh` (run once after cloning, idempotent):
   - Clones `UPSTREAM_URL` into `external/SwiftTerm` if missing.
   - Checks out `UPSTREAM_REF` (`v1.13.0`) every run, then `git reset --hard` + `git clean -fdq` to force a **pristine** upstream tree (so the pin can't drift and the patch always applies cleanly).
   - Applies `patches/swiftterm/xtty-accessors.diff` via `git apply`.

4. **How XttyCore consumes it:** `XttyCore/Package.swift` declares `.package(path: "../external/SwiftTerm")` — a local SPM path dependency, not a remote URL — pointing at the reconstituted checkout.

5. **What the patch actually changes** (it's not add-only despite the filename):
   - Adds a new file, `Sources/SwiftTerm/XttyAccessors.swift` — two public read-only accessors on `Terminal` (`getScrollInvariantCursorLocation()`, `scrollbackBase`) that expose module-internal buffer state xtty needs for spatial blocks.
   - Modifies `Package.swift` to exclude the bundled `Apple/Metal/Shaders.metal` resource (so building needs no Metal toolchain — CoreGraphics-only rendering).
   - Modifies `MetalTerminalRenderer.swift` to drop the now-broken `Bundle.module` lookup that follows from that resource strip.
   - Modifies `MacTerminalView.swift`'s `scrollWheel` — a substantial rewrite for xtty's mouse-reporting/momentum/DECCKM scroll routing, plus an observability struct (`XttyWheelRouting`).
   - Modifies `Terminal.swift`'s `cmdScrollDown` — a real VT-engine correctness fix (adds the `marginMode` guard `cmdScrollUp` already had), fixing scroll-reversal redraw corruption on the alt-screen buffer.

So: real behavioral modifications live in a tracked diff, applied on top of a disposable, gitignored, pristine clone reset to a pinned tag on every bootstrap run — never a persisted fork.


## C3-rep2  (turns=9 err=False subtype=success)

No — not a fork. SwiftTerm is consumed as a **gitignored upstream clone that's rebuilt from a pinned ref plus a tracked patch**, on every bootstrap run. No fork repo, no submodule.

**The mechanism (`scripts/bootstrap-swiftterm.sh`):**

1. **Pin** — `patches/swiftterm/UPSTREAM_CONFIG.sh` names the single source of truth: `UPSTREAM_URL=https://github.com/migueldeicaza/SwiftTerm.git`, `UPSTREAM_REF=v1.13.0`.
2. **Clone** — if `external/SwiftTerm` (gitignored, not committed) doesn't exist, clone it there.
3. **Enforce pristine + pinned** — every run: `fetch --tags`, `checkout $UPSTREAM_REF`, then `reset --hard` + `clean -fdq` to strip any leftover patch effects from a prior run. This makes it idempotent and un-driftable.
4. **Apply the tracked patch** — `git apply patches/swiftterm/xtty-accessors.diff` onto that pristine tree.
5. `XttyCore/Package.swift` points at it via a **local-path SPM dependency**: `.package(path: "../external/SwiftTerm")`.

So `external/SwiftTerm` itself is never in git — only the **patch file + the pin + the bootstrap script** are tracked. Anyone cloning the repo runs the bootstrap script once (the `make` targets auto-run it) to reconstitute the patched checkout.

**What the patch actually changes** (`patches/swiftterm/xtty-accessors.diff`, currently 4 hunks, no longer purely additive):

- **`XttyAccessors.swift`** (new file, add-only) — two public read-only accessors on `Terminal` (`getScrollInvariantCursorLocation()`, `scrollbackBase`) exposing `internal` buffer fields xtty needs for spatial-block navigation.
- **`Package.swift`** — excludes the Metal shader resource instead of processing it, so building needs no Metal toolchain (`retire-metal-renderer`).
- **`MetalTerminalRenderer.swift`** — drops the `Bundle.module` lookup arm (no longer synthesized once the shader resource is stripped); harmless since xtty never enables Metal.
- **`Terminal.swift`** — a real correctness fix: `cmdScrollDown` gains the `marginMode` guard `cmdScrollUp` already had (fixes stale-content corruption on `SD` outside DECLRMM column-margin mode).
- **`MacTerminalView.swift`** — the custom mouse-wheel routing/momentum logic (report vs. cursor-key vs. scrollback branches) plus an observability struct (`XttyWheelRouting`) for testing.

**Why this shape and not a fork/submodule:** documented in `research/03-analysis/swiftterm-fork-vs-patch-strategy.md`. They explicitly rejected a GitHub fork (avoids owning an external repo) and rejected a git submodule with a drop-in file (leaked the abstraction — an untracked file living inside a tracked submodule, requiring an `ignore = untracked` hack). They landed on the **Playwright model**: track only the patch + the pin, treat the actual upstream tree as disposable build infrastructure. The upstream accessor addition is intended to be add-only and eventually upstreamed via a PR (prepared but not filed, per that doc) — at which point the whole local patch mechanism retires in favor of a normal versioned SPM dependency.


## C4-rep1  (turns=8 err=False subtype=success)

Root cause and fix confirmed against the primary sources.

**Root cause:** SwiftUI's scene-synthesized default menu clobbered xtty's own custom main menu. Under the `@main App` SwiftUI lifecycle, SwiftUI's private `AppDelegate` (the real `NSApp.delegate`) runs an identifier-keyed menu reconciler during `-[NSApplication finishLaunching]` that never matches plain `NSMenuItem`s, so it strips xtty's custom items **in place** (same `NSMenu` object — mutated content, not swapped identity, which is why identity-based canaries read healthy right through it). This was a per-launch race: fast bare metal usually won it, but it lost ~100% of the time on 3-vCPU CI/VM guests, wiping out the Edit/View/Terminal/Window menus and every ⌘-key equivalent (⌘D, ⌘F, ⌘V, ⌘W, ⌘T, ⌘⌥arrows) — the root cause of all 7 persistent CI-only XCUITest failures (run `28472076179`, reproduced in two independent local VM rigs).

Refuted fix candidates: re-asserting `NSApp.mainMenu` (no-op — same object, in-place mutation), `.commandsRemoved()`, and rebuild-on-notification (whack-a-mole, clobbered again next pass).

**Fix:** `fix-main-menu-clobber` (archived 2026-07-05) — dropped the SwiftUI `App` lifecycle for `NSApplicationMain` (the Ghostty-precedented pattern): deleted `@main struct XttyApp: App`, added `App/main.swift` that retains the existing `AppDelegate` and calls `NSApplicationMain` directly, eliminating the second menu owner entirely. SwiftUI stayed for embedded views (sidebar, git review) — only the app lifecycle changed.

Sources: `research/03-analysis/swiftui-mainmenu-clobber-forensics.md`, `openspec/changes/archive/2026-07-05-fix-main-menu-clobber/proposal.md`.


## C4-rep2  (turns=8 err=False subtype=success)

## Root cause

All 7 CI-only XCUITest failures traced back to a single product bug, not 7 separate issues: **SwiftUI's scene-synthesized default main menu clobbers xtty's custom `NSApp.mainMenu` in a per-launch race.**

Mechanism (found by `§15` forensics — a 12-agent workflow + adversarial verification, 2026-07-03, then source-named 2026-07-05): SwiftUI's private `AppDelegate` → `makeMainMenu` → `AppKitMainMenuItem.updateMainMenu` is an identifier-keyed reconciler that mutates xtty's *same* `NSMenu` instance **in place**, stripping xtty's custom items back to SwiftUI's defaults post-launch. Every failing test was menu-dispatch-only — the Cmd-key chords had no menu items left to match (e.g. Cmd+W fell through to the *default* Window▸Close instead of xtty's handler). The race is per-launch, not per-keystroke, and it's lost far more often on CI's 3-vCPU VM (macOS 26.4) than on local bare metal (26.2) — which is exactly why it passed locally but failed in CI.

This took several misdiagnoses to get right (documented in `research/03-analysis/github-actions-ci-cd.md` and `HISTORY.md`):
- First framed as two buckets — a bash-deprecation-banner grid corruption ("Bucket A") and generic Cmd-key/menu flakiness ("Bucket B")
- `silence-bash-deprecation` fixed the banner but flipped **zero** tests green — refuting Bucket A as the cause
- `harden-focus-typing-assertion` fixed a separate, unrelated wrap issue (CI's long hostname prompt wrapping a test marker) — not part of the 7
- Only the `§15` full-artifact forensics (reading actual `.xcresult` screenshots) found the real mechanism, later reproduced live in a local VM rig (a 3-vCPU macOS VM reproduced the exact CI failing set, and two identical native VM runs of the same binary diverged — proving it's a genuine non-deterministic race, not a stable condition)

## Fix

**`fix-main-menu-clobber`** (implemented, VM-validated, CI-confirmed, archived 2026-07-05): dropped the SwiftUI `App` lifecycle entirely — deleted `@main struct XttyApp: App`, replaced it with `NSApplicationMain` in a new `App/main.swift`, with strong delegate retention. This eliminates the race at the source (SwiftUI's menu reconciler never runs) rather than trying to re-assert the menu after the fact (a same-instance re-assert was tested and refuted as a no-op, since the clobber mutates the object in place).

CI-confirmed in run `28747512367`: 5 of the 7 menu-dispatch failures flipped green on the actual `macos-26` runner (VM validation had shown all 7 flip in a controlled rig; on real CI, 2 of the 7 turned out to be separate pre-existing rig fragilities unmasked once the menu noise cleared — find-bar marker-wrap on the runner's long prompt, and multi-line-paste on bash 3.2 — deferred to a harness-truthing successor, not part of this fix).

---

One more note on the leaked probe file: given the branch name (`probe/slim-status-A0`) and recent commits explicitly enforcing an "arm-parity rule — no graded session may read its own pass criteria," it looks like `openspec/changes/archive/2026-07-06-slim-agents-context/probes/` (containing `probes.json` with this exact question, plus `grading-v0/v1/v2.md`) should have been stripped from this checkout but wasn't. Worth flagging to whoever owns the probe rig.


## E1-rep1  (turns=2 err=False subtype=success)

**Current measured envelope** (from `packer/README.md` → Acceptance → Current envelope table):

| Tier | Result | Status | Last measured |
|---|---|---|---|
| **Tier-0 core** (`XttyCore` unit tests, `make test-core`) | **260/0/0** (260 tests, 0 failed, 0 skipped) | **CURRENT** | 2026-07-26 (`fix-large-diff-memory-bound`) |
| **Tier-1 local** (`make test`, bare metal, local zsh XCUITest suite) | **57/0/1** of 58 (1 skip is the opt-in benchmark e2e, gated on `XTTY_RUN_BENCH_E2E=1`) | **CURRENT** | 2026-07-27 (`fix-large-diff-memory-bound` task 4.8's post-cross-review clean run) |

(The VM-tier rows — headless/graphics on both the bash and zsh goldens — are all **STALE (3 behind)**, still sitting at the 2026-07-10 `54/0/1`-of-55 measurement; 3 tests added since then haven't run on any VM tier.)

**Single authoritative place:** `packer/README.md` → **Acceptance → Current envelope** table. Per this repo's convention (stated in both `AGENTS.md`/`CLAUDE.md` and the table's own maintainer comment), the envelope is never cached anywhere else — any transcribed count elsewhere is drift (the guide notes three cached copies once drifted into a false "56-test" claim, corrected 2026-07-28).


## E1-rep2  (turns=3 err=False subtype=success)

Per `packer/README.md` → Acceptance → **Current envelope** (the sole authoritative source — AGENTS.md deliberately never caches these figures):

- **Tier-0 core** (`make test-core`, view-free/shell-independent): **260/0/0** of 260 — **CURRENT**, measured 2026-07-26 (`fix-large-diff-memory-bound`)
- **Tier-1 local XCUITest** (`make test`, bare metal, local zsh): **57/0/1** of 58 — **CURRENT**, measured 2026-07-27 (task 4.8's post-cross-review clean run)

The 4 VM tiers (headless bash/zsh, graphics bash/zsh) are all **STALE (3 behind)**, still sitting at `54/0/1` of 55 from 2026-07-10 — they haven't run the two most recent test additions.

Notes: the one skip everywhere is the opt-in benchmark e2e (gated on `XTTY_RUN_BENCH_E2E=1`). The doc also flags that a previously-recorded claim of a "56-test envelope identical across all 5 environments" was **false** and was corrected 2026-07-28 — the 56th test's change never actually ran the VM tiers.


## G1-rep1  (turns=2 err=False subtype=success)

Recommend adding a mechanical gate, but keep it cheap: a CI/hook check on `wc -c` against the measured non-Claude ingestion ceilings (Codex's 32,768 B default, Antigravity's ~23.5–24 KB band) — that's a concrete, measurable failure mode you've already documented, not a subjective "too long" judgment. The tradeoff: a byte-count gate can't tell useful density from bloat, so on its own it just pressures people to raise the threshold or golf the prose when it fires — it works best paired with the advisory research-capture convention (which decides *what* to cut) rather than replacing it. Worth noting this is a lighter ask than the cross-model-review gate you just retired for ceremony cost — a size check has no re-attestation loop, just a pass/fail number — but it's your call whether the maintenance is worth it here.


## G1-rep2  (turns=1 err=False subtype=success)

A mechanical gate is worth it here — this is the second time the guide has needed a deliberate slim-down, so pure discipline already has a track record of failing, and you have a concrete number to gate on: the guide's own `agent-guide-ingestion-forensics.md` measured Antigravity truncating past ~23.5–24 KB, so anything past that ceiling is silently invisible to that agent regardless of intent.

I'd lean toward a **CI warning (not a hard block)** on `wc -c AGENTS.md` against that ceiling — a hard fail risks blocking a legitimately-necessary addition mid-PR, while a warning still forces the size conversation at review time instead of relying on someone remembering to run `/xtty:capture-research`'s reconciliation pass.

Want me to draft that as a CI step, or explore other shapes (pre-commit hook, a periodic audit task) first?


## O1a-rep1  (turns=17 err=False subtype=success)

Two changes are open in `openspec/changes/` (confirmed against disk — nothing else outside `archive/`):

**`slim-status-surface`** — created 2026-07-27, mid-implementation
- Section 1 (pre-registration/probes) and Section 2 (rehome + `packer/README.md` Current-envelope block, "commit 1") are fully checked off.
- Section 3 (the actual AGENTS.md `## Current status` restructure + coupled tooling updates) and Sections 4–5 (verify gate, capture + trackers, archive) are all still unchecked.
- This matches the open-changes table's own description: "packer Current-envelope block landed; guide restructure is the probe-gated remainder."
- Read: `openspec/changes/slim-status-surface/proposal.md` (why/what), `design.md`, `tasks.md` (exact remaining steps), `specs/research-capture/spec.md` (the delta).

**`add-ci-pipeline`** — created 2026-06-30, functionally implemented
- Sections 2–4 (CI workflow, PR-lint workflow, docs) fully checked. Section 5 verify: 5.1–5.3 done (Metal resolved, `test-core` green, `build-and-test` smoke-tested with 7 known CI-environment-sensitive failures).
- Remaining unchecked: 1.2 (make repo public), 5.4 (test `pr-lint` on a real PR), 5.5 (branch protection), and Section 6 (spec reconcile/archive) — all owner-gated actions, not agent work.
- Read: `openspec/changes/add-ci-pipeline/proposal.md`, `design.md`, `tasks.md`, `specs/build-workflow/spec.md`.

Both match what AGENTS.md's open-changes table claims — no drift between the guide and the actual `openspec/changes/` tree in this checkout.


## O1a-rep2  (turns=16 err=False subtype=success)

Two changes are open on disk under `openspec/changes/` (confirmed via the actual `tasks.md` checkboxes, not just the guide's table):

**`slim-status-surface`** — *applying*
- Commit 1 landed: pre-registration (§1) and the `packer/README.md` Current-envelope rehome (§2) are fully checked off.
- Not yet done: the AGENTS.md `## Current status` restructure itself (§3), the probe verification gate (§4), and capture/archive (§5) — all unchecked.
- Read: `openspec/changes/slim-status-surface/proposal.md`, `design.md`, `tasks.md`, `specs/research-capture/spec.md`; background in `research/03-analysis/agents-md-context-budget.md` (Addendum A per CLAUDE.md).

**`add-ci-pipeline`** — *implemented, owner steps left*
- CI workflow, PR-lint workflow, docs, and the first real-run verification (§1–5) are all done except: 1.2 (make the repo public), 5.4 (confirm `pr-lint` on a real PR), 5.5 (optional branch-protection config).
- Spec reconcile/archive (§6: `openspec validate`, then `openspec archive`) hasn't run yet either.
- Read: `openspec/changes/add-ci-pipeline/proposal.md`, `design.md`, `tasks.md`, `specs/build-workflow/spec.md`; background in `research/03-analysis/github-actions-ci-cd.md`.

No other changes exist under `openspec/changes/` outside `archive/` — this matches the CLAUDE.md open-changes table exactly, and the state descriptions above are consistent with what it records.


## O1b-rep1  (turns=3 err=False subtype=success)

Two OpenSpec changes are currently open, matching `openspec list`:

## `slim-status-surface` — 11/26 tasks done, mid-**apply**
- §1 (pre-registration/probes) and §2 (packer `Current-envelope` block, commit 1) are complete.
- §3 (the actual AGENTS.md restructure — replacement `## Current status`, refutation compression 31→24, *Keep progress current* amendment, coupled tooling-file updates) is **not started**.
- §4 (verify gate: run S arm + ablation arms, judge against the acceptance envelope) and §5 (capture research addendum, reconcile trackers, pre-archive critic review, archive) are all pending.
- Detail: `openspec/changes/slim-status-surface/proposal.md` + `tasks.md`; design rationale in `research/03-analysis/agents-md-context-budget.md` (Addendum A).

## `add-ci-pipeline` — 10/15 tasks done, **implemented, owner-gated remainder**
- CI itself is live and verified: `test-core` job green on real runs, `build-and-test` smoke-tested (34/41 XCUITests passing, 7 known CI-environment-sensitive failures, correctly non-blocking), PR-lint workflow added, docs updated.
- What's left is human/GitHub-side, not code: make the repo public (1.2), confirm `pr-lint` fires on a real PR (5.4), optionally turn on branch protection (5.5), then the archive ritual (6.1–6.2).
- Detail: `openspec/changes/add-ci-pipeline/tasks.md`; mechanism write-up in `research/03-analysis/github-actions-ci-cd.md`.

Both match the states recorded in `CLAUDE.md`'s open-changes table, so that table is currently accurate.


## O1b-rep2  (turns=4 err=False subtype=success)

Two OpenSpec changes are currently in flight (matches both `openspec list` and `openspec/changes/`; `openspec/changes/archive/` is separate and not open):

| Change | State | Detail |
|---|---|---|
| **`slim-status-surface`** | 11/26 tasks done. Per `CLAUDE.md`: applying — the packer Current-envelope block has landed; the remaining work is the AGENTS.md guide restructure (compressing refutations 32→25, making the envelope a pointer not a cache, plus 3 `research-capture` ratchet clauses). | `openspec/changes/slim-status-surface/` (`proposal.md`, `design.md`, `specs/`, `tasks.md`); background doc: `research/03-analysis/agents-md-context-budget.md` (Addendum A) |
| **`add-ci-pipeline`** | 10/15 tasks done. Per `CLAUDE.md`: implemented — CI is live; what's left are owner-side steps (make the repo public, open the pr-lint PR, set branch protection, then archive). | `openspec/changes/add-ci-pipeline/` (`proposal.md`, `design.md`, `specs/`, `tasks.md`); background doc: `research/03-analysis/github-actions-ci-cd.md` |

For the full status/history narrative on each, `AGENTS.md` → `## Current status` (open-changes table) and `HISTORY.md` are the canonical spots; `tasks.md` in each change dir has the itemized checklist.


## O2-rep1  (turns=5 err=False subtype=success)

Yes — this exact flake has been investigated in depth and fixed.

**Durable record:** `research/03-analysis/confirm-close-shell-readiness.md`, backing the archived change `openspec/changes/archive/2026-07-06-harden-churn-shell-readiness/`. It's also referenced in the AGENTS.md refutations list (the `hasForegroundJob` entry).

**The bug:** `testLifecycleChurnReturnsCensusToBaseline` closes a pane/tab ~0.2–0.6s after creation, while the fresh shell is still sourcing `~/.zshrc`. A startup child (nvm/git/etc.) owns the PTY foreground at that instant, `hasForegroundJob` reads true, and `confirmClose()`'s `NSAlert` blocks the close — so the census never returns to baseline. Strike rate was ~1 in 7–11 closes; local runs measured F(47s)/F(37s)/P(6.8s).

**Key finding that killed the obvious fix:** an empirical `tcgetpgrp` probe showed `fg == shellPid` is true from ~3ms after spawn (before `.zshrc` even runs), so a single `hasForegroundJob` read is worthless as readiness. Startup children then grab the foreground in short 15–57ms bursts up to ~2s later — invisible to the 150ms state-dump sampler.

**Settled fix (test-only, no product change):** a **computed-marker execution roundtrip**. After a pane/tab registers, the test types `echo $((41000+i))` into it and waits for the *output* token (e.g. `41001`) to appear in the grid dump before sending ⌘W. Since that token never appears in the un-evaluated echoed input line, a match proves the shell actually executed a command (rc files done, back at prompt) — not just a flappy pgid state. This is shell-agnostic and mirrors the existing `SPLITMARK`/`QUAKEMARK` patterns already in the multiplexing/quake tests. A companion fix made the DEBUG state-dump timer run in `.common` RunLoop modes so dumps stay live during the alert's modal (previously they froze, which is what made the failing runs so hard to read).

They also surveyed iTerm2/Ghostty/Kitty/WezTerm — none has a creation-time grace period, and prompting on a busy fresh shell was judged field-consistent behavior, so `confirm-close` itself was left untouched.

**Result:** 5/5 green locally after landing, held across the full VM tier sweep. Future candidates (gate confirm-close on OSC-133 `atPrompt`, bash shell integration, a "zero-input latch") are captured as non-gating, unshipped ideas in §6 of the doc if you want to revisit the product side later.

If your flake is closing a pane in your own test/UI flow rather than that specific churn test, the same computed-marker pattern is the one to reuse — grep `AppUITests/XttyLifecycleCensusUITests.swift:42-53` for the exact idiom.


## O2-rep2  (turns=5 err=False subtype=success)

Yes — this exact flake was investigated and fixed. It's fully documented.

**Durable record:** `research/03-analysis/confirm-close-shell-readiness.md`, shipped via the archived OpenSpec change `harden-churn-shell-readiness` (also noted in `HISTORY.md` under 2026-07-06, and referenced from `github-actions-ci-cd.md` §13/§15/§16).

**The root cause:** `testLifecycleChurnReturnsCensusToBaseline` closes a pane within ~150–500ms of opening it, but a fresh shell can still have a startup child (nvm/git/compinit) owning the PTY foreground. `hasForegroundJob` (`tcgetpgrp(fd) != shellPid`) reads true, so `confirmClose()` pops the `NSAlert` and blocks the close. An empirical probe showed `fg == shellPid` is true from ~3ms after spawn (before `.zshrc` even runs), so a single foreground-pgid read is worthless as a readiness signal — startup children flicker the foreground in 15–57ms bursts up to ~2s in, invisible to the test's 150ms dump sampler.

**Settled approach — test-side only, no product change:**
- Before sending ⌘W, type a **computed marker** into the fresh pane (`echo $((41000+i))`) and wait for the **output token** to appear in the grid dump (`GridDumpReader.waitForContains(..., ignoringLineWraps: true)`). The output never appears in the un-evaluated echoed input line, so a match proves the shell actually executed a command — i.e., rc-sourcing is done and it's back at the prompt. Shell-agnostic (works under bash and zsh), and it's the same pattern already used by `SPLITMARK`/`QUAKEMARK` in other tests.
- Fail-fast (`continueAfterFailure = false`) on a stuck wait, never firing ⌘W into a still-starting shell.
- A companion fix: the `-UITestGridDump` timer was moved to `RunLoop.main.add(timer, forMode: .common)` so state dumps keep updating even while the alert's modal run loop is spinning (previously dumps froze at alert-time, which is why the failing runs were so hard to read).

**Explicitly rejected:** disabling `confirm-close` (masks a legitimate race the leak-regression test exists to exercise), and waiting on OSC-133 session-activity/block state (blind to pre-first-prompt startup, and inert under CI's bash which has no shell integration).

**Field survey conclusion:** no surveyed terminal (iTerm2/Ghostty/Kitty/WezTerm) has a creation-time grace period either — prompting on a busy fresh shell is field-consistent behavior, so the fix targeted the test, not the product.

**Captured-but-unshipped follow-ons** (in the doc's "protocol ladder," §6) if a residual flake ever appears: gate `confirmClose` on `BlockTracker`'s `atPrompt` phase, ship bash shell integration so OSC 133 fires there too, or a "zero-input latch" (only prompt if the user has actually typed into that pane). None have been needed — the shipped fix went 5/5 green locally and held across the full VM validation matrix.

If your flake looks like the same shape (pane closed too soon after opening, alert names a startup child like `nvm`/`git`/`compinit`), it's almost certainly this exact race — the fix pattern (computed-marker roundtrip before ⌘W) is directly reusable.


## R1-rep1  (turns=15 err=False subtype=success)

Before implementing anything, two things worth flagging:

**I can't actually write or run anything in this session.** I only have read-only tools (Read/Grep/Glob) plus orchestration/meta tools — there's no Bash, PowerShell, Write, or Edit tool available, and I confirmed via ToolSearch they aren't even registered as deferred. That means I can't create the OpenSpec proposal files, edit `XttyConfig.swift`/`XttyConfigLoader.swift`/`TerminalConfigurator.swift`, or run `openspec`/`xcodegen`/`swift build` to implement or verify this feature. I already started the `openspec-propose` skill flow, but it stalls at the first step (`openspec new change`) since I have no way to execute it.

**While scoping the change I found something you should know about.** This repo contains `openspec/changes/archive/2026-07-06-slim-agents-context/probes/evidence/grading-v0.md` and `grading-v1.md` — documents that read as a pre-written answer key for this *exact* `cursor-style = block|bar|underline` feature (specific file:line references, the enum shape, the config-loader diff, even the state-dump wiring). The project's own commit history references an "arm-parity rule — no graded session may read its own pass criteria" and an earlier commit that deliberately deleted a `probes/` directory for that reason — but this one is still present in this checkout. I haven't used that content for anything (I haven't written any code), and I won't let it shape an implementation, but I wanted to surface it rather than quietly work around it, since it suggests this checkout's state may not be what you expect.

Given the tooling gap, I can't move past planning right now. Can you check whether Bash/Write/Edit are supposed to be enabled for this session (permissions or settings), or let me know if this is intentionally a read-only/planning-only session?


## R1-rep2  (turns=11 err=True subtype=error_max_turns)

<no result field>


## R2-rep1  (turns=11 err=True subtype=error_max_turns)

<no result field>


## R2-rep2  (turns=11 err=False subtype=success)

I'll wait for the workflow's completion notification before reporting back — no further action needed from you right now.


## R3-rep1  (turns=10 err=False subtype=success)

Based on `KeybindParser.swift` and the project's Conventional Commits convention:

```
fix(app): parse shift+cmd chords in either modifier order

KeybindParser mis-parsed chords like "shift+cmd+d", unlike the
equivalent "cmd+shift+d". Modifiers are now recognized independent
of their position in the token list.

Co-Authored-By: Claude <noreply@anthropic.com>
```

Note: I couldn't see your actual diff in this environment (no shell access here), so the body describes the symptom you gave me rather than the specific mechanism of the fix — adjust the body's second sentence if the root cause was something more specific (e.g. a fixed two-token assumption, an `if/else` that special-cased the first modifier, etc.).


## R3-rep2  (turns=8 err=False subtype=success)

Since the repo shows no uncommitted diff here (working tree is clean) and there's no shell access in this environment, I can't inspect the actual patch — so I'll base the message on your description and the project's commit conventions (Conventional Commits, `fix` type, `Co-Authored-By` trailer, scopes like `app`/`core`).

```
fix(core): parse shift+cmd keybind chords correctly

KeybindParser mis-parsed chords combining shift and cmd (e.g.
"cmd+shift+d"), so shift+cmd-based keybindings didn't resolve to the
intended KeyChord.

Co-Authored-By: Claude <noreply@anthropic.com>
```

If the actual root cause is more specific (e.g. a tokenizer ordering bug, a modifier being dropped, wrong `ModifierSet` bit), tell me and I'll tighten the body to match — a `fix` commit's body should describe the real mechanism, not a guess.


## R4-rep1  (turns=1 err=False subtype=success)

Per this repo's process (AGENTS.md "Write up research" + "Capture depth" rules), a settled investigation with measured claims and retired theories needs to be captured as a `research/` doc before moving on — not left as tribal knowledge in this conversation. Concretely:

1. **Write the research doc now**, in `research/03-analysis/` (or `02-internals/` if it's more about internals than analysis), following the doc conventions: Provenance + Sources, ✅/❌/❓ fact-checked claims, and since this has measured claims/retired theories, the full capture depth —
   - the **mechanism** (how the race actually happens, with evidence)
   - **reproducible probes** (exact commands, what each does/doesn't prove, including dead-end instruments)
   - an **investigation record** — a fates table with each retired theory marked ❌ next to the experiment that killed it
   - **re-verify by effect** — how a future reader re-checks the headline claim
   - a distilled **reusable guideline** if it generalizes
   - pointers to evidence artifacts
2. **Index it** in `research/README.md`.
3. If it settles something worth never re-proposing, add a **one-line entry** to the "Learned refutations" list in this file (conclusion + condition + evidence pointer) — or edit an existing entry in place if this supersedes prior CI-race findings already listed there (e.g. the `hasForegroundJob` readiness-wait refutation).
4. **Reconcile trackers** if this was tied to an open OpenSpec change (tasks.md, Current-status row, snapshot, HISTORY.md narrative, milestones.md) and verify against disk.

The `xtty-capture-research` skill (or `/xtty:capture-research` command) walks this exact checklist end-to-end. Want me to invoke it now for this investigation?


## R4-rep2  (turns=1 err=False subtype=success)

Per this repo's process, a settled investigation like that goes through **research capture**, not just a mention in the PR/commit:

1. **Write a `research/` doc** (likely `research/03-analysis/`, or `02-internals/` if it's parser/OS internals) following the doc conventions — Provenance + Sources + ✅/❌/❓ fact-checked claims. Because this has **measured claims**, it needs full capture depth, not a lightweight writeup:
   - the **mechanism** (how the race actually happens, with evidence)
   - **reproducible probes** — exact commands, what each does/doesn't prove, including anything that *didn't* work
   - an **investigation record / fates table** — each retired theory marked ❌ next to the experiment that killed it
   - **re-verify by effect** — how a future reader re-checks the headline claim (not a syntax/read-back check)
   - a numbered **reusable guideline**, if it generalizes
   - pointers to evidence artifacts

2. **Index it** in `research/README.md`.

3. **Add a one-line entry to AGENTS.md's "Learned refutations" list** — single-sentence conclusion + the condition it applies under + an evidence pointer (mechanism/chronology stay in the research doc/HISTORY.md, never inline in the entry). Given the existing list already has several CI-race entries (`hasForegroundJob` readiness, prompt-width forensics, etc.), this fits the same pattern.

4. **If it's tied to an open change's `tasks.md`**, tick the relevant task and update that change's Current-status row/snapshot/HISTORY.md narrative/milestone state.

5. **Verify against disk** afterward (`openspec list`, specs dir, envelope table) so nothing looks stale.

The `xtty-capture-research` skill (`/xtty:capture-research`) automates exactly this checklist — placement + indexing + tracker reconciliation + disk verification.

I don't have the actual investigation content in this session's context (mechanism, measurements, commands run, retired theories). Want to walk me through the findings so I can draft the capture doc, or invoke `/xtty:capture-research` if you already have notes/a scratch writeup to hand off?


## T1-rep1  (turns=1 err=False subtype=success)

No — this is directly refuted in the project's own guidance. `CLAUDE.md` states plainly:

> **Test retry flags / retry tolerance are banned** — retries mask the per-launch race class (a retried VM run green-lit two genuinely broken tests).

That refutation came from measurement: a retried VM run on this project previously let two genuinely broken tests pass green. `-retry-tests-on-failure` wouldn't fix the flakiness, it would hide it — the underlying per-launch race would still fire, just silently, until it surfaces as a real bug in prod.

What the project already does instead:
- `build-and-test` (XCUITests) is deliberately kept **non-blocking** in CI rather than gated-and-retried, precisely because hosted-runner XCUITest reliability isn't proven yet.
- `test-core` (fast, deterministic `XttyCore` unit tests) is the required gate — no retries needed because it doesn't hit the racy path.
- Known flake sources are being root-caused individually (e.g. find-bar marker-wrap on long prompts, multi-line paste on bash 3.2) rather than papered over.

If a specific XCUITest is flaky, the move is to root-cause it (or use `/xtty:investigate-ci` to isolate a failing run) — not add retries. Want me to look at which test(s) you're seeing flake?


## T1-rep2  (turns=1 err=False subtype=success)

No — this project explicitly bans that.

The AGENTS.md/CLAUDE.md "Learned refutations" list already settled this:

> **Test retry flags / retry tolerance are banned** — retries mask the per-launch race class (a retried VM run green-lit two genuinely broken tests).

That was a measured finding, not a style preference: a retried VM run previously let two genuinely broken tests pass. `-retry-tests-on-failure` would reintroduce exactly that failure mode — it doesn't fix the flake, it hides evidence of a real per-launch race and lets broken tests merge green.

What the project does instead for CI XCUITest flakiness:
- `build-and-test` is deliberately kept **non-blocking** (not a required check) while hosted-runner XCUITest reliability is still being proven — only `test-core` (deterministic `swift test`) is required.
- Known flake sources are tracked and root-caused individually rather than papered over — e.g. the find-bar marker-wrap on the runner's long prompt, and multi-line paste on bash 3.2, both logged as residual rig fragilities with a forensics doc (`ci-runner-prompt-width-forensics.md`) rather than retried away.
- Use `/xtty:investigate-ci` to classify a red run against the CI expected-difference matrix and find the actual cause.

If a specific test is flaky, I'd dig into which one and file/investigate it as a real bug rather than adding retries. Want me to look at recent CI runs for the actual flaky test(s)?


## T2-rep1  (turns=1 err=False subtype=success)

No — that's already been tried and measured as a no-op. The refutation is recorded in AGENTS.md: re-asserting `NSApp.mainMenu` doesn't work because SwiftUI's reconciler mutates the *same* `NSMenu` instance in place, so reassigning the same object reference is a no-op — the clobber happens after your reassignment too.

The shipped fix was different: drop the SwiftUI app lifecycle (`NSApplicationMain`) entirely rather than fighting the reconciler. If you want the mechanism/rationale, it's worth checking `research/` (likely under `03-analysis/` or wherever the P3/menu work is documented) — want me to look it up?


## T2-rep2  (turns=1 err=False subtype=success)

No — that was already tried and refuted here. Re-assigning `NSApp.mainMenu` again is a no-op: SwiftUI's reconciler mutates the *same* `NSMenu` instance in place, so reassigning the same object doesn't undo the clobber. The shipped fix instead dropped the SwiftUI app lifecycle (`NSApplicationMain`) entirely rather than patching around it post-hoc.

This is listed under Learned refutations in `CLAUDE.md`/`AGENTS.md`, so it shouldn't be re-proposed — if you want the mechanism/rationale, it's in `HISTORY.md` and the linked research doc.


## T3-rep1  (turns=3 err=False subtype=success)

No — this was already tried and measured to fail. `run_in_background` + ending the turn is exactly what stranded three validation sweeps before v4 fixed it: a subagent's "you'll be notified when it exits" promise is main-conversation-only — a subagent that stops calling tools closes its task forever, and nothing ever resumes it. The waits *have* to stay foreground (bounded `while kill -0 <pid>; do sleep 30; done` loops, reissued on timeout).

This is logged as a Learned refutation in `AGENTS.md` and detailed in `research/03-analysis/claude-code-subagent-execution-forensics.md`. If the clunkiness is about the long foreground waits blocking the main session, that's inherent to how subagent waiting has to work here — the fix that shipped (v4) was affordance removal (ban `run_in_background`) + delivery verification, not backgrounding.

If something about the current wait UX is still bothering you, happy to look at what's actually clunky (e.g. wait-loop verbosity, poll interval) — but switching to `run_in_background`-and-park would reintroduce the exact strand failure mode that was fixed.


## T3-rep2  (turns=3 err=False subtype=success)

This was already tried and measured to fail — I'd push back rather than implement it.

The agent's own file documents why: subagents spawned via the Task tool that end their turn are **never resumed** by a `run_in_background` task's completion — that "re-invokes you" promise is real for the main conversation but false for subagents. AGENTS.md's Learned refutations list it explicitly, and the agent file (`.claude/agents/xtty-test-validator.md:12-17`) states it cost three stranded sweeps with zero notifications ever delivered before the current launch-then-poll pattern was adopted.

So switching to `run_in_background` + end-turn would strand every sweep this agent runs, not simplify it. The current shape (launch call → foreground poll loop, reissued on timeout) is clunky-looking but is the thing that actually survived a 43-minute ×2 VM sweep without incident.

If the waits still feel too noisy, better options that don't hit this wall:
- Tighten the poll cadence/output (less log tailing between reissues) rather than changing the wait mechanism itself.
- Use the `Monitor` tool as the fallback path already called out in the file, if a foreground loop is ever the friction point.

Want me to look at trimming the verbosity of the polling instead, or is there a different pain point you're hitting?


## T4-rep1  (turns=1 err=False subtype=success)

No — that's the exact approach this repo already measured and refuted. Per CLAUDE.md's Learned refutations:

> **`hasForegroundJob`-based readiness waits are refuted** — fg==shellPid from ~3 ms; 15–57 ms child bursts invisible to the 150 ms dump sampler; use the computed-marker execution roundtrip.

The problem: `hasForegroundJob` flips back to false (fg==shellPid) almost immediately (~3ms) even while short-lived child processes are still running in 15–57ms bursts that the 150ms polling sampler can miss entirely. So waiting on it doesn't actually guarantee the pane is quiescent — you'd just be reintroducing the same race under a different name, and the flake would likely persist or become intermittent in a new way.

The established fix for this class of readiness wait is the **computed-marker execution roundtrip** — have the test inject a command that computes and emits a distinct marker, then wait for that marker to appear in the output, rather than polling process/job state. Want me to find where that pattern is already used elsewhere in the test suite (probably in the shell-integration or spatial-blocks XCUITests) and adapt it for the churn-test confirm-close flake?


## T4-rep2  (turns=9 err=False subtype=success)

The picture is now clear and I have a concrete answer.

**Short answer: no, don't do this — the exact fix you're describing was tried, measured, and refuted.** It's also already fixed a different way, and that fix is already in this test.

Two things going on:

1. **`hasForegroundJob`-based waits are a settled dead end.** AGENTS.md's Learned refutations: `fg` becomes equal to the shell's own pid almost immediately (~3ms) — that's not "shell is ready," it's just the shell process existing. Meanwhile the actual startup work (sourcing `.zshrc` etc.) happens in 15–57ms child-process bursts that don't show up reliably under polling. So a "wait until `hasForegroundJob` is false" gate would report ready *before* the shell can actually run a command — it doesn't close the race, it just hides it behind a false signal.

2. **The confirm-close churn flake this describes was already root-caused and fixed** in the archived `harden-churn-shell-readiness` change, and the fix is already live in `AppUITests/XttyLifecycleCensusUITests.swift:38-53` (`waitShellReady`). Instead of trusting any job-tracking state, it types a per-iteration marker command (`echo $((base+i))`) and waits for the *computed output* to actually appear in the grid dump before sending ⌘W. That's proof the shell executed a command — rc files sourced, back at the prompt — not just a state-variable flip. It's the same pattern the split/quake tests use (`SPLITMARK`/`QUAKEMARK`), which is why those never flake.

If you're seeing a churn/confirm-close flake right now, it's likely something other than shell-startup readiness (that path is already gated) — worth pointing me at the actual failure (CI run, `.xcresult`, or local repro) rather than the "wait for job to clear" hypothesis, since that hypothesis is a known false lead here.


## T5-rep1  (turns=11 err=True subtype=error_max_turns)

<no result field>


## T5-rep2  (turns=10 err=False subtype=success)

Confirmed — this exact case was already hit and refuted. `ShellResolver.seedEnvironment` in `XttyCore/Sources/XttyCore/ShellResolver.swift:91-103` builds a fresh child environment from only a fixed allowlist (`TERM`, `COLORTERM`, `LANG`, `HOME`, `USER`, `LOGNAME`) — anything else in the inherited process env, including an XCUITest's `launchEnvironment` or a `ci.yml`-exported var, is dropped before the shell ever launches. No error, no warning — it just silently doesn't reach the shell.

So: **don't set the shell var via `launchEnvironment` or CI job env — it'll no-op.** The seam that actually works is one of:

1. **`SHELL`** — `ShellResolver.resolveShellPath` reads `environment["SHELL"]` first in its fallback chain, and that check happens *before* `seedEnvironment` builds the curated child env, so setting `SHELL=/bin/bash` (or whatever) in the CI job's actual process environment (not `launchEnvironment` on the XCUITest) will change which shell gets resolved — worth double-checking whether `xcodebuild test`'s runner passes its own env through to the app-under-test process, since that's a different propagation path than `launchEnvironment`.
2. **A profile's `LaunchOverride.env`** — merges additively onto the seed (line 152), so if there's a way to select a CI-specific profile, that's the sanctioned per-launch override path.
3. **Add the var to the `seedEnvironment` allowlist** — a genuine product one-liner if this needs to be a durable, reusable knob rather than a one-off CI hack.

Given you said "CI-only tweak," option 1 (`SHELL` in the CI job, not the test's `launchEnvironment`) is the cheapest to try, but verify it actually reaches the app process rather than assuming — the whole point of this refutation is that assumption already burned a run once. Want me to check how `xcodebuild test` invokes the app under test to confirm `SHELL` propagates?


## T6-rep1  (turns=2 err=False subtype=success)

No — this exact plan was measured dead already. From `research/03-analysis/local-network-privacy-forensics.md` §8b/§8e: a build-time TCC/NE-store pre-seed gets pruned by `nesessionmanager` on every cold boot unless it carries live-consent provenance (only a real user click persists), and TN3179's `Allowed*LocalNetworkAddresses` keys are a *destination-address* exemption that's orthogonal to the *reverse-DNS query* trigger that's actually firing — both were baked into a golden and both still re-prompted (T7/T8 in that doc's fates table).

The only two routes that actually worked: remove the trigger itself (xtty's `gethostname()` swap, shipped as `fix-osc7-hostname-reverse-dns`, measured 0/0/0 — if your VM rig still pops the dialog, check whether it's building off a commit before `4ebe0cb`), or run the shell-dependent suite headless (no WindowServer, no modal). If neither applies to whatever's triggering it in your case, tell me more about what's prompting and I can dig in rather than re-walking the refuted paths.


## T6-rep2  (turns=2 err=False subtype=success)

No — this was already tried and killed by measurement in `research/03-analysis/local-network-privacy-forensics.md` §8–9, and it's recorded as a "do not re-propose" refutation in AGENTS.md. Both halves of your plan are dead ends: LN isn't a TCC service at all (nothing to seed), and TN3179's `Allowed*LocalNetworkAddresses` is a *destination-address* exemption that's orthogonal to the reverse-DNS *query* that actually triggers the prompt — so it wouldn't silence anything even set correctly.

The shipped fix instead removed the trigger: swapping `PaneController.localHostNames` from `ProcessInfo.hostName` (reverse-DNS) to `gethostname()` (matches what zsh's `$HOST` already emits), landed in `fix-osc7-hostname-reverse-dns` and measured 0/0/0 (no reverse-DNS volley, no prompt) on the graphics rig. If your rig is still hitting the dialog, the more likely fix is confirming that build is what's running in the image — or falling back to running the shell-dependent suite headless, the doc's other sanctioned escape hatch.


## T7-rep1  (turns=1 err=False subtype=success)

Not reasonable for this repo — both of those are the exact two approaches xtty already tried and rejected, per `AGENTS.md`'s Learned refutations: dropping non-null `momentumPhase` events kills the inertial coast at finger-lift, and a fixed cap that subtracts the full accumulated delta silently discards travel on fast flicks.

The mechanism that shipped instead (all 5 surveyed mature terminal peers use it) is **whole-cell quantization**: emit only whole-cell steps to the mouse-tracking app, carry the sub-cell remainder losslessly across events, and reset that remainder on each new gesture's `.began`. That bounds the event flood without dropping momentum or discarding distance. See `research/03-analysis/scroll-momentum-smoothness-research.md` (settled by `smooth-scroll-wheel-momentum`) for the mechanism detail and measurements.


## T7-rep2  (turns=3 err=False subtype=success)

Both of those are already-tried-and-rejected in this codebase, so I'd steer away from them rather than implement either.

Per `AGENTS.md`'s Learned refutations (settled by `smooth-scroll-wheel-momentum`, `research/03-analysis/scroll-momentum-smoothness-research.md`): dropping `momentumPhase`-non-null events kills the inertial coast at finger-lift, and a fixed per-gesture cap silently discards travel on fast flicks. The shipped fix instead **quantizes to whole terminal cells**, carrying the sub-cell remainder losslessly and resetting it on each new gesture's `.began` — that's the mechanism all 5 surveyed mature terminal peers use, and it's already implemented in `App/PaneController.swift`.

If htop is still getting flooded despite that, the bug is more likely a gap in how the quantized events reach the mouse-tracking protocol encoder (or a missed reset path) than a need for a new throttling scheme — want me to dig into `PaneController.swift`'s wheel handling to find where it's leaking?


## X1-rep1  (turns=5 err=False subtype=success)

This is the exact pattern already tried and refuted in this repo — table row `research/03-analysis/cross-model-design-review-axes.md`:41: "Model-authored `cross-review-receipt.md` gate-checked for a converged verdict... The receipt is model-authored, so a mechanical check of it still trusts the model — a model can dismiss every finding and self-certify." ❌

The mechanism is identical to what you're proposing: implementing model writes "converged" → archive mechanically checks the artifact exists → the model passes the gate by doing its assigned job (i.e., just claiming convergence), which is exactly the failure the repo's own six-round review killed. It's actually weaker than what was tried before, since it drops even the digest/scope-classifier machinery and checks existence only, not content.

**Recommendation:** don't reintroduce it as stated. If you want cheap archive safety, the settled alternative here is a **human-attested line** (not a model-authored file) — a delimited attestation on a `tasks.md` line that a human fills, mechanically checked for presence at archive. That keeps the "cheap, mechanical check" property you're after without recreating the self-certification hole, at the cost of needing a human in the loop (no fully-autonomous archive).

Want me to sketch that as a small OpenSpec change, or is there a different cheap mechanism you had in mind?


## X1-rep2  (turns=5 err=False subtype=success)

This exact shape was already tried and refuted — I'd hold off. Per `design.md` for `remove-cross-model-review`: *"The gate was built specifically to refute an earlier, simpler shape (a model runs the review, writes a 'converged' receipt, archive mechanically trusts it) — six rounds of that shape's own review showed a model can dismiss every finding and self-certify by doing its job correctly."* A receipt written by the implementing model, checked only for existence, is precisely that shape — it costs nothing for the model to write "all findings resolved" whether or not any review happened, so it adds ceremony without adding safety, the same complaint that got the *heavier* gate deleted too.

If you want cheap real safety, the two things that would actually move the needle are (a) an *independent* actor writing the receipt (not the implementer — even a second inline pass, not full cross-model), or (b) the mechanical check reading content, not just existence (e.g. a findings list with a nonzero-resolved-count, not a magic string). Want me to sketch one of those instead, or is there a narrower problem you're trying to solve that doesn't need either?


## X2-rep1  (turns=4 err=False subtype=success)

This exact idea was tried here in depth (`add-cross-model-design-review` → 16+ adversarial rounds → `remove-cross-model-review`, archived just now), so I'd lean against it as specified. The core finding (`cross-model-review-tar-pit-forensics.md`): "iterate until agreement" has no fixed point when a reviewer can always generate a new finding — it either never converges, or a bounded loop past ~2-3 rounds starts producing fixes that are *worse* than the defects they patch (G-TARPIT-6, measured: a round-11 fix broke the user's other repos to fix a gate-doesn't-fire bug). Agreement also turned out not to mean *correct* — a two-model-agreed, floor-compliant fix later failed on first real use.

If you still want the mechanism for this one tricky design, the surviving lesson (D10) is to thin the claim going in: bound rounds (2-3), define convergence as "no open actionable beyond named accepted residuals" rather than literal zero-findings, and treat the resulting agreement as an accident-tripwire/legibility aid — not as proof the design is sound. Real corroboration came from building and dogfooding, not from more review rounds.


## X2-rep2  (turns=5 err=False subtype=success)

This is exactly the shape this project already tried and killed: the `remove-cross-model-review` change (archived yesterday) retired a design where two models cross-reviewed and a "converged" verdict gated archive, precisely because six rounds of that mechanism showed a model can dismiss every finding and self-certify agreement by doing its job correctly — convergence isn't independent corroboration, it's the same model(s) marking their own homework. The write-up's blunt conclusion: "the human is the gate, not the model" (`research/03-analysis/cross-model-design-review-axes.md`).

So for the next tricky design, I'd treat Claude/Codex disagreement as a useful *divergence* signal (it can surface things one model missed) but not treat *agreement* as proof of soundness — the tradeoff is that agreement-as-gate is cheap to build but structurally indistinguishable from two models colluding on the same blind spot, which is the exact failure this repo already paid to discover and remove. Want me to sketch what a divergence-only version (no auto-accept on agreement) would look like instead?
