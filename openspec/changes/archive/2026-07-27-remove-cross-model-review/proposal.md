## Why

The cross-model-review capability — the advisory `/xtty:cross-review` worker plus the mechanical human-attestation archive gate (scope classifier, reviewed-state digest, exempt-by-act checks) — has cost more than it has returned. Its own spec already states the mechanical checks are "accident tripwires and human-legibility aids, NOT adversarial guarantees," and using it in practice repeatedly surfaced friction the design itself calls out as unresolved: a re-attestation deadlock after any post-attestation drift, a reviewed-state digest fragile to any unrelated commit landing before archive, an explicitly unsettled exempt-by-act question, and three prior incidents of hand-typing unverified hex values before a print-only convenience was added. The owner has judged this weight not worth carrying for this project and wants the mechanism gone entirely — not narrowed to advisory-only.

## What Changes

- **BREAKING** Remove the `/xtty:cross-review` worker (its launcher command, the three-pass protocol) entirely — it is no longer available to run, not even as an optional advisory tool.
- Remove the mechanical archive gate: the scope classifier (`scripts/cross-review-scope.sh`), the reviewed-state digest tool (`scripts/cross-review-digest.sh`), and their regression harness (`scripts/test-cross-review-scripts.sh`).
- Retire the established `cross-model-review` capability (all 5 requirements removed).
- Modify the `coherence-review` capability: remove the `xtty-openspec-critic` agent's cross-review-gate-task-presence check (both the operationalized check and its requirement clause/scenario), since there is no longer a gate task to check for.
- Edit `.claude/agents/xtty-openspec-critic.md`'s Pass 4 (design-claim code-accuracy) scope note to honestly record that the new-symbol-misplacement defect class it deliberately exempts (e.g. a new config field placed on the wrong owner type) is no longer caught by anything, rather than pointing to a cross-model catch that no longer exists. Pass 4's own scope is not widened to compensate — the gap is recorded, not backfilled.
- Remove the "Cross-model design review + the human-attestation archive gate" section, its pre-archive step-0 rule, the "Not in the table" cross-review callout, and the tracked-tooling exception clauses (the launcher command + both scripts) from `AGENTS.md`; reword the Learned-refutations bullets that describe this mechanism to a past-tense, retired-aware form (keeping the still-true underlying measurement and pointing to `HISTORY.md` instead of deleted artifacts), and add one new bullet recording that retiring the gate does not retire the finding that motivated it (a model-authored artifact was refuted as an archive-eligibility signal; nothing model-authored replaces it).
- Mark the six research docs describing this mechanism's design, tar-pit, and defect history as historical (a dated status note at the top of each; content otherwise preserved as evidence).
- This removal is implemented directly, without running `/xtty:cross-review` on itself first — an explicit owner decision, since the reviewer would otherwise be asked to bless its own deletion.
- Preserve archived OpenSpec changes, their cross-review ledgers, and scattered historical "found in cross-review round N" attributions (in `packer/README.md`, `research/04-design/02-milestones.md`, `research/03-analysis/known-product-issues.md`, `research/artifacts/large-diff-memory/`, `App/GitReviewView.swift`) untouched, as records that the mechanism once existed and what it found while it did.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `cross-model-review`: remove the capability entirely — the repository will no longer provide the cross-model review worker or the human-attestation archive gate.
- `coherence-review`: remove the cross-review-gate-task-presence check from the single-change coherence pass, since the gate task it verifies no longer exists.

## Impact

- Removed: `.claude/commands/xtty/cross-review.md`, `scripts/cross-review-digest.sh`, `scripts/cross-review-scope.sh`, `scripts/test-cross-review-scripts.sh`, `openspec/specs/cross-model-review/`.
- Modified: `.claude/agents/xtty-openspec-critic.md`, `AGENTS.md`, `openspec/specs/coherence-review/spec.md`, and six `research/03-analysis/` docs (historical-status marker only).
- Product code and terminal behavior are unchanged.
- No other established capability spec references this mechanism (confirmed against every `openspec/specs/*/spec.md`); the sole currently-open change (`add-ci-pipeline`) does not reference it either.
- Retained as historical evidence: archived OpenSpec changes and their preserved `cross-review-ledger.md` files, prior `HISTORY.md` entries, scattered provenance comments/docs attributing past fixes to a cross-review round, with no rewriting.
