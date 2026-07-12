## Context

`add-cross-model-design-review` (archived 2026-07-12) shipped a **human-attestation archive gate**. Its eligibility mechanism is a **blocking human-only task** in an in-scope change's `tasks.md` tail, which the human ticks while recording a reviewed-state digest on a delimited attestation line. AGENTS.md and `openspec/specs/cross-model-review/spec.md` both state that an in-scope change's tail **SHALL** carry exactly one such task.

**Measured reality on disk:**

| Fact | Evidence |
| --- | --- |
| `/opsx:propose` never emits the task | `grep -c -Ei 'cross-review\|attestation' openspec/config.yaml` = **0**, while all four existing point-of-tick markers *do* have `rules.tasks` entries (config.yaml L45–81). The propose loop reads `config.yaml`, not `AGENTS.md`. |
| Nothing blocks on its absence | `xtty-openspec-critic` v4 (L42): gate-task presence is `heuristic → REVIEW`, *"never a BLOCKER — the in-scope judgment is semantic"*; L80: *"REVIEW findings never block."* |
| Both open changes violate the shipped spec | `add-ci-pipeline` and `add-git-diff-wrap-toggle` → `cross-review-scope.sh` **exit 10 (in scope)**; `grep -ci 'cross-review\|HUMAN-ONLY\|attestation'` on each `tasks.md` → **0**. |
| The gate has fired once, by hand | The archived change's task 5.2 was hand-authored during its own dogfood. |

The gate still **fail-closes at archive** (step-0 check (1) finds no attestation line), so nothing unreviewed can slip through *silently*. The defect is that the human is never **prompted**: they learn of the requirement only when archive refuses, after the work is done. This is a *tool-doesn't-work-when-used* defect — **G-TARPIT-4**'s highest-value class, and found by *using* the gate rather than reviewing its spec.

## Goals / Non-Goals

**Goals:**
- The blocking human-attestation task is **emitted at propose time** for an in-scope change, from the surface the propose loop actually reads.
- A missing gate task is **mechanically blocking** at pre-archive review, where a mechanical scope call is available.
- The two open in-scope changes are brought into conformance.
- **Zero new machinery**: no new script, agent, or marker grammar.

**Non-Goals:**
- **No auto-firing marker.** Not introducing `⟶ xtty-cross-review` (see D2).
- **Not fixing the re-attestation deadlock** (check (4)) — a separate, sequenced change; this one only makes the gate *reach* a change.
- **Not fixing range pollution** — a separate change (see Risks R3).
- Not touching the four archive-gate checks, `cross-review-digest.sh`, or `cross-review-scope.sh`. No product code, no harness surface.

## Decisions

### D1 — Two layers, because the mechanical classifier cannot run at propose time

This is the load-bearing constraint, and it is **measured, not assumed**:

```
$ scripts/cross-review-scope.sh fix-cross-review-gate-task-emission
cross-review-scope: cannot find the commit that added .../proposal.md   → exit 2
$ scripts/cross-review-scope.sh add-git-diff-wrap-toggle                → exit 10
```

The classifier resolves its base from **git history** (`git log --diff-filter=A -- <dir>/proposal.md`). A change being proposed *right now* is **uncommitted**, so the classifier **refuses**. Scope at propose time is therefore irreducibly **semantic**, and a semantic call cannot carry blocker force — which is exactly why the current check is REVIEW-only. **The existing design is right about that; only its consequences were left unbuilt.** So the fix splits by what is *knowable when*:

| Layer | When | Scope call | Force |
| --- | --- | --- | --- |
| **Emission** — `config.yaml` `rules.tasks` | propose | **semantic**, fail-closed (when in doubt, emit) | authoring instruction |
| **Enforcement** — critic gate-task check | pre-archive (committed) | **mechanical** (`cross-review-scope.sh`) | **BLOCKER** |

*Alternative rejected — raise the critic's severity to BLOCKER without the classifier:* it would make a **semantic** judgment blocking, false-failing legitimate docs-only changes. The classifier is what earns the blocker.

### D2 — An authoring rule, NOT a delegation marker

AGENTS.md explicitly refutes an auto-firing `⟶ xtty-cross-review` marker: *"a paid review that must not fire on task-arrival is neither delegate-to-subagent nor run-inline — the only two things the point-of-tick grammar can express."* Reintroducing one would either (a) fire a **paid** external review on task arrival, or (b) hand a **human-only** act to a subagent — both prohibited.

So the `config.yaml` rule targets the **author**, not the apply loop: *"when authoring an in-scope change's tail, write this task."* The **task's own text** carries the HUMAN-ONLY / model-MUST-STOP instruction that the apply loop reads at the point of tick. Emission and firing stay separate, and the model-STOP boundary is untouched.

*Why `config.yaml` and not AGENTS.md:* AGENTS.md **already** says this and it demonstrably did not reach the loop. That is the repo's own G13 refutation. `config.yaml` `rules.tasks` is the *only* surface `/opsx:propose` reads, and it is where the four working markers live. Mirror them, and **defer to AGENTS.md for the boundary** rather than restating it (as all four do).

### D3 — Fail-closed at propose, mirroring the classifier's own rule

