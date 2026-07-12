# Cross-review ledger — `fix-cross-review-gate-task-emission`

> **Advisory in its entirety. Gate-inert.** Nothing here is read mechanically by any downstream step,
> and nothing here gates archive. Archive eligibility lives **entirely** in the human-attestation
> `⟶ archive-ritual` step-0 precondition (AGENTS.md), computed from git — never from this file.
> **"Converged" carries no gate force; a dismissal is a *proposal*, not an accepted state; this
> ledger is not a receipt.** Excluded by the digest tool, allowlisted by the scope classifier.

## Header — the transparency contract

> ⚠️ **HEADER REFRESHED IN ROUND 4 — and the old one was materially false.** It recorded
> *"Scope: `exit 0` — OUT of scope … the human overrode the classifier"* and a 6/12-file range.
> **Live today: `exit 10` — IN scope, 21 files.** That inversion is not a bookkeeping slip: it is
> **this run's most important finding** (R4-1). The header is the human's audit surface for the
> 6.2 attestation, so the stale values are corrected in place and the old ones named as retired.

| Field | Value |
| --- | --- |
| **Reviewed range** | base `B = 895088430b9b` (parent of `3815113`) .. HEAD — **round 4: HEAD = `c47a5c1`, 21 files.** *(Rounds 1–2: `3815113`, 6 files. Round 3: `dca6b11`, 12 files.)* |
| **Base rule** | positional: parent of the commit that added `proposal.md`. No ownership metadata. `B` is itself the **archive commit of `add-cross-model-design-review`** — the gate's own ship commit. |
| **Scope (mechanical)** | ⚠️ **`exit 10` — IN scope. Driven 100% by FOREIGN paths.** The two out-of-allowlist paths (`.claude/commands/xtty/cross-review.md`, `openspec/specs/cross-model-review/spec.md`) were introduced **entirely** by `brief-cross-review-pass-b` (`ca7b235`, `39fd78c`, `c47a5c1`). This change's **own 7 paths are 100% allowlisted**, and it stands at **1/20 tasks — zero implementation landed**. *(Rounds 1–3 read `exit 0`; the flip came from unrelated work, not from this change.)* |
| **Range pollution** | **21 paths: 7 own, 14 foreign (67%).** The 14 belong to the archived `brief-cross-review-pass-b`. |
| **Passes run** | **All three, all four rounds.** None skipped. |
| **Pass A** | Opus — `xtty-openspec-critic`, stamp **`Definition: v4 (2026-07-12)`**; delivery check **served == committed** ⇒ valid, **not stale** (v5 is this change's *unlanded* task 2.2, so v4 is the correct current stamp). Verdict: **ISSUES-FOUND**, 1 BLOCKER. |
| **Pass B** | **`gpt-5.6-sol`** (GPT family), model pinned at invocation. Effort **`xhigh`**, config-governed and readable (`~/.codex/config.toml`: `model_reasoning_effort = "xhigh"`) — `adversarial-review` exposes no per-call effort flag. Companion **`codex/1.0.6`**; `codex.available` + `auth.loggedIn` both true. Verdict: **needs-attention** (3 findings). |
| **Pass C** | Opus — **inline** agent (anti-roster: not a standing agent), effort invocation-controlled. Verdict: **needs-attention** (10 findings, 1 critical). *(Launch defect, recovered: the initial prompt carried a literal `<<<BRIEF>>>` placeholder; the real brief was delivered by follow-up message before the pass reported. Recorded, not hidden.)* |
| **Cross-family?** | **Yes** — genuinely two-family soundness (B = GPT, C = Opus). Not single-model. |
| **The brief (round 4)** | **Both soundness passes were briefed** (design intent + 8 claims-to-check `C1–C8` + a 4-item drill digest `D-1…D-4` + 2 do-not-reopen items `S1/S2`), staged out-of-repo (`mktemp`) and delivered as a **single positional**. Explicitly **additive** (*"…and report any material finding outside this brief"*) and **advisory** (zero gate force). **Full text reproduced in the appendix below**, so the human can audit the shared framing behind every consensus flag. |
| **Consensus discipline** | ⚠️ **Because the brief was shared, B∧C agreement on a *briefed* claim is NOT independent corroboration** — and this ledger does not flag it as such. Consensus is claimed **only** for findings that arose **outside** the brief. Round 3 already recorded a near-miss where B endorsed a claim A and C then refuted: **a model agreeing with you is not evidence.** |

### Reviewed file list (verbatim, `git diff --name-only B..HEAD` — 21 paths)

```
 OWN (7 — all inside the allowlist)
   openspec/changes/fix-cross-review-gate-task-emission/.openspec.yaml
   openspec/changes/fix-cross-review-gate-task-emission/cross-review-ledger.md
   openspec/changes/fix-cross-review-gate-task-emission/design.md
   openspec/changes/fix-cross-review-gate-task-emission/proposal.md
   openspec/changes/fix-cross-review-gate-task-emission/specs/coherence-review/spec.md
   openspec/changes/fix-cross-review-gate-task-emission/specs/cross-model-review/spec.md
   openspec/changes/fix-cross-review-gate-task-emission/tasks.md

 FOREIGN (14 — the archived `brief-cross-review-pass-b`; ★ = drives the exit-10 verdict)
 ★ .claude/commands/xtty/cross-review.md
 ★ openspec/specs/cross-model-review/spec.md
   AGENTS.md
   HISTORY.md
   research/README.md
   research/03-analysis/codex-review-integration-forensics.md
   research/03-analysis/cross-model-review-tar-pit-forensics.md
   research/03-analysis/cross-review-gate-defect-forensics.md
   openspec/changes/archive/2026-07-12-brief-cross-review-pass-b/.openspec.yaml
   openspec/changes/archive/2026-07-12-brief-cross-review-pass-b/cross-review-ledger.md
   openspec/changes/archive/2026-07-12-brief-cross-review-pass-b/design.md
   openspec/changes/archive/2026-07-12-brief-cross-review-pass-b/proposal.md
   openspec/changes/archive/2026-07-12-brief-cross-review-pass-b/specs/cross-model-review/spec.md
   openspec/changes/archive/2026-07-12-brief-cross-review-pass-b/tasks.md
```

*Honest limitation (unchanged): work committed **before** `proposal.md` outside the change dir is
invisible to `B..HEAD`. **The new limitation round 4 exposes is the opposite one** — work committed
**after** `proposal.md` by **anyone else** is fully inside `B..HEAD`, and it is what flipped this
change's scope verdict. The reviewed surface is a **range**, not a change.*

---

## Round 1 — the complete union ledger

| # | Src | Sev | Finding | Resolution |
| --- | --- | --- | --- | --- |
| **F1** | **A ∩ B ∩ C** | **BLOCKER / critical** | **The exit-arm model is wrong, and the design was fail-open.** The classifier scopes from `git diff --name-only B..HEAD` — **paths already committed** (`cross-review-scope.sh:54`). So its verdict is a function of *(HEAD, what is committed)*, moving `exit 2 → exit 0 → exit 10` across a change's lifecycle. **Only `exit 10` is positively informative.** The draft treated `exit 0` as "out of scope ⇒ **SHALL NOT flag**" — but the *normal post-propose state is `exit 0`*, so the new rule would have **mandated silence on a missing gate task for the entire propose→implement window**, regressing today's v4 REVIEW. Measured live on this very change: `exit 0`. | **FIXED.** D4 rewritten to four arms: `exit 10` ⇒ **BLOCKER**; `exit 0` ⇒ **semantic REVIEW, never suppressed**, stating what the classifier returned; `exit 2` uncommitted ⇒ **REVIEW**; `exit 2` committed (malformed range) ⇒ **BLOCKED-PREREQUISITE**. Spec delta + tasks 2.1/2.4/2.5 updated. |
| **F2** | **A ∩ C** | **BLOCKER / high** | **D1's load-bearing measurement was stale, and its false rationale was being frozen into the permanent spec.** D1 claimed *"the classifier cannot run at propose time (exit 2)"*. It **can** run — and returns a confident **wrong** answer (`exit 0`). The spec delta had baked *"cannot classify a change that is not yet committed"* into a SHALL block, which `openspec archive` would merge into `openspec/specs/` — a false mechanism claim in a spec that is supposed to record what is **true**. | **FIXED.** D1 restated: the classifier is **retrospective**; before implementation lands it returns a **false negative, not an abstention**; propose-time scope is a *prediction about paths that do not exist yet*, hence irreducibly semantic. The false clause is **removed from the spec prose**; the reasoning now lives only in `design.md`. |
| **F3** | B | medium | **`exit 2` conflated four distinct causes.** `cross-review-scope.sh` has four `die` paths: no-such-change-dir, no-introducing-commit, **range-omission** (dir touched before `proposal.md`), and root-commit. The draft treated *all* as "uncommitted ⇒ non-blocking REVIEW" — so a **committed but malformed** change would pass review and fail later at archive: exactly the late discovery this change exists to eliminate. | **FIXED.** `exit 2` is now disambiguated: `proposal.md` **absent from HEAD** ⇒ genuinely uncommitted ⇒ REVIEW; `proposal.md` **committed** ⇒ malformed range ⇒ **BLOCKED-PREREQUISITE** (archive will refuse on the same defect). Task 2.5 verifies both arms by effect. |
| **F4** | B | medium | **Enforcement checked presence but not cardinality or ordering.** The shipped spec requires *exactly one* attestation task, *after* the coherence task and *before* archive. The draft blocked only on **absent** / missing-wording. A **duplicate** stops the checkbox loop twice; a task placed **after** archive makes step-0 fail before the human is ever prompted. | **FIXED.** D6 added; the `exit 10` BLOCKER now covers **absent, duplicated, misordered, or mis-worded**. Task 2.3 verifies all four defect shapes by effect. |
| **F5** | C | high | **Pre-existing gate bypass: the scope call is blind to *uncommitted* implementation.** Clean-room verified (and independently reproduced here): with real product code present but **uncommitted**, the classifier reads `exit 0` ⇒ step-0 applies the precondition only *"for a change in scope"* ⇒ **the entire four-check precondition is skipped and `openspec archive` proceeds.** The counterintuitive crux: `cross-review-digest.sh`'s dirty-tree refusal does **not** backstop this, because it *is* check (3) — inside the precondition that was skipped. | **DOCUMENTED, deliberately not fixed here** (design R5). Fixing it means editing `cross-review-scope.sh`, which drags in the reviewed-base self-validation rule that task 6.3 correctly asserts does not apply to this change. **Routed to the base-resolution change:** give the classifier the same dirty-tree refusal the digest tool already has. **Pre-existing** — shipped with `add-cross-model-design-review`, not introduced here. |
| **F6** | C | high | **R3 materially understated the cost of pollution under a BLOCKER.** "One unnecessary review" is wrong. The digest covers HEAD content of **every** file in `B..HEAD` (33 files for `add-git-diff-wrap-toggle`; **315** for `add-ci-pipeline`), so it is a function of repo HEAD — **any** commit anywhere restages it. Once stale, re-attestation flips check (4) to `adds=2 dels=1` ⇒ **permanently failing**, no forward recovery. This change promotes that hazard from *once-per-dogfood* to *once-per-change*. | **PARTIALLY FIXED + ESCALATED.** R3/R4 rewritten to state the true cost. The **sequencing question is escalated to the human** (below) — it is not mine to decide. |
| **F7** | C + A | medium | **Migrating `add-ci-pipeline` appends an obligation with no viable path.** It has **no** `⟶ xtty-openspec-critic` task, so *"place after the critic task"* has **no anchor** (A's REVIEW). Its digest range is **315 files, 98.4% foreign**. Its remaining owner-step commits (pr-lint PR) would restage the digest, and check (4) forbids re-recording — so any attestation is **unsatisfiable**. | **FIXED by exclusion.** D7 added: `add-ci-pipeline` is **deliberately excluded** from migration, recorded as a decision, not an oversight. It is already `exit 10`, so the gate applies to it with or without this change — excluding it **strands nothing**; it merely declines to hand the human an impossible obligation. Its disposition belongs to the base-resolution change. Task 4.2 rewritten accordingly. |
| **F8** | C | medium | **Requirement prose grew +30% / +21% — the tar-pit bloat signature — with *rationale* inside SHALL blocks.** AGENTS.md requires requirements stay mechanism-neutral (the *what*); the *why* belongs in `design.md`. And the embedded rationale was the **factually wrong** one (F2), so bloat and inaccuracy compounded. | **PARTIALLY FIXED — residual recorded honestly.** All *"Because…"* rationale stripped from the SHALL blocks (`coherence-review` now has **zero**; the reasoning moved to `design.md`). **Residual, measured and NOT hidden: +23% / +31% (+26% combined).** Decomposed: **+213 words of new normative obligation** (emission rule; cardinality/ordering; the retrospective-classifier limit; the blocked-prerequisite arm) and **+341 words of four *required* scenarios** (the spec-delta format mandates scenarios for new normative behavior). **This is content, not rationale-bloat.** I did **not** compress normative text to hit a number — that would trade a real guarantee for a metric. Stated plainly rather than claiming a floor-compliance I cannot meet. |
| **F9** | C | low | **Check (4) confines the attestation-introducing commit's `tasks.md` hunk to *attestation line + ticks*.** So if a human adds the gate-task **text** and attests in the same commit, the hunk contains new task text ⇒ check (4) fails. | **FIXED as D3 — but I OVER-PROMOTED IT IN ROUND 1, and my own round-2 probe refuted me. See F12.** |
| **F12** | **self (adjudicator)** | **high** | **⚠️ I introduced a defect while fixing one.** In round 1 I promoted F9 into a load-bearing Decision claiming check (4) makes the one-layer alternative (*"skip the config rule; just make the critic BLOCK at pre-archive"*) **mechanically unsatisfiable**. **That is false.** Measured by effect (all five checks, real digest tool): a human prompted only at pre-archive adds the gate task in **commit A** and attests in **commit B** — `check(1) PASS · check(2) PASS · check(3) PASS · check(4a) adds=1 dels=0 PASS · check(4b) confinement SATISFIED`. Two ordinary commits. **The one-layer alternative IS satisfiable.** *(Pass C round 2 asserted D3 "stands" — but it only ever tested **bundling** (one commit, and an `--amend`); it never ran the two-commit path. I did not defer to it.)* | **FIXED.** D3 rewritten and **demoted**: check (4) does **not** force propose-time emission; it forbids **bundling**. What survives is a procedural constraint (the gate-task text must not ride the attestation commit ⇒ task 4.1 is a separate commit). **The two-layer split now stands on D1 alone** (propose-time scope is irreducibly semantic + G13), which is sufficient and was always the real justification. |
| **F10** | C | low | **The v5 critic is verified partly by itself, and a 6.1 run at `exit 0` would exercise the broken arm and report nothing.** | **FIXED.** Task 6.1 gains an explicit **validity precondition**: valid only after 2.3–2.5 pass **and** the implementation commits land (classifier ⇒ `exit 10`). A 6.1 run against an `exit 0` state **is not a pass** — the same posture as the existing v4-stamp rule. |
| **F11** | A | REVIEW | **Disk-drift: the change is missing its row** in AGENTS.md's *Open changes* table, which states it *"must match `openspec list`"*. | **FIXED immediately** (live drift, not deferrable work) — row added; task 3.2 ticked with a note. |

### Confirmed-clean by Pass A (fact-checked, no finding)

`openspec/config.yaml` has exactly **4** `rules.tasks` entries and **0** cross-review hits · critic **L42/L80** are as claimed · classifier ⇒ **exit 10** on both open changes · both carry **zero** attestation tasks · `cross-review-digest.sh` **does** normalize ticks + exclude the attestation line · AGENTS.md **does** refute an auto-firing marker · **both MODIFIED blocks paste the ENTIRE established requirement — nothing truncated** (diffed line-by-line) · proposal↔specs contract holds both ways · the change tail is well-formed · no `verification-harness` delta correctly justified · the `25 of 52` prose count re-derives exactly.

---

## Round 2 (N=2 — the bound; there is no round 3)

Re-ran all three passes against `eadd8d0`. **The round-1 BLOCKER is confirmed genuinely fixed on every normative surface** — both spec deltas, `design.md` D1/D4, `tasks.md` 2.1 — with **no silent truncation** (Pass A word-diffed both MODIFIED blocks against `openspec/specs/`: nothing lost) and **no new fail-open introduced**.

| # | Src | Sev | Finding | Resolution |
| --- | --- | --- | --- | --- |
| **G1** | A | **BLOCKER** | **The last surviving trace of the fail-open model.** `proposal.md`'s *Modified Capabilities → `coherence-review`* bullet still summarized the model in **two** states (exit 10, exit-2-uncommitted) and **omitted the exit-0 arm entirely** — the very arm the round-1 BLOCKER was about. Reads as a fall-through. | **FIXED.** The bullet now states all four arms, naming `exit 0` as *not yet knowable to be in scope* with a **REVIEW that is never suppressed**. |
| **G2** | **self (adjudicator)** | high | **F12 above** — I over-promoted D3 in round 1; my own probe refuted it. | **FIXED** (see F12). |
| **G3** | C | medium | **Surviving pre-D7 trace:** `proposal.md`'s **Impact** list still said `add-ci-pipeline/tasks.md` gets the task appended — contradicting D7 and task 4.2 in the artifact that states the change's file-level contract. | **FIXED.** Impact now names only `add-git-diff-wrap-toggle`, with the D7 exclusion stated. |
| **G4** | C | medium | **Confinement is load-bearing and the sequenced check-(4) change could destroy it.** An `--amend` bundle passes checks (1)(2)(3) **and** the counter; only confinement catches it. | ⚠️ **RETRACTED IN ROUND 3 — this was WRONG, and the constraint it imposed on the next change was actively harmful.** Passes A **and** C, independently, refuted it: **two plain forward commits defeat confinement exactly as they defeat the counter**, so it is *not* a guard. It is also **not separable** (its "introducing commit" anchor is well-defined only while the counter holds). And deleting the counter **deletes the gate's principal *accident* tripwire** (silent re-attestation). **The check-(4) fix is UNSETTLED**; the constraint is removed from design D3 and from the research doc, which now prescribes no fix. See round 3 below. |
| **G5** | C | medium | **D7's "excluding it strands nothing" is overstated.** The exclusion creates (a) a **standing, unclearable critic BLOCKER** on `add-ci-pipeline` — it is `exit 10` and will permanently lack the task, so every review emits a BLOCKER no D7-permitted action can clear; and (b) archive stays reachable for it **only** because step-0 check (1) greps the attestation **line**, not the gate **task**. | **FIXED.** Both recorded in D7 as **accepted residuals**, not glossed. The standing BLOCKER is accepted deliberately: a loud honest flag beats an unsatisfiable obligation. |
| **G6** | C | low | **The exit-2-committed arm asserted more than the rules deliver.** *Measured:* on a committed malformed range **both** tools refuse, so check (2) cannot be satisfied. **But** no committed rule *requires* step-0 to run on a refusal (its SHALL is conditioned on *"in scope"*; a refusal is neither in nor out). | **FIXED by softening.** The design now states the measurement **and** the honest limit — it no longer claims archive is *mechanically forced* to refuse. Same shape as R5; reduces to the accepted residual. |
| **G7** | **A ∩ C** | low/REVIEW | **D4's heading was stale fail-open vocabulary** — *"Three arms, and only `exit 10` may suppress or block"* over a four-row table, when **no arm suppresses** under the corrected model. | **FIXED** → *"Four arms; only `exit 10` carries blocker force, and no arm suppresses the check."* |
| **G8** | **A ∩ C** | low/REVIEW | **Disk-drift:** the AGENTS.md open-changes row (added in round 1) read `0/18`; disk says `1/20`. Born wrong in the same commit that ticked 3.2. | **FIXED** → `1/20`, computed from disk. |
| **G9** | A | REVIEW | **Pass 4 code-accuracy:** D8 claimed `add-git-diff-wrap-toggle` carries *"all four"* config-backed markers. Disk shows **three** — `⟶ xtty-ci-investigator` is absent, **correctly** (its rule is conditional on a failed-CI task). The argument survives; only the count was wrong. | **FIXED** → *"every applicable marker (three of four)"*, with the reason the fourth is absent. |
| **G10** | A | REVIEW | **HEAD-dependent numbers self-invalidate.** *"315 files"* / *"33 files"* measured **316** / **34** one commit later — which is R4's own point, demonstrated on the design's own prose. | **FIXED** → written as `~N (HEAD-dependent)`. |
| **G11** | **B** | **high ×2** | **Explicit "no-ship":** *"leaves a verified archive bypass and makes an unrecoverable attestation deadlock routine."* Both are R5 and R4 — already documented residuals. Codex demands the dirty-tree scope fix and the re-attestation fix **land first**. | **NOT a new finding — it is the SEQUENCING argument, and it now carries a TWO-MODEL consensus** (C in round 1, B in round 2). **Escalated below.** *Codex's proposed remedy — "append-only, superseding attestation generations" — is **DISMISSED**: it is the **refuted "recoverable attestation epoch"** (G-TARPIT-1/2). Its **sequencing** argument stands; its **remedy** does not.* |

**Pass C's convergence call (G-TARPIT-3):** *"converged modulo bounded edits; no open actionable beyond documented-accepted residuals once they land. NO round 3 is warranted — do not iterate to agreement."* Those edits have landed. **Bound reached; the loop stops here.**

---

## Round 3 (a NEW human-launched run — the capture is now in the reviewed range)

Range extended to `dca6b11` (12 paths), adding the research capture. Passes A ‖ B ‖ C re-run.

| # | Src | Sev | Finding | Resolution |
| --- | --- | --- | --- | --- |
| **H1** | **A ∩ C** | **critical** | **The research doc's operative prescription was WRONG, and my round-1 "correction" (G4) was the error.** I claimed the confinement clause is *"the sole adversarial guard"* — in explicit contrast to the counter's *"adversarially null"*. **Both passes independently refuted it:** apply the doc's *own* one-step generalization (the split-commit forge) and **confinement collapses identically** — commit A carries the content, commit B carries attestation + ticks (confined *by construction*) ⇒ **all four checks pass on unreviewed content**. Measured. My asymmetric standard (adversarial for one clause, bundle-only for the other) manufactured a guard that does not exist. | **FIXED — prescription RETRACTED.** |
| **H2** | **A ∩ C** | **high** | **Check (4) has THREE clauses, not two.** The shipped spec adds *"every later commit touches only the remaining bookkeeping surfaces"*. My 4a/4b decomposition **omitted it** — in the section the capture-depth bar most demands be right (*settle the mechanism*). | **FIXED** — §1 now enumerates all three, with the decisive provenance: **`3319785` added only the counter; the other two pre-existed it.** |
| **H3** | C | **high** | **The confinement clause is NOT separable from the counter.** Its subject is *"the attestation-**introducing** commit"* — uniquely defined **only because** the counter guarantees `adds==1`. Delete the counter (which legalises a second add — the entire point) and the anchor is **ambiguous**: anchored to the *first* add, an actor re-attests later and confinement passes against the *original* clean commit. **So "delete 4a, MUST NOT touch 4b" is not implementable** — any deletion **must re-anchor** it. | **FIXED** — the instruction is retracted as *actively harmful*; recorded as a fact the fix must handle. |
| **H4** | C | **high** | **⚠️ Deleting the counter deletes the gate's PRINCIPAL ACCIDENT TRIPWIRE.** Check (2)'s teeth come **entirely** from the attested value being frozen by `dels==0`. Delete it and check (2) degrades to *"the value equals itself"*: **measured** — after drift, a model refreshes the digest in **one plain forward commit** and check (2) goes **green on content the human never re-read**; **only the counter catches it**. This is not adversarial — it is *the most plausible accident in this repo* (an over-helpful model "repairing" a stale attestation). **I condemned the counter on adversarial grounds — the exact error my own G-GATE-2 forbids.** | **FIXED — and it is the reason the prescription is retracted.** ❗ **The counter's value and its liveness cost are THE SAME PROPERTY**: a silent re-attestation and an honest one are *mechanically identical acts*. You cannot delete the cost without deleting the value. |
| **H5** | C | medium | **F6 over-claimed "no metadata-free fix".** Two of its four consequences *do* have clean metadata-free fixes: the archived-ledger **glob** (a one-line fix the doc names and then files under "no fix"), and **head-pinning** — `base=`/`head=` are recorded on the attestation line but the digest **reads neither** (0 references; it re-derives `B` positionally and hashes at live HEAD), so they are **decorative**. | **FIXED** — claim narrowed to *"no metadata-free narrowing of the reviewed **file set**"*; head-pinning recorded as an **unevaluated candidate**, explicitly **not endorsed** (it does not resolve H4's tension). |
| **H6** | C | medium | **G-GATE-5 was distilled from my mistake** and would be cited to block the correct fix. | **FIXED** — rewritten on C's **symmetric-standard** lesson: *test every clause against the same adversary/accident model; an asymmetric standard makes a null clause look load-bearing*; plus *when your prescription flips every round, **stop prescribing***. |
| **H7** | **B** | medium | **The "strands nothing" claim survived in `proposal.md` + `tasks.md`** after design D7 had already recorded the standing unclearable BLOCKER as an accepted residual. | **FIXED** — all three artifacts now agree. |
| **H8** | **B** | high ×2 | Sequencing (**third** consecutive Codex "no-ship"). Notably **B has now adopted the confinement refinement**, recommending *"…preserving the confinement clause"* — which **H1 then refuted.** A model endorsing a claim is not evidence for it. | **ESCALATED** (below), and B's endorsement is recorded as a **near-miss**: the tri-pass nearly ratified a false claim by agreement. |

**The meta-finding — and it is the most valuable output of this run.** The check-(4) prescription **flipped on every round**: *keep it* → *delete it entirely* → *delete-the-counter-keep-confinement* → **all wrong**. That is the **tar pit's non-termination signature applied to *un*-hardening**, and the correct response is **G-TARPIT-3/4**: **stop prescribing.** The research doc now records the **measurements** (solid) and the **tension** (genuine, two-horned, unresolved), and explicitly **routes the fix design to an `/opsx:explore`**. *A forensics doc records what is; it must not pre-decide a fix that three review rounds could not settle.*

---

## Round 4 (a NEW human-launched run — and the range flipped under the change's feet)

**Why this run found more than rounds 1–3 combined:** between round 3 and now, an entire other change
(`brief-cross-review-pass-b`) was proposed, implemented, attested and **archived** — *inside this
change's reviewed range*. That did two things: it grew the range from 12 → 21 paths (67% foreign),
and it **flipped the scope verdict from `exit 0` to `exit 10`** — falsifying the design's central
demonstration. Rounds 1–3 could not have caught this: the range was clean then (*"0 foreign"*).

| # | Src | Sev | Finding | Resolution |
| --- | --- | --- | --- | --- |
| **R4-1** | **self (adjudicator)**, re-derived by **A ∩ B ∩ C** | **BLOCKER** | **The classifier reads `exit 10` on this change RIGHT NOW — at 1/20 tasks, zero implementation landed — driven 100% by FOREIGN paths.** Both out-of-allowlist paths belong to `brief-cross-review-pass-b`; this change's own 7 are 100% allowlisted. **Design D1's lifecycle table is dead** (*"propose committed → `exit 0`"*), and with it the change's headline self-demonstration (*"it reads `exit 0` — the bug reproducing on itself"*). **Task 6.1's validity precondition is now a FALSE-POSITIVE TEST:** it disqualifies a run *"while the change still reads `exit 0`"* — a condition that **can never fire again** — so it would green-light a pre-archive review of an unimplemented change. *(I briefed all three passes on this, so their agreement is **confirmation, not independent consensus** — but each re-derived it from disk, and C **extended** it structurally: see R4-2.)* | **FIXED.** **D1 re-anchored** on the classifier's **non-attributive** nature (the property `D-1` does *not* falsify — see R4-2) and the dead table replaced with the live `exit 10` measurement. **Task 6.1's precondition replaced with an ATTRIBUTIVE test**: assert this change's own implementation paths (`openspec/config.yaml`, `.claude/agents/xtty-openspec-critic.md`) are present in `B..HEAD` **and** tasks 1.1–2.2 are ticked+committed. The classifier proxy is gone. |
| **R4-2** | **C** *(then confirmed on disk)* | **critical** | **⚠️ THE DEEPEST FINDING OF THE RUN — and no pass was briefed on it. The pollution is STRUCTURAL, not a quirk, and the spec was about to FREEZE A FALSE DESCRIPTION of the classifier into `openspec/specs/`.** Two parts. **(a) The latch:** `openspec archive` **always** writes `openspec/specs/**`, which is **not** in the allowlist (verified: `cross-review-scope.sh:45-51` allows only `openspec/changes/*`, `research/*`, the 4 root docs, `packer/README.md`). So **any change left open across any other change's archive latches to `exit 10` permanently and can never return.** With concurrent changes — the repo's normal state — that is the **common case**. Measured: **all three** open changes read `exit 10`; for **two** of them every driving path is foreign. **(b) The false spec text:** the MODIFIED requirement still called it *"a mechanical classifier over **the change's changed paths**"* and kept the scenario *"a pure-documentation **change** … is out of scope"*. **Both false** — it scopes over a repo-wide **range**. And `openspec archive` would merge that into `openspec/specs/`, which the repo defines as *what is true* — **the exact F2 error class (a false mechanism claim frozen into the permanent spec), recurring in the opposite direction, in the very paragraph this change edits, on the verdict this change is promoting to BLOCKER force.** | **FIXED.** The spec delta now describes the classifier correctly and normatively: it scopes over the **reviewed range**; its verdict is **non-attributive** (an in-scope result says only that *some* path is out-of-allowlist — never *whose*), **retrospective**, and **monotone under intervening archives**. An in-scope verdict **SHALL NOT** be read as evidence the change's own implementation landed. The pure-docs scenario is corrected (`change` → **range**) and a **new scenario** added for the foreign-driven verdict. *(Pass A reached the same tension independently at REVIEW severity — "latent tension carried into the permanent spec" — so this is **genuine A ∩ C consensus, arising OUTSIDE the brief.**)* |
| **R4-3** | **B** | **high** | **D7's "unsatisfiable" premise is REFUTED — the whole migrate/exclude split rests on a false claim.** The design excluded `add-ci-pipeline` because its attestation would be *"unsatisfiable"* (owner-step commits would restage the HEAD-dependent digest, and check (4) forbids re-recording). **Verified on disk: false.** Its remaining work — **5.4** (a test PR) and **5.5** (a GitHub **repo setting**, not even a commit) — sits **before** its tail. So *owner-steps → commit → **then** attest → **then** archive* is an ordinary, available ordering with **zero** intervening commits. And the missing `⟶ xtty-openspec-critic` anchor (a real gap — confirmed) is fixable by simply *adding one*. The range is a **cost** (324 paths, 98.5% foreign), not an impossibility — **and the design migrates `add-git-diff-wrap-toggle` at 83% foreign.** The line between *"migrate at 83%"* and *"impossible at 98.5%"* is **arbitrary and unstated.** | **PREMISE FIXED; DECISION ESCALATED (Q3).** D7 rewritten: the unsatisfiability claim is retracted with the measurement that kills it, and the decision is **withdrawn from the model**. Tasks 4.1–4.3 are marked **⛔ BLOCKED ON Q3** with the three branches spelled out. **I did not choose** — this is a scope/policy call about another change's obligations. |
| **R4-4** | **C** | **medium** | **The proposal's evidence is ANACHRONISTIC — and it refutes the brief's C4 in *both* directions.** The *"the gate is inert / doesn't work when used"* severity rested on *"both open changes are in scope and carry zero attestation tasks."* But **both predate the obligation**: `add-cross-model-design-review` archived **2026-07-12**; `add-ci-pipeline` proposed **2026-06-30** (12 days before), `add-git-diff-wrap-toggle` **2026-07-11** (1 day before). Neither could emit a task for a rule that did not exist — they evidence a **retroactively-applied rule**, not a broken loop. And the **only** post-gate change (`brief-cross-review-pass-b`) **did** carry the task, with `config.yaml` at 0 hits. **C then refuted its own counter-evidence too:** that data point is *also* confounded (a gate-saturated session; git cannot distinguish loop-emitted from hand-added). **Net: no clean evidence in either direction, n=1 either way.** | **FIXED — severity claim narrowed, not defended.** The *"inert / doesn't work when used"* framing is **withdrawn as unsupported**. The Why section now states the honest record (with the date table) and re-grounds the change on a **structural** argument that needs no empirical claim: the obligation lives only in prose, and `/opsx:propose` reads `config.yaml`, not `AGENTS.md` — the repo's own **G13**, already settled by measurement elsewhere. Prose is a fragile carrier; `rules.tasks` is the surface the loop **provably** reads. *(This is a model **refuting the brief that briefed it** — exactly what an additive brief is supposed to permit.)* |
| **R4-5** | **B ∩ C** | **high** | **D5's "over-emission costs one strikeable task" is FALSE — there is no strike, and D4's own BLOCKER closes the hatch.** (1) **No striking procedure exists anywhere** — every hit for *strike/remove/delete the task* across AGENTS.md, both established specs, and this change is **the assertion itself**: no actor, no authority, no form. The model may not **tick** the task; nothing sanctions it **deleting** the task either, and no rule distinguishes *"strike an over-emitted task"* from *"delete an inconvenient gate task"* — the very act the gate exists to prevent. (2) **The BLOCKER re-raises it:** under the latch (R4-2), an open change reads `exit 10`; D4 then **mandates a BLOCKER** if the tail lacks the task — so striking it **immediately produces a BLOCKER**. **The two halves of the change are in tension: emission is justified as cheap *because reversible*; enforcement makes it irreversible.** | **CLAIM RETRACTED; RESOLUTION ESCALATED.** D5 no longer claims cheapness-by-reversibility. It now claims only the **direction** (fail-closed errs toward an extra obligation, never a missed review) and states the tension plainly. The fix — define the strike as a first-class human-only act, or accept the task as effectively mandatory — is **escalated**, not chosen. *(Briefed as C5, so **not** flagged as independent consensus — though C's mechanism, the BLOCKER closing the hatch, went beyond the brief.)* |
| **R4-6** | **A** | **REVIEW** | **⚠️ The cardinality BLOCKER would FALSE-POSITIVE on this very change.** D6 mandates a BLOCKER on a **duplicated** gate task. But this change's own `tasks.md` carries **three** lines with HUMAN-ONLY / model-MUST-STOP wording: **1.1** (the task that *authors* the emission rule), **4.1/4.2** (the task that *migrates* the gate task into another change's tail), and **6.2** (the one real gate task). A naive grep-based cardinality check reports a **duplicate on the change that introduces the check** — failing 6.1's own self-review with a self-inflicted false red. **The design never says how the check distinguishes *the task* from a line *describing* it.** | **FIXED.** Both the `coherence-review` spec delta and task 2.1 now state the rule: cardinality counts **gate *tasks*, not gate *mentions*** — a line that **describes, specifies, or migrates** a gate task is not counted — and where the two cannot be told apart the check reports a **REVIEW naming the ambiguity**, never a false-duplicate BLOCKER. A **new scenario** covers it. |
| **R4-7** | **A** | **REVIEW** | **Task 2.4 — the arm the change itself calls "the single most important" — has NO natural specimen left on disk.** It requires *"a committed-but-unimplemented change with no gate task"* to yield a REVIEW. But **all three** open changes now read `exit 10` (the latch), **including `add-git-diff-wrap-toggle`** (0/20 tasks, own paths 100% allowlisted). So testing this arm against any real change would **silently exercise the exit-10 arm instead** and report a **false pass** — the precise failure mode the task exists to prevent. | **FIXED.** Task 2.4 now states the specimen problem explicitly and requires a **synthesized scratch change on a clean range** (proposed at HEAD so its range holds only its own allowlisted artifacts), with the classifier confirmed at `exit 0` **before** asserting the REVIEW. |
| **R4-8** | **B ∩ C** | **medium** | **Alarm fatigue is wider than D7 models — and the "Enforcement" layer is not executable.** Because the latch is structural (R4-2), the BLOCKER will be **red by default on nearly every open change**, not just `add-ci-pipeline`. Compounding it: **nothing executable consumes a critic BLOCKER** — no script refuses, no gate fires. Per the repo's own **G-GATE-1** (*"fail-closed is an instruction-following convention, not an enforced property"*), this change upgrades the check from **REVIEW-prose to BLOCKER-prose**. Both are instruction-following. So the design's Goals bullet — *"a missing … gate task is **mechanically blocking**"* — **overclaims**: it is mechanically **detected**, not mechanically **blocking**. And a check that is red by default spends the only currency it has: **the reader's attention.** | **FIXED (honesty) + ESCALATED (substance).** The Goals bullet now says **detected, not enforced**, and cites G-GATE-1 explicitly. Whether an arm this coarse should carry BLOCKER force **at all** is now **open question Q2** — with the concrete alternative named (narrow `cross-review-scope.sh` to the change's own paths **first**, which is already routed to the base-resolution change and would dissolve most of this). **Not chosen by the model.** |
| **R4-9** | **A ∩ C** | **medium** | **The ledger header — the human's audit surface for the 6.2 attestation — was materially FALSE.** It recorded *"Scope: **`exit 0` — OUT of scope** … the human launched the review anyway, **overriding the classifier**"* and a 6/12-file range. Live: **`exit 10` — IN scope, 21 files**. A human attesting today would read a header that understates the reviewed surface by 15 files and tells them the **opposite** of the classifier's actual verdict. | **FIXED.** Header rebuilt from disk: live base/HEAD, the **21-path verbatim file list** split **own (7) vs foreign (14)** with the two exit-10 drivers starred, the brief reproduced in full, and the retired `exit 0` framing named as retired. *(Both passes flagged it **outside the brief** — genuine consensus.)* |
| **R4-10** | **A** | **REVIEW** | **HEAD-dependent counts: three different values for one quantity, all stale.** `add-ci-pipeline`'s digest range appears as *"~315"* (proposal), *"~316"* (R4), *"~317"* (D7/task 4.2). Disk today: **324** (319 foreign = 98.5%). `add-git-diff-wrap-toggle`: *"~33"* → disk **42**. All hedged `~` and labeled HEAD-dependent per round 2's G10 fix, so **informational** — but they should at least agree with each other. **This is G10 recurring a third time**, which is itself R4's point: HEAD-dependent numbers self-invalidate. | **FIXED.** All counts re-derived from disk and unified (**324 / 319 / 98.5%**; **42 / 35 / 83%**), presented in R3 as a **table** so they cannot drift apart independently again. |
| **R4-11** | **C** | low | **The spec delta drops the recorded *reason* there is no auto-firing marker** (*"…the point-of-tick grammar can express only delegate-to-subagent or run-inline, and a paid review that must not fire on task-arrival is neither"*). The prohibition survives; the **rationale** does not. In a repo that runs an explicit *"Learned refutations — do not re-propose"* discipline, deleting the reason from the durable artifact while keeping only the rule is **exactly how a settled refutation gets re-proposed later**. | **ACCEPTED AS-IS — dismissal recorded.** This is F8's intended mechanism-neutrality trim (AGENTS.md: requirements state the *what*; the *why* lives in `design.md`), and the reason **is** durably recorded — in **design D2** and in AGENTS.md's refutation list, both of which survive archive. Restoring it to the SHALL block would re-import the rationale-bloat F8 removed. **A real trade-off, noted not hidden**; if the refutation is ever re-proposed, this dismissal is where to look. |
| **R4-12** | **C** | low | **Task 6.3's *"no self-validation hazard"* reads as a blanket clearance and is not one.** True for the two gate **scripts** (this change touches neither — verified). But the change **authors the v5 critic**, which *is* the enforcement layer it introduces, and task 6.1 then runs that v5 critic **on this change**. AGENTS.md's reviewed-base rule is scoped to the two scripts, so the critic falls **outside** it. | **FIXED.** Task 6.3's parenthetical narrowed: the clearance covers the two scripts only; the v5 self-review is bounded by 6.1's validity precondition — **which is exactly why that precondition had to become attributive** (R4-1) rather than the dead classifier proxy. Bounded, not fatal (a critic BLOCKER is advisory), but no longer overstated. |

### Confirmed clean by round 4 (fact-checked against disk — no finding)

**Spec-delta integrity (the highest-stakes check, and it passed in all three passes independently):**
the `cross-model-review` MODIFIED block pastes the **entire current post-`c47a5c1` established
requirement** — all 4 paragraphs and all 7 scenarios preserved (6 verbatim + 1 deliberately
**corrected**, `change` → **range**, because it was false as written), plus 3 new. `coherence-review`:
entire block, 6 scenarios retained + the old gate scenario deliberately replaced by 3 arm-specific
ones + 1 new. **No silent truncation. No collision** with `brief-cross-review-pass-b`'s newly-added
*"Soundness passes are briefed"* requirement (it **ADDED** a separate requirement and did not touch
the one this change modifies — so the paste is against current text). `openspec validate --strict` ⇒
**valid**; 10/10 four-hash scenarios in each delta, **0** three-hash, **0** five-hash.

**Pass-4 code-accuracy — every other design claim verified TRUE on disk:** `config.yaml` has exactly
**4** `rules.tasks` entries and **0** cross-review/attestation hits ✓ · critic **L42** = *"heuristic →
REVIEW … never a BLOCKER"* and **L80** = *"REVIEW findings never block"* ✓ (line numbers exact) ·
`cross-review-scope.sh:54` = `git diff --name-only "$B"..HEAD` ✓ · both scripts refuse a dirty tree /
`range-omission` ✓ · digest excludes the ledger + attestation line and normalizes checkbox state ✓ ·
`add-ci-pipeline` has **no** `⟶ xtty-openspec-critic` task ✓ (D7's anchor claim — the *one* part of D7
that held) · `add-git-diff-wrap-toggle` carries **3 of 4** applicable markers and **zero** attestation
tasks ✓ · proposal↔specs contract holds **both** directions ✓ · delegation markers + change tail
well-formed ✓ · no `verification-harness` delta correctly justified ✓ · AGENTS.md open-changes row
`1/20` == disk ✓ · established-specs list (23) == `ls openspec/specs/` ✓.

**Inherited disk-drift (NOT introduced by this change, reported for the human):** `AGENTS.md:201` says
*"25 of the **52** archived changes carried a harness delta"* — disk: **53** archived (the denominator
went stale at `c47a5c1`, the `brief-cross-review-pass-b` archive). Numerator (25) is correct.

---

## ⚠️ ESCALATED TO THE HUMAN — the sequencing decision (F6 / G11) — **TWO-MODEL CONSENSUS**

**This is the most consequential open question, and the model is not the right party to settle it.**

**Both soundness passes, independently, on different model families, argue this change should land *after* the check-(4) deletion and the range-pollution/dirty-tree fix.** Pass C said so in round 1; Pass B (`gpt-5.6-sol`) returned an explicit **"no-ship"** in round 2. That is the run's **only two-model consensus besides the round-1 BLOCKER**, and it is not a finding I can resolve by editing an artifact.

**The case for landing the other two first:**
- **R5 — a *verified* archive bypass.** With implementation present but **uncommitted**, the classifier reads `exit 0` ⇒ step-0's **entire** precondition is skipped (including the digest's dirty-tree refusal, which lives *inside* it) ⇒ `openspec archive` proceeds. This change makes gate-task enforcement routine **while that bypass is open**.
- **R4 — an *unrecoverable* attestation model.** The digest covers HEAD content of a **~33–316-file, mostly-foreign** range, so **any** commit anywhere restages it; check (4) then forbids re-recording. This change promotes that hazard from *once-per-dogfood* to *once-per-change*.

**The case for landing this one first** (from the explore brief): the deadlock is only *reachable* once a change acquires an attestation, and today **nothing prompts one**.

**A fact that constrains both readings:** the archive gate **already** applies to both open changes (`exit 10`) **with or without this change**. So this change does **not create** the exposure — it makes it **routine**.

**⚠️ RETRACTED — what round 3 says about whichever check-(4) change lands.** An earlier version of this ledger instructed the next change to *"target the counter and **preserve the separable confinement clause**"*. **That instruction is withdrawn — it was wrong and actively harmful** (H1/H3/H4): the confinement clause is **adversarially null too**, is **not separable** (its anchor depends on the counter), and **deleting the counter deletes the gate's principal *accident* tripwire** (silent re-attestation — measured). **The check-(4) fix is UNSETTLED.** This ledger — and the research capture — now impose **no constraint** on it beyond the measured facts. Design it in an `/opsx:explore` against **both horns** of the tension; do not inherit a prescription from any model-authored artifact here.

**Both positions are coherent. The human decides the order — and the model has not decided it.**

### ⚠️ Round-4 update to the sequencing escalation — it is no longer hypothetical

Codex has now returned a **fourth consecutive no-ship**. But the material change in round 4 is not
the vote count — **it is that the pollution hazard the sequencing argument is *about* has now
actually bitten this very change.** Rounds 1–3 argued the risk in the abstract, on a clean range.
Round 4 measured it: this change reads **`exit 10`, driven 100% by foreign paths, with zero
implementation landed**, and the mechanism is **structural** (`openspec archive` always writes the
non-allowlisted `openspec/specs/**`, so *any* change open across *any* archive latches in-scope
permanently and can never return).

That does not settle the order — the counter-argument still stands (the deadlock is only *reachable*
once a change acquires an attestation, and today nothing prompts one). But the human should weigh it
knowing that **the range-narrowing fix routed to the base-resolution change would dissolve Q2, most
of Q3, and much of R4/R5 at once** — which is precisely what "land that first" would buy.

---

## ⚠️ THE THREE DECISIONS ROUND 4 PUTS TO THE HUMAN — **the model chose none of them**

| | Question | Why it is not the model's call |
| --- | --- | --- |
| **Q1** | **Sequencing** — land this change now, or after the range-pollution + check-(4) fixes? | Standing escalation, now 4 consecutive Codex no-ships, **and now empirically demonstrated** (above). A scope/order call with real cost either way. |
| **Q2** | **Should the `exit 10` arm carry BLOCKER force at all?** *(new)* | The verdict is **non-attributive** and **latches**: for 2 of 3 open changes it is driven **entirely by foreign paths**. The BLOCKER stays **safe in direction** (it can never open a bypass) but will be **red by default on nearly every change** — and since nothing executable consumes it (**G-GATE-1**), its whole force *is* the reader's attention. Alternative: **narrow the classifier first** (a `cross-review-scope.sh` edit, already routed to the base-resolution change). |
| **Q3** | **Migrate, grandfather, or exclude?** *(new)* | D7's *"unsatisfiable"* premise is **refuted**, and **both** open changes **predate the obligation** (by 12 days / 1 day) — this is a **retroactively-applied rule**. Options: **(a)** migrate both; **(b)** **grandfather** pre-gate changes (a mechanical, dateable rule vs the gate's ship commit `8950884`) and migrate neither; **(c)** keep the split + accept a standing unclearable BLOCKER. Tasks 4.1–4.3 are **⛔ blocked** pending this. |

