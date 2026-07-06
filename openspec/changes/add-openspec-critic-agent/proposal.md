## Why

Checking an OpenSpec change for **coherence** is a rule-dense, repetitive activity: the proposal↔specs capability contract, a MODIFIED requirement pasting the *entire* existing block, scenarios using exactly four hashtags, every requirement having a build+verify task, verify tasks that run the suite/VM carrying the delegation marker, new observable behavior carrying a `verification-harness` delta, requirements staying mechanism-neutral, and the trackers matching disk. Today it is done by hand/self-check, inconsistently — and it demonstrably drifts: AGENTS.md's own prose claims "**7 of the 10** archived changes carry a harness delta" while the disk truth is **19/34**, a staleness nothing currently catches. This is exactly the friction the dev-workflow forensics ([`dev-workflow-agent-orchestration.md`](../../../research/03-analysis/dev-workflow-agent-orchestration.md)) identified as the one that recurs **every change**, is **entirely unautomated**, and is **provably under-done** — the reactive-friction signal that justifies a committed agent. It maps onto the existing `xtty-ci-investigator` / `xtty-test-validator` pattern (isolate the noisy checking, defer to a repo-owned rulebook, return a fixed-skeleton verdict) and adds the **project-specific** need those two don't touch: **cross-change coherence** across the 2–5 changes this project routinely has open at once.

## What Changes

- **New committed agent `xtty-openspec-critic`** that, given a change name (or "all active"), verifies coherence against AGENTS.md's rulebook and the live repo state and returns a **fixed-skeleton findings report** — **observe-and-report only, never repair**. It covers three passes: (1) **single-change coherence** (the AGENTS.md §"Keeping a change coherent" + spec-delta-format rules, operationalized as concrete checks); (2) **disk-drift** (established specs match `ls openspec/specs/`, count claims in prose re-derived against disk, promised tracker edits actually made); (3) **cross-change coherence** (shared spec requirements, archive-ordering, red→green apply-order pairs across active changes).
- **New thin launcher `/xtty:review`** (mirrors `/xtty:investigate-ci`): spawns the agent, forwards the change reference, relays the report, and does the definition-stamp delivery check.
- **Deference chain:** the agent defers to **AGENTS.md** (the "Keeping a change coherent" + spec-delta-format sections) as the single source of truth for the *rules*, read fresh each run — it never hardcodes the rule set; it encodes only the *operationalization* (how to check each) in its own definition, exactly as `xtty-test-validator` encodes tier mechanics while deferring to `packer/README.md` for numbers. A rule it cannot mechanically check is **flagged for human review**, never silently dropped.
- **Findings vocabulary:** `COHERENT` / `ISSUES-FOUND` / `BLOCKED-PREREQUISITE`; each finding tagged **BLOCKER** (a hard rule, e.g. a MODIFIED block that truncates the established requirement) or **REVIEW** (a heuristic rule, e.g. suspected mechanism-specific detail in a requirement) so heuristics inform without false-failing.
- **Trigger boundary (validate-vs-review):** running `openspec validate` (cheap, mechanical, already the documented gate) stays **inline**; a **full coherence review** (the rule passes + drift + cross-change) is **delegated**, carried to the apply/propose loop by a per-task marker `⟶ xtty-openspec-critic (<change|all>)`.
- **Model:** ships on **Opus** (coherence has genuine judgment calls — mechanism-neutrality, design↔requirement traceability, cross-change collision reasoning — beyond table-lookup); to be tuned toward Sonnet later only if measured runs prove the checks are overwhelmingly mechanical (settle by measurement, the inverse of the ci-investigator's Sonnet→Haiku note).

## Capabilities

### New Capabilities

- `coherence-review`: the committed `xtty-openspec-critic` agent + its `/xtty:review` launcher, the deference to AGENTS.md's coherence rulebook + live repo state (never hardcoded), the three review passes (single-change coherence, disk-drift, cross-change coherence), the fixed findings-report contract (definition stamp, verdict, per-change findings with BLOCKER/REVIEW severity + location, cross-change findings, evidence, recommendation), the two spawn scenarios (direct user request; apply/propose-task delegation with a per-task marker and a documented validate-vs-review boundary), and the observe-never-repair guardrails.

### Modified Capabilities

- (none) — the new agent's delegation boundary is part of `coherence-review`; `ci-investigation` and `test-validation` are untouched.

## Impact

- **New tracked files:** `.claude/agents/xtty-openspec-critic.md`, `.claude/commands/xtty/review.md` (both covered by the existing `.claude/agents/xtty-*` + `.claude/commands/xtty/*` gitignore exceptions).
- **Modified docs:** `AGENTS.md` (tooling row + the validate-vs-review delegation boundary bullet + committed-tooling list), `openspec/config.yaml` (`rules.tasks` pointer to the boundary), `research/README.md` line if warranted.
- **Dependencies:** `openspec` CLI, `git`, `grep`/`find` — all already present. **No product code and no runtime app behavior are touched.**
- **Relationship to the sibling agents:** the third member of the `xtty-*` family, sharing the isolate-the-noise / defer-to-a-repo-rulebook / fixed-verdict discipline. Like `xtty-ci-investigator` it is short and read-only, so it needs **no** turn-alive/babysitter apparatus — only the shared definition stamp + delivery check. It is the first to add a **cross-artifact (change-set) pass**, the distinctive project need.
