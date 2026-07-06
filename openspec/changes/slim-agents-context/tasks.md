# Tasks — slim-agents-context

## 1. Pre-registration (before any restructuring or probe run)

- [ ] 1.1 Commit the probe suite + rubric into the change dir (`probes/` — ~12 prompts: 4 rule-compliance, 4 recall/routing, 4 traps; a written pass/fail rubric per probe) and the **acceptance envelope**: ≥20k input-token reduction at session start (from `claude -p --output-format json` usage fields, never estimates); **zero regressions** on rule + trap classes (slim ≥ fat per probe, 3 reps per cell); recall probes correct within ≤2 extra tool calls vs fat
- [ ] 1.2 Record the fat baseline: run the full probe suite against main (fat AGENTS.md), 3 reps per probe; grade against the rubric; save transcripts + a results table to the change dir — the fat variant's own failures (if any) are recorded, per design D6

## 2. The restructure (on a branch/worktree; main stays fat until §3 passes)

- [ ] 2.1 Create `HISTORY.md` (repo root): dated heading scaffolding, then move **verbatim** the three history blobs — the ✅ per-change narratives from *Current status*, the changelog tail embedded in *OpenSpec workflow* (the `fix-main-menu-clobber`… line and its companions), and the CI-run history digest lines in *Building* — and verify losslessness mechanically (every moved line appears byte-identical in HISTORY.md; nothing in the union of old-AGENTS + new-AGENTS + HISTORY.md is missing vs old AGENTS.md)
- [ ] 2.2 Rewrite AGENTS.md *Current status* as: snapshot paragraph (milestone position, unit/e2e counts, VM acceptance envelope pointer) + the status table (`change | state | one-liner | detail pointer` — one row per open change, one per shipped milestone group) + the **inoculation list** (~10 one-liners with conclusions inline: retries mask races; `run_in_background` strands subagents; menu re-assert no-op → `NSApplicationMain`; `hasForegroundJob` waits refuted; Scope-B tree rejected; SwiftUI hosting renders black; Metal renderer slower-tailed → CoreGraphics; agent-definition propagation lag → verify delivery; seed-wall strips launchEnvironment; bash-3.2 lacks bracketed paste)
- [ ] 2.3 Trim *Building* to quick-start + prerequisites + the SwiftTerm patch mechanism; CI section becomes a short paragraph (two jobs, gate status) + pointer to `research/03-analysis/github-actions-ci-cd.md` §9–§18; move the displaced history into HISTORY.md (same losslessness check as 2.1)
- [ ] 2.4 Amend the **"Keep progress current"** rule per design D4 (completion = bounded table-row edit + snapshot refresh + narrative appended to HISTORY.md; a paragraph-sized status entry is by rule HISTORY.md content) and update the `xtty-capture-research` skill checklist + `/xtty:capture-research` command to match (rules stay only in AGENTS.md — deference chain intact)
- [ ] 2.5 Sanity-measure the slim file: byte size ≤ ~20 KB; token count via a fresh session `/context` (or headless usage) confirms the *Memory files* category dropped by ≥20k — record the number

## 3. Verify (the fat-vs-slim A/B, per design D5)

- [ ] 3.1 Run the probe suite against the slim worktree: same 12 probes × 3 reps, headless fresh sessions; grade with the same rubric; save transcripts + results table alongside the fat baseline
- [ ] 3.2 Judge against the pre-registered envelope: token reduction ≥20k; rule + trap classes zero regressions; recall ≤2 extra tool calls. For any trap failure: strengthen that inoculation line (or add one), re-run **that probe** (3 reps) — never restore moved history; record each fix + re-run in the results table
- [ ] 3.3 Land the restructure on main as **one atomic commit** (AGENTS.md + HISTORY.md + skill/command checklist + rule amendment together — no dangling pointers), with the probe results referenced in the commit message

## 4. Capture + trackers

- [ ] 4.1 Write `research/03-analysis/agents-md-context-budget.md` per the capture-depth bar: the growth curve (12.3→80.6 KB with dates), the 2.46 bytes/token density measurement, the `/context` budget breakdown (incl. the deferred-MCP ~50k already saved — a dead-end lane), the probe-suite method + results (incl. anything the fat baseline failed), re-verify-by-effect (a fresh session's `/context` Memory-files number), and the reusable guideline (always-loaded guide = rules + orientation + inoculations; history lives one `Read` away); index it in `research/README.md`
- [ ] 4.2 Reconcile trackers **in the new format** (this change eats its own cooking): status table row updated, narrative paragraph appended to HISTORY.md, milestones file touched; `openspec validate "slim-agents-context"` green
- [ ] 4.3 At archive: verify the merged `research-capture` spec reflects what shipped (lean-status + history-log + inoculation requirements); hand-check the merge per the post-archive rule; verify-against-disk (`openspec list`, archive dir, specs dir)
