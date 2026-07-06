# Design — harden-validator-delegation-trigger

## Context

`test-validation` already carries the delegation rule (scenario b: verify tasks that execute the suite are delegated; the apply loop consumes only the report). The `retire-metal-renderer` apply measured that rule failing: **0 autonomous delegations** across ~10 verify tasks; the Tier‑1 suite (`make test`, 4.3) and the full local matrix (6.1) ran inline, and delegation happened once only on an explicit user command. This is the "delegation drift" `add-test-validation-agent` pre-registered as the trigger condition for "per-task delegate markers."

Two facts, both confirmed empirically this session, fix the surface:

1. `openspec instructions apply --json` carries **neither** `context` **nor** `rules` from `config.yaml` (a distant rule cannot reach the apply loop); `openspec instructions tasks --json` carries `context` **and**, once populated, `rules` (probe: a `rules.tasks` entry surfaced verbatim). So `config.yaml` is a **propose-time** surface only.
2. The generic `/opsx:apply` skill models only *implement* tasks ("make the changes, tick the box") and is **not ours to edit**. The only delegation signal that survives to the apply loop is one that lives in the data the loop reads line-by-line: **the marked task in `tasks.md`**.

The failure concentrated precisely on the heavy tiers the agent is *for* (Tier‑1 suite, full matrix) while cheap checks (grep, one‑off launch, `openspec validate`) inlined harmlessly — so the fix is selective marking at a crisp boundary, not "delegate every verify task."

## Goals / Non-Goals

**Goals:**
- Put the delegation trigger **at the point of action** (the marked verify task line), so it survives the ~100k-token distance from `AGENTS.md` and the generic-apply-skill boundary.
- Seed the marker reliably at propose time (`config.yaml` `rules.tasks`).
- Draw one crisp boundary — iterate-inline vs validate-delegate — with a single source of truth (`AGENTS.md`), so `config.yaml` and the markers point to it rather than restating it.
- Make the fix live for the **already-open** changes, not only future proposals.

**Non-Goals:**
- No change to the agent's behavior or report contract (this is caller-side authoring, not agent execution).
- No edit to the generic `/opsx:apply` / `/opsx:propose` skills (not ours; the `tasks.md` marker is the mechanism that reaches them).
- No hard gate — the marker raises the delegation rate and removes the rationalization space; it does not (and cannot, given the generic skill) *force* delegation. The honest proof is by-effect (D6).
- No new capability, no `verification-harness` delta (nothing new is observable in the product).

## Decisions

### D1 — The marker syntax and the delegation boundary

