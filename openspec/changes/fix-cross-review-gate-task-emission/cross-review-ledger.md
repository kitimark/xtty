# Cross-review ledger — `fix-cross-review-gate-task-emission`

> **Advisory in its entirety. Gate-inert.** Nothing here is read mechanically by any downstream step,
> and nothing here gates archive. Archive eligibility lives **entirely** in the human-attestation
> `⟶ archive-ritual` step-0 precondition (AGENTS.md), computed from git — never from this file.
> **"Converged" carries no gate force; a dismissal is a *proposal*, not an accepted state; this
> ledger is not a receipt.** Excluded by the digest tool, allowlisted by the scope classifier.

## Header — the transparency contract

| Field | Value |
| --- | --- |
| **Reviewed range** | base `B = 895088430b9b` (parent of `3815113`, the `proposal.md`-introducing commit) .. HEAD `3815113` — **6 files** |
| **Base rule** | positional: parent of the commit that added `proposal.md`. No ownership metadata. |
| **Scope (mechanical)** | **`exit 0` — OUT of scope.** The classifier reports docs/tracker-only, because only the change's own artifacts have landed. **The human launched the review anyway, overriding the classifier.** *This is not a footnote — it is the change's central finding, reproduced on itself (see F1).* |
| **Passes run** | **All three.** None skipped. |
| **Pass A** | Opus — `xtty-openspec-critic`, stamp **`Definition: v4 (2026-07-12)`**; delivery check **served == committed** ⇒ valid, not stale. |
| **Pass B** | **`gpt-5.6-sol`** (GPT family), model pinned at invocation. Effort **`xhigh`**, config-governed and readable (`~/.codex/config.toml`: `model_reasoning_effort = "xhigh"`) — `adversarial-review` exposes no per-call effort flag. Companion `codex/1.0.6`; `codex.available` + `auth.loggedIn` both true. |
| **Pass C** | Opus — inline agent (anti-roster: not a standing agent), effort invocation-controlled. |
| **Cross-family?** | **Yes** — genuinely two-family soundness (B = GPT, C = Opus). Not single-model. |
| **Two-model consensus (B∩C)** | **YES — on the central defect.** Both soundness passes independently landed on the exit-arm model being wrong, and Pass A independently reached it as a **BLOCKER**. A **three-pass** convergence; the highest-confidence finding of the run. |

### Reviewed file list (verbatim, `git diff --name-only B..HEAD`)

```
openspec/changes/fix-cross-review-gate-task-emission/.openspec.yaml
openspec/changes/fix-cross-review-gate-task-emission/design.md
openspec/changes/fix-cross-review-gate-task-emission/proposal.md
openspec/changes/fix-cross-review-gate-task-emission/specs/coherence-review/spec.md
openspec/changes/fix-cross-review-gate-task-emission/specs/cross-model-review/spec.md
openspec/changes/fix-cross-review-gate-task-emission/tasks.md
```

