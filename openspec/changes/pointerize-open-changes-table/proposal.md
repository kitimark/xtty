## Why

AGENTS.md's Current-status **"Open changes"** table hand-transcribes each in-flight change's state and a free-typed one-line summary of what's left. That summary already drifted from disk: the `add-ci-pipeline` row states "remaining: repo public, pr-lint PR, branch protection, archive," but `gh repo view` shows the repository is already public — and `tasks.md`'s own checkbox (1.2, "Make the repository public") is *also* still unticked, so this isn't a case of the AGENTS.md row lagging behind an up-to-date `tasks.md`; neither tracker was updated when the repo actually went public. That's a sharper motivating case, not a weaker one: even the more authoritative-looking checkbox list drifts, so a hand-maintained one-line summary in AGENTS.md is one more independent copy of the same fragile state, not a safety net against it (pointerizing this change doesn't retroactively fix `add-ci-pipeline`'s own stale checkbox — that's a separate, pre-existing problem out of this change's scope — it just removes AGENTS.md's copy of the same claim). The table's only reason for existing as a cached artifact — `research-capture`'s status-surface requirement mandating "a tabular per-change entry (state, one-line summary, pointer to detail)" — was explicitly weighed against pointerizing it during `slim-status-surface` (design decision D4) and kept, but only on a cost argument ("save 298 bytes") that was never measured against a real alternative; the pointerize probe arm (A-T) was dropped before running. The guide's sibling section, **"Established specs,"** already uses the derive-on-demand idiom this proposal extends to open changes ("derive on demand — `openspec list --specs`... disk is the truth, no cached list here"), so this also brings the two sections into a consistent shape.

The owner has weighed the tradeoff explicitly and prefers updating AGENTS.md less frequently over keeping the free one-line "what's left" context: a session that wants that detail will run `openspec show <name>` or read `tasks.md` instead of trusting a hand-maintained summary that can silently go stale.

## What Changes

- Change the `research-capture` spec's status-surface requirement so the guide's tabular per-change entry for **in-flight changes** is replaced by a derive-on-demand pointer (`openspec list`, `openspec show <name>` for detail) — never a cached row. **BREAKING** in the sense that it removes a previously-mandated guide element (the tabular per-change entry for open changes); the snapshot and learned-refutations elements of the status surface are unaffected.
- Delete AGENTS.md's "Open changes" table and replace it with a one-line pointer in the same idiom as the existing "Established specs" line.
- Update AGENTS.md's "Keep progress current" checklist bullet: drop the instruction to update "the change's row in the Current-status table," and drop the verify-against-disk clause that compares `openspec list` against the open-changes table (there is no longer a row to keep in sync or check).
- Update the committed `xtty-openspec-critic` agent, which currently runs a disk-drift check comparing `openspec list` against the AGENTS.md open-changes table (and references that table generically as a ground-truth tracker) — this check is removed/rewritten since the table it checks against no longer exists. Bump the agent's version, matching the precedent set when `slim-status-surface` last changed the guide's status-surface shape.
- Update the committed `xtty-capture-research` skill the same way: its verify-against-disk snippet annotates `openspec list` with "must match the Current-status open-changes table", and its reconcile step (and frontmatter description) restate the per-change table-row update — rewritten to the derive-on-demand shape, with the skill's `version` metadata bumped.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `research-capture`: the "Documented capture-and-reconcile workflow with verify-against-disk" requirement's status-surface description changes from a tabular per-change entry for in-flight changes to a derive-on-demand pointer; the snapshot and learned-refutations elements, and the reconcile/archive-ritual/capture-depth-bar clauses, are unchanged.

## Impact

- **Docs:** `AGENTS.md` (Current status section: table removed, "Keep progress current" bullet reworded), `CLAUDE.md` (symlink, no separate edit).
- **Spec:** one `## MODIFIED Requirement` delta in `research-capture` (the full existing requirement block pasted, with the status-surface paragraph's open-changes clause changed).
- **Tooling:** `.claude/agents/xtty-openspec-critic.md` — the open-changes-vs-disk check removed/rewritten, version bumped; `.claude/skills/xtty-capture-research/SKILL.md` — the row-update step and the open-changes-table verify line rewritten to derive-on-demand, version bumped.
- **No application code, no other spec.** The one currently-open change (`add-ci-pipeline`) loses its AGENTS.md row as a direct consequence; its own progress continues to be tracked in its own `tasks.md` and via `openspec list`/`openspec show`, unaffected by this change.
