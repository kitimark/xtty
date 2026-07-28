# slim-status-surface — probe suite, rubric, and pre-registered acceptance envelope

Pre-registered **before** any variant run (tasks 1.1 + 1.2; design D7). The envelope below is the
gate for task 4.3; it is **never adjusted after seeing results**. Precedent:
`openspec/changes/archive/2026-07-06-slim-agents-context/probes/` — its harness is reused here
(provenance below); its 2026-07-06 numbers are cited as precedent only, **never as a bar** — every
bar in this suite is computed against the freshly frozen N.

## Variants (design D7)

| Variant | Definition |
| --- | --- |
| **N** | frozen baseline — a throwaway git worktree **detached at `eaa765b`** (main at pre-registration time, *before* this probes/ directory was committed, so the pass criteria are not discoverable by any graded N session). Graded and frozen before any S content is authored anywhere. |
| **S** | the full restructure (AGENTS.md `## Current status` + packer Current-envelope block + tooling edits), authored in a worktree **only after** N is graded + frozen — **the only gated comparison is N-vs-S** |
| **A-R** | N + the refutation compression only (diagnostic — prices the compression alone) |
| **A-0** | S with the cross-model cluster **deleted** rather than merged (diagnostic — decides the merge floor, design D2) |

The **A-T** (pointerized-tables) arm is **dropped** per design D4/D7: the open-changes table is
kept, so there is no shipping shape for it to price.

Worktree isolation: each variant runs in its own worktree path, giving it a fresh
`~/.claude/projects/<path>` — **no auto-memory in any variant's context**, memory-parity-controlled.
Arm parity rule: N is pinned at the pre-probes commit; the S / A-R / A-0 worktrees MUST have
`openspec/changes/slim-status-surface/probes/` **removed** before any run (a graded session must
never be able to read its own pass criteria). The change's proposal/design/tasks artifacts are part
of main and therefore present in every arm (symmetric); a rep whose trail reads them is annotated
(see rubric).

## Instruments

1. **Context usage** (`measure-context.sh`, byte-for-byte from the archived suite): in the variant
   worktree, `claude -p "Reply with exactly: OK" --output-format json --max-turns 1`; startup
   context = `usage.input_tokens + cache_creation_input_tokens + cache_read_input_tokens` of that
   first turn. 3 reps per variant (variance is a finding).
2. **Behavioral probes** (`run-probe.sh` + `probes.json`): each probe is a fresh headless session in
   the variant worktree — `claude -p "<prompt>" --output-format json --max-turns 10`, tools
   restricted to read-only (`Read`, `Grep`, `Glob`) except the declared per-probe override (O1b adds
   `Bash`). A denied write attempt is itself gradeable signal. The CLI (2.1.220) emits the **full
   message array** for `--output-format json`, so per-rep tool trails ride the same artifact — used
   for max-turns grading and instrument 4.
3. **Tool-call proxy**: `num_turns` from the result JSON; the envelope's bound is
   **median num_turns(S) ≤ median num_turns(N) + 3** per recall/orientation probe. Limitation
   acknowledged: num_turns counts batches, not individual calls.
4. **Inline sufficiency** (new; gating for the merged cross-model cluster **X1/X2/G1** only): from
   the message array, a rep is **inline-sufficient** iff the **first assistant message** contains a
   text block stating the trap's refutation conclusion unambiguously **before any `tool_use` block
   in that message** — i.e. the refutation rode in from loaded context with **zero file reads**.
   Motivation: the archived suite proved traps can pass off secondary doc homes
   (`archive/2026-07-06-slim-agents-context/probes/results.md:89–91`), so a bare PASS does not
   evidence that the compressed line itself still inoculates.

## Repetitions

- Gated arms (N, S): all 22 probes × **3 reps**.
- Diagnostic arms (A-R, A-0): all probes × **2 reps** (task 4.2's dose-response table spans all four
  classes; the arms tune content, never gate).
- Context instrument: 3 reps per variant.

## Grading rubric

- Grade **only** from the run's own output (the `result` text + `num_turns` + the recorded tool
  trail); quote the decisive sentence into the results table. Grader = the apply session, same
  rubric for every variant. **Grading order (design D7, hindsight-bias control): probes + envelope
  committed first → N run, graded, frozen → only then S is authored/run → then ablations.**
- **rule/trap**: PASS only if the probe's `pass` criterion in `probes.json` is unambiguously met.
  Ambiguous, hedged-both-ways, or non-committal answers are **FAIL** (conservative, applied
  identically to all variants).
- **recall/orientation**: PASS requires the material facts correct (per the `pass` field); a
  partially-correct answer is FAIL. A correct figure alongside a false claim asserted as true is
  FAIL. `num_turns` recorded for the envelope check.
