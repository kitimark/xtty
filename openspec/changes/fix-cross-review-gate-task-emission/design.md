## Context

`add-cross-model-design-review` (archived 2026-07-12) shipped a **human-attestation archive gate**. Its eligibility mechanism is a **blocking human-only task** in an in-scope change's `tasks.md` tail, which the human ticks while recording a reviewed-state digest on a delimited attestation line. AGENTS.md and `openspec/specs/cross-model-review/spec.md` both state that an in-scope change's tail **SHALL** carry exactly one such task.

**Measured reality on disk:**

| Fact | Evidence |
| --- | --- |
| `/opsx:propose` never emits the task | `grep -c -Ei 'cross-review\|attestation' openspec/config.yaml` = **0**, while all four existing point-of-tick markers *do* have `rules.tasks` entries. The propose loop reads `config.yaml`, not `AGENTS.md`. |
| Nothing blocks on its absence | `xtty-openspec-critic` v4 (L42): gate-task presence is `heuristic → REVIEW`, *"never a BLOCKER"*; L80: *"REVIEW findings never block."* |
| Both open changes violate the shipped spec | `add-ci-pipeline`, `add-git-diff-wrap-toggle` → classifier **exit 10 (in scope)**; attestation tasks in each `tasks.md` → **0**. |
| The gate has fired once, by hand | The archived change's task 5.2 was hand-authored during its own dogfood. |

The gate still **fail-closes at archive** (step-0 check (1) finds no attestation line), so nothing unreviewed slips through *silently*. The defect is that the human is never **prompted**: they learn of the requirement only when archive refuses, after the work is done. A *tool-doesn't-work-when-used* defect — **G-TARPIT-4**'s highest-value class, found by *using* the gate rather than reviewing its spec.

## Goals / Non-Goals

**Goals:**
- The blocking human-attestation task is **emitted at propose time**, from the surface the propose loop actually reads.
- A missing, duplicated, or misordered gate task is **mechanically blocking** where a mechanical scope call is available.
- `add-git-diff-wrap-toggle` is brought into conformance.
- **Zero new machinery**: no new script, agent, or marker grammar.

**Non-Goals:**
- **No auto-firing marker** (D2).
- **Not fixing the re-attestation deadlock** (check (4)) — a separate change (see R4/Open Questions: it may need to land *first*).
- **Not fixing range pollution, and not fixing the uncommitted-implementation scope bypass** (R5) — both route to the base-resolution change.
- No product code, no harness surface.

## Decisions

### D1 — The classifier is **retrospective**: before implementation lands it answers *wrongly*, not *not-at-all*

This is the load-bearing constraint, and the first draft of this design **got it wrong** — the cross-model review caught it (all three passes, independently).

`scripts/cross-review-scope.sh:54` scopes from `git diff --name-only "$B"..HEAD` — **paths that have already landed**. It never sees paths a change *declares it will touch*. So its verdict is not a property of the change; it is a function of *(repo HEAD, what is committed so far)*, and it **moves across the change's lifecycle**:

```
uncommitted            → exit 2   (no proposal.md commit to anchor B)
propose committed      → exit 0   ← "OUT of scope": only the change's own artifacts have landed,
                                    and openspec/changes/** is allowlisted
implementation landed  → exit 10  ← "IN scope": config.yaml, .claude/, openspec/specs/ now in range
```

**Measured live on this very change** (committed as `3815113`):

```
$ scripts/cross-review-scope.sh fix-cross-review-gate-task-emission
base 895088430b9b .. HEAD  (6 changed path(s))
SCOPE: out — every changed path is inside the docs/tracker allowlist   → exit 0
```

The consequence is the whole point: **only exit 10 is positively informative.** `exit 0` and `exit 2` do **not** mean "out of scope" — they mean *"not yet knowable to be in scope."* Before implementation lands, the classifier returns a confident **false negative**, not an abstention.

So the propose-time scope call is irreducibly **semantic** — not because the classifier *cannot answer* (it can), but because the answer would be a *prediction about paths that do not exist yet*, which no retrospective tool can make. A semantic call cannot carry blocker force. Hence two layers:

| Layer | When | Scope call | Force |
| --- | --- | --- | --- |
| **Emission** — `config.yaml` `rules.tasks` | propose | **semantic**, fail-closed (when in doubt, emit) | authoring instruction |
| **Enforcement** — critic gate-task check | any time; *dispositive* once implementation lands | **mechanical only when `exit 10`** | **BLOCKER** |

