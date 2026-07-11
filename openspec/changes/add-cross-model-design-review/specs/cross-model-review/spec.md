## ADDED Requirements

### Requirement: Committed cross-model review orchestrator tooling

The repository SHALL provide **version-controlled** tooling that reviews an OpenSpec change **in scope for cross-model review** (see the scope requirement) by composing multiple review passes across **two independently-modeled reviewers** and driving the change toward a converged state. Because the orchestration must both invoke a long-running external reviewer and **apply fixes between rounds**, it SHALL run in the **invoking (main) session**, not inside a review subagent — a subagent cannot own a detached background reviewer without stranding it, and the individual review passes remain observe-only. The tooling SHALL include a **thin launcher command** that invokes the protocol rather than restating it. Given such a change, the orchestrator SHALL run a **conformance** pass (the committed coherence-review agent) and **two soundness** passes carried out on **different models**, and produce a single merged result. The orchestrator SHALL locate the external soundness reviewer by a **version-independent** resolution rather than a version-pinned path, and SHALL **scope each soundness review to the change under review** — its own artifact and product paths — rather than the whole repository, so that with several changes open (including committed ones) no pass reviews a *different* change in its place.

#### Scenario: The orchestrator tooling is version-controlled

- **WHEN** the repository is cloned and the committed tooling files are inspected
- **THEN** the cross-model review launcher command is present and tracked by git (not gitignored), while machine-local and tool-generated `.claude` files remain ignored

#### Scenario: Orchestration runs in the main session, not a review subagent

- **WHEN** a cross-model review is run for a change
- **THEN** the parallel review passes and the between-round fixes are driven from the invoking session, and no review subagent owns the detached external reviewer (which would strand it)

#### Scenario: A change in scope is reviewed by conformance plus two-model soundness

- **WHEN** the orchestrator reviews a change in scope for cross-model review
- **THEN** it runs a conformance pass and two soundness passes on different models, and merges their outputs into one result

#### Scenario: A soundness review is scoped to the change, not the repository

- **WHEN** more than one change is open (some committed) and the orchestrator runs a soundness pass for a named change
- **THEN** that pass reviews only the named change's own artifact and product paths, not other open changes' commits, and the external reviewer is located by a version-independent resolution rather than a version-pinned path

### Requirement: Union-with-consensus finding ledger and inline diversity pass

The orchestrator SHALL merge the passes' findings into a single **union ledger**, each finding tagged by its **source pass**, and SHALL flag a finding independently raised by **both soundness passes** as a **two-model consensus** finding carrying higher confidence. To make "the same finding raised by both" a **defined** match rather than a fuzzy judgment, **both soundness passes SHALL emit findings in a common structured schema** (at least a severity, a title, the implicated file, a location, and a confidence), and consensus SHALL be determined by matching on that structure (the implicated file and the claim's subject), not by prose similarity. The passes SHALL be **complementary** — the conformance pass need not duplicate the soundness passes — so the ledger's value is **coverage** (conformance ∪ soundness) *plus* **consensus** (soundness ∩ soundness). The soundness pass that shares the conformance agent's model family SHALL run **inline** within the orchestration (emitting the common schema) rather than as a new standing committed agent, unless and until recurring friction justifies promoting it to committed tooling.

#### Scenario: A finding raised by both soundness passes is marked consensus

- **WHEN** both soundness passes independently raise the same design finding
- **THEN** the ledger flags that finding as a two-model consensus finding of higher confidence than a finding raised by only one pass

#### Scenario: The diversity pass runs inline, not as a new standing agent

- **WHEN** the orchestrator runs the same-model-family soundness pass
- **THEN** it is executed inline within the orchestration rather than by introducing a new committed standing agent, consistent with the guide's rule against a speculative agent roster

#### Scenario: Both soundness passes emit a common schema for consensus matching

- **WHEN** the two soundness passes run
- **THEN** each emits its findings in the common structured schema, and the consensus flag is computed by matching on the implicated file and claim rather than by a subjective prose comparison

### Requirement: Terminating convergence loop

