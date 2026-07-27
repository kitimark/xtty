## Context

`cross-model-review` is a two-layer capability, archived in six prior changes (`add-cross-model-design-review`, `brief-cross-review-pass-b`, `fix-cross-review-gate-task-emission` — abandoned, `pin-cross-review-pass-c-fable`, `emit-attestation-line`, plus every change that used it as its own archive gate):

- **The worker** — `/xtty:cross-review`, a main-loop protocol composing an Opus conformance pass with two soundness passes (Codex `gpt-5.6-sol`, inline Fable 5), merged into an advisory union ledger. Zero gate force.
- **The gate** — a mechanical scope classifier (`scripts/cross-review-scope.sh`), a reviewed-state digest tool (`scripts/cross-review-digest.sh`), and a fail-closed archive precondition requiring a human-only attestation line in `tasks.md`.

The gate was built specifically to refute an earlier, simpler shape (a model runs the review, writes a "converged" receipt, archive mechanically trusts it) — six rounds of that shape's own review showed a model can dismiss every finding and self-certify by doing its job correctly. "The human is the gate, not the model" became this project's hardest-won conclusion (`research/03-analysis/cross-model-design-review-axes.md`).

Used in practice, though, the gate surfaced real, recorded friction its own spec does not deny: a re-attestation deadlock (any post-attestation drift forces a history rewrite to fix, which the design calls adversarially exploitable), a reviewed-state digest fragile to any unrelated commit landing before archive (measured directly on `pin-cross-review-pass-c-fable`), an explicitly unsettled exempt-by-act question, and three incidents of hand-typing unverified hex values before `emit-attestation-line` shipped a print-only convenience. The spec itself states the four mechanical checks are "accident tripwires and human-legibility aids, NOT adversarial guarantees" — the owner has judged that ceremony isn't earning its cost for this project and wants the whole capability gone, not narrowed to advisory-only the way `remove-guide-gate` treated its own mechanism.

## Goals / Non-Goals

