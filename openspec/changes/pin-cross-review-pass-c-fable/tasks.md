## 1. Implement the pin

- [x] 1.1 Edit `.claude/commands/xtty/cross-review.md`: pin Pass C to Fable 5 everywhere it's currently named as "inline Opus" — the §2 Pass C bullet **and** the frontmatter `description` line (the text also surfaced as the `/xtty:cross-review` skill-listing description); add the checkpoint-vs-family clarification (Pass C sharing Pass A's family is an in-vendor checkpoint choice, not a third independent family — only Pass B provides cross-vendor diversity, and this doesn't conflict with `research.md`'s separate "Fable 5 not an analytical-reasoning tier" tiering decision, which governs a different concern) and the human-only evaluation-method language (Pass C's comparative value against Pass A is judged by a human reading several runs' union ledgers — persisted per run, or the human's own recorded per-run judgment, with each pass's findings kept distinguishable by source tag — for genuine disjointness, weighing that within-family disjointness may just be prompt variance, never by a model-computed metric)
- [x] 1.2 Update `AGENTS.md`'s "Cross-model design review" summary sentence naming Pass C's model (currently "an inline Opus soundness pass") so the guide matches the edited command file
- [x] 1.3 `openspec validate "pin-cross-review-pass-c-fable"` — mechanical validation of the change artifacts

## 2. Pre-archive review

- [x] 2.1 Pre-archive coherence review ⟶ xtty-openspec-critic (pin-cross-review-pass-c-fable)
- [x] 2.2 Human-attestation cross-review (this change will be mechanically **in scope** once task 1.1 lands — it commits `.claude/commands/xtty/cross-review.md`, a path outside the docs/tracker allowlist; at propose time the classifier reads exit 0, per `scripts/cross-review-scope.sh`). Run `/xtty:cross-review pin-cross-review-pass-c-fable`, read the complete ledger, run `scripts/cross-review-digest.sh pin-cross-review-pass-c-fable`, and record the reviewed-state digest on a delimited attestation line. **HUMAN-ONLY — the model MUST NOT tick this task or derive the attested value:**
  `<!-- cross-review-attestation: base=<B> head=<HEAD> digest=<sha256> reviewed=<date> -->`
<!-- cross-review-attestation: base=8dc589daa1384fb73d0a82fe119453ff03f927c5 head=6398208a012666eca6d2f3e13ebbde55d74a37ea digest=2d5fdf015a3014a06e2c4532d1200f864f913d8ba751d8bfbcfa849712f68f78 reviewed=2026-07-19 -->

## 3. Archive

- [ ] 3.1 Archive + reconcile ⟶ archive-ritual
