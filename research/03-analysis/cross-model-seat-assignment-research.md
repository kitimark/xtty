# Cross-model seat assignment — reframing the Fable/GPT role split

## Provenance

Generated 2026-07-19 from a two-stage investigation: (1) a 6-agent Workflow fan-out (5 parallel Fable-5 research angles — one per stated Fable-5 strength — plus a Fable-5 synthesis pass) evaluating a user-proposed model-role split against xtty's live tooling; (2) a human-driven `/opsx:explore` session pressure-testing the synthesis's three candidate changes against the actual `cross-review.md`/`spec.md` text and git history, followed by an independent Fable-5 critique pass of that pressure-testing. All git/file claims below were re-verified directly against repo state before being written down here, not taken on an agent's citation alone.

## Sources

- `.claude/commands/xtty/cross-review.md`, `openspec/specs/cross-model-review/spec.md` — the reviewed system
- `research/03-analysis/cross-model-pairing-consult-research.md` (G-CONSULT-1..15) — the zombie-rate and apply-stage-value evidence this doc leans on
- `.claude/commands/xtty/research.md` — the prior "Fable 5 intentionally unused" tiering decision
- `git log` over the full repository history (a `Co-Authored-By` trailer census)
- Live `codex:rescue`/`codex-companion.mjs` job telemetry from this investigation's own two zombie incidents

## The proposal, and the verdict

The user proposed a task-type model-role split: **Fable 5** = clarify requirements / analyze long documents / identify assumptions+risks / develop alternatives / critique; **GPT-5.6-sol** = turn plans into deliverables / write+debug code / technical implementation / structured research / produce the final integrated output.

✅ **Verdict: reject the task-type framing; keep a narrower, already-partially-built "epistemic seat" framing instead** — author vs. independent reviewer/falsifier-runner vs. non-participant merger. Three concrete follow-ons were evaluated; each is disposed separately below.

## Mechanism: why "seat" beats "task type" here

- Cross-review's Pass A/B/C already assign models by **seat**, not by task type: Pass A = conformance (Opus), Pass B = external soundness (GPT, read-only), Pass C = inline soundness — **spec-required** to share Pass A's model family (`spec.md`: *"the soundness pass sharing the conformance agent's model family SHALL run inline"*). The two-soundness-passes-distinct-families requirement binds B against C, not C against A.
- The **author seat is always Claude-family**, verified: `git log --all --format='%(trailers:key=Co-Authored-By,valueonly)' | sort -u` returns only `Claude Fable 5`, `Claude Opus 4.8 (1M context)`, `Claude Opus 4.8`, `Claude Sonnet 5` — **never** a GPT/Codex trailer, across this repo's entire history.
- This project's one **FIRM** empirical cross-model result (G-CONSULT-8/10, `cross-model-pairing-consult-research.md`) is specifically: GPT **reviewing** Claude-authored code at the apply stage produces 4 stage-exclusive, cross-family-disjoint findings — not GPT authoring anything.
- The task-type split, taken literally, inverts this: GPT authors ("produces the final integrated output"), Claude-family becomes the reviewer — handing the reviewer seat to the side that, on the one measured anchoring incident in the pairing-consult doc, **folded and published a false "converged" consensus its partner then refuted** (⚠️ that incident is itself flagged SUGGESTIVE/CONFOUNDED, n=1, in the source doc — noted honestly, not overclaimed here).
- It also collides with the archive gate's own authority rule: **no model-authored artifact may gate archive; a participating model may never author the synthesis.** "GPT produces the final integrated output" reintroduces exactly the authority shape that rule was built to refuse.

## Disposition of the three candidates

### #1 — Pin cross-review's Pass C to Fable 5 (currently: inline Opus)

**Status: legitimate, bounded experiment — reframed.**

Spec-legal either way: Pass C only has to share Pass A's family, and Opus/Fable are both Claude-family, so the requirement that actually matters (B vs. C distinct families) is untouched by this swap. But it is a **checkpoint swap within one vendor, not a third independent family** — the original synthesis's "Opus-conformance / GPT-soundness / Fable-soundness = 3-way diversity" framing overstates it, and any resulting spec/proposal text should say so plainly. A tension worth stating rather than eliding: `.claude/commands/xtty/research.md` already records *"(Fable 5 is intentionally unused — not an analytical-reasoning tier)"* for the research fan-out's own tiering. This proposal doesn't relitigate that line — it's a different use (review diversity, not analytical-tier ranking) — but the two decisions sit close enough that a future reader could reasonably ask why they differ.