## Why this run STOPS here instead of running a round 5

The protocol permits a bounded **N = 2** fix→re-review loop. **I am deliberately stopping after one
round of fixes, and not re-reviewing.** The residual is **not a review-convergence problem** — it is
**three design-shape decisions that belong to the human** (Q1–Q3). Re-running the passes on patched
prose would predictably return a **fifth** Codex no-ship on Q1 and re-litigate Q2/Q3 without new
information: that is the tar pit's **non-termination signature** (**G-TARPIT-3**), and the repo's own
rule is *operationalize convergence as "no open actionable beyond documented-accepted residuals"* —
which is exactly where this now sits. Every finding is either **fixed** or **escalated with its
measurement attached**. **G-TARPIT-4** applies too: what this change needs next is not another
spec-review round but a **human decision**, and then **building and using it**.

---

## Appendix — the brief given to both soundness passes (for auditing shared framing)

Reproduced so the human can judge which agreements are **independent** and which merely reflect the
brief. **Findings arising OUTSIDE this brief — and therefore genuinely independent — are R4-2 (A ∩ C),
R4-3 (B), R4-4 (C, which *refuted* the brief), R4-6 (A), R4-7 (A), R4-9 (A ∩ C), R4-10 (A), R4-11 (C),
R4-12 (C).** The brief's own claims (`C1`–`C8`, drills `D-1`–`D-4`) were **confirmed** by the passes,
which is **not** independent corroboration and is **not** flagged as consensus anywhere above.

