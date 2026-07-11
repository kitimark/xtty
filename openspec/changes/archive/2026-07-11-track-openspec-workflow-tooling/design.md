## Context

The `openspec` CLI generates workflow tooling into `.claude/`: the `commands/opsx/*.md` launchers (8 files) and the `skills/openspec-*/SKILL.md` skills (8 files). Today `.gitignore` ignores them — only the project's own `xtty-*` tooling (`commands/xtty/`, `skills/xtty-*/`, `agents/xtty-*`) is re-included and tracked. Every generated file carries a `generatedBy: "1.4.1"` frontmatter stamp.

Verified before proposing:
- **Routine commands don't rewrite them.** `openspec list` / `list --specs` / `validate --all` / `status` left all 16 files byte-identical (SHA compared before/after). The only regeneration triggers are the explicit `openspec init` and `openspec update` subcommands.
- **The re-include mechanism already works for nested files.** `.claude/skills/xtty-capture-research/SKILL.md` is tracked today under `!.claude/skills/xtty-*/`; `git check-ignore` reports it not-ignored. So `!.claude/commands/opsx/` + `!.claude/skills/openspec-*/` will track the nested files identically.
- **Machine-local files stay caught.** `.claude/settings.local.json` and `.claude/scheduled_tasks.lock` are matched by `.claude/*` and untouched by the two targeted re-includes.

This reverses a policy AGENTS.md documents in several places, so the edits span more than `.gitignore`.

## Goals / Non-Goals

**Goals:**
- Make the spec-driven workflow self-contained on a fresh clone and reviewable in PRs, by tracking the `opsx`/`openspec-*` tooling.
- Pin the workflow-prompt text to a recorded CLI version so a silent `openspec` bump can't change agent behavior with no diff.
- Keep `.gitignore` in the existing explicit, level-by-level style (targeted, not blanket).
- Record the tracking-and-pinning policy as `build-workflow` truth and reconcile every AGENTS.md passage the reversal touches.

**Non-Goals:**
- No blanket "track all of `.claude/`" default; `settings.local.json` + lock stay ignored.
- No change to how the `openspec` CLI is invoked, nor to any app runtime behavior.
- No verification-harness delta (no observable runtime surface).

## Decisions

**D1 — Targeted un-ignore, mirroring the `xtty-*` re-includes.** Add exactly two lines to `.gitignore`:
```
!.claude/commands/opsx/
!.claude/skills/openspec-*/
```
placed beside the existing `!.claude/commands/xtty/` and `!.claude/skills/xtty-*/` re-includes, and rewrite the leading comment block (lines 1–4) that currently states these "stay out of git." *Alternative rejected:* a blanket flip to "track everything except `settings.local.json` + `*.lock`" — it would auto-track any future machine-local file the CLI or agent drops into `.claude/`, trading explicit control for convenience the project hasn't asked for.

**D2 — Why the two generated-artifact classes are treated oppositely.** `build-workflow` already says the generated Xcode project *SHALL NOT be tracked*. This change adds the opposite rule for the workflow tooling. The distinction is real, not contradictory:

| | Generated Xcode project | opsx / openspec-\* tooling |
| --- | --- | --- |
| Source of truth | committed in-repo `project.yml` | the external CLI's built-in templates (no in-repo source) |
| Regenerated | on every build, from that source | ~never — only on explicit `openspec init`/`update` |
| Agent needs it present? | no | **yes** — `/opsx:*` + the skills don't exist for the agent until the files are on disk |
| Consequence of ignoring | none (rebuilt on demand from tracked input) | fresh clone has no workflow; prompt text unpinned |

So the same principle — *track the thing a fresh clone can't otherwise reconstruct from tracked inputs* — points to *untracked* for the xcodeproj and *tracked* for the workflow tooling.

