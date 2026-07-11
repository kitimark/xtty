## ADDED Requirements

### Requirement: Committed cross-model review orchestrator tooling

The repository SHALL provide **version-controlled** tooling that reviews an OpenSpec change **in scope for cross-model review** (see the scope requirement) by composing multiple review passes across **two independently-modeled reviewers** and driving the change toward a converged state. Because the orchestration must both invoke a long-running external reviewer and **apply fixes between rounds**, it SHALL run in the **invoking (main) session**, not inside a review subagent — a subagent cannot own a detached background reviewer without stranding it, and the individual review passes remain observe-only. The tooling SHALL include a **thin launcher command** that invokes the protocol rather than restating it. Given such a change, the orchestrator SHALL run a **conformance** pass (the committed coherence-review agent) and **two soundness** passes carried out on **different models**, and produce a single merged result. The orchestrator SHALL locate the external soundness reviewer by a **version-independent, version-ordered** resolution (comparing versions numerically, not lexically) rather than a version-pinned path. Because the external reviewer reviews the whole diff of its git target and a focus hint does **not** restrict what it reviews, the orchestrator SHALL enforce isolation by a **contiguous commit-range substrate**: the review base SHALL be the **parent of the change's first commit**, the working tree SHALL be **clean** at launch, each round's accepted fixes SHALL be **checkpoint-committed** onto the range, and every round's soundness review SHALL run against that same fixed base — so the reviewed diff is always the **whole change and nothing else**, across commits and rounds. Before launching the soundness reviewer the orchestrator SHALL **assert**: the base is an ancestor of HEAD (their merge-base equals the base); the tree is clean; the base-to-HEAD range contains **no merge commits**; the **first** commit in the range is the change-introduction commit; and **every commit in the range carries verifiable per-commit ownership for the named change** — a **validated per-commit change trailer** (`OpenSpec-Change: <name>`, a **new convention this change introduces**) on each range commit, or an entry in an **explicit immutable commit-hash manifest** — **regardless of branch location**, because path-based inference fails once implementation edits product files and a branch does not establish ownership (a branch can hold interleaved or arbitrary commits): a per-change branch or worktree MAY be used for *isolation* but SHALL NOT be accepted as ownership *proof*. When any range commit lacks matching ownership metadata, or an unrelated commit is interleaved into the range, the orchestrator SHALL **fail closed** — declining to review that range and using an **isolated review branch containing only the change's commits** instead, rather than reviewing a *different* change's work in the named change's place.

#### Scenario: The orchestrator tooling is version-controlled

- **WHEN** the repository is cloned and the committed tooling files are inspected
- **THEN** the cross-model review launcher command is present and tracked by git (not gitignored), while machine-local and tool-generated `.claude` files remain ignored

#### Scenario: Orchestration runs in the main session, not a review subagent

- **WHEN** a cross-model review is run for a change
- **THEN** the parallel review passes and the between-round fixes are driven from the invoking session, and no review subagent owns the detached external reviewer (which would strand it)

#### Scenario: A change in scope is reviewed by conformance plus two-model soundness

- **WHEN** the orchestrator reviews a change in scope for cross-model review
- **THEN** it runs a conformance pass and two soundness passes on different models, and merges their outputs into one result

#### Scenario: A soundness review is scoped to the change's commit range, not the repository

- **WHEN** more than one change is open (some committed) and the orchestrator is asked to run a soundness pass for a named change
- **THEN** the orchestrator reviews the contiguous commit range from the parent of the change's first commit to HEAD, asserting before launch that the tree is clean, the range contains no merge commits, and every range commit carries verifiable ownership metadata for the named change (a validated per-commit change trailer or an entry in an explicit immutable commit-hash manifest — branch location is not accepted as ownership proof); if any range commit lacks matching ownership metadata or an unrelated commit is interleaved it fails closed — declining that range and reviewing an isolated branch of only the change's commits (rather than reviewing another change in its place) — and it locates the reviewer by a version-ordered, version-independent resolution

#### Scenario: Each round re-reviews the whole change against the same base

- **WHEN** a convergence round applies accepted fixes to the change artifacts
- **THEN** those fixes are checkpoint-committed onto the change's commit range and the next round's soundness review runs against the same fixed base, so the reviewed diff remains the whole change and nothing else

