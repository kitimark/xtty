## ADDED Requirements

### Requirement: Authority-free cross-model review worker

The repository SHALL provide **version-controlled** tooling that reviews an OpenSpec change **in scope for cross-model review** (see the archive-gate requirement) by composing multiple review passes across **two independently-modeled reviewers** and surfacing a single merged result. Because the worker must both invoke a long-running external reviewer and **apply fixes between rounds**, it SHALL run in the **invoking (main) session**, not inside a review subagent — a subagent cannot own a detached background reviewer without stranding it — and the individual review passes remain observe-only. The tooling SHALL include a **thin launcher command** that invokes the protocol rather than restating it.

Given such a change, the worker SHALL run a **conformance** pass (the committed coherence-review agent) and **two soundness** passes carried out on **distinct model families**, and merge their findings into a **single union ledger**, each finding tagged by its source pass, flagging a finding raised by **both soundness passes** as a **heuristic two-model consensus** signal of higher confidence (the same-finding match across differently-modeled reviewers is an irreducibly semantic judgment, not a mechanical join). Both soundness passes SHALL emit findings in a **common structured schema** so their outputs are comparable, and the soundness pass sharing the conformance agent's model family SHALL run **inline** within the worker rather than as a new standing committed agent, unless recurring friction later justifies promoting it.

The worker SHALL locate the external soundness reviewer by a **version-independent, version-ordered** resolution (comparing versions numerically, not lexically). Because a focus hint does **not** restrict what the external reviewer reviews, the worker SHALL scope the review by a **deterministic commit range anchored at an immutable recorded base**: the change SHALL record, **at its creation and before implementation work begins**, the identity of the commit that is its review base — a **single recorded base commit**, requiring no per-commit ownership metadata — and the range SHALL run from that recorded base to HEAD. The review, the reviewed-state digest, and the archive gate's scope classification SHALL all resolve the range from that **same recorded base**; any tooling consuming the base SHALL **fail closed** — refusing with a named error rather than proceeding on a guessed or narrower range — when the recorded base is **absent, unresolvable, or not an ancestor of HEAD**. The worker SHALL **name that range in the ledger header** — the base, the HEAD, and the reviewed file list — so the reviewed scope is transparent to the human reader rather than asserted by a trusted metadata chain. The worker MAY iterate a **bounded** number of rounds (a single human launch authorizing the whole bounded run), adjudicating and applying fixes between rounds; bounded iteration is **worker behavior only** and carries no archive-eligibility meaning.

The two soundness passes SHALL run on **distinct model families**, at an effort suitable to deep adversarial design review; the concrete model pin SHALL live in the design document (not this requirement) so the family-diversity invariant and effort floor survive model-version drift. The worker SHALL pin the external pass's model **explicitly at invocation** (not inherit it silently from a contributor's configuration) and SHALL **record the effective model of each soundness pass — and its effort where the reviewer's interface exposes it (the external adversarial reviewer may expose no per-call effort control, in which case its effort is governed by the reviewer's own configuration and reported as such) — in the ledger header**, so a human reader can see whether the run was genuinely cross-family.

When the external soundness reviewer is unavailable — no companion resolvable by the version-ordered resolution, the reviewer binary absent from PATH, or a genuinely logged-out workstation — the worker SHALL **skip that pass, complete on the remaining passes, and state plainly in the ledger header which passes ran, which did not, and why**. Degradation SHALL be **reported, never gating**: no availability state, coverage label, verdict, consensus flag, or ledger the worker produces SHALL auto-satisfy or auto-block archive, and none SHALL be read mechanically by any downstream step. The worker's output is **advisory in its entirety** — a human reads it; a dismissal recorded by the worker is a *proposal*, not an accepted state.

Because the human attestation (see the archive-gate requirement) is the **sole acceptance authority** and rests entirely on the human reading the ledger, the worker SHALL surface the **complete** union ledger — every finding with its resolution, **every dismissal with its recorded rationale**, and any residual escalated at the round bound — to the human on **every** run, never a filtered subset.

#### Scenario: The worker tooling is version-controlled

- **WHEN** the repository is cloned and the committed tooling files are inspected
- **THEN** the cross-model review launcher command, the reviewed-state digest tool, and the scope classifier are present and tracked by git (not gitignored), while machine-local and tool-generated `.claude` files remain ignored

#### Scenario: The worker runs in the main session, not a review subagent

- **WHEN** a cross-model review is run for a change
- **THEN** the parallel review passes and the between-round fixes are driven from the invoking session, and no review subagent owns the detached external reviewer (which would strand it)

#### Scenario: A change in scope is reviewed by conformance plus two-family soundness over a named range

- **WHEN** the worker reviews a change in scope for cross-model review
- **THEN** it runs a conformance pass and two soundness passes on distinct model families, reviews the commit range from the change's recorded review base to HEAD, and names that range — base, HEAD, and the reviewed file list — together with the effective model of each soundness pass (and its effort where the reviewer exposes it) in the ledger header

