## Context

Cross-review's Pass C currently pins "inline Opus" — reusing Pass A's exact checkpoint for the review's second Claude-family pass. Recent research (`research/03-analysis/cross-model-seat-assignment-research.md`) found this worth a bounded experiment: swap Pass C to Fable 5, a different Claude-family checkpoint, so the review's two Claude-family passes aren't literally the same model reviewing the same range twice. The spec already permits this — Pass C only has to share Pass A's model *family*, not its checkpoint, and the concrete pin is deliberately kept out of the requirement text and left to the design/command layer. This design covers the mechanics of the swap and, more importantly, how to state and evaluate it honestly.

## Goals / Non-Goals

**Goals:**
- Swap Pass C's pinned model from Opus to Fable 5 in `.claude/commands/xtty/cross-review.md`.
- Prevent the swap from being misread as adding a third independent review family — only Pass B is cross-vendor.
- Establish a concrete, human-owned evaluation procedure so the experiment can actually be judged over time.

**Non-Goals:**
- Not touching Pass A, Pass B, the scope classifier, the digest tool, or the archive gate.
- Not building any new standing agent or automation to compute "disjointness" — that judgment stays human and manual.
- Not committing to keeping the Fable pin permanently; this is explicitly reversible pending evaluation.

## Decisions

1. **Pin Fable 5, not another Opus invocation or a rotating pin.** Rejected keeping Opus (status quo — no diversity gain) and rejected rotating between several Claude checkpoints per run (adds complexity with no clear evaluation win over a single fixed swap). Fable 5 is chosen because this repo has direct, recent, positive experience with it for exactly this kind of adversarial design critique: the seat-assignment research investigation used a 6-agent Fable-5 fan-out to research the topic, and a separate, independent Fable-5 critique pass over that investigation's own reasoning found concrete, verified defects (the pilot's promotion bar, its measured variable, and the evaluation-methodology corrections captured in `cross-model-seat-assignment-research.md`) — grounded, specific findings against real repo state, not generic commentary.

2. **ADDED requirement, not MODIFIED.** The existing "Authority-free cross-model review worker" requirement already accommodates a checkpoint swap without any edit — it explicitly keeps the concrete model pin out of the requirement text, and its "record the effective model of each soundness pass" language already covers whichever checkpoint runs, unchanged. Editing that requirement would mean pasting and re-threading a long, multi-scenario block for zero behavioral change to it. The two genuinely new expectations this change adds — documentation clarity about family-vs-checkpoint, and a human-only evaluation rule — are additive, so a new, narrowly-scoped requirement is cleaner and lower-risk than a large MODIFIED paste.

3. **Human-only evaluation, made explicitly normative.** This repo has a settled refutation: a model-authored artifact can never gate archive — the human is the gate. A mechanism where a model scores its own review pass's comparative value would repeat that mistake at smaller scale. Stating the evaluation rule as an explicit SHALL (rather than leaving it an unstated assumption) closes that off before anyone is tempted to build a "disjointness score" feature.

4. **No new tooling for the evaluation, for now.** Considered building a script that diffs Pass A's and Pass C's findings and reports overlap automatically. Rejected: building measurement tooling before a single run has happened is the same premature-machinery pattern the seat-assignment research already flagged and deferred for a different candidate (the author-family ledger field). If the pin proves valuable across several runs and a human keeps wanting the same comparison done by hand, that's the point to reconsider a tool — not before.

## Risks / Trade-offs

- [Risk] The swap adds nothing over Opus — Fable and Opus might simply agree on everything, or Fable might under-perform Opus at this specific adversarial-review task. → [Mitigation] The evaluation is explicitly scoped to "watch several runs," not "assume it works"; reverting is a one-line change back to Opus, and nothing else in the system depends on Pass C's specific checkpoint.
- [Risk] `.claude/commands/xtty/research.md` already records "Fable 5 is intentionally unused — not an analytical-reasoning tier" for its own tiering, which could read as inconsistent with pinning Fable here. → [Mitigation] That prior decision governs the research fan-out's tiering specifically (a different use case: ranked analytical tiers vs. review-diversity value); this change's ADDED requirement states that scoping directly, so a future reader sees the distinction instead of an apparent contradiction.
- [Risk] This change touches `.claude/commands/xtty/cross-review.md`, a path outside the docs/tracker allowlist, putting it in scope for cross-model review before archive. → [Mitigation] Expected and accounted for in `tasks.md` (the standard human-attestation cross-review task); the change is small enough that this is a light lift, not a blocker.

## Migration Plan

No runtime migration — this is a documentation/prompt change to one command file plus a spec delta merged at archive. Steps: edit `cross-review.md`'s Pass C description to pin Fable 5 and add the clarifying/evaluation language; at archive, the spec delta merges into `openspec/specs/cross-model-review/spec.md`. Rollback is symmetric: revert the pin to Opus in the command file; the ADDED requirement can remain (it is honestly still true of "whichever checkpoint runs"), or be removed via a follow-up REMOVED delta if the experiment is abandoned outright.

## Open Questions

- How many cross-review runs constitute "enough" to judge the pin, given `/xtty:cross-review` never auto-fires and is human-launched only? Left to the human's judgment at each future in-scope change rather than pre-specifying a threshold with no data behind it yet.
- Should the human's ledger-disjointness judgment be recorded anywhere (a running log), or is an ephemeral per-run judgment sufficient? Left open — a natural follow-up for a later `xtty:capture-research` pass if the pin sticks around.
