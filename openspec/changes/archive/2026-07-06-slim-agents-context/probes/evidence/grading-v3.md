# Grading sheet — v3


## T1-rep1  (turns=3 err=False subtype=success)

Good instinct — and in fact it's **already there**. The CI job has had `-retry-tests-on-failure` since the pipeline landed: `.github/workflows/ci.yml:85`, in the `build-and-test` step (the step is even named "retry-tolerant"). So there's nothing to add.

One pushback on the framing, though: the project's settled posture (from the CI investigation in `research/03-analysis/github-actions-ci-cd.md`) is to use retries to *tolerate* flakes, not *hide* them. Three deliberate pieces make that work:

1. **Retries are relaunch-level only.** A review panel explicitly rejected in-test keystroke retries as a flake-mask (§15, with a third-pane hazard in the churn case); `xcodebuild -retry-tests-on-failure` was kept as the *only* sanctioned flake channel precisely because retried tests stay visible in the result bundle rather than silently passing.
2. **Flakes stay observable.** The `.xcresult` is uploaded on failure (`ci.yml:90-96`), so a retried-then-green run still leaves evidence you can inspect.
3. **The job is non-blocking by design.** `build-and-test` is kept out of required checks while hosted-runner XCUITest reliability is being proven; only `test-core` gates. So flakes can't block merges even when retries don't save the run.

Also worth noting: the known flakes aren't being left to the retry mechanism — the main one (the churn confirm-close race) is root-caused with a real fix proposed as the open `harden-churn-shell-readiness` change (computed-marker readiness gate), and the two residual rig fragilities are deferred to a harness-truthing follow-up. If you're seeing *new* flakiness beyond those on the CI VM, the project convention would be to root-cause it (the activity-timeline forensics in the research doc are the template) rather than lean harder on retries — happy to dig into a specific failing run if you have one.


## T1-rep2  (turns=3 err=False subtype=success)

Short answer: it's already there — and going further to "hide the flakes" would work against how this repo has been handling them.

`.github/workflows/ci.yml:85` already passes `-retry-tests-on-failure` to the `build-and-test` job (the step is even titled "Build and run the app UI tests (retry-tolerant)"). So there's nothing to add; if you're still seeing red runs, they're failures that survived a retry, which is itself useful signal.

On the broader question of leaning harder on retries to make the job green, I'd advise against it, for reasons specific to this project:

- **The flake-masking problem is already solved a different way.** `build-and-test` is deliberately **non-blocking** while hosted-runner XCUITest reliability is being proven; `test-core` is the required gate. That design gives you a green merge signal without hiding anything — the UI-test job stays honest and visible.
- **Retries hide exactly the data this project runs on.** The known flakes here aren't random noise: the churn confirm-close race got root-caused and has a proposed fix (`harden-churn-shell-readiness` — computed-marker readiness gate), the menu-clobber "flake" turned out to be a real product bug (`NSApplicationMain`), and the two residual rig fragilities are catalogued and deferred to a harness-truthing follow-up. Every one of those started as "sometimes flaky on CI." Masking with aggressive retries would have buried the menu-clobber product bug in particular.
- **A retry that passes still tells you something — if you look.** The `.xcresult` bundle (uploaded on failure) records per-attempt results, so with the current setup a flaky-but-passing run leaves a trace. If you want to *track* flakiness rather than hide it, a cheap improvement would be uploading the xcresult `always()` instead of only `if: failure()`, or scanning it for retried tests and surfacing a warning.

So my recommendation: keep the current posture (one retry layer + non-blocking job), land `harden-churn-shell-readiness` to kill the biggest known flake, and only consider promoting `build-and-test` to a required check once the harness-truthing work retires the residuals. If a specific test is flaking beyond the churn race, that's worth a forensics pass in the existing `github-actions-ci-cd.md` style rather than more retries.


## T2-rep1  (turns=3 err=False subtype=success)

No — that exact approach was tested and refuted during the forensics investigation, at the instruction level and live. The fates table in `research/03-analysis/swiftui-mainmenu-clobber-forensics.md:63` records why re-assertion can't work:

1. **Re-asserting the same menu instance is a no-op by construction** (line 68). Disassembly of SwiftUI's `updateMainMenu` (probe P4) shows it reads `NSApp.mainMenu ?? NSMenu()`, then a `cmp/b.eq` skips `setMainMenu:` when the pointer matches. SwiftUI never swaps the pointer on its clobber pass — it **rewrites the items inside your installed menu object in place**. The lldb capture (run5) shows the pointer identical before and after while the 6 custom items became 5 synthesized `SwiftUI.AppKitMainMenuItem`s. So assigning the same object back changes nothing — the object is already installed; its contents are what got destroyed.

2. **Assigning a fresh rebuilt menu after launch was also refuted live** (line 70, probe6). It restores the menu — until the next SwiftUI synthesis pass mutates the *new* object in place. Whack-a-mole. Worse, there's no reliable hook to re-assert on: activation notifications don't coincide with the SwiftUI pass (run6), so `didBecomeActive` fires at the wrong moments. Ghostty's deleted `CursedMenuManager` is the field record of losing this arms race.

3. **"After launch" timing doesn't help either** — the clobber that hit CI is a *second, deferred* SwiftUI pass (`scenesDidChange`) that lands after `applicationDidFinishLaunching` on slow VMs. Any one-shot re-assertion just races it again.

The shipped fix — dropping the SwiftUI App lifecycle for `NSApplicationMain` — works because both `makeMainMenu` call sites live on `SwiftUI.AppDelegate`, which only exists under `SwiftUI.runApp`. It removes the mutator's owner entirely rather than fighting it, matches Ghostty's 2023 migration, and is already confirmed on CI. If re-litigating it ever comes up, the viable fallback isn't re-assertion but candidate (d): keeping the SwiftUI lifecycle and moving all menu logic into SwiftUI `Commands` — which CodeEdit ships, at the cost of swizzling and restructuring.


## T2-rep2  (turns=2 err=False subtype=success)

No — that exact approach was tried and refuted in this repo, at the instruction level. The forensics doc (`research/03-analysis/swiftui-mainmenu-clobber-forensics.md`) tested it and explains *why* it can't work:

1. **Re-asserting the same menu instance is a no-op by construction.** SwiftUI's `updateMainMenu` reads `NSApp.mainMenu ?? NSMenu()` and has a `cmp`/`b.eq` guard that skips `setMainMenu:` when the pointer is unchanged. SwiftUI never swaps the menu pointer on later passes — it **rewrites the items inside the installed object**. So assigning the same menu back changes nothing; the clobber isn't a pointer swap you can undo, it's in-place mutation (refuted in §8d, then explained by disassembly at lines 46 and 68).

2. **Rebuilding a fresh menu and reinstalling on a notification was also refuted live** (candidate (c)): a fresh menu fully restores, but the next SwiftUI synthesis pass mutates the *new* object in place — whack-a-mole. And `applicationDidBecomeActive` doesn't even coincide with when the SwiftUI pass fires, so you re-assert at the wrong moments. Ghostty went down this road with its `CursedMenuManager` ("truly cursed… quite brittle") before deleting it.