**Evaluation-methodology correction** (from the Fable-5 critique pass): judge success by a **human** reading the ledger for genuine Pass-A/Pass-C disjointness across several runs — not by a model computing its own "disjointness" score (one step from the self-certification shape the archive gate exists to refuse), and not by within-family disjointness alone (the disjointness phenomenon this project actually measured was cross-family; within-family agreement or disagreement could just be prompt variance).

### #2 — Add an "author-family" ledger field + suppress the consensus flag when reviewer-family == author-family

**Status: defer — the field would read a permanent constant.**

Mechanically cheap: git already carries a per-commit `Co-Authored-By` trailer naming the exact authoring checkpoint, so `git log B..HEAD --format='%(trailers:key=Co-Authored-By,valueonly)'` would work today with zero new bookkeeping. But **every candidate on the table, including #3, keeps Claude-family as the sole author** — so the suppression logic could never fire under anything currently proposed. That is the same defect shape as the archive gate's already-diagnosed `exit 0` scope-classifier arm: a check that has decayed to a non-attributive constant. Building it now is premature machinery for a scenario nothing here causes.

**Conditional note** (from the Fable-5 critique pass): the deferral holds only **as long as #3 stays strictly find-only**. Git trailers measure who *typed* a commit, not whose *idea* it was — if a future #3 pilot ever lets Codex *propose* a fix that a Claude session merely transcribes, authorship blurs invisibly past this check, and #2 would need re-opening.

### #3 — Extend GPT-5.6-sol to an optional "falsifier-runner" step at apply-time

**Status: real premise, no new standing infrastructure yet — needs a corrected pilot design.** See the dedicated section below; this is where most of the investigation's substance lives.

## The #3 investigation, in detail

### Why the premise is sound

G-CONSULT-13 (`cross-model-pairing-consult-research.md`): the value test for a cross-model consult is *"could either model retrieve this answer from something it has read?"* — not *"is this code?"*. Freshly-implemented code from an apply step has no existing answer key, which is exactly where this project's one FIRM cross-model result was measured. The conceptual case for #3 is sound; the open problems are entirely operational.

### What's actually unmeasured

G-CONSULT-10 already proves apply-stage Codex **review** adds value (4 stage-exclusive, cross-family-disjoint findings, zero overlap). A #3 pilot that just re-confirms "Codex-at-apply helps" is re-testing an already-answered question, and any result from it is uninterpretable. **The actually-open question is narrower: does EXECUTING falsifiers/drills add anything beyond READING the diff, which Pass B already does statically.** A pilot must be designed to isolate that specific delta, not the one G-CONSULT-10 already settled.

### The operational hazard, confirmed live twice

Two `codex:rescue` background-task calls in this exact investigation zombied — `status` stayed `"running"` indefinitely while the underlying job was dead. This matches a previously-measured, well-documented failure mode: `cross-model-pairing-consult-research.md` §12e/12e-bis records **~40% of `codex task` runs zombie** (4 of 10 in that doc's population), **cause explicitly unestablished** — concurrency and packet-size theories were both raised and then refuted by a later observation in the very same document (a self-inflicted violation of that doc's own "check the population, not the sample" rule). The doc's own conclusion stands: **ship the detector, not a fix for an unestablished cause** (G-CONSULT-14).