Marker (in a verify task's text, adjacent to the trigger): **`⟶ xtty-test-validator (<tier/scope>)`**, e.g. `- [ ] 4.3 Verify ⟶ xtty-test-validator (Tier 1): make test is green …` or `- [ ] 6.1 Verify ⟶ xtty-test-validator (full local sweep): …`.

**Delegate (marker required)** — a verify task that runs any of:
- the **Tier‑1 XCUITest suite** (`make test`), or
- **any VM tier** (headless or graphics Tart rig), or
- an explicit **"full/acceptance matrix"** task (one that bundles multiple tiers as the change's acceptance gate).

**Inline (no marker)** — cheap checks that are fast, clean, and useful as immediate feedback while implementing:
- `make test-core` run for **iteration** (fast, view-free, clean output),
- one‑off `-UITestGridDump` app launches to read a dump field,
- `grep`/sweep checks, `make doctor`, `openspec validate`, `gh run watch`.

**Grey case — `make bench`:** a single app run, not the XCUITest suite; **inline-permitted on its own**, but if it appears inside a full-matrix acceptance task it rides with that task's delegation. Kept explicit so the boundary has no fuzz.

Rationale: this matches the measured cost/value gradient — the tiers that flood context and carry the acceptance judgment are marked; the tiers that give tight iterative feedback are not. Marking `make test-core` for iteration would spawn a VM-capable agent for a 1‑minute clean run — negative value.

Alternative rejected: **delegate every verify task.** Absurd for a grep; would breed marker fatigue and inline workarounds. The selective boundary is what keeps the marker credible.

### D2 — Seed the marker at propose time via `config.yaml` `rules.tasks`; defer to AGENTS.md for the boundary

Populate `config.yaml`'s `rules.tasks` (currently commented/empty) with a **short pointer**, e.g.: *"When authoring verify tasks, mark any task that runs the Tier‑1 XCUITest suite, a VM tier, or a full acceptance matrix with `⟶ xtty-test-validator (<tier>)` — see AGENTS.md → test-validation for the boundary. Cheap checks (test-core for iteration, greps, openspec validate) stay inline."*

It is a **pointer, not a restatement** — `AGENTS.md` remains the single source of the boundary, so the three surfaces (AGENTS.md rule, config rule, marker instances) cannot drift into three different boundaries. Empirically confirmed to surface in `openspec instructions tasks` once populated.

Fallback (should a future CLI version stop emitting `rules`): a compact equivalent line appended to `config.yaml`'s `context` block, which is *proven* to flow into task authoring (at the cost of being shown for all artifacts). The verify task (§tasks) checks that the populated `rules.tasks` actually surfaces before relying on it.

Alternative rejected: putting the authoring rule **only** in `AGENTS.md`. That is the surface that just failed; `config.yaml` is injected at the exact authoring moment, which `AGENTS.md` (read 100k tokens earlier) is not.

### D3 — The `tasks.md` marker is the load-bearing surface

`config.yaml` seeds the marker at propose; the **marker in `tasks.md`** is what carries the signal to apply, because (fact 1 above) apply reads neither `config.yaml` nor reliably re-reads the `AGENTS.md` rule against the loud generic-skill prompt, but it **does** read the task line it is about to tick. So the marker is not decoration — it is the only channel across the generic-skill boundary. This is why D5 (retrofit) matters: an open change whose tasks predate this convention gets no benefit until its tasks are marked.

### D4 — Name the two verbs (iterate vs validate) in the AGENTS.md rule

Amend the `AGENTS.md` test-validation rule to state the split explicitly: inline is *expected* for iterative feedback during implementation (the cheap tiers in D1); the agent is *required* for the delegate tiers in D1. Removing the unnamed conflation is what closes the rationalization ("I'm just running my verify tasks") that let the Tier‑1 run ride along with legitimate test-core iteration.

### D5 — Retrofit the open changes so the fix is live now

Add the D1 marker to the suite-executing verify tasks already written in `harden-churn-shell-readiness`, `add-xtty-test-image`, and `add-ci-pipeline` (mark only Tier‑1/VM/full‑matrix tasks; leave cheap checks unmarked). This makes the very next apply (likely `harden-churn-shell-readiness`) exercise the fix, and converts the "won't help already-open changes" limitation into a one-time edit. It changes neither the scope nor any requirement of those changes — only the authoring form of specific verify tasks.

### D6 — Verification is by-effect, and the change is HOLD-OPEN until it is captured

Primary bar (pre-registered, re-verify by effect — never a read-back that the marker text exists): **the next product-code change's apply delegates its Tier‑1/matrix verify tasks autonomously** — observable as an `xtty-test-validator` spawn for those tasks and the tasks ticked from the report's verbatim counts, with no user prompt. `harden-churn-shell-readiness`'s apply is the natural vehicle — it is genuine product code that needs a validation sweep anyway, so the trigger is real, not staged.

**Hold-open** (repo pattern — `add-ci-pipeline` stayed open pending its first CI run, `add-test-validation-agent` pending live-smoke): this change is implemented-but-open until the proof is captured. The proof executes during a *different* change's apply, so it cannot be ticked in this change's own apply session — the change stays open across the `harden-churn-shell-readiness` apply, then is ticked and archived.

**Sequencing dependency (proof validity):** this change must be applied **before** `harden-churn-shell-readiness` — its retrofit (D5) is what puts the markers into that change's tasks — then context is compacted, then `harden-churn-shell-readiness` is applied. Applying them in the other order tests nothing (no markers yet).

**Primed-observer caveat:** this change's *own* apply does not count as the proof — that session just authored the marker convention and is maximally primed; delegating there proves only the machinery. The valid observation is the post-compact `harden-churn-shell-readiness` apply; the cleaner the compaction (the less it foregrounds "we are testing delegation"), the stronger the proof. This is why a fully-isolated result is unattainable — the compaction summary carries some history — but the failure being fixed is *delegation not happening at all*, so an autonomous post-compact delegation (driven by the marker, the internalized convention, or both) is valid evidence of success; only an inline-anyway result is a clean failure.

Deliberately **not** a gratuitous marked task on this change (D1 boundary: mark only genuine Tier‑1/VM/matrix tasks — a docs-only change has nothing to validate; a proof-only marked task would undercut the boundary). And an optional `slim-agents-context`-style headless probe is dropped: a behavioral probe of a convention change is heavier than, and adds little over, observing the real next apply.

### D7 — A pre-tick self-check (belt-and-suspenders)

Because the marker is not a hard gate (D-non-goals), add a one-line self-check to the `AGENTS.md` rule: **before ticking a verify task that ran a suite, confirm the counts came from a validator report; if it was run inline, it must be a cheap/iteration case per the D1 boundary.** Cheap insurance against the residual that the generic apply skill still whispers "make the changes, tick the box."

## Risks / Trade-offs

- **[Marker rot — propose forgets to emit it]** → mitigated three ways: `config.yaml` `rules.tasks` at the authoring moment (D2), the "keeping a change coherent" checklist entry, and the retrofit (D5) proving the pattern in-repo. Residual: a proposal authored without reading either still misses it — caught at the coherence check.
- **[Three surfaces drift into three boundaries]** → mitigated by the deference chain: `AGENTS.md` is the sole boundary definition; `config.yaml` and the markers are pointers. Same pattern the agent already uses (defers to AGENTS.md for rules, packer/README for numbers).
- **[Over-marking → agent spawned for trivial runs]** → mitigated by D1's crisp inline list; `make test-core`-for-iteration and greps are explicitly unmarked.
- **[`config.yaml` `rules` stops surfacing on a future CLI]** → the verify task checks it surfaces; the `context`-block fallback (proven to flow) is documented in D2.
- **[The marker still isn't a hard gate]** → acknowledged (non-goal); D4 (name the verbs) + D7 (pre-tick self-check) raise adherence, and D6 measures whether it worked rather than assuming it. If the next apply still inlines a marked Tier‑1 task, that is a measured signal to escalate (e.g. a stronger apply-side mechanism), captured then — not pre-built now.
- **[Retrofitting open changes edits their artifacts]** → low risk: only the authoring form of specific verify tasks changes, no scope/requirement; each retrofit is one line per marked task.

## Migration Plan

1. `AGENTS.md` rule: add the iterate/validate boundary (D1/D4), the marker convention, and the pre-tick self-check (D7); add the marker item to the "keeping a change coherent" task-authoring checklist.
2. `config.yaml` `rules.tasks` pointer (D2); verify it surfaces in `openspec instructions tasks`.
3. `test-validation` spec delta (MODIFIED "Two documented spawn scenarios").
4. Retrofit the three open changes' suite-executing verify tasks (D5).
5. Validate; leave the by-effect verification (D6) to observe on the next product-code apply, and record the observation when it happens.

Rollback: revert the docs/config commit; no product code changes, so the tree rolls back cleanly and nothing downstream depends on the marker.

## Open Questions

- None blocking. Whether a hard apply-side gate is ever warranted depends on D6's outcome — deferred until there is measured evidence the marker + gradient are insufficient.
