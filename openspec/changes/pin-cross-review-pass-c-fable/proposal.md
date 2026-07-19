## Why

Cross-review's Pass C ("the diversity slice") is currently pinned to inline Opus — the same checkpoint that already drives Pass A (conformance). Recent research (`research/03-analysis/cross-model-seat-assignment-research.md`) found this worth a bounded, cheap experiment: the spec only requires Pass C to share Pass A's model *family* (Claude), not its specific checkpoint, so swapping Pass C's checkpoint from Opus to Fable 5 stays spec-compliant while giving the review a distinct checkpoint for its two Claude-family passes instead of running the identical model twice. The same research also found the original framing overstated the win ("3-way family diversity") and left the evaluation method underspecified — this change fixes both alongside the pin.

## What Changes

- Pin cross-review's Pass C (the inline soundness pass) to **Fable 5** instead of Opus.
- Correct the command/spec language: Pass C sharing Pass A's family is an **in-vendor checkpoint choice**, not a third independent family — the only cross-vendor diversity in the review is Pass B (GPT). State this explicitly so a future reader doesn't overread the pin.
- Add an explicit **human-only evaluation rule**: Pass C's comparative value is judged by a human reading several runs' ledgers for genuine Pass-A/Pass-C disjointness — never a model-computed disjointness score (which would edge toward the self-certification shape the archive gate exists to refuse), and never judged from a single run.
- No change to Pass A, Pass B, the archive gate mechanics, the scope classifier, or the digest tool. No new standing agent.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `cross-model-review`: Pass C's pinned model changes from Opus to Fable 5 (a command-file edit; no existing requirement text changes, since the concrete pin deliberately lives outside the requirement per the established spec). A new **ADDED** requirement governs the two concerns this pin creates: Pass C's family-sharing with Pass A must be documented as an in-vendor checkpoint choice — not an independent third family, and not in tension with `research.md`'s separate "Fable 5 not an analytical-reasoning tier" tiering decision, which governs a different concern — and Pass C's comparative value against Pass A must be evaluated by a human reading the ledger across multiple runs, weighing that within-family disjointness may just be prompt variance, never by a computed or model-derived metric.

## Impact

- `.claude/commands/xtty/cross-review.md` — Pass C's model pin (§2) and the added evaluation-method language.
- `openspec/specs/cross-model-review/spec.md` — one new **ADDED** requirement and its two scenarios (no existing requirement text is edited).
- `AGENTS.md` — the open-changes tracker row for this change (added at propose time); its "Cross-model design review" summary sentence naming Pass C's model, updated alongside the command-file edit at apply time so the guide never describes a pin that no longer matches `cross-review.md`.
- No product code, no CI, no test-suite changes.
- This change touches `.claude/commands/xtty/cross-review.md`, a path outside the docs/tracker allowlist, so it is classified **in scope** for cross-model review before archive (per `scripts/cross-review-scope.sh`) — its `tasks.md` carries the standard human-attestation cross-review task.