#### Scenario: The range tooling fails closed on an absent or non-ancestor recorded base

- **WHEN** a change's recorded review base is absent, unresolvable, or not an ancestor of HEAD
- **THEN** the range tooling refuses with a named error rather than proceeding on a guessed or narrower range

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

#### Scenario: The complete ledger is surfaced on every run

- **WHEN** a review run completes — including a run in which findings were resolved by dismissal-with-rationale, or a residual was escalated at the round bound
- **THEN** the worker surfaces the complete union ledger — every finding with its resolution, every dismissal rationale, and any escalated residual — to the human, never a filtered subset, since the human attestation that gates archive rests entirely on reading it

### Requirement: Mechanically-scoped, human-attested, fail-closed archive gate

The cross-model review's **applicability** SHALL be decided by a **mechanical classifier over the change's changed paths**, computed by committed deterministic tooling — **not a model judgment** — with the changed paths computed over the **same recorded-base range** the review and the digest resolve (see the worker requirement), never a narrower or independently-computed range: a change touching any path **outside a fixed allowlist of documentation and tracker surfaces** SHALL be **in scope**, and an **unrecognized or ambiguous path SHALL default to in scope (fail-closed)**, so a session cannot exempt a substantive change by a semantic call. A change whose recorded base is **absent, unresolvable, or not an ancestor of HEAD** SHALL classify **in scope (fail-closed)** — and, its reviewed-state digest being uncomputable without the base, its archive precondition cannot pass until a base is recorded, reviewed, and attested. A change all of whose changed paths fall inside the allowlist (pure documentation, tracker reconciliation, a rename) SHALL remain eligible for the single-agent coherence review alone. The review runs at **pre-archive** (and MAY run post-propose), not per-edit.

Because the worker carries no authority, archive eligibility SHALL rest entirely on an **explicit human attestation**, never on any artifact a model authored. An in-scope change's task tail SHALL keep the standard single-agent coherence-review delegation marker as its own task, and SHALL additionally carry **exactly one blocking human-attestation cross-review task**, placed after the coherence-review task and before the archive task. That task SHALL be **human-only**: the model SHALL NOT tick it, and SHALL NOT derive, compute, or fill in the attested value; reaching it never auto-fires the paid external reviewer (there is no auto-firing cross-model delegation marker, because the apply loop's point-of-tick grammar can express only delegate-to-subagent or run-inline, and a paid review that must not fire on task-arrival is neither). The human deliberately runs the review, reads the complete ledger, runs the **committed deterministic reviewed-state digest tool** themselves, and ticks the task, **recording the reviewed-state digest on a delimited attestation line** — a stable marker precisely bounding the attested surface within the task file, so that surface is exactly identifiable for exclusion and integrity checks.

The archive step SHALL, for a change the mechanical classifier deems in scope, evaluate a **fail-closed precondition** whose inputs are the human's attestation line, a digest computed by committed deterministic tooling, and git ground truth — and which **reads no model-authored review artifact** (not a ledger, not a verdict, not a coverage label). To prevent a change from weakening its own gate, the archive step SHALL run the digest and scope tooling **as of the reviewed base state** rather than the working-tree version wherever a prior committed version exists — including when the change *modifies* that tooling, since a modification still has a prior committed version to run from. **Only for a change that itself introduces that tooling does no prior version exist to run from, and the honest trust anchor there is human code review of the committed scripts** — an accepted, stated boundary, not a mechanically-closed one. Archive SHALL be refused unless **all** hold: (1) the human attestation **exists and is well-formed**; (2) the reviewed-state digest, **independently recomputed** over the reviewed content excluding only the review's bookkeeping surfaces (the advisory ledger and the delimited attestation surface), **equals** the attested value; (3) the working tree and index are **clean**; and (4) **every commit after the reviewed state touches only bookkeeping surfaces** — in particular the attestation-introducing commit's change to the task file SHALL be confined to the **delimited attestation line and checkbox-state ticks**, altering **no reviewed artifact and no gate implementation** — so neither a reviewed artifact, nor the attestation record, nor the gate tooling can be mutated after review under cover of the attestation act. The precondition SHALL be evaluated **immediately before** the archive merge; the mechanical spec-delta merge and tracker reconciliation that follow a passed precondition are the committed archive procedure's **own bookkeeping** — the same committed-procedure trust class as the gate tooling itself, an accepted and stated boundary rather than a re-gated surface — and re-verifying (re-digesting) the final merged candidate before the archive commit is finalized MAY be applied as a hardening option. A design-time **optional strong form** MAY additionally require the attestation act to be cryptographically signed and verify that signature when present; it SHALL NOT be the default.

