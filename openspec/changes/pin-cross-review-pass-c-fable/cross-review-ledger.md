# Cross-review ledger — pin-cross-review-pass-c-fable (Rounds 1–2, bound reached)

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

## Round 2 (re-review after round-1 fix commit `35848ce`)

Range unchanged (base `8dc589daa138`), HEAD advanced to `35848ce2e07fd8421e0037ed6e13f2f44f77715e`, 8 changed paths (round 1 added `cross-review-ledger.md`). Scope classifier unchanged: exit 10, still exactly 1 path outside the allowlist (`cross-review.md`). Companion still `1.0.6`, still available/logged-in. Pass A delivery check: critic Definition-version unchanged (`v6, 2026-07-18`) — no stale-definition risk.

**Effective model / effort per soundness pass, round 2:** Pass B `gpt-5.6-sol` (effort undetermined, config not queried); Pass C `claude-fable-5` (self-attested; **this round's Pass C was a fresh spawn**, so delivery was sound — but nothing in the round-1 protocol text yet *prevented* a resume next time, which round 2's top finding closes).

### Round-2 findings and resolutions

Again ordered by priority per the human's standing "focus on fixing the highest priority" steer.

#### 1. [HIGH — Codex, escalating round-1's dismissal 5, independently corroborated by Fable at medium] Pass C's served model was never verified — round 1's dismissal was wrong
- **Pass B** (high): the protocol never verifies Pass C's effective model against expectation. Cites this repo's own memory (a `SendMessage` resume can drop a per-call model override) and Claude Code's subagent model-resolution precedence — a future run could silently run a non-Fable checkpoint while being recorded and evaluated as Fable, corrupting the multi-run comparison this whole change is built on.
- **Pass C** (medium, same root cause, sharper mechanism): the standing protocol never specifies whether round-2-and-later's Pass C is a *fresh* Agent call or a resume of a prior round's agent — and the harness actively invites resuming a prior agent via `SendMessage`. Round 1's dismissal conflated "mechanical disjointness-scoring tooling" (correctly deferred by Non-Goal 4) with two free prompt-text lines (fresh-spawn-per-round + self-report the served model), which aren't tooling at all.
- **Resolution: FIXED, reversing round 1's dismissal.** Added a new "Verify, don't trust, the served model" paragraph to `cross-review.md`'s Pass C section: each round's Pass C MUST be a fresh inline `Agent` call (never a `SendMessage` resume), and MUST self-attest its served model id in its output, which the ledger records as the effective model instead of trusting the invocation parameter. Round 1's dismissal 5 is superseded by this fix.

#### 2. [MEDIUM — Codex, deepening round-1's fix 1] Even after discounting brief-disclosed findings, Pass-A/Pass-C disjointness still can't distinguish "Fable adds value" from "the soundness role adds value, independent of checkpoint"
- **Pass B** (medium): round 1's discount instruction removes only the brief-sharing confound; the deeper conformance-vs-soundness lens/prompt/schema mismatch remains, and repeating the comparison across runs doesn't repair that identification problem. Recommends either narrowing the claim further or adding a same-brief/same-prompt Opus-C control.
- **Resolution: FIXED, by narrowing further (not adding a control — stays inside Non-Goal 4).** Added one sentence to both `specs/cross-model-review/spec.md` (requirement body + Scenario 2) and `cross-review.md`: the residual signal, even after the brief-discount, is **directional, not causal** — it cannot by itself isolate the checkpoint's contribution from the soundness role's — and a decisive causal answer would need an optional future same-brief/same-prompt Opus-run Pass-C control, not required now.