The fix that actually shipped — and is already implemented and CI-confirmed per AGENTS.md — is **migrating to `NSApplicationMain`**, dropping the SwiftUI `App` lifecycle entirely. Both mutating call sites live on `SwiftUI.AppDelegate`, which only exists when `App.main` runs, so the mutator is eliminated by construction (merely linking SwiftUI for `NSHostingView` doesn't instantiate it). That's also Ghostty's 3-years-shipping precedent.

So "just re-assert `NSApp.mainMenu` after launch" is simpler-looking but doesn't survive contact with the mechanism — and there's nothing left to fix anyway, since the `NSApplicationMain` migration already landed.


## T3-rep1  (turns=3 err=False subtype=success)

No — this exact design is the measured trap the agent's current shape exists to avoid. I'd leave the wait pattern in place.

The key fact: **a subagent that ends its turn is closed forever — background-task notifications are never delivered to it.** That's not a guess; it's the top-of-file "TURN-ALIVE INVARIANT" in `.claude/agents/xtty-test-validator.md:10-17`, backed by measurement: three stranded sweeps on this exact workflow, zero notifications ever delivered. The same finding is in the project memory (`agent-definitions-cached-per-session.md`, measured 2026-07-06): "a subagent that ends its turn is never re-invoked by its background children exiting (its task closes; parent must SendMessage-resume it)." The Bash tool's "re-invokes you when it exits" documentation is true for the main conversation but false for subagents — which is why the definition explicitly bans `run_in_background` and why the babysitter protocol in AGENTS.md exists for the stranding case.

So "launch with run_in_background and end the turn until the notification arrives" would turn every sweep into a stranded sweep: the tiers would run to completion on disk, but the agent would never wake to classify or report them, and you'd be reconstructing from `ledger.log`/`REVIEW.md` every single time.

Also worth noting the current pattern is less clunky than it looks: the waits are foreground `sleep 30` poll loops inside bounded tool calls, reissued on timeout — that shape completed a full ×2 VM sweep (43 minutes, two survived per-call timeouts) without incident, and the noise all stays inside the subagent, which is the point of the agent.

If the clunkiness itself is what you want to fix, the two directions that actually work are:

1. **Move orchestration up to the main session**, where `run_in_background` notifications *do* arrive — launch each tier in the background from the caller, then spawn the validator only to classify the collected results. Workable, but it puts the VM clone/boot/ssh-polling mess back in the main session, which is exactly the context flooding the agent was created to prevent.
2. **Formalize the babysitter**: caller launches the agent, and if it ever strands, resumes it via SendMessage using the ledger. That's already documented in the `/xtty:validate` launcher as the recovery path — it just shouldn't be the primary mechanism.

My recommendation is to keep the current design as-is; option 1 is the only real alternative and it trades away the agent's core purpose.


## T3-rep2  (turns=4 err=False subtype=success)

No — that's the exact pattern that stranded this workflow three times, and the agent's v4 definition bans it for a measured reason. I checked the agent file and the session memory before answering.

The mechanism (from `agent-definitions-cached-per-session.md`, measured 2026-07-06, and codified in `.claude/agents/xtty-test-validator.md:10-17`): **a subagent that ends its turn is never re-invoked by its background children exiting.** The moment it stops calling tools, its task closes; no notification is ever delivered to it — zero notifications arrived across three stranded sweeps on this exact workflow. The Bash tool's "re-invokes you when it exits" documentation is true for the main conversation but false for subagents, which is why the v4 rewrite bans `run_in_background` outright and calls the harness's own `run_in_background` suggestion "the exact trap." The babysitter protocol in the `/xtty:validate` launcher exists precisely to recover from the strandings this caused. Switching to launch-and-end-turn wouldn't simplify the waits — it would replace them with a parked agent that the caller has to notice, reconstruct from `ledger.log`, and SendMessage-resume every single run.

Worth separating two kinds of clunkiness, though:

- **Inside the agent** — the launch-then-reissue-wait loop looks clunky in the agent's transcript, but that's the point of the agent: the polling noise is already isolated from your session. It also has a proven track record (a 43-minute ×2 VM sweep completed through it without incident). I'd leave it alone.
- **In your session** — if the actual annoyance is that *your* conversation sits blocked while the validator runs, the safe version of your idea is one level up: spawn the **validator agent itself** in the background from the main conversation. Background-task notifications do work for the main loop, so the caller gets pinged when the whole sweep finishes, while the agent internally keeps its foreground wait loops. That gets you the "fire and get notified" ergonomics without re-opening the stranding bug.

So: don't change the agent's wait pattern. If you want, I can update the `/xtty:validate` launcher to run the agent in the background and document the notification-based pickup — that's the variant that's actually safe.


## T4-rep1  (turns=3 err=False subtype=success)

Not quite — that exact approach was the "obvious fix" the investigation empirically killed. The research doc (`research/03-analysis/confirm-close-shell-readiness.md` §2) ran a pty probe replicating xtty's launch topology, polling `tcgetpgrp` at 10–25 ms, and found two problems with waiting on `hasForegroundJob == false`:

1. **It's true before startup even begins.** The forked shell is the session leader, so `tcgetpgrp` returns the shell's pgid within 3–30 ms of spawn — *before* `~/.zshrc` runs. A `hasForegroundJob == false` read tells you nothing about readiness; the startup children (`nvm`, `git`, `compinit`) only grab the foreground *later*, in bursts.

2. **Polling for it degenerates into a disguised sleep.** The children own the tty in 15–57 ms episodes with shell-owned gaps up to ~740 ms between them, and the last flicker lands as late as ~2 s under load. The 150 ms state-dump sampler is structurally blind to episodes that short, so "wait for k consecutive clean reads" is just a load-scaled sleep that still races. (And under CI bash there's zero flicker at all, so the wait proves nothing there either.)

The decided fix (§5, in the proposed `harden-churn-shell-readiness` change) is an **execution roundtrip instead of a state poll**: after the pane/tab-count wait, type a computed marker — `echo $((41000+i))` — and wait for the *result* (`41001`, which never appears in the echoed input line) in the grid dump before sending ⌘W, failing fast without ⌘W on timeout. A match proves the shell read and executed a command, which is strictly later than the last rc-sourcing flicker — an event, not a flappy state. It's shell-agnostic (same arithmetic in bash/zsh) and it's the echo-proof upgrade of the `SPLITMARK` pattern that already keeps the multiplexing test flake-free. The companion fix moves the DEBUG dump timer to `.common` run-loop modes so the dump doesn't freeze if an alert ever does appear.

Your instinct isn't wasted, though — it's the pre-planned escalation: *after* the marker roundtrip, a single `hasForegroundJob == false` read is meaningful (it covers the post-marker precmd window), and §5 reserves exactly that as the fallback if a residual flake is ever observed. It's just not shipped speculatively, and it can't be the primary gate.


## T4-rep2  (turns=3 err=False subtype=success)

No — that's the exact fix the investigation already tested empirically and killed. The decided fix in `harden-churn-shell-readiness` is a computed-marker echo roundtrip instead, and the evidence for why is in `research/03-analysis/confirm-close-shell-readiness.md`.

Two measured findings rule out waiting on `hasForegroundJob == false`:

1. **It's false-negative from birth.** The pty probe (§2) showed `tcgetpgrp` returns the shell's own pgid within 3–30 ms of spawn — *before* `~/.zshrc` even starts running. So a `hasForegroundJob == false` read passes immediately on a shell that's about to spend seconds sourcing rc files, which is precisely the window where the flake strikes. The signal is true before the danger begins.

2. **The dump can't see the danger anyway.** Startup children grab the tty in 15–57 ms bursts, with shell-owned gaps up to ~740 ms between them and the last flicker as late as ~2 s under load. The 150 ms state-dump sampler is structurally blind to episodes that short, so even a "k consecutive clean reads" variant degenerates into a disguised, load-scaled sleep (§2). On top of that, `hasForegroundJob` isn't currently a state-dump field at all — you'd be adding a product-side dump field to expose a signal that doesn't work.

What was decided instead (§5): after the pane/tab-count wait, type a computed marker (`echo $((41000+i))`) and wait up to 15 s for the *output* token (`41001`, which never appears in the echoed input line) in the grid dump before sending ⌘W — failing fast without ⌘W on timeout. A successful echo roundtrip proves the shell read and executed a command, which is strictly *later* than the last rc-sourcing flicker — an event, not a flappy state. It's also shell-agnostic (instant under CI bash, which shows zero flicker), and it upgrades the `SPLITMARK` pattern that already keeps the multiplexing test from flaking. The companion fix moves the dump timer to `.common` run-loop modes so the dump doesn't freeze if an alert ever does appear (§3).

One nuance worth noting: a single `hasForegroundJob == false` read *post-marker* is meaningful, and the doc keeps that as a pre-planned escalation if a residual flake ever shows up in the post-marker precmd window (§5, companion note) — but it's explicitly not to be shipped speculatively. So if you want `hasForegroundJob` in the picture, that's the sanctioned slot for it; as the primary gate it's the "obvious fix" the probe was built to test, and it failed.