- A probe rep that errors out (CLI failure, timeout) is re-run once and noted; two consecutive
  errors = infrastructure failure, excluded from grading (not counted as FAIL), and flagged.
- A run cut at the 10-turn cap (`error_max_turns`) is graded from the transcript's observable
  behavior (tool trail + partial text), conservative on ambiguity; the annotation is recorded
  before any later arm is run.
- **Contamination annotation**: a rep whose trail reads this change's own artifacts
  (`openspec/changes/slim-status-surface/**`) is annotated in the grading sheet; if the decisive
  graded fact was obtainable **only** there (not from the guide, packer, HISTORY, or research
  docs), that is recorded next to the grade in the results table. The probes/ directory itself must
  be absent from every probed worktree (arm-parity rule above).
- **Memory annotation** (task 1.4): any rep whose trail reaches a file under `~/.claude/projects/`
  (an auto-memory file found by disk search — it cannot be context injection, per the worktree
  isolation) is annotated in the grading sheet.

## Pre-registered acceptance envelope (the gate for task 4.3 — never adjusted after results)

(a) **Context**: `startup(S) ≤ startup(N) − 0.85 × (bytes_removed_from_AGENTS.md / 2.49)`, with an
    **absolute floor of ≥3,000 tokens saved** (predicted ≈4.2k). Below the floor the guide half is
    reconsidered, not shipped (the packer block + F4 correction stand on their own merits).
    `bytes_removed_from_AGENTS.md` is measured at apply time between the S worktree's AGENTS.md and
    the N commit's AGENTS.md. A measured Δ disagreeing with the byte prediction by >15% is
    investigated before any behavioral comparison is trusted (task 3.6).
(b) **Rule + trap classes**: `pass(S, of 3) ≥ pass(N, of 3)` for **every** probe; **zero
    regressions** tolerated.
(c) **Recall + orientation classes**: facts correct in **≥2/3 reps** per probe AND
    **median num_turns(S) ≤ median num_turns(N) + 3** per probe (medians from the freshly frozen N
    below, never the 2026-07-06 figures).
(d) **Inline sufficiency, gating for the merged cross-model cluster (X1/X2/G1)**: **≥1 of 3 S-reps**
    refutes at turn 1 with zero file reads (instrument 4's definition). A miss un-merges that entry
    back toward its pre-merge conclusion — never restores narrative.
(e) **Wobble**: a 2/3-vs-3/3 flip on a gated cell triggers **+2 reps** on that cell before
    judgment; a 0/3-vs-3/3 flip is signal as-is.
(f) **Fix loop**: a trap failure is repaired by **restoring that one line's conclusion clause** and
    re-running **that probe** at 3 reps — **never** by restoring narrative; **cap 2 iterations**,
    after which that entry ships at full length (G-TARPIT-6/7 applies to this loop too). Every fix +
    re-run is recorded in the results table.

## Pre-flight mechanical grep (task 3.6, before any S behavioral run)

Grep the new packer Current-envelope block for **`260/0/0` · `57/0/1` · `58` · `54/0/1`** — the
envelope-retrieval probes (E1/C1) cannot otherwise distinguish "pointer broken" from "guide broken".
(`54/0/1` added to this list at pre-registration, per task 1.1's C1 correction.)

## Evidence layout

Committed next to this file: `ledger.log` (provenance: CLI version, probe model, N commit,
launch/err records), `grading-N.md` / `grading-S.md` (extraction sheets the grades were made from,
with tool-trail annotations), `results.md` (the graded tables; the N section is **frozen** at task
1.3), `context/<variant>-rep<N>.json` (raw token-number source records), and — for the S phase —
`max-turns-tool-trails.md` + `inline-sufficiency.md` (task 4.1). The raw per-probe transcripts are
machine-local (regenerable in kind via `run-batch.sh` + `probes.json`); every graded fact is
derivable from the committed layer. Worktrees are throwaway.

## Harness provenance and declared edits

Copied from `openspec/changes/archive/2026-07-06-slim-agents-context/probes/`:
`measure-context.sh`, `run-batch.sh`, `extract-results.py` **byte-for-byte**; `run-probe.sh` with
exactly the **two declared edits**, applied identically to every arm (design D7):

1. turn cap **8 → 10** (`--max-turns`);
2. a **per-probe `tools` override** read from `probes.json` (defaults identical to the archived
   suite: allowed `Read Grep Glob`, disallowed `Write Edit Bash Task WebSearch WebFetch`); used
   only by the Bash-enabled orientation probe **O1b**.

CLI at pre-registration: `claude --version` = **2.1.220 (Claude Code)** (recorded in `ledger.log`);
probe-session model `claude-sonnet-5` (from the result JSON init record). Verified by smoke test
2026-07-28: this CLI's `--output-format json` emits the full message array the archived parsers
already handle (`isinstance(d, list)`), so no further harness edit was needed for trails.
