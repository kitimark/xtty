# Claude Code subagent execution forensics — why long-wait subagents strand, and how xtty-test-validator v4 fixed it

> **Provenance:** 2026-07-06. Produced during `add-test-validation-agent`'s apply/hardening session: three stranded Sonnet validation sweeps → a 7-agent forensic workflow (four per-transcript investigators + a definition-caching historian + a prompt-engineering synthesis + an adversarial red-team) over the full JSONL transcripts of all four runs (three failures + the one completed control), plus live version probes against running agents and three post-fix validation sweeps. All measured on Claude Code v2.1.201, macOS 26.2 host.
>
> **Sources:** the four subagent transcripts (session task outputs); the forensics workflow journal (`wf_0dd27ebe-e1c`); the agent-definition git history (`765e1ec` v1 → `6fc3bfe` v2 → `0c74e1d` v3 → `8355216` v4 → `d60e628`); on-disk run evidence at `~/Downloads/xtty-vm-poc/artifacts/2026-07-06-*/` (ledgers, REVIEW.md files, xcresults); live probe answers quoted verbatim by resumed agents.

## 1. TL;DR

✅ **A Claude Code subagent that stops calling tools is done forever** — its task closes; no background child exiting, no watcher, no notification ever re-invokes it. The Bash tool's "keeps running across turns and re-invokes you when it exits" promise is **main-conversation-only**; for subagents it is false (measured: zero notifications delivered across every stranded transcript).

✅ **The strand mechanism was an affordance failure, not model disobedience.** Three independent Sonnet runs all: launched tiers with `run_in_background: true` (whose result text promises "You will be notified"), had a bare `sleep N && cmd` foreground wait **blocked by the anti-sleep hook whose error text recommends `run_in_background`** — the trap stated as advice at the decision moment — then put `run_in_background: true` on their own *wait loops*, orphaning them, and parked. The successful control run (same model, same task shape, 43 minutes) simply never touched `run_in_background`: plain foreground `nohup` launches + foreground `while kill -0 …; do sleep 30; done` waits (600 s cap, reissued on timeout — two timeouts survived).

✅ **Agent-definition edits reach spawns with unpredictable lag.** A spawn **63 s** after an edit was served the stale pre-edit definition (probe-proven, verbatim quote); a spawn **~40 min** after the next edit got the fresh one. Consequence: all three "the model ignored the rule" incidents were spawns that **never received the rule** — the v2/v3 anti-park escalations were an A/B test whose treatment arm was never dosed.

✅ **The fix that worked is affordance removal + delivery verification, not louder prompts:** ban `run_in_background` outright, mandate the control's unfused foreground launch→wait shape, stamp every report with a `Definition: <version>` first line the caller checks, and give the caller a babysitter/resume protocol. Post-v4: three consecutive Sonnet sweeps (14 / 65 / 30 min), zero strands, zero `run_in_background` uses.

## 2. The mechanism (how subagent task lifecycle actually behaves, with evidence)

1. **Task closure on turn end.** When a subagent emits a message with no tool call, its harness task reports `completed` (the parent receives a task-notification carrying whatever interim text the agent wrote). From that point the agent is inert. Evidence: all three parked runs' tasks reported completed with "waiting for the notification" text; their background children (make test, watcher shells) kept running and finished fine; no agent was ever re-invoked (ledgers/REVIEW.md untouched after park; next-tier work never started).
2. **The false promise.** Inside the subagent's own context, the Bash tool doc claims background tasks re-invoke on exit. Empirically zero such re-invocations occurred for subagents. Worse, a `nohup` wrapper exiting instantly can emit a *real* mid-turn "completed" notification — teaching the model that notifications work, right before it stakes the sweep on one (run 2 explicitly diagnosed that false signal, then parked anyway).
3. **The hook that recommends the trap.** The anti-sleep hook blocks bare foreground `sleep N && cmd` calls and its error text suggests `run_in_background: true`. Runs 2 and 3 hit this exact block and took the suggestion. The hook does **not** block `while <check>; do sleep 30; done` loops — the control ran four multi-minute foreground waits (longest 6.5 min in one call) unimpeded.
4. **Self-neutralizing waits.** All three failures authored a *correct* bounded wait loop — then set `run_in_background: true` on it, converting the survival mechanic into an orphan watcher. The park then followed with filler like `Bash true` described as "yield turn" — the model fumbling to hand control to a mailman that doesn't exist.
5. **Definition propagation lag.** The agent registry does not serve the on-disk file at spawn time; it serves a cached copy refreshed on an unpredictable schedule. Measured bounds: stale at +63 s, fresh at +40 min (same session, `.claude/agents/` dir created mid-session — possibly the worst case, since the directory watcher only attaches to dirs existing at session start).
6. **Resume semantics.** A completed subagent can be resumed via SendMessage with its context intact — but the resume **drops a per-call model override** (a Sonnet-pinned agent resumed onto the session model, measured twice). Model-comparison runs are therefore only valid if they complete without a resume.

## 3. Reproducible probes (what each proves, and the instruments that did NOT work)

