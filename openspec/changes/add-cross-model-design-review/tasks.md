## 1. Critic code-accuracy pass (coherence-review MODIFY)

- [ ] 1.1 Add a **Pass 4 — design-claim code-accuracy** to `.claude/agents/xtty-openspec-critic.md`'s single-change pass: extract concrete code claims from `design.md`/`tasks.md` (`` `Type.field` ``, `` `File.swift` ``, `"mirrors `X`"`, symbol names), grep the source, and flag a claimed symbol that is **absent/contradicted** as BLOCKER, a fuzzy/unlocatable claim as REVIEW — bounded to claims about the **existing** codebase, read-only, no edits (design D6).
- [ ] 1.2 Bump the agent's stamp to **`Definition: v4 (<date>)`** and update the delivery-check stamp the launcher `.claude/commands/xtty/review.md` expects to match.
- [ ] 1.3 Verify by effect: run the critic (`/xtty:review`) on a change carrying a deliberately wrong code claim (a field asserted on the wrong type) and confirm a BLOCKER naming the claim + contradicting source; confirm a change whose claims match source is **not** flagged.

## 2. Cross-model review orchestrator (cross-model-review)

- [ ] 2.1 Author `.claude/commands/xtty/cross-review.md` as the **main-loop protocol**: given a design-bearing change, fire **Pass A** (the Opus critic) ∥ **Pass B** (`codex-companion.mjs adversarial-review`, background, owned by the main loop) ∥ **Pass C** (an inline Opus design-soundness `Agent` call mirroring B's lens).
- [ ] 2.2 Specify **target selection** for Pass B: working-tree review when the change is uncommitted, `--base <ref>` when committed (design D5).
- [ ] 2.3 Specify the **union-with-consensus ledger**: merge findings tagged by source; flag a finding raised by **both** B and C as a two-model consensus finding.
- [ ] 2.4 Specify the **terminating convergence loop**: each round adjudicate every finding as fix | dismiss-with-recorded-rationale, apply fixes, re-review; converged = zero unresolved findings from any pass (not identical output); bound at **N = 2 rounds**, then escalate the residual ledger to the human.
- [ ] 2.5 Specify the **degrade path**: Codex unavailable (auth/headless/CI) → run Passes A + C, mark Pass B skipped, still return a verdict; never hard-block.
- [ ] 2.6 Confirm the command is committed (un-ignored) alongside the other `.claude/commands/xtty/` tooling (`.gitignore` allowlist covers it).
- [ ] 2.7 Verify by effect: run `/xtty:cross-review` on a real design-bearing change and confirm the tri-pass fires, the ledger merges with a consensus flag, the loop converges (or escalates at the bound), and a Codex-absent run degrades to A + C with the skip marked.

## 3. Guide + research capture

- [ ] 3.1 Document in `AGENTS.md`: the cross-model **convergence protocol** (passes, union-with-consensus ledger, terminating convergence rule, round bound, degrade behavior), the two-axes framing (conformance vs soundness), the design-bearing scope + pre-archive timing, and the `⟶ xtty-cross-review` change-tail marker that **replaces** `⟶ xtty-openspec-critic` for design-bearing changes (trivial changes keep the single-agent marker).
- [ ] 3.2 Update `AGENTS.md`'s committed-tooling bullet + the agents/launchers table to list `/xtty:cross-review`, and note Pass C is inline (not a standing agent) per the anti-roster refutation.
- [ ] 3.3 Capture `research/03-analysis/cross-model-design-review-*.md`: the complementary-axes finding with **this session as the worked exemplar** (critic COHERENT ↔ Codex caught the `XttyConfigSet` config bug + the shallow test); index it in `research/README.md`.

## 4. Land the change

- [ ] 4.1 Pre-archive cross-model review of this change — **dogfood** the tooling built in groups 1–2, using the marker defined in group 3. ⟶ xtty-cross-review (add-cross-model-design-review)
- [ ] 4.2 Archive + reconcile: merge the spec deltas (`openspec archive`), fill the new `cross-model-review` spec Purpose, tick trackers (Current-status row + snapshot + HISTORY narrative + established-specs line + milestone), and verify-against-disk. ⟶ archive-ritual