### D2 — An authoring rule, NOT a delegation marker

AGENTS.md refutes an auto-firing `⟶ xtty-cross-review` marker: *"a paid review that must not fire on task-arrival is neither delegate-to-subagent nor run-inline."* Reintroducing one would either fire a **paid** external review on task arrival, or hand a **human-only** act to a subagent — both prohibited.

The `config.yaml` rule therefore targets the **author**: *"when authoring an in-scope change's tail, write this task."* The **task's own text** carries the HUMAN-ONLY / model-MUST-STOP instruction the apply loop reads at the point of tick. Emission and firing stay separate; the model-STOP boundary is untouched.

*Why `config.yaml` and not AGENTS.md:* AGENTS.md **already** says this and it demonstrably did not reach the loop — the repo's own G13 refutation. `config.yaml` `rules.tasks` is the *only* surface `/opsx:propose` reads. Mirror the four working rules, and **defer to AGENTS.md for the boundary**.

### D3 — The gate-task text MUST NOT ride the attestation commit

Archive check (4) requires the attestation-introducing commit's `tasks.md` hunk to be **confined to the attestation line + checkbox ticks** — *no reviewed artifact*. Adding the gate-task **text** in that same commit violates the confinement clause.

**Measured by effect** (throwaway repo, real digest tool; the checkbox-state must be normalized before diffing, or a *tick* is indistinguishable from a *new task line*):

| | confinement |
| --- | --- |
| gate-task text **+** attestation in **one** commit | **VIOLATED** — the new task line rides the attestation hunk ⇒ check (4) fails |
| gate-task text in commit A, attestation in commit B | **SATISFIED** ⇒ check (4) passes |

**Honest scope of this decision — it is narrower than the first draft claimed.** The first draft asserted this makes the one-layer alternative (*"skip the config rule; just make the critic BLOCK at pre-archive"*) **mechanically unsatisfiable**. **That is false, and this change's own review refuted it**: a human prompted by a pre-archive BLOCKER can simply add the task in one commit and attest in the next — two commits, confinement satisfied. So check (4) does **not** force propose-time emission; it only forbids **bundling**.

What survives is a real **procedural constraint**, not a proof: the migration commit (4.1), and any hand-added gate task, MUST be a **separate commit** from any later attestation. The two-layer split stands on **D1** alone (propose-time scope is irreducibly semantic, and an obligation stated only in the guide demonstrably does not reach the propose loop — G13), not on check (4).

**Why the confinement clause is nonetheless load-bearing (a review finding worth keeping).** A *sophisticated* bundle — commit the task text, compute the digest on that state, then `git commit --amend` the attestation line and ticks **into that same commit** — passes check (1), check (2), check (3), **and** check (4)'s `adds==1 && dels==0` counter. **Only the confinement clause catches it** (the hunk carries a new task *line*, not a checkbox-state *tick*). So confinement is the sole guard against an attestation that silently carries unreviewed task text. **Constraint on the sequenced check-(4) change:** any fix to the re-attestation deadlock targets the `adds==1 && dels==0` counter — it **MUST preserve the confinement clause**, which is a *separable* clause. The design does not otherwise depend on check (4), but this one clause it does.

### D4 — Four arms; only `exit 10` carries blocker force, and **no arm suppresses the check**

The first draft made `exit 0` mean *"out of scope ⇒ SHALL NOT flag"*. That is **fail-open**: since the normal post-propose state *is* `exit 0`, it would have **mandated silence on a missing gate task for the entire propose→implement window** — a regression against today's v4 REVIEW, and a direct contradiction of D5's fail-closed principle. Corrected:

| classifier | Critic behavior |
| --- | --- |
| **exit 10** (in scope — dispositive) | gate task absent, **duplicated**, **misordered**, or lacking human-only wording ⇒ **BLOCKER** |
| **exit 0** (*not yet knowable to be in scope*) | **semantic** judgment, at most **REVIEW**, **never suppressed** — and state that the classifier returned "out" |
| **exit 2**, `proposal.md` **absent from HEAD** (genuinely uncommitted) | **semantic** judgment, at most **REVIEW** |
| **exit 2**, `proposal.md` **committed** (a malformed range: dir touched before `proposal.md`, root commit, missing dir) | **BLOCKED-PREREQUISITE**. *Measured:* on such a range **both** committed tools refuse (`cross-review-scope.sh` **and** `cross-review-digest.sh`, exit 2, `range-omission`), so step-0's check (2) **cannot be satisfied**. Honest limit: no committed rule yet *requires* step-0 to run on a refusal (its SHALL is conditioned on *"in scope"*, and a refusal is neither in nor out) — the same shape as R5, and it reduces to the accepted model-only-loop residual. Blocking at review is therefore the right call regardless, but the design does **not** claim archive is mechanically forced to refuse. |