- **The in-context version probe (the decisive instrument).** Resume (or ask) a live/parked agent: *"quote verbatim, from your own system prompt without reading disk, the heading + first sentence of section X / your definition-version line."* Proves exactly which definition version the spawn received. This settled stale-vs-ignored conclusively where nothing else could.
- **The report stamp (the zero-cost standing probe).** A `Definition: <version>` line the definition orders into every report; caller compares to the file. Detects stale delivery on every run for free. Caveat: a parked run emits no report — the babysitter's resume message carries the probe instead. Second caveat: a stamp nobody bumps on edit is worse than none (it returns false confidence) — bump-on-every-edit is part of the discipline.
- **Transcript greps that work:** `grep -o '"run_in_background":[a-z]*' <task-output> | sort | uniq -c` (affordance usage); `grep -o '"model":"[^"]*"' … | uniq -c` (model purity / resume-switch detection); tool_use/tool_result timeline extraction via a per-line JSON parse (the forensic workflow's recipe).
- ❌ **Instrument that does NOT work: grepping transcripts for the system prompt.** Subagent JSONL transcripts do **not** record the system prompt/agent definition — every definition-text grep returned 0 on every run, both stale and fresh. Only the in-context probe (the agent quoting itself) can witness the served version.
- **Liveness ground truth:** `ps aux | grep -E "xcodebuild|make test|tart run"` — never trust task status or notifications for whether work is actually running (the wrapper-exit false-completed is real and measured).
- **Effect-level validation of a fix:** spawn the agent for a real sweep and require (a) the first notification IS the full report (no interim "waiting" text), (b) stamp matches, (c) zero `run_in_background` in the transcript, (d) model purity if pinned.

## 4. Retired theories (fates table)

| Theory | Fate | Killed by |
| --- | --- | --- |
| "Sonnet 5 ignores explicit anti-park rules (3/3 failures)" | ❌ REFUTED | The version probe: the run-3 spawn quoted the **pre-strict** section verbatim 63 s after v3 hit disk — no failed run ever received any anti-park text. |
| "Parking is a Sonnet capability/model problem → pin sweeps to the session model" | ❌ REFUTED | The control: same Sonnet model completed a 43-min, two-VM sweep with *zero* anti-park text — it just never used `run_in_background`. Post-v4, Sonnet ran three clean sweeps. |
| "Agent definitions are cached once per session → edits require a fresh session" | ❌ REFINED | A same-session spawn ~40 min after the v4 edit received it (stamp emitted from context, zero disk reads). It's unpredictable **lag**, not hard per-session freezing; the durable rule is verify-delivery-per-run, never assume. |
| "A fused atomic launch+wait call structurally prevents parking" (proposal draft) | ❌ KILLED PRE-SHIP | Red-team F1: the 600 s per-call timeout SIGTERMs the call's process tree — a fused call converts a survivable wait timeout into a workload-killer; the control's proven shape was *unfused*. Also its pedigree claim cited the unfused shape's record. |
| "Stricter/louder prompt wording is the fix" (v2→v3 escalation) | ❌ INVALID EXPERIMENT | Both escalations were drawn from runs that never received the prior wording (propagation lag). Wording remains untested as a lever; affordance removal + delivery verification is what shipped and validated. |
| "The park was caused by the wrapper's false 'completed' notification alone" | ❌ INSUFFICIENT | Run 2 *diagnosed* the false notification correctly in the same message where it parked — insight didn't convert to behavior; the affordance chain (promise + hook advice + orphaned waits) is the full mechanism. |

## 5. Re-verify by effect

To re-check the headline claims today: (1) edit any `.claude/agents/*.md` stamp, spawn the agent within a minute, and ask for the stamp — expect stale; (2) spawn `xtty-test-validator` for a quick confirm and check the three transcript greps + first-notification-is-report; (3) to re-demonstrate the strand mechanism itself, spawn any subagent that launches a 5-min command with `run_in_background: true` and ends its turn "awaiting notification" — the task completes, the child finishes unobserved, nothing resumes.

## 6. Reusable guideline (generalizes to any Claude Code subagent that outlives a tool call)

1. **Never let a subagent end its turn while its work runs.** Waiting is a tool call you are inside of (foreground bounded loops, reissued on timeout), never a state entered by stopping.
2. **Ban `run_in_background` in subagent definitions** whose workflows involve waits; its contract is main-loop-only and its result text actively misleads the model.
3. **Launch and wait unfused:** instant foreground `nohup … & echo $! > pidfile` launch, then separate foreground `while kill -0 <pid>; do sleep 30; done` waits — a wait-call timeout must never be able to kill the workload.
4. **Stamp definitions, verify delivery per run** (report-opening version line + caller check); treat any definition-change test without a passed probe as proving nothing.
5. **Write evidence incrementally to disk** (ledger + review doc) so a cut-off run is reconstructable; give the caller a documented resume-not-respawn recovery path, and record resumes (a resurrected run must be distinguishable from a clean one — the same masking logic as test retries).
6. **Trust `ps` and log tails, never notifications or task status**, for whether work is actually running.

## 7. Evidence artifacts

- Run evidence + ledgers: `~/Downloads/xtty-vm-poc/artifacts/2026-07-06-{tier01-smoke,tier2-smoke-x2,quick-confirm,quickconfirm-2,quickconfirm-3,core-only-verify,tier0-only,default-sweep-a,full-sweep,full-sweep-2}/`
- Forensics workflow journal (per-investigator findings + synthesis + red-team): session workflow `wf_0dd27ebe-e1c` (`journal.jsonl`); proposal/critique snapshots in the session scratchpad.
- Definition history: `git log -p -- .claude/agents/xtty-test-validator.md` (`765e1ec`→`6fc3bfe`→`0c74e1d`→`8355216`→`d60e628`).
- The shipped artifacts: `.claude/agents/xtty-test-validator.md` (v4), `.claude/commands/xtty/validate.md` (delivery check + babysitter protocol), `openspec/changes/add-test-validation-agent/design.md` §Apply-phase amendments (D10–D12).