#### 3. [MEDIUM — Codex; independently, Fable flagged the same underspecification at low] The new re-evaluation trigger has no defined "eligible" and no run-ordinal register
- **Pass B** (medium, harsher framing: "not reachable or auditable"): "eligible" is undefined; no register tracks which numbered run is which; `cross-model-seat-assignment-research.md` doesn't yet contain any dated note despite the round-1 ledger phrasing implying one existed.
- **Pass C** (low, softer framing: "residual ambiguity, not restored toothlessness" — the dual trigger and per-run recording mandate already prevent indefinite postponement): flagged specifically that "eligible" needs a definition, or a broad "self-review" reading could exclude runs indefinitely in a repo that frequently touches review tooling.
- **Resolution: PARTIALLY FIXED + residual escalated (bound reached, not looped further).** Defined "eligible" in `design.md`'s Open Questions: *any in-scope `/xtty:cross-review` run whose own reviewed diff does not itself modify Pass C's protocol in `cross-review.md`*. **Did not** add a persisted run-ordinal register — that would be exactly the new tracking tooling `design.md`'s Non-Goal 4 defers until the pin proves worth keeping. **Escalating as the round's residual:** nothing mechanically enforces that a human actually counts to 3 or notices the trigger fired; this rests on human diligence, consistent with (not a defect introduced by) the design's deliberate no-new-tooling stance. Also fixed a small round-1-introduced defect in the same sentence: a backwards "see risk below" cross-reference (the self-review-confound risk is *above*, in Risks/Trade-offs) — corrected to "above."

#### 4. [LOW — Opus + Fable consensus] Round-1's own fix introduced a SHALL/SHOULD strength drift between two synced clauses
- **Pass A** and **Pass C** independently caught the same thing: the spec delta's brief-discount clause says SHALL; `cross-review.md`'s synced copy said SHOULD — a future reader of the operative command file (not the spec) would see the weaker form.
- **Resolution: FIXED.** Changed `cross-review.md`'s clause to SHALL, matching the spec.

#### 5. [LOW, confidence 0.5 — Fable only] Post-merge, the established spec's effort parenthetical will read asymmetric (names only the external reviewer as possibly lacking per-call effort control)
- The pre-existing (not this-change) requirement's effort language singles out the external pass as the one that "may expose no per-call effort control" — round 1 discovered the inline pass ALSO has none, but that established line wasn't revisited.
- **Resolution: DISMISSED (recorded rationale).** Not a contradiction — the generic "where the interface exposes it" clause still technically covers Pass C — and fixing it cleanly would mean a MODIFIED delta against the *established* spec (a bigger, separately-risky edit needing the entire-existing-block paste this repo's own rules require), which is out of scope for this bounded change. Left as a known, recorded asymmetry rather than silently accepted.

#### 6. [LOW, confidence 0.4 — Fable only] `proposal.md` wasn't updated with the narrowed evaluation-method language
- Proposal bullet 3 still describes the pre-narrowing shape (no mention of the confound-narrowing or brief-discount now in the spec delta and command file).
- **Resolution: DISMISSED (recorded rationale, per the reviewer's own suggestion).** The proposal is a shallower, still-accurate summary; it is the spec delta (not the proposal) that merges at archive, so this is cosmetic, not load-bearing.

#### Pass A's other finding
- design.md:19's claim that "a Workflow's `agent()`... does [expose a per-call effort parameter]" was flagged as unverifiable from in-repo files alone (out of Pass-4's scope). Not a defect — it's an accurate claim about the harness's Workflow tool (documented in the tool's own schema, outside this repo) — no action needed; noted for completeness.

## Residual (bound reached — N=2 rounds complete, escalating rather than looping further)

**One residual is escalated, not further fixed:** the re-evaluation trigger (round 2, finding 3) has no mechanical enforcement that a human actually notices or counts toward it — it rests on human diligence and the durable-but-manual `cross-model-seat-assignment-research.md` recording, consistent with this change's deliberate Non-Goal against new tracking tooling. This is a known, accepted limitation, not a defect to chase into a third round.

Two low-confidence items (5, 6 above) were dismissed with recorded rationale rather than fixed, per the same bounded-scope judgment.

Per the protocol: **no further fix→re-review round should be launched for this change without a new human decision to do so.** Both rounds' fixes were verified independently by two model families each round; round 2 confirmed round 1's three consensus fixes held structurally, while surfacing that round 1 had both under-fixed one item (the evaluation's residual causality gap) and wrongly dismissed another (Pass C model verification) — consistent with this repo's own measured pattern that review fixes can both resolve and introduce/reveal issues, which is exactly why the bound exists.

**Restated:** everything above is advisory. The human reads this ledger, runs `scripts/cross-review-digest.sh pin-cross-review-pass-c-fable`, and records the attestation line in `tasks.md` themselves — the model must not tick task 2.2 or derive the digest.
