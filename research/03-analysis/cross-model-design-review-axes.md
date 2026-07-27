# Cross-model design review — the complementary-axes finding + the two-layer architecture

> **Status (2026-07-27): historical.** The worker and the human-attestation archive gate this
> document describes were retired in full by `remove-cross-model-review`. The complementary-axes
> reasoning and the self-certification refutation remain valid findings, but `/xtty:cross-review`,
> its archive gate, and the two deterministic scripts it names no longer exist.

**Provenance.** 2026-07-12, written during `/opsx:apply add-cross-model-design-review` (the build of the cross-model-review worker + the human-attestation archive gate). Distilled from the change's `proposal.md`/`design.md`, two worked exemplars from this and the prior session, and the live Fable-5 + `gpt-5.6-sol` fan-out that re-architected the proposal. This doc captures **why two differently-modeled reviewers are complementary** and **why the design splits into an authority-free worker + a human gate**. The *non-termination / thin-claim / content-floor* mechanics are a **separate** finding — see [`cross-model-review-tar-pit-forensics.md`](cross-model-review-tar-pit-forensics.md) — and are not repeated here.

## Sources

- `openspec/changes/add-cross-model-design-review/{proposal,design}.md` (the settled two-layer design).
- Exemplar (a): the `add-git-diff-wrap-toggle` review — the Opus critic returned COHERENT while a Codex/GPT adversarial pass caught a config-ownership bug. Types confirmed present: `XttyProfile` + `XttyConfigSet`, both in `XttyCore/Sources/XttyCore/XttyProfile.swift`.
- Exemplar (b): this change's own six-round cross-model review of its first (self-policing-gate) shape; the live fan-out (Fable-5 fixing, `gpt-5.6-sol` adversarial-verifying, Claude adjudicating).
- The build's deterministic fail-closed drills (12/12) — scratchpad `test-cross-review-scripts.sh`.

## 1. The finding — conformance and soundness are different axes, and one model can't cover both

A single-model coherence pass is **insufficient** for a substantive change. The two reviewers this repo runs are **complementary, not redundant**, because they check **different axes** and, crucially, **read different inputs**:

| Axis | Reviewer | Reads | Catches | Blind to |
| --- | --- | --- | --- | --- |
| **Conformance** | Opus `xtty-openspec-critic` | the artifacts + AGENTS.md rulebook + disk state; **never product source** (except the new Pass 4, which fact-checks *stated claims about existing symbols*) | spec-delta-format breaks, proposal↔specs drift, missing delegation markers, tracker drift, a **false claim about an existing symbol** | whether the *approach* is sound; a **misplaced new symbol**; external-dependency internals |
| **Soundness** | Codex `gpt-5.6-sol` (Pass B) + inline Opus (Pass C) | the **full diff** of the reviewed range; traces claims into real code | wrong approach, unsound assumptions, a design-ownership bug, a too-shallow test plan | conformance rules it isn't told about; whatever *both* models share as a blind spot (R2) |

The axes barely overlap. A change can be perfectly **conformant** and **unsound**, or vice-versa. ✅ This is why the design runs *both* — and why the soundness slice uses **two distinct model families** (a shared blind spot is the residual risk R2, mitigated only by the human reading every finding).

## 2. Exemplar (a) — critic COHERENT ↔ Codex caught the config-ownership bug

On `add-git-diff-wrap-toggle` the Opus critic returned **COHERENT** (the artifacts were rule-clean). A Codex/GPT adversarial pass caught a real **config-ownership bug**: a base-only key was modeled on `XttyProfile` (the per-profile override struct) instead of `XttyConfigSet` (the base config struct) — *and* flagged a too-shallow test plan.

- ❌ The critic could not catch it: the bug lives in the *approach* (which struct owns the key), and the misplaced field was a **new** symbol — outside even Pass 4's honest scope (Pass 4 fact-checks *existing* symbols only; a misplaced **new** field is exempt). This is the exemplar that fixes Pass 4's scope boundary in the design (D6/R6): Pass 4 rides along for independent value, but the **motivating** bug's class stays a **cross-model catch**. ✅

**Guideline (G-AXES-1).** When a change adds a new field/type/key, *"which existing thing owns it"* is a **soundness** question — route it to the cross-model passes, not the conformance critic. The critic's code-accuracy pass is for *stated claims about things that already exist*, nothing more.

## 3. Exemplar (b) — the self-policing gate was refuted; the human is the gate

