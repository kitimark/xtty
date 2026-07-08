## 1. The launcher command

- [x] 1.1 Write `.claude/commands/xtty/research.md` — the `/xtty:research <question>` launcher recipe: the staged pattern (explore → optional scout → readers fan-out → synthesis → critic → verify-by-effect → capture hand-off), the role→model tiering table (D3), a pointer to the AGENTS.md delegation boundary (not a restatement), and the hand-off to `xtty-capture-research`. Thin launcher; defers to AGENTS.md for the rules (D1/D4/D6).
- [x] 1.2 Confirm it needs **no new `.gitignore` exception** — the existing `!.claude/commands/xtty/` already tracks it — and introduces **no new `.claude/agents/xtty-*`** (worker is a Workflow, D2).

## 2. AGENTS.md wiring

- [x] 2.1 Add a *How to work here* delegation rule for source-research fan-outs: the inline-vs-delegate boundary (source-heavy multi-source research above the ~12k-token inheritance floor → a `/xtty:research`-launched Workflow; light existing-doc reads / single-file lookups → inline), mirroring the validate/investigate/review rules. AGENTS.md is the single source of truth; the launcher points here (D4).
- [x] 2.2 Add `/xtty:research` to the *Conventions* → "Don't track local tooling" committed-tooling exception list.

## 3. Verify (dogfood by effect — inline, no suite/VM delegation)

- [x] 3.1 Dogfood `/xtty:research` on a small real source-research question end-to-end (a 2–3 source fan-out): confirm the launcher drives a Workflow with the tiered models (readers sonnet, synthesis/critic opus), returns a compact synthesis + critique, the verify-by-effect step runs, and the capture hand-off fires. Record the by-effect result (as the other launcher changes recorded their dogfood proof). — **DONE** (run `wf_7dac0fa9-ea9`; 4 agents 0-error; readers Sonnet·medium ×2, synthesis+critic Opus·high; critic refuted the synthesis CR-rewrite claim, verify-by-effect confirmed raw-LF against SwiftTerm source, capture fired null-delta; full write-up in design.md → *Dogfood result*).
- [x] 3.2 Confirm the delegation boundary reads correctly: a light single-file/existing-doc lookup is NOT routed to `/xtty:research` (stays inline). — **DONE** (AGENTS.md:144 + launcher lines 10/16 both state light `research/`-doc reads / single-file lookups stay inline in main/fork, not routed to the fan-out).

## 4. Coherence + archive (standard change tail)

- [x] 4.1 Pre-archive coherence review ⟶ xtty-openspec-critic (add-research-launcher) — **DONE** (Definition v1; VERDICT ISSUES-FOUND → resolved: BLOCKER = launcher git-untracked, fixed by `git add`; 2 REVIEW items — stale `0/8` row cleared by this reconcile, mechanism-neutrality acceptable-by-design).
- [x] 4.2 Archive + reconcile ⟶ archive-ritual — **DONE** — `openspec archive add-research-launcher` (research-orchestration spec created, 4 reqs); filled the new spec's Purpose (requirement text matched what shipped, no correction needed); reconciled trackers: AGENTS.md open-changes row removed + established-specs line (+`research-orchestration`) + Shipped/archived Tooling row entry, HISTORY.md narrative, `research/04-design/02-milestones.md` (decided→BUILT), `dev-workflow-agent-orchestration.md` §11 status (decided→BUILT). Verified against disk (`openspec list` = only `add-ci-pipeline` active · archive dir `2026-07-08-add-research-launcher` · `research-orchestration` in `openspec/specs/` · 22/22 specs validate). Snapshot unchanged (no counts/envelope/milestone moved — dev-tooling).
