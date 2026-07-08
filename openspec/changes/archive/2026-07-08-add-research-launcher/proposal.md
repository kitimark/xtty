## Why

Source-heavy research — cloning OSS repos to `/tmp`, reading their build/internals machinery, comparing across sources, then verifying by effect — has recurred across ~7–9 changes (distribution, CI, install, confirm-close, VM-repro, p4/p4b/p6, the 12-agent `add-install-workflow` sweep), each time **hand-authored inline** as an ad-hoc multi-agent Workflow. There is no committed, repeatable entry point, so the role→model tiering, the adversarial-critic + verify-by-effect stages, and the delegation boundary are re-decided every time. The settled design (`research/03-analysis/dev-workflow-agent-orchestration.md` §11 — the T3 revisit) established that this recurring pattern now clears the project's reactive-build bar and should be formalized as a **Workflow launcher** (not the agent roster T1 refuted), completing the doc's named gap: *"explore/research… has no `xtty-*` launcher+worker."* This change builds that launcher.

## What Changes

- **New committed `/xtty:research` launcher** (`.claude/commands/xtty/research.md`) — the 4th member of the `xtty-*` launcher family (after `validate`/`investigate-ci`/`review`), but whose **worker is a Workflow, not a standing agent**. It carries the reusable, durable parts of the pattern: the role→model tiering, the staged shape (explore → readers → synthesis → critic → verify → capture), the delegation boundary, and the hand-off to the existing `xtty-capture-research` tail. The **fan-out width/shape stays main-authored** per question (research shapes are heterogeneous), so the launcher documents the recipe rather than rigidly scripting it.
- **Role → model tiering** baked into the recipe, consistent with the committed agents (`validator`/`investigator` = sonnet, `openspec-critic` = opus): main orchestrator **Opus/xhigh** (never delegated) · optional scout **Haiku/low** · source readers **Sonnet/medium** (fan-out) · synthesis **Opus/high** · critic **Opus/high→xhigh** · verify-by-effect **Sonnet/medium or main** · capture main + `xtty-capture-research`.
- **AGENTS.md → How to work here**: a new delegation rule for source-research fan-outs (mirroring the validate/investigate/review inline-vs-delegate boundary — source-heavy multi-source research above the ~12k-token inheritance floor is delegated to a `/xtty:research`-launched Workflow; light existing-doc reads / single-file lookups stay inline in main/fork).
- **AGENTS.md → Conventions**: add the `/xtty:research` command to the committed-tooling exception list.
- **No new `.gitignore` exception** (the existing `!.claude/commands/xtty/` already tracks it) and **no new standing agent** (so no agent-definition-lag / `Definition:`-stamp concern — the worker is a Workflow).

## Capabilities

### New Capabilities

- `research-orchestration`: the committed source-research delegation launcher — the *doing* phase of research (multi-agent source-clone fan-out with a defined model tiering, an adversarial critic, verify-by-effect, and a delegation boundary), explicitly the counterpart of `research-capture`'s *write-up* phase (which lists the research-doing method as out of scope).

### Modified Capabilities

<!-- none — research-capture already scopes the research-doing method OUT; the /xtty:research command is covered by the existing .claude/commands/xtty/ gitignore exception, so no research-capture requirement changes -->

## Impact

- **New file** `.claude/commands/xtty/research.md` (committed via the existing `!.claude/commands/xtty/` exception).
- **`AGENTS.md`** — one *How to work here* delegation rule + the *Conventions* tooling-exception line.
- **`research/03-analysis/dev-workflow-agent-orchestration.md`** — on completion, flip §11's status from "decided, not yet built" to built (a reconcile step, not new prose).
- **No product/app/`XttyCore`/test code, no `verification-harness` delta** — dev-tooling only (parallels `add-openspec-critic-agent` / `add-ci-investigator-agent` / `add-test-validation-agent`, each of which added its own capability spec with no harness delta).
- **No new external dependency**; reuses the existing Workflow tool + the committed `xtty-capture-research` tail.
