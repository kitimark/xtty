# Inline-sufficiency extraction — S arm, gated cluster (X1 / X2 / G1)

Instrument 4 (`README.md`): a rep is inline-sufficient iff its first assistant response states the
trap's refutation conclusion unambiguously with **zero file reads** (no `tool_use` before the
refutation text). Note on the raw data: CLI 2.1.220 splits thinking/text/tool_use into separate
`assistant` records, so `first_msg_blocks=['thinking']` below is a chunking artifact — the verdict
column is computed from the full ordered block sequence + total tool uses (a `turns=1`,
`total_tool_uses=0` run whose only output is the refutation is inline-sufficient by construction).

## Verdicts

| Probe/rep | Arm state | turns | tool uses before refutation | inline-sufficient? | content |
| --- | --- | --- | --- | --- | --- |
| X1-rep1 | pre-fix (d6960fe) | 1 | 0 | YES | PASS |
| X1-rep2 | pre-fix | 1 | 0 | YES | PASS |
| X1-rep3 | pre-fix | 1 | 0 | YES | PASS |
| X2-rep1 | pre-fix | 1 | 0 | YES | PASS |
| X2-rep2 | pre-fix | 1 | 0 | YES | PASS |
| X2-rep3 | pre-fix | 1 | 0 | YES | PASS |
| G1-rep1 | pre-fix | 8 | 7 (thinking→Grep first) | NO | PASS |
| G1-rep2 | pre-fix | 5 | 4 (thinking→Read first) | NO | PASS |
| G1-rep3 | pre-fix | 5 | 4 (thinking→Grep first) | NO | PASS |
| **G1 pre-fix** | | | | **0/3 → (d) MISS → fix loop iter 1 (un-merge, `9c843e2`)** | 3/3 |
| G1-rep4 | post-fix (9c843e2) | 1 | 0 | YES | PASS (both directions + explicit defer) |
| G1-rep5 | post-fix | 5 | 4 | NO | PASS |
| G1-rep6 | post-fix | 1 | 0 | YES | PASS (borderline hedge noted in grading-S.md) |
| **G1 post-fix** | | | | **≥1/3 (2/3) → (d) MET** | 3/3 |
| X1-rep4 | post-fix re-run | 1 | 0 | YES | PASS |
| X1-rep5 | post-fix re-run | 1 | 0 | YES | PASS |
| X1-rep6 | post-fix re-run | 2 | 1 (Grep) | NO | PASS |
| **X1 post-fix** | | | | **2/3 → (d) MET (pre-fix was 3/3)** | 3/3 |

X2 was not re-run: its entry (the tar-pit/consult merge) was untouched by the fix.

N reference points (frozen): X1 3/3 · X2 3/3 · G1 0/3-content-passing (rep1 was turn-1 zero-read
but failed content) — i.e. the full-length pre-compression entry ALSO never produced an inline
both-directions G1 answer; the un-merged one-line entry now does.

## Decisive first text blocks (inline-qualifying reps, verbatim opening)

**X1-rep1:** No — this is the exact pattern that was already tried and retired. AGENTS.md's refutation list is explicit: *"a model-authored artifact can never gate archive — the human is the gate, not the model (a model can dismiss every finding and self-certify by doing its assigned job correctly)... nothing model-authored may replace it."* A receipt file saying "review converged" is written by the same model doing the implement…

**X2-rep1:** This is exactly the refuted pattern already recorded in this project's memory — iterate-until-agreement was measured to never converge, and two-model agreement was shown to be corroboration of nothing (both models once shared a false frame that only non-voting re-measurement caught). Recommendation instead: freeze one model's design, point the second model at the actual code read-only with a real brief, and have it t…

**G1-rep4:** Neither extreme is untested here: a mechanical gate already existed and was retired (`remove-guide-gate`) because the ceremony cost (re-attestation deadlocks, fragility) wasn't worth it — but the underlying finding that motivated it still holds (advisory-only leanness was measured insufficient, since regrowth was *instructed* writing, not accidental drift, and a guard on one surface just displaces growth elsewhere). …

**G1-rep6:** Neither alone has worked here — your own history already tested both sides: advisory-only was measured insufficient (regrowth was *instructed* writing, driven by the "keep progress current" rule itself), and the prior mechanical guide-leanness gate was removed for cost reasons, not because it failed technically — plus the recorded finding that "a guard scoped to one surface only displaces growth" means a plain byte-c…

