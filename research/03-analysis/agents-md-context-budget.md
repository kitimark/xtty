# AGENTS.md context budget — the rules/history split, measured

**Provenance:** 2026-07-06, produced during the `slim-agents-context` apply session (single main session
+ ~100 headless `claude -p` probe runs + one Agent-tool presence probe). All numbers measured, none
estimated. Change artifacts: `openspec/changes/slim-agents-context/` (pre-registered envelope + rubric in
`probes/`, graded results in `probes/results.md`).

**TL;DR:** AGENTS.md had become an append-only changelog costing **32.8k tokens at every session start**
(56% of the fixed pre-message budget) and growing ~2.5k tokens/day. Splitting it into rules-in-AGENTS +
verbatim-history-in-HISTORY.md saved **21,548 startup tokens** and — measured by a pre-registered
fat-vs-slim behavioral A/B — **improved** rule adherence (OpenSpec routing under implementation pressure:
1/3 → 3/3) with zero regressions elsewhere. Subagents inherit the file too (probe-proven), so the saving
multiplies by every agent of every workflow (~25k × N). An ablation arm proved the one-line
"learned refutation" tier load-bearing: without it, the retries trap regressed 3/3 → 0/2.

## 1. Mechanism

- **What loads at session start:** CLAUDE.md `@AGENTS.md` import → the whole file lands in the `Memory
  files` context category of every session — and, probe-proven (§3.4), in **every Task-tool subagent's**
  context as well. Nothing about the load is lazy; the only lazy layer in the stack is the auto-memory
  index (one line per memory, bodies read on demand) — the pattern the split copies.
- **Token density:** the file's backtick/bold/§-dense style tokenizes at **2.46 bytes/token** (80,609
  bytes ↔ 32.8k tokens per `/context`), ~40% worse than the ~4 bytes/token prose heuristic. Estimates
  based on /4 undercount this class of file by a third.
- **Growth (git history):** 12.3 KB (06-28) → 28.2/40.1 KB (06-29) → 52.5 KB (07-01) → 68.4 KB (07-05)
  → 80.6 KB (07-06); ~8.5 KB/day, linear, no pruning mechanism. The growth was the "Keep progress
  current" rule working as written — each completed change appended a narrative paragraph.
- **Where it sat:** *OpenSpec workflow* section 48% (one single line of 32,933 bytes — the changelog
  tail), *Building* 21% (an 8.5 KB CI-history line), *Current status* 19%. The durable rules were ~12%.
- **Budget context (session `/context`, 2026-07-06):** system prompt 5.5k + built-in tools 14.8k +
  skills 4.2k + agents 0.3k + Memory files 33.5k (32.8k = AGENTS.md) ≈ 58k fixed. Deferred MCP schemas
  (33.5k) and deferred system tools (~16k) are **not** in context — deferral already saves ~50k in this
  client, so MCP pruning was a dead-end lane here (it matters only in eager-loading clients).

## 2. The split (what shipped, commit `d2a11fd`)

Rules + orientation stay in AGENTS.md (28.1 KB): snapshot paragraph, open-changes + shipped tables with
detail pointers, **11 learned-refutation one-liners with conclusions inline**, build/workflow rules. The
three history blobs moved **verbatim** to a root `HISTORY.md` (not imported; append-only), checked
mechanically: all 43 original lines ≥200 chars survive byte-identical in the union. The
"Keep progress current" rule now bounds status updates to a table row + snapshot refresh, with narratives
appended to HISTORY.md — without the rule amendment the file re-inflates at measured ~2.5k tokens/day.

## 3. Reproducible probes (and what each can/cannot prove)

1. **Startup-cost instrument:** in a variant worktree, `claude -p "Reply with exactly: OK"
   --output-format json --max-turns 1`; sum `input_tokens + cache_creation_input_tokens +
   cache_read_input_tokens` on the `type:"result"` record (the CLI emits a message *array*, not a bare
   object). Near-deterministic (±33 tokens over 3 reps). Proves per-variant startup cost; cannot see
   *where* tokens sit — pair with a per-section byte breakdown.
2. **Behavioral A/B:** 12 probes (4 rule-routing / 4 recall / 4 refuted-decision traps) × 3 reps ×
   variant, fresh headless sessions, read-only tools (`--allowedTools Read Grep Glob`), `--max-turns 8`,
   graded against a rubric **frozen before the slim variant ran** (change `probes/README.md`). num_turns
   is the tool-call proxy (counts batches, not calls — documented limitation). Max-turns-cut runs are
   graded from the transcript's observable behavior (first-stated intent + tool trail), a protocol
   declared at baseline grading. Cannot prove long-horizon effects; samples the three failure lanes.
3. **Subagent-inheritance presence probe:** spawn a trivial subagent instructed to answer *without
   tools*: quote the line containing a marker string unique to AGENTS.md (verify uniqueness across all
   loadable context first). Verbatim quote + `tool_uses: 0` in the usage receipt = inheritance proven.
   (Transcripts do not record system prompts — the in-context probe is the only witness; same dead
   instrument documented in `claude-code-subagent-execution-forensics.md`.)
