# Pre-flight mechanical checks (task 1.4) — run 2026-07-28, no LLM calls

All checks are disk/grep only, run against main at `9c1118b` (working tree == `eaa765b` for every
checked path). Re-runnable: each finding names its instrument.

## 1. Pointer targets named by the drafted compressed refutations

**Scope note (gap, recorded honestly):** the drafted replacement `## Current status` text itself is
not materialized on disk — design.md records that the fan-out's per-pass outputs were ephemeral
`/tmp` scratchpad (`agents-md-context-budget.md` A.7). The check therefore ran against the pointer
set the compressed entries will carry per design D2/D3: the evidence pointers of the current
refutation entries (compression keeps conclusion + applicability + *existing verified pointer*)
plus the design-named rehome/correction targets. The full per-entry home re-check re-runs at apply
(task 3.2), as the design's risk register already requires.

- **Every research-doc pointer in the current refutations list resolves** (instrument:
  `sed -n '39,71p' AGENTS.md | grep -o '[a-z0-9-]*\.md'` → find in `research/`): 17/17 docs found —
  agent-guide-ingestion-forensics, agents-md-structural-best-practices,
  archive-trigger-affordance-forensics, ci-runner-prompt-width-forensics,
  codex-review-integration-forensics, cross-model-design-review-axes,
  cross-model-pairing-consult-research, cross-model-review-tar-pit-forensics,
  cross-model-seat-assignment-research, cross-review-gate-defect-forensics,
  dev-workflow-agent-orchestration, known-product-issues, local-install-workflow-research,
  local-network-privacy-forensics, p6-file-diff-decisions, scroll-momentum-smoothness-research,
  shell-dependent-test-partitioning — plus HISTORY.md. (Two grep artifacts discarded: a bare `.md`
  from markdown-link syntax and a generic `tasks.md` filename mention — neither is a pointer
  target.)
- **The D2 merge's corrected pointer is right**: "instructed" has **0** occurrences in
  `agents-md-structural-best-practices.md` and a live home in `HISTORY.md` (currently `:133`; the
  design's `:121` drifted with unrelated edits — content present, line number stale).
- **D3 rehome target exists**: the sign-convention comment block at
  `AppUITests/XttyMouseWheelUITests.swift:26–33` (the declared destination for the `wheel1`
  sign-inverse sentence). `App/PaneController.swift` uses the field without documenting sign, as
  design D3 states.
- **`wheel1` orphan status, re-verified with a nuance**: `grep -rln wheel1` now also hits
  `research/README.md` and `research/03-analysis/agents-md-context-budget.md` (the Addendum-A
  capture, committed after the design's grep at `fbe3c9e`). Both mentions are the audit record *of
  the orphan finding*, not a home documenting the sign convention for a future editor — D3's
  rationale stands unchanged.
- **D2 carve-out homes verified**: E9 `env-seed-wall`'s only other home is the blockquote at
  `research/03-analysis/github-actions-ci-cd.md:274` inside a 96,273 B doc (as designed — entry
  stays verbatim + gains the pointer); E20's `smkx` secondary homes confirmed at `HISTORY.md`
  (§ fix-scroll-wheel-mouse-reporting narrative) and `AppUITests/XttyMouseWheelUITests.swift:213`.
- **D4's Tooling-row collapse is orphan-safe**: every research-doc name in the current Tooling row
  (18 distinct docs — the row grew past the design's 14 with post-`fbe3c9e` archives) is indexed in
  `research/README.md` AND present on disk (instrument: extract names from the `| Tooling |` row,
  grep `research/README.md`, `find research packer`). 18/18 indexed, 18/18 on disk.

## 2. Baseline-drift finding (flagged for §3, not a 1.x blocker)

Current main carries **32** Learned-refutations entries, not the 31 the design measured at
`fbe3c9e`: commit `eaa765b` appended the `agent-guide-ingestion-forensics` entry (AGENTS.md L71,
~1.2 KB) after the design's byte-slicing, and AGENTS.md is now 46,234 B (design: 44,996 B). The
frozen N baseline **includes** this state (worktree at `eaa765b`), so N-vs-S stays coherent — but
task 3.2's "31 → 24" plan must explicitly decide the 32nd entry's fate (it is a fresh, long,
already-out-of-bound entry with a verified pointer; nothing in the drafted plan covers it), and the
S byte-delta arithmetic must be computed against 46,234 B / the N worktree's file, not the design's
`fbe3c9e` figures.

## 3. Project memory index — no home for any probed trap topic (with one adjacency, recorded)

Instrument: read `~/.claude/projects/-Users-markmark-source-contribute-xtty/memory/MEMORY.md` +
each named file. The index carries: xtty project, terminal research findings, terminal
preferences, launch-on-builtin-display, SwiftUI-hosting-black, peekaboo input,
research-from-external-sources, agent-definitions-cached-per-session, push-to-main,
automation-mode. **No memory file is a home for any probed trap topic** (retries, menu re-assert,
fg-job wait, env-seed-wall, Local Network, momentum, self-certification, convergence,
gate-directions) — with **one adjacency recorded honestly**: the tail of
`agent-definitions-cached-per-session.md` contains "a subagent that ends its turn is never
re-invoked by its background children exiting", which overlaps probe T3's topic. Mitigations, both
verified: (a) worktree isolation gives every probe arm a fresh project dir, so no memory is in any
probe's context (confirmed post-batch: no `memory/` dir was created under the N worktree's project
dir); (b) the pre-registered annotation rule catches the disk-search vector.

## 4. Memory-annotation rule — applied to the N sheet

Exactly one N rep reached a memory file by disk search: **T3-rep2** Read
`~/.claude/projects/-Users-markmark-source-contribute-xtty/memory/agent-definitions-cached-per-session.md`
(trail in `n-tool-trails.md`, flagged `READS-MEMORY-PATH`). Annotated in `results.md` (T3 row): its
refutation was stated in its first text block *before* any tool call, so the memory file
corroborated rather than sourced the verdict; the pass stands with the annotation. No other rep in
any class touched a `~/.claude/projects/` path.
