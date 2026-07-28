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

> **Forward pointer (2026-07-28):** the amended rule bounded *narratives* but not the status surface
> itself — `## Current status` regrew to 22,613 B (50.3% of the guide) within 22 days, concentrated in
> the Learned-refutations tier. The measured record, the regrowth mechanism, and the resulting
> `slim-status-surface` proposal are in **Addendum A** at the end of this file; the shipped change's
> graded probe campaign (gate PASSED, S′ 62/66 vs N 56/66) is in **Addendum B**.

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
- Run evidence (committed): `openspec/changes/slim-agents-context/probes/evidence/` — grading sheets,
  context-run JSONs, max-turns tool trails, the subagent-probe record, ledger. Only the raw per-probe
  transcripts (~3.7 MB) were left machine-local (ephemeral; regenerable via the committed
  `run-batch.sh` + `probes.json`)
- Change artifacts: `openspec/changes/slim-agents-context/` (probes/README.md = rubric + envelope,
  probes/results.md = graded tables, design.md D1–D8)
- Prior art this builds on: `claude-code-subagent-execution-forensics.md` (in-context probe technique;
  transcripts-lack-system-prompts dead instrument)

---

## Addendum A (2026-07-28) — the Current-status regrowth, measured; `slim-status-surface` proposed

**Provenance:** 2026-07-28, produced by a multi-pass research fan-out — five read-only research passes
(refutation-compression audit · spec-delta/tooling enumeration · packer-acceptance redesign · probe plan ·
Current-status redesign) plus a change-assembly pass and a **non-voting audit** that re-derived every
disputed load-bearing claim from the repo before judging (per this repo's G-CONSULT re-measurement rule).
All byte figures below were re-measured against the tree at commit `4903359`
(`docs(openspec): propose slim-status-surface`). The fan-out's per-pass outputs lived in the session's
`/tmp` scratchpad — **ephemeral workflow output, not a durable record**; the durable record is this
addendum plus the change artifacts in `openspec/changes/slim-status-surface/`. Status at capture time:
**proposal only** (0/26 tasks — nothing has been implemented, and the live defects named below are still
live in the repo).

### A.1 What happened

Net trajectory: AGENTS.md 28,132 B (the 2026-07-06 §2 slim endpoint) → **44,996 B** (2026-07-28), +16,864 B
in 22 days ≈ 0.77 KB/day *net of two intervening diet/regrow cycles* (recorded in
`agents-md-structural-best-practices.md` §A — this is at least the third regrowth of this file). The
regrowth is concentrated in exactly one section, sliced at `4903359`:

| Slice (AGENTS.md lines) | Bytes | Share |
| --- | --- | --- |
| `## Current status` (L9–69) | 22,613 | 50.3% of the file |
| Learned refutations (L36–69, 31 entries avg ~88 words) | 17,367 | 38.6% of the file |
| — of which the cross-model/guide-gate cluster (L60–69, 10 entries) | 7,212 | 41.5% of the list |
| Shipped table (L23–32) | 3,074 | — of which the `Tooling` row (L32) = 1,773 B (58%) |
| Snapshot (L11–15) | 1,716 | |
| Open-changes table (L17–21) | **298** | 1.3% of the section |

✅ The ratified bound already forbids most of this: `openspec/specs/research-capture/spec.md:48` requires
refutations as "inline **one-line** statements" (20 of 31 entries exceed it) and perpetual rows
category-keyed (the Tooling row is a per-change mini-index). The regrowth is the rule's *shape* being
under-specified, not the rule being absent.

### A.2 Mechanism — why it regrew (three shapes, each with a live exhibit)

1. **Append-on-retirement, with no in-place-edit rule.** When `remove-cross-model-review` retired the
   mechanism a refutation was measured on, it *appended* a retirement entry instead of editing the entry it
   retired — `AGENTS.md:60` ⊃ `:69` are near-verbatim (805 B recoverable at zero information loss), and the
   whole 10-entry cluster restates one saga. Nothing today forbids the append, so every retirement *grows*
   the index.
2. **A perpetual row that became a mini-index.** The shipped table's `Tooling` row accreted a per-change
   clause + doc pointer on every archive — 1,773 B, 58% of its table — despite the category-keyed bound.
   (Same shape `agents-md-structural-best-practices.md` diagnosed in 2026-07-11; the guard shipped there
   held for the row it watched while growth moved to the refutations tier — displacement, again.)
3. **Cached state with no rule forbidding the cache — and it silently went false.** The snapshot transcribes
   the measured test envelope. At capture time **three copies carry the same wrong claim**: `AGENTS.md:14`
   ("the prior 56-test envelope was identical across all 5 environments"), `HISTORY.md:64` ("their prior
   56-test envelope remains the cross-environment baseline"), and `packer/README.md:667` ("VM tiers retain
   the prior 56-test accepted envelope"). ❌ False: `packer/README.md:644–648` records that the change adding
   the 56th test (`add-git-diff-wrap-toggle`) **never ran the VM tiers**. The last genuinely
   5-environment-identical measurement is the **55**-test `54/0/1` (2026-07-10), so the VM tiers are **3
   tests behind across 2 changes** (`add-git-diff-wrap-toggle` + `fix-large-diff-memory-bound`), not 2
   behind across 1. The duplication detected nothing — all three copies drifted *together*. Worse, the
   nominal pointer home is itself unusable: `packer/README.md` → `### Acceptance` *leads* with a figure six
   supersessions stale (`Envelope: 40/1/1 of 42`, `:299`), the current figures sit in a blockquote ~350
   lines down (`:650–668`), and the only string reading "current authoritative envelope" (`:603`) points at
   a superseded figure.

### A.3 Reproducible probes (what each proves and cannot prove)

- **Byte slicing** (all re-run for this addendum; line ranges valid at `4903359`):
  `wc -c AGENTS.md` → 44,996; `sed -n '9,69p' AGENTS.md | wc -c` → 22,613; `sed -n '36,69p' … | wc -c` →
  17,367; `sed -n '60,69p'` → 7,212; `sed -n '17,21p'` → 298; `sed -n '32p'` → 1,773; `sed -n '11,15p'` →
  1,716. Proves sizes objectively (and corrected one pass's 357 B table figure to the measured 298 B);
  proves **nothing** about whether content is safe to remove.
- **"Safe to compress" is not byte-derivable — it was cross-checked entry-by-entry, not assumed.** For each
  of the 31 refutation entries, the named pointer target was opened and confirmed to (a) exist and
  (b) actually contain the mechanism the compression drops (28 distinct file pointers + section anchors;
  per-entry verdicts in the compression audit, spot re-derived by the non-voting audit). This is the step
  that found two pointer defects a byte-only pass would have shipped: the "instructed writing" claim cited
  `agents-md-structural-best-practices.md`, which has **0** occurrences of "instructed" (real home
  `HISTORY.md:121`), and the `env-seed-wall` entry's only other home is one blockquote inside a 96 KB doc.
- **Orphan checks by grep:** `grep -rn wheel1 AGENTS.md HISTORY.md packer/README.md research/ AppUITests/`
  → exactly `AGENTS.md:56` + `App/PaneController.swift:578` (an *undocumented use*), confirming the
  `CGEvent` sign-inverse fact is documented nowhere but the guide (so it must be rehomed before its entry
  compresses). The same instrument *refuted* a sibling claim — see the fates table.
- **Planned (not yet run) verification instrument:** the archived
  `openspec/changes/archive/2026-07-06-slim-agents-context/probes/` harness (`measure-context.sh`,
  `run-probe.sh`, `run-batch.sh`), reused with two declared arm-symmetric edits (turn cap 8→10; a per-probe
  tools override) plus a new **inline-sufficiency** instrument — did the refutation land at turn 1 with
  zero file reads — because the archived `results.md:89–91` proved traps can pass off *secondary doc
  homes*, so a bare PASS no longer evidences the spec's "not as bare pointers" clause. Pre-registered
  envelope: ≥3,000-token floor, zero trap regressions, 2-iteration fix cap. ❓ Results did not exist at
  this addendum's capture — they now do: **Addendum B** below records the full graded campaign.

### A.4 Fates table — retired options and corrected claims

| Theory / claim | Fate | Killed by |
| --- | --- | --- |
| "The shipped table is fully redundant with `research/04-design/02-milestones.md` — delete it" | ❌ | The milestones file is 51 KB, stale and self-contradictory on later items, and misses post-P7 work entirely; the 5 phase rows are the *useful compression of it*, and deleting the table would leave `coherence-review`'s category-keyed check (`:30–33`) with nothing to police. Kept; only the Tooling row collapses. |
| "The open-changes table should become a derive-on-demand pointer (`openspec list`)" | ❌ deferred, not adopted | The one cross-pass fork the audit had to resolve: two parallel passes committed to opposite arms (change-assembly drafted a SHALL-NOT-transcribe spec delta + a restore-the-table contingency; the redesign kept the table and measured the entire draft spec-compliant *as-is*). Pointerizing is the only element requiring both a spec-requirement change and a never-tested probe class (O1 orientation) — to save 298 B. Resolution: keep the table; revisit only on observed friction (the O1 probes stay designed). |
| "`smkx` is orphaned — AGENTS.md is its only home" (compression-audit risk R3) | ❌ | `grep`: `HISTORY.md:318` and `AppUITests/XttyMouseWheelUITests.swift:213` both carry it. The error was made by one research pass, caught by a later pass, and confirmed by the non-voting audit's own re-grep. (Contrast: the sibling `wheel1` sign-inverse orphan claim **survived** the identical re-check — the verification discriminated rather than blanket-judging.) |
| Probe C1's drafted pass criterion (`41/0/1` of 42 as the current VM envelope) | ❌ | The packer figure inventory: `41/0/1` is the 2026-07-08 figure, superseded by 2026-07-10's `54/0/1` of 55 — C1 as drafted would have **failed a correct answer**. Fixed at assembly: the shipped `tasks.md` 1.1 orders the correction before the baseline freeze. |
| Predicted saving "13–15 KB / 5.2–6.0k tokens" (probe plan) | ❌ | Re-derived byte math: −10,275 B measured on the paste-ready draft ≈ 4.2k tokens at 2.46 B/token. Still clears the pre-registered ≥3,000-token floor with ~39% headroom — the estimate was wrong, the decision it fed survives. |
| "Duplicating the envelope across AGENTS.md/HISTORY.md/packer is a drift detector" | ❌ | A.2 exhibit 3: all three copies drifted together into the same false 56-test claim; the redundancy detected nothing. |
| "The compressed refutations still inoculate" | ❓ → ✅ (Addendum B) | Gated, not assumed: the archived V3 arm's T1 0/2 regression is exactly the risk; the pre-registered trap probes + inline-sufficiency criterion decided it when the change's §4 ran — zero trap regressions, S′ 62/66 vs N 56/66 (B.2), with one inline-sufficiency miss repaired by the bounded fix loop (B.3). |

### A.5 Re-verify by effect

- **Now (pre-implementation):** `grep -n "56-test" AGENTS.md HISTORY.md packer/README.md` still returns the
  false claim at all three sites — the defect is live until `slim-status-surface` task 2.3 lands. If that
  grep comes back clean, the correction shipped.
- **Once the change lands:** (1) `wc -c AGENTS.md` should read ≈10.3 KB below the 44,996 B recorded here,
  with the `## Current status` section at ≈12.3 KB vs the recorded 22,613 B; (2) re-run the archived
  harness's `measure-context.sh` (3 reps) against a `4903359` worktree — the Δ must satisfy the
  pre-registered `0.85 ×` formula and the ≥3,000-token floor; (3) the graded trap probes (T1 retries; the
  merged cross-model cluster under the turn-1 zero-read criterion) must be ≥ the frozen N baseline;
  (4) `packer/README.md` → Acceptance must open with the Current-envelope table carrying per-tier
  `CURRENT | STALE (n behind)` tokens and the corrected 3-tests-behind statement. Never grade this by
  reading the diff — the headline claims are token and behavior deltas, and (2)–(3) are the only
  instruments that measure them.

### A.6 Reusable guidelines (continuing §7)

7. **N cached copies of one measurement drift together, not apart — a cache is a drift-detector only if at
   least one copy is independently re-measured.** Three copies of the envelope claim agreed on the same
   wrong answer for three tracker generations; nothing re-measured, so nothing disagreed. Keep exactly one
   measured home that states its current answer plainly and up front; every other surface points at it and
   caches nothing.
8. **An always-loaded curated index needs an edit-in-place rule for retirement, not just a size bound.**
   Retiring a mechanism by *appending* a retirement entry grows the index precisely when the system shrinks
   — 41.5% of the refutations tier was one saga restated by successive appends, each individually
   compliant with a bound that only capped entry length, never entry count per finding.

### A.7 Artifacts

- **The resulting proposal:** `openspec/changes/slim-status-surface/` (proposal.md · design.md ·
  `specs/research-capture/` delta · tasks.md, 26 tasks), committed at `4903359`
  (`docs(openspec): propose slim-status-surface`). The proposal's Why/What sections restate the A.1–A.2
  measurements as the change's motivation; its tasks 2.2–2.6 build the packer Current-envelope block, 3.1–3.2
  the compressed section, 1.1–1.3 + 4.1–4.3 the probe gate.
- **Precedent + harness:** `openspec/changes/archive/2026-07-06-slim-agents-context/` (the probes/ directory
  this plan reuses; its `results.md` V2/V3 arms are the evidence base for compress-don't-delete).
- **Companion regrowth record:** `research/03-analysis/agents-md-structural-best-practices.md` §A (the
  second regrowth + the surface-scoped-guard-displaces-growth finding; historical).
- The fan-out's working files (per-pass outputs + audit) were session-scratchpad `/tmp` artifacts and are
  **not** durable; every load-bearing number from them was re-verified against the repo before entering
  this addendum, which supersedes them.

**Sources (addendum):** repo reads and greps at `4903359` (commands in A.3); `openspec list`;
`openspec/changes/archive/2026-07-06-slim-agents-context/probes/results.md`; `packer/README.md`
`:295–712`; `openspec/specs/research-capture/spec.md`.

**Companion doc (2026-07-28):** [Agent-guide ingestion across CLI vendors — forensics](agent-guide-ingestion-forensics.md)
measures a different axis of the same guide: not its token *cost* (this doc), but what *fraction of it
even reaches* a non-Claude agent CLI. Headline: Codex silently truncates at a documented 32,768 B default
(27.8% of the guide dropped, measured at a 45,362 B snapshot) and Antigravity at ~23,450–24,150 B (~48% dropped, and 0%
without an explicit project registration) — both silent, neither warns. Recommends a non-gating byte
target for `slim-status-surface` (≤32,768 B), not a probe-campaign gate.

---

## Addendum B (2026-07-28) — `slim-status-surface` shipped: the probe campaign, graded

**Provenance:** 2026-07-28, produced by the `slim-status-surface` apply session (single main session +
132 headless `claude -p` probe runs across 4 arms + 8 fix-loop re-runs; CLI 2.1.220, probe model
`claude-sonnet-5`). All numbers measured against the pre-registered envelope frozen in the change's
`probes/` directory **before any S content was authored** (N graded and frozen first, per the §7.4
precedent). Grading sheets, results tables, context JSONs, tool trails, and the inline-sufficiency
extraction are committed in the change dir (`openspec/changes/slim-status-surface/probes/` — under
`openspec/changes/archive/` once the change archives); raw per-probe transcripts are machine-local and
regenerable via the committed `run-batch.sh` + `probes.json`.

### B.1 What shipped, and the corrected "from" figure

The restructure landed on `main` as three commits: **commit 1** (`3a48509`) the packer
Current-envelope truth block + the F4 false-claim correction + the `wheel1` rehome; **commit 2**
(`38c9af1`) the replacement `## Current status` + the amended *Keep progress current* rule + the three
coupled tooling files (critic v8, capture skill 1.3); **commit 3** this capture + tracker reconcile.

The size actually compressed FROM is **46,234 B** (AGENTS.md at `eaa765b`, the frozen N baseline) —
not A.1's 44,996 B, which was correct at the propose commit `4903359` but went stale when the
agent-guide-ingestion refutation entry (+1,238 B) landed between propose and freeze. Corrected curve:
**28,132 B (2026-07-06) → 46,234 B (2026-07-28) = +18,102 B in 22 days ≈ 0.82 KB/day** — the third
regrowth of this file, again concentrated in `## Current status` (A.2's three mechanisms: the
append-on-retirement cluster, the Tooling mini-index row, and the cached envelope whose three copies
drifted together into one false claim — the last fixed at the source by commit 1's single-truth block).

Shipped shape (measured on `main` at `38c9af1`): file **37,373 B** (−8,861); `## Current status`
23,851 → **14,250 B**; the refutations list 32 → **26 bounded entries** (11 kept byte-for-byte incl.
the frozen retry-ban entry, 10 compressed to conclusion + applicability + pointer, 10 merged to 3,
+1 pre-freeze ingestion entry kept, +1 fix-loop un-merge — see B.3). Slicing probes:
`awk '/^## Current status$/{f=1} /^## Repository structure$/{f=0} f' AGENTS.md | wc -c` → 14,250;
same pattern from `/^\*\*Learned refutations/` → 10,122 (the surviving list incl. header).

### B.2 Results against the frozen envelope (gate PASSED)

Context instrument (3 reps/arm; startup tokens per §3.1's instrument):

| Arm | AGENTS.md bytes | Startup (median) | Δ vs N |
| --- | --- | --- | --- |
| N (`eaa765b`) | 46,234 | 55,028 (deterministic ×3) | — |
| **S′ shipped** (`9c843e2` ≙ main `38c9af1`) | **37,373** | **51,779** | **−3,249** |
| A-R (compression only) | 38,116 | 52,139 | −2,889 |
| A-0 (cross-model cluster deleted) | 34,300 | 50,626 | −4,402 |

Gate (a): formula bar `55,028 − 0.85×(8,861/2.49) = 52,003` ≥ 51,779 ✓; absolute floor Δ 3,249 ≥
3,000 ✓; byte-prediction disagreement 8.7% < 15% ✓. **Honest variance finding:** post-fix S′ reps
spread 352 tokens (52,098/51,779/51,746 — N and pre-fix S were rep-deterministic); the worst rep's Δ
is 2,930, *below* the floor, and the pass is on the median per the instrument's pre-registered 3-rep
design. Recorded, not hidden.

Behavioral (per-probe bar `pass(S) ≥ pass(N)`, 3 reps each): **S′ 62/66 vs N 56/66 — zero
regressions** (rule 11/12 vs 9/12 · recall 14/15 vs 12/15 · orientation 9/9 vs 9/9 · trap 28/30 vs
26/30). The two cells the change was built to fix both moved **1/3 → 3/3**:

- **E1 (current-envelope recall) — the F4 poison measured live, then measured fixed.** At N, 2 of 3
  reps answered the asked figures correctly *and* repeated the guide's false "56-test envelope
  identical across all 5 environments" cache as fact (FAIL under the pre-registered
  correct-figure-beside-asserted-falsehood rule). At S′, all 3 reps pulled the figures from the packer
  Current-envelope table via the pointer and none repeated the claim — two independently cited it as
  the corrected falsehood.
- **G1 (guide-gate both-directions) — the merged entry under-delivered until un-merged.** N's
  full-length two-entry prose managed only 1/3 under a direct question (one rep flatly recommended a
  mechanical gate — the criterion's literal FAIL); S′ post-fix went 3/3. The baseline was not assumed
  perfect, and wasn't (the §4 V0 precedent again).

**N's other failures, recorded not cherry-picked:** R1 2/3 (one rep surveyed code with zero OpenSpec
mention — the archived FAIL shape), R3 1/3 (one invented `fix(core)` scope, one cap-cut with no
message), T5 1/3 — and T5 stayed 1/3 at S′ with a **recorded probe-design defect**: the prompt
straddles a genuinely-working arm (`launchEnvironment["SHELL"]` does reach `resolveShellPath` for
shell *selection*, verified against source, while the seed wall strips child-env vars), so the frozen
criterion's letter fails a partly-correct two-mechanism answer. Applied identically to every arm for
comparability; T5 measures inoculation-recitation, not pure correctness. C4 dipped 3/3 → 2/3 (one
cap-cut no-verdict rep); the pre-registered wobble rule fired +2 reps → 4/5, benign.

### B.3 The inline-sufficiency instrument, and the one fix-loop iteration

**The instrument:** for the merged cross-model cluster (X1/X2/G1), a PASS also requires ≥1 of 3 reps
stating the refutation **in its first assistant message with zero tool calls**. What it proves: the
always-loaded surface alone carries the inoculation. What it cannot prove: anything about a rep that
researches first and then answers correctly (that shape is exactly how a trap passes off a *secondary
doc home* — archived `results.md:89–91` — so a bare content-PASS never evidences the spec's "not as
bare pointers" clause). It is a per-probe gate on the most-compressed entries only.

**The one iteration (cap 2, used 1):** pre-fix G1 content was 3/3 but inline sufficiency **0/3** —
every rep researched before answering. The pre-registered named contingency was applied exactly:
un-merge the guide-gate both-directions conclusion out of the merged self-certification entry back to
two bounded one-liners (+126 B, 25 → 26 entries, probe-arm commit `9c843e2`), **no narrative
restored**. Re-run: G1 content 3/3, inline 2/3 ✓; X1 (whose entry also changed shape) re-run 3/3,
inline 2/3 — no regression introduced. Context re-measured (the B.2 S′ row).

### B.4 Ablation dose-response — attribution, and the A-0 verdict on compress-vs-delete

| Arm | bytes | startup (med) | rule | recall | orientation | trap |
| --- | --- | --- | --- | --- | --- | --- |
| N | 46,234 | 55,028 | 9/12 | 12/15 | 9/9 | 26/30 |
| A-R (compression only) | 38,116 | 52,139 | 7/8 | 9/10 | 6/6 | 18/20 |
| S′ (full restructure) | 37,373 | 51,779 | 11/12 | 14/15 | 9/9 | 28/30 |
| A-0 (cluster deleted) | 34,300 | 50,626 | 7/8 | 10/10 | 6/6 | 18/20 |

- **E1's fix is the packer block + pointer, not the compression:** A-R (which keeps N's cached
  snapshot) still taught the false claim (1/2, N's rate); S′ and A-0 (pointer + single-truth block)
  produced zero false claims.
- **A-0 refutes delete-instead-of-merge at cluster granularity — the merge floor holds.** With the
  cross-model cluster deleted, G1 collapsed to **0/2** (both reps flatly recommending a mechanical
  gate — the V3-class regression reproduced one level down), while X1/X2 "passed" 2/2 **off secondary
  homes** (archived change artifacts, historical docs) at 4–5 turns vs S′'s turn-1 — exactly the
  false-certification shape the inline-sufficiency instrument exists to catch. D2's rejected
  alternative stays rejected; no further compression of the cluster is warranted.
- **A-R's compressed-but-present cluster held G1 at 2/2** — compression preserves the inoculation;
  only deletion breaks it.

### B.5 Fates table — retired options, next to what killed them

| Theory / option | Fate | Killed by |
| --- | --- | --- |
| Pointerize the refutations (a `REFUTATIONS.md` / bare pointers) | ❌ | Two ratified specs forbid it (`research-capture:86`, `agent-guide-parity:9`) + the archived V3 T1 0/2 — and now A-0's G1 0/2 at cluster granularity (B.4). |
| Delete the cross-model cluster outright (the A-0 arm) | ❌ | G1 0/2 with secondary-home X1/X2 passes certifying nothing (B.4); merged-to-3 ships instead. |
| Delete the shipped table | ❌ | Would leave `coherence-review:30–33`'s category-keyed check vacuous; the 5 phase rows are the useful compression of a stale 51 KB milestones file (A.4). Only the Tooling row collapsed. |
| Pointerize the open-changes table | ❌ deferred, not adopted | A spec-text change + an untested probe class to save 298 B (A.4); kept as a table, revisit on observed friction. |
| "The 2026-07-06 measured numbers can serve as this campaign's bar" | ❌ | Different CLI/cap/model; every bar was computed against the freshly frozen N (which scored 56/66 — not the archived baseline's shape). |
| "The baseline is presumptively clean; only S needs grading care" | ❌ | N failed E1 1/3 (teaching the false envelope claim as fact), G1 1/3, T5 1/3, R3 1/3 — the diet again *fixed* measured defects rather than risking regressions against a perfect fat file. |
| "T5 measures env-seed-wall correctness" | ❌ (recorded defect) | The prompt straddles a genuinely-working arm (`ShellResolver` consumes the app's own `$SHELL` before the seed wall); frozen-letter grading kept arms comparable but the cell measures recitation (B.2). |
| "Startup measurement is rep-deterministic, judge any single rep" | ❌ | Post-fix S′ spread 352 tokens across reps (cache-creation split); the worst rep sits 70 under the floor while the median clears it by 249 — judge the median of 3, and say so (B.2). |

### B.6 Re-verify by effect

1. **Size:** `wc -c AGENTS.md` ≈ 37.4 KB; the B.1 `awk` slices ≈ 14.3 KB section / ≈ 10.1 KB list.
2. **Cost:** re-run the change's `probes/measure-context.sh` (3 reps, median) in a worktree at the
   shipped commit vs one at `eaa765b` — expect a median Δ ≈ 3.2–3.4k startup tokens (±~350 rep
   variance; the gate formula and floor are in the committed `probes/README.md`).
3. **Behavior (the headline claim):** in a fresh session, ask the E1 question ("what is the current
   measured test envelope and where is its authoritative home?") — the answer must come from
   `packer/README.md` → Acceptance → Current envelope via the guide's pointer and must state the
   56-test/5-environment claim only as a corrected falsehood, if at all. Then ask a G1-shaped
   question — the answer must state both directions (advisory measured insufficient; don't re-propose
   a mechanical gate without new evidence). Never grade this change by reading its diff.
4. **The correction:** `grep -n "56-test" AGENTS.md HISTORY.md packer/README.md` — every surviving
   occurrence states the claim as false/corrected, none asserts it.

### B.7 Reusable guidelines (continuing A.6)

9. **Gate a guide compression per-probe against a freshly frozen baseline — and expect the baseline
   to fail somewhere.** Aggregate scores hide a swapped failure; `pass(S) ≥ pass(N)` per probe caught
   what a 62-vs-56 total alone could not, and N's own failures (E1, G1) were the change's strongest
   evidence: both diets in this doc's record *fixed* measured baseline defects.
10. **A trap PASS off a secondary doc home certifies nothing about the loaded surface — instrument
    inline sufficiency for the most-compressed entries, and repair a miss by un-merging one conclusion
    line, never by restoring narrative.** A-0's X1/X2 2/2-with-research beside G1's 0/2 collapse is
    the measured proof both directions; the bounded fix cost +126 B and one re-run.

**Sources (Addendum B):** `openspec/changes/slim-status-surface/probes/` — `results.md` (frozen N
baseline + S/ablation tables + the envelope judgment), `grading-N.md` / `grading-S.md` /
`grading-ablations.md` (extraction sheets), `README.md` (rubric + pre-registered envelope),
`inline-sufficiency.md`, `max-turns-tool-trails.md`, `context/` JSONs, `ledger.log`; repo
measurements at `eaa765b` / `9c843e2` / `38c9af1` (commands inline above).
