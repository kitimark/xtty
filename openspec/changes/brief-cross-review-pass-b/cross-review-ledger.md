# Cross-review ledger — `brief-cross-review-pass-b` (the A' dogfood)

> **Advisory in its entirety. Gate-inert.** Nothing here gates archive. This ledger records the change's
> own dogfood: `/xtty:cross-review`'s Pass B was run on this change **both blind and briefed (A')**, to
> test — by effect, on the change itself — whether the brief the change adds actually sharpens the review.

## Header

| Field | Value |
| --- | --- |
| **Reviewed range** | base `B = 8108081` (parent of the propose commit) .. HEAD `155feb7` — 6 files |
| **Scope (mechanical)** | **`exit 0`** — a *live demonstration of the retrospective-classifier finding* (F4): this change **will** be in scope once its `.claude/` edits land, but at propose time only its allowlisted artifacts exist. Human launched anyway. |
| **Passes run** | Pass B (Codex `gpt-5.6-sol`) **twice on the identical range**: RUN 1 blind (no brief), RUN 2 briefed (A'). Both `adversarial-review`, hardcoded read-only. xtty **CLEAN** after both. |
| **Purpose** | Dogfood the A' fix on the change that proposes it. |

## The contrast — what the brief did, and what it cost

| | RUN 1 — BLIND | RUN 2 — BRIEFED (A') |
| --- | --- | --- |
| verdict | needs-attention, 2×medium | needs-attention, 1×high + 1×medium |
| engaged the 5 briefed claims? | **no** (only what the diff shows) | **yes** — explicit verdicts on D2 (refuted), attention-vs-range (dismissed the worry, correctly), D3 read-only (endorsed) |
| unique catch | **shared brief → opaque two-model consensus** | **D2 "verbatim" overstated** (`positionals.join(' ').trim()`; version-pinned to 1.0.6) |
| both found | the brief-file fallback is **broken/unimplementable** | same, escalated to **high** |

**A' works** (briefed run walked the checklist and returned verdicts on the exact uncertain claims), **and A' has a real cost** — the blind run's #1 finding (opaque consensus) was **crowded out** of the briefed run. **That is R1 in this change's own design, confirmed by effect.**

## Findings + resolutions (all three real; all folded in)

| # | Run | Sev | Finding | Resolution |
| --- | --- | --- | --- | --- |
| **B1** | both (blind #2 / briefed #1) | high | **Brief-file fallback is unimplementable.** The digest excludes exactly `cross-review-ledger.md`; a new brief file either enters the reviewed-state digest (committed) or trips the dirty-tree refusal (untracked) — contradicting the gate-inert claim + task 4.3. | **FIXED — fallback DROPPED.** Inline only; overflow (if ever) rides the already-excluded advisory ledger, never a new file. Spec 2nd-paragraph rewritten, design D2, proposal, task 1.5. |
| **B2** | briefed | medium | **D2 overstates "verbatim".** Code is `positionals.join(' ').trim()` — strips/normalizes whitespace; the effect test proves *semantic engagement*, not byte-preservation. Also version-pinned to companion 1.0.6. | **FIXED.** D2 narrowed to *semantic delivery + internal newlines intact*, with a version-sensitivity mitigation (re-probe on companion version change). Task 3.2 corrected. |
| **B3** | blind (top finding) | medium | **Shared brief → opaque two-model consensus** + (by effect) it **crowds out** open-ended findings = R1. | **FIXED — new decision D2a + spec guards.** Brief is **additive** (check the claims *and* report outside them); **no consensus** on shared-brief-only findings; brief **recorded in the ledger**; drill digest presented **as claims to challenge**. |

## What the briefed run correctly *dismissed* (my worries, laid to rest)

- **attention-vs-range coexistence** (the ADDED requirement vs the existing "focus doesn't restrict what's reviewed") — *"not contradictory"*. Correct: a brief scopes attention, not the diff.
- **D3 (reject `task --write`)** — *"keep D3's read-only decision … neither requires a blocking redesign on the current evidence."*

## The meta-result

This is the cleanest possible validation of the A' change: **run on itself, the brief made the review measurably sharper on the author's stated uncertainties — and simultaneously demonstrated its own documented cost (R1), which the change now guards against.** The exit tell from the research doc (§8) is met: a briefed read-only pass engaged the design's specific claims, and the two real defects it found were both fixed.

## Authority restatement

Advisory. No gate force. The model did **not** tick task 4.2, computed no digest, wrote no attestation line. A genuine archive still requires the human to read this ledger, run `scripts/cross-review-digest.sh` themselves, and attest.
