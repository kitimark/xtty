## Context

The `coherence-review` capability delegates full coherence review to the committed Opus `xtty-openspec-critic` agent (6 requirements; three passes: single-change coherence, disk-drift, cross-change). It checks **conformance** — the rulebook + disk-drift — and by design never reads product source. This session produced the motivating evidence: the critic returned **COHERENT** on `add-git-diff-wrap-toggle` while a Codex (GPT) adversarial review returned **needs-attention** with a real config-ownership bug (`XttyConfigSet` vs `XttyProfile`) and a too-shallow test plan. The critic could not catch the first because it does not fact-check code; both reviews were complementary, covering different axes (conformance vs soundness) on different models.

The Codex plugin is already installed (`codex-companion.mjs adversarial-review`), emitting a structured verdict (`approve | needs-attention`, `findings[]` with a `confidence` score, `next_steps`). It is `disable-model-invocation: true` (user-triggered by design) and auth-gated (absent in headless/CI). The repo's refutations that bind this design: **`run_in_background` strands subagents** (so a subagent must not own the detached Codex run); **don't pre-build a speculative agent roster** (so the new soundness pass runs inline first).

## Goals / Non-Goals

**Goals:**
- A repeatable, terminating cross-model review for **design-bearing** changes: conformance (Opus critic) ∥ soundness (Codex/GPT) ∥ soundness (inline Opus) → union-with-consensus ledger → adjudicate → fix → re-review until resolved.
- Harden the critic so the code-accuracy class is catchable **Opus-only** and when Codex is unavailable.
- Degrade gracefully; never hard-block on a missing reviewer.

**Non-Goals:**
- Not a per-edit gate (cost); scoped to design-bearing changes at pre-archive.
- Not a new standing soundness agent yet (inline until friction recurs).
- Not "make the two models agree literally" — the gate is *findings resolved*, not *identical output*.
- No product-code change and no `verification-harness` delta (dev-workflow tooling, non-UI).

## Decisions

