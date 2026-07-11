## Why

A single-model coherence pass is insufficient for design-bearing changes. Worked evidence from this session: the Opus `xtty-openspec-critic` returned **COHERENT** on `add-git-diff-wrap-toggle` while a GPT Codex adversarial review caught a real **config-ownership bug** (a base-only key modeled on `XttyProfile` instead of `XttyConfigSet`) *and* a too-shallow test plan. The two reviewers are complementary, not redundant: the critic checks **conformance** (rulebook + disk-drift) and never reads product source, while Codex checks **soundness** (approach/assumptions) and fact-checks claims against the real code. We want that cross-model check to be a repeatable, terminating ritual for design-bearing changes — plus the critic hardened so the code-accuracy class is catchable Opus-only when Codex is unavailable.

## What Changes

- A new **cross-model review orchestrator** (`/xtty:cross-review`, main-loop-driven) fires three review passes in parallel over a change: **Pass A** = the Opus critic (conformance), **Pass B** = Codex adversarial-review (GPT soundness), **Pass C** = an *inline* Opus design-soundness pass (the diversity slice). It merges their findings into a **union ledger** tagged by source and a **2-model consensus flag** (a finding raised by both B and C = high-confidence design call).
- A **terminating convergence loop**: each round fires A∥B∥C, the caller adjudicates every finding as **fix** or **dismiss-with-recorded-rationale**, applies fixes, and re-reviews; **converged** when a round yields zero *unresolved* actionable findings from any pass — explicitly **not** "the models produce identical output." Capped at **N rounds** (default 2) with the residual ledger escalated to the human.
- **Degrade, never hard-block**: when a model/CLI is unavailable (Codex is auth-gated and absent in headless/CI), run the available passes and mark the skipped one.
- **Gated to design-bearing changes** at pre-archive (optionally post-propose); the standard change-tail's `⟶ xtty-openspec-critic` marker becomes `⟶ xtty-cross-review` for those. Trivial/non-design changes stay critic-only.
- **Pass C runs inline, not as a new standing agent** — honoring the guide's anti-speculative-roster refutation; it is promoted to a committed `xtty-design-soundness` agent only if the friction recurs.
- The **critic gains a code-accuracy pass** (Pass 4): it fact-checks `design.md`/`tasks.md` concrete code claims (file / type / field / symbol names, "mirrors `X`") against the actual source — a claimed symbol that is absent or contradicted is a **BLOCKER**, a fuzzy/unlocatable claim is a **REVIEW**. Its definition stamp bumps to **v4**.
- **AGENTS.md** documents the convergence protocol, the `⟶ xtty-cross-review` marker and when it replaces the critic marker, the degrade rule, and the "two reviewers cover different axes" framing; **`research/`** captures the finding with this session as the worked exemplar.

## Capabilities

### New Capabilities

- `cross-model-review`: a committed orchestrator that composes multiple review passes across two models (conformance + two-model soundness) over a design-bearing change, merges them into a union-with-consensus ledger, and drives a terminating convergence loop (findings resolved or adjudicated, capped, human-escalated), degrading gracefully when a model is unavailable.

### Modified Capabilities

- `coherence-review`: the `xtty-openspec-critic` single-change pass gains a **design-claim code-accuracy** check — fact-checking the concrete code claims a change's `design.md`/`tasks.md` makes against the actual source, BLOCKER when a claimed symbol is absent/contradicted, REVIEW when fuzzy.

## Impact

- **New committed tooling**: `.claude/commands/xtty/cross-review.md` (the orchestrator launcher/protocol).
- **`.claude/agents/xtty-openspec-critic.md`**: add the code-accuracy pass (Pass 4) to Pass 1; bump `Definition: v4`.
- **`AGENTS.md`**: the cross-model convergence protocol, the `⟶ xtty-cross-review` change-tail marker (design-bearing changes) and its relation to `⟶ xtty-openspec-critic`, the degrade rule, and the committed-tooling bullet listing the new command.
- **`research/03-analysis/`**: a new capture (`cross-model-design-review-*.md`) documenting the complementary-axes finding + this session's exemplar (critic COHERENT ↔ Codex caught the config bug), indexed in `research/README.md`.
- **External dependency**: the Codex plugin's companion script (`codex-companion.mjs adversarial-review`), already installed; the orchestrator invokes it via Bash from the main loop (never a subagent — `run_in_background` strands subagents) and degrades when it is unavailable.
- **No product code and no `verification-harness` delta** — this is dev-workflow tooling (non-UI), verified by inspection + a live review run, not the app's XCUITest state dump.
- **Cost/latency**: tri-pass × up-to-N rounds is heavy, so it is gated to design-bearing changes at pre-archive rather than run per-edit.
