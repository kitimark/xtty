## Context

`add-cross-model-design-review` (archived 2026-07-12) shipped a **human-attestation archive gate**. Its eligibility mechanism is a **blocking human-only task** in an in-scope change's `tasks.md` tail, which the human ticks while recording a reviewed-state digest on a delimited attestation line. AGENTS.md and `openspec/specs/cross-model-review/spec.md` both state that an in-scope change's tail **SHALL** carry exactly one such task.

**Measured reality on disk:**

| Fact | Evidence |
| --- | --- |
| `/opsx:propose` never emits the task | `grep -c -Ei 'cross-review\|attestation' openspec/config.yaml` = **0**, while all four existing point-of-tick markers *do* have `rules.tasks` entries. The propose loop reads `config.yaml`, not `AGENTS.md`. |
| Nothing blocks on its absence | `xtty-openspec-critic` v4 (L42): gate-task presence is `heuristic → REVIEW`, *"never a BLOCKER"*; L80: *"REVIEW findings never block."* |
| Both open changes violate the shipped spec | `add-ci-pipeline`, `add-git-diff-wrap-toggle` → classifier **exit 10 (in scope)**; attestation tasks in each `tasks.md` → **0**. |
| The gate has fired **twice**, both times with a **hand-authored** task | `add-cross-model-design-review`'s own dogfood (task 5.2), and `brief-cross-review-pass-b` (task 4.2, archived 2026-07-13 through the **full** gate). ⚠️ **Round-4 correction — an earlier draft said "once", and the second firing matters:** it proves the convention *can* reach an author with `config.yaml` still at **0** hits. It does **not** prove the loop emitted it (git cannot distinguish loop-emitted from hand-added in the same commit), so it is **not** counter-evidence either. See the anachronism record in `proposal.md` → Why. |

The gate still **fail-closes at archive** (step-0 check (1) finds no attestation line), so nothing unreviewed slips through *silently*. The defect is one of **carriage, not of observed failure**: the obligation is stated only where the propose loop never looks, so whether an author gets prompted depends on whether that author happened to be carrying the guide's context. ⚠️ **An earlier draft called this a measured *"tool-doesn't-work-when-used"* defect. That framing is withdrawn** — round 4 showed the supporting evidence was **anachronistic** (both non-conforming changes predate the obligation) and the one clean post-gate change *did* carry the task. The case is **G13** (prose does not reach the loop; `rules.tasks` does), which is already settled by measurement elsewhere and needs no fresh empirical claim here. *(**G-TARPIT-4** still applies, but as a **method** note: what this change genuinely surfaced by **using** the gate — rather than reviewing its spec — is the structural range-pollution latch of D1/R3, not the emission story.)*

## Goals / Non-Goals

**Goals:**
- The blocking human-attestation task is **emitted at propose time**, from the surface the propose loop actually reads.
- A missing, duplicated, or misordered gate task is **mechanically detected and reported as a BLOCKER** where a mechanical scope call is available. ⚠️ **Detected, not enforced** — and the difference matters: this enforcement layer is **prose in an agent definition**. **Nothing executable consumes a critic BLOCKER** — no script refuses, no gate fires. Per **G-GATE-1**, *"fail-closed is an instruction-following convention, not an enforced property"*; this change upgrades the gate-task check from REVIEW-prose to BLOCKER-prose, which is a **real** improvement in what the human is shown, but it does **not** make the check executable. An earlier draft's *"mechanically blocking"* overclaimed. The BLOCKER's entire force is the reader's attention — which is why the standing-red surface (D7) is a first-order cost, not a cosmetic one.
- The disposition of the two pre-gate open changes is **decided by the human** (D7 — escalated, not settled here).
- **Zero new machinery**: no new script, agent, or marker grammar.

**Non-Goals:**
- **No auto-firing marker** (D2).
- **Not fixing the re-attestation deadlock** (check (4)) — a separate change (see R4/Open Questions: it may need to land *first*).
- **Not fixing range pollution, and not fixing the uncommitted-implementation scope bypass** (R5) — both route to the base-resolution change.
- No product code, no harness surface.

