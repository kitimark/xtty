# test-validation — delta for harden-validator-delegation-trigger

## MODIFIED Requirements

### Requirement: Two documented spawn scenarios

The canonical project guide SHALL document the two ways the agent is spawned: (a) **direct user request** (via the launcher command or natural language), and (b) **spec-workflow verify tasks** — a delegation rule that change-verification tasks which execute the test suite are delegated to the agent, with the apply loop consuming the agent's report and recording its verbatim results when ticking the task. The guide SHALL define the **delegation boundary** so the rule is actionable rather than aspirational: a verify task that runs the **local bare-metal XCUITest suite, any VM tier, or a full acceptance matrix** MUST be delegated, while **cheap checks run for iterative feedback** during implementation (the fast view-free unit tier, one-off state-dump launches, text/grep checks, prerequisite checks, spec validation) MAY run inline. To carry that boundary to the point of action, a verify task in the **delegate** set SHALL be authored with an explicit **per-task delegation marker** naming the agent and the tier/scope, so the delegation instruction sits in the task line the apply loop reads and ticks — not only in the guide read at session start (which does not reach the apply step). The task-authoring configuration shown when verify tasks are written SHALL instruct that such tasks carry the marker, **deferring to the guide for the boundary definition** so the boundary has a single source of truth. Before ticking a verify task that executed a suite, the apply loop SHALL confirm the counts came from the agent's report, or that the inline run was a cheap/iteration case within the boundary. The guide SHALL also state the deference chain (the agent defers to the project guide for rules and to the test-image documentation for numbers) so the documents cannot drift apart silently. The launcher SHALL additionally document the caller's half of the workflow: the **delivery check** (compare the report's definition-version stamp against the repository file) and the **strand-recovery protocol** — if a sweep ends without a final report, the caller reconstructs state from the run's on-disk evidence and **resumes the same agent** rather than spawning a fresh run, recording the resume in the run's review document so a resurrected run is distinguishable from a clean one.

#### Scenario: A verify task is delegated

- **WHEN** an OpenSpec change's verify task requires running the suite (locally or on the VM rigs) during apply
- **THEN** the task is executed by spawning the test-validation agent, and the task is ticked with the report's verbatim counts/classification rather than inline execution flooding the session

#### Scenario: A suite-executing verify task is authored with a delegation marker

- **WHEN** a change's `tasks.md` is authored with a verify task that runs the local bare-metal XCUITest suite, a VM tier, or a full acceptance matrix
- **THEN** that task carries an explicit per-task delegation marker naming the agent and the tier/scope, so the delegation instruction is present in the task line the apply loop reads, and the task-authoring configuration that prompts this defers to the project guide for the boundary rather than restating it

#### Scenario: A cheap check stays inline

- **WHEN** a verify task runs only a cheap check for iterative feedback (the fast view-free unit tier, a one-off state-dump launch, a text/grep or prerequisite check, or spec validation)
- **THEN** it carries no delegation marker and may run inline, and ticking it does not require an agent report

#### Scenario: The delegation rule is documented

- **WHEN** a contributor or agent reads the canonical project guide
- **THEN** it states both spawn scenarios, the delegation boundary (which tiers delegate vs which may run inline), the per-task marker convention, and the deference chain for the test-validation tooling

#### Scenario: A stranded sweep is recovered, not rerun

- **WHEN** the agent's task ends without a final report while tier work is still running or partial evidence exists on disk
- **THEN** the caller follows the documented recovery protocol — resuming the same agent with the on-disk state rather than starting a fresh sweep — and the resume is recorded in the run's review document