### D1 — New `cross-model-review` capability + a `coherence-review` MODIFY, not one blob
The **orchestrator + convergence loop** is a distinct capability (it composes reviewers across models and, crucially, **applies fixes between rounds** — a fix-loop that `coherence-review`'s observe-never-repair identity forbids). So it is a **new `cross-model-review` spec**. The **code-accuracy pass** is squarely a *critic* enhancement, so it **MODIFIES `coherence-review`**'s single-change pass. This keeps the critic pure-observe and the orchestrator's fix-loop cleanly separated. *Alternative rejected:* folding the orchestrator into `coherence-review` — it would put a repair loop inside an observe-only capability.

### D2 — Orchestration runs in the main loop, not a subagent
The loop must (a) drive a **long-running detached Codex** call and (b) **edit change artifacts** between rounds. A review subagent owning the Codex background call hits the *strand* refutation, and editing artifacts is the main loop's job anyway. So `/xtty:cross-review` is a **main-loop protocol** (a launcher command that the main session executes), and the three passes stay observe-only callees. *Alternative rejected:* a Workflow that owns the fix step — worktree round-tripping of edits is messier than main-loop ownership, and the main loop is the natural adjudicator.

### D3 — The tri-pass "both" flavor (union + diversity slice)
- **Pass A — conformance (Opus critic):** the existing `xtty-openspec-critic` (now with code-accuracy, D6).
- **Pass B — soundness (GPT/Codex):** `codex-companion.mjs adversarial-review` over the change's diff; reads real source.
- **Pass C — soundness (Opus, inline):** an inline `Agent` call with the *same adversarial-soundness lens* as B, on Opus.

Merge into a **union ledger** tagged by source; a finding raised by **both B and C** is a **two-model consensus** finding (higher confidence). Value = coverage (A ∪ {B,C}) + consensus (B ∩ C). Pass C runs **inline** (not a committed agent) per the anti-roster refutation; promote to `xtty-design-soundness` only if it recurs. *Alternative considered:* pure model-diversity (run the *same* spec on both models only) — narrower; the "both" flavor keeps A's conformance coverage too.

### D4 — Convergence = findings resolved, bounded, escalated
A round runs A∥B∥C; the caller adjudicates **every** finding as **fix** or **dismiss-with-recorded-rationale**, applies fixes, re-runs. **Converged** ⇐ a round with **zero unresolved actionable findings from any pass**. This is *not* "identical output" (they review different axes; a correct design may warrant a dismissal — e.g. the grounded "P6 intended" flag kept this session). Bound at **N = 2 rounds** (default; tunable); on hitting the bound, **escalate the residual ledger to the human**. This defeats non-termination and thrash (a Codex fix that trips a critic rule surfaces next round, bounded).

### D5 — Codex integration mechanics
Invoke `node codex-companion.mjs adversarial-review` via **Bash from the main loop** (background per the existing `--background` flow; the main loop, not a subagent, owns it). **Target:** the change's artifacts must be in a reviewable diff — **working-tree** review when the change is uncommitted, or `--base <ref>` when committed; the orchestrator computes which. Codex reads any repo file for cross-check (that is how it caught the config bug). **Availability:** on auth failure / headless / CI, mark Pass B skipped and continue (D-degrade). Its JSON verdict (`needs-attention`/`approve`, per-finding `confidence`) feeds the ledger.

### D6 — Critic code-accuracy pass (Pass 4)
Extract the change's **concrete code claims** from `design.md`/`tasks.md` — `` `Type.field` ``, `` `File.swift` ``, `"mirrors `X`"`, symbol names — and **grep the source**: a claimed symbol **absent or contradicted** (e.g. a field asserted on `XttyProfile` that the source shows on `XttyConfigSet`) ⇒ **BLOCKER**; a claim that cannot be located precisely ⇒ **REVIEW**. Bounded to claims about the **existing** codebase (a claim about code the change will *create* is not flagged); read-only greps keep the critic fast and observe-only. Bump `Definition: v4` and update the delivery-check stamp in the launcher.

### D7 — Gating and the change-tail marker
Cross-model review is for **design-bearing** changes at **pre-archive** (optionally post-propose). AGENTS.md documents the protocol and a `⟶ xtty-cross-review` marker that **replaces** `⟶ xtty-openspec-critic` in the standard change-tail *for design-bearing changes*; trivial/non-design changes keep the single-agent marker. "Design-bearing" = the change has a `design.md` with substantive decisions (a heuristic the guide states, not a hard gate).

### Verification approach (no product test added)
This is dev-workflow tooling, so it is verified **by effect**, not by a product `XCUITest`/unit test: run the enhanced critic on a change with a deliberately wrong code claim and confirm the BLOCKER; run `/xtty:cross-review` on a real design-bearing change and confirm the tri-pass fires, the ledger merges with a consensus flag, the loop converges/escalates, and Codex-absent degrades. Hence no `verification-harness` delta and no `⟶ xtty-test-validator` marker.

## Risks / Trade-offs

- **R1 — Non-termination / thrash.** → **Mitigation:** convergence gates on *unresolved* findings, `dismiss-with-rationale` is legal, and the loop is bounded (N=2) with human escalation.
- **R2 — Correlated model errors** (both soundness passes wrong the same way). → **Mitigation:** the consensus flag denotes *confidence, not truth*; the human adjudicates residuals and any dismissal is recorded. Cross-model narrows but never eliminates correlated blind spots.
- **R3 — Cost/latency** (tri-pass × up-to-N rounds, Codex minutes + external API). → **Mitigation:** gate to design-bearing changes at pre-archive; trivial changes stay critic-only.
- **R4 — Codex unavailability** (auth/headless/CI). → **Mitigation:** degrade — run available passes, mark the skip, still verdict; never hard-block. CI runs are always Codex-absent by construction and are fine on Pass A (+ C).
- **R5 — Code-accuracy false positives** (a design claim about *intended*, not-yet-existing code read as a contradiction). → **Mitigation:** scope the check to claims about the *existing* codebase; fuzzy/unlocatable ⇒ REVIEW (never BLOCKER); "mirrors `X`" only flags when `X` itself is absent/contradicted.
- **R6 — Codex diff-target mismatch** (a committed change shows an empty working tree). → **Mitigation:** the orchestrator selects working-tree vs `--base <ref>` from the change's commit state before invoking Codex.

## Migration Plan

Additive tooling; no migration. New command + agent-pass + AGENTS.md/`research/` docs. Rollback = revert the change; the single-agent `/xtty:review` continues to work unchanged (the code-accuracy pass is a strict addition to it). The Codex plugin is a pre-existing external dependency, not introduced here.

## Open Questions

- **N default (2 vs 3)?** Start at 2; revisit if design-bearing changes routinely need a third round.
- **Promote Pass C to a committed `xtty-design-soundness` agent?** Deferred until recurring friction justifies it (anti-roster refutation).
- **Should Pass C reuse Codex's exact JSON soundness schema** for apples-to-apples per-finding consensus, or a looser lens? Start loose; tighten to the shared schema if consensus matching proves noisy.
