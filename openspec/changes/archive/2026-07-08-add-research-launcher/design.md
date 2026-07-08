## Context

xtty's dev workflow leans heavily on source-grounded research: **9 research docs** were produced by multi-agent fan-outs that cloned external source to `/tmp`, read build/internals machinery, synthesized, adversarially verified, and captured the result. Each was hand-authored inline as an ad-hoc Workflow (the latest being the 12-agent `add-install-workflow` comparator sweep). The project already committed three launcher→worker pairs — `/xtty:validate`→`xtty-test-validator`, `/xtty:investigate-ci`→`xtty-ci-investigator`, `/xtty:review`→`xtty-openspec-critic` — and `research-capture` tooling for the *write-up* tail. The one gap the design doc named is the *doing* phase: *"explore/research… has no `xtty-*` launcher+worker."*

The settled decision (`research/03-analysis/dev-workflow-agent-orchestration.md` §11, the T3 revisit) is to close that gap with a **Workflow launcher** at the **Medium** commitment tier. This design records how.

## Goals / Non-Goals

**Goals:**
- A committed `/xtty:research` launcher carrying the reusable parts of the pattern: the role→model tiering, the staged shape (explore → readers → synthesis → critic → verify → capture), the delegation boundary, and the hand-off to `xtty-capture-research`.
- Make the model-per-role recommendation durable and consistent with the existing committed agents.
- Add the AGENTS.md delegation rule (the boundary's single source of truth) and the Conventions tooling-exception line.

**Non-Goals:**
- A rigid, fully-parameterized committed Workflow **script** (the "Full" tier) — research shapes are too heterogeneous (per-terminal / per-facet / per-repo / forensics) for one script; the fan-out width/shape stays main-authored.
- A new standing **agent** for the reader/synthesis/critic roles (the roster refuted by the design doc's T1) — the worker is a per-invocation Workflow whose stages are `agent()` calls.
- Re-implementing the capture tail (already the committed `xtty-capture-research` skill/command).
- Any product/app/test code or `verification-harness` delta.

## Decisions

**D1 — Medium tier: a launcher command, not a workflow script.** `/xtty:research` documents the recipe; the main loop authors the fan-out inline per question. *Rationale:* the recurrence is proven (9 clone-heavy fan-outs) so the pattern is worth committing, but the shapes vary too much for a rigid script — Medium banks the durable parts (tiers + stages + boundary + capture tail) without betting on one shape. *Alternatives rejected:* **Full** (committed `.claude/workflows/xtty-*.js` — rigid, and would need a new `.gitignore` exception); **Minimal** (document the tiers only — banks nothing invokable, leaves the launcher gap open).

**D2 — The worker is a Workflow, not a standing agent.** The reader→synthesis→critic fan-out is "structured multi-stage at scale," which the design doc §3 maps to the **Workflow** mechanism; standing reader/synth/critic agents would be the roster T1 refuted. *Consequence (a real advantage over the other three launchers):* no new `.claude/agents/xtty-*` definition, therefore **no agent-definition-delivery-lag / `Definition:`-stamp concern** — the recurring gotcha that bites the validator/investigator/critic does not apply here.

**D3 — Role→model tiering by cognitive load (§3.D), the substance of the ask.** Baked into the launcher recipe and consistent with the committed agents (validator/investigator = sonnet, openspec-critic = opus):

| Stage | Model · effort | Tier rationale |
|---|---|---|
| explore / orchestrate | **Opus · xhigh** (main, never delegated) | shapes the inquiry, holds the decision thread — journey-value |
| scout *(optional)* | **Haiku · low** | pure mechanical enumeration (list repos/casks/files) |
| readers (fan-out) | **Sonnet · medium** | search/extract; understands build systems; cheap enough to run 8–12 ∥ |
| synthesis | **Opus · high** | holds all records, judges, designs |
| critic | **Opus · high→xhigh** | adversarial reasoning — the quality gate |
| verify-by-effect | **Sonnet · medium** (or main) | run probes + check; escalate to Opus only if the check needs judgment |
| capture | main + `xtty-capture-research` | shared-write trackers → main |

*(Fable 5 is intentionally unused — not an analytical-reasoning tier.)* The spec records this at tier-principle level (mid for readers, top for synthesis/critique, cheapest for scout); the concrete model names live here and in the command recipe.

**D4 — The delegation boundary lives in AGENTS.md, mirrored by the launcher.** Source-heavy multi-source research above the ~12k-token subagent-inheritance floor is delegated; light existing-doc reads and single-file lookups stay inline. AGENTS.md is the single source of truth (as it is for the validate/investigate/review boundaries); the launcher points to it. *Rationale:* the design doc's §9.6 rule — each delegate needs a per-task carrier, and AGENTS.md is the boundary's home — and the ~12k floor from `agents-md-context-budget.md`.

**D5 — Verify-by-effect defaults to the main loop.** The orchestrator runs the critic's load-bearing probes firsthand (as the `add-install-workflow` Release/quarantine/plist spikes were), escalating to a delegated Sonnet verify stage only when the probes are numerous or isolated. *Rationale:* verify-by-effect is journey-value — the orchestrator's judgment sharpens on the evidence.

**D6 — Hand off to the existing capture tail.** On conclusion the pattern invokes `xtty-capture-research`, not a re-implemented write-up. *Rationale:* research-capture already owns the *write-up* phase and explicitly scopes the *doing* method out — the two capabilities compose cleanly (research-orchestration → research-capture).

## Risks / Trade-offs

- **A recipe can be ignored / drift from practice.** → Mitigation: the launcher is thin and points to AGENTS.md (one source of truth); the design doc §11 re-verify probe (re-run the recurrence greps) catches whether the pattern stays used and whether a rigid shape emerges that would justify escalating to Full.
- **Model tiers are a recommendation, not enforced by the harness.** → Mitigation: they're documented in the command recipe + the spec at tier-principle level; the Workflow tool's per-`agent()` `model` override is where they're applied, and the main loop applies them when authoring the fan-out.
- **Medium under-serves a future high-volume, homogeneous research need.** → Mitigation: the design doc records the escalation trigger (a stable shape recurring across the next several) → revisit Full; low cost to add a script later.

## Migration Plan

Additive; no existing behavior changes.
1. Add `.claude/commands/xtty/research.md` (the launcher recipe: tiering table + stages + boundary pointer + capture hand-off).
2. Add the AGENTS.md *How to work here* delegation rule + the *Conventions* tooling-exception line.
3. Dogfood `/xtty:research` on a small real question (by-effect proof the launcher works end-to-end).
4. On completion, flip §11's status in the design doc to "built" and reconcile the trackers.
- **Rollback:** delete the command file + the two AGENTS.md lines; nothing else depends on them.

## Dogfood result (by effect — 2026-07-08)

`/xtty:research` was driven end-to-end on a real question ("how do native terminals implement bracketed paste / OSC 2004, and how does it map to xtty?"). The launcher drove a **per-invocation Workflow** with the tiered models, and every stage fired:

- **Readers (Sonnet · medium, ∥ fan-out)** — 2/2 returned file:line-grounded records: Ghostty (`ghostty-org/ghostty`) + Alacritty (`alacritty/alacritty`), shallow-cloned to `/tmp`. 4 agents, 0 errors, 0 empty results; ~207k subagent tokens, 394 s.
- **Synthesis (Opus · high)** — a compact cross-source comparison table + xtty mapping + named load-bearing claims.
- **Critic (Opus · high)** — *genuinely adversarial*: it read **SwiftTerm's own source (which neither reader touched)** and **refuted** the synthesis's central mechanism claim — that xtty's bash-3.2 first-line-execute residual comes from a `\n`→`\r` CR-rewrite like Ghostty/Alacritty. It also flagged the Ghostty record's missing verbatim snippets and named one unknown to close by effect.
- **Verify-by-effect (main loop, D5)** — confirmed the refutation firsthand against the actual engine checkout: `MacTerminalView.swift:1202-1208` wraps only when `terminal.bracketedPasteMode` is on and otherwise `send(txt:)`s raw bytes; `send(txt:)` (`AppleTerminalView.swift:1982`) does only `[UInt8](txt.utf8)` — **no CR-rewrite**. `EscapeSequences.bracketedPasteEnd` = `ESC[201~`, byte-identical to both references. The recorded measured ground truth (`AppUITests/XttyUITests.swift:126-139`, bash bracketed-OFF arm) confirms the *effect* (first `\n`-terminated line executes, tail staged) that the synthesis predicted — while the *mechanism* is raw-LF-into-tty-line-discipline, exactly as the critic said.
- **Capture hand-off (D6)** — fired with an honest **null-delta** conclusion: the owning doc `research/03-analysis/shell-dependent-test-partitioning.md:43-47` already states the correct raw-bytes mechanism (*"xtty legitimately pastes raw bytes → the embedded `\n` executes"*), and the critic's "injection gap" note is an unverified future-hardening idea, correctly **not** minted as durable research.

**Net proof:** the launcher drives the full staged pattern with the D3 tiers, and the adversarial critic + verify-by-effect stages earned their keep by stopping a wrong mechanism claim (CR-rewrite) from reaching `research/`. Run: `wf_7dac0fa9-ea9`.

## Open Questions

- **Reader `agentType`** — inline workflow prompts (chosen; zero new standing definitions, honors T1) vs. a committed reader agent with a rich reused system prompt (heavier; only if a fixed reader persona proves necessary). Resolution: inline for now.
- **Escalation to Full** — deferred; revisit only if a single rigid research shape recurs across the next several changes (the §11 re-verify probe is the trigger).
