# Cross-Model Review — The Mechanical-Airtightness Tar Pit

**Provenance:** 2026-07-12, produced during the `add-cross-model-design-review` proposal work as the forensic record of an in-session *convergence experiment* — a Workflow that ran the proposal's own cross-model review loop **on the proposal itself** (Claude fixing, `gpt-5.6-sol` adversarial-verifying, a Claude adjudicator calling convergence), plus the ~16 adversarial-review rounds across the whole session that preceded it. Time-sensitive: model IDs and the codex plugin version (`1.0.6`) are current as of this date.

**Headline:** *Iterating cross-model review "until both models agree" does not terminate when the thing being hardened is a **mechanical git-provenance gate** and the adversary is **the model running the tool**. The unbounded set of git-history-manipulation bypasses all reduce to the one accepted residual (a repo-controlling model performing a forbidden act). The correction is to **thin the claim** — scope the mechanical checks to accident-catching + human-legibility, and route adversarial resistance through the human + that residual — and, more broadly, to **validate dev tooling by building and using it, not by reviewing its spec forever.***

## Sources

- Workflow transcript `wf_454a4338-7e8` (the 4-round convergence run: 16 agents, ~1.29M tokens) — `…/subagents/workflows/wf_454a4338-7e8/journal.jsonl`.
- The four `docs(openspec): converge Round N …` commits (`fe6be52`, `840b450`, `fa691ef`, `8451f22`) — the evidence record, kept (not reset).
- The re-baselining commit that restored the thin target (this doc's companion; cites this file).
- The proposal artifacts: `openspec/changes/add-cross-model-design-review/` (design D10 = the thin-claim correction).

## 1. What was run

The proposal `add-cross-model-design-review` specifies a **cross-model review worker** (Claude conformance + `gpt-5.6-sol` soundness + inline Claude soundness → a bounded fix→re-review loop) feeding a **human-attested, fail-closed archive gate**. To make the proposal "proper," we dogfooded that exact loop on the proposal:

```
each round:  Fable-5 applies the round's open findings + commits a checkpoint
             → gpt-5.6-sol adversarial-review (verify)  ∥  Claude soundness (verify)
             → Claude adjudicator: converged? (no open actionable beyond accepted residuals)
bound: 4 rounds; seed: the 2 open highs from the prior hardened-state review
```

## 2. The result — it did not converge

`converged: false`, `hit_bound_without_convergence: true`. Every round's fix opened the next hole; the spec grew **100 → 145 lines (+45%)**; round 4 **regressed a round-1 guarantee**. The fates table:

| Round | Fix applied (theory: "this closes the range-narrowing") | Refuted by (next round's finding) | Fate |
| --- | --- | --- | --- |
| 1 | Recorded **immutable base** at change creation, resolved identically by review/digest/scope | Immutability enforced only *post*-attestation; a model rewrites the base to a later ancestor *before* attestation → range silently narrows, all checks pass on the narrowed range with a genuine tick | ❌ |
| 2 | **Check-5**: base record byte-identical from its introducing commit through HEAD | A legitimate re-record is a *second* commit touching the record → check-5 permanently false → *"Archive SHALL be refused unless all hold"* → a rebased change is **unarchivable** (recovery path self-contradicts) | ❌ |
| 3 | **Re-anchor boundary** + `--ack-re-anchor` acknowledgment (lets a legit recovery reach archive) | The boundary verifies record **ownership**, not range **completeness**; an honest re-anchor to a too-late base silently archives unreviewed work, invisible in the file list | ❌ |
| 4 | **Range-completeness invariant**: base must be a strict ancestor of creation commit C | `git log -- <dir>` is **rename-blind** (`--follow` is single-file only); one commit that renames the change dir + rewrites the base defeats C-derivation *and* check-5 simultaneously. Separately: C = "earliest change-dir touch" is a false proxy — the round-1 pre-proposal-commit class is an *ancestor* of C, so the premise "B<C ⇒ range complete" is provably false | ❌ |
| — | **Thin the claim (D10)**: mechanical checks are accident tripwires + human-legibility aids; adversarial resistance = human reading the ledger + the R3 residual; a git-manipulation bypass is R3, out of scope, not a hole | *(terminates — a new bypass is no longer a "hole")* | ✅ |

Note what class **every** ❌ finding is: a **git-history manipulation** (pre-attestation rewrite, rename, interleaved pre-proposal commit). That is the tell.

## 3. Mechanism — why it cannot terminate

The gate's adversary, by construction of a model-driven apply loop, is **the model running the tool** — which **controls the repository**. A mechanical check over git provenance asks "does the committed history prove the reviewed range covers the change?" But the party being checked *authors* that history. So:

1. **The closable-bypass set is effectively unbounded.** Git history has open-endedly many narrowing vectors — rebase, directory rename, pre-proposal commits, grafts, `replace` refs, submodule/shallow boundaries, symlinked paths… Each mechanical check closes finitely many; the adversary picks another. Rounds 1–4 walked four of them and were nowhere near done.
2. **Every member reduces to the same residual.** "A repo-controlling model narrows the reviewed range" is *not* a separable, mechanically-closable class — it is an instance of **R3**: a model performing an affirmative forbidden act to defeat the gate, the same trust class the repo already accepts for every committed procedure (a session that ignores a committed rule already operates outside the workflow's contract). R3 is **irreducible in a single-machine model-only loop** — the design already concedes this for tick-forgery. Provenance-narrowing is the identical concession wearing a different hat.
3. **The design's own philosophy was the trap.** An earlier decision (D8) said *"delete every mechanically-closable failure class, own only the irreducible residual."* For git provenance, "mechanically-closable" is an infinite set, so the philosophy commits you to an infinite regress. Each round the verifiers *correctly* argued "this narrowing is git-computable, so per D8 it must be closed, not accepted" — and were right by that rule, which is exactly why the rule is wrong at the limit.

Adversarial review **never returns zero** (it is generative, not convergent), so "iterate until both models agree / no findings" has no fixed point *unless* the design stops *claiming* the property the reviewer keeps probing.

## 4. The correction — thin the *claim*, not just the range

Reverting only the range machinery would re-enter the tar pit on the next mechanism (gpt would hand the identical regress on the digest). The durable fix is **D10**: the mechanical checks — digest, clean-tree, exempt-by-act, scope classifier, named range — are **accident tripwires and human-legibility aids** (they catch *accidental* post-review drift and make the reviewed range legible so the human *can* judge adequacy), **not** adversarial-integrity guarantees. Adversarial resistance lives in exactly two places: **the human reading the complete ledger** (range + file list surfaced) and the **R3 boundary**. Once the design stops *claiming* airtightness, a newly-demonstrated git-manipulation bypass is **out of scope by definition, not a blocking hole** — the loop can't restart. Keep the cheap tripwires (they have real value against *accidental* drift and cost nothing); strip only the language that promises they stop a hostile model.

## 5. Second-order finding — the dev-tooling review cliff

~16 adversarial-review rounds ran across this session on a proposal at **0/21 tasks — zero implementation.** A dev-workflow tool's real test is **building and using it**; this very change's task 5.2 has the human dogfood the built tool for real. Past a small number of rounds, adversarial spec-review of dev tooling yields sharply diminishing returns and can actively *harm* (the +45% bloat, the regressed guarantee). The way out of the loop is to **stop reviewing and start applying**.

## 6. Re-verify by effect

Do **not** re-read the spec to "confirm it's thin." Re-run the convergence Workflow (`cross-model-converge`) against any mechanical-provenance gate spec and observe the **by-effect** signature: (a) each round's `gpt-verify` returns a *new* high whose class is a git-history manipulation; (b) the spec line count grows round over round; (c) `converged` never latches true within the bound. The headline is re-verified by that non-termination, not by any static read. The **correction** is re-verified by effect at apply time: build the tool (tasks 1–3) and run task 5.2's real dogfood — the tool's value shows up in *use*, and a demonstrated git-manipulation bypass is correctly logged as an R3 residual rather than triggering another spec round.

## 7. Reusable guidelines

- **G-TARPIT-1 — Don't harden a mechanical gate against the model that runs it.** When the adversary controls the repository/process the gate inspects, it wins any mechanical contest by construction. Route adversarial resistance through a human + a single named, accepted model-only-loop residual; scope the mechanical checks to **accident-catching + human-legibility**. *Thin the claim, not just the mechanism.*
- **G-TARPIT-2 — "Delete every mechanically-closable class" is a trap for open-ended domains.** For git provenance (and any domain with an unbounded manipulation surface) the closable set is effectively infinite; the philosophy mandates an infinite regress. Accept the irreducible residual explicitly and stop.
- **G-TARPIT-3 — Operationalize "until the models agree" as a reachable fixed point.** Adversarial review never returns zero. Convergence = *no open actionable finding beyond documented-accepted residuals*, and the round count is **bounded**; "zero concern / literal agreement" is not a terminating condition.
- **G-TARPIT-4 — Dev tooling is validated by building and using it.** Adversarial spec-review has a hard diminishing-returns cliff (empirically ~2–3 useful rounds here, then bloat). Past it, apply and dogfood; don't review the spec further.

## 8. Evidence artifacts

- The non-convergence itself: Workflow `wf_454a4338-7e8` result (`converged:false`, `hit_bound_without_convergence:true`) + its per-round `verdict`/`new_actionable` trail.
- The +45% bloat: `git show <round-N>:…/specs/cross-model-review/spec.md | wc -l` across `fe6be52`→`8451f22`.
- The four retired mechanisms: the `converge Round N` commit diffs.
- The correction on disk: design D10 + the Open-Questions tar-pit note in `add-cross-model-design-review`, and this file.

## 9. Confirming run (2026-07-12) — the *corrected* loop terminates; measure bloat by content, not lines

**Provenance:** 2026-07-12, a follow-up dogfood (Workflow `wf_15f6ecb9-aad`) that re-ran the loop **with the D10 correction and a hard anti-bloat floor already in place** — both to re-verify the headline by effect and to test whether a **proactive co-draft** variant (two models jointly negotiate an edit rather than attack-then-patch) escapes the tar pit. It does — and it terminated in **one round**.

**Setup.** Bounded proactive co-draft: Fable-5 proposes the single most valuable floor-respecting improvement *or none* → `gpt-5.6-sol` (codex `adversarial-review`, `xhigh`) verifies **∥** an inline Opus soundness pass → an Opus adjudicator enforces the floor, commits only a both-model-agreed edit, else reverts. Floor: the two spec files may shrink but not grow past their committed ceilings, and no round may re-introduce airtightness-vs-a-repo-controlling-model language. Convergence operationalized per **G-TARPIT-3** (no open actionable beyond accepted residuals); bound 5.

**Result — converged round 1, 0 net bytes.** `converged:true`, `rounds:1`, `appliedRounds:[]`; the spec stayed at 100/40, `openspec validate --strict` green, working tree clean. Against the original run (§2: 4 rounds non-converging / +45% bloat / round-4 regression) this is **1 round / 0 net change / floor intact**, ~263k tokens vs ~1.29M.

**What happened — the two models disagreed on the merits, and the correct answer won.** Fable-5 found a *real* coherence gap (archive-gate check-(4) under-encoded the exempt-by-act rule relative to its own scenario and the other three artifacts) and fixed it **within the line-count floor** — the file stayed exactly 100 lines. `gpt-5.6-sol` independently recomputed and objected: the line-neutral edit still grew the file **+34 words / +253 bytes** (2415→2449 words, 16459→16712 bytes) and duplicated wording already in design D7/D8, proposal, and tasks 3.3 → `agreesImprove:false`. The adjudicator sided with gpt and reverted. No change landed — in one round.

**Refinement — a line-count floor is a leaky proxy.** The floor gated on `wc -l` (100 unchanged ⇒ "passes"); the tar pit measures bloat as **content** (§2's +45% is by content). A single line simply got longer: +253 bytes at a fixed line count. gpt's content recompute (`wc -lwc`) caught what the line floor let through.

**Fates (this run).**

| Theory | Refuted / confirmed by | Fate |
| --- | --- | --- |
| A line-count floor bounds bloat | a line-neutral edit grew +253 bytes; only the `wc -lwc` content check caught it | ❌ → refined to content-count |
| Proactive co-draft re-enters the tar pit as the reactive loop did | converged round 1, 0 net change — no defect ⇒ nothing to converge on | ❌ (safe *because* the claim is already thin + a content floor holds) |
| The corrected (thin-claim + content-floor) loop terminates | `converged:true`, `hit_bound_without_convergence:false` | ✅ |

**Reproducible probe — the line-neutral-bloat detector the floor must use:**
```
F=openspec/changes/add-cross-model-design-review/specs/cross-model-review/spec.md
git show HEAD:"$F" | wc -lwc   # baseline: lines words bytes
wc -lwc < "$F"                 # working tree
```
A `1 1` numstat with a positive **word/byte** delta = a line got longer — invisible to `wc -l` alone. It **cannot** prove *semantic* duplication (that the added words are redundant); that stayed the cross-model judgment (gpt flagged duplication against design/proposal/tasks).

**Re-verify by effect.** Re-run the bounded floor-guarded co-draft loop on the thin proposal and watch: (a) convergence within 1–2 rounds; (b) 0 net word/byte growth in the spec files; (c) any edit that grows content — even at a fixed line count — caught and reverted. Never a static read.

**Reusable guideline.**

- **G-TARPIT-5 — Measure bloat by content (words/bytes), not lines; have an independent verifier recompute it.** A line-count ceiling is leaky — one line can grow without bound. Gate the anti-bloat floor on `wc -lwc` / a diff word-byte delta, and pair it with a verifier that recomputes the numbers rather than trusting the drafter's "line count unchanged." Constructive corollary to **G-TARPIT-4**: with the claim thinned and a content floor in place, a proactive two-model co-draft loop **converges immediately when there is no defect** — the remaining source of new information is building and using the tool, not more drafting rounds.

## 10. Evidence artifacts (§9 run)

- The convergence itself: Workflow `wf_15f6ecb9-aad` `result` + `journal.jsonl` (`converged:true`, `rounds:1`, `appliedRounds:[]`, `finalCrossSpecLines:100`).
- The reverted (never-committed) Fable edit + gpt's independent `wc -lwc` recompute: the activity render `wf_446e62d2-854` (verbatim codex `needs-attention` review).

## 11. Constructive confirmation (2026-07-12) — the content floor *admits* net-smaller fixes, it isn't only restrictive

**Provenance:** 2026-07-12, a second scoped dogfood (Workflow `wf_a0e713ea-101`) run *after* §9, to test whether the content floor (**G-TARPIT-5**) blocks *all* edits or only additive bloat. Target: the one concrete defect §9's run surfaced but reverted — archive-gate **check (4)** under-encoded the exempt-by-act rule (a later commit rewriting the digest-*excluded* attestation line "touched only bookkeeping surfaces" and passed all four checks, contradicting the requirement's own post-review-alteration scenario + design D7/D8 + proposal + tasks 3.3).

**Result — the fix landed, net-*smaller*.** Same loop shape (Fable-5 drafts → `gpt-5.6-sol` + inline Opus verify → Opus adjudicates), floor now content-based. Converged round 1, `action:applied`: check (4) rewritten to the full exempt-by-act rule (the attestation line appears exactly once, stays byte-identical from its introducing commit through archive, any later add/delete/modify invalidates it), **paid net-neutral by compressing duplicative prose in the same paragraph** — **2415→2404 words, 16459→16450 bytes** (strictly smaller), 100 lines, D10 intact, no airtightness vocabulary, `openspec validate --strict` green. Committed `3319785`.

**Mechanism — why the floor is constructive, not a straitjacket.** It gates on the *absolute* word/byte total vs the committed baseline, so it is blind to *where* content moves: a fix that compresses at least as much as it adds passes; only a net *addition* fails. §9's fix was pure addition (+253 bytes) → rejected; §11's fix added the guarantee **and** removed equal-or-more duplicative prose → net −9 bytes → accepted. The floor filters *bloat*, not *change*.

**Fates (this run).**

| Theory | Refuted / confirmed by | Fate |
| --- | --- | --- |
| A content floor is purely restrictive — it would block legitimate coherence fixes too | a genuine gap-closing fix landed net −11 words / −9 bytes, both models agreeing | ❌ (the floor admits net-smaller fixes) |
| The check-(4) gap was a false positive (the scenario already suffices, no fix needed) | both models independently judged the enumerated precondition — what an implementer builds from — genuinely incomplete; fix accepted | ❌ (real defect, now closed) |

**Reproducible probe.** Same detector as §9, now used as the *accept* gate: `baseline=$(git show HEAD:$F | wc -lwc)`, `working=$(wc -lwc < $F)`; **accept** iff working words ≤ baseline words **and** working bytes ≤ baseline bytes. It **cannot** judge whether *meaning* survived the compression — that stayed the cross-model + soundness judgment (Opus soundness flagged only two low-severity legibility notes, no meaning loss).

**Re-verify by effect.** Re-run the scoped loop (`cross-model-codraft-check4`) and observe a net-smaller edit *land* (a commit) while any +byte variant is reverted — the accept and reject arms exercised one per run (§11 accept, §9 reject).

**Reusable guideline (corollary to G-TARPIT-5).** A content floor gates *bloat, not change*: comparing absolute word/byte totals to the baseline admits any fix that compresses ≥ what it adds and rejects only net growth — so "fix the defect **and** stay ≤ baseline" is a satisfiable instruction, not a contradiction. Give the drafter the explicit permission-and-obligation to compress duplicative prose to pay for a genuine addition.

**Evidence artifacts.** Workflow `wf_a0e713ea-101` (`result`: `action:applied`, `finalWords:2404`, `finalBytes:16450`); commit `3319785` (`docs(openspec): codraft — close the check-(4) exempt-by-act gap net-neutral`) — the single-line normative diff reviewed on disk.
