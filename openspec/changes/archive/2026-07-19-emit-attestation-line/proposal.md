## Why

The archive gate's attestation line (`<!-- cross-review-attestation: base=<B> head=<HEAD> digest=<sha256> reviewed=<date> -->`) is human-only by design, but assembling it today is hand-work the tooling could do without touching the authority boundary: `scripts/cross-review-digest.sh` prints only the bare 64-hex digest, so the human must separately derive `base` (a positional git rule the script already computes internally and discards) and `head` (`git rev-parse HEAD`) and hand-type three long hex values into `tasks.md`. In a recent real incident a human asked an AI three times to assemble the line (the AI correctly refused each time, per the established human-only rule), then hand-typed all three values — and because the gate's four mechanical checks never verify the `base=`/`head=` fields, those exact bytes transiting an AI's chat output before being pasted was an unverified, model-mediated step in the attested value chain. Emitting the fully-assembled line from the committed deterministic tool removes both the busywork and that model-mediated step, while leaving the acts that constitute attestation — writing the line into `tasks.md`, ticking the task, committing — exclusively human.

## What Changes

- **Enhance `scripts/cross-review-digest.sh` to also emit the fully-assembled, ready-to-paste attestation line** — `base`, `head`, `digest`, and `reviewed` all filled in from the same values the script already computes (base) or can derive deterministically (head, date). Additive output only: e.g. the assembled line printed to stderr alongside the normal run, and/or a new flag such as `--line` that prints only the assembled line to stdout for piping to a clipboard tool.
- **Preserve the default stdout contract byte-identical.** The default invocation (`scripts/cross-review-digest.sh <change>`) continues to print the bare 64-hex digest and nothing else on stdout — existing consumers (the archive step-0 recompute-and-compare) are untouched.
- **Permanently reject the next step on the affordance gradient** — recorded as a rejection, not a "not yet": the tool must never write the line into `tasks.md`, never tick the attestation checkbox, and never commit. A committed script performing those acts would convert the one genuinely forbidden act (a model self-attesting) into a routine-looking command invocation nobody would notice crossing the line — the affordance is the attack; git cannot see who pressed the button.
- **Add one new ADDED requirement to the `cross-model-review` spec** codifying the above guardrail as a SHALL (see Capabilities), following this repo's established practice of writing down a guardrail specifically to close off a tempting future overreach before anyone builds it.
- **Nothing else changes.** No scope-classifier changes, no changes to the archive step-0 precondition or its four checks, no changes to review Passes A/B/C, no new file-write capability in any committed tooling.

Because this change touches `scripts/cross-review-digest.sh` (outside the docs/tracker allowlist), it is itself mechanically in-scope for the cross-review + human-attestation gate it modifies. Per the established spec, the gate runs the digest and scope tooling from the reviewed-base (pre-modification) version — the rule already explicitly covers a change that modifies that tooling, so this is the well-trodden path, not the bootstrap boundary. It is a separate change by necessity: it cannot fold into the already-attested `pin-cross-review-pass-c-fable` (editing its files now would violate exempt-by-act) nor into the unrelated `add-git-diff-wrap-toggle` or `add-ci-pipeline`.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `cross-model-review`: one new **ADDED** requirement scoping the digest tool's attestation-line-emission convenience. It states that the convenience (a) SHALL NOT alter the tool's default digest-only stdout contract; (b) is not itself an attestation and carries no gate force on its own; and (c) is explicitly not license for any tool to write the line into a task file, tick the attestation task, or commit on the human's behalf — those three acts remain exclusively human. No MODIFIED delta is needed: the existing archive-gate requirement's normative text ("runs the committed deterministic reviewed-state digest tool themselves, and ticks the task, recording the reviewed-state digest on a delimited attestation line") does not specify the tool's output format, so the enhancement is compatible with it as written.

## Impact

- **`scripts/cross-review-digest.sh`** — the only code change: assembled-line emission added; default stdout contract, exit codes, dirty-tree refusal, and base-resolution rule unchanged.
- **`openspec/specs/cross-model-review/spec.md`** — gains the one ADDED requirement at archive (delivered via this change's spec delta).
- **`scripts/cross-review-scope.sh`, archive step-0, `/xtty:cross-review` protocol** — untouched.
- **This change's own archive path** — in-scope for the cross-review + human-attestation gate; the gate runs against the reviewed-base version of the digest script, per the existing spec rule.
