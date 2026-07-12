## Why

`/xtty:cross-review`'s external soundness pass (Pass B, Codex `gpt-5.6-sol`) has been shipping **blind** — fed only an auto-collected git diff with **no brief**. Across three rounds it under-performed, and once **endorsed a claim two other reviewers refuted by drill**, because it had no context to test the claim against.

Two measured causes (`research/03-analysis/codex-review-integration-forensics.md`):

- **The command tells itself the brief channel is useless.** `.claude/commands/xtty/cross-review.md:44` reads *"Focus text does **not** scope the review"* — true of the *range*, but it reads as "focus is useless", so the invocation populates `USER_FOCUS` with **nothing**.
- **For a large diff, Codex isn't even given the diff.** The plugin inlines the diff only for ≤2 files / ≤256 KiB (`lib/git.mjs:8-9`); beyond that it sends a summary and tells Codex to self-collect. On this session's polluted 33–317-file ranges, Pass B got neither a brief nor the diff.

**The read-only sandbox was NOT the bottleneck.** The discriminating datum: once finally handed a full brief + drill results, a **read-only** Codex found this session's two biggest gate defects *by reading* (`cross-review-gate-defect-forensics.md`). The gap is **under-briefing**, not read-only.

**The fix is verified by effect (A').** Passing a brief as the trailing positional on the *existing* `adversarial-review` call: the brief survives verbatim (`--base` + `--model` keep `argv.length > 1`, so the CLI's single-arg mangler never fires), Codex engages it precisely (a two-question design brief produced two findings mapping onto exactly those questions), the validated `review-output` JSON schema is preserved, and the pass stays read-only and safe.

## What Changes

- **The `/xtty:cross-review` worker SHALL supply Pass B a brief** through the reviewer's focus channel: one paragraph of **design intent** + the **specific claims/assumptions the soundness pass must verify** + a **compact digest of any drills the main loop already ran**. Delivered **inline** as the trailing positional on the `adversarial-review` invocation.
- **The command's poisoned note is corrected** — `cross-review.md:44` is reframed from *"focus text does not scope the review"* to: focus text does **not** change *which* diff is reviewed, but it **is** the brief / soundness-lens channel (`USER_FOCUS`) and **must be populated**.
- **The brief is additive, not a replacement for open-ended review** (dogfood-confirmed R1): each soundness pass checks the briefed claims **and** reports anything material outside them. A finding is **not** elevated to two-model consensus when both passes rest only on the same briefed assertion (shared framing ≠ independent corroboration), and the brief is **recorded in the advisory ledger** so the shared framing behind any consensus flag is auditable.
- **Inline delivery only; no brief-file fallback.** Both dogfood runs flagged a separate brief file as unimplementable — the digest tool excludes exactly `cross-review-ledger.md`, so a new file would either enter the reviewed-state digest or trip the dirty-tree refusal. An over-long brief carries its overflow in the **already-excluded advisory ledger**, never a new file.
- **No new machinery.** No `task` subcommand, no `--write`, no `--resume`, no new script, no new flag. Pass B stays on the **hardcoded-read-only** `adversarial-review` path (structurally cannot touch the tree). The `task --write` drilling mode is **explicitly rejected** (it loses the schema, adds a write-safety surface, and OpenAI's content-safety filter aborts security-flavoured drills mid-run) — documented as a non-default out-of-band escape hatch only.

## Capabilities

### New Capabilities

<!-- none -->

### Modified Capabilities

- `cross-model-review`: the worker capability gains a **Soundness-pass briefing** requirement — the worker SHALL brief the external (and inline) soundness passes via the focus channel, without altering the reviewed range, keeping the structured schema, and keeping the brief **gate-inert**. This is a worker-behavior addition; it carries **zero archive-gate force** (the brief is advisory input, like the ledger).

## Impact

- **`.claude/commands/xtty/cross-review.md`** — two edits: populate the brief on the Pass B invocation (§2 of the command); correct the line-44 focus note. Optionally document the gate-inert file-pointer fallback and the Mode-B rejection.
- **`openspec/specs/cross-model-review/spec.md`** — one ADDED requirement (Soundness-pass briefing) with scenarios.
- **`AGENTS.md`** — the worker-protocol description (Pass B bullet) notes the brief channel.
- **No product code, no tests, no harness surface.** Dev-workflow tooling; no observable app behavior, so no `verification-harness` delta.
- **This change is itself mechanically in scope** for cross-model review (it touches `.claude/` and `openspec/specs/`), so it carries the standard human-attestation gate task — noting that the archive gate itself is under a separate, unresolved `/opsx:explore` (the `G-GATE` defects) and has no committed executable; that does not block this advisory-worker improvement.
