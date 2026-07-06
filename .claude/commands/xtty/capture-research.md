---
name: "XTTY: Capture Research"
description: "Capture settled research into research/ and reconcile the trackers (README, AGENTS, milestones), verified against the repo state"
category: Workflow
tags: [xtty, research, capture, reconcile, trackers]
---

Run the **`xtty-capture-research`** skill — invoke the Skill tool with `skill: xtty-capture-research`.

It walks the capture-and-reconcile checklist: write the settled research/decision into the right `research/` subfolder (Provenance + Sources + ✅/❌/❓ conventions; a **dated addendum**, not a rewrite, for an evolving decision) — **to the capture-depth bar** when the finding has measured claims or retired theories (mechanism, reproducible probes, retired-theory fates, re-verify-by-effect, guideline if it generalizes) → index it in `research/README.md` → reconcile the trackers (`AGENTS.md` Current-status **table row + snapshot** — bounded, never a narrative paragraph — plus the full narrative **appended to `HISTORY.md`** + `research/04-design/02-milestones.md`) → **verify against disk** (`openspec list` · `ls openspec/changes/archive/` · `ls openspec/specs/`) → commit only when asked.

**AGENTS.md is the source of truth for the rules** — the skill defers to it. This command is just the launcher.