The canonical project guide SHALL document the **worker protocol** (the passes, the advisory union-with-heuristic-consensus ledger and its header contract, the complete-ledger-every-run surfacing rule, bounded rounds, the one-launch-authorizes-the-bounded-run spend rule, the model-family diversity rule, and the detectable non-gating degradation behavior), the **recorded review-base rule** (recorded at change creation before implementation; resolved identically by review, digest, and scope classification; fail-closed when absent, unresolvable, or not an ancestor of HEAD), the **mechanical path-based scope classifier** (the allowlist and the ambiguous-is-in-scope, fail-closed rule), and the **human-attestation gate with its fail-closed archive precondition** (the four checks, the reviewed-base tooling rule and its bootstrap boundary, the exempt-by-act rule, and the optional-not-default signing form).

#### Scenario: A behavior-altering change cannot be exempted by a semantic call

- **WHEN** the archive step evaluates a change whose changed paths include one outside the documentation/tracker allowlist (product code, a non-doc spec delta, or review/verification/CI tooling), or an unrecognized/ambiguous path
- **THEN** the mechanical classifier deems it in scope — an ambiguous path defaulting to in scope — and the fail-closed human-attestation precondition applies, so no session can skip the gate by judging the change out of scope

#### Scenario: A pre-proposal implementation commit cannot silently escape the gate

- **WHEN** implementation work lands in a commit after the recorded review base but before the change's proposal artifact is committed, touching no change-directory path
- **THEN** that commit lies inside the recorded-base range resolved identically by the review, the digest, and the scope classifier — so it is reviewed, digested, and drives the classification in scope, and the change cannot be declared out of scope by a range that silently excluded it

#### Scenario: An absent recorded base cannot classify a change out of scope

- **WHEN** the scope classifier evaluates a change whose recorded review base is absent, unresolvable, or not an ancestor of HEAD
- **THEN** it classifies the change in scope (fail-closed), and — the reviewed-state digest being uncomputable without the base — the archive precondition cannot pass until a base is recorded, reviewed, and attested

#### Scenario: A pure-documentation change needs only the single-agent review

- **WHEN** every changed path of a change falls inside the documentation/tracker allowlist (docs, tracker reconciliation, a rename)
- **THEN** the mechanical classifier deems it out of scope for cross-model review and it is eligible for the single-agent coherence review alone

#### Scenario: The human-attestation task is human-only

- **WHEN** the apply loop reaches the blocking human-attestation cross-review task
- **THEN** the model stops at the task — it neither ticks it nor derives, computes, or fills in the attested value — and the task is satisfied only by a direct human act that records the reviewed-state digest on the delimited attestation line after the human has run the review and the digest tool

#### Scenario: Archive fails closed without a human attestation

- **WHEN** the archive step runs for an in-scope change whose task tail carries no ticked human-attestation task recording a reviewed-state digest
- **THEN** it fails closed — refusing to archive and surfacing the missing attestation as an unmet precondition — rather than archiving a change whose cross-model review was never human-attested

#### Scenario: Archive fails closed on a mismatched digest, a dirty tree, or a post-review alteration

- **WHEN** the archive step evaluates an in-scope change and either the recomputed reviewed-state digest does not equal the attested value, or the working tree/index is dirty, or a commit landing after the reviewed state touched a reviewed artifact, rewrote the attestation record, or modified the gate tooling
- **THEN** it fails closed — surfacing the stale or unreviewed state as an unmet precondition requiring a fresh review and attestation — while the attestation-introducing commit, confined to the delimited attestation line and checkbox ticks, does not trip the check

#### Scenario: The archive gate reads no model-authored artifact

- **WHEN** the archive precondition is evaluated
- **THEN** its only inputs are the human's attestation line, the digest recomputed by committed deterministic tooling (run from the reviewed-base version where one exists), and git ground truth — never a ledger, verdict, coverage label, or any other artifact a model authored

#### Scenario: Post-precondition archive work is confined to the committed ritual's own bookkeeping

- **WHEN** the fail-closed precondition has passed and the archive step performs the committed ritual's mechanical spec-delta merge, purpose fill, and tracker reconciliation
- **THEN** those post-gate edits are confined to the committed procedure's own archive surfaces (the spec merge, the new-spec purpose fill, the tracker documents) — altering no reviewed artifact and no gate implementation under cover of the archive act — with re-digesting the final merged candidate available as an optional hardening before the archive commit is finalized

#### Scenario: The protocol and gate are documented in the guide

- **WHEN** a contributor or agent reads the canonical project guide
- **THEN** it states the worker protocol (passes, advisory ledger and header contract, complete-ledger-every-run surfacing, bounded rounds, one-launch spend, model-family diversity, detectable non-gating degradation), the recorded review-base rule (recorded at change creation; resolved identically by review, digest, and scope; fail-closed when absent or not an ancestor), the mechanical path-based scope classifier (allowlist + ambiguous-is-in-scope), and the human-attestation gate with its fail-closed archive precondition (the four checks, the reviewed-base tooling rule and its bootstrap boundary, exempt-by-act, and the optional-not-default signing form)