**D3 — Pin anchor + drift policy.** The pin is the `generatedBy` version stamp already in each file. The policy: treat a `generatedBy` bump like any other reviewable change — regenerate via `openspec update` (or `init`) and commit the diff deliberately. Nothing enforces this mechanically; it's a documented discipline in AGENTS.md's Conventions bullet. Since routine workflow commands are proven not to rewrite the files, day-to-day work won't produce spurious diffs.

**D4 — Reconcile the archive-ritual passages, preserving the principle.** Committing the `openspec-*` skills makes `/openspec-archive-change` no longer gitignored, which contradicts three AGENTS.md passages that justify the `⟶ archive-ritual` marker by calling that skill "gitignored"/"uncommitted":
- the **G13 Learned-refutation** (*"anchor to committed guidance, never the gitignored `/openspec-archive-change` skill — a committed task can't depend on an uncommitted tool"*),
- the **Keep-progress-current** archive-ritual passage (*"not … the openspec-generated, gitignored `/openspec-archive-change` skill"*),
- the **tasks.md archive-marker rule** (*"not the gitignored archive skill"*).

The reframing keeps the conclusion (anchor the ritual to the hand-authored committed AGENTS.md procedure) while replacing the now-false reason with the durable one: *even committed, the skill is CLI-generated and a `generatedBy` bump can rewrite it, so the committed hand-authored procedure — not the generated skill — remains the stable anchor.* This actually strengthens the rule.

**D5 — Test precision vs. the claim.** This change has no app runtime surface, so there is no program/UI layer to drive. The claims are purely about git's tracking decision, and they live in `.gitignore` evaluation. The right driver is therefore `git check-ignore -v` / `git ls-files` / `git add --dry-run` run against the actual repo — the exact layer where "is this path tracked/ignored?" is decided. A deeper (app/harness) test would prove nothing here, and a shallower check (grepping `.gitignore` text) would only prove the lines exist, not that git resolves them correctly against the nested-file-under-re-included-dir rule. Hence the verify task asserts, by effect: `opsx/*` + `openspec-*/SKILL.md` resolve to **tracked**, and `settings.local.json` + `scheduled_tasks.lock` resolve to **still ignored**. No `verification-harness` delta — the harness-coupling rule is about observable *app* behavior, which this change has none of.

## Risks / Trade-offs

- **[Spurious diffs after `openspec update`]** → Accepted and documented (D3). The re-commit-on-bump discipline lives in the Conventions bullet; routine commands are proven not to trigger it.
- **[A future AGENTS.md edit re-introduces the "gitignored archive skill" phrasing]** → The `xtty-openspec-critic` coherence pass (pre-archive) and this design's D4 record the corrected rationale; the spec requirement makes the tracked-tooling policy authoritative.
- **[Blanket-vs-targeted regret]** → If the project later wants everything tracked, widening the re-include is a one-line follow-up; starting targeted is the reversible choice.
- **[The pin is a convention, not a lock]** → No mechanical guard prevents an un-reviewed regeneration commit. Mitigated by review + the visible `generatedBy` stamp; a hard lock (e.g. CI diffing against a recorded version) is out of scope.

## Migration Plan

1. Edit `.gitignore` (D1); rewrite the leading comment.
2. `git add .claude/commands/opsx .claude/skills/openspec-*` — the 16 files enter tracking.
3. Reconcile AGENTS.md: the Conventions "Don't track local tooling" bullet (add `opsx`/`openspec-*` to the committed set + the drift policy) and the three archive-ritual passages (D4).
4. Verify by effect (D5): `git check-ignore` / `git ls-files --error-unmatch` / `git add --dry-run`.
5. Standard change tail: pre-archive `⟶ xtty-openspec-critic`, then `⟶ archive-ritual` (archive merges the `build-workflow` delta + reconciles trackers).

Rollback: revert the commit — re-adds the ignore lines and `git rm --cached`s the 16 files. No runtime state to unwind.

## Open Questions

- None blocking. (A mechanical pin-enforcement guard in CI is deliberately deferred as out of scope, not unresolved.)
