## Context

`/xtty:cross-review` composes three review passes; **Pass B** is the external soundness pass (Codex `gpt-5.6-sol` via the `codex-plugin-cc` companion, `adversarial-review` subcommand). The full mechanism map and both reproductions are in `research/03-analysis/codex-review-integration-forensics.md`. The load-bearing facts:

- `adversarial-review` accepts **focus text** (the trailing positional → `USER_FOCUS` in `prompts/adversarial-review.md`) and returns the **validated `review-output` JSON schema**; its sandbox is **hardcoded read-only** (`codex-companion.mjs:414`).
- The command currently passes **no focus text** — `cross-review.md:44` frames focus as "does not scope the review", so it ships empty.
- The discriminating datum (`cross-review-gate-defect-forensics.md`): a **read-only** Codex, once briefed, found the two biggest gate defects **by reading**. Under-briefing — not the sandbox — was the gap.

## Goals / Non-Goals

**Goals:**
- Pass B receives a **brief** (design intent + specific claims to verify + a digest of drills already run) every run.
- Keep the **structured `review-output` schema**, the **read-only** sandbox, and the **advisory / zero-gate-force** posture.
- **Zero new machinery.**

**Non-Goals:**
- **No `task --write` drilling** (D3).
- No change to the reviewed **range** (the base rule is unchanged; a brief is not a range).
- No change to Pass A (critic) or Pass C (inline Opus), the bounded-N loop, degradation behavior, or the archive gate.

## Decisions

### D1 — A' (brief-via-focus), verified by effect

Pass the brief as the trailing positional on the existing invocation:
`node "$COMPANION" adversarial-review --base "$B" --model gpt-5.6-sol "<brief>"`.

Reproduced live (`research/…/codex-review-integration-forensics.md` §3): a two-question design-soundness brief produced two findings mapping onto exactly those questions, with valid schema output, read-only, xtty untouched. **The claim the test proves:** the brief reaches the model and shapes the review, *and* the structured schema survives — both verified against the real companion, not asserted.

### D2 — Deliver the brief **inline**; the survival claim is *semantic*, not byte-identical (dogfood-corrected)

The brief goes inline. The companion reconstructs focus as `focusText = positionals.join(' ').trim()` and its single-arg mangler fires **only** when `normalizeArgv` sees `argv.length === 1` (`codex-companion.mjs:130-138`); Pass B's `--base` + `--model` keep `argv.length > 1`, so the trailing brief positional is **not** mangled.

⚠️ **Corrected by the change's own dogfood** (the briefed Pass B on this very change): the earlier claim that the brief survives *"verbatim"* is **overstated**. `join(' ').trim()` strips leading/trailing whitespace and normalizes inter-positional spacing; a single quoted positional preserves its **internal newlines** but is not byte-identical. The claim is therefore: **the brief is delivered with its semantic content and internal structure intact** — which the effect test confirms (Codex engaged the brief's specific questions). It does **not** claim byte-preservation.