4. **Ablation arms:** single-deletion variants of the slim file (V2 = −status tables, V3 = −inoculation
   list) at reduced reps price each tier separately. Cannot price content no probe exercises — V2
   recorded exactly that gap for the tables.
5. **Dead end worth keeping:** worktree variants each get a **fresh** `~/.claude/projects/<path>` dir, so
   auto-memory is absent from all variants (parity holds). A V3 rep still quoting the memory file traced
   to an explicit disk `Read` it found by search — check the transcript before concluding an injection
   channel exists.

## 4. Results (dose-response; full grading in the change's `probes/results.md`)

| Variant | bytes | startup tokens | rule | recall | trap |
| --- | --- | --- | --- | --- | --- |
| V0 fat | 79,704 | 57,137 | 10/12 (R1 1/3) | 12/12 | 12/12 |
| **V1 slim (shipped)** | 28,132 | **35,589 (−21,548)** | **12/12** | 12/12 | 12/12 |
| V2 −tables | 25,346 | 34,252 | n/r | 8/8 | 8/8 |
| V3 −inoculations | 27,150 | 35,126 | n/r | n/r | **6/8 (T1 0/2)** |

- Recall medians (turns): C1 3→2, C2 1→1, C3 6→6, C4 1→4 (bound was +3) — slim answers were often
  *richer* (pointer-following surfaced p99 tables and canary counts the fat from-memory answers lacked).
- Subagent probe: a trivial no-tool spawn costs **49.3k tokens** at fat; workflows of 7–24 agents were
  paying ~230k–790k in AGENTS.md copies alone (~49k–170k at slim).

## 5. Retired theories (fates table)

| Theory | Fate | Killed by |
| --- | --- | --- |
| "The fat file's history makes behavior safer" | ❌ | V0 baseline: R1 (implement-now routing) 1/3 *at fat*; V1 3/3 — dilution hurt the rules it buried |
| "Recall needs history in context" | ❌ | V1/V2 recall 12/12 & 8/8 via pointers, equal-or-fewer turns, richer answers |
| "Slim is safe without inline refutations" | ❌ | V3 T1 0/2 ("Good instinct — … nothing to add") vs V1 3/3; ~40 tokens is the difference |
| "The status tables earn their recall keep" | ❓ unpriced | V2 16/16 — but no probe exercises open-change orientation (gap recorded); kept at ~1,320 tokens on orientation grounds |
| "MCP schemas are a big lever here" | ❌ (this client) | `/context`: deferred rows excluded from the total; ~50k already saved by deferral |
| "Worktree probes leak the main project's auto-memory" | ❌ | fresh per-path project dirs; the one memory quote was an explicit disk `Read` in the transcript |

## 6. Re-verify by effect

Run `/context` in a fresh session in this repo: the *Memory files* category should read **~12k tokens**
(slim AGENTS.md ~11.3k + CLAUDE.md + MEMORY.md), not ~33.5k. Headless equivalent: probe 1 above at repo
root vs `git show a9b3a47` worktree — expect ≈ −21.5k. Behavioral spot-check: paste any trap probe from
`openspec/changes/slim-agents-context/probes/probes.json` into a fresh session — the answer must state
the refutation, not endorse the trap.

## 7. Reusable guideline (generalizes to any always-loaded agent guide)

1. **An always-loaded guide is a per-token program, price it like one:** measure real density (not /4),
   measure per-section, watch the growth derivative — an append-per-change rule compounds.
2. **Split by half-life:** rules + orientation (snapshot, state table with pointers) stay loaded;
   narratives move verbatim to a non-loaded log, one `Read` away. Verbatim moves make review = "was
   anything dropped?" and rollback = one revert.
3. **Inoculate, don't just point:** expensively-learned refutations keep their *conclusions* inline
   (one line each). The failure mode is not-knowing-to-look; ~40 tokens/lesson is the cheapest
   insurance measured in this repo. Refutations with deep doc-homes survive without it; thin ones don't.
4. **Verify by effect against a pre-registered envelope:** startup-token gate from headless usage
   fields, plus a behavioral A/B (rule/recall/trap classes), baseline graded and frozen first — and
   measure the fat baseline rather than assuming it's perfect (here it wasn't, and the diet *fixed* it).
5. **Probe subagent inheritance before claiming (or ignoring) the multiplier** — a marker-quote
   presence probe with a zero-tool receipt settles it in one spawn.
6. **Cap the growth rule, not just the file:** completion updates are bounded (table row + appended
   narrative), or the diet unwinds at its measured daily rate.

## Sources

- `/context` outputs (2026-07-06, this session — fat file); git history of AGENTS.md (79 commits)
- Run evidence: `~/Downloads/xtty-vm-poc/artifacts/2026-07-06-slim-agents-probes/` (context/*.json,
  probes/<variant>/*.json, grading-*.md, ledger.log, subagent-inheritance-probe.md)
- Change artifacts: `openspec/changes/slim-agents-context/` (probes/README.md = rubric + envelope,
  probes/results.md = graded tables, design.md D1–D8)
- Prior art this builds on: `claude-code-subagent-execution-forensics.md` (in-context probe technique;
  transcripts-lack-system-prompts dead instrument)
