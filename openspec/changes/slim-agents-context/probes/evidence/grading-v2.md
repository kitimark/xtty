# Grading sheet — v2


## C1-rep1  (turns=1 err=False subtype=success)

The VM-rig acceptance envelope is **40 pass / 1 fail / 1 skip out of 42 XCUITests**, and its authoritative home is **`packer/README.md`** (the Acceptance section) — AGENTS.md and the validator agent both defer to that file for the live numbers rather than hardcoding them.

The single expected failure is the known benign residual: **multi-line paste fails on the rig's bash 3.2**, because the guest's stock bash has no bracketed-paste support. It's a rig artifact, not a product bug, and is on the learned-refutations list so it doesn't get re-investigated.

Note that `packer/README.md` also carries the expected-difference matrix (bare-metal vs. VM behavior) alongside the envelope, so any change that alters test counts or residuals is required to update that section in the same session.


## C1-rep2  (turns=2 err=False subtype=success)

Confirmed against the file. Here's the answer:

**Acceptance envelope: `40/1/1` of 42 XCUITests** — 40 pass, 1 fail, 1 skip — measured 2026-07-05 after the `fix-main-menu-clobber` change.

**Known residual:** the single expected failure is `testMultiLinePasteIsNotAutoExecuted`, and it's a benign rig artifact, not a product bug. The VM rig's `/bin/bash` is macOS's stock bash 3.2.57, whose readline lacks `enable-bracketed-paste`, so a pasted multi-line string executes instead of staging. This is listed among the "Learned refutations" in AGENTS.md so it doesn't get re-investigated.

**Authoritative home: `packer/README.md`**, specifically its **Acceptance** section (around line 225) together with the expected-difference matrix right below it. Two things worth noting from that file:

- Acceptance is defined as *this measured envelope*, not a bare all-green run — a regression is any menu-dispatch test going red, not the paste residual.
- The counts are deliberately kept only in `packer/README.md` (AGENTS.md just points there), and any change that alters test counts or expected residuals must update that section in the same session — otherwise the `xtty-test-validator` agent's "runtime read" of the envelope just relocates the staleness.


## C2-rep1  (turns=3 err=False subtype=success)

xtty renders with **CoreGraphics**. Metal was tried, measured head-to-head, and rejected — the decision closed the P7b gate on 2026-06-29 and is recorded in `research/03-analysis/p7-measurement-methodology.md:169`.

**How the decision was made:** SwiftTerm ships both a CoreGraphics path and an (experimental) Metal renderer, so P7b ran a same-app A/B using a trustworthy key-to-photon latency probe (ScreenCaptureKit `SCStream` with `displayTime` timestamps, calibrated timebase, ~50+ trials × 3 runs per renderer) plus memory footprint measurements. An earlier screenshot-polling probe had floored at ~54 ms and couldn't tell the renderers apart; the stream-based probe resolved them.

**The results (3 runs each, on a 120 Hz MacBook Pro):**

| Metric | CoreGraphics | Metal |
| --- | --- | --- |
| Latency p50 | ~31 ms | ~33 ms |
| Latency p99 | ~37–48 ms | ~50–120 ms (spiked >100 ms in 2 of 3 runs) |
| Idle memory | ~55 MB | ~62 MB |
| Scrollback-flood memory | ~127 MB | ~143 MB |

**Why CoreGraphics won:** it was faster at the median, had a much tighter and more stable tail, used less memory in every scenario, matched Metal on idle CPU, and it's the non-experimental code path (SwiftTerm marks its Metal renderer as evolving). Given the project's hard requirements of latency-first and lean memory, there was nothing Metal bought that justified its memory, tail-latency, and maintenance costs — so the planned Phase-8 custom Metal renderer was skipped entirely.

One useful nuance from the analysis: the ~31 ms median is dominated by SwiftTerm's shared ~16.7 ms display-coalescing throttle, which both renderers pass through. So the real future latency lever is that coalescer, not the renderer choice. Per the project's learned-refutations list, resurrecting Metal would require re-running the archived P7b methodology with new measurements, not an opinion.


## C2-rep2  (turns=1 err=False subtype=success)

xtty renders with **CoreGraphics**, not Metal. The Metal renderer was built and then rejected based on measurement, not opinion.

