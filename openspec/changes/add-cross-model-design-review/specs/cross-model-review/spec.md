## ADDED Requirements

### Requirement: Committed cross-model review orchestrator tooling

The repository SHALL provide **version-controlled** tooling that reviews a **design-bearing** OpenSpec change by composing multiple review passes across **two independently-modeled reviewers** and driving the change toward a converged state. Because the orchestration must both invoke a long-running external reviewer and **apply fixes between rounds**, it SHALL run in the **invoking (main) session**, not inside a review subagent — a subagent cannot own a detached background reviewer without stranding it, and the individual review passes remain observe-only. The tooling SHALL include a **thin launcher command** that invokes the protocol rather than restating it. Given a design-bearing change, the orchestrator SHALL run a **conformance** pass (the committed coherence-review agent) and **two soundness** passes carried out on **different models**, and produce a single merged result.

#### Scenario: The orchestrator tooling is version-controlled

- **WHEN** the repository is cloned and the committed tooling files are inspected
- **THEN** the cross-model review launcher command is present and tracked by git (not gitignored), while machine-local and tool-generated `.claude` files remain ignored

#### Scenario: Orchestration runs in the main session, not a review subagent

- **WHEN** a cross-model review is run for a change
- **THEN** the parallel review passes and the between-round fixes are driven from the invoking session, and no review subagent owns the detached external reviewer (which would strand it)

#### Scenario: A design-bearing change is reviewed by conformance plus two-model soundness

- **WHEN** the orchestrator reviews a design-bearing change
- **THEN** it runs a conformance pass and two soundness passes on different models, and merges their outputs into one result

### Requirement: Union-with-consensus finding ledger and inline diversity pass

The orchestrator SHALL merge the passes' findings into a single **union ledger**, each finding tagged by its **source pass**, and SHALL flag a finding independently raised by **both soundness passes** as a **two-model consensus** finding carrying higher confidence. The passes SHALL be **complementary** — the conformance pass need not duplicate the soundness passes — so the ledger's value is **coverage** (conformance ∪ soundness) *plus* **consensus** (soundness ∩ soundness). The soundness pass that shares the conformance agent's model family SHALL run **inline** within the orchestration rather than as a new standing committed agent, unless and until recurring friction justifies promoting it to committed tooling.

#### Scenario: A finding raised by both soundness passes is marked consensus

- **WHEN** both soundness passes independently raise the same design finding
- **THEN** the ledger flags that finding as a two-model consensus finding of higher confidence than a finding raised by only one pass

#### Scenario: The diversity pass runs inline, not as a new standing agent

- **WHEN** the orchestrator runs the same-model-family soundness pass
- **THEN** it is executed inline within the orchestration rather than by introducing a new committed standing agent, consistent with the guide's rule against a speculative agent roster

### Requirement: Terminating convergence loop

The orchestrator SHALL drive a **terminating convergence loop**: each round runs the passes, the caller **adjudicates every finding** as either **fix** or **dismiss with a recorded rationale**, applies the fixes to the change artifacts, and re-runs the passes. Convergence SHALL be defined as a round in which **no unresolved actionable finding remains from any pass** — explicitly **not** as the passes producing identical output (they review different axes, and a correct design may warrant a dismissal). The loop SHALL be bounded by a **maximum number of rounds**; on reaching the bound without convergence it SHALL **escalate the residual ledger to the human** rather than loop indefinitely.

#### Scenario: The loop converges when every finding is resolved

- **WHEN** a round is reached in which every finding from every pass has been either fixed or dismissed with a recorded rationale
- **THEN** the orchestrator reports convergence, rather than requiring the passes to produce identical output

#### Scenario: A finding may be dismissed with a rationale

- **WHEN** the caller judges a finding to be a false positive against a justified design decision
- **THEN** dismissing it with a recorded rationale is a legal resolution that counts toward convergence, and the change is not edited to silence it

#### Scenario: The loop is bounded and escalates the residual

- **WHEN** the maximum number of rounds is reached with findings still unresolved
- **THEN** the orchestrator stops and escalates the residual ledger to the human rather than looping indefinitely

### Requirement: Graceful degradation when a reviewer is unavailable

When a reviewer is **unavailable** — for example the external soundness reviewer requires authentication and is absent in a headless or CI context — the orchestrator SHALL run the **available** passes, **mark the skipped pass** in the result, and still produce a verdict. It SHALL NOT hard-block on the missing reviewer, and a run that skipped a pass SHALL state so, so the reduced coverage is visible rather than silently implied.

#### Scenario: An absent external reviewer degrades to available passes

- **WHEN** the external soundness reviewer cannot run (e.g. no authentication in a headless context)
- **THEN** the orchestrator runs the available passes, marks the skipped pass in the result, and still returns a verdict rather than failing the whole review

### Requirement: Design-bearing scope and convergence protocol documentation

The cross-model review SHALL be scoped to **design-bearing** changes and run at **pre-archive** (and MAY run post-propose), not per-edit, because a multi-pass, multi-round review is costly. The canonical project guide SHALL document the **convergence protocol** (the passes, the union-with-consensus ledger, the terminating convergence rule, the round bound, and the degrade behavior) and a **per-task delegation marker** that, for a design-bearing change, replaces the single-agent coherence-review marker in the standard change-tail. A trivial or non-design change SHALL remain eligible for the single-agent coherence review alone.

#### Scenario: A design-bearing change carries the cross-review marker

- **WHEN** a design-bearing change's `tasks.md` is authored with its pre-archive review task
- **THEN** that task carries the cross-model review delegation marker in place of the single-agent coherence-review marker, while a trivial change keeps the single-agent marker

#### Scenario: The protocol is documented in the guide

- **WHEN** a contributor or agent reads the canonical project guide
- **THEN** it states the cross-model convergence protocol, the design-bearing scope and timing, the marker convention, and the degrade behavior when a reviewer is unavailable