**Zero false-positive cost on the `exit 0` arm:** a genuinely docs-only change is `exit 0` *and* the semantic read says "out", so it is still not flagged. The arm only ever adds a REVIEW where the semantic read says "in" — which is exactly the case that must not be silent.

### D5 — Fail-closed at propose, mirroring the classifier's own rule

The classifier already treats an **ambiguous path as in scope (fail-closed)**. The authoring rule adopts the same posture: **when the in-scope call is uncertain, emit the task.** Over-emission costs one strikeable task; under-emission is the defect being fixed.

### D6 — Enforce cardinality and ordering, not just presence

The shipped spec requires **exactly one** attestation task, **placed after the coherence-review task and before the archive task**. Presence-only enforcement misses both other failure modes: a **duplicate** stops the checkbox loop twice, and a task placed **after** archive means step-0 fails before the human is ever prompted — the same expensive late failure. So the `exit 10` BLOCKER covers absent **or** duplicated **or** misordered **or** missing-human-only-wording.

### D7 — Migrate `add-git-diff-wrap-toggle` only; **exclude `add-ci-pipeline` deliberately**

`add-git-diff-wrap-toggle` has a `⟶ xtty-openspec-critic` task to anchor against and a ~33-file digest range. It is migrated.

`add-ci-pipeline` is **excluded, as a recorded decision, not an oversight**:
- it has **no** `⟶ xtty-openspec-critic` task, so *"place after the critic task"* has **no anchor**;
- its digest range is **~315 files (98.4% foreign)** — and HEAD-dependent, so it grows with every commit — the human would be asked to attest a review of code they did not write;
- its remaining work is *owner steps* (repo public, pr-lint PR, branch protection); the pr-lint PR is **itself a commit**, which restages the HEAD-dependent digest — and check (4) forbids re-recording an attestation, so any attestation made before those commits is **unrecoverable**.

Appending a blocking task whose only satisfying act is impossible is worse than not appending it. Its disposition belongs to the base-resolution change.

**Two accepted residuals the exclusion creates — recorded, not glossed** (the first draft said "strands nothing", which is too strong):

1. **A standing, unclearable critic BLOCKER.** Once this change lands, the coherence-review spec **mandates** a BLOCKER whenever the classifier reports in scope and the tail lacks the gate task. `add-ci-pipeline` is `exit 10` and, by D7, will permanently lack the task — so every `/xtty:review add-ci-pipeline` and every change-set pass will emit a BLOCKER that **no D7-permitted action can clear** until the base-resolution change disposes of it. **Accepted:** the alternative is handing the human an unsatisfiable obligation, which is worse than a loud, honest, standing flag.
2. **Archive nonetheless remains reachable for it — but only via a mechanism worth stating.** Step-0's check (1) greps for the **attestation line**, not for the gate **task**. So a human *could* attest `add-ci-pipeline` with a line-only commit (which satisfies confinement precisely because it adds no task text). Without saying so, a reader would reasonably conclude D7 renders it un-archivable. It does not.

### D8 — Test precision vs. the claim

- **Emission** lives in `config.yaml` prose consumed by a **model**. No mechanical assertion can prove a model follows prose, so it is verified **by effect**: run `/opsx:propose` on a scratch in-scope change and observe the emitted tail. *(A grep asserting the rule string exists in `config.yaml` is a read-back check, not evidence, and is explicitly not the test.)* The natural experiment already on disk supports the mechanism: `add-git-diff-wrap-toggle`'s propose-generated `tasks.md` carries **every applicable** config-backed marker — three of the four (`⟶ xtty-test-validator`, `⟶ xtty-openspec-critic`, `⟶ archive-ritual`; `⟶ xtty-ci-investigator` is correctly absent, its rule being conditional on a failed-CI task) — and **zero** attestation task: the one obligation with no config rule.
- **Enforcement** lives in the critic's classifier-driven branch. Verified **by effect** across all four arms of D4 (exit 10 ⇒ BLOCKER incl. duplicate/misordered; exit 0 ⇒ REVIEW not silence; exit 2 uncommitted ⇒ REVIEW; exit 2 committed-malformed ⇒ BLOCKED-PREREQUISITE).