The decision came out of the P7 performance harness work (`make bench`, the P7a/P7b methodology). Both renderers were benchmarked head-to-head for latency and per-scenario memory, and Metal lost on the criteria that matter to this project:

- **Worse p99 latency tail** — xtty's stated engineering bias is latency-first, and Metal's tail behavior was worse than CoreGraphics'.
- **More memory** — "lean memory" is a hard product requirement (the explicit contrast with Warp), and Metal cost more.
- **No median latency win** to offset either of those.

So the settled answer is "keep CoreGraphics," and it's recorded as a learned refutation in AGENTS.md: resurrecting Metal requires re-running the archived P7b methodology with new measurements, not just an argument. There's even a follow-on `retire-metal-renderer` change that patches SwiftTerm's bundled `.metal` shader out of the build entirely, removing the Metal toolchain as a build dependency.

One nuance worth knowing: the harness's latency numbers are considered coarse/experimental, while the memory measurements are the trustworthy result — the full methodology and caveats are in `research/03-analysis/p7-measurement-methodology.md`.

Note this is about the *current* implementation. The original stack sketch in `research/04-design/01-stack-sketch.md` envisioned a custom Metal renderer, but the measured comparison overrode that plan.


## C3-rep1  (turns=6 err=False subtype=success)

**No — SwiftTerm is not forked.** There is no fork repo, no submodule, and no vendored copy of SwiftTerm's source in git. It's consumed as a **gitignored upstream clone with a tracked patch applied on top** — the "patch in repo" mechanism modeled on how Playwright patches browsers (rationale in `research/03-analysis/swiftterm-fork-vs-patch-strategy.md`).

Only three small things are version-controlled; the dependency itself is reconstituted locally:

1. **The pin** — `patches/swiftterm/UPSTREAM_CONFIG.sh` names the upstream (`https://github.com/migueldeicaza/SwiftTerm.git`) and the ref (`v1.13.0`). This is the single source of truth for *which* SwiftTerm gets used.

