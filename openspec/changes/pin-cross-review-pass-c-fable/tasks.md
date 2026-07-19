## 1. Implement the pin

- [ ] 1.1 Edit `.claude/commands/xtty/cross-review.md`: pin Pass C to Fable 5 (was: inline Opus); add the checkpoint-vs-family clarification (Pass C sharing Pass A's family is an in-vendor checkpoint choice, not a third independent family — only Pass B provides cross-vendor diversity, and this doesn't conflict with `research.md`'s separate "Fable 5 not an analytical-reasoning tier" tiering decision, which governs a different concern) and the human-only evaluation-method language (Pass C's comparative value against Pass A is judged by a human reading several runs' union ledgers for genuine disjointness — weighing that within-family disjointness may just be prompt variance — never by a model-computed metric)
- [ ] 1.2 Update `AGENTS.md`'s "Cross-model design review" summary sentence naming Pass C's model (currently "an inline Opus soundness pass") so the guide matches the edited command file
- [ ] 1.3 `openspec validate "pin-cross-review-pass-c-fable"` — mechanical validation of the change artifacts

## 2. Pre-archive review

- [ ] 2.1 Pre-archive coherence review ⟶ xtty-openspec-critic (pin-cross-review-pass-c-fable)
- [ ] 2.2 Human-attestation cross-review (this change is **in scope** — it touches `.claude/commands/xtty/cross-review.md`, a path outside the docs/tracker allowlist, per `scripts/cross-review-scope.sh`). Run `/xtty:cross-review pin-cross-review-pass-c-fable`, read the complete ledger, run `scripts/cross-review-digest.sh pin-cross-review-pass-c-fable`, and record the reviewed-state digest on a delimited attestation line. **HUMAN-ONLY — the model MUST NOT tick this task or derive the attested value:**
  `<!-- cross-review-attestation: base=<B> head=<HEAD> digest=<sha256> reviewed=<date> -->`

## 3. Archive

- [ ] 3.1 Archive + reconcile ⟶ archive-ritual
