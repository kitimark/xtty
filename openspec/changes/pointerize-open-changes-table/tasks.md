## 1. Spec delta

- [ ] 1.1 (verify, inline) `openspec validate pointerize-open-changes-table` passes for the `research-capture` MODIFIED requirement (correct SHALL/scenario formatting, whole existing block pasted before edits)

## 2. AGENTS.md — Current status

- [ ] 2.1 Delete the "Open changes" table (state/what-it-is/detail rows and its `must match openspec list` header) and replace it with a one-line derive-on-demand pointer in the same idiom as "Established specs": `**Open changes:** derive on demand — `openspec list` (or `openspec show <name>` for detail); disk is the truth, no cached list here.`
- [ ] 2.2 Reword the "Keep progress current" checklist bullet: remove the instruction to update "the change's row in the Current-status table," and remove the verify-against-disk clause that compares `openspec list` against the open-changes table (there is no row left to keep in sync or check against)

## 3. Committed tooling — `xtty-openspec-critic`

- [ ] 3.1 Rewrite the agent's disk-drift check ("Active changes match the AGENTS.md open-changes/Current-status table") to instead confirm the derive-on-demand pointer line is present and generic (flags if it's been hand-edited to name a specific change, or if a per-change row has regrown)
- [ ] 3.2 Update the agent's line-22 reference to "AGENTS.md Current-status table" as a ground-truth tracker so it no longer implies a per-change open-changes table exists
- [ ] 3.3 Bump the agent's version stamp, matching the precedent set when `slim-status-surface` last changed the guide's status-surface shape (v7→v8)

## 4. Reconcile and verify against disk

- [ ] 4.1 Grep AGENTS.md and `.claude/agents/` for any other stale reference to "the open-changes table" beyond the ones already identified, and fix or intentionally leave historical narrative untouched (HISTORY.md and archived-change docs are historical record, not live trackers — not edited)
- [ ] 4.2 `openspec validate --all --type spec` passes with no regressions elsewhere

## 5. Standard change tail

- [ ] 5.1 Pre-archive coherence review ⟶ xtty-openspec-critic (pointerize-open-changes-table)
- [ ] 5.2 Archive + reconcile: `openspec archive pointerize-open-changes-table` (merge the `research-capture` delta), finish-by-hand (confirm the merged requirement text reads correctly, `openspec validate --all --type spec`), reconcile the trackers per AGENTS.md "Keep progress current" (snapshot only if posture moved; `HISTORY.md` narrative), and verify against disk (`openspec list`, `ls openspec/changes/archive/`, `ls openspec/specs/`). ⟶ archive-ritual