## Decisions

### D1 — The classifier is **non-attributive**: its verdict is a property of the *range*, never of the change

This is the load-bearing constraint. **It has been re-anchored twice.** The first draft claimed the classifier *cannot run* at propose (refuted: it can). The second claimed it is merely **retrospective** — that a change reads `exit 0` until its own implementation lands. **Round 4 refuted that too, by measurement on this very change** (below). What survives — and what no measurement has falsified — is the deeper property: **the classifier cannot attribute a path to a change.**

`scripts/cross-review-scope.sh:54` scopes from `git diff --name-only "$B"..HEAD`, where `B = parent(<the proposal.md commit>)`. That range is **repo-wide**: it contains *every* commit that landed after the change was proposed, by anyone, for any reason. The classifier therefore answers *"is some path in this range out-of-allowlist?"* — **not** *"is this change in scope?"* Three consequences, all measured:

- **Non-attributive.** An `exit 10` verdict says only that *some* path in the range is out-of-allowlist. It **cannot** say whose. So it is never evidence that *this change's* implementation landed.
- **Retrospective.** It reads committed paths only, so it can never answer a *propose-time* question about paths that do not exist yet.
- **⚠️ Monotone under intervening archives — and this is the one that bites.** `openspec archive` **always** writes `openspec/specs/**`, which is **not** in the allowlist (verified: `scripts/cross-review-scope.sh:45-51` allowlists `openspec/changes/*`, `research/*`, the four root docs, and `packer/README.md` — nothing else). So **any change left open across any other change's archive latches to `exit 10` permanently, and can never return.** With concurrent changes — the repo's normal state — this is the common case, not the exception.

**Measured live on this very change, 2026-07-13** (at **1/20 tasks — zero implementation landed**):

```
$ scripts/cross-review-scope.sh fix-cross-review-gate-task-emission
base 895088430b9b .. HEAD  (21 changed path(s))
SCOPE: in — 2 path(s) outside the docs/tracker allowlist:
  .claude/commands/xtty/cross-review.md
  openspec/specs/cross-model-review/spec.md
                                                                        → exit 10
```

**Both driving paths are foreign** — introduced entirely by `brief-cross-review-pass-b` (`ca7b235`, `39fd78c`, and its archive `c47a5c1`). This change's own 7 paths remain **100% allowlisted**. The earlier draft's headline demonstration (*"it reads `exit 0` — the bug reproducing on itself"*) is **dead**: the verdict flipped to `exit 10` without this change touching anything.

So the propose-time scope call is irreducibly **semantic** — not because the classifier cannot answer, but because **no answer it can give is about this change.** A semantic call cannot carry blocker force. Hence two layers:

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

**⚠️ Constraint on the sequenced check-(4) change — and it is NOT what an earlier draft said.** An earlier draft of this design asserted the confinement clause must be *preserved untouched* as *"the sole adversarial guard"*. **That is retracted — it was false.** Measured (research doc F3): the confinement clause is **adversarially null too** (two plain forward commits defeat it), it is **not separable** from the counter (its *"introducing commit"* anchor is well-defined only while the counter holds), and **deleting the counter deletes the gate's principal *accident* tripwire** (silent re-attestation). **The check-(4) fix is therefore UNSETTLED.** This change must not encode a constraint on it: the only thing it may assume is that **some** attestation gate exists at archive. See `research/03-analysis/cross-review-gate-defect-forensics.md` F3 — which deliberately prescribes no fix and routes the design to an explore.

### D4 — Four arms; only `exit 10` carries blocker force, and **no arm suppresses the check**

