## 1. AGENTS.md rule

- [ ] 1.1 Add the "Test precision vs. the claim" bullet to `AGENTS.md`'s "Keeping a change coherent" walk-list (verbatim text in design.md), placed alongside the existing verification-harness-coupling bullet.

## 2. Critic agent operationalization

- [ ] 2.1 Add one new Pass-1 heuristic line to `.claude/agents/xtty-openspec-critic.md` (REVIEW-severity, alongside the existing `mechanism-neutrality` and `design↔requirements traceability` heuristics): flag a change that adds/modifies a test file without `design.md` stating the test's target claim, layer, and driver-reach.
- [ ] 2.2 Bump the `Definition version` stamp at the top of `.claude/agents/xtty-openspec-critic.md`, per the file's own maintenance note ("bump this stamp on EVERY edit to this file").

## 3. Verify

- [ ] 3.1 `openspec validate` on this change (inline, cheap).
- [ ] 3.2 Re-read both edited files once complete and confirm the new heuristic's wording matches design.md's final rule text and doesn't drift into a "prefer low-level tests" misreading (inline, cheap — a read-back, not a test run).

## 4. Coherence + archive (the standard change tail)

- [ ] 4.1 Pre-archive coherence review of this change. ⟶ xtty-openspec-critic (harden-test-precision-vs-claim)
- [ ] 4.2 Archive + reconcile: `openspec archive`; correct the merged requirement text to reflect what actually shipped; reconcile the trackers (AGENTS.md Current-status row + snapshot, HISTORY.md narrative); verify against disk (`openspec list` / `ls openspec/changes/archive/` / `ls openspec/specs/`). ⟶ archive-ritual
