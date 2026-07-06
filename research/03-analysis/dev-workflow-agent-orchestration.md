# Dev-workflow agent orchestration — the data-fitted model for xtty's OpenSpec loop

> **Provenance:** 2026-07-07. Produced in an `/opsx:explore` session (main-session dialogue) whose downstream investigation was itself run as a **3-agent parallel fan-out** (git-history forensics · agent/context prior-art · tooling+coherence-rulebook) — sonnet search/extract tier, synthesized in the main opus session. The fan-out *dogfooded the model it was designing* (findings returned compact; raw git log + 49-doc corpus + tooling scan stayed inside the subagents). Builds on and defers to [`claude-code-subagent-execution-forensics.md`](claude-code-subagent-execution-forensics.md) (subagent mechanics), [`agents-md-context-budget.md`](agents-md-context-budget.md) (context numbers), and [`agents-and-xtty.md`](agents-and-xtty.md) (the product's agent thesis). **Design rationale — no agent built yet.** The actionable build (if pursued) belongs in an OpenSpec change; this doc is the *why* and the guardrails.

---

## TL;DR — the headline

The question was "how do we specialize agents across the whole dev loop, pick models, parallelize, and verify with the workflow harness?" The data answered it more narrowly than the question implied:

- xtty's dev workflow is **solo-human + AI, bursty, 79%-docs, 91%-research-backed, increasingly tooling-heavy, with 2–5 changes concurrent.**
- The project's own history establishes a governing rule: **agents are added *reactively*, after a recurring inline friction proves itself — never as a speculative roster.**
- Therefore the answer is **not** a roster of specialized agents. It is: **build the ONE agent whose friction is already proven every change (a change-set-aware `openspec-critic`), adopt fork-per-change authoring as a habit (no build), and defer everything else until its own friction proves it.**
- The distinctive, project-specific need a generic model misses: **cross-change coherence** (2–5 concurrent changes with shared spec requirements, archive-ordering, and red→green pairs).

## 1. The workflow's actual shape (git forensics, 34 changes / 214 commits / 11 days)

| Fact (✅ measured) | Number | Orchestration implication |
| --- | --- | --- |
| Solo human + AI | 214/214 commits `kitimark` + an AI `Co-Authored-By` | No human-coordination primitives; optimize **context-economy + parallelism** only |
| Bursty cadence | ~5.7 changes/active-day on **6** days, **0** on the other 5 | Orchestrator must be **light by default**, scale up only in bursts — no always-on rig |
| Doc-heavy | **79%** of commits `docs(openspec)`, 21% impl; ~4.3 commits/change | ★ High-value delegation targets are the **doc phases** (propose/research/reconcile), *not* code |
| Research-heavy | **91%** of changes cite a `research/` doc (49 docs, 31/34) | Authoring is **warm** (antecedent research) → a **fork** inherits it; a cold-author agent is unjustified |
| Tooling-ramping | 50/50 tooling/product overall, but recent batches ~100% tooling (07-06: 7–8/8) | The project already builds its own dev machinery; this is that trend, so hold it to the same bar |
| Concurrency | **2–5 changes open at once** (peak 5), explicit "collision protocols", joint proposals, red→green pairs | ★ The distinctive pain is **cross-change coherence** — see §5 |

## 2. The context economy (why delegation has a floor)

Deferring the mechanism to [`agents-md-context-budget.md`](agents-md-context-budget.md); the load-bearing numbers for orchestration:

- **Every Task-tool subagent inherits the full AGENTS.md/CLAUDE.md** (probe-proven): **~11–12k tokens/spawn post-slim** (was **49.3k** at fat). A 7–24-agent workflow once paid **230k–790k** tokens in guide-copies alone at fat (**49k–170k** slim).
- ⇒ **A delegation only pays off when the task's own noise exceeds the ~12k inheritance floor.** Investigate/validate/author/deep-read clear it by multiples (tens of thousands of tokens of logs/clones/spec-reads); a 2-file read does **not**. This is the quantitative form of "don't delegate trivia."
- Subagent operational constraints an orchestrator must respect (from [`claude-code-subagent-execution-forensics.md`](claude-code-subagent-execution-forensics.md)): `run_in_background` **strands** subagents (foreground unfused waits only); agent-definition edits reach spawns with **unpredictable lag** (63 s stale / 40 min fresh — verify delivery per run with a `Definition:` stamp); a `SendMessage` **resume drops a per-call model override**; transcripts never record the system prompt (only an in-context self-quote witnesses the served version).

## 3. The model (decision rules that *generate* the assignments)

```
 A. Main = thin reducer over compact agent returns + the human's thinking partner.
    Holds the decision thread + cross-cutting edits; never absorbs logs/clones/build-output.

 B. Delegate by CONCLUSION-vs-JOURNEY — does main need the ANSWER (delegate) or the REASONING (keep)?
    explore/decide = main.  investigate/research/author/verify = delegate.

 C. MECHANISM by (context-need × write-scope × duration):
       needs session context + writes  → FORK             (author a change)
       fresh + read-only               → COMMITTED AGENT  (investigate · research · critic)
       fresh + long-wait + VM/write     → COMMITTED AGENT + babysitter  (validate)
       shared-write, cross-cutting      → MAIN            (tracker reconcile · cross-change reorder)
       structured multi-stage at scale  → WORKFLOW        (propose-5 · audit-branch)

 D. MODEL tier by cognitive load: haiku (mechanical) · sonnet (search/classify/run) · opus (author/design/coherence)
 E. PARALLELISM gated by write-scope: read-only ∥ freely · writers ∥ only on disjoint dirs/worktrees · shared trackers SERIALIZE
 F. The through-line: command = launcher, agent = worker.  Complete this pattern across the loop, don't rebuild opsx skills.
```

**The launcher=worker pattern is half-built** (tooling inventory): `investigate-ci`→`xtty-ci-investigator` and `validate`→`xtty-test-validator` exist (apply→verify phase); `capture-research`→skill exists (inline, not a spawn). **explore/research, propose, and review have no `xtty-*` launcher+worker** — the gap.

## 4. The governing principle: reactive, not speculative → build ONE

The project's own history (both existing agents were added only after a repeatedly-painful inline workflow, never speculatively) is the decisive constraint. Ranking the loop's frictions by **recurrence × how-unautomated × evidence-it's-under-done**:

| Friction | Recurs | Automated today? | Under-done evidence |
| --- | --- | --- | --- |
| **coherence / tracker-drift** | **every change** | ❌ none | ★ AGENTS.md's own "**7 of 10** archived changes carry a harness delta" is **stale — actual 19/34** (nothing catches this today) |
| propose authoring | every change | ❌ inline | 79% doc-commits; this session authored 2 proposals **serially** inline |
| research capture | 91% of changes | ~ skill, inline | heavy tracker reads each time |
| source deep-read (clone OSS) | **rare** (~this session) | ❌ | too infrequent to justify a build |

Coherence-checking wins outright — every change, entirely unautomated, **provably drifting now**. That is the reactive-friction signal. So: **build `xtty-openspec-critic` first (and, for now, only)**; adopt **fork-per-change authoring** as a habit; defer the rest.

## 5. The distinctive need generic models miss: cross-change coherence

The history shows 2–5 concurrent changes with **explicit collision protocols** (changes sharing a `verification-harness` requirement needed a defined archive-ordering re-paste rule), **joint proposals with declared dependencies** (`retire-metal-renderer` + `add-xtty-test-image`), and **red→green pairs** (this session's `add-vm-prompt-width-parity` → `harden-findbar-wrap-assertion`). No existing tooling sees across changes.

⇒ The critic must be **change-set-aware**: read *all* active changes together and check shared-requirement collisions, archive-ordering, and apply-order pairs — not just single-change spec syntax. This is where "suitable for *this* project" actually lives. It also **doubles as the disk-drift detector** (the capture-research skill's manual "verify against disk" step): the same agent that checks spec coherence re-derives the counts that go stale (the `7/10`→`19/34` class). **Two jobs, one build.** State is **computed on demand** from `openspec list` + the change dirs — never cached (the project's own anti-stale-count instinct).

## 6. Retired-theory fates

| # | Theory (held earlier this session) | Verdict | Killed by |
| --- | --- | --- | --- |
| T1 | "Build a **roster of ~4** specialized agents across the loop" | ❌ | The reactive-not-speculative rule + friction ranking (§4): only coherence-checking has proven, every-change friction. Narrowed to **build one + a habit**. |
| T2 | "The orchestrator needs a **persistent in-flight-change state ledger**" | ❌ | Cross-change coherence is **computable on demand** from `openspec list` + change dirs; a cached ledger just re-introduces the stale-count problem the project already distrusts (§5). |
| T3 | "`xtty-source-researcher` is a **high-priority** build" | ❌ (demoted) | Git forensics: external-clone deep-reads are **rare**; 91% of research is *reading existing docs* (light — stays in main/fork). Build only if clone-heavy research recurs. |
| T4 | "A committed **cold-proposal-author** agent" | ❌ | 91% of changes are **warm** (antecedent research a fork inherits); no proven cold-author friction. |
| T5 | "Delegate more of the loop broadly" | ❌ (bounded) | The ~12k/agent inheritance floor (§2): sub-floor tasks are **net-negative** to delegate; explore/decide is journey-value and stays in main. |

## 7. Reproducible probes

| Probe | Re-derives | Cannot show |
| --- | --- | --- |
| `ls openspec/changes/archive/ \| wc -l` + date-prefix histogram (`ls … \| sed 's/-[^-]*$//' \| cut -d- -f1-3 \| uniq -c`) | change count + the bursty cadence | *why* the bursts cluster (needs the narrative) |
| `git log --format='%s' \| grep -c '^docs(openspec)'` vs `grep -cE '^(feat|test|chore)'` | the 79/21 doc-heavy split | per-change commit shape (needs per-change trace) |
| `git log --format='%an%n%(trailers:key=Co-Authored-By)'` | solo-human + 100% AI-co-authored | — |
| `find openspec/changes/archive -path '*/specs/verification-harness/*' \| wc -l` vs the AGENTS.md prose fraction | the drift (**19/34** vs the stale "7/10") — *the critic's headline job, by effect* | — |
| The 3-agent fan-out (this session): 3× `Agent(subagent_type:general-purpose, model:sonnet)` on disjoint read-only angles → compact returns | the model working (context stays out of main) | anything needing cross-angle synthesis — that's the caller's job |
| In-context definition probe (ask a spawn to quote its own definition) | which definition version a spawn received (lag) | — grepping the transcript for the system prompt returns 0 (dead instrument, per the forensics doc) |

## 8. Re-verify by effect (never a read-back)

- **The critic's value:** run `find openspec/changes/archive -path '*/specs/verification-harness/*' | wc -l` and compare to the fraction AGENTS.md prose currently claims — a mismatch is a live drift a coherence/drift critic would flag. (As of capture: prose "7/10", disk 19/34 — mismatched.)
- **The context saving:** delegate a doc-heavy leg (e.g. propose-authoring) to a fork and compare main's token growth vs. doing it inline — the leg's own reads should not appear in main.
- **The reactive rule holding:** before building any *second* agent, check that its friction recurs across ≥ several changes in `git log` (as coherence-checking does) — if it only appeared once (like the source-clone), don't build it.

## 9. Reusable guideline

1. **Fit the orchestration to the *measured* workflow, not the imagined one.** Here: doc-heavy (79%) + bursty + 2–5-concurrent reordered the priorities away from a code pipeline and toward cross-change doc coherence.
2. **Build agents reactively.** Add one only after its friction recurs across several changes and is provably under-done; never ship a speculative roster. (The project's own two agents are the precedent.)
3. **Pick the mechanism from (context-need × write-scope × duration)** — fork (context+write), committed agent (fresh+read-only, or +babysitter if long/VM), main (shared-write/cross-cutting), Workflow (scale). Model tier by cognitive load.
4. **Delegate above the ~12k-token inheritance floor only.** Below it, delegation is net-negative; keep it inline.
5. **Compute cross-artifact state on demand; never cache counts** — cached counts drift (this project's recurring bug).
6. **Complete the command=launcher / agent=worker pattern** rather than rebuilding shared skills; each new delegate needs a per-task carrier (a launcher or a `⟶` marker), because the apply loop doesn't re-read AGENTS.md.

## 10. Artifact pointers

- The critic's ready spec: a **28-rule coherence checklist** derived from `AGENTS.md` §162–177 (spec-delta syntax; proposal↔specs contract; MODIFIED-pastes-full-block; 4-hashtag scenarios; delegation-marker presence on suite/VM tasks; harness-delta coupling; disk-drift/count re-derivation; archive hygiene). Captured in this session's tooling-inventory investigation; it becomes the critic's `design.md` if the build proceeds.
- This session's three fan-out findings blocks (git forensics · prior-art · tooling anatomy) — the evidence base for §§1–5.
- Sibling forensics this defers to: `claude-code-subagent-execution-forensics.md`, `agents-md-context-budget.md`, `agents-and-xtty.md`.

## Sources

- **xtty git history** (2026-07-07): `git log` (214 commits), `openspec/changes/archive/` (34), `openspec/specs/` (19), `research/` (49 docs), `.claude/agents|commands|skills/`.
- **AGENTS.md** §162–177 (Keeping a change coherent + spec-delta format), the Learned-refutations list, the two delegation rules (test-validation, ci-investigation).
- **Sibling research:** `claude-code-subagent-execution-forensics.md`, `agents-md-context-budget.md`, `agents-and-xtty.md`.