The first draft made `exit 0` mean *"out of scope ⇒ SHALL NOT flag"*. That is **fail-open**: it would have **mandated silence on a missing gate task** whenever the classifier said "out" — a regression against today's v4 REVIEW, and a direct contradiction of D5's fail-closed principle. *(That draft justified itself with "the normal post-propose state **is** `exit 0`". Round 4 refuted the premise — after any intervening archive the steady state is `exit 10` (D1's latch) — but the **conclusion survives on stronger ground**: `exit 0` must not suppress the check, because per D1 the classifier's answer is **never about this change** and so can never license silence about it.)* Corrected:

| classifier | Critic behavior |
| --- | --- |
| **exit 10** (in scope — see the honest reading below) | gate task absent, **duplicated**, **misordered**, or lacking human-only wording ⇒ **BLOCKER** |
| **exit 0** (*not yet knowable to be in scope*) | **semantic** judgment, at most **REVIEW**, **never suppressed** — and state that the classifier returned "out" |
| **exit 2**, `proposal.md` **absent from HEAD** (genuinely uncommitted) | **semantic** judgment, at most **REVIEW** |
| **exit 2**, `proposal.md` **committed** (a malformed range: dir touched before `proposal.md`, root commit, missing dir) | **BLOCKED-PREREQUISITE**. *Measured:* on such a range **both** committed tools refuse (`cross-review-scope.sh` **and** `cross-review-digest.sh`, exit 2, `range-omission`), so step-0's check (2) **cannot be satisfied**. Honest limit: no committed rule yet *requires* step-0 to run on a refusal (its SHALL is conditioned on *"in scope"*, and a refusal is neither in nor out) — the same shape as R5, and it reduces to the accepted model-only-loop residual. Blocking at review is therefore the right call regardless, but the design does **not** claim archive is mechanically forced to refuse. |

**⚠️ What `exit 10` actually asserts — and the false-positive claim an earlier draft made here.** That draft claimed *"zero false-positive cost on the `exit 0` arm: a genuinely docs-only change is `exit 0`."* **That is false, and R3 below already refuted it** — the two decisions contradicted each other in the same document. Per **D1**, `exit 10` asserts only that *some* path in the repo-wide range is out-of-allowlist; it may be **entirely foreign**, and after any intervening archive it **latches on permanently**. Measured today: **all three** open changes read `exit 10`, and for **two of them** (`fix-cross-review-gate-task-emission`, `add-git-diff-wrap-toggle`) **every** driving path is foreign — their own paths are 100% allowlisted.

So the BLOCKER's false-positive rate is **a function of repo activity, not of the change.** The arm is still **safe in direction** (pollution over-includes; it can never *under*-trigger a bypass, so no bypass is opened). But it is **not** a precise instrument, and the design must not claim it is. **Whether an arm this coarse should carry BLOCKER force at all is the open question escalated below** — it is the human's call, not the model's, and it is entangled with the range-pollution fix already routed to the base-resolution change.

### D5 — Fail-closed at propose, mirroring the classifier's own rule

The classifier already treats an **ambiguous path as in scope (fail-closed)**. The authoring rule adopts the same posture: **when the in-scope call is uncertain, emit the task.** Under-emission is the defect being fixed; over-emission is the safe direction.

**⚠️ But "over-emission costs one strikeable task" — the earlier justification here — is RETRACTED. There is no strike.** Both soundness passes found this independently, and it is confirmed on disk:

1. **No striking procedure exists anywhere.** Grepping AGENTS.md, both established specs, and this change's own artifacts, every hit for *strike / remove the task / delete the task* is **the assertion itself** — no actor, no authority, no recorded form. The model is forbidden to **tick** the task; nothing sanctions the model **deleting** it either, and no rule distinguishes *"strike an over-emitted task"* from *"delete an inconvenient gate task"* — which is precisely the act the gate exists to prevent.
2. **D4's own BLOCKER closes the hatch.** Under D1's latch, an open change reads `exit 10` after any intervening archive. D4 then **mandates a BLOCKER** if the tail lacks the gate task. So striking an over-emitted task on such a change **immediately produces a BLOCKER** — the task is un-strikeable in exactly the case that justified emitting it.

The two halves of this change are therefore in tension: **emission is justified as cheap *because* reversible; enforcement makes it irreversible.** Resolving that means either defining the strike as a first-class human-only act (an explicit *"cross-review-not-applicable"* line the critic honors) or dropping the cheapness claim and accepting that the gate task is **effectively mandatory for any change open across an archive**. **Not decided here — escalated (see Open Questions).** What this design may honestly claim is only the direction: fail-closed errs toward *an extra obligation*, never toward *a missed review*.

### D6 — Enforce cardinality and ordering, not just presence

The shipped spec requires **exactly one** attestation task, **placed after the coherence-review task and before the archive task**. Presence-only enforcement misses both other failure modes: a **duplicate** stops the checkbox loop twice, and a task placed **after** archive means step-0 fails before the human is ever prompted — the same expensive late failure. So the `exit 10` BLOCKER covers absent **or** duplicated **or** misordered **or** missing-human-only-wording.

### D7 — ⚠️ UNSETTLED: the migration/exclusion split is escalated, not decided

**An earlier draft decided this: migrate `add-git-diff-wrap-toggle`, deliberately exclude `add-ci-pipeline` because its obligation would be "unsatisfiable", and accept a standing unclearable BLOCKER. Round 4 refuted the premise and surfaced a cleaner alternative. The decision is withdrawn and escalated.**

**What was claimed, and what measurement says (2026-07-13):**

| Earlier claim | Status |
| --- | --- |
| `add-ci-pipeline` has **no** `⟶ xtty-openspec-critic` task to anchor against | **TRUE** (verified) — but the fix is trivial: *add one* while repairing its already-nonstandard tail. Not a reason for exclusion. |
| Its remaining owner-step commits restage the HEAD-dependent digest, so any attestation is **unrecoverable** ⇒ the obligation is **unsatisfiable** | **REFUTED (Pass B).** Its remaining work (5.4 test-PR, 5.5 a GitHub *repo setting* — not even a commit) sits **before** the tail. Owner-steps → commit → *then* attest → *then* archive is an ordinary, available ordering with **zero** intervening commits. "Unsatisfiable" is not established; only **more expensive**. |
| Its digest range is **~317 files, 98.4% foreign** | **Directionally right, numerically stale** — disk today: **324 paths, 319 foreign (98.5%)**. But this is a **cost**, not an impossibility — and the design **migrates** `add-git-diff-wrap-toggle` at **42 paths / 35 foreign (83%)**. The line between "migrate at 83% foreign" and "impossible at 98.5%" is **arbitrary and unstated.** |

**And a cleaner alternative the design never considered (Pass C) — grandfathering.** The two "violating" changes **predate the obligation**:

```
add-cross-model-design-review  ARCHIVED 2026-07-12 (8950884)  ← the gate ships here
add-ci-pipeline               proposed 2026-06-30 (c6ae3ea)   ← 12 days BEFORE
add-git-diff-wrap-toggle      proposed 2026-07-11 (0c454cd)   ←  1 day BEFORE
brief-cross-review-pass-b     proposed 2026-07-12 (155feb7)   ← the only POST-gate change
```

Neither could have emitted a task for an obligation that did not yet exist. Grandfathering pre-gate changes is a **mechanical, dateable rule** (compare a change's proposal commit against the gate's ship commit `8950884`) and it would dissolve **both** the migration **and** the unclearable BLOCKER at once.

**Escalated to the human — three coherent options, none chosen here:** (a) migrate **both** (the unsatisfiability objection is refuted; `add-ci-pipeline` needs a critic task added first); (b) **grandfather** all pre-gate changes and migrate neither; (c) keep the split and accept the standing BLOCKER. This design **no longer asserts (c)**. Whichever is chosen, one fact stands: the archive gate **already** applies to both open changes (`exit 10`) with or without this change.

### D8 — Test precision vs. the claim

- **Emission** lives in `config.yaml` prose consumed by a **model**. No mechanical assertion can prove a model follows prose, so it is verified **by effect**: run `/opsx:propose` on a scratch in-scope change and observe the emitted tail. *(A grep asserting the rule string exists in `config.yaml` is a read-back check, not evidence, and is explicitly not the test.)* The natural experiment already on disk supports the mechanism: `add-git-diff-wrap-toggle`'s propose-generated `tasks.md` carries **every applicable** config-backed marker — three of the four (`⟶ xtty-test-validator`, `⟶ xtty-openspec-critic`, `⟶ archive-ritual`; `⟶ xtty-ci-investigator` is correctly absent, its rule being conditional on a failed-CI task) — and **zero** attestation task: the one obligation with no config rule.
- **Enforcement** lives in the critic's classifier-driven branch. Verified **by effect** across all four arms of D4 (exit 10 ⇒ BLOCKER incl. duplicate/misordered; exit 0 ⇒ REVIEW not silence; exit 2 uncommitted ⇒ REVIEW; exit 2 committed-malformed ⇒ BLOCKED-PREREQUISITE).

No `verification-harness` delta: dev-workflow tooling, no observable app behavior.

## Risks / Trade-offs

- **R1 — The fix cannot be emitted by the rule it introduces.** This change was proposed before the rule existed, so its own attestation task was added **by hand**. The *next* in-scope change is the first real test of emission. *(An earlier draft called this "the bug reproducing on itself." That framing is retired — see the Why-section correction in `proposal.md`: the demonstration no longer holds, because the classifier now reads `exit 10` on this change for entirely foreign reasons.)*
- **R2 — A semantic propose-time call will sometimes be wrong.** → D5's fail-closed posture makes the error direction **over-emission**, and D4's BLOCKER is the backstop. ⚠️ But per D5, over-emission is **not** cheaply reversible (there is no defined strike, and D4's BLOCKER re-raises the task the moment it is removed).
- **R3 — ⚠️ Range pollution is not an edge case; it is the STEADY STATE, and it is *structural*.** `openspec archive` **always** writes `openspec/specs/**`, which is **not** in the allowlist — so **any change left open across any other change's archive latches to `exit 10` permanently and can never return.** Measured today: **all three** open changes read `exit 10`, and for **two** of them every driving path is **foreign**:

  | change | range (HEAD-dependent) | own paths | foreign | own paths out-of-allowlist? |
  | --- | --- | --- | --- | --- |
  | `fix-cross-review-gate-task-emission` | 21 | 7 | 14 (67%) | **none** — verdict is 100% foreign-driven |
  | `add-git-diff-wrap-toggle` | 42 | 7 | 35 (83%) | **none** — verdict is 100% foreign-driven |
  | `add-ci-pipeline` | 324 | 5 | 319 (98.5%) | yes (`.github/workflows/**`) |

  → **Accepted for the BLOCKER's *direction*** (pollution over-includes; it can never *under*-trigger a bypass, so **no bypass is opened**) — but **not** for its *precision*: the BLOCKER's false-positive rate is a function of **repo activity**, not of the change. Whether an arm this coarse should carry BLOCKER force is **escalated** (D4, Open Questions).
- **R4 — ⚠️ The real cost of R3: a BLOCKER + pollution + one-shot attestation is an *unrecoverable* combination.** The digest covers HEAD content of **every** file in `B..HEAD` (**42** paths for `add-git-diff-wrap-toggle`; **324** for `add-ci-pipeline` — both HEAD-dependent and **growing**), so it is a function of repo HEAD — **any** commit anywhere restages it. Once stale, re-attestation requires editing the attestation line, which flips check (4) to `adds=2, dels=1` — **permanently failing**, with no forward-history recovery. This change promotes that hazard from *once-per-dogfood* to *once-per-change*. → **ESCALATED, not mitigated here — see Open Questions.**
- **R5 — ⚠️ Pre-existing gate bypass, verified, NOT fixed here: the scope call is blind to *uncommitted* implementation.** Clean-room measured: with real product code present but uncommitted, the classifier reads `exit 0` ⇒ AGENTS.md step-0 applies the precondition only *"for a change in scope"* ⇒ **the entire four-check precondition is skipped and `openspec archive` proceeds.** The counterintuitive crux: `cross-review-digest.sh`'s dirty-tree refusal does **not** backstop this, because that refusal is *check (3)*, which lives **inside** the precondition that was skipped. → **Named, deliberately not fixed here:** fixing it means editing `cross-review-scope.sh`, which drags in the reviewed-base self-validation rule that task 6.3 currently (correctly) asserts does not apply. Route to the base-resolution change: give the classifier the same dirty-tree refusal the digest tool already has.
- **R6 — A stale-served agent definition would silently keep v4 behavior.** → Bump the stamp to **v5**; a run reporting v4 is invalid, not a pass.
- **R7 — Trade-off: the gate now fires more often.** Accepted: the mechanical classifier is the authority, over-inclusion costs a review, and the alternative is the status quo being fixed.

## Migration Plan

Additive. The `config.yaml` rule affects only future propose runs; the critic upgrade only future reviews. **Which existing change (if any) gains the task is ⛔ blocked on Q3** — see D7; the earlier plan (migrate `add-git-diff-wrap-toggle` only) is withdrawn. Whatever Q3 chooses, any hand-added gate task MUST land in a **separate commit** from any later attestation (D3). Rollback = revert; the gate returns to emitting nothing at propose. No attested state is involved.

**⚠️ This design assumes it lands as-is — and Q1/Q2 may invalidate that.** The spec delta enshrines the classifier's **non-attributive / latching** behavior as normative text. That description is **factually verified** and correct **today**. But if the human answers **Q1 = "land the base-resolution change first"** or **Q2 = "narrow the classifier before granting BLOCKER force"**, then `cross-review-scope.sh` changes and **this very delta gets re-modified** by that change — its `openspec/specs/` text would then describe a classifier that no longer behaves that way. The polished spec is therefore **a proposal contingent on Q1/Q2**, not settled text. Sequence accordingly.

## Open Questions

**Round 4 escalated three decisions to the human. The model has settled none of them.**

- **⚠️ Q1 — SEQUENCING. Escalated; now backed by measurement, not just argument.** Both soundness passes have argued across four rounds that this change should land **after** the range-pollution fix and the check-(4) fix; Codex (`gpt-5.6-sol`) has returned an explicit **no-ship** four times running. The reason: it makes the gate fire *reliably* into an attestation model with an **unrecoverable** failure mode (R4) and a **verified bypass** (R5). *(Codex's proposed remedy — "append-only, superseding attestation generations" — remains the **refuted "recoverable attestation epoch"** (G-TARPIT-1/2). Its **sequencing** argument stands; its **remedy** does not.)* **What is new in round 4:** the pollution hazard is no longer hypothetical — it has **already bitten this very change** (R3/D1: `exit 10`, driven 100% by foreign paths, with zero implementation landed) and it is **structural** (any change open across any archive latches on, permanently). The counter-argument for landing this first is unchanged: the deadlock is only *reachable* once a change acquires an attestation, and today nothing prompts one. Both remain coherent. **The human decides the order.**
- **⚠️ Q2 — Should the `exit 10` arm carry BLOCKER force at all, given what `exit 10` actually asserts?** (New in round 4 — D4/R3.) The verdict is **non-attributive** and **latches**: for two of the three open changes it is driven **entirely by foreign paths**. The BLOCKER is still **safe in direction** (it can never open a bypass), but it will be **red by default on nearly every open change** — and since nothing executable consumes a critic BLOCKER (G-GATE-1), its entire force **is** the reader's attention. A check that is red by default spends exactly that. Options: ship the BLOCKER anyway (loud, honest, noisy); **narrow the classifier to the change's own paths first** (a `cross-review-scope.sh` edit — already routed to the base-resolution change, and it would dissolve most of this); or scope the BLOCKER to changes whose **own** paths are out-of-allowlist. **Not chosen here.**
- **⚠️ Q3 — Migrate, grandfather, or exclude?** (New in round 4 — D7.) The "unsatisfiable" premise that justified excluding `add-ci-pipeline` is **refuted**, and both "violating" changes **predate the obligation** (by 12 days and 1 day). Grandfathering pre-gate changes is a mechanical, dateable rule that dissolves both the migration and the standing BLOCKER. **Not chosen here.**
- **Q4 — Should `cross-review-scope.sh` gain a dirty-tree refusal (R5)?** **Yes — but in the base-resolution change**, not here. *(Note that Q2 may fold into the same change: both are `cross-review-scope.sh` edits.)*
