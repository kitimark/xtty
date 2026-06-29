## 1. The tooling files

- [ ] 1.1 Create `.claude/skills/xtty-capture-research/SKILL.md` (flat dir = `/xtty-capture-research`): frontmatter `name` + a tight auto-trigger `description` ("after a research investigation/decision settles, or a change is archived — capture it into research/ and reconcile the trackers"); body = the capture-and-reconcile checklist (place doc w/ conventions → index in README → reconcile AGENTS + milestones → **verify-against-disk** → commit on request) that **defers to AGENTS.md** for the rules.
- [ ] 1.2 Create `.claude/commands/xtty/capture-research.md` (nested = `/xtty:capture-research`): a thin launcher that invokes the `xtty-capture-research` skill (no duplicated body).

## 2. Track the tooling in git

- [ ] 2.1 Replace the blanket `.claude/` rule in `.gitignore` with the level-by-level negation block (`.claude/*` → re-include `commands/` then `commands/*` then `!commands/xtty/`; re-include `skills/` then `skills/*` then `!skills/xtty-*/`), with an explanatory comment in the SwiftTerm-comment style.
- [ ] 2.2 Stage the new tooling files (`git add .claude/commands/xtty .claude/skills/xtty-capture-research`).

## 3. Document it in AGENTS.md

- [ ] 3.1 Update the Conventions line: "don't track `.claude/`" → "`.claude/` is gitignored **except** the committed `.claude/commands/xtty/` + `.claude/skills/xtty-*/` tooling."
- [ ] 3.2 Add a concise **capture-and-reconcile checklist** (write+index the research doc per conventions → reconcile the trackers [AGENTS Current status + `research/04-design/02-milestones.md`] → **verify-against-disk** [`openspec list` · `ls openspec/changes/archive/` · `ls openspec/specs/`] → commit on request) — the source of truth the skill defers to.

## 4. Verify the ignore boundary

- [ ] 4.1 `git check-ignore -v` confirms the boundary: `.claude/settings.local.json`, `.claude/scheduled_tasks.lock`, `.claude/commands/opsx/explore.md`, `.claude/skills/openspec-explore/SKILL.md` all still **ignored**; `.claude/commands/xtty/capture-research.md` + `.claude/skills/xtty-capture-research/SKILL.md` **not ignored** (tracked).
- [ ] 4.2 `git status --short .claude/` shows only the `xtty` tooling paths as new/tracked (no machine-local or generated file leaked in).
- [ ] 4.3 `openspec validate add-capture-research-tooling --strict` clean; on completion update the trackers per the very workflow this change documents.
