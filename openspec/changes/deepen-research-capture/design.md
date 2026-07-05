## Context

Three artifacts govern research capture, with an explicit deference chain established by the `research-capture` spec: **AGENTS.md holds the rules** → the **skill** is the runnable checklist that defers to AGENTS → the **command** is a thin launcher. Today all three describe packaging + reconciliation only. The depth expectation exists solely by example (`local-network-privacy-forensics.md`), which is exactly the kind of unwritten rule the tooling was created to eliminate.

## Goals / Non-Goals

**Goals:**
- Codify the capture-depth anatomy once, in AGENTS.md, and surface it in the skill/command without duplicating the rules (preserve the deference chain — the spec's own "cannot drift" scenario).
- Keep it **scaled**: depth requirements bind captures with *measured claims or retired theories*; lightweight notes stay lightweight.

**Non-Goals:**
- No retro-editing of existing research docs.
- No change to the research-*doing* method (workflows, adversarial verification — explicitly out of the spec's scope).
- No new tooling files.

## Decisions

**D1 — The anatomy, as six named elements (the AGENTS wording):** (1) **Mechanism** — how the system actually works, with evidence, not just the conclusion; (2) **Reproducible probes** — exact commands, what each proves *and cannot prove*, including dead instruments; (3) **Investigation record** — each retired theory as a ❌ *next to the experiment that killed it* (a fates table); (4) **Re-verify by effect** — how a future reader re-checks the headline claim (never a syntax/read-back check); (5) **Guideline** — when the finding generalizes, distill the method as a numbered reusable guideline; (6) **Artifacts** — where the evidence lives. *Alternative considered:* a rigid required template (rejected — over-prescribes small captures; the scale clause does the work).

**D2 — Rules land in AGENTS.md; the skill carries only the checklist form.** Mandated by the spec ("the skill SHALL defer to AGENTS.md … so the two cannot drift"). The skill's step 1 gets a compact "Depth bar" sub-list naming the six elements + the exemplar pointer; the command description gets one clause. *Alternative:* full anatomy in the skill (rejected — forks the rules, violates the existing requirement).

**D3 — Spec delta is a MODIFIED requirement, not a new one.** The depth bar is part of "the documented capture-and-reconcile workflow"; extending that requirement (full block copied + edited, one added scenario) keeps the capability's shape. Mechanism-neutral wording: the *conventions* must include the depth bar; the exact six-element list is the AGENTS/skill *how*.

## Risks / Trade-offs

- [Over-prescription] Small captures feel taxed → the scale-to-the-finding clause is part of the *requirement text itself*, not just guidance.
- [Drift between the three files] → unchanged mitigation: AGENTS is the single rule source; skill/command only point at it (spec scenario already enforces this).

## Migration Plan

Docs/tooling edit only; no rollout. Rollback = revert the commits.

## Open Questions

None.
