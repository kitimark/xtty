# Harden the test-validation delegation trigger (author verify tasks to delegate)

## Why

The `test-validation` capability already mandates that suite-executing verify tasks are delegated to the `xtty-test-validator` agent (scenario b), so execution noise stays out of the main session — but the `retire-metal-renderer` apply (2026-07-06) measured that rule failing in practice: across ~10 verify tasks the main session delegated **zero** times autonomously and once only on an explicit user request, running the Tier‑1 XCUITest suite (`make test`, task 4.3) and the full local matrix (task 6.1) inline — flooding the context with exactly the build/test output the agent exists to absorb.

Root cause is an **affordance failure at the point of action**, not a missing rule (the same class the v4 subagent forensics named for the stranding bug). Three mechanisms, one confirmed empirically this session:

- The delegation rule lives in `AGENTS.md` (loaded at session start); at apply time the loud, proximate instruction is the generic `/opsx:apply` skill ("make the changes, tick the box"), which models only *implement* tasks and has no concept of a *delegate* task. We cannot edit that generic skill.
- The verify task text carries the wrong verb: `4.3 Verify: make test is green` invites `make test` inline; the "delegate this" instruction is nowhere near the trigger. **No open change's tasks.md carries any delegation marker** (measured: 0).
- The rule names only one activity ("validation is delegated") and never distinguishes **iterate** (fast inline feedback while coding — `make test-core`, one‑off launches) from **validate/accept** (the acceptance sweep). Under implementation momentum the heavy Tier‑1 run got swept along with legitimate test‑core iteration.

The fix was **pre-registered**: `add-test-validation-agent` deferred "per-task delegate markers (only if delegation drift appears)." This session is that drift. And the correct surface is now proven: `openspec instructions apply` does **not** carry `config.yaml`'s `context`/`rules` (so a distant rule can't reach the apply loop), while a populated `config.yaml` `rules.tasks` **does** surface at task-authoring time — so the marker can be seeded at propose and, once written into `tasks.md`, is the one signal that survives to the apply loop the generic skill drives.

## What Changes

- **Define the delegation boundary and the per-task marker** in `AGENTS.md`'s test-validation rule: name the **iterate (inline) vs validate (delegate)** split, and require that any verify task running the **Tier‑1 XCUITest suite (`make test`), any VM tier, or a full acceptance matrix** be authored with a `⟶ xtty-test-validator (<tier/scope>)` marker; cheap checks (`make test-core` for iteration, one‑off `-UITestGridDump` launches, greps, `make doctor`, `openspec validate`) stay inline. Add a lightweight **pre‑tick self-check** (a suite-running verify task's counts must come from a validator report, or the inline run must be justified as a cheap/iteration case).
- **Seed the marker at propose time** via `openspec/config.yaml` `rules.tasks` — a short instruction to author suite-executing verify tasks with the marker, **deferring to `AGENTS.md` for the boundary** (no restatement, so the boundary has a single source of truth). Confirmed to surface in `openspec instructions tasks`.
- **Add the marker to the "keeping a change coherent" task-authoring checklist** in `AGENTS.md` so propose emits it and coherence checks catch its absence.
- **Retrofit the currently-open changes** — mark the suite-executing verify tasks already written in `harden-churn-shell-readiness`, `add-xtty-test-image`, and `add-ci-pipeline` — so the fix is live for the **next** apply, not only future proposals.
- **`test-validation` spec delta**: strengthen the "Two documented spawn scenarios" requirement so the delegation half names the marker convention and the iterate/validate boundary, with scenarios for a marked verify task and for the inline-permitted cheap tier.
- **Verify by effect, hold-open** (primary): this change is implemented-but-open until the proof is captured — on the next product-code apply (`harden-churn-shell-readiness`, which needs a real sweep), its marked verify task must trigger an **autonomous** `xtty-test-validator` spawn (ticked from the report), on a **compacted** context, with no user prompt. Sequencing is load-bearing: apply this change first (its retrofit marks `harden-churn-shell-readiness`'s tasks) → compact → apply `harden-churn-shell-readiness`. An inline-anyway result is a clean failure that justifies a stronger apply-side gate (a follow-up), not a silent patch.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `test-validation`: the "Two documented spawn scenarios" requirement's delegation half (scenario b) gains the **per-task delegation marker** convention and the **iterate-vs-validate boundary** — the observable contract that suite-executing verify tasks are marked for delegation and ticked from the agent's report, while cheap checks stay inline.

## Impact

- **Docs / workflow (no product code):** `AGENTS.md` (the test-validation rule + the "keeping a change coherent" task-authoring checklist); `openspec/config.yaml` (`rules.tasks`, currently commented/empty).
- **Open changes retrofitted:** `openspec/changes/harden-churn-shell-readiness/tasks.md`, `openspec/changes/add-xtty-test-image/tasks.md`, `openspec/changes/add-ci-pipeline/tasks.md` — marker added only to the Tier‑1/VM/full‑matrix verify tasks (no scope or requirement change to those changes).
- **Spec:** `openspec/specs/test-validation/spec.md` (one MODIFIED requirement, merged at archive).
- **Not affected:** the agent definition (`.claude/agents/xtty-test-validator.md`) — the trigger is a *caller-side* authoring concern, not an agent-behavior one; the launcher; `verification-harness` (no new product-observable behavior); the acceptance envelope / `packer/README.md` numbers.
- **Deferred / out of scope:** editing the generic `/opsx:apply` or `/opsx:propose` skills (not ours to own; the marker in `tasks.md` is the mechanism that reaches the generic loop instead); ad-hoc "run the tests" chat requests (already covered by spawn scenario (a) / the `/xtty:validate` launcher).