The change's **first** shape was a **self-policing automated gate**: a model ran the review, wrote a `cross-review-receipt.md` with a "converged" verdict, and archive checked that receipt. Six rounds of its own cross-model review (live: Fable-5 fixing, `gpt-5.6-sol` adversarial-verifying, Claude adjudicating) refuted it.

**Retired theories (fates) — the receipt-as-gate family:**

| Retired shape | Why it died (the refuting observation) | Fate |
| --- | --- | --- |
| Model-authored `cross-review-receipt.md` gate-checked for a converged verdict | The receipt is **model-authored**, so a mechanical check of it **still trusts the model** — a model can dismiss every finding and self-certify | ❌ |
| "Converged verdict" as archive eligibility | Correct behavior (dismiss → converge → write receipt) *defeats* the guarantee — the model **passes the gate by doing its assigned job** | ❌ |
| `OpenSpec-Change:` per-commit ownership trailers + immutable manifests | The change **could not dogfood its own trailer rule** on its already-landed history | ❌ |
| Coverage-label / effort-floor audit as a gate input | Another model-authored label; same self-certification hole | ❌ |
| Mandatory commit-signing | Only bites at an **out-of-band** boundary (CI/branch-protection or human-run archive); an in-loop model runs `verify-commit` itself → pays ceremony for closure it doesn't deliver in-loop | ❌ (kept as an *optional, non-default* strong form) |
| **Authority-free worker + human-attested fail-closed gate** | Splits two failure classes: **deletes** the self-certification class (no model artifact has gate force) and owns only the **affirmative-forbidden-act** residual (R3) — the same trust class the repo already accepts for every committed procedure | ✅ |

**The irreducible lesson: the human is the gate, not the model.** The design splits into two layers with a hard rule between them — **the worker is arbitrarily helpful but carries zero authority; the gate is authority-complete, has near-zero machinery, and reads no model-authored artifact.** Its inputs are the human's attestation line, a git-computed digest from committed deterministic tooling, and git ground truth.

**Two failure classes, only one of which is a design flaw** (the load-bearing distinction):

- ❌ **Self-certification** (refuted): a model **passes the gate by doing its assigned job** (dismiss/converge/write receipt). A design where *correct behavior* defeats the guarantee is broken. This design **deletes the class entirely**.
- ❓ **Affirmative forbidden act** (R3, accepted residual): a model **forges** the human tick + digest line. No in-repo check the same model runs closes this — but it is the **same trust class** the repo already extends to every committed procedure (a session that ignores `⟶ archive-ritual` is already outside the contract). A design that states this boundary honestly is sound; one that overclaims is not.

That is *why* signing is **optional-not-default**: it converts the barrier from an instruction ("HUMAN-ONLY, don't fill the line") to a capability ("the model can't produce the signature"), but only at an out-of-band boundary — so it's the strong form for anyone who needs mechanical (not procedural) forgery-resistance, not the default against the repo's $0/no-ceremony ethos.

## 4. Re-verify by effect

- The complementary-axes claim re-checks by **running both reviewers on a real substantive change** and confirming they surface **different** findings (not a static read of this doc). The build's live arm — a real `/xtty:cross-review` run on an in-scope change — is the change's own dogfood (tasks 5.2/5.3), deferred to a **fresh session after the v4 critic is committed** (R9: an in-session run may be served the stale v3 critic as Pass A).
- The gate's fail-closed claim re-checks by **a real archive attempt** on this change that provably **fails closed** on an absent/stale/rewritten attestation (task 5.3). The **deterministic** half is already proven: 12/12 fail-closed drills (scope bypass, range-omission refuse, digest invariance vs. content-change, dirty-tree refuse, exempt-by-act rewrite/delete detection, numeric semver) — scratchpad `test-cross-review-scripts.sh`.

## 5. Relationship to the tar-pit forensics

This doc = **why two reviewers + why the two-layer architecture** (the *value* and the *shape*). The companion [`cross-model-review-tar-pit-forensics.md`](cross-model-review-tar-pit-forensics.md) = **why you can't mechanize the gate to airtightness** (non-termination against a repo-controlling model → thin the claim, D10) and **why you stop reviewing the spec and start building** (the dev-tooling review cliff; G-TARPIT-1..5). Read together: the axes doc says *do the cross-model review and gate it with a human*; the tar-pit doc says *don't try to make that gate mechanically airtight, and don't review its spec forever — build and use it.*