The classifier already treats an **unrecognized/ambiguous path as in scope (fail-closed)**. The propose-time authoring rule adopts the same posture: **when the in-scope call is uncertain, emit the task.** Over-emission costs one unnecessary task the human can strike; under-emission is precisely the defect being fixed. This keeps the two scope determinations *directionally consistent* even though one is semantic and the other mechanical.

### D4 — The critic's degraded path is honest, not a silent pass

Three classifier outcomes, three behaviors — and the **exit-2 arm must not silently pass**:

| `cross-review-scope.sh` | Critic behavior |
| --- | --- |
| **exit 10** (in scope) + task absent / missing human-only wording | **BLOCKER** |
| **exit 0** (out of scope) | not flagged |
| **exit 2** (cannot resolve — uncommitted change) | fall back to **semantic REVIEW** (today's check), and **say the classifier could not resolve** |

The exit-2 arm is the propose-time case, so a newly-proposed change still gets the REVIEW nudge it gets today — never an unexplained silence.

### D5 — Migration is a task-tail append, and it is safe

`add-ci-pipeline` (10/15) and `add-git-diff-wrap-toggle` (0/20) each gain the missing task. Neither has attested, so no digest is invalidated: the reviewed-state digest is computed **fresh at attestation time**, and `cross-review-digest.sh` **normalizes checkbox state and excludes the attestation line** — so editing an unattested `tasks.md` has no gate consequence. (The digest *does* cover task **text**, so this edit will be part of whatever state each change eventually attests — which is correct: the task is part of what gets reviewed.)

### D6 — Test precision vs. the claim

The claim is *"an in-scope change's tail carries the blocking human-attestation task, emitted at propose and enforced at pre-archive."* It lives in two places, and each is verified where it lives:

- **Emission** lives in `config.yaml` prose consumed by a **model**, not in code. There is no mechanical assertion that can prove a model will follow prose — so it is verified **by effect**: run `/opsx:propose` on a scratch in-scope change and observe the emitted tail. A grep asserting the rule *string* exists in `config.yaml` would be a **read-back check**, not evidence, and is explicitly *not* the verification.
- **Enforcement** lives in the critic's classifier-driven branch. Verified **by effect**: run the critic against a change that is mechanically in scope with the task removed (a scratch copy) → expect **BLOCKER**; against one with the task → expect no gate finding; against an uncommitted change → expect the **REVIEW** fallback.

No `verification-harness` delta: this is dev-workflow tooling with no observable app behavior.

## Risks / Trade-offs

- **R1 — The fix cannot be emitted by the rule it introduces.** This change is mechanically in scope, but was proposed *before* the rule existed, so `/opsx:propose` did not emit its own attestation task. → **Mitigation:** add it **by hand**, and say so. This is the bug reproducing on itself, and it is the honest dogfood: the *next* in-scope change is the first real test of emission.
- **R2 — A semantic propose-time call will sometimes be wrong.** → **Mitigation:** D3's fail-closed posture makes the error direction **over-emission** (harmless — the human strikes an unneeded task), and D1's mechanical pre-archive BLOCKER is the backstop that catches an under-emission before archive.
- **R3 — Range pollution can make the classifier say "in scope" for the wrong reason.** Measured: `add-git-diff-wrap-toggle` classifies in-scope on **8 paths that are all foreign** (its own 7 are 100% allowlisted). → **Accepted, not fixed here.** Pollution is **fail-closed** — it over-includes, so a classifier-driven BLOCKER can only *over*-trigger (cost: one unnecessary review), never *under*-trigger (a bypass). Fixing the base resolution is a separate change; it does **not** block this one.
- **R4 — A stale-served agent definition would silently keep the old REVIEW-only behavior.** Agent-definition edits reach spawns with unpredictable lag (a known refutation). → **Mitigation:** bump the critic's stamp to **v5** and rely on the existing `Definition:` delivery check; a run reporting v4 is invalid, not a pass.
- **R5 — Migrating the two open changes edits `tasks.md` files mid-flight.** → **Mitigation:** per D5, neither has attested, and the digest normalizes ticks and excludes the attestation line, so there is no gate consequence. `add-ci-pipeline` is 10/15 done; appending a tail task does not disturb completed work.
- **R6 — Trade-off: this makes the gate *fire more often*, including on changes a human may feel don't need it.** Accepted deliberately: the mechanical classifier is the authority (AGENTS.md), the cost of over-inclusion is one review, and the alternative — a gate nobody is prompted to satisfy — is the status quo being fixed.

## Migration Plan

Additive; no rollback complexity. The `config.yaml` rule affects only *future* propose runs. The critic upgrade affects only *future* reviews. The two task-tail appends are ordinary artifact edits. Rollback = revert the change; the gate returns to its current (inert-at-propose) state, and no data or attested state is involved.

## Open Questions

- Should the critic's **exit-2 (unresolvable)** arm eventually become a BLOCKER once a change is committed but its `proposal.md` commit is not yet found (a genuinely broken range)? Today that is an honest REVIEW; making it blocking risks false-failing a mid-propose change. **Deferred** — revisit only if a real unresolvable-but-committed change appears.
- Should `add-ci-pipeline`, whose reviewed range is **98.4% foreign** (304/309 paths), be attested at all in its current shape, or be re-anchored first by the range-pollution change? **Deferred to that change** — flagged here so the sequencing is not lost.
