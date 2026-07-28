## Context

AGENTS.md's Current-status section carries two distinct per-change tables:

- **"Open changes"** — one row per in-flight OpenSpec change, hand-updated as tasks complete. Required by `research-capture`'s status-surface clause and by the table's own header text in AGENTS.md ("must match `openspec list`").
- **"Shipped and archived"** — bounded, category-keyed rows for completed work, updated once at archive time and then largely static.

The first table is the one that drifts: it's edited every time an in-flight change's task list moves, by hand, and its content isn't mechanically derived from anything. It already has drifted — `add-ci-pipeline`'s row lists "repo public" as still remaining; `gh repo view` shows the repository has been public for some time — and notably `tasks.md`'s own checkbox (1.2) is *also* still unticked, so this isn't a case of the row lagging behind an accurate `tasks.md`; neither tracker got updated when the repo actually went public. Pointerizing doesn't retroactively fix `add-ci-pipeline`'s stale checkbox (that's a separate, pre-existing problem in that change, out of scope here) — it removes AGENTS.md's independent copy of the same claim, so there's one fewer place for this exact class of drift to live. The second table doesn't have this failure mode because it's write-once per change.

`slim-status-surface` (archived 2026-07-28) considered removing/pointerizing the open-changes table (design decision D4) and rejected it — but purely on a cost argument ("save 298 bytes") that was never measured against a real alternative; the pointerize probe arm was dropped before running, and the drift above had not yet been *observed* to inform the call (whether the repo was already public when D4 was written is unrecorded — no tracker noticed either way; D4 itself even named recurring table-maintenance friction as the trigger for "a small follow-up change" that pointerizes the table). The owner has now stated a preference (update AGENTS.md less frequently) that D4 didn't have to weigh, plus the "Established specs" section already demonstrates the derive-on-demand idiom this change extends to open changes.

## Goals / Non-Goals

**Goals:**
- Stop AGENTS.md's open-changes table from being a hand-maintained, drift-prone cache.
- Bring "Open changes" into the same derive-on-demand idiom already used by "Established specs."
- Keep the committed tooling (`xtty-openspec-critic`, `xtty-capture-research`) coherent with the new shape — no check or checklist step left pointing at a table that no longer exists.

**Non-Goals:**
- Touching the "Shipped and archived" table — it doesn't have the drift failure mode this change is fixing, and `research-capture` explicitly keeps it tabular/category-keyed.
- Finishing or archiving `add-ci-pipeline` — its own remaining tasks are unrelated to this change; it simply loses its AGENTS.md row as a side effect, and its state continues to live in its own `tasks.md` and `openspec list`/`openspec show`.
- Changing what `openspec list` or `openspec show` output — this change only changes what the guide asks a reader to do, not the CLI.

## Decisions

**D1 — Pointerize only the in-flight table, not the archived one.** The two tables have different failure profiles (drift-prone vs. write-once), so only the drift-prone one needs the derive-on-demand fix. The `research-capture` spec delta is worded to split what was one generic "tabular per-change entry" clause into two: a derive-on-demand pointer for open changes, and an unchanged tabular entry for archived ones — so a future reader of the spec can't conflate the two and re-apply the old caching habit to open changes, or mistakenly try to pointerize the archive table too.

**D2 — The AGENTS.md replacement line mirrors "Established specs" verbatim in shape.** Rather than inventing new phrasing, reuse the exact idiom already proven in the guide: `**Open changes:** derive on demand — `openspec list` (or `openspec show <name>` for detail); disk is the truth, no cached list here.` Consistency here is itself the payoff — a reader who's already learned the "Established specs" pattern recognizes this one for free.

*Alternative considered:* keep a table shell with just a header and no rows, filled in only when a change is open. Rejected — it reintroduces exactly the maintenance the change is trying to remove (someone still has to notice a change opened and re-add a row), and it isn't cheaper than the one-line pointer, which is always accurate regardless of how many changes are open.

**D3 — Both committed-tooling surfaces (`xtty-openspec-critic`, `xtty-capture-research`) are rewritten and version-bumped, matching precedent.** The critic's line 45 check ("Active changes match the AGENTS.md open-changes/Current-status table") and its line-22 ground-truth-tracker reference both name the table directly. Since the table is gone, the check is rewritten to confirm the *pointer line* is present and generic (not itself drifted into naming a specific change), rather than diffing rows against `openspec list`. This mirrors the exact precedent set when `slim-status-surface` last changed the guide's status-surface shape and bumped the critic (v7→v8) to match. The **`xtty-capture-research` skill** has the same failure mode in three places: its step-4 verify snippet annotates `openspec list` with "must match the Current-status open-changes table" (`SKILL.md:38`), its step-3 reconcile bullet restates the per-change **table row** update that AGENTS.md's reworded bullet drops, and its frontmatter description names the "AGENTS.md Current status table/snapshot" — all three are rewritten to the derive-on-demand shape, and the skill's `version` metadata is bumped (1.3 → 1.4) so an edit is detectable, like the critic's stamp.

**D4 (superseding the prior D4 in `slim-status-surface`) — Reopen and reverse the "keep the table" call.** The prior decision was made on a pure byte-cost argument with no counter-evidence. This change supplies the counter-evidence (observed drift) and a stated preference (lower update frequency) that together outweigh the at-a-glance convenience the table provided. This is recorded here rather than silently overwritten so a future reader can see the call was revisited deliberately, not by accident.

## Risks / Trade-offs

**[Risk] Losing free at-a-glance context.** Today, AGENTS.md tells a session in one line what's blocking an open change ("remaining: repo public, pr-lint PR, branch protection, archive") with zero commands run. After this change, a session only learns "a change is open" from the pointer and must run `openspec show <name>` or open `tasks.md` to learn what's left.
→ *Mitigation:* this is the explicitly accepted trade — the owner prefers not maintaining the row over keeping this convenience, and `openspec show <name>` already surfaces more detail (the full proposal) than the one-line summary did.

**[Risk] The spec delta narrows a previously-generic clause into two, which could be read as scope creep beyond "just remove a table."**
→ *Mitigation:* the split is the minimum precise wording needed to keep the archived-changes table's existing behavior (tabular, category-keyed, write-once) explicitly unchanged while carving out the open-changes behavior; without the split, the MODIFIED requirement would either under-specify (leave "tabular per-change entry" ambiguous about which table it still governs) or over-reach (accidentally also permit pointerizing the archive table, which isn't wanted).