**The discriminator used live tonight (`ps -p <pid>` on the job's recorded pid) was inferior to the one already established in this repo's own research, and happened to work only by luck** (the supervising process had also died both times). The validated method, already on record before this investigation started:

- Poll **log-file growth**, not the `status` field — `wc -c` on the job's `logFile`; **≥5 min of zero growth = death**. `status: running` is not a liveness signal; the companion can keep reporting it after the underlying thread is gone.
- Confirm via `grep -c 'Turn completed' <job>.log` — **1** = real completion, **0** plus `"thread not found: <thread-id>"` on `cancel` = a confirmed zombie.
- **Never read `run_in_background`'s `exit 0` as completion** — it returns immediately regardless of the job's real state.
- Landmine: **`codex task --help` runs a task** — no help flag exists on that subcommand; the string becomes the prompt.

A subagent handed a `codex:rescue` background call **cannot** poll or cancel its own job (a task-verb-only restriction observed live in this investigation), and its "I'll report back once it completes" promise is **false** — a subagent that ends its turn mid-work is never resumed. The general form of this is already an AGENTS.md Learned Refutation; this investigation is a concrete, fresh, `codex:rescue`-specific confirmation of it. Any #3 design must run from the **driving session itself**, backgrounded via the harness's own `run_in_background`, polled directly — the same architecture cross-review already built for Pass B, not a new one.

### Corrected pilot design

1. **Isolate running-vs-reading** — give the pilot a drill/falsifier to *execute*, not just a diff to review; something Pass B's static read cannot already produce.
2. **Detectable non-gating degradation, mandatory** — a zombied run must be explicitly stamped "did not complete" in the pilot's own output, never silently absent. Without this, at a documented ~40% activation rate, the check is a fixture that never fails: decoration, not a safety net.
3. **Promotion bar: recurrence across ≥2 independent pilots finding something distinct, not one.** A single trial finding one thing is the same n=1-promotion shape this project's anti-speculative-roster rule, and this project's own zombie-cause misfire (an n=3 causal claim killed by a 4th observation), both already forbid.
4. **A real `tasks.md` line, not a conversational agreement.** "Trial it on the next code-heavy apply," recorded only in chat, will not happen on its own: this project has a named, measured instance of exactly this failure (`fix-osc7-hostname-reverse-dns`'s archive stalled because its completion procedure lived only in prose and never reached the `tasks.md`-walking apply loop). The pilot needs its own task line with a marker before it can be expected to fire.

## An independent bug found in passing

AGENTS.md's Learned Refutations list cited `research/03-analysis/cross-model-pairing-consult-research.md` as `(G-CONSULT-1..11)`. The document itself runs through **G-CONSULT-15**, including G-14/15 — the zombie-detection and thesis-statement guidelines this very investigation depended on. **Fixed as part of this capture** (2026-07-19; `AGENTS.md`, the "second model earns its cost by RUNNING falsifiers" bullet).

## Reproducible probes

```sh
# Author-family census — confirms Codex has never authored a commit here
git log --all --format='%(trailers:key=Co-Authored-By,valueonly)' | sort -u
# → Claude Fable 5 / Claude Opus 4.8 (1M context) / Claude Opus 4.8 / Claude Sonnet 5 — never GPT/Codex

# Zombie discriminator (the validated method — NOT ps -p <pid>)
wc -c "$LOGFILE"                                    # re-poll after ~5 min; zero growth = death
grep -c 'Turn completed' "$LOGFILE"                 # 0 = never completed
node codex-companion.mjs cancel <job-id> --json     # look for "thread not found" in the response/log

# Stale-citation check — re-run to catch the next drift
grep -c '^### G-CONSULT-' research/03-analysis/cross-model-pairing-consult-research.md   # highest number in the doc
grep -n 'G-CONSULT-1\.\.' AGENTS.md                                                       # what the guide currently cites
```

*What these prove, and what they can't*: the author census proves Codex has never authored in *this* repo's recorded history — it cannot prove no future commit ever will (re-run it before trusting #2's deferral). The zombie discriminator confirms a specific job's fate; it cannot explain *why* zombies happen (the cause remains unestablished per the source doc — don't cite a cause). The citation check only catches drift if re-run after a future edit to the source doc.

## Fates table

| Claim | Fate | Killed / corrected by |
| --- | --- | --- |
| "Fable=thinker, GPT=builder, GPT produces the final integrated output" (the user's proposed split, taken literally) | ❌ **REFUTED** | inverts the repo's one FIRM cross-model result (GPT reviews, doesn't author); collides with "no model-authored synthesis" (archive-gate authority rule); ~40% zombie rate makes a sole-executor pin an outage risk |
| "Pass C → Fable gives 3-way family diversity" (original synthesis framing) | ❌ **REFUTED, reframed** | `spec.md` requires Pass C to share Pass A's family — it's a checkpoint swap within Claude, not a third family |
| "#2 (author-family ledger field) is needed now" | ❌ **REFUTED — premature** | git-trailer census: every author in this repo's history is Claude-family; the suppression logic can't fire under any candidate on the table |
| "`ps -p <pid>` is a valid Codex-job liveness check" | ⚠️ **SUPERSEDED — worked by luck** | the validated method (log-growth + `Turn completed` grep + cancel's `thread not found`) was already on record and is more general |
| "Judge #1's Pass-C-swap success by ledger disjointness" (as originally stated, unscoped) | ❌ **REFUTED, corrected** | must be human-judged and cross-family-only; a model self-scoring disjointness is one step from self-certification; within-family disjointness may be noise |
| "Pilot #3 once, ad hoc; formalize if it finds one thing" | ❌ **REFUTED, corrected** | n=1 promotion is the same shape the anti-roster rule and this project's own n=3 zombie-cause misfire both forbid; also re-tests an already-answered question (G-CONSULT-10) unless the pilot isolates running-vs-reading specifically |
| "A conversational agreement to pilot #3 later will happen" | ❌ **REFUTED** | matches the already-documented `fix-osc7` archive-stall shape; needs a real `tasks.md` line |
| AGENTS.md's `(G-CONSULT-1..11)` citation | ❌ **STALE** | the doc runs through G-CONSULT-15; fixed in this capture |

## Reusable guidelines

- **G-SEAT-1** — Reframe cross-model role questions as **which epistemic seat** (author / independent reviewer-falsifier / non-participant merger), not **which task type**. A task-type split risks handing the reviewer seat to whichever family authored the work, destroying the one property (independence) that makes a second model worth paying for.
- **G-SEAT-2** — A model swap that keeps the same vendor/family as an already-pinned seat is a **checkpoint-diversity experiment**, not a new-family upgrade. Label and evaluate it as such; don't inflate the diversity claim in spec/proposal text.
- **G-SEAT-3** — Don't build ledger/consensus machinery keyed on a scenario git history shows has **never occurred** and that no proposal on the table would cause. A field with a permanently-constant value is the same defect class as a scope classifier's dead waiver arm.
- **G-SEAT-4** — Verify a backgrounded reviewer's liveness by **output growth**, never by a status field or a supervisor-process check alone — a pid-liveness check can coincidentally work and mask the actually-validated discriminator (log growth + a completion-marker grep + the cancel response).
- **G-SEAT-5** — A pilot's promotion bar and its measured variable must match: (a) require recurrence across multiple trials, not one; (b) design the pilot to isolate the actually-open question, not re-confirm an already-measured one; (c) give the pilot a real task-line marker — a plan that lives only in conversation does not reach the `tasks.md`-walking apply loop.

## Re-verify by effect

- Re-run the author-family census (`git log --all --format='%(trailers:key=Co-Authored-By,valueonly)' | sort -u`) after any future change that touches `codex:rescue`'s write permissions — if a GPT/Codex trailer ever appears, #2's deferral needs re-opening.
- Re-check `research.md`'s "Fable 5 intentionally unused" line still stands before ever pinning Fable to a new analytical seat — if that decision is revisited, #1's framing needs revisiting too.
- If #1 is ever trialed, the re-verification is a **human** read of several runs' ledgers for genuine Pass-A/Pass-C disjointness — not a percentage a script or model computes.
- If #3 is ever piloted, re-verify by whether the pilot's own output explicitly distinguishes "ran and found nothing" from "did not complete" — if the two are indistinguishable in the output, the degradation-stamping requirement wasn't met.

## Evidence artifacts

- This capture: `research/03-analysis/cross-model-seat-assignment-research.md` (this file)
- Citation fix: `AGENTS.md` — the "second model earns its cost by RUNNING falsifiers" Learned Refutation bullet
- Reviewed system: `.claude/commands/xtty/cross-review.md`, `openspec/specs/cross-model-review/spec.md`
- Prior research this builds on: `research/03-analysis/cross-model-pairing-consult-research.md` (G-CONSULT-1..15), `research/03-analysis/cross-model-design-review-axes.md`, `.claude/commands/xtty/research.md`
