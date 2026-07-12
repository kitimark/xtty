## ADDED Requirements

### Requirement: Soundness passes are briefed

The cross-model review worker SHALL supply each **soundness pass** — the external pass and the inline diversity pass — with a **brief**, so a soundness reviewer receives the reviewer's design context rather than an unexplained diff. The brief SHALL convey the change's **design intent**, the **specific claims or assumptions the soundness pass is to verify**, and a **compact digest of any experiments the worker itself already ran** (so the reviewer reasons from those results rather than re-deriving them). Briefing SHALL **not** alter the **reviewed range** (the deterministic base rule is unchanged — a brief directs attention, it does not scope which diff is reviewed), SHALL **not** change the pass's **structured output schema** (the brief is input, the schema is unchanged), and SHALL **not** change the pass's **sandbox** (the external soundness pass remains read-only).

The brief SHALL be delivered through the reviewer's **focus channel** where the reviewer exposes one. Delivery MAY be **inline** (the default) or, only where an inline brief is not expressible (it must begin with a delimiter the reviewer's argument parser would consume, or exceeds the argument-length limit), through an **in-repo brief file the worker points the reviewer at**. When a brief file is used it SHALL be **gate-inert** — excluded by the reviewed-state digest tool and allowlisted by the scope classifier, exactly as the advisory ledger is — so it never enters the attested reviewed state.

The brief SHALL be **advisory in its entirety**, carrying the same authority as the diff and the ledger: **no** archive-eligibility meaning, and read by **no** downstream mechanical step. Briefing the reviewer SHALL **not** require a write-capable reviewer; the worker SHALL NOT trade the read-only soundness path for a write-capable one merely to brief it.

#### Scenario: The external soundness pass receives a brief

- **WHEN** the worker runs the external soundness pass on an in-scope change
- **THEN** it supplies, through the reviewer's focus channel, a brief conveying the change's design intent, the specific claims to verify, and a digest of any experiments the worker already ran — so the reviewer reasons from context rather than from an unexplained diff

#### Scenario: The brief directs attention without changing the reviewed range or the schema

- **WHEN** a brief is supplied to a soundness pass
- **THEN** the reviewed commit range is unchanged (the brief scopes attention, not the diff), the pass still emits the common structured findings schema, and the external pass remains read-only

#### Scenario: A brief-file fallback stays out of the attested state

- **WHEN** a brief cannot be expressed inline and the worker points the reviewer at an in-repo brief file instead
- **THEN** that file is excluded by the reviewed-state digest tool and allowlisted by the scope classifier, so it never contributes to the attested reviewed state

#### Scenario: The brief carries no gate force

- **WHEN** the archive gate's fail-closed precondition is later evaluated for the change
- **THEN** it reads no brief — the brief is advisory input to the review, never an input to archive eligibility
