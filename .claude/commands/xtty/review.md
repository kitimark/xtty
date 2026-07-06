---
name: "XTTY: Review"
description: "Review an OpenSpec change (or the active change-set) for coherence via the xtty-openspec-critic agent — isolate the rule-checking/disk-drift/cross-change noise and return a fixed findings verdict"
category: Workflow
tags: [xtty, openspec, coherence, review, critic, agent]
---

Spawn the **`xtty-openspec-critic`** agent (invoke it by name — this is a subagent invocation, not the Skill tool) to review the referenced change for coherence and return its fixed findings report.

Forward `$ARGUMENTS` to it verbatim as the review scope: a change name, or `all active` for the whole open change-set. If `$ARGUMENTS` is empty, default to `all active` (or ask the user which change to review if that's ambiguous) — the agent needs a scope.

Do not run the coherence checks yourself in this session — the rule-by-rule grepping, the `openspec/specs` diffing for MODIFIED blocks, and the cross-change comparison are exactly the noise the agent exists to absorb. `openspec validate` (the cheap mechanical gate) is fine to run inline; a **full coherence review** is what the agent is for. Just spawn it and relay its report back.

**Delivery check:** the report's first line must read `Definition: v1 (2026-07-07)` (the stamp in `.claude/agents/xtty-openspec-critic.md` — compare against the file if in doubt). A missing or older stamp means the harness served a stale cached definition (agent-definition edits propagate to spawns with unpredictable lag — measured on the sibling agents: stale 63 s after an edit, fresh ~40 min later; a fresh session always serves current) — treat that as a blocker finding, not a valid run.

**No strand-recovery needed** (unlike `/xtty:validate`): this agent runs only short read-only `openspec`/`git`/`grep` calls — there is no VM boot, no long sweep, nothing to strand or resume. If it returns a `blocked-prerequisite` (e.g. an artifact isn't created yet, or an established spec is unreadable), relay that verbatim; it is a one-time setup issue for the human, not something to retry blindly.

**AGENTS.md is the source of truth for the two spawn scenarios and the validate-vs-review boundary** (running `openspec validate` stays inline; a *full coherence review* is delegated here) — this command is just the launcher.
