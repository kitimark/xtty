# slim-agents-context — probe suite, rubric, and pre-registered acceptance envelope

Pre-registered **before** any variant run (task 1.1). The envelope below is the gate for landing the
restructure on main; it is not adjusted after seeing results.

## Variants

| Variant | Definition |
| --- | --- |
| **V0** | fat AGENTS.md — main at the pre-restructure commit (baseline; also measured, per design D6 — not assumed perfect) |
| **V1** | slim AGENTS.md, all three status tiers (snapshot ¶ + table + inoculations) — **the shipping candidate; the only gated comparison is V0-vs-V1** |
| **V2** | V1 minus the status table (diagnostic — prices the table; recall class expected to drop) |
| **V3** | V1 minus the inoculation list (diagnostic — prices the inoculations; trap class expected to drop) |

Each variant runs as a **git worktree** (V0 detached at the fat commit; V2/V3 are V1 plus exactly one
deletion, so any probe delta is attributable). Worktree paths give each variant a fresh
`~/.claude/projects/<path>` — i.e. **no auto-memory in any variant, including V0** — so the comparison
is memory-parity-controlled.

## Instruments

1. **Context usage** (`measure-context.sh`): in the variant worktree, `claude -p "Reply with exactly: OK"
   --output-format json --max-turns 1`; startup context = `usage.input_tokens +
   usage.cache_creation_input_tokens + usage.cache_read_input_tokens` of that first turn. 3 reps.
   Cross-check on V0: the number must be consistent (±~1k) with the interactive `/context` reading
   recorded 2026-07-06 (AGENTS.md = 32.8k of a 33.5k Memory-files category) — i.e. V0 minus V1 must
   land near 32.8k minus the slim file's own token count. Disagreement beyond that is investigated
   before any variant comparison is trusted.
2. **Behavioral probes** (`run-probe.sh` + `probes.json`): each probe is a fresh headless session in the
   variant worktree — `claude -p "<prompt>" --output-format json --max-turns 8` with tools restricted to
   read-only (`Read`, `Grep`, `Glob`). No writes possible; a denied write attempt is itself gradeable
   signal. The JSON `result` text (and `num_turns`) is the grading input; full JSONs are kept as evidence.
3. **Tool-call proxy**: `num_turns` from the result JSON. The envelope's "≤2 extra tool calls" is
   operationalized as **median num_turns(V1) ≤ median num_turns(V0) + 3** per recall probe (one turn ≈ one
   tool batch; the final answer turn is constant across variants). Limitation acknowledged: num_turns
   counts batches, not individual calls.

## Repetitions

- Gated arms (V0, V1): all 12 probes × **3 reps**.
- Diagnostic arms: V2 recall+trap classes × 2 reps; V3 trap class × 2 reps (design D7 — they tune
  content, never gate; a 1-rep wobble triggers a re-run, not a conclusion).
- Context instrument: 3 reps per variant (expected near-deterministic; variance is a finding).

## Grading rubric

- Grade **only** from the run's own output (the `result` text + `num_turns`); quote the decisive
  sentence into the results table. Grader = the apply session, same rubric for every variant, V0 graded
  first and frozen before V1 is run.
- **rule/trap**: PASS only if the probe's `pass` criterion in `probes.json` is unambiguously met.
  Ambiguous, hedged-both-ways, or non-committal answers are **FAIL** (conservative, applied identically
  to all variants).
- **recall**: PASS requires the material facts correct (per the `pass` field); a partially-correct
  answer is FAIL. `num_turns` recorded for the envelope check.
- A probe rep that errors out (CLI failure, timeout) is re-run once and noted; two consecutive errors =
  recorded as infrastructure failure, excluded from grading (not counted as FAIL), and flagged.

## Pre-registered acceptance envelope (the gate for task 3.3)

1. **Context**: V1 startup context ≤ V0 startup context − **20,000 tokens** (instrument 1).
2. **Rule + trap classes**: for every probe, pass-count(V1, of 3) ≥ pass-count(V0, of 3). Zero
   regressions tolerated. A V1 trap failure is repaired by strengthening/adding that inoculation line
   and re-running **that probe** (3 reps) — never by restoring moved history; every fix + re-run is
   recorded in the results table.
3. **Recall class**: facts correct in ≥2/3 reps per probe, AND median num_turns within the +3 proxy
   bound (instrument 3).
4. A 2/3-vs-3/3 wobble on any gated cell triggers +2 reps on that cell before judgment (design risk
   register); a 0/3-vs-3/3 flip is signal as-is.

## Evidence layout

The audit layer is **committed** in `evidence/` next to this file (moved in from the machine-local run
dir after the apply, so the change is self-contained): `grading-v{0..3}.md` (the extraction sheets the
grades were made from), `context/<variant>-rep<N>.json` (the raw token-number source records),
`max-turns-tool-trails.md` (verbatim text+tool trails of the 7 `error_max_turns` runs graded from
behavior), `subagent-inheritance-probe.md` (the task-1.4 record), `ledger.log` + `*batch.log`
(provenance). `results.md` (one level up) is the graded table.

Only the **raw per-probe transcripts** (96 full message-array JSONs, ~3.7 MB) stay machine-local at
`~/Downloads/xtty-vm-poc/artifacts/2026-07-06-slim-agents-probes/probes/` — treated as ephemeral: every
graded fact is derivable from the committed layer, and fresh transcripts are regenerable in kind with
`run-batch.sh` + `probes.json`. Worktrees are ephemeral (removed post-landing).

## Subagent-inheritance probe (task 1.4, design D8)

Separate from the suite: an Agent-tool subagent in the fat checkout is asked — **without using any
tools** — to quote the exact line of its context containing a marker string that exists only in
AGENTS.md's history blob (marker: `probe-quoted verbatim` — chosen from the Current-status history text;
verify pre-run it appears nowhere else in loaded context). Verbatim quote = inheritance confirmed (the
multiplier arithmetic ships); "not present" = refuted (the negative result ships); ambiguous = the
multiplier claim is omitted entirely.
