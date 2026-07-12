## ADDED Requirements

### Requirement: Soundness passes are briefed

The cross-model review worker SHALL supply each **soundness pass** — the external pass and the inline diversity pass — with a **brief**, so a soundness reviewer receives the reviewer's design context rather than an unexplained diff. The brief SHALL convey the change's **design intent**, the **specific claims or assumptions the soundness pass is to verify**, and a **compact digest of any experiments the worker itself already ran** (so the reviewer reasons from those results rather than re-deriving them). Briefing SHALL **not** alter the **reviewed range** (the deterministic base rule is unchanged — a brief directs attention, it does not scope which diff is reviewed), SHALL **not** change the pass's **structured output schema** (the brief is input, the schema is unchanged), and SHALL **not** change the pass's **sandbox** (the external soundness pass remains read-only).

The brief SHALL be **additive, never a substitute for open-ended review**: each soundness pass SHALL be instructed to soundness-check the briefed claims **and** to report any material finding **outside** the brief, so a brief that omits a risk does not blind the reviewer to it. Because both soundness passes may share the same brief (and the same worker-run drill digest within it), a finding SHALL NOT be elevated to **two-model consensus** when both passes' findings rest **only** on the same briefed assertion — shared framing is not independent corroboration. To keep the shared framing auditable, the worker SHALL **record the brief** (or a faithful reference to it) in the **advisory ledger**, and SHALL present any worker-supplied drill digest as **claims to challenge**, not established fact.

The brief SHALL be delivered through the reviewer's **focus channel** as a **single inline input**, reaching the reviewer with its **semantic content and internal newlines intact** (delivery is semantic, not byte-identical). A brief SHALL fit the inline budget: if a brief would exceed it, the worker SHALL **compact it and note the compaction** — it SHALL NOT silently under-brief. The worker SHALL NOT introduce any brief-carrying file **that would enter the attested reviewed state**: no new file inside the repository worktree (the gate tooling excludes only the advisory ledger, so any other worktree file would enter the reviewed-state digest or trip the dirty-tree refusal). Staging the brief **outside the repository** and delivering it as a single focus-channel input is permitted, and is the appropriate channel when a brief carries newlines or shell metacharacters that an inline literal would mangle.

The brief SHALL be **advisory in its entirety**, carrying the same authority as the diff and the ledger: **no** archive-eligibility meaning, and read by **no** downstream mechanical step. Briefing the reviewer SHALL **not** require a write-capable reviewer; the worker SHALL NOT trade the read-only soundness path for a write-capable one merely to brief it.

#### Scenario: The external soundness pass receives a brief

- **WHEN** the worker runs the external soundness pass on an in-scope change
- **THEN** it supplies, through the reviewer's focus channel, a brief conveying the change's design intent, the specific claims to verify, and a digest of any experiments the worker already ran — so the reviewer reasons from context rather than from an unexplained diff

#### Scenario: The brief directs attention without changing the reviewed range or the schema

- **WHEN** a brief is supplied to a soundness pass
- **THEN** the reviewed commit range is unchanged (the brief scopes attention, not the diff), the pass still emits the common structured findings schema, and the external pass remains read-only

#### Scenario: The brief is additive, not a substitute for open-ended review

- **WHEN** a soundness pass is briefed and finds a material risk the brief did not mention
- **THEN** it reports that finding as well — the pass is instructed to check the briefed claims **and** to surface anything outside them, so a brief that omits a risk does not blind the reviewer to it

#### Scenario: Shared framing is not independent consensus

- **WHEN** both soundness passes receive the same brief and each raises a finding that rests **only** on the same briefed assertion
- **THEN** the worker does **not** flag that as a two-model consensus signal, and the brief is recorded in the advisory ledger so the human can audit the shared framing behind any consensus flag

#### Scenario: The brief carries no gate force

- **WHEN** the archive gate's fail-closed precondition is later evaluated for the change
- **THEN** it reads no brief — the brief is advisory input to the review, never an input to archive eligibility, and no brief-carrying file enters the reviewed-state digest
