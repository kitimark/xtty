---
name: "XTTY: Investigate CI"
description: "Investigate a failed xtty CI run via the xtty-ci-investigator agent — isolate the log/xcresult/attachment noise and return a fixed verdict classifying each failure against the CI expected-difference matrix"
category: Workflow
tags: [xtty, ci, github-actions, investigate, agent]
---

Spawn the **`xtty-ci-investigator`** agent (invoke it by name — this is a subagent invocation, not the Skill tool) to investigate the referenced failed CI run and return its fixed verdict report.

Forward `$ARGUMENTS` to it verbatim as the run reference (a run URL or id, optionally a job link). If `$ARGUMENTS` is empty, ask the user which run to investigate (a URL or id) before spawning — the agent needs a specific run.

Do not run any `gh`/`xcrun` investigation commands yourself in this session — that log/result-bundle noise is exactly what the agent exists to absorb. Just spawn it and relay its report back.

**Delivery check:** the report's first line must read `Definition: v1 (2026-07-06)` (the stamp in `.claude/agents/xtty-ci-investigator.md` — compare against the file if in doubt). A missing or older stamp means the harness served a stale cached definition (agent-definition edits propagate to spawns with unpredictable lag — measured on the sibling validator: stale 63 s after an edit, fresh ~40 min later; a fresh session always serves current) — treat that as a blocker finding, not a valid run.

**No strand-recovery needed** (unlike `/xtty:validate`): this agent runs only short read-only `gh`/`xcrun` calls — there is no VM boot, no long sweep, nothing to strand or resume. If it returns a `blocked-prerequisite` (e.g. it can't fetch the run, or `xcresulttool` output drifted), relay that verbatim; it is a one-time setup/environment issue for the human, not something to retry blindly.

**AGENTS.md is the source of truth for the two spawn scenarios and the watch-vs-investigate boundary** (watching a run with `gh run watch` stays inline; *investigating* a red run is delegated here) — this command is just the launcher.
