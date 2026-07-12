## MODIFIED Requirements

### Requirement: Mechanically-scoped, human-attested, fail-closed archive gate

The cross-model review's **applicability** SHALL be decided by a **mechanical classifier over the change's changed paths**, computed by committed deterministic tooling — **not a model judgment**: a change touching any path **outside a fixed allowlist of documentation and tracker surfaces** SHALL be **in scope**, and an **unrecognized or ambiguous path SHALL default to in scope (fail-closed)**, so an accidental out-of-scope slip is mechanically detectable and no ambiguity judgment remains a scoping surface. A change all of whose changed paths fall inside the allowlist (pure documentation, tracker reconciliation, a rename) SHALL remain eligible for the single-agent coherence review alone. The review runs at **pre-archive** (and MAY run post-propose), not per-edit.

Because the worker carries no authority, archive eligibility SHALL rest entirely on an **explicit human attestation**, never on any artifact a model authored. An in-scope change's task tail SHALL keep the standard single-agent coherence-review delegation marker as its own task, and SHALL additionally carry **exactly one blocking human-attestation cross-review task**, placed after the coherence-review task and before the archive task. That task SHALL be **human-only**: the model SHALL NOT tick it, and SHALL NOT derive, compute, or fill in the attested value; reaching it never auto-fires the paid external reviewer (there is no auto-firing cross-model delegation marker, because the apply loop's point-of-tick grammar can express only delegate-to-subagent or run-inline, and a paid review that must not fire on task-arrival is neither). The human deliberately runs the review, reads the complete ledger, runs the **committed deterministic reviewed-state digest tool** themselves, and ticks the task, **recording the reviewed-state digest on a delimited attestation line** — a stable marker precisely bounding the attested surface within the task file, so that surface is exactly identifiable for exclusion and integrity checks.

Because a rule stated only in the canonical project guide does not reach the task-authoring loop, the obligation to carry that task SHALL additionally be encoded in the **task-authoring configuration** — the surface the propose loop actually reads — instructing the author that a change in scope for cross-model review carries the blocking human-attestation task in its tail with its human-only wording, and **deferring to the guide for the scope boundary** rather than restating it. That configuration rule SHALL be an **authoring instruction, not a delegation marker**: it directs what task is *written*, never causing the paid external review to fire on task arrival. Because the mechanical classifier resolves a change's scope from **committed history**, it **cannot classify a change that is not yet committed**, so the propose-time scope call is necessarily a **semantic** one; that call SHALL therefore be **fail-closed** — when in scope is uncertain, the task is emitted — mirroring the classifier's own ambiguous-is-in-scope rule, so the error direction is a strikeable extra task rather than a silently missing gate. The **coherence-review** capability SHALL enforce the task's presence mechanically at pre-archive, where committed history makes the classifier's verdict available.

The archive step SHALL, for a change the mechanical classifier deems in scope, evaluate a **fail-closed precondition** whose inputs are the human's attestation line, a digest computed by committed deterministic tooling, and git ground truth — and which **reads no model-authored review artifact** (no ledger, verdict, or coverage label). So that a gate-tooling edit does not accidentally validate itself, the archive step SHALL run the digest and scope tooling **as of the reviewed base state** wherever a prior committed version exists — including when the change *modifies* that tooling. **Only where the change itself introduces that tooling does no prior version exist, and the honest trust anchor is human code review of the committed scripts** — an accepted, stated boundary, not mechanically closed. Archive SHALL be refused unless **all** hold: (1) the human attestation **exists and is well-formed**; (2) the reviewed-state digest, **independently recomputed** over the reviewed content excluding only the review's bookkeeping surfaces (the advisory ledger and the delimited attestation surface), **equals** the attested value; (3) the working tree and index are **clean**; and (4) **exempt-by-act** — the delimited attestation line appears **exactly once** and stays **byte-identical from its introducing commit through archive** (any later add/delete/modify of it invalidates the attestation), that commit's task-file change is confined to the **attestation line and checkbox-state ticks**, and every later commit touches only the remaining bookkeeping surfaces, altering **no reviewed artifact and no gate implementation** — so an accidental post-review mutation of a reviewed artifact, the attestation record, or the gate tooling is caught rather than riding the attestation act. A design-time **optional strong form** MAY require the attestation act to be cryptographically signed and verify that signature when present; it SHALL NOT be the default. These mechanical checks are **accident tripwires and human-legibility aids** — they catch accidental post-review drift and surface the reviewed range and attested state for the human to judge — and adversarial resistance rests on the human reading the complete ledger plus the accepted model-only-loop residual, not on any mechanical git-provenance check.

The canonical project guide SHALL document the **worker protocol** (the passes, the advisory union-with-heuristic-consensus ledger and its header contract, the complete-ledger-every-run surfacing rule, bounded rounds, the one-launch-authorizes-the-bounded-run spend rule, the model-family diversity rule, and the detectable non-gating degradation behavior), the **mechanical path-based scope classifier** (the allowlist and the ambiguous-is-in-scope, fail-closed rule), the **task-authoring configuration rule** that emits the gate task at propose time and its fail-closed semantic scope call, and the **human-attestation gate with its fail-closed archive precondition** (the four checks, the reviewed-base tooling rule and its bootstrap boundary, the exempt-by-act rule, and the optional-not-default signing form).

#### Scenario: A behavior-altering change is classified in scope mechanically, never by a semantic call

- **WHEN** the archive step evaluates a change whose changed paths include one outside the documentation/tracker allowlist (product code, a non-doc spec delta, or review/verification/CI tooling), or an unrecognized/ambiguous path
- **THEN** the mechanical classifier deems it in scope — an ambiguous path defaulting to in scope — and the fail-closed human-attestation precondition applies, leaving no semantic scoping judgment by which an in-scope change could accidentally slip past the gate

#### Scenario: A pure-documentation change needs only the single-agent review

- **WHEN** every changed path of a change falls inside the documentation/tracker allowlist (docs, tracker reconciliation, a rename)
- **THEN** the mechanical classifier deems it out of scope for cross-model review and it is eligible for the single-agent coherence review alone

#### Scenario: The gate task is emitted when the change's tasks are authored

- **WHEN** a change in scope for cross-model review has its `tasks.md` authored by the propose loop
- **THEN** the task-authoring configuration the loop reads instructs it to emit the blocking human-attestation cross-review task in the tail with its human-only wording, so the obligation reaches change authoring rather than living only in guide prose — and the rule is an authoring instruction, so emitting the task does not fire the paid external review

#### Scenario: An uncertain propose-time scope call emits the task anyway

- **WHEN** a change's tasks are authored and the mechanical classifier cannot resolve its scope because the change is not yet committed, leaving the propose-time in-scope call semantic and uncertain
- **THEN** the task is emitted (fail-closed), so the error direction is an unnecessary task the human can strike rather than a silently missing gate task

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

#### Scenario: The protocol and gate are documented in the guide

- **WHEN** a contributor or agent reads the canonical project guide
- **THEN** it states the worker protocol (passes, advisory ledger and header contract, complete-ledger-every-run surfacing, bounded rounds, one-launch spend, model-family diversity, detectable non-gating degradation), the mechanical path-based scope classifier (allowlist + ambiguous-is-in-scope), the task-authoring configuration rule that emits the gate task at propose time with its fail-closed semantic scope call, and the human-attestation gate with its fail-closed archive precondition (the four checks, the reviewed-base tooling rule and its bootstrap boundary, exempt-by-act, and the optional-not-default signing form)
