## Context

The `coherence-review` capability delegates full coherence review to the committed Opus `xtty-openspec-critic` agent (conformance: rulebook + disk-drift; never reads product source). This change was **dogfooded through two rounds of its own tri-pass** during authoring, which is the source of most decisions below: Pass A (conformance) stayed clean and blind to soundness; Pass B (Codex/GPT) and Pass C (inline Opus soundness) each caught real feasibility bugs, and round 2 *fact-checked and refuted several plausible round-1 fixes* against the actual plugin source — the corrections here are the survivors.

Fact-checked properties of the installed Codex plugin (`~/.claude/plugins/cache/openai-codex/codex/<v>/`):
- The `status` subcommand returns **no `ready` field** and succeeds even when Codex is uninstalled/unauthenticated. The **`setup --json`** subcommand emits `ready = node.available && codex.available && auth.loggedIn` **and the individual fields**; it connects to the Codex app-server (may block/err in a headless env).
- The review **input is the full diff** of the resolved git target; **focus text is prompt guidance, not a path filter** (the template even tells Codex to report issues outside the focus).
- The `review-output` schema requires top-level `verdict/summary/findings/next_steps` and per-finding `severity/title/body/file/line_start/line_end/confidence/recommendation` (**no `line`**, `additionalProperties:false`).
- Invocation is via a **version-pinned** script path; `${CLAUDE_PLUGIN_ROOT}` is unset in a non-plugin project command; the command is `disable-model-invocation: true` (user-triggered by design).

Binding refutations: **`run_in_background` strands subagents**; **don't pre-build speculative dev-workflow machinery** (n≥several, provably under-done); **agent-definition edits reach spawns with unpredictable lag**.

## Goals / Non-Goals

**Goals:** a repeatable, terminating cross-model review (conformance ∥ two-model soundness) with a union ledger, a bounded fix→re-review loop, and **detectable** degradation; a critic hardened to fact-check *existing-code* claims.

**Non-Goals:** not per-edit; not a new standing agent (Pass C inline); not literal model agreement (gate = findings resolved); not a claim that Pass 4 catches design-*ownership* soundness (it does not — D6); no product-code / `verification-harness` change.

## Decisions

### D1 — New `cross-model-review` capability + a `coherence-review` MODIFY
Orchestrator + fix-loop is a new capability (the loop *edits* artifacts — `coherence-review` is observe-only); the code-accuracy pass MODIFIES the critic.

### D2 — Orchestration in the main loop, not a subagent
The loop drives a detached Codex call and edits artifacts between rounds; a subagent owning Codex hits the strand refutation. `/xtty:cross-review` is a main-loop protocol; the passes stay observe-only.

### D3 — Tri-pass on the real schema; consensus is a heuristic, not a mechanical join
- **Pass A** — Opus critic (conformance, + code-accuracy D6). **Pass B** — Codex/GPT soundness. **Pass C** — inline Opus soundness, **emitting the real `review-output` schema** (top-level `verdict/summary/findings/next_steps`; per-finding `severity/title/body/file/line_start/line_end/confidence/recommendation`).
- **Consensus is a heuristic confidence signal, not a "defined join."** The common schema makes B and C outputs *comparable*, but two differently-modeled reviewers diverge on title text, file attribution (a bug can be filed under `design.md`, the spec, or a product file), and line ranges — so matching "same finding" is an **irreducibly semantic judgment** made by the main-loop Opus. Flag likely-consensus findings as higher-confidence; do not claim a mechanical join.
- **Async-join:** launch B in the background, run A + C as subagents, **await B's re-invoke before merging** (concurrent passes, barrier merge).

### D4 — Convergence: bounded, escalated, audited; one launch authorizes the bounded spend
A round runs A∥B∥C; the caller adjudicates each finding **fix** or **dismiss-with-recorded-rationale**, applies fixes, re-runs. **Converged** ⇐ zero unresolved actionable findings from any pass. Bound **N = 2 rounds**; on the bound, **escalate the residual to the human** (who MAY authorize continuation — as happened here). **Spend model:** a single user launch of `/xtty:cross-review` **authorizes the whole bounded run** (up to N Pass-B invocations); the loop does **not** re-prompt per round, but a *new* review requires a *new* user launch — this resolves the "auto-fires paid Codex in rounds 2..N" contradiction while preserving the human-initiated-spend intent. The orchestrator SHALL **surface the full ledger — every finding, resolution, and dismissal rationale — to the human on every converged run**, not only at the bound.

### D5 — Codex mechanics (portable, scoped, detectably-degrading) — all four fact-checked
- **Locate:** glob `~/.claude/plugins/cache/openai-codex/codex/*/scripts/codex-companion.mjs`, pick the highest version by **semver/numeric** comparison (not lexical — `1.0.10 > 1.0.6`), **fail loud** if none.
- **Scope by precondition, not focus text:** focus text does **not** scope the review (the companion reviews the whole target diff). So **require the named change to be the sole repository diff** — the sole *dirty* change (working-tree), or the sole HEAD commit (`--base`) — and **assert that precondition before launching Pass B**; if unmet, do **not** run Pass B repo-wide (report the unmet precondition). With several changes open, this is the only enforceable isolation.
- **Degrade on `setup --json` individual fields (not `status`, which has no `ready`):** skip Pass B **only** on a positively-identified **auth absence** (`node.available && codex.available && auth.loggedIn == false`) → label the run **single-model**. **Missing node/codex, a probe error, indeterminate auth, or a `setup` timeout** (it connects to the app-server and can block in headless) are **misconfigurations → surfaced hard**, never a silent skip. This makes the unavailable-vs-broken invariant actually implementable.
- **User-initiated:** the direct Bash call bypasses `disable-model-invocation`, so `/xtty:cross-review` is human-launched only (D7 marker is a *gate*, not an apply-loop auto-delegation).

