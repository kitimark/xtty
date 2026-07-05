---
name: "XTTY: Validate"
description: "Run xtty's test-suite validation tiers (core/local/headless-VM/graphics-VM) via the xtty-test-validator agent, isolating the build/VM noise from this session"
category: Workflow
tags: [xtty, test, validation, vm, agent]
---

Spawn the **`xtty-test-validator`** agent (invoke it by name — this is a subagent invocation, not the Skill tool) to run the requested validation tiers and return its fixed verdict report.

Forward `$ARGUMENTS` to it verbatim as the requested tiers/runs (e.g. "tier 0 only", "full sweep", "headless x2"). If `$ARGUMENTS` is empty, say nothing about tiers — the agent applies its own documented default.

Do not run any test/build/VM commands yourself in this session — that noise is exactly what the agent exists to absorb. Just spawn it and relay its report back.

**AGENTS.md is the source of truth for the two spawn scenarios and the deference chain** — this command is just the launcher.