### Requirement: Union-with-consensus finding ledger and inline diversity pass

The orchestrator SHALL merge the passes' findings into a single **union ledger**, each finding tagged by its **source pass**, and SHALL flag a finding raised by **both soundness passes** as a **two-model consensus** finding carrying higher confidence. **Both soundness passes SHALL emit findings in a common structured schema** (at least a severity, a title, the implicated file, a location, and a confidence) so their outputs are **comparable**; but because two differently-modeled reviewers diverge on wording, on which file a shared flaw is attributed to, and on line ranges, the "same finding" match is an **irreducibly semantic judgment** — the consensus flag SHALL therefore be treated as a **heuristic confidence signal**, not a mechanical guarantee. The passes SHALL be **complementary** — the conformance pass need not duplicate the soundness passes — so the ledger's value is **coverage** (conformance ∪ soundness) *plus* **consensus** (soundness ∩ soundness). The soundness pass that shares the conformance agent's model family SHALL run **inline** within the orchestration (emitting the common schema) rather than as a new standing committed agent, unless and until recurring friction justifies promoting it to committed tooling.

#### Scenario: A finding raised by both soundness passes is marked consensus

- **WHEN** both soundness passes independently raise the same design finding
- **THEN** the ledger flags that finding as a two-model consensus finding of higher confidence than a finding raised by only one pass

#### Scenario: The diversity pass runs inline, not as a new standing agent

- **WHEN** the orchestrator runs the same-model-family soundness pass
- **THEN** it is executed inline within the orchestration rather than by introducing a new committed standing agent, consistent with the guide's rule against a speculative agent roster

#### Scenario: Both soundness passes emit a common schema for consensus matching

- **WHEN** the two soundness passes run
- **THEN** each emits its findings in the common structured schema so the outputs are comparable, and the consensus flag is applied as a heuristic confidence signal (a semantic same-finding judgment), not asserted as a mechanical join

### Requirement: Terminating convergence loop

The orchestrator SHALL drive a **terminating convergence loop**: each round runs the passes, the caller **adjudicates every finding** as either **fix** or **dismiss with a recorded rationale**, applies the fixes to the change artifacts (checkpoint-committing them onto the change's commit range, keeping the tree clean for the next round's review), and re-runs the passes. Convergence SHALL be defined as a round in which **no unresolved actionable finding remains from any pass** — explicitly **not** as the passes producing identical output (they review different axes, and a correct design may warrant a dismissal). The loop SHALL be bounded by a **maximum number of rounds**; on reaching the bound without convergence it SHALL **escalate the residual ledger to the human** rather than loop indefinitely. A single human launch of the review SHALL authorize the **entire bounded run** (up to the round bound); the loop SHALL NOT require a fresh human authorization for each additional round's paid external reviewer, but a **new** review SHALL require a **new** human launch — the spend is therefore human-initiated **per run**, not per individual paid call (rounds after the first fire the paid reviewer under the original launch's authorization, an owned deviation from a per-call user-initiation model), and the bounded loop is not interrupted mid-run. Because the same caller both records dismissal rationales and judges convergence, the orchestrator SHALL **surface the full ledger — every finding with its resolution, including each dismissal and its rationale — to the human on every converged run**, not only when the round bound is reached, so a convergence reached by dismissing findings is visible rather than hidden.

#### Scenario: The loop converges when every finding is resolved

- **WHEN** a round is reached in which every finding from every pass has been either fixed or dismissed with a recorded rationale
- **THEN** the orchestrator reports convergence, rather than requiring the passes to produce identical output

#### Scenario: A finding may be dismissed with a rationale

- **WHEN** the caller judges a finding to be a false positive against a justified design decision
- **THEN** dismissing it with a recorded rationale is a legal resolution that counts toward convergence, and the change is not edited to silence it

#### Scenario: The loop is bounded and escalates the residual

- **WHEN** the maximum number of rounds is reached with findings still unresolved
- **THEN** the orchestrator stops and escalates the residual ledger to the human rather than looping indefinitely

#### Scenario: Dismissals are surfaced on a converged run

- **WHEN** the loop converges in a round where one or more findings were resolved by dismissal-with-rationale
- **THEN** the full ledger including those dismissals and their rationales is surfaced to the human, so convergence-by-dismissal is not hidden

