## Why

This session surfaced a recurring failure: after research settles, the *capture + reconcile* step gets forgotten — the milestone tracker stayed stale ("pending archive") and was only fixed when the user asked "did you reconcile the milestone yet?" AGENTS.md already says "Write up research when done" and "Keep progress current," so the problem isn't missing documentation — it's the lack of a **triggered checkpoint** and a **verify-against-disk** step that would catch the staleness. A committed, auto-triggering Claude Code skill (plus a slash command) fixes the trigger; an AGENTS.md checklist fixes the shared, every-session knowledge.

## What Changes

- **Add a committed `xtty-capture-research` skill** (auto-triggers when a research investigation/decision settles or a change is archived) that walks the capture-and-reconcile checklist and **defers to AGENTS.md** for the rules (no duplicated, drift-prone content). Its headline step is **verify-against-disk** (`openspec list` / `ls changes/archive/` / `ls specs/`) — the step that would have caught the stale tracker.
- **Add a thin `/xtty:capture-research` command** that launches the skill — present only to give the colon-namespaced slash; the skill remains the single source of truth.
- **Track this tooling in git** via a `.gitignore` exception: the project's committed `.claude/commands/xtty/**` + `.claude/skills/xtty-*/**` become tracked, while machine-local Claude files (`settings.local.json`, `scheduled_tasks.lock`) and the tool-generated `opsx`/`openspec-*` tooling stay ignored.
- **Update AGENTS.md**: document the capture-and-reconcile workflow (including verify-against-disk) and replace the blanket "don't track `.claude/`" convention with the precise tracked-tooling exception.
- **Out of scope:** the research-*doing* method (cloning OSS, multi-agent workflows, adversarial verification) — this tooling is narrowly the *capture + reconcile* back half.

## Capabilities

### New Capabilities

- `research-capture`: committed Claude Code tooling and the documented workflow for capturing settled research into `research/` and reconciling the related trackers, verified against the actual repository state.

### Modified Capabilities

(none — AGENTS.md and `.gitignore` are repo documentation/config, not spec capabilities.)

## Impact

- **New tracked files:** `.claude/commands/xtty/capture-research.md` (launcher), `.claude/skills/xtty-capture-research/SKILL.md` (the checklist + auto-trigger).
- **`.gitignore`:** a 7-line negation block (`.claude/*` + re-include the two `xtty` tooling subtrees).
- **`AGENTS.md`:** the capture-and-reconcile checklist + the corrected `.claude/` tracking convention.
- **No app/code impact:** this is contributor/dev tooling; no `XttyCore`/App change, no `verification-harness` (the assertion is `git check-ignore` + file presence, not the XCUITest harness).
- **Bootstrap note:** `.claude/` tooling is consumed in place (tracked), so no setup step is required — unlike the SwiftTerm clone, this does not need `make` reconstitution.
