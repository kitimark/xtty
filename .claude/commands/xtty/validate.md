---
name: "XTTY: Validate"
description: "Run xtty's test-suite validation tiers (core/local/headless-VM/graphics-VM) via the xtty-test-validator agent, isolating the build/VM noise from this session"
category: Workflow
tags: [xtty, test, validation, vm, agent]
---

Spawn the **`xtty-test-validator`** agent (invoke it by name — this is a subagent invocation, not the Skill tool) to run the requested validation tiers and return its fixed verdict report.

Forward `$ARGUMENTS` to it verbatim as the requested tiers/runs (e.g. "tier 0 only", "full sweep", "headless x2"). If `$ARGUMENTS` is empty, say nothing about tiers — the agent applies its own documented default.

Do not run any test/build/VM commands yourself in this session — that noise is exactly what the agent exists to absorb. Just spawn it and relay its report back.

**Delivery check:** the report's first line must read `Definition: v4 (2026-07-06)` (the stamp in `.claude/agents/xtty-test-validator.md` — compare against the file if in doubt). A missing or older stamp means the harness served a stale cached definition (definitions are cached at session registration; edits need a fresh session) — treat that as a blocker finding, not a valid run.

**Babysitter protocol (the caller's half — a stranded sweep is a measured failure mode):** after spawning, note the artifacts dir the agent uses (`~/Downloads/xtty-vm-poc/artifacts/<run-name>/`). If the agent's task ends WITHOUT a fixed-skeleton report (an interim "waiting…" message means it parked), do not respawn: check `ps` for live sweep processes (`xcodebuild|make test|tart run`) and the artifacts dir's `ledger.log`/`REVIEW.md` for where it got to; wait for any live tier process to exit; then **resume the same agent via SendMessage** with: what completed while it was parked (log paths, verbatim tail), any caller descope, and an instruction to finalize per its definition. Record every resume in the run's REVIEW.md — a resurrected run must be distinguishable from a clean one. Known side effect: a resume drops a per-call model override (the resumed half runs on the session model), so model-comparison runs are only valid if they complete without a resume.

**AGENTS.md is the source of truth for the two spawn scenarios and the deference chain** — this command is just the launcher.
