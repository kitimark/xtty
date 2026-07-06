# Design — slim-agents-context

## Context

Every Claude Code session in this repo loads CLAUDE.md, which imports AGENTS.md wholesale. Measured state (2026-07-06):

- AGENTS.md = 80,609 bytes = **32.8k tokens** (per `/context`; 2.46 bytes/token — the backtick/bold/§-dense style tokenizes far worse than the ~4 bytes/token prose heuristic).
- Section budget: *OpenSpec workflow* 38.2 KB (48% — of which a single 32,933-byte line, the per-change changelog tail), *Building* 16.5 KB (21% — incl. an 8.5 KB CI-history line), *Current status* 15.5 KB (19%), everything else ~9.5 KB (12%).
- Growth: 12.3 KB (06-28) → 40.1 KB (06-29) → 52.5 KB (07-01) → 68.4 KB (07-05) → 80.6 KB (07-06); ~8.5 KB/day ≈ +2.5k tokens/day, linear, no pruning mechanism.
- The fixed pre-message session cost is ~58k tokens, so AGENTS.md is ~56% of it and the largest single item (system prompt 5.5k + built-in tools 14.8k combined are smaller).

The history content is a third copy by construction: `openspec/specs/` records what is true, `openspec/changes/archive/<date>-<name>/` holds each change's full proposal/design/tasks, and `research/03-analysis/` holds the mechanisms. What the narratives uniquely provide at session start is *orientation* (where are we) and *routing* (which doc has the detail) — plus a handful of inline refutations that stop sessions from re-proposing dead ideas.

Contrast that works: the auto-memory system loads only a one-line-per-memory index (495 tokens for 8 memories) and reads bodies on demand — the progressive-disclosure pattern this change applies to AGENTS.md.

## Goals / Non-Goals

**Goals:**

- Cut AGENTS.md to the durable rules + a lean status surface: target ≈18 KB / ~7k tokens (≥20k tokens saved at session start, measured).
- Preserve every byte of history (moved verbatim, grep-able) and every learned refutation (inline one-liners).
- Change the growth rule so the file stays lean: bounded per-change status entries; narratives append to the history log.
- Prove no behavioral regression with a pre-registered fat-vs-slim probe suite before the slim file lands on main.

**Non-Goals:**

- No change to the CLAUDE.md→AGENTS.md import mechanism (AGENTS.md stays the single canonical guide; splitting truth across two always-loaded files invites drift).
- No rewriting/summarizing of the moved narratives (verbatim move only — summarization loses detail and doubles the review burden).
- No harness-side optimization (MCP deferral already saves ~50k in this client; system prompt/tools are not repo-controllable).
- No changes to `openspec/specs/` content, research docs, or the milestones file beyond the tracker touches the workflow already requires.
- Not a general documentation reorganization — only the three measured history blobs move.

## Decisions

**D1 — One `HISTORY.md` at the repo root, not per-change files or research docs.**
The narratives are cross-cutting digests (a single entry references specs, research docs, CI runs, and other changes), so scattering them into per-change archive READMEs would destroy the chronological read and make the move un-reviewable. A research doc is wrong too: `research/` docs carry Provenance/Sources conventions and are topical, not a running log. A root `HISTORY.md` keeps `git log --follow` continuity simple, is one predictable `Read` target, and is trivially excluded from context (nothing imports it). Alternative rejected: `docs/` subdirectory — the repo has no `docs/` tree and one file doesn't justify creating one.