### D6 — Critic code-accuracy pass (Pass 4) — honest scope, axis reconciled
Extract claims about **existing** symbols (`` `Type.field` ``, `` `File.swift` ``, `"mirrors `X`"`) and grep source: an **existing** symbol absent/contradicted ⇒ BLOCKER; fuzzy/unlocatable ⇒ REVIEW. It **does not** catch a misplaced *new* field (R5 exempts to-be-created code — exactly what blinds it to the motivating `XttyConfigSet` bug), so that ownership class stays a **cross-model** catch. **Axis reconciliation:** Pass 4 has the critic read product source, which narrows the "critic = conformance, never reads source" split the premise leans on; this is defensible because it fact-checks a *stated existing-symbol claim* (a bounded factual check: "does the design's claim match the code?"), **not** open-ended code soundness ("is the approach right?") — the AGENTS.md two-axes framing SHALL state this explicitly so it stays honest. Bump `Definition: v4`, repair the launcher stamp **v1 → v4**, and teach the critic's Pass-1 marker check the `⟶ xtty-cross-review` substitute.

### D7 — Mechanical gate; the marker is a human-launched gate
Scoped **mechanically** to changes touching **product code, a spec delta beyond docs/tooling, or the review/verification/CI tooling itself** (this last clause is load-bearing: this session proved a pure-tooling change benefits, so "product code only" would wrongly exclude it). Purely mechanical changes (docs/trackers/renames) stay single-agent-critic. **Honest framing:** this is *most substantive changes*, not a rare minority ("has a `design.md`" is ~100% and was never a gate); cost is bounded by running **once** and by degrade. The `⟶ xtty-cross-review` change-tail marker is a **human-launched gate** — like `⟶ archive-ritual`, a procedure pointer, **not** an apply-loop auto-delegation: on reaching it, `/opsx:apply` does not auto-fire Codex; the human runs `/xtty:cross-review`. This keeps the spend user-initiated.

### Verification approach (by-effect + adversarial-env, non-vacuous)
Dev-workflow tooling. The two riskiest claims (portable resolution, detectable degrade) manifest only in a *different* environment / after a version bump, so verification MUST exercise them adversarially **against the real `setup` probe** (not `status`, or the test passes vacuously): (a) unset auth → `setup.ready==false` with `auth.loggedIn==false` → skip labeled single-model; (b) hide the `codex` binary → `codex.available==false` → **hard error surfaced**, not skipped; (c) confirm semver-correct resolution independent of installed version; (d) confirm the sole-diff precondition holds with several changes open. No `verification-harness` delta.

## Risks / Trade-offs

- **R1 — Non-termination/thrash.** → gate on *unresolved* findings; dismiss-with-rationale legal; bounded N=2 + escalation.
- **R2 — Correlated model errors / consensus ≠ truth.** → consensus is a heuristic confidence signal (D3); the human sees every dismissal (D4).
- **R3 — Proportionality (accepted trade-off, recorded).** The orchestrator + loop + always-on gate is heavyweight machinery justified from **n=1** (one exemplar), and in the common **degrade** case A + C collapse to two *same-family* Opus passes = **no cross-model coverage at ~3× cost** while the gate requires the run. Round-2 Pass C flagged this against the anti-speculative-machinery refutation. **Decision (human, fix-forward):** proceed at full scope. **Mitigation:** a *known* Codex-absent context (CI/headless) SHOULD prefer the single-agent critic rather than pay 3× for A+C-same-family — the gate defers to critic there — and the proportionality is revisited after a few real runs (Open Questions).
- **R4 — Unavailable vs broken.** → **the** central fix (D5): classify on `setup`'s individual `node`/`codex`/`auth` fields; only auth-absence skips, everything else surfaces.
- **R5 — Code-accuracy false positives / narrow value.** → existing-symbol scope; new symbols exempt (⇒ REVIEW). This exemption is *why* Pass 4 can't catch the motivating bug (D6) — stated, not hidden.
- **R6 — Isolating one of several changes.** → require and **assert** sole-dirty-or-sole-HEAD before Pass B; focus text is not scoping.
- **R7 — Convergence self-adjudicated.** → surface the full ledger + all dismissals every converged run (D4).
- **R8 — Async control-flow.** → background-B, run-A+C, await-B, merge (D3).
- **R9 — Self-dogfood circular under delivery-lag.** Task 4.1 dogfoods in the same session that authors the v4 critic + marker awareness, but agent-definition edits reach spawns with unpredictable lag → Pass A may be served the **stale v3** critic, which doesn't know `⟶ xtty-cross-review` and would false-flag 4.1's own tail. → **run the 4.1 dogfood in a fresh session after v4 is committed**, or gate it on an explicit `Definition: v4` delivery check.

## Migration Plan

Additive tooling; rollback = revert. The single-agent `/xtty:review` is unchanged (code-accuracy is a strict addition). Codex is a pre-existing dependency.

## Open Questions

- **N default (2 vs 3)?** Start at 2 (this session hit it and escalated correctly).
- **Promote Pass C to a committed agent?** Deferred (anti-roster) until friction recurs.
- **Is the always-on orchestrator proportionate (R3)?** Re-check after a few runs; if the degrade case dominates in practice, narrow the gate or defer the loop.
