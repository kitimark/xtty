## Context

`.claude/` is gitignored in this repo (a blanket `.claude/` rule) and AGENTS.md states "don't track local tooling." But the capture-research skill+command are *project knowledge*, not machine-local cruft — and the openspec `opsx`/`openspec-*` tooling under `.claude/` is tool-generated and re-creatable, whereas hand-authored tooling is not. So this change carves a narrow tracked exception.

The layout was settled by an authoritative check of the Claude Code skills docs (via the `claude-code-guide` agent) plus the repo's own `.claude/` contents. Key findings:

- **Skill discovery is flat**: the loader globs `.claude/skills/*/SKILL.md` (one level), not `**`. A nested `.claude/skills/xtty/capture-research/SKILL.md` is **not discovered**.
- **A skill's invocation slug is its directory name** (frontmatter `name:` is a display label only). `.claude/skills/xtty-capture-research/` → `/xtty-capture-research`.
- **Skills are slash-invocable** (`/xtty-capture-research`) *and* auto-trigger on their `description`.
- **Colon-namespacing for skills** is reserved for plugins / separate nested-repo `.claude/skills/` folders — it cannot be minted in frontmatter for a project skill.
- **Commands namespace by folder**: `.claude/commands/opsx/explore.md` → `/opsx:explore` (confirmed in-repo), so `.claude/commands/xtty/capture-research.md` → `/xtty:capture-research`.
- The openspec integration is itself asymmetric — **nested commands, flat skills** — so "follow the openspec structure" means exactly that.

## Goals / Non-Goals

**Goals:**
- A committed skill that auto-triggers the capture-and-reconcile workflow (the trigger is the whole point — documentation alone didn't prevent the miss).
- The `/xtty:capture-research` colon slash the user asked for.
- Track the tooling without weakening the `.claude/` ignore for machine-local/generated files.
- One source of truth (skill body), with AGENTS.md as the rules anchor.

**Non-Goals:**
- The research-*doing* method (OSS cloning, multi-agent workflows, adversarial verification).
- A bootstrap/`make` step (the files are consumed in place — no reconstitution needed).
- Tracking the tool-generated `opsx`/`openspec-*` tooling.

## Decisions

### D1 — In-place tracking via `.gitignore` negation (not a tracked-source + bootstrap)

Track the files where they live, using a negation block. The repo's SwiftTerm pattern (track source + bootstrap into a gitignored tree) was considered and rejected here: these files are consumed in place by Claude Code, need no reconstitution, and a bootstrap step adds a fresh-clone failure mode for zero benefit. The cost of in-place tracking is that the blanket `.claude/` rule becomes a precise one (handled in D4).

The negation must re-include **each path level** — git cannot re-include a child of an ignored directory, so the directory itself must be ignored-by-contents (`dir/*`), not ignored-as-dir:

```gitignore
.claude/*
!.claude/commands/
.claude/commands/*
!.claude/commands/xtty/
!.claude/skills/
.claude/skills/*
!.claude/skills/xtty-*/
```

Result: `.claude/commands/xtty/**` and `.claude/skills/xtty-*/**` are tracked; `settings.local.json`, `scheduled_tasks.lock`, `commands/opsx/**`, and `skills/openspec-*/**` stay ignored.

### D2 — Skill flat, command nested (forced by the loader)

```
.claude/commands/xtty/capture-research.md      → /xtty:capture-research   (folder→colon, like opsx)
.claude/skills/xtty-capture-research/SKILL.md  → /xtty-capture-research + auto-trigger (flat — skills don't nest)
```

The user's `/xtty:capture-research` comes from the **command**; the **skill** carries the auto-trigger and is reachable at `/xtty-capture-research`. A nested `.claude/skills/xtty/` skill folder is impossible (D-findings), so the gitignore skill rule is a **`xtty-*/` prefix glob** (mirrors openspec's own `openspec-*` prefix) — future xtty skills are tracked by the same one line.

### D3 — Skill is the body; command is a thin launcher (DRY)

The skill holds the full checklist; the command is ~3 lines that invoke the skill. This avoids the two-copies-drift that hand-maintaining parallel bodies would cause (openspec tolerates duplicated command/skill bodies only because they're generated). The skill in turn **defers to AGENTS.md** for the conventions, so the rules live in exactly one canonical, tracked, every-session-loaded place.

### D4 — AGENTS.md carries the shared knowledge + the corrected convention

The auto-trigger only helps the local machine; the *forget-problem* is killed repo-wide in AGENTS.md (tracked + loaded every session). So AGENTS.md gains the capture-and-reconcile checklist (headlining verify-against-disk) and its Conventions line changes from "don't track `.claude/`" to "`.claude/` is gitignored **except** the committed `.claude/commands/xtty/` + `.claude/skills/xtty-*/` tooling." The skill points at this; AGENTS.md is the source of truth.

## Risks / Trade-offs

- **A `.gitignore` slip tracks a machine-local file** → mitigation: the negation is surgical (only `xtty`/`xtty-*` subtrees), and a `git check-ignore` verification step (tasks) asserts `settings.local.json` and `opsx`/`openspec-*` remain ignored before committing.
- **The blanket-rule loss confuses readers** → mitigation: an explanatory comment in `.gitignore` (mirroring the SwiftTerm comment style) + the AGENTS.md convention update.
- **Auto-trigger over-fires** → mitigation: a tight `description` scoped to "a research investigation/decision has settled or a change was archived," not any mention of research.
- **`.claude/` is per-machine** → the committed tooling helps this contributor across machines and is reviewable, but other contributors only benefit if they use Claude Code; the durable shared knowledge is therefore in AGENTS.md by design (D4).

## Open Questions

- ❓ None blocking. (The earlier symlink/bootstrap option is explicitly rejected in D1; the nested-skill option is ruled out by the loader findings in D2.)