No `verification-harness` delta: dev-workflow tooling, no observable app behavior.

## Risks / Trade-offs

- **R1 — The fix cannot be emitted by the rule it introduces.** This change was proposed before the rule existed, so its own attestation task was added **by hand**. The bug reproducing on itself; the *next* in-scope change is the first real test of emission.
- **R2 — A semantic propose-time call will sometimes be wrong.** → D5's fail-closed posture makes the error direction **over-emission** (harmless), and D4's mechanical BLOCKER is the backstop.
- **R3 — Range pollution makes the classifier say "in scope" for the wrong reason.** Measured: `add-git-diff-wrap-toggle` classifies in-scope on **8 paths that are all foreign** (its own 7 are 100% allowlisted). Under a BLOCKER, that becomes a blocking obligation. → **Accepted for the BLOCKER's *direction*** (pollution over-includes; it can never *under*-trigger a bypass) — **but the *cost* is not "one unnecessary review"** (see R4).
- **R4 — ⚠️ The real cost of R3: a BLOCKER + pollution + one-shot attestation is an *unrecoverable* combination.** The digest covers HEAD content of **every** file in `B..HEAD` (~33 files for `add-git-diff-wrap-toggle`; ~316 for `add-ci-pipeline` — both HEAD-dependent), so it is a function of repo HEAD — **any** commit anywhere restages it. Once stale, re-attestation requires editing the attestation line, which flips check (4) to `adds=2, dels=1` — **permanently failing**, with no forward-history recovery. This change promotes that hazard from *once-per-dogfood* to *once-per-change*. → **ESCALATED, not mitigated here — see Open Questions.**
- **R5 — ⚠️ Pre-existing gate bypass, verified, NOT fixed here: the scope call is blind to *uncommitted* implementation.** Clean-room measured: with real product code present but uncommitted, the classifier reads `exit 0` ⇒ AGENTS.md step-0 applies the precondition only *"for a change in scope"* ⇒ **the entire four-check precondition is skipped and `openspec archive` proceeds.** The counterintuitive crux: `cross-review-digest.sh`'s dirty-tree refusal does **not** backstop this, because that refusal is *check (3)*, which lives **inside** the precondition that was skipped. → **Named, deliberately not fixed here:** fixing it means editing `cross-review-scope.sh`, which drags in the reviewed-base self-validation rule that task 6.3 currently (correctly) asserts does not apply. Route to the base-resolution change: give the classifier the same dirty-tree refusal the digest tool already has.
- **R6 — A stale-served agent definition would silently keep v4 behavior.** → Bump the stamp to **v5**; a run reporting v4 is invalid, not a pass.
- **R7 — Trade-off: the gate now fires more often.** Accepted: the mechanical classifier is the authority, over-inclusion costs a review, and the alternative is the status quo being fixed.

## Migration Plan

Additive. The `config.yaml` rule affects only future propose runs; the critic upgrade only future reviews; `add-git-diff-wrap-toggle`'s tail gains one task (a **separate commit** from any attestation, per D3). Rollback = revert; the gate returns to its inert-at-propose state. No attested state is involved.

## Open Questions

- **⚠️ SEQUENCING — the most consequential open decision, escalated to the human. Now a TWO-MODEL consensus.** **Both** soundness passes independently argue this change should land **after** the check-(4) deletion and the range-pollution/dirty-tree fix — Pass C in round 1, Pass B (`gpt-5.6-sol`) in round 2, which returned an explicit *"no-ship: leaves a verified archive bypass and makes an unrecoverable attestation deadlock routine."* The reason: it makes the gate fire *reliably* into an attestation model with an **unrecoverable** failure mode (R4) and a **verified bypass** (R5). *(Note: Codex's proposed remedy — "append-only, superseding attestation generations" — is the **refuted "recoverable attestation epoch"** (G-TARPIT-1/2). Its **sequencing** argument stands; its **remedy** does not.)* The counter-argument for landing it **first** is that the deadlock is only *reachable* once a change acquires an attestation, and today nothing prompts one. Both are coherent; note that the archive gate **already** applies to both open changes (`exit 10`) with or without this change, so this change does not *create* the exposure — it makes it routine. **The human decides the order.**
- Should `cross-review-scope.sh` gain a dirty-tree refusal (R5)? **Yes — but in the base-resolution change**, not here.
