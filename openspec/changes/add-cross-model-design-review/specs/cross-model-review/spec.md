## ADDED Requirements

### Requirement: Authority-free cross-model review worker

The repository SHALL provide **version-controlled** tooling that reviews an OpenSpec change **in scope for cross-model review** (see the scope-and-gate requirement) by composing multiple review passes across **two independently-modeled reviewers** and surfacing a single merged result. Because the worker must both invoke a long-running external reviewer and **apply fixes between rounds**, it SHALL run in the **invoking (main) session**, not inside a review subagent — a subagent cannot own a detached background reviewer without stranding it — and the individual review passes remain observe-only. The tooling SHALL include a **thin launcher command** that invokes the protocol rather than restating it.

Given such a change, the worker SHALL run a **conformance** pass (the committed coherence-review agent) and **two soundness** passes carried out on **distinct model families**, and merge their findings into a **single union ledger**, each finding tagged by its source pass, flagging a finding raised by **both soundness passes** as a **heuristic two-model consensus** signal of higher confidence (the same-finding match across differently-modeled reviewers is an irreducibly semantic judgment, not a mechanical join). Both soundness passes SHALL emit findings in a **common structured schema** so their outputs are comparable, and the soundness pass sharing the conformance agent's model family SHALL run **inline** within the worker rather than as a new standing committed agent, unless recurring friction later justifies promoting it.

The worker SHALL locate the external soundness reviewer by a **version-independent, version-ordered** resolution (comparing versions numerically, not lexically). Because a focus hint does **not** restrict what the external reviewer reviews, the worker SHALL scope the review by a **deterministic best-effort commit range**: the review base SHALL be the **parent of the commit that introduced the change** (a purely positional git rule requiring no ownership metadata), the range SHALL run to HEAD, and the worker SHALL **name that range in the ledger header** — the base, the HEAD, and the reviewed file list — so the reviewed scope is transparent to the human reader rather than asserted by a trusted metadata chain. The worker MAY iterate a **bounded** number of rounds (a single human launch authorizing the whole bounded run), adjudicating and applying fixes between rounds; bounded iteration is **worker behavior only** and carries no archive-eligibility meaning.

The two soundness passes SHALL run on **distinct model families**, at an effort suitable to deep adversarial design review; the concrete model pin SHALL live in the design document (not this requirement) so the family-diversity invariant and effort floor survive model-version drift. The worker SHALL pin the external pass's model **explicitly at invocation** (not inherit it silently from a contributor's configuration) and SHALL **record the effective model and effort of each soundness pass in the ledger header**, so a human reader can see whether the run was genuinely cross-family.

When the external soundness reviewer is unavailable — no companion resolvable by the version-ordered resolution, the reviewer binary absent from PATH, or a genuinely logged-out workstation — the worker SHALL **skip that pass, complete on the remaining passes, and state plainly in the ledger header which passes ran, which did not, and why**. Degradation SHALL be **reported, never gating**: no availability state, coverage label, verdict, consensus flag, or ledger the worker produces SHALL auto-satisfy or auto-block archive, and none SHALL be read mechanically by any downstream step. The worker's output is **advisory in its entirety** — a human reads it; a dismissal recorded by the worker is a *proposal*, not an accepted state.

#### Scenario: The worker tooling is version-controlled

- **WHEN** the repository is cloned and the committed tooling files are inspected
- **THEN** the cross-model review launcher command and the reviewed-state digest tool are present and tracked by git (not gitignored), while machine-local and tool-generated `.claude` files remain ignored

#### Scenario: The worker runs in the main session, not a review subagent

- **WHEN** a cross-model review is run for a change
- **THEN** the parallel review passes and the between-round fixes are driven from the invoking session, and no review subagent owns the detached external reviewer (which would strand it)

#### Scenario: A change in scope is reviewed by conformance plus two-family soundness over a named range

- **WHEN** the worker reviews a change in scope for cross-model review
- **THEN** it runs a conformance pass and two soundness passes on distinct model families, reviews the commit range from the parent of the change-introducing commit to HEAD, and names that range — base, HEAD, and the reviewed file list — together with the effective model and effort of each soundness pass in the ledger header

#### Scenario: Findings merge into a union ledger with a heuristic consensus flag

- **WHEN** the passes complete
- **THEN** the worker merges their findings into one source-tagged union ledger and flags a finding raised by both soundness passes as a heuristic two-model consensus signal of higher confidence, without asserting a mechanical join

#### Scenario: The diversity pass runs inline, not as a new standing agent

- **WHEN** the worker runs the soundness pass that shares the conformance agent's model family
- **THEN** it is executed inline within the worker rather than by introducing a new committed standing agent, consistent with the guide's rule against a speculative agent roster

#### Scenario: An unavailable external reviewer degrades detectably, never as a gate

- **WHEN** no external reviewer is resolvable, the reviewer binary is absent from PATH, or the workstation is logged out
- **THEN** the worker skips the external soundness pass, completes on the remaining passes, and states in the ledger header which passes ran, which did not, and why — and nothing about the skip blocks or satisfies any archive gate

#### Scenario: The worker's output carries no gate semantics

- **WHEN** the worker produces its ledger, consensus flags, coverage description, and any recorded dismissals
- **THEN** every one of these is advisory information a human reads, and no downstream step (in particular the archive gate) reads any of them mechanically or treats any of them as authority to archive