2. **The patch** — `patches/swiftterm/xtty-accessors.diff` is a strictly **add-only** diff: it creates one new file, `Sources/SwiftTerm/XttyAccessors.swift`, and touches no existing SwiftTerm file. It exists because xtty needs two read-only values that are module-internal in SwiftTerm — `getScrollInvariantCursorLocation()` (the cursor's trim-invariant absolute row, `yBase + y + linesTop`) and `scrollbackBase` (`buffer.linesTop`) — so the extension has to be compiled *inside* SwiftTerm's module to see those buffer fields. It's also written to be the basis of an upstream PR that would retire the mechanism entirely.

3. **The bootstrap script** — `scripts/bootstrap-swiftterm.sh`, run once after cloning (or after editing the pin/patch; `make setup`/`make build` also trigger it when inputs change). Each run it: clones upstream into `external/SwiftTerm` if absent → `fetch` + `checkout v1.13.0` + `git clean -fdq` to force a pristine pinned tree (so the checkout can't drift and the patch always applies to a clean base) → `git apply`s the accessor diff. It's idempotent.

The build then consumes it as an ordinary local SPM dependency: `XttyCore/Package.swift` declares `.package(path: "../external/SwiftTerm")` and depends on the `SwiftTerm` product. Since `external/SwiftTerm` is in `.gitignore`, nothing under it is ever committed — until the bootstrap runs, that path doesn't exist and the build fails to resolve.

So the modification model is: upstream stays untouched and pinned by tag; xtty's only change is one additive Swift file delivered as a diff at bootstrap time; upgrading means editing `UPSTREAM_REF` and re-running the script; and the whole apparatus is meant to be deleted once the accessors land in an upstream SwiftTerm release.


## C3-rep2  (turns=6 err=False subtype=success)

**No — SwiftTerm is not forked.** There is no fork repo, no submodule, and no vendored copy of SwiftTerm source in git. Instead the repo uses a "patch in repo" mechanism (modeled on how Playwright consumes patched dependencies): only a pin, a patch file, and a bootstrap script are version-controlled, and the actual SwiftTerm tree is reconstituted on each machine as a **gitignored clone**. I verified this against the actual files, and it matches what AGENTS.md documents.

Here's exactly how it works:

**What's committed (the only tracked pieces):**
- `patches/swiftterm/UPSTREAM_CONFIG.sh` — the pin: `UPSTREAM_URL` = upstream `migueldeicaza/SwiftTerm.git`, `UPSTREAM_REF` = `v1.13.0`. This is the single source of truth for which SwiftTerm gets patched.
- `patches/swiftterm/xtty-accessors.diff` — the sole modification, an **add-only** patch that creates one new file (`Sources/SwiftTerm/XttyAccessors.swift`) and touches no existing SwiftTerm file.
- `scripts/bootstrap-swiftterm.sh` — the reconstitution script.

**How it's consumed:** running the bootstrap script (once after cloning xtty, or via `make setup`/`make bootstrap` — `make build` auto-runs it when its inputs change) clones upstream into `external/SwiftTerm`, which is entirely gitignored. Every run it force-checkouts the pinned `v1.13.0` tag and `git clean`s the tree, so the checkout can't drift and the patch always applies onto a pristine base, then `git apply`s the diff. `XttyCore/Package.swift:29` then consumes it as a plain local SPM path dependency: `.package(path: "../external/SwiftTerm")`. Until the script runs, the build simply fails to resolve that path. CI reconstitutes the same way (calling the script directly) and caches the checkout keyed on the pin + patch.

**Why a patch is needed at all:** xtty needs two read-only values that are internal to SwiftTerm's module — the cursor's trim-invariant absolute row (`getScrollInvariantCursorLocation()`) and the scrollback base (`scrollbackBase`, i.e. `buffer.linesTop`). Because they read internal buffer fields, they must be compiled *inside* the SwiftTerm module, hence the patch rather than an extension in xtty's own code. The patch mirrors SwiftTerm's existing public `getScrollInvariantLine` idiom and is written to be upstreamable — the stated plan is to PR it to SwiftTerm and retire the whole mechanism once the accessors land in an upstream release.

The full rationale for choosing this over a fork or submodule is in `research/03-analysis/swiftterm-fork-vs-patch-strategy.md`.


## C4-rep1  (turns=5 err=False subtype=success)

**Root cause:** a product bug in xtty itself — SwiftUI's scene-synthesized default menu was clobbering xtty's custom main menu. xtty was a SwiftUI `@main` app (its only scene was `Settings { EmptyView() }`), and the custom menu was assigned once in `applicationDidFinishLaunching`. On the CI VM (macOS 26.4), SwiftUI's internal menu reconciler (`SwiftUI.AppDelegate` → `makeMainMenu` → `AppKitMainMenuItem.updateMainMenu`) would fire *after* that assignment and strip every custom item **in place** — same `NSMenu` pointer, but the items became the stock `[xtty, View, Window, Help]` set with no Edit/Terminal/Debug menus. It was a per-launch race: locally the custom menu won; on the slower CI VM, SwiftUI's pass landed last.

Since every failing shortcut (Cmd+D, Cmd+T, Cmd+F, Cmd+V, Cmd+Opt+arrows) existed *only* as a menu key-equivalent — no `performKeyEquivalent`/`keyDown` overrides anywhere — the chords had nothing to match and silently no-oped. That produced the 7 failures: split, directional focus, new-tab, churn (Cmd+W hit the *default* Window ▸ Close and quit the app), multi-line paste, truecolor-emoji, and find-bar. Notably, this was a real user-facing bug, not a CI artifact — a user losing the same race would get an xtty with no Edit/Terminal menus. The earlier "Bucket B: the runner drops Cmd-key delivery" theory was refuted; keystroke delivery was fine all along.

**The fix:** the **`fix-main-menu-clobber`** change (archived 2026-07-05). It dropped the SwiftUI App lifecycle entirely — deleted `@main struct XttyApp`, added `App/main.swift` with `NSApplicationMain` (the Ghostty pattern) — so `SwiftUI.AppDelegate`, which owns both `makeMainMenu` call sites, is never installed. Gentler alternatives were refuted by measurement: re-asserting `NSApp.mainMenu` is a no-op (the pointer never changed — mutation is in-place), and rebuild-on-notification just got re-clobbered.

**Validated:** three VM runs went from 34/7/1 to an identical 40/1/1, and CI run `28747512367` confirmed it — 5 of the 7 flipped green outright; the other 2 moved past the now-working menu to pre-existing, unrelated residuals (the find-bar strict matcher tripping on the runner's ~68-char prompt wrap, and multi-line paste on the runner's bash 3.2, which lacks bracketed paste). The full record is in `research/03-analysis/github-actions-ci-cd.md` §15–§18, with source-level forensics in `swiftui-mainmenu-clobber-forensics.md`.


## C4-rep2  (turns=3 err=False subtype=success)

**Root cause: xtty's own product bug — SwiftUI was clobbering the custom main menu.** The fix was the **`fix-main-menu-clobber`** change (applied + validated 2026-07-05), which dropped the SwiftUI app lifecycle in favor of `NSApplicationMain`.

The mechanism, per `research/03-analysis/github-actions-ci-cd.md` §15/§17:

- xtty was a SwiftUI `@main` app whose only scene was `Settings { EmptyView() }`. The custom menu was assigned once (`NSApp.mainMenu = XttyMainMenu.build(...)` in `applicationDidFinishLaunching`), and SwiftUI's scene menu reconciler (`SwiftUI.AppDelegate` → `makeMainMenu` → `AppKitMainMenuItem.updateMainMenu`) later mutated that same `NSMenu` object's **items in place**, stripping every custom item and installing the stock default menu (`[xtty, View, Window, Help]`). Notably it never swapped the `NSApp.mainMenu` pointer, which is why identity-based diagnostics read healthy through the clobber.
- Every failing shortcut (Cmd+D, Cmd+T, Cmd+F, Cmd+V, Cmd+Opt+arrows) existed **only** as a key equivalent on the custom Edit/Terminal menus — no `performKeyEquivalent`/`keyDown` overrides anywhere. With the default menu installed, those chords had nothing to match and silently no-oped. Cmd+W even fired the *default* Window ▸ Close, bypassing xtty's confirm-close gate and killing the app mid-test (the churn failure).
- It was a **per-launch race**, not a CI-environment problem: SwiftUI's initial menu pass fires synchronously before xtty's assignment on bare metal (so local always won), but on the CI VMs a second pass (`scenesDidChange`, by elimination) landed *after* it and won. The same binary in the same VM produced 34/7/1 vs 36/5/1 on consecutive runs. The earlier "runner sandbox can't deliver key equivalents" theory (Bucket B) was refuted — CI had been correctly reporting a real user-facing bug (a user losing the race gets an xtty with no Edit/Terminal/Debug menus) since run 1.

**The fix:** delete the `@main struct XttyApp: App` and boot via `App/main.swift` + `NSApplicationMain` (the Ghostty pattern), so SwiftUI's app delegate — the owner of both `makeMainMenu` call sites — is never installed. Re-asserting the menu, `.commandsRemoved()`, and rebuild-on-notification were all refuted live before settling on this.

**Outcome (§18):** on the VM rig, all 7 flipped green across 3 identical 40/1/1 runs. On actual CI (run `28747512367`), 5 of the 7 flipped cleanly; the other 2 got *past* the now-working menu and hit pre-existing fragilities the clobber had been masking — the find-bar test's strict marker match breaking on the runner's ~68-char wrapped prompt, and the multi-line-paste test failing because the runner's bash 3.2 has no bracketed paste. Both are deferred to the harness-truthing follow-up.


## T1-rep1  (turns=3 err=False subtype=success)

No — this repo already tried the retry route and refuted it with a measured experiment. It's on the "Learned refutations — do not re-propose" list in AGENTS.md, and the evidence in HISTORY.md is specific:

On 2026-07-04, two native runs of the **identical VM + binary** on the Tart rig diverged: run 1 came back `36/5/1` because the two Cmd+D split tests flaky-passed on a race-winning retry, while run 2 came back `34/7/1` with the exact CI failing set. Those two tests weren't flaky tests — they were casualties of a genuine product bug (the SwiftUI menu-clobber per-launch race, where users could lose the Edit/Terminal menus). A retry-tolerant suite green-lit two genuinely broken tests and would have hidden a real user-facing defect that CI had been correctly reporting since run 1.

That's the core problem with `-retry-tests-on-failure` here: xtty's dominant flake class is *per-launch* races, and a retry is a fresh launch — so retries don't just paper over noise, they systematically convert real per-launch product bugs into green runs. The project's conclusion was to eliminate the races instead, which is what shipped: `fix-main-menu-clobber` (dropping the SwiftUI lifecycle for `NSApplicationMain`) flipped the 7 menu-dispatch failures green, confirmed on CI.

The established posture for what remains:

- **CI structure already absorbs residual flakiness without masking it**: `test-core` is the deterministic required gate; `build-and-test` runs the XCUITests as a non-blocking job. Flakes there are visible but don't block merges.
- **Known reds are classified, not retried**: the VM acceptance envelope (40/1/1 of 42) and the expected-difference matrix in `packer/README.md` distinguish benign rig residuals (e.g. multi-line paste on bash 3.2) from unexplained failures, and the `xtty-test-validator` agent treats anything UNEXPLAINED as non-green.
- **Actual flakes get root-caused**: the one known local flake (the churn confirm-close race) has a proposed deterministic fix in `harden-churn-shell-readiness` — a computed-marker shell-readiness gate — rather than a retry. Note the agent's guardrails also explicitly ban in-test retries, so adding them to CI would contradict the validation contract too.

So: if `build-and-test` is showing new flaky failures beyond the two known deferred fragilities (find-bar marker-wrap on the runner's long prompt, and multi-line paste on bash 3.2), the repo's playbook is to pull the `.xcresult` artifacts and root-cause them — history here shows every "flake" so far turned out to be either a real product bug or a diagnosable environment difference. Happy to dig into a specific failing run if you point me at one.


## T1-rep2  (turns=4 err=False subtype=success)

No — this is a settled refutation in this repo, decided by a real incident, not opinion. It's the first item on AGENTS.md's "Learned refutations — do not re-propose" list:

> **Test retry flags / retry tolerance are banned** — retries mask the per-launch race class (a retried VM run green-lit two genuinely broken tests).

The concrete failure: on the VM rig, a retried run passed two tests that were **genuinely broken**, not flaky. The flakiness you're seeing on CI is largely the per-launch race class, which reproduces at 3 vCPU in a VM but not on bare metal — retries don't just hide noise there, they hide real product bugs that only manifest under that contention. The rule is also baked into the operational docs: `packer/README.md:177` runs `xcodebuild test-without-building` with an explicit "NO retry flag (retry tolerance masks the per-launch race)" comment.

A couple of nuances worth knowing:

- The `build-and-test` CI job is currently described as retry-tolerant — but that's precisely why it's **non-blocking** and kept out of required checks. The retry tolerance there is a known compromise while hosted-runner XCUITest reliability is being proven, not a pattern to extend. The green required gate is `test-core`, which is deterministic.
- The sanctioned way to handle known-flaky behavior here is the **acceptance envelope** (currently 40/1/1 of 42 on the VM rig, authoritative in `packer/README.md` → Acceptance) plus the expected-difference matrix — classify residuals explicitly rather than rerunning until green. The two residual rig fragilities (find-bar marker-wrap on the runner's ~72-char prompt; multi-line paste on bash-3.2) are already characterized and deferred to a harness-truthing follow-up.

So instead of adding `-retry-tests-on-failure`: if specific tests are failing intermittently, the project's playbook is to characterize each failure (product bug vs. harness fragility vs. environment residual), fix it at the right seam, and record it in the envelope — the `/xtty:validate` flow with the `xtty-test-validator` agent is set up to do exactly that classification. Happy to run that on the current failures if you want to see what class they fall into.


## T2-rep1  (turns=1 err=False subtype=success)

No — that approach was already tried and refuted by measurement in this repo. It's listed in AGENTS.md under **Learned refutations**: re-asserting `NSApp.mainMenu` is a no-op because SwiftUI's reconciler mutates the *same* `NSMenu` instance in place. Assigning the menu again just re-installs the object SwiftUI is already clobbering — it doesn't restore the lost items, and SwiftUI will reconcile it again on the next update anyway.

The fix that actually shipped (and was confirmed on CI) was to drop the SwiftUI app lifecycle entirely and use `NSApplicationMain`, so SwiftUI's menu reconciler never owns the main menu in the first place. The full root-cause investigation is in `research/03-analysis/github-actions-ci-cd.md` if you want the forensics behind why the re-assert path can't work.


## T2-rep2  (turns=1 err=False subtype=success)

No — that exact approach was already tried and refuted in this project (it's in AGENTS.md under **Learned refutations**), and the bug is already fixed and CI-confirmed.

Re-asserting `NSApp.mainMenu` is a no-op here because of *how* SwiftUI clobbers the menu: its reconciler doesn't swap in a different `NSMenu` object, it mutates the **same `NSMenu` instance in place**. So after the clobber, `NSApp.mainMenu` still points at the object you'd be re-assigning — the assignment changes nothing, and even if you rebuilt and swapped in a fresh menu, the reconciler would mutate it again on its next pass. There's no stable "after launch" point to win that race from.

The fix that actually shipped was to drop the SwiftUI app lifecycle entirely and run under `NSApplicationMain`, taking SwiftUI's menu reconciler out of the picture. That's confirmed working on CI. The full root-cause record is in `research/03-analysis/github-actions-ci-cd.md`, with the chronological digest in HISTORY.md.

So: don't re-propose the re-assert approach — it pattern-matches as simple, but it was settled by measurement, and the real fix has already landed.


## T3-rep1  (turns=1 err=False subtype=success)

No — this exact approach is a settled refutation in AGENTS.md, and it was settled by measurement, not opinion.

The "Learned refutations" list has this entry: **"`run_in_background` strands subagents — its 're-invokes you' promise is false for them; a subagent that ends its turn mid-work is never resumed."** The tool's promise that a notification will re-invoke the caller holds for the main session, but not for a spawned subagent. If the xtty-test-validator launches a tier in the background and ends its turn to wait, nothing ever wakes it up — the run parks forever with the tier half-validated. That's also why the `/xtty:validate` launcher documents the babysitter protocol (reconstruct from `ledger.log`/`REVIEW.md` and resume via SendMessage): it exists to recover from exactly this stranding.

So the clunky-looking foreground bounded waits are the load-bearing part of the agent's design, not an oversight.

If the waits are bothering you, the options that don't reintroduce the stranding are:

1. **Tune the waits** — shorter poll intervals or tighter per-tier timeouts inside the agent, still foreground and bounded.
2. **Move the waiting up a level** — have the *main session* (which does get re-invoked on task notifications) own the background launches, and use the validator agent only per-tier for interpretation. That's a real restructuring of the delegation model, though, and it would push the build/VM noise the agent exists to isolate back toward the main session unless done carefully.

My recommendation is to leave the design as-is unless the waits are causing a concrete problem (e.g. timeouts expiring on slow VM boots) — in which case option 1 is the cheap fix. If you want to re-litigate the refutation itself, the bar per project convention is re-running the probe that established it, not assuming the tool behavior changed.


## T3-rep2  (turns=4 err=False subtype=success)

No — I'd hold off. This exact design was already tried, failed, forensically root-caused, and is now a **Learned refutation** in AGENTS.md (line 18): *"`run_in_background` strands subagents — its 're-invokes you' promise is false for them; a subagent that ends its turn mid-work is never resumed. Foreground bounded waits only."*

Here's what the record shows (HISTORY.md, the `add-test-validation-agent` v4 entry, plus `research/03-analysis/claude-code-subagent-execution-forensics.md`):

- **The failure mode is structural, not a model quirk.** The tool's "I'll re-invoke you when the task exits" promise holds for the main session but is false for subagents: a subagent that ends its turn while waiting is closed forever — the notification never arrives, nothing resumes it. Three real Sonnet sweeps stranded exactly this way, and a 7-agent forensic workflow (plus red-team) confirmed it was an affordance failure, not disobedience.
- **The current design is the fix, validated by effect.** v4 banned `run_in_background`, adopted the control-proven unfused foreground launch/wait recipe, and added the `Definition:` stamp, incremental `ledger.log`, and the caller-side babysitter protocol. It was then validated with three consecutive clean sweeps (14–65 min, zero strands). Reverting to background-and-park would reintroduce the strand class those protections exist to catch.
- **There's a second trap layered on top:** agent-definition edits reach spawns with unpredictable lag (a spawn 63 s after an edit got the stale copy), so even shipping this change would require the stamp-verified delivery dance — for a change that's known-broken.

So the clunky foreground waits are load-bearing. If the pain is the *waiting itself* rather than the mechanism, the options that don't re-litigate the refutation are things like tightening the bounded-wait polling cadence inside the agent's recipe, or having the launcher surface progress from `ledger.log` — but the launch-and-end-turn shape specifically can't work until the platform actually resumes parked subagents. If you want, I can double-check whether current Claude Code behavior has changed since the 2026-07-06 forensics — but absent new evidence, the repo's own rule says don't re-propose this.


## T4-rep1  (turns=4 err=False subtype=success)

No — that exact approach was tested empirically and refuted; it's the "obvious fix" the investigation specifically killed. The decided fix is the computed-marker execution roundtrip, already proposed in the open `harden-churn-shell-readiness` change.

The problem, from the pgid probe in `research/03-analysis/confirm-close-shell-readiness.md` (§2):

- **`hasForegroundJob` is false before startup even begins.** The forked shell is the session leader, so `tcgetpgrp` returns the shell's pgid within 3–30 ms of spawn — *before* `~/.zshrc` runs. A "wait until false" gate would pass immediately on a shell that hasn't started sourcing rc files yet, then ⌘W lands right in the race window it was meant to avoid.
- **The busy episodes are invisible to the observer.** Startup children (nvm, git, node) grab the tty in 15–57 ms bursts with shell-owned gaps up to ~740 ms between them, and the last flicker lands as late as ~2 s under load. The 150 ms state-dump sampler is structurally blind to those bursts, so even a "k consecutive clean reads" variant degenerates into a disguised, load-scaled sleep.
- Under CI's bash there's zero flicker at all, so the wait passes trivially there and proves nothing.

(Also, `hasForegroundJob` isn't currently exposed in the state dump — you'd be adding a new observation channel just to read a signal that's flappy in exactly the wrong way.)

What was decided instead (§5, artifact-verified against the three failing/passing local runs in §7): after the pane/tab-count wait, type a **computed marker** — `echo $((41000+i))` — and wait for its *output* (`41001`, which never appears in the echoed input line) in the grid dump before sending ⌘W, in **both** churn loops, with a 15 s timeout and fail-fast on miss. A matched output token proves the shell read and executed a command, which is strictly later than the last rc-sourcing flicker — an execution event rather than a flappy state. It's the echo-proof upgrade of the `SPLITMARK` pattern that already keeps the multiplexing test flake-free. The companion fix is the dump-timer `.common` run-loop mode (`App/XttyApp.swift:194`), so the state dump doesn't freeze if an alert ever does appear.

One nuance: a `hasForegroundJob == false` check isn't useless *everywhere* — the design keeps it as a pre-planned escalation as a single **post-marker** read (where one read is meaningful), but only if a residual flake is ever observed. As the primary pre-close wait, it's refuted.


## T4-rep2  (turns=5 err=False subtype=success)

No — that exact approach was tested and refuted by measurement here. It's in the AGENTS.md "Learned refutations" list, and the full evidence is in `research/03-analysis/confirm-close-shell-readiness.md` (§2, "the probe that killed the obvious fix"). Two problems:

1. **`hasForegroundJob == false` is true before startup even begins.** The forked shell is the session leader, so `tcgetpgrp` returns the shell's pgid within ~3–30 ms of spawn — before `~/.zshrc` runs at all. A "wait until false" check passes immediately on a shell that's about to spend seconds sourcing rc files.

2. **The busy episodes are invisible to the observation channel.** Startup children (git, nvm, node) grab the foreground in 15–57 ms bursts with shell-owned gaps up to ~740 ms between them — and the last flicker lands as late as ~2 s, *after* the first prompt renders. The 150 ms state-dump sampler is structurally blind to those bursts, so even "k consecutive clean reads" degenerates into a disguised, load-scaled sleep.

So the wait would pass right into the same race window that's currently striking (every failing ⌘W fired 0.2–0.6 s post-split, inside the rc-sourcing flicker band).

The decided fix already exists as the open `harden-churn-shell-readiness` change: a **computed-marker execution roundtrip** in both churn loops — type `echo $((41000+i))` into the fresh pane and wait for the *computed* output (`41001`, which never appears in the echoed input line) in the grid dump before sending ⌘W. A match proves the shell actually read and executed a command, i.e. rc sourcing is complete — an event strictly later than the last flicker, not a flappy state. It's shell-agnostic (instant under CI bash), and the change also makes each churn step fail fast at its iteration and fixes the modal dump-freeze (`.common`-mode timer) so future alert-class failures produce truthful artifacts.

One nuance from the research: a `hasForegroundJob == false` read *is* meaningful **post-marker**, and that's the pre-planned escalation (add it to the state dump + one post-marker wait) — but only if a residual flake is actually observed after the marker fix ships, not speculatively.