The orchestrator SHALL drive a **terminating convergence loop**: each round runs the passes, the caller **adjudicates every finding** as either **fix** or **dismiss with a recorded rationale**, applies the fixes to the change artifacts, and re-runs the passes. Convergence SHALL be defined as a round in which **no unresolved actionable finding remains from any pass** — explicitly **not** as the passes producing identical output (they review different axes, and a correct design may warrant a dismissal). The loop SHALL be bounded by a **maximum number of rounds**; on reaching the bound without convergence it SHALL **escalate the residual ledger to the human** rather than loop indefinitely. Because the same caller both records dismissal rationales and judges convergence, the orchestrator SHALL **surface the full ledger — every finding with its resolution, including each dismissal and its rationale — to the human on every converged run**, not only when the round bound is reached, so a convergence reached by dismissing findings is visible rather than hidden.

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

### Requirement: Detectable degradation — unavailable versus broken

The orchestrator SHALL distinguish a reviewer that is **legitimately unavailable** from one whose invocation is **broken or misconfigured**. Only a **legitimately-unavailable** reviewer — determined by the reviewer's own **readiness signal** (e.g. missing authentication in a headless or CI context) — SHALL cause its pass to be **skipped**; the orchestrator SHALL then run the remaining passes, **mark the pass skipped**, and, because the skip removes the cross-model axis, **label the run as reduced (single-model) coverage** rather than implying full cross-model review. Any **other** failure to invoke the reviewer (an unresolved or moved script path, a module or spawn error) is a **misconfiguration** and SHALL be **surfaced to the human as an error**, never silently treated as a skip — otherwise a broken integration would masquerade as a clean degrade and permanently, silently reduce every review to single-model.

#### Scenario: A legitimately-unavailable reviewer is skipped and the run labeled single-model

- **WHEN** the external soundness reviewer's readiness signal reports it unavailable (e.g. no authentication in a headless context)
- **THEN** the orchestrator skips that pass, runs the remaining passes, marks the pass skipped, and labels the run as reduced single-model coverage rather than full cross-model review

#### Scenario: A broken reviewer invocation is surfaced, not skipped

- **WHEN** the external soundness reviewer cannot be invoked for a reason other than its readiness signal (e.g. its script path does not resolve, or it errors on launch)
- **THEN** the orchestrator surfaces the failure to the human as a misconfiguration rather than silently skipping the pass and reporting a clean degrade

### Requirement: Scope criterion and convergence protocol documentation

The cross-model review SHALL be scoped by a **mechanical criterion** to changes that **alter product behavior or the project's own review/verification tooling** — those touching product code, a spec delta beyond docs/tooling, or the review/verification/CI tooling itself — and run at **pre-archive** (and MAY run post-propose), not per-edit, because a multi-pass, multi-round review is costly. A **purely mechanical** change (documentation, tracker reconciliation, a rename) SHALL remain eligible for the single-agent coherence review alone. The criterion SHALL NOT be "the change has a design document" — nearly every change has one, so that would gate nothing; the scope is therefore *most substantive changes*, with cost bounded by running once and by the degrade behavior, not by a rare-minority framing. The canonical project guide SHALL document the **convergence protocol** (the passes, the common-schema union-with-consensus ledger, the terminating convergence rule with dismissal surfacing, the round bound, and the detectable-degrade behavior) and a **per-task delegation marker** that, for an in-scope change, replaces the single-agent coherence-review marker in the standard change-tail.

#### Scenario: A change in scope carries the cross-review marker

- **WHEN** a change that alters product behavior or the review/verification tooling has its pre-archive review task authored
- **THEN** that task carries the cross-model review delegation marker in place of the single-agent coherence-review marker, while a purely mechanical change (docs/tracker/rename) keeps the single-agent marker

#### Scenario: The protocol is documented in the guide

- **WHEN** a contributor or agent reads the canonical project guide
- **THEN** it states the cross-model convergence protocol, the mechanical scope criterion and pre-archive timing, the marker convention, and the detectable-degrade behavior (unavailable versus broken)
