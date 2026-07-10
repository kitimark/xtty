## 1. AGENTS.md rule

- [x] 1.1 Add the "Test precision vs. the claim" bullet to `AGENTS.md`'s "Keeping a change coherent" walk-list (verbatim text in design.md), placed alongside the existing verification-harness-coupling bullet.

## 2. Critic agent operationalization

- [x] 2.1 Add one new Pass-1 heuristic line to `.claude/agents/xtty-openspec-critic.md` (REVIEW-severity, alongside the existing `mechanism-neutrality` and `design↔requirements traceability` heuristics): flag a change that adds/modifies a test file without `design.md` stating the test's target claim, layer, and driver-reach.
- [x] 2.2 Bump the `Definition version` stamp at the top of `.claude/agents/xtty-openspec-critic.md`, per the file's own maintenance note ("bump this stamp on EVERY edit to this file").

## 3. Verify

- [x] 3.1 `openspec validate` on this change (inline, cheap).
- [x] 3.2 Re-read both edited files once complete and confirm the new heuristic's wording matches design.md's final rule text and doesn't drift into a "prefer low-level tests" misreading (inline, cheap — a read-back, not a test run).

## 4. Coherence + archive (the standard change tail)

- [x] 4.1 Pre-archive coherence review of this change. ⟶ xtty-openspec-critic (harden-test-precision-vs-claim)
- [x] 4.2 Archive + reconcile: `openspec archive`; correct the merged requirement text to reflect what actually shipped; reconcile the trackers (AGENTS.md Current-status row + snapshot, HISTORY.md narrative); verify against disk (`openspec list` / `ls openspec/changes/archive/` / `ls openspec/specs/`). **If `revamp-agents-md` implemented or archived first:** hand-merge, don't overwrite — its own delta also modifies `coherence-review`'s "Committed coherence-review agent tooling" requirement (both this change's and `revamp-agents-md`'s heuristic sentences + scenarios must both survive), and it also appends a Pass-1 heuristic line + bumps the `Definition version` stamp in `.claude/agents/xtty-openspec-critic.md` and edits `AGENTS.md` in a different region — a mechanical archive of whichever change goes second will drop the first's additions unless merged by hand (confirmed by coherence review 2026-07-11; see `openspec/changes/revamp-agents-md/design.md` D4). ⟶ archive-ritual
