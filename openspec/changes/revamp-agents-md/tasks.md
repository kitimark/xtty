## 1. Restructure the "Shipped and archived" table

- [ ] 1.1 Confirm (grep) that every one of the Tooling row's ~24 change narratives already has a corresponding entry in `HISTORY.md`; for any not found, append its narrative to `HISTORY.md` first (should be none, per design.md's verified check, but re-confirm against the current file state before deleting anything).
- [ ] 1.2 Replace the Tooling row's cell with a bounded, category-keyed one-liner (categories: CI, dev-workflow agents, install/signing, test-image/VM, launchers; each with a `HISTORY.md` pointer), matching the one-line-per-unit shape the five phase rows already use.
- [ ] 1.3 Re-measure `wc -c AGENTS.md` and the row's own byte size (`grep -n '| Tooling |' AGENTS.md | wc -c`) and record the before/after numbers for the archive narrative.

## 2. Rewrite the Snapshot paragraph

- [ ] 2.1 Replace the run-on Snapshot paragraph with a short bulleted status block: milestone position, the authoritative test envelope + pointer to `packer/README.md`, and a "latest change: X, see HISTORY.md" line.
- [ ] 2.2 Confirm no information is lost — every fact currently in the paragraph either survives in the bulleted block or already lives in `HISTORY.md`/`packer/README.md`.

## 3. Tabularize the "How to work here" delegation bullets

- [ ] 3.1 Replace the four near-identical bullets (`xtty-test-validator`, `xtty-ci-investigator`, `xtty-openspec-critic`, `/xtty:research`) with one table: columns for agent/launcher, spawn triggers, the inline-vs-delegate boundary, the marker string, and a pointer to the mechanism/rationale. Keep the "Keep progress current" bullet as prose (different shape, not part of this template).
- [ ] 3.2 Confirm every marker string (`⟶ xtty-test-validator`, `⟶ xtty-ci-investigator`, `⟶ xtty-openspec-critic`, and the research-launcher's lack of one) survives verbatim in the table — these are load-bearing strings the apply loop reads.

## 4. Critic agent operationalization

- [ ] 4.1 Add the new Pass-1 heuristic line to `.claude/agents/xtty-openspec-critic.md` (REVIEW-severity, alongside the existing heuristics): flag a change whose tracker reconcile appends a per-change narrative to a category-keyed status-surface row/paragraph instead of leaving its category summary as-is.
- [ ] 4.2 Bump the `Definition version` stamp at the top of `.claude/agents/xtty-openspec-critic.md`, per the file's own maintenance note.

## 5. Verify

- [ ] 5.1 `openspec validate` on this change (inline, cheap).
- [ ] 5.2 Re-read the restructured `AGENTS.md` sections end-to-end and confirm they read coherently (no dangling references to content that moved) — inline, cheap, a read-back not a test run.
- [ ] 5.3 Confirm `openspec/specs/research-capture/spec.md` and `openspec/specs/coherence-review/spec.md`'s current (pre-archive) requirement text still matches what this change's deltas assume (re-read both established specs) — catches drift if either was edited by another change since this proposal was written.

## 6. Coherence + archive (the standard change tail)

- [ ] 6.1 Pre-archive coherence review of this change. ⟶ xtty-openspec-critic (revamp-agents-md)
- [ ] 6.2 Archive + reconcile: `openspec archive`; hand-merge the `coherence-review` requirement if `harden-test-precision-vs-claim` archived first (design.md D4); correct merged requirement text to reflect what actually shipped; reconcile the trackers (AGENTS.md Current-status row + snapshot, HISTORY.md narrative, research/README.md pointer to the now-settled research); verify against disk (`openspec list` / `ls openspec/changes/archive/` / `ls openspec/specs/`). ⟶ archive-ritual
