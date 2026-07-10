## Why

`AGENTS.md` is 206 lines but 68,897 bytes (~333 chars/line) and growing at ~8-10KB/day — a prior diet (`slim-agents-context`, 2026-07-06) cut it 80.6KB→28.5KB but the gain eroded within ~4-5 days. Two `/xtty:research` fan-outs (`research/03-analysis/agents-md-structural-best-practices.md` + its addendum) pinned down the actual mechanism, not just the symptom: the file's "Shipped and archived" table has 6 rows — 5 correspond to closed feature milestones and total only ~1.2KB because they're edited only when a *phase* closes (rare); the 6th, "Tooling," is 16.6KB (93% of the table, 24% of the whole file) because it's edited on every archived tooling change (change-keyed, not category-keyed like its siblings). The Snapshot paragraph (5.8KB) and four near-identical agent-delegation bullets in "How to work here" (11KB) carry the same run-on-narrative anti-pattern. The existing `research-capture` spec requirement ("SHALL NOT grow the guide's status surface beyond a bounded entry") already forbids this, but doesn't define "bounded" precisely enough to have prevented it in practice, and nothing currently checks compliance — the rule has been silently violated since the last diet.

## What Changes

- Restructure the "Shipped and archived" table's "Tooling" row from an ever-growing per-change cell into a bounded, **category-keyed** index (edited only when a genuinely new category of tooling appears, never per-change) — mirroring the shape its sibling phase rows and the "Open changes" table already use. The ~24 narratives currently bracketed into the cell are verified already present in `HISTORY.md`; removing them from `AGENTS.md` is a pure deletion with zero information loss.
- Rewrite the run-on "Snapshot" paragraph as a short bulleted status block (milestone position, authoritative test envelope + pointer, latest-change pointer) — the same anti-pattern as the Tooling row, at smaller scale.
- Tabularize the four near-identical agent/launcher delegation-boundary bullets in "How to work here" (`xtty-test-validator`, `xtty-ci-investigator`, `xtty-openspec-critic`, `/xtty:research`) into one table (agent/launcher · spawn triggers · inline-vs-delegate boundary · marker · pointer) — they currently repeat the same template as four separate multi-paragraph essays.
- Clarify the `research-capture` spec requirement: for a perpetual (never-closing) status-surface row, "bounded entry" explicitly means **category-keyed**, not change-keyed — closing the ambiguity that let the Tooling row violate the rule's spirit while nominally satisfying "a row in the table."
- Add one new REVIEW-severity `xtty-openspec-critic` Pass-1 heuristic (mirroring the established pattern from `harden-test-precision-vs-claim`): flag a change whose tracker reconcile appends a per-change narrative to a category-keyed status-surface row/paragraph instead of routing it to `HISTORY.md`.
- Explicitly do **not** add a mechanical CI byte/line-count gate this round. Real precedent exists (`konflux-ci`, `tektoncd/catalog`, `cloudposse/atmos`, `homeassistant-ai/ha-mcp` all gate `AGENTS.md` size in CI), but the research's adversarial critique found it disproportionate for xtty specifically: xtty pushes straight to `main` with no PR to hang a path-scoped gate on, and a fixed ceiling would immediately red a file that legitimately carries durable content. The critic heuristic is the proportionate primary mechanism; its sufficiency should be measured over the next several archives, not assumed — revisit a mechanical gate only if the heuristic proves insufficient.
- Explicitly do **not** nest `AGENTS.md` into per-directory files. xtty is a single app plus one small SPM package, not a monorepo of differently-stacked subprojects — the bar every real nesting precedent (Airflow, Codex) clears.
- No product code changes.

## Capabilities

### New Capabilities

<!-- none — this tightens two existing capabilities' checklists -->

### Modified Capabilities

- `research-capture`: the **Documented capture-and-reconcile workflow with verify-against-disk** requirement's "keep the guide lean" clause gains a precise definition of "bounded entry" for a perpetual (non-closing) row — category-keyed, edited only on a new category, never per-change.
- `coherence-review`: the **Committed coherence-review agent tooling** requirement's single-change pass gains one more heuristic check — whether a tracker reconcile appended a per-change narrative to a status-surface row/paragraph that should only change per-category.

## Impact

- **`AGENTS.md`**: the Shipped-and-archived table's Tooling row, the Snapshot paragraph, and the four delegation bullets in "How to work here" are restructured (recovers roughly half the file's current bytes; exact figures land in `design.md`).
- **`.claude/agents/xtty-openspec-critic.md`**: one new Pass-1 heuristic line + a bumped `Definition version` stamp.
- **`HISTORY.md`**: unaffected — it already holds the full narratives the Tooling row's sweep removes from `AGENTS.md`; no edits needed there.
- **`openspec/specs/research-capture/spec.md`** and **`openspec/specs/coherence-review/spec.md`**: each gains one clarified/extended requirement via delta at archive.
- **No product code, no build system, no tests** — docs and committed agent-tooling only, parallel to `slim-agents-context` and `harden-test-precision-vs-claim`.