**[Risk] `xtty-openspec-critic`'s rewritten check could regress to a no-op (never flagging anything) since there's no row to diff against `openspec list` anymore.**
→ *Mitigation:* the rewritten check still has a real failure mode to catch — a future edit that re-introduces a per-change row (regrowth), or a pointer line that's been hand-edited to reference a specific change name (defeating the point of a generic derive-on-demand line). Task 3.1 in `tasks.md` spells out the exact check.

## Migration Plan

1. Land the `research-capture` spec delta (this is what unblocks the AGENTS.md edit being spec-compliant).
2. Edit AGENTS.md: delete the "Open changes" table, add the one-line pointer; reword the "Keep progress current" bullet's row-update clause, verify-against-disk clause, and the same bullet's closing **Pre-tick self-check** parenthetical ("row + snapshot + …" loses its "row" item).
3. Edit `.claude/agents/xtty-openspec-critic.md`: rewrite the line-45 check and the line-22 tracker reference; bump the agent version stamp. Edit `.claude/skills/xtty-capture-research/SKILL.md`: rewrite the step-4 verify line, the step-3 row-update bullet, and the frontmatter description; bump its `version` metadata.
4. Run `openspec validate --all --type spec` and re-read AGENTS.md for any other stale reference to "the open-changes table" (e.g. cross-review/HISTORY narrative pointers written when the table existed — those are historical record and are NOT edited, only the live guide and live tooling are).
5. No rollback complexity — this is a docs/tooling-only change with no runtime behavior; reverting is a plain git revert if ever needed.

## Open Questions

- None outstanding. The one deliberate scope boundary (archived-table untouched) is recorded as D1/Non-Goals above, not left open.
