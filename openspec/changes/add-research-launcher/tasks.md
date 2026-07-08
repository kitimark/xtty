## 1. The launcher command

- [ ] 1.1 Write `.claude/commands/xtty/research.md` — the `/xtty:research <question>` launcher recipe: the staged pattern (explore → optional scout → readers fan-out → synthesis → critic → verify-by-effect → capture hand-off), the role→model tiering table (D3), a pointer to the AGENTS.md delegation boundary (not a restatement), and the hand-off to `xtty-capture-research`. Thin launcher; defers to AGENTS.md for the rules (D1/D4/D6).
- [ ] 1.2 Confirm it needs **no new `.gitignore` exception** — the existing `!.claude/commands/xtty/` already tracks it — and introduces **no new `.claude/agents/xtty-*`** (worker is a Workflow, D2).

## 2. AGENTS.md wiring

- [ ] 2.1 Add a *How to work here* delegation rule for source-research fan-outs: the inline-vs-delegate boundary (source-heavy multi-source research above the ~12k-token inheritance floor → a `/xtty:research`-launched Workflow; light existing-doc reads / single-file lookups → inline), mirroring the validate/investigate/review rules. AGENTS.md is the single source of truth; the launcher points here (D4).
- [ ] 2.2 Add `/xtty:research` to the *Conventions* → "Don't track local tooling" committed-tooling exception list.

## 3. Verify (dogfood by effect — inline, no suite/VM delegation)

- [ ] 3.1 Dogfood `/xtty:research` on a small real source-research question end-to-end (a 2–3 source fan-out): confirm the launcher drives a Workflow with the tiered models (readers sonnet, synthesis/critic opus), returns a compact synthesis + critique, the verify-by-effect step runs, and the capture hand-off fires. Record the by-effect result (as the other launcher changes recorded their dogfood proof).
- [ ] 3.2 Confirm the delegation boundary reads correctly: a light single-file/existing-doc lookup is NOT routed to `/xtty:research` (stays inline).

## 4. Coherence + archive (standard change tail)

- [ ] 4.1 Pre-archive coherence review ⟶ xtty-openspec-critic (add-research-launcher)
- [ ] 4.2 Archive + reconcile ⟶ archive-ritual — `openspec archive add-research-launcher`, finish the merge by hand (fill the new `research-orchestration` spec's Purpose, correct merged requirement text to what shipped), then reconcile trackers: AGENTS.md Current-status row + snapshot + the established-specs line (add `research-orchestration`), HISTORY.md narrative, `research/04-design/02-milestones.md`, and flip the `dev-workflow-agent-orchestration.md` §11 status from "decided, not yet built" → built. Verify against disk (`openspec list` · `ls openspec/changes/archive/` · `ls openspec/specs/`). Pre-tick self-check per AGENTS.md.
