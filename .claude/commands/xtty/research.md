---
name: "XTTY: Research"
description: "Launch a source-research fan-out (clone → read → synthesize → critic → verify-by-effect → capture) as a per-invocation Workflow with model tiers per role, then hand off to xtty-capture-research"
category: Workflow
tags: [xtty, research, workflow, fan-out, source, orchestration]
---

Run a **source-research fan-out** for the question in `$ARGUMENTS`: clone the external sources, read them in parallel, synthesize across them, adversarially critique, verify the load-bearing claims by effect, then hand the settled result to `xtty-capture-research`.

Unlike the other three `xtty:*` launchers (`validate`/`investigate-ci`/`review`), the worker here is **not a standing agent** — it is a **per-invocation Workflow** whose stages are `agent()` calls (design D2). That means **no `Definition:` stamp, no delivery check, no babysitter/strand-recovery** — none of the agent-definition-lag concerns apply. This launcher documents the *recipe*; you (the main loop) author the fan-out's width and shape inline per question, because research shapes are heterogeneous (per-terminal / per-facet / per-repo / forensics) and too varied for one rigid script (D1).

If `$ARGUMENTS` is empty, ask the user for the research question before proceeding — the fan-out needs a subject.

## When to reach for this (defer to AGENTS.md)

**AGENTS.md → How to work here is the single source of truth** for the inline-vs-delegate boundary — this launcher only points to it. In short: source-heavy, multi-source research whose own noise (external clones, many-file reads, cross-source comparison) exceeds the ~12k-token subagent-inheritance floor is delegated to this fan-out; light work — reading an existing `research/` doc or a single-file lookup — stays **inline** in the main loop or a fork, not routed here.

## The staged recipe

Author these as a `Workflow` (calling this launcher is the explicit opt-in to the Workflow tool). Keep the readers a barrier'd fan-out; synthesis/critic serialize after.

1. **Explore / orchestrate** *(you — never delegated)* — shape the inquiry, decide the fan-out width and which sources to clone, hold the decision thread.
2. **Scout** *(optional)* — mechanical enumeration only (list the repos/casks/files to read).
3. **Readers (fan-out, ∥)** — each clones one source to `/tmp`, reads its build/internals machinery, and returns a **structured record** (use a schema). Run 8–12 in parallel as the question warrants.
4. **Synthesis** — cross-source compare + recommend, holding all the reader records.
5. **Critic (adversarial)** — refute the synthesis's claims, flag every unverified assertion, and name the **load-bearing unknowns**.
6. **Verify-by-effect** — close those unknowns by running the **real probes** (never a read-back). Default to running them yourself in the main loop (the orchestrator should see the evidence firsthand — as the `add-install-workflow` Release/quarantine/plist spikes were); escalate to a delegated Sonnet verify stage only when the probes are many or isolated (D5).
7. **Capture** — hand off to **`xtty-capture-research`** (invoke the Skill tool with `skill: xtty-capture-research`) to write the result into `research/` and reconcile the trackers. Do **not** re-implement the write-up tail — that capability is already committed (D6).

## Role → model tiering (D3)

Apply these as the per-`agent()` `model` / `effort` overrides in the Workflow. Consistent with the committed agents (validator/investigator = sonnet, openspec-critic = opus):

| Stage | Model · effort | Why this tier |
|---|---|---|
| explore / orchestrate | **Opus · xhigh** (main, never delegated) | shapes the inquiry, holds the decision thread — journey-value |
| scout *(optional)* | **Haiku · low** | pure mechanical enumeration |
| readers (fan-out) | **Sonnet · medium** | search/extract; understands build systems; cheap enough to run 8–12 ∥ |
| synthesis | **Opus · high** | holds all records, judges, designs |
| critic | **Opus · high→xhigh** | adversarial reasoning — the quality gate |
| verify-by-effect | **Sonnet · medium** (or main) | run probes + check; escalate to Opus only if the check needs judgment |
| capture | main + `xtty-capture-research` | shared-write trackers → main |

*(Fable 5 is intentionally unused — not an analytical-reasoning tier.)*

**AGENTS.md is the source of truth for the delegation boundary and the rules** — this command is just the launcher.
