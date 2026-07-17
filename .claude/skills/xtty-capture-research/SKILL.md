---
name: xtty-capture-research
description: Capture settled research/decisions into research/ and reconcile the related trackers. Use AFTER a research investigation or decision has settled, or a change has been archived/decided — to write it into research/ following the doc conventions, index it, reconcile the trackers (research/README.md, AGENTS.md Current status table/snapshot, HISTORY.md narrative, research/04-design/02-milestones.md), and verify against the actual repo state. NOT for doing research — only for capturing + reconciling what has already settled.
metadata:
  author: xtty
  version: "1.2"
---

# Capture research & reconcile trackers

Capture a settled finding/decision into `research/` and bring every tracker back in sync.

**AGENTS.md is the source of truth** for the conventions — this skill is the runnable checklist. Defer to AGENTS.md (**How to work here** + **Keeping a change coherent**) for the rules; don't restate or fork them here. Use this when a spike/investigation concludes, a decision is made, or a change is archived. Do **not** use it to *do* research.

## Checklist

1. **Place the doc.** Write the finding into the right `research/` subfolder (`00-overview` / `01-terminals` / `02-internals` / `03-analysis` / `04-design`). Follow the research-doc conventions: a **Provenance** note (date + how produced), a **Sources** list, and ✅/❌/❓ confidence tags. For an *evolving* decision, **add a dated addendum — do not rewrite** the original, and add a forward-pointer from the superseded section.

   **Depth bar** (AGENTS.md "Capture depth" is the rule; exemplar: `research/03-analysis/local-network-privacy-forensics.md`). If the capture has **measured claims or retired theories**, check it contains:
   - [ ] the **mechanism/internals** (how it actually works, with evidence — not just the conclusion)
   - [ ] **reproducible probes** — exact commands, what each proves *and cannot prove*, incl. dead instruments
   - [ ] the **retired-theory fates table** — each ❌ next to the experiment that killed it
   - [ ] **re-verify by effect** — how a future reader re-checks the headline claim (never syntax/read-back)
   - [ ] a **reusable guideline** if the finding generalizes; **artifact pointers** always

   Lightweight captures (landscape/comparison, no measurements) skip the bar.

2. **Index it.** Add or update the one-line entry in `research/README.md`.

3. **Reconcile the trackers** (the step that gets forgotten) — **bounded in AGENTS.md, narrative in HISTORY.md**:
   - **`AGENTS.md` → Current status**: update the change's **table row** (state + one-liner + detail pointer; state it accurately: implemented / archived / decided / pending) and refresh the **snapshot paragraph** if counts/envelope/milestone position moved. (The established-specs list is not cached in AGENTS.md — step 4 verifies it against `ls openspec/specs/`.) **Narrative paragraphs never go here** — a status entry is one table row.
   - **`HISTORY.md`**: **append the full narrative** under the matching section with a dated lead-in (append-only — never rewrite existing entries).
   - If the work settled a **refutation** worth never re-litigating, add a one-liner (with its conclusion) to AGENTS.md's **Learned refutations** list.
   - **`research/04-design/02-milestones.md`** → the milestone's state tag + bullets.

4. **Verify against disk** (the step that catches a stale tracker — e.g. a change still marked "pending archive" after it was archived):
   ```
   openspec list                  # active changes   → must match the Current-status open-changes table
   ls openspec/changes/archive/   # archived changes → must be marked archived in the trackers
   ls openspec/specs/             # established specs → AGENTS.md carries no cached list; disk is the truth
   ```
   Fix any place a tracker disagrees with reality.

5. **Commit only when asked** (repo rule). Conventional Commit scope: `docs(research): …` for research docs, `docs(openspec): …` for change/spec artifacts. End with the `Co-Authored-By` trailer.

## Guardrails

- Never rewrite archived history — use a dated addendum for an evolving decision. `HISTORY.md` is append-only.
- `.claude/` is gitignored **except** this committed tooling (`.claude/commands/xtty/`, `.claude/skills/xtty-*/`) — don't expect other `.claude/` files to be tracked.
- Defer to AGENTS.md for the rules; if anything here conflicts with AGENTS.md, AGENTS.md wins (update it, don't fork the rules into this skill).
