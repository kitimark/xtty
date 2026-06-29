---
name: xtty-capture-research
description: Capture settled research/decisions into research/ and reconcile the related trackers. Use AFTER a research investigation or decision has settled, or a change has been archived/decided — to write it into research/ following the doc conventions, index it, reconcile the trackers (research/README.md, AGENTS.md Current status, research/04-design/02-milestones.md), and verify against the actual repo state. NOT for doing research — only for capturing + reconciling what has already settled.
metadata:
  author: xtty
  version: "1.0"
---

# Capture research & reconcile trackers

Capture a settled finding/decision into `research/` and bring every tracker back in sync.

**AGENTS.md is the source of truth** for the conventions — this skill is the runnable checklist. Defer to AGENTS.md (**How to work here** + **Keeping a change coherent**) for the rules; don't restate or fork them here. Use this when a spike/investigation concludes, a decision is made, or a change is archived. Do **not** use it to *do* research.

## Checklist

1. **Place the doc.** Write the finding into the right `research/` subfolder (`00-overview` / `01-terminals` / `02-internals` / `03-analysis` / `04-design`). Follow the research-doc conventions: a **Provenance** note (date + how produced), a **Sources** list, and ✅/❌/❓ confidence tags. For an *evolving* decision, **add a dated addendum — do not rewrite** the original, and add a forward-pointer from the superseded section.

2. **Index it.** Add or update the one-line entry in `research/README.md`.

3. **Reconcile the trackers** (the step that gets forgotten):
   - **`AGENTS.md`** → the **Current status** bullet for the milestone/change (state it accurately: implemented / archived / decided / pending), the **established-specs** list, and the **Current open changes / Next** line.
   - **`research/04-design/02-milestones.md`** → the milestone's state tag + bullets.

4. **Verify against disk** (the step that catches a stale tracker — e.g. a change still marked "pending archive" after it was archived):
   ```
   openspec list                  # active changes   → must match "Current open changes"
   ls openspec/changes/archive/   # archived changes → must be marked archived in the trackers
   ls openspec/specs/             # established specs → must match the AGENTS list
   ```
   Fix any place a tracker disagrees with reality.

5. **Commit only when asked** (repo rule). Conventional Commit scope: `docs(research): …` for research docs, `docs(openspec): …` for change/spec artifacts. End with the `Co-Authored-By` trailer.

## Guardrails

- Never rewrite archived history — use a dated addendum for an evolving decision.
- `.claude/` is gitignored **except** this committed tooling (`.claude/commands/xtty/`, `.claude/skills/xtty-*/`) — don't expect other `.claude/` files to be tracked.
- Defer to AGENTS.md for the rules; if anything here conflicts with AGENTS.md, AGENTS.md wins (update it, don't fork the rules into this skill).