#### Scenario: One human launch authorizes the bounded run

- **WHEN** a user launches the review and the loop runs a second round within the bound
- **THEN** the second round's paid external reviewer runs under the original launch's authorization without a fresh prompt, while a subsequent review requires a new human launch

### Requirement: Detectable degradation — absent versus broken versus logged-out

The orchestrator SHALL classify the external reviewer's state **three ways** before running its pass, using staged probes and the reviewer's own **readiness fields** rather than a coarse success/failure of an unrelated command. **(1) Capability absent:** no reviewer companion script is resolvable at all (the version-glob resolution matches nothing, or the reviewer binary is absent from the PATH) — the pass SHALL be **skipped as a single-model degrade**, NOT surfaced as a hard failure, because a fresh clone or a machine where the reviewer was never installed MUST NOT be blocked; and because a never-installed reviewer cannot be distinguished from a corrupted cache missing its companion, an absent companion SHALL default to degrade. **(2) Present but broken:** the companion resolves but a **staged probe fails** — the reviewer's version probe, its app-server probe, or its readiness probe run under a timeout exits nonzero, times out (the readiness probe may contact a background service), or emits malformed output — a **misconfiguration** that SHALL be **surfaced to the human as an error**, never silently treated as a skip — otherwise a broken integration would masquerade as a clean degrade and permanently, silently reduce every review to single-model. **(3) Authentication absence, strictly identified:** the pass SHALL be skipped as a degrade **only** when the readiness fields affirmatively show **all** of: the runtime available, the reviewer binary available, logged-in **false**, the auth source reported as the app-server probe, **and** the requires-authentication field affirmatively **true**. A **null or absent** requires-authentication field SHALL be treated as **indeterminate and surfaced as an error**, not a skip — the reviewer normalizes an app-server connection failure and a genuine logged-out state into the same not-logged-in shape and exposes no probe-success field, so this strict predicate **conservatively rejects some genuine logged-out states**; that is an accepted, documented cost, because full unavailable-versus-broken correctness is not achievable against the installed reviewer version. Whenever a pass is skipped (arm 1 or arm 3), the orchestrator SHALL run the remaining passes, **mark the pass skipped**, and, because the skip removes the cross-model axis, **label the run as reduced (single-model) coverage** rather than implying full cross-model review.

#### Scenario: An absent reviewer degrades to single-model, not a hard failure

- **WHEN** no reviewer companion script is resolvable (a fresh clone, or a machine where the reviewer was never installed) or the reviewer binary is absent from the PATH
- **THEN** the orchestrator skips the external pass as a single-model degrade — running the remaining passes, marking the pass skipped, and labeling the run reduced coverage — rather than surfacing a hard failure that blocks the review

#### Scenario: A strictly-identified auth absence is skipped and the run labeled single-model

- **WHEN** the reviewer's readiness fields affirmatively show its runtime and binary available, logged-in false, the auth source reported as the app-server probe, and the requires-authentication field true (e.g. a genuinely logged-out workstation)
- **THEN** the orchestrator skips that pass, runs the remaining passes, marks the pass skipped, and labels the run as reduced single-model coverage rather than full cross-model review

#### Scenario: A present-but-broken reviewer or indeterminate readiness is surfaced, not skipped

- **WHEN** the companion resolves but a staged probe exits nonzero, times out, or emits malformed output — or the readiness result's requires-authentication field is null or absent (indeterminate, since a connect failure and a genuine logout share the same shape)
- **THEN** the orchestrator surfaces the failure to the human as a misconfiguration rather than silently skipping the pass and reporting a clean degrade

### Requirement: Scope criterion and convergence protocol documentation

