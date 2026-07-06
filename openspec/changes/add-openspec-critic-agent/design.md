## Context

xtty is a doc-heavy, spec-driven project (79% of commits are `docs(openspec)`; every change carries proposal/design/specs/tasks artifacts that must stay mutually coherent per AGENTS.md's "Keeping a change coherent" + spec-delta-format rules). Coherence is checked today by hand or self-review, inconsistently — and it drifts: AGENTS.md's own "7 of 10 archived changes carry a harness delta" is stale against the disk truth (19/34). The dev-workflow forensics ([`dev-workflow-agent-orchestration.md`](../../../research/03-analysis/dev-workflow-agent-orchestration.md)) ranked this the single friction that recurs every change, is entirely unautomated, and is provably under-done — the reactive-friction signal the project's own rule ("build agents reactively, not a speculative roster") requires before committing an agent. The two existing agents (`xtty-ci-investigator`, `xtty-test-validator`) are the template; this is the third, and the first with a cross-artifact (change-set) pass.

## Goals / Non-Goals

**Goals:**
- Automate the coherence check as a **read-only, fixed-verdict agent** that isolates the rule-checking from the invoking session.
- **Defer to AGENTS.md for the rules** (single source of truth), never hardcode them; encode only the operationalization.
- Add the project-specific **cross-change** pass (shared requirements, archive-ordering, red→green pairs) that no single-change review sees.
- **Catch tracker/disk drift** (the `7/10`→`19/34` class) as a first-class finding.

**Non-Goals:**
- Replacing `openspec validate` (the cheap mechanical gate stays inline — the critic is the *deeper* review).
- Editing artifacts to fix findings (observe-never-repair).
- A persistent in-flight-change ledger (refuted by the forensics — cross-change state is computed on demand).
- Building any other agent from the deferred roster (source-researcher, cold-author) — this is the one reactive-justified build.

## Decisions

### D1: Clone the `xtty-ci-investigator` shape, not the validator

The critic is **short and read-only** (`openspec`/`git`/`grep`/`find`, no VM, no build, no long wait). So it clones the *investigator* template — `Definition: <version>` stamp, deference chain, fixed-skeleton report, observe-never-repair — and **omits** the validator's heavy apparatus (turn-alive invariant, foreground-wait loops, ledger, babysitter/resume). Matching apparatus weight to strand-risk is an explicit project lesson; the critic has no strand risk.

### D2: Defer to AGENTS.md's coherence rulebook; operationalize in the agent, flag the un-checkable

The *rules* live in AGENTS.md's "Keeping a change coherent" + spec-delta-format sections (single source of truth), read **fresh each run** — unlike the sibling agents' separate matrices (`packer/README.md`, `github-actions-ci-cd.md` §19), the coherence rulebook already has a durable home. The agent encodes only the **operationalization** (the concrete grep/diff/derive for each rule — the 28-check list captured in the dev-workflow investigation is its starting operationalization). A rule present in AGENTS.md that the agent cannot mechanically check is **flagged for human review**, never silently dropped — so the authoritative list can grow ahead of the operationalization without a silent gap.

### D3: Three passes, with cross-change computed on demand

- **Single-change coherence** — the operationalized rules (`## ADDED/MODIFIED` headers; `### Requirement:` with SHALL/MUST; ≥1 four-hashtag scenario each; proposal↔specs capability contract both directions; MODIFIED pastes the *entire* established block; verify tasks running the Tier-1/VM suite carry `⟶ xtty-test-validator`, CI-investigation tasks carry `⟶ xtty-ci-investigator`; new observable behavior carries a `verification-harness` delta; requirements mechanism-neutral).
- **Disk-drift** — established specs match `ls openspec/specs/`; active changes match the AGENTS.md open-changes table; any prose count/fraction re-derived against disk; promised reverse-duty tracker edits actually present.
- **Cross-change** — shared established-requirement collisions, declared archive/apply ordering (incl. red→green pairs), inter-change dependency references — **derived at run time** from `openspec list` + the change dirs, never cached.

### D4: BLOCKER vs REVIEW severity — heuristics inform without false-failing

Some rules are hard and mechanical (a three-hashtag scenario; a truncated MODIFIED block) → **BLOCKER**. Some are heuristic (suspected mechanism-specific detail in a requirement; a design decision with no matching requirement) → **REVIEW**. Only a BLOCKER blocks the `COHERENT` verdict; REVIEW findings inform the human. This keeps the critic from crying wolf on judgment calls while still surfacing them.

### D5: Model = Opus, tuned by measurement

Coherence has genuine judgment (mechanism-neutrality, design↔requirement traceability, cross-change reasoning) beyond table-lookup, so it **ships on Opus** — the inverse of the ci-investigator's "Sonnet, tune to Haiku if purely mechanical." If measured runs show the checks are overwhelmingly mechanical/greppable, tune down to Sonnet later (settle by measurement, not opinion).

### D6: The validate-vs-review boundary + per-task marker

`openspec validate` (cheap, mechanical) stays **inline**; a **full coherence review** (rules + drift + cross-change) is **delegated**, carried by `⟶ xtty-openspec-critic (<change|all>)`. Same point-of-tick reasoning as the two sibling markers: the apply/propose loop reads the marker, not the AGENTS.md rule. The natural trigger points are **post-propose** (is the new change coherent?) and **pre-archive** (still coherent after implementation?), documented as recommendations rather than hardcoded into the openspec skills (which are not xtty's to edit).

## Risks / Trade-offs

- **Operationalization drifts behind the AGENTS.md rulebook** → *Mitigation:* D2 — AGENTS.md is read fresh as authoritative; an un-checkable rule is flagged, so the gap is visible, not silent. A reverse-duty note: a new coherence rule should prompt a critic operationalization update.
- **Heuristic over-flagging erodes trust** → *Mitigation:* D4's BLOCKER/REVIEW split; heuristics never block the verdict.
- **Cross-change false positives** (a "collision" that's intentional, like the red→green pair) → *Mitigation:* reported as findings for the human, never a hard fail; the report *names* the declared ordering rather than judging it wrong.
- **Opus cost per review** → *Accepted:* reviews are per-change and infrequent (bursty cadence), and this is a quality gate; D5 leaves a measured path to Sonnet.

## Open Questions

- **Exact loop integration points.** The boundary says "delegate a full review"; the natural triggers are post-propose and pre-archive, but the generic `/opsx:*` skills aren't xtty's to edit. Resolve during apply by documenting the recommendation in AGENTS.md (and optionally a future `/xtty:propose` launcher that chains author→review), not by forcing it into openspec tooling now.
