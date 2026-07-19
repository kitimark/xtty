# Cross-review ledger — pin-cross-review-pass-c-fable (Round 1)

**Advisory only — carries ZERO gate force.** Nothing below is read mechanically by any downstream step. "Converged" has no gate force; a dismissal is a proposal, not an accepted state; there is no receipt. Archive eligibility lives entirely in the human-attestation gate (`⟶ archive-ritual` step-0), computed from git, never from this file.

## Header (transparency contract)

- **Range:** base `8dc589daa1384fb73d0a82fe119453ff03f927c5` .. HEAD `2098ad1fa2bb8b708630a10644996de523b559fb` (7 changed paths: `.claude/commands/xtty/cross-review.md`, `AGENTS.md`, `openspec/changes/pin-cross-review-pass-c-fable/{.openspec.yaml,design.md,proposal.md,tasks.md,specs/cross-model-review/spec.md}`).
- **Scope classifier:** `scripts/cross-review-scope.sh pin-cross-review-pass-c-fable` → exit 10, in scope (1 path outside the docs/tracker allowlist: `cross-review.md`).
- **Passes run:** all three (A, B, C) — no skip. Not single-model.
- **Effective model / effort per soundness pass:**
  - Pass B: `gpt-5.6-sol` (pinned via `--model`); effort undetermined this run (codex CLI config not queried).
  - Pass C: `claude-fable-5` (self-attested in its own output); effort session-inherited — **no per-call override exists in the harness `Agent` tool** (a design/doc gap this round's fixes correct); not independently verified beyond self-attestation.
- **Companion version:** `1.0.6` (`~/.claude/plugins/cache/openai-codex/codex/1.0.6/scripts/codex-companion.mjs`).
- **Brief:** ~4.7 KB, staged out-of-repo (`$CLAUDE_JOB_DIR/tmp/cross-review-brief.*`, never entered the repo/digest). Contents: design intent + 5 numbered claims-to-soundness-check + a drill digest that included Pass A's own prior (pre-cross-review) coherence verdict, presented as "soundness-check independently, don't defer."
- **Self-review confound (disclosed per design.md's own risk):** this is the first-ever Fable-pinned Pass C run, reviewing the diff that installs the Fable pin. Per design.md's mitigation, this ledger should be **bracketed** (noted, not counted) in the future multi-run disjointness evaluation.

## Findings and resolutions

Ordered by priority, per the human's explicit steer this round ("focus on fixing the highest priority").

### 1. [HIGH — B+C consensus] The evaluation method is confounded/non-causal, not a controlled isolation of checkpoint value
- **Pass B** (high): Pass A (conformance) vs Pass C (soundness) disjointness can't attribute a difference to the checkpoint — role/prompt/schema differ too. Recommends paired same-prompt Fable-C/Opus-C controls, or narrowing the claim to non-causal observation.
- **Pass C** (medium, independent framing): the standing protocol's own briefing rule digests Pass A's findings into Pass C's brief every run (not just this bootstrap run) — pre-disclosing/pre-dismissing them, manufacturing apparent disjointness structurally, not just as a one-off bootstrap artifact.
- **Resolution: FIXED.** Narrowed the causal claim and added a discount instruction in three places: `specs/cross-model-review/spec.md` (ADDED requirement body + Scenario 2), `cross-review.md`'s "Evaluation is human-only" paragraph. Did **not** implement Pass B's stronger paired-control alternative (same-prompt Fable-C/Opus-C runs) — that's a heavier mechanism change outside this round's bounded scope; noted as a possible future strengthening, not required now.

### 2. [MEDIUM — B+C consensus] Pass C's effort is claimed "invocation-controlled" but no such per-call mechanism exists
- **Pass B** (medium): the operative `cross-review.md` Pass C bullet sets only `model: 'fable'`, no effort override, contradicting the design's "invocation-controlled, high/xhigh" claim.
- **Pass C** (medium, sharper diagnosis): verified directly against the harness `Agent` tool schema — there is **no per-call effort parameter at all** for an inline Agent call (only `description`, `isolation`, `model`, `prompt`, `subagent_type`). "Invocation-controlled" was never executable as written.
- **Verified independently** (read the Agent tool's own schema — confirmed no `effort` field exists).
- **Resolution: FIXED.** Corrected `design.md` Decision 1 and `cross-review.md`'s §3 ledger-header bullet to state the true mechanism: effort is session-inherited, not invocation-pinned; recorded as reported/best-effort; the human launching a run should confirm their own session's effort is high/xhigh first.

### 3. [MEDIUM — B+C consensus] No trigger/owner ensures the evaluation ever actually happens
- **Pass B** (medium): no minimum run count, deadline, or persisted register — human-launched-only cadence means the pin could coast unevaluated indefinitely.
- **Pass C** (low, same underlying point): "toothless as enforcement... the pin can coast unevaluated indefinitely while remaining nominally 'reversible pending evaluation.'"
- **Resolution: FIXED.** `design.md`'s Open Questions now names a concrete trigger: re-evaluate after the 3rd eligible non-self-review run, or at the next `xtty:capture-research` pass touching cross-model review, whichever comes first — recorded as a dated note in `cross-model-seat-assignment-research.md`.

### 4. [LOW] Tracker row task-count went stale a second time (Pass A + Pass C, same finding)
- Both Pass A and Pass C independently caught `AGENTS.md`'s open-changes row undercounting (3/6 vs actual 4/6) — it had gone stale within minutes of being fixed the first time.
- **Resolution: FIXED, structurally.** Dropped the cached numeric fraction from the row entirely (now "in progress (`openspec list` for live count)"), matching this repo's own established "compute cross-artifact state on demand, never cache counts" convention and the `add-ci-pipeline` row's no-fraction style — so it can't go stale again the same way.

### 5. [LOW] Pass C's effective model is trusted from the invocation parameter, never verified — dismissed, not fixed
- Pass C: the ledger header records "effective model" from the `model: 'fable'` invocation intent, never independently verified; this harness class has documented delivery-lag/override-drop flakiness elsewhere in this repo's memory.
- **Resolution: DISMISSED (recorded rationale).** Out of scope for this bounded round per the human's "focus on highest priority" steer — the self-attestation this run (`claude-fable-5`) already worked, and building a mechanical self-report-and-record step is exactly the kind of new-tooling machinery `design.md`'s Non-Goal 4 defers until the pin has proven worth keeping across several runs.

### 6. [LOW] The author-checkpoint axis (Opus/Fable/Sonnet all author changes in this repo) is un-derived — dismissed
- Pass C: an interesting confounder (a Fable-authored change would put the diversity slice on the author's own checkpoint) with no evaluation-guidance mention.
- **Resolution: DISMISSED (recorded rationale).** Genuine but low-priority observation for a future research capture, not a defect in this bounded change; noted here so it isn't lost, deferred to a future `xtty-capture-research` pass per this round's own new trigger (finding 3).

### 7. [LOW] AGENTS.md's edited sentence conveys "B and C are different families" only by implication, not as an explicit stated rule — dismissed
- Pass C (confidence 0.4, its own lowest-confidence finding): the pre-edit sentence stated the two-family invariant directly; the edit conveys it only by entailment.
- **Resolution: DISMISSED (recorded rationale).** Low confidence from the reviewer itself; the current text ("Pass B remains the review's only cross-vendor diversity") already entails the invariant and reads clearly in context; not worth further AGENTS.md growth against the guide-gate ceiling for a restatement of something already implied.

### Pass A (conformance) findings — both resolved above
- Stale tracker count → folded into finding 4.
- Process nit (task 2.1 ticked before this formal Pass A ran) → no artifact fix applicable; task 2.1 (the apply-loop's own pre-archive coherence gate) and this cross-review's Pass A are two distinct, both-legitimate invocations of the same critic agent for different purposes. Recorded, not actionable.

## Residual

No blocking residual. Round 1 of the bounded N=2 fix→re-review loop is complete. A second round (re-running A‖B‖C against the fixes above) is available but not yet run — per this repo's own measured tar-pit dynamic (fixes past ~2-3 rounds tend to introduce as many defects as they remove), and per the change's already-small, now-tightly-scoped diff, a second round is the human's call, not auto-triggered.

**Restated:** everything above is advisory. The human reads this ledger, runs `scripts/cross-review-digest.sh pin-cross-review-pass-c-fable`, and records the attestation line in `tasks.md` themselves — the model must not tick task 2.2 or derive the digest.