The cross-model review SHALL be scoped by a **mechanical criterion** to changes that **alter product behavior or the project's own review/verification tooling** — those touching product code, a spec delta beyond docs/tooling, or the review/verification/CI tooling itself — and run at **pre-archive** (and MAY run post-propose), not per-edit, because a multi-pass, multi-round review is costly. A **purely mechanical** change (documentation, tracker reconciliation, a rename) SHALL remain eligible for the single-agent coherence review alone. The criterion SHALL NOT be "the change has a design document" — nearly every change has one, so that would gate nothing; the scope is therefore *most substantive changes*, with cost bounded by running once and by the degrade behavior, not by a rare-minority framing. The cross-model review SHALL be **human-initiated** yet SHALL sit **inside the point-of-tick** as an enforceable, non-skippable pre-archive gate: an in-scope change's tail SHALL **keep** the standard single-agent coherence-review delegation marker as its own task, and SHALL additionally carry the **distinct blocking cross-review gate task** defined by the receipt requirement below. The cross-model review SHALL NOT be encoded as an auto-firing per-task delegation marker — the apply loop's point-of-tick grammar can express only *delegate-to-subagent* or *run-inline*, and a paid review that must **not** fire merely because a task was reached is neither — so reaching the gate task never auto-fires the paid external reviewer; the human launches the review deliberately before archive, preserving the user-initiated-spend intent, and the gate task is satisfied only by the review's **persisted receipt**, so the step cannot be silently skipped the way a rule living outside the point-of-tick is. The canonical project guide SHALL document the **convergence protocol** (the passes, the common-schema union-with-consensus ledger, the terminating convergence rule with dismissal surfacing, the round bound, the one-launch-authorizes-the-bounded-run spend rule — per run, not per paid call — and the three-way detectable-degrade behavior), the **commit-range review substrate** with its **verifiable per-commit ownership convention** (a validated change trailer or an explicit commit-hash manifest — never branch location), and this **receipt-gated blocking pre-archive-gate convention** (including the archive step's fail-closed receipt precondition).

#### Scenario: A change in scope keeps the standard tail and gains a blocking cross-review gate task

- **WHEN** a change that alters product behavior or the review/verification tooling has its pre-archive tasks authored
- **THEN** the tail carries the standard single-agent coherence-review delegation marker as its own task plus a distinct blocking cross-review gate task (no auto-firing cross-model marker exists), the gate task is satisfied only by the human-initiated review's persisted receipt, and a purely mechanical change (docs/tracker/rename) needs only the single-agent review

#### Scenario: The protocol is documented in the guide

- **WHEN** a contributor or agent reads the canonical project guide
- **THEN** it states the cross-model convergence protocol, the mechanical scope criterion and pre-archive timing, the receipt-gated blocking pre-archive-gate convention (the change tail keeps the single-agent marker; the cross-review gate is its own blocking task, human-initiated, ticked only on the persisted receipt, with archive failing closed without it), the commit-range substrate and its per-commit ownership convention (validated change trailer or explicit commit-hash manifest — never branch location), the one-launch-authorizes-the-bounded-run spend rule (per run, not per paid call), and the three-way detectable-degrade behavior (absent degrades, broken surfaces, only a strictly-identified auth absence skips)

### Requirement: Durable cross-review receipt and fail-closed archive precondition

A completed cross-model review run SHALL persist a **durable receipt** — a committed ledger file in the reviewed change's directory (`openspec/changes/<name>/cross-review-receipt.md`) — recording the run's **verdict**, the **adjudicated ledger** (every finding with its resolution, including each dismissal and its rationale), and the run's **coverage label** (full cross-model, or reduced single-model under a degrade). For an in-scope change, the pre-archive cross-review SHALL be encoded as a **distinct, blocking gate task** in the change's task list — separate from the single-agent coherence-review task — and that task SHALL NOT be ticked until the receipt exists: a **human-attestation gate at the point-of-tick**, not an auto-firing delegation and not prose-only guidance living outside the task list. The archive step SHALL **verify the receipt exists** for an in-scope change and SHALL **fail closed** — refusing to archive — when it is absent, so a prematurely ticked gate task cannot let a change archive without the cross-model review having actually run.

#### Scenario: The receipt is persisted and the gate task blocks until it exists

- **WHEN** an in-scope change's blocking cross-review gate task is reached and no receipt exists in the change's directory
- **THEN** the task remains unticked until a human-initiated cross-model review run completes and persists the receipt recording its verdict, adjudicated ledger, and coverage label — and only then may the gate task be ticked

#### Scenario: Archive refuses without a receipt

- **WHEN** the archive step runs for an in-scope change whose directory contains no cross-review receipt
- **THEN** it fails closed — refusing to archive and surfacing the missing receipt as an unmet precondition — rather than archiving a change whose cross-model review never ran