**Version-sensitivity (also a dogfood catch):** measured against companion **`1.0.6`**, and the worker resolves the *highest installed* companion by version-ordered glob — a future version could change positional parsing and silently restore the blind-review failure. → **Mitigation (tasks §3):** the by-effect probe (a briefed review whose findings reference the brief's questions) *is* the contract check; re-run it when the resolved companion version changes, and treat a brief the reviewer clearly did not engage as a **regression, not a pass**.

**No brief-file fallback — DROPPED (both dogfood runs flagged it unimplementable).** The gate tooling excludes exactly `cross-review-ledger.md`; a *new* brief file would either enter the reviewed-state digest (committed) or trip the digest tool's dirty-tree refusal (untracked) — contradicting the gate-inert claim and task 4.3's "neither gate script changes". So there is **no separate brief file**. If a brief ever exceeds the inline budget, carry the overflow in the **already-excluded advisory ledger** (which the digest tool already skips), never a new file. Inline suffices for the design-brief sizes this worker produces (YAGNI on the ARG_MAX edge).

### D2a — The brief is **additive**, and shared framing is not consensus (dogfood-added)

The change's own dogfood surfaced **R1 by effect**: the *blind* review's top finding — a shared brief can manufacture a fake independent two-model consensus — was **crowded out** of the *briefed* run, which spent its attention on the author's framing. So the requirement gains three guards:
- Each soundness pass is instructed to check the briefed claims **AND** report anything material outside them — the brief steers, it does not blinker.
- A finding is **not** elevated to two-model consensus when both passes rest **only** on the same briefed assertion (shared framing ≠ independent corroboration).
- The brief is **recorded in the advisory ledger**, and any worker-run drill digest is presented **as claims to challenge**, so the human can audit the shared framing behind any consensus flag.

### D3 — Reject `task --write` (drilling Codex)

`task --write --cwd <throwaway>` genuinely unlocks drilling (reproduced: Codex built the split-commit forge by effect, safely confined). Rejected for four measured reasons:
1. **Loses the schema** — task turns pass `outputSchema:null` → free text; breaks B/C comparability.
2. **Content-safety abort** — OpenAI's filter killed the reproduced security-flavoured drill mid-run.
3. **Write-safety surface** — `--write` ⇒ `workspace-write`; the throwaway `--cwd` becomes load-bearing (default cwd = the **xtty repo root**).
4. **`--resume` cross-wiring** — targets "the latest task job in this session" with no thread-id pin; single-flight broker → `-32001` → silent cold fallback.

It buys only **independent drill construction**, which the round-4 datum shows was **not** the missing capability — reading a brief (incl. drill results the main loop already ran) is. Documented as a non-default out-of-band escape hatch. **Revisit only if a future real defect proves a briefed read-only pass missed something a drill would have caught** — never from analysis.

### D4 — The brief is advisory; zero gate force

The brief is input to the review, exactly like the diff and the ledger. It carries **no** archive-eligibility meaning and is read by **no** downstream mechanical step. The human-attestation archive gate is untouched. *(This keeps the change cleanly on the advisory-worker axis, separate from the `G-GATE` archive-gate defects parked in their own explore.)*

### D5 — Test precision vs. the claim

The claim is *"Pass B is briefed, and the brief reaches the model without breaking the schema or safety."* It lives in the **command's invocation + the companion's arg handling**, and is verified **by effect**: a briefed `adversarial-review` on a throwaway diff whose findings **reference the brief's questions** (not generic notes) and whose output **parses as `review-output`**. A grep asserting the brief string is present in the command file is a **read-back check, not evidence**. No `verification-harness` delta — dev tooling, no observable app behavior.

## Risks / Trade-offs

- **R1 — A brief could bias the reviewer toward the author's framing.** → The `adversarial-review` system prompt is *"break confidence in the change"*; the brief supplies claims **to attack**, not conclusions to confirm. Frame briefs as *"soundness-check these claims"*, never *"confirm X"*.
- **R2 — A brief phrased around forging/bypassing may trip OpenAI's content-safety filter** (observed on the Mode-B drill). → Keep briefs as neutral **design-soundness** questions; hand Codex drill *results*, not "help me forge" instructions.
- **R3 — Inline brief survival is source-verified, not yet run through a live paid review.** → Cheap first-use confirmation (tasks §5); the file-pointer fallback (D2) exists for the edge case.
- **R4 — Large diffs are still summary-only** (the ≤2-file/≤256 KiB inline threshold). → Orthogonal and complementary: the brief helps **most** exactly where the diff isn't inlined; the range-pollution fix (separate change) shrinks the diff. Neither blocks the other.

## Migration Plan

Additive; affects only future `/xtty:cross-review` runs. Rollback = revert; Pass B returns to its (blind) state. No data, no attested state, no product surface.

## Open Questions

- Should the command **template** the brief (a fixed skeleton: intent / claims / drill-digest) or leave it free-form? Lean free-form to start; template only if briefs prove inconsistent in use.
- The one capability A' gives up vs Mode B is GPT-family **independent drill construction**. Trigger to revisit: a future real defect a briefed read-only pass provably missed — not analysis now.