*Honest limitation: work committed **before** `proposal.md` outside the change dir is invisible to
`B..HEAD`. Here the range is clean — 6 own files, 0 foreign — because the change was proposed on a
fresh HEAD. (Contrast `add-git-diff-wrap-toggle`: 33 files, 26 foreign.)*

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
| **G4** | C | medium | **Confinement is load-bearing, and the sequenced check-(4) change could destroy it.** A *sophisticated* bundle — commit task text → compute digest → `git commit --amend` the attestation into that commit — passes checks (1)(2)(3) **and** check (4)'s `adds==1 && dels==0` counter. **Only the confinement clause catches it.** | **FIXED — and it constrains the next change.** D3 now records this, plus an explicit constraint: **any fix to the re-attestation deadlock targets the `adds==1 && dels==0` counter and MUST preserve the *separable* confinement clause.** |
| **G5** | C | medium | **D7's "excluding it strands nothing" is overstated.** The exclusion creates (a) a **standing, unclearable critic BLOCKER** on `add-ci-pipeline` — it is `exit 10` and will permanently lack the task, so every review emits a BLOCKER no D7-permitted action can clear; and (b) archive stays reachable for it **only** because step-0 check (1) greps the attestation **line**, not the gate **task**. | **FIXED.** Both recorded in D7 as **accepted residuals**, not glossed. The standing BLOCKER is accepted deliberately: a loud honest flag beats an unsatisfiable obligation. |
| **G6** | C | low | **The exit-2-committed arm asserted more than the rules deliver.** *Measured:* on a committed malformed range **both** tools refuse, so check (2) cannot be satisfied. **But** no committed rule *requires* step-0 to run on a refusal (its SHALL is conditioned on *"in scope"*; a refusal is neither in nor out). | **FIXED by softening.** The design now states the measurement **and** the honest limit — it no longer claims archive is *mechanically forced* to refuse. Same shape as R5; reduces to the accepted residual. |
| **G7** | **A ∩ C** | low/REVIEW | **D4's heading was stale fail-open vocabulary** — *"Three arms, and only `exit 10` may suppress or block"* over a four-row table, when **no arm suppresses** under the corrected model. | **FIXED** → *"Four arms; only `exit 10` carries blocker force, and no arm suppresses the check."* |
| **G8** | **A ∩ C** | low/REVIEW | **Disk-drift:** the AGENTS.md open-changes row (added in round 1) read `0/18`; disk says `1/20`. Born wrong in the same commit that ticked 3.2. | **FIXED** → `1/20`, computed from disk. |
| **G9** | A | REVIEW | **Pass 4 code-accuracy:** D8 claimed `add-git-diff-wrap-toggle` carries *"all four"* config-backed markers. Disk shows **three** — `⟶ xtty-ci-investigator` is absent, **correctly** (its rule is conditional on a failed-CI task). The argument survives; only the count was wrong. | **FIXED** → *"every applicable marker (three of four)"*, with the reason the fourth is absent. |
| **G10** | A | REVIEW | **HEAD-dependent numbers self-invalidate.** *"315 files"* / *"33 files"* measured **316** / **34** one commit later — which is R4's own point, demonstrated on the design's own prose. | **FIXED** → written as `~N (HEAD-dependent)`. |
| **G11** | **B** | **high ×2** | **Explicit "no-ship":** *"leaves a verified archive bypass and makes an unrecoverable attestation deadlock routine."* Both are R5 and R4 — already documented residuals. Codex demands the dirty-tree scope fix and the re-attestation fix **land first**. | **NOT a new finding — it is the SEQUENCING argument, and it now carries a TWO-MODEL consensus** (C in round 1, B in round 2). **Escalated below.** *Codex's proposed remedy — "append-only, superseding attestation generations" — is **DISMISSED**: it is the **refuted "recoverable attestation epoch"** (G-TARPIT-1/2). Its **sequencing** argument stands; its **remedy** does not.* |

**Pass C's convergence call (G-TARPIT-3):** *"converged modulo bounded edits; no open actionable beyond documented-accepted residuals once they land. NO round 3 is warranted — do not iterate to agreement."* Those edits have landed. **Bound reached; the loop stops here.**

---

## ⚠️ ESCALATED TO THE HUMAN — the sequencing decision (F6 / G11) — **TWO-MODEL CONSENSUS**

**This is the most consequential open question, and the model is not the right party to settle it.**

**Both soundness passes, independently, on different model families, argue this change should land *after* the check-(4) deletion and the range-pollution/dirty-tree fix.** Pass C said so in round 1; Pass B (`gpt-5.6-sol`) returned an explicit **"no-ship"** in round 2. That is the run's **only two-model consensus besides the round-1 BLOCKER**, and it is not a finding I can resolve by editing an artifact.

**The case for landing the other two first:**
- **R5 — a *verified* archive bypass.** With implementation present but **uncommitted**, the classifier reads `exit 0` ⇒ step-0's **entire** precondition is skipped (including the digest's dirty-tree refusal, which lives *inside* it) ⇒ `openspec archive` proceeds. This change makes gate-task enforcement routine **while that bypass is open**.
- **R4 — an *unrecoverable* attestation model.** The digest covers HEAD content of a **~33–316-file, mostly-foreign** range, so **any** commit anywhere restages it; check (4) then forbids re-recording. This change promotes that hazard from *once-per-dogfood* to *once-per-change*.

**The case for landing this one first** (from the explore brief): the deadlock is only *reachable* once a change acquires an attestation, and today **nothing prompts one**.

**A fact that constrains both readings:** the archive gate **already** applies to both open changes (`exit 10`) **with or without this change**. So this change does **not create** the exposure — it makes it **routine**.

**A constraint on whichever check-(4) change lands (G4):** it must target the `adds==1 && dels==0` counter and **preserve the separable confinement clause** — that clause is the only guard against an `--amend`-bundled attestation carrying unreviewed task text.

**Both positions are coherent. The human decides the order — and the model has not decided it.**

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