### Requirement: Scope, human-attested gate, and fail-closed archive

The cross-model review SHALL be scoped by a **mechanical criterion** to changes that **alter product behavior or the project's own review/verification tooling** — those touching product code, a spec delta beyond docs/tooling, or the review/verification/CI tooling itself — and run at **pre-archive** (and MAY run post-propose), not per-edit. A **purely mechanical** change (documentation, tracker reconciliation, a rename) SHALL remain eligible for the single-agent coherence review alone. The criterion SHALL NOT be "the change has a design document" (nearly every change has one).

Because the worker carries no authority, archive eligibility SHALL rest entirely on an **explicit human attestation**, not on any artifact a model authored. An in-scope change's task tail SHALL **keep** the standard single-agent coherence-review delegation marker as its own task, and SHALL additionally carry **exactly one blocking human-attestation cross-review task** — placed after the coherence-review task and before the archive task. That task SHALL be **human-only**: the model SHALL NOT tick it, and SHALL NOT derive, compute, or fill in the attested value; reaching the task never auto-fires the paid external reviewer (there is no auto-firing cross-model delegation marker, because the apply loop's point-of-tick grammar can express only delegate-to-subagent or run-inline, and a paid review that must not fire on task-arrival is neither). The human deliberately runs the review, reads the full ledger, runs the **committed deterministic reviewed-state digest tool** themselves, and only then ticks the task, **recording the reviewed-state digest on the tick line** as the attested value.

The archive step SHALL, for an in-scope change, evaluate a **fail-closed precondition** whose inputs are the human's attestation line, a digest computed by committed deterministic tooling, and git ground truth — and which **reads no model-authored review artifact** (not a ledger, not a verdict, not a coverage label). Archive SHALL be refused unless **all** hold: (1) the human attestation **exists and is well-formed**; (2) the reviewed-state digest, **independently recomputed** at archive over the reviewed content excluding only the review's own bookkeeping surfaces (the advisory ledger and the attestation/tick surface), **equals** the attested value; (3) the working tree and index are **clean**; and (4) the **only change since the reviewed state is the single human attestation act itself** — no later commit altered a reviewed artifact, and no later commit rewrote the attestation record (so a by-path exclusion of the attestation surface cannot be abused to tamper with the record after the fact). A design-time **optional strong form** MAY additionally require the attestation act to be cryptographically signed and verify that signature when present; it SHALL NOT be the default.

The canonical project guide SHALL document the **worker protocol** (the passes, the advisory union-with-heuristic-consensus ledger and its header contract, bounded rounds, the one-launch-authorizes-the-bounded-run spend rule, the model-family diversity rule, and the detectable non-gating degradation behavior), the **mechanical scope criterion**, and the **human-attestation gate with its fail-closed archive precondition** (the four checks, including the exempt-by-act staleness rule and the optional-not-default signing form).

#### Scenario: A change in scope keeps the standard tail and gains one blocking human-attestation task

- **WHEN** a change that alters product behavior or the review/verification tooling has its pre-archive tasks authored
- **THEN** the tail carries the standard single-agent coherence-review delegation marker as its own task plus exactly one blocking human-attestation cross-review task (no auto-firing cross-model marker exists), while a purely mechanical change (docs/tracker/rename) needs only the single-agent review

#### Scenario: The human-attestation task is human-only

- **WHEN** the apply loop reaches the blocking human-attestation cross-review task
- **THEN** the model stops at the task — it neither ticks it nor derives, computes, or fills in the attested value — and the task is satisfied only by a direct human act that records the reviewed-state digest on the tick line after the human has run the review and the digest tool

#### Scenario: Archive fails closed without a human attestation

- **WHEN** the archive step runs for an in-scope change whose task tail carries no ticked human-attestation task recording a reviewed-state digest
- **THEN** it fails closed — refusing to archive and surfacing the missing attestation as an unmet precondition — rather than archiving a change whose cross-model review was never human-attested

#### Scenario: Archive fails closed on a mismatched digest, a dirty tree, or a post-review alteration

- **WHEN** the archive step evaluates an in-scope change and either the recomputed reviewed-state digest does not equal the attested value, or the working tree/index is dirty, or a commit landing after the reviewed state altered a reviewed artifact or rewrote the attestation record
- **THEN** it fails closed — surfacing the stale or unreviewed state as an unmet precondition requiring a fresh review and attestation — while the human attestation act itself, being the sole permitted post-review change, does not trip the check

#### Scenario: The archive gate reads no model-authored artifact

- **WHEN** the archive precondition is evaluated
- **THEN** its only inputs are the human's attestation line, the digest recomputed by committed deterministic tooling, and git ground truth — never a ledger, verdict, coverage label, or any other artifact a model authored

#### Scenario: The protocol and gate are documented in the guide

- **WHEN** a contributor or agent reads the canonical project guide
- **THEN** it states the worker protocol (passes, advisory ledger and header contract, bounded rounds, one-launch spend, model-family diversity, detectable non-gating degradation), the mechanical scope criterion and pre-archive timing, and the human-attestation gate with its fail-closed archive precondition (the four checks including exempt-by-act staleness and the optional-not-default signing form)