**Goals:**
- Remove the worker (`/xtty:cross-review` and its three-pass protocol) so it can no longer be invoked at all.
- Remove the mechanical archive gate (scope classifier, digest tool, their regression harness) and every rule that makes archive depend on them.
- Retire the `cross-model-review` capability spec cleanly, and strip the one coupled requirement it left behind in `coherence-review` (the critic's cross-review-gate-task-presence check).
- Leave `AGENTS.md`, the critic agent, and the research corpus internally consistent — no dangling references to a mechanism, task, or script that no longer exists.
- Record, rather than silently drop, the two things this removal costs: (a) the Learned-refutations knowledge this mechanism's construction and use produced, and (b) the code-accuracy coverage gap the critic's Pass 4 currently disclaims by pointing at cross-model-review.

**Non-Goals:**
- No replacement review mechanism, gate, or process is being designed. This is a subtraction, not a redesign.
- No expansion of the `xtty-openspec-critic` agent's scope to backfill the Pass-4 coverage gap the removal creates (the new-symbol-misplacement defect class becomes an accepted, documented gap — not a target for a heuristic replacement in this change).
- No rewriting of archived changes, their preserved `cross-review-ledger.md` files, or `HISTORY.md`'s past narrative entries — they stay as an accurate record of what happened and when.
- No scrubbing of scattered historical attribution comments/docs that merely say a past bug was *found by* a cross-review round (`packer/README.md`, `research/04-design/02-milestones.md`, `research/03-analysis/known-product-issues.md`, `research/artifacts/large-diff-memory/`, `App/GitReviewView.swift:400`) — these are provenance notes about already-shipped fixes, not live dependencies on the mechanism.

## Decisions

**Full deletion over advisory-only narrowing.** `remove-guide-gate` kept its underlying mechanism nowhere (guide-gate had no advisory-only mode to fall back to); this change is explicitly asked to go further than that precedent in one sense — cross-model-review *does* have a natural "keep the worker, drop only the gate" narrowing (Option A explored and rejected), but the owner chose full removal (Option B) instead. Decision: delete both layers. No optional/advisory `/xtty:cross-review` survives this change.

**Reuse the `remove-guide-gate` `--skip-specs` deviation, applied to every capability the removal touches.** OpenSpec 1.6.x's schema rejects a capability spec left with zero requirements (`SPEC_NO_REQUIREMENTS`), so a plain `openspec archive` will abort the instant `cross-model-review`'s last requirement is removed — identical to the collision `remove-guide-gate` hit on `agent-guide-budget`. The fix is the same: `openspec archive remove-cross-model-review -y --skip-specs`, then hand-delete `openspec/specs/cross-model-review/` and hand-edit `openspec/specs/coherence-review/spec.md`'s partial removal, then `openspec validate --all --type spec` to confirm. One sharpened detail carried forward from that precedent's own cross-review: the plain-archive abort is **global across the run**, not scoped to the offending capability — since this change touches exactly two capabilities (`cross-model-review` fully, `coherence-review` partially) and the first alone triggers the abort, `--skip-specs` + hand-merge is used for **both**, not just the one hitting zero.

**No self-review dogfood.** Since `.claude/`, `scripts/`, and `openspec/specs/` are not on the gate's own docs/tracker allowlist, this change would classify **in scope** for cross-model review by the very mechanism it deletes — the reviewer would be asked to bless its own deletion. `remove-guide-gate` used the *still-existing* review on its own retirement; this is a step further into reflexivity. Explicit owner decision: skip it. This change carries no human-attestation cross-review task and is not run through `/xtty:cross-review` before archive. The existing coherence-review agent (unaffected by this decision — it is a different capability) still reviews this change in the normal way.

**Record the Pass-4 coverage gap; don't backfill it.** The critic's Pass 4 (design-claim code-accuracy) is deliberately scoped to existing-symbol claims only; it has always exempted new-symbol placement (e.g. a new config field on the wrong owner type — the exact defect `add-git-diff-wrap-toggle` shipped and cross-model review caught) on the assumption that cross-model review covered that class. Once cross-model review is gone, nothing does. Decision: reword the exemption's rationale to state the gap plainly (no automated check catches new-symbol misplacement) rather than pointing at a mechanism that no longer exists, and stop there — widening Pass 4's mandate is a separate, later decision if the gap actually bites again, not a rider on this removal.

**Reword Learned-refutations bullets to past tense; don't delete them.** Several `AGENTS.md` Learned-refutations entries record measurements this mechanism's construction and use produced (the self-certification refutation, the tar-pit non-termination result, the gate-defect findings, the digest-fragility incident). Per the `remove-guide-gate` precedent, these get reworded to a retired-aware past tense that keeps the still-true underlying measurement and redirects any now-dead artifact pointer to `HISTORY.md`, rather than silently disappearing. A new bullet is added recording that retiring the gate does not retire the finding that motivated it (self-certification stays refuted; nothing model-authored has replaced the human-attestation idea, there simply is no gate at all now).

**Historical-status marker, not deletion, for the six research docs.** `cross-model-design-review-axes.md`, `cross-model-review-tar-pit-forensics.md`, `cross-review-gate-defect-forensics.md`, `codex-review-integration-forensics.md`, `cross-model-pairing-consult-research.md`, `cross-model-seat-assignment-research.md` each get the same top-of-file blockquote pattern `agents-md-structural-best-practices.md` already uses: a dated `> **Status: historical.**` note naming the retiring change, 1-3 sentences on what remains useful vs. what no longer describes current reality, and nothing else touched in the body.

## Risks / Trade-offs

- **[Risk] Losing the only mechanism that caught new-symbol-misplacement design bugs** → Mitigation: explicitly documented as an accepted, named gap (not silently absorbed); a future change can reintroduce a targeted check if the gap recurs.
- **[Risk] `AGENTS.md`'s prose edit is large and easy to under-scope by grepping alone** — several of the most load-bearing sentences (the archive step-0 rule, the section header, the "two axes" framing) don't contain the literal string "cross-review"/"cross-model-review" — a grep-only pass would leave them dangling. → Mitigation: the edit list in `tasks.md` names each location explicitly rather than delegating to "search and remove."
- **[Risk] The `--skip-specs` global-abort behavior is non-obvious and easy to trip** if the two touched capabilities aren't hand-merged together in one pass. → Mitigation: called out explicitly in tasks.md as a single combined step, not two separate ones.
- **[Trade-off] No advisory successor exists after this change** — if a future soundness-review need reappears, there is no cheap partial fallback (unlike `remove-guide-gate`, which left the advisory research-capture convention standing). Accepted: the owner judged the whole mechanism not worth its weight, not just its mechanical gate.

## Migration Plan

1. Delete `.claude/commands/xtty/cross-review.md`, `scripts/cross-review-digest.sh`, `scripts/cross-review-scope.sh`, `scripts/test-cross-review-scripts.sh`.
2. Edit `.claude/agents/xtty-openspec-critic.md`: drop the frontmatter's "+ cross-review-gate-task presence" clause, delete the "Cross-review-gate-task presence" Pass-1 bullet, reword the Pass-4 exemption note per the Decisions section above, bump the `Definition version` stamp.
3. Edit `AGENTS.md` per the full location list in `tasks.md` (section removal, step-0 rule, "Not in the table" callout, tooling-exception paragraph, Tooling row's cross-model-review clause, snapshot line, ~7 reworded Learned-refutations bullets, 1 new bullet).
4. Add the `coherence-review` MODIFIED-Requirements delta and the `cross-model-review` REMOVED-Requirements delta (this change's own `specs/`).
5. Add the historical-status blockquote to the six research docs.
6. Implement, verify no residual reference remains (re-run the same grep + completeness-sweep terms used to scope this change), then archive with `openspec archive remove-cross-model-review -y --skip-specs` followed by the hand-merge and `openspec validate --all --type spec`.
7. Standard tracker reconcile: `AGENTS.md` open-changes row, snapshot, `HISTORY.md` entry, verify-against-disk — no milestone advance (dev-workflow tooling, not a P-milestone).

Rollback: since nothing about product code or terminal behavior changes, rollback is a plain revert of the implementation commit(s) before archive; after archive, reintroducing the capability would be a new proposal, not a revert (the spec directory is gone and `openspec archive` is not reversible).

## Open Questions

None outstanding — both judgment calls this change depended on (no self-review dogfood; record-not-backfill the Pass-4 gap) were resolved during exploration and are captured as Decisions above.
