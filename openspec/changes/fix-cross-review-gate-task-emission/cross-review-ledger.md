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
| **F9** | C | low | **A mechanical argument the design MISSED that *strengthens* it.** Check (4) confines the attestation-introducing commit's `tasks.md` hunk to *attestation line + ticks*. So if a human — prompted only by a pre-archive BLOCKER — adds the gate-task **text** and attests in the same commit, that hunk contains new task text ⇒ **check (4) fails ⇒ archive refused.** The gate task's text **must already be committed before attestation**. | **FIXED — and promoted to a Decision (D3).** This independently **rebuts the one-layer alternative** ("skip the config rule, just make the critic block at pre-archive"), which would force the human into a check-(4)-violating commit. The two-layer split is therefore **required by the gate's own checks**, not a judgment call. Corollary added: the migration commit must be separate from any attestation. |
| **F10** | C | low | **The v5 critic is verified partly by itself, and a 6.1 run at `exit 0` would exercise the broken arm and report nothing.** | **FIXED.** Task 6.1 gains an explicit **validity precondition**: valid only after 2.3–2.5 pass **and** the implementation commits land (classifier ⇒ `exit 10`). A 6.1 run against an `exit 0` state **is not a pass** — the same posture as the existing v4-stamp rule. |
| **F11** | A | REVIEW | **Disk-drift: the change is missing its row** in AGENTS.md's *Open changes* table, which states it *"must match `openspec list`"*. | **FIXED immediately** (live drift, not deferrable work) — row added; task 3.2 ticked with a note. |

### Confirmed-clean by Pass A (fact-checked, no finding)

`openspec/config.yaml` has exactly **4** `rules.tasks` entries and **0** cross-review hits · critic **L42/L80** are as claimed · classifier ⇒ **exit 10** on both open changes · both carry **zero** attestation tasks · `cross-review-digest.sh` **does** normalize ticks + exclude the attestation line · AGENTS.md **does** refute an auto-firing marker · **both MODIFIED blocks paste the ENTIRE established requirement — nothing truncated** (diffed line-by-line) · proposal↔specs contract holds both ways · the change tail is well-formed · no `verification-harness` delta correctly justified · the `25 of 52` prose count re-derives exactly.

---

## ⚠️ ESCALATED TO THE HUMAN — the sequencing decision (F6)

**This is the most consequential open question, and the model is not the right party to settle it.**

- **Pass C argues this change should land *after* the check-(4) deletion and the range-pollution fix.** It makes the gate fire *reliably* into an attestation model with an **unrecoverable** failure mode: a 33–315-file, mostly-foreign, HEAD-dependent digest range, where any commit anywhere restages the digest and check (4) then forbids re-recording.
- **The counter-argument for landing it first** (from the explore brief): the deadlock is only *reachable* once a change acquires an attestation, and today nothing prompts one.
- **A fact that constrains both:** the archive gate **already** applies to both open changes (`exit 10`) **with or without this change**. So this change does **not create** the exposure — it makes it **routine**.

**Both positions are coherent. The human decides the order.**

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