<details>
<summary>Full brief text (staged out-of-repo, delivered as a single positional)</summary>

The brief carried, in order: **(1) a scope warning** — the diff is 67% foreign (7 own files vs 14 from
the archived `brief-cross-review-pass-b`), review the foreign files only for cross-contamination;
**(2) design intent** — the two-layer emission/enforcement fix and the measured defect it addresses;
**(3) eight claims to soundness-check**, framed as *"challenge these; do not confirm them"* — `C1` D1's
lifecycle table, `C2` task 6.1's validity precondition, `C3` what `exit 10` actually asserts under
pollution, `C4` the *"gate is inert"* premise vs the `brief-cross-review-pass-b` natural experiment,
`C5` whether over-emission is really cheap / who may strike the task, `C6` D7's exclusion and alarm
fatigue, `C7` whether the two-layer split still earns its keep with D3 demoted, `C8` spec-delta
truncation; **(4) a four-item digest of drills I had already run** (`D-1` the exit-10-from-foreign-paths
measurement, `D-2` the pollution census, `D-3` the config/critic premise checks, `D-4` the truncation
check), each explicitly framed as *"claims to challenge, not established fact"*; **(5) two do-not-reopen
items** — `S1` the standing sequencing escalation, `S2` the check-(4) fix (formally UNSETTLED; the repo
forbids re-litigating it in-model, and *"append-only attestation generations"* is already refuted);
and **(6) the additive instruction**: *"Soundness-check the claims above **AND report any material
finding outside this brief** … Do not agree with a claim merely because I asserted it; a model agreeing
with the brief is not evidence for the brief."*

**The additive instruction worked, and is worth recording as evidence for the A′ brief design:** the
passes' **most valuable findings came from outside the brief** (R4-2's structural latch + false spec
text; R4-3's refutation of D7's premise), and Pass C **used the licence to refute the brief itself**
(R4-4 — it dismantled my `C4` framing in *both* directions rather than picking the side I leaned
toward). A brief that had merely been *confirmed* would have been a warning sign, not a result.

</details>

---

## Authority restatement (non-negotiable)

This entire ledger is **advisory**. **"Converged" has no gate force.** Every resolution above is a
**proposal**, not an accepted state. This file is **not a receipt** and produces **no reviewed-state
binding**. Archive eligibility is decided **only** by the human-attestation `⟶ archive-ritual` step-0
precondition, computed from git.

**The model has not ticked task 6.2, has not computed any digest, and has written no attestation
line.** If and when this change is archived, the **human** reads this complete ledger, runs
`scripts/cross-review-digest.sh fix-cross-review-gate-task-emission` **themselves**, and records the
digest on the delimited attestation line.