**D2 — Move verbatim; restructure only the surviving file.**
The moved text is pasted into HISTORY.md unchanged (under dated headings matching today's structure), so review reduces to "was anything dropped?" (checkable by diff/grep) rather than "was the summary faithful?". All compression happens on the AGENTS.md side, where the new content is *new writing* (snapshot + table) reviewed on its own terms.

**D3 — The status surface is a snapshot paragraph + a pointer table + inline inoculations.**
Three tiers, by how expensive a miss is:
- *Snapshot* (one paragraph): milestone position, test counts, acceptance envelope — the facts nearly every session needs.
- *Table* (`change | state | one-liner | detail pointer`): one row per open change and per shipped milestone-group; routing in one hop.
- *Inoculations* (~10 single lines, conclusion stated inline): the refutations that were expensive to learn and dangerous to forget — e.g. retry tolerance masks per-launch races; `run_in_background` strands subagents; same-instance menu re-assert is a no-op (`NSApplicationMain` is the fix); `hasForegroundJob`-based readiness waits are refuted; Scope-B file tree rejected as IDE-creep. A pointer alone fails here because the failure mode is *not knowing there is something to look up*; ~300 tokens buys the whole trap class.

**D4 — Amend "Keep progress current" instead of adding a new rule.**
The growth is the rule working as written. The amendment: on completion, (a) update the change's table row (bounded: one line), (b) append the narrative to HISTORY.md, (c) refresh the snapshot paragraph if counts/envelope moved. The `xtty-capture-research` skill's reconcile checklist is updated in the same commit (it operationalizes this rule; AGENTS.md remains the only rules home — deference chain unchanged).

**D5 — Verification is a fat-vs-slim behavioral A/B with a pre-registered envelope, run before the slim file lands.**
Method (mirrors the validator-agent "validate by effect" precedent): two checkouts (main = fat; branch/worktree = slim), identical probe prompts as fresh headless sessions (`claude -p --output-format json`), ~3 repetitions per probe per variant (behavior is stochastic; a single run proves nothing), graded against a written rubric committed with the change. Probe classes map to the three risk lanes:
- *Rule compliance* (expect slim ≥ fat): does a feature request get routed to an OpenSpec proposal; does a suite-verification request delegate to `xtty-test-validator`; are commits Conventional.
- *Recall/routing* (expect ≤2 extra tool calls): envelope numbers; why CoreGraphics; how SwiftTerm is consumed.
- *Traps* (gate — zero regressions): suggest CI retries; suggest re-asserting `NSApp.mainMenu`; suggest backgrounding validator waits.
Envelope registered in tasks.md before any run: ≥20k input-token reduction at session start (from JSON usage fields, not estimates); zero rule/trap regressions; recall correct within ≤2 extra tool calls. A trap failure is repaired by strengthening that inoculation line and re-running the probe — never by moving history back.
Alternative rejected: shipping the diet unverified ("it's just docs") — the file *is* the per-session program; the repo's own forensics show prompt-affordance changes altering agent behavior in measured ways, so it gets the same validate-by-effect treatment.

**D6 — Fat baseline is measured too, not assumed perfect.**
The rule-compliance probes run against today's file first. If the fat variant itself fails probes (plausible given 33k tokens of dilution), that is recorded — it reframes the change from "hopefully harmless" to "measurably corrective", and it sets the real bar (slim must beat *measured* fat, not imagined-perfect fat).

## Risks / Trade-offs

- **[Silent non-recall: a session re-proposes a refuted idea it no longer sees]** → the trap-probe class gates the change; the inoculation tier (D3) carries conclusions inline; any post-ship recurrence is fixed by adding one line to the inoculation list (cheap, targeted).
- **[Recall latency: history questions now cost a `Read`]** → accepted by design (progressive disclosure); bounded by the ≤2-extra-tool-calls envelope; every table row carries its pointer so routing is one hop.
- **[Compaction summaries currently free-ride on the fat file]** → post-diet, summaries lean on the summarizer plus the slim file's snapshot/table, which concentrates exactly the state a summary needs; monitored risk — not cheaply A/B-testable, revisit if post-compaction sessions visibly lose orientation.
- **[The probe suite is a sample, not proof]** → accepted; probes target the three failure lanes with the trap class chosen from the *known* expensive lessons; the structural backstop is that nothing is deleted, so any discovered gap is repairable at pointer/inoculation granularity.
- **[File re-inflates after the diet]** → D4's bounded-entry rule + the reviewable convention that status edits are table-row-sized; if a future entry needs a paragraph, that paragraph belongs in HISTORY.md by rule.
- **[Verbatim move leaves HISTORY.md internally rough (single 33 KB lines)]** → accepted; HISTORY.md is an archive read by grep/on-demand `Read`, not a startup cost; light heading scaffolding is added around the pasted blocks without editing them.
- **[Stochastic probe noise produces a false regression signal]** → 3 reps per cell + rubric grading; a 0/3 vs 3/3 flip is signal, a 2/3 vs 3/3 wobble triggers more reps on that probe before judgment.

## Migration Plan

1. Branch (worktree) carries the restructure; main stays fat until verification passes.
2. Run the probe suite fat-vs-slim; record results + transcripts as evidence; fold any inoculation fixes.
3. Land AGENTS.md + HISTORY.md + skill-checklist + rule amendment as one commit (the split must be atomic — a session that sees the slim file without HISTORY.md has dangling pointers).
4. Rollback: `git revert` of that commit restores the fat file exactly (verbatim move guarantees losslessness).

## Open Questions

- Whether the ~10 inoculation lines are the right set — the trap-probe results decide (a probe the slim variant fails promotes its lesson to an inoculation line).
- Whether `research/04-design/02-milestones.md` should get the same treatment later (it is *not* auto-loaded, so it is out of scope here, but the same append-forever pattern exists).
