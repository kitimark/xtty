# test-validation Specification

## Purpose

Defines xtty's **multi-environment test-validation** tooling: the committed `xtty-test-validator` Claude Code agent (`.claude/agents/xtty-test-validator.md`) and its thin `/xtty:validate` launcher (`.claude/commands/xtty/validate.md`), which run the suite across the validation environments — the fast `XttyCore` unit tier, local bare-metal XCUITests, the headless Tart VM rig, and the graphics VM rig — inside an isolated agent context so the invoking session receives only a fixed-skeleton verdict report. It covers the runtime deference to repo-owned numbers (the living acceptance envelope + the expected-difference matrix in the test-image documentation, with the reverse duty on envelope-shifting changes), the report contract (a definition-version stamp for stale-delivery detection, verbatim counts, per-red classification with UNEXPLAINED forcing a non-green verdict, cross-environment consistency, incrementally-written evidence + launch ledger, feedback, and a cleanup manifest — the agent deletes nothing), the two spawn scenarios (direct user request; OpenSpec verify-task delegation) with the caller's delivery-check + strand-recovery duties, and the measured validation-discipline guardrails (no retries, clone-per-run against the golden image, serialized VM runs, observe-never-repair, hands-off warning, continuous execution). Mechanism details (the `run_in_background` subagent trap, the unfused launch/wait recipe) live in the archived change's design and `research/03-analysis/claude-code-subagent-execution-forensics.md`.
## Requirements
### Requirement: Committed test-validation agent tooling

The repository SHALL provide **version-controlled** Claude Code tooling that runs xtty's test suite across the validation environments — the fast core tier, the local bare-metal suite, the headless VM rig, and the graphics VM rig — in an **isolated agent context** so the execution noise (polling, remote-shell output, build/test logs) does not enter the invoking session, which receives only the agent's report. The tooling SHALL include the **agent** and a **thin launcher command**; the launcher SHALL invoke the agent rather than restating its content. The agent SHALL support running any requested subset of tiers, with documented defaults (a quick-confirm subset by default; a full sweep — including at least two headless VM runs — for product-code changes, because per-launch races are not settled by a single run).

#### Scenario: The tooling is version-controlled

- **WHEN** the repository is cloned and the committed tooling files are inspected
- **THEN** the test-validation agent and its launcher command are present and tracked by git (not gitignored), while machine-local and tool-generated `.claude` files remain ignored

#### Scenario: Execution noise stays out of the invoking session

- **WHEN** a validation sweep is run through the agent
- **THEN** the tier execution (VM boots, remote-shell polling, build/test logs) happens in the agent's own context and the invoking session receives only the verdict report

### Requirement: Runtime deference for envelope and environment-difference numbers

The agent SHALL NOT hardcode acceptance counts, failing-set expectations, or environment-difference facts. It SHALL read, at run time, the **living acceptance envelope** and the **expected-difference matrix** from their repository home (the test-image documentation), so that changes landing elsewhere (e.g. a test being added or deleted, an environment fix) update the agent's judgments without editing the agent. The repository documentation SHALL therefore durably record the expected-difference matrix — the per-environment deltas that are *legitimate* (shell-dependent test arms, race sensitivity, input-capability gaps, interference sources) — alongside the acceptance envelope.

#### Scenario: Envelope changes propagate without editing the agent

- **WHEN** the documented acceptance envelope changes (e.g. a change lands that removes a test or fixes a known-benign residual) and a validation sweep runs afterwards
- **THEN** the agent classifies results against the updated envelope without any modification to the agent's own definition

#### Scenario: The expected-difference matrix has a durable repository home

- **WHEN** a contributor reads the test-image documentation
- **THEN** it records the expected per-environment differences (local vs headless VM vs graphics VM) with their causes, next to the acceptance envelope the agent reads

### Requirement: Fixed verdict-report contract with a cleanup manifest

The agent's report SHALL follow a fixed skeleton so both a human and an apply-loop caller can act on it: a **definition-version stamp** as the first line (agent-definition edits propagate to spawns with unpredictable lag, so every report self-identifies which definition version produced it and the caller can detect a stale-served definition); an overall **verdict** (in-envelope / out-of-envelope / regression); **verbatim** per-tier counts and failing-test sets (never paraphrased); a per-failure **classification** mapping every red to a named known bucket or **UNEXPLAINED** — and any UNEXPLAINED red SHALL prevent an in-envelope verdict; a **cross-environment consistency** assessment against the expected-difference matrix (an unexplained cross-tier delta is itself a reportable finding); **evidence paths** (the agent SHALL preserve result bundles, write a review document, and record every long-running launch in an on-disk ledger as it happens — evidence is written incrementally, never held for a single final write, so a cut-off sweep is reconstructable from disk); actionable **feedback** for the caller; and a **cleanup manifest** enumerating everything the sweep created or left running with the commands to remove it. The agent SHALL NOT delete rigs, clones, or evidence itself — follow-on review and re-verification take precedence over tidiness (stopping a finished, evidence-collected VM is permitted; deleting is not).

#### Scenario: A known-benign residual does not fail the verdict

- **WHEN** a sweep's only reds match documented known-benign buckets (e.g. an environment-capability gap recorded in the matrix)
- **THEN** the report classifies each red to its named bucket and the verdict is in-envelope, with the residuals listed verbatim

#### Scenario: An unexplained red forces a non-green verdict

- **WHEN** any failing test cannot be mapped to a documented bucket
- **THEN** the verdict is not in-envelope and the feedback section recommends stop-and-investigate before proceeding

#### Scenario: Nothing is deleted; the manifest says what may be

- **WHEN** a sweep completes (fully or partially)
- **THEN** every clone/rig/artifact created is still present and the report's cleanup manifest lists each with the exact removal command, so the user decides what to keep for further verification

#### Scenario: A stale-served definition is detectable

- **WHEN** a validation run executes under an agent definition older than the file in the repository
- **THEN** the report's version stamp does not match the repository file's stamp, and the caller treats the run as invalid for judging any definition change rather than silently trusting it

### Requirement: Two documented spawn scenarios

The canonical project guide SHALL document the two ways the agent is spawned: (a) **direct user request** (via the launcher command or natural language), and (b) **spec-workflow verify tasks** — a delegation rule that change-verification tasks which execute the test suite are delegated to the agent, with the apply loop consuming the agent's report and recording its verbatim results when ticking the task. The guide SHALL also state the deference chain (the agent defers to the project guide for rules and to the test-image documentation for numbers) so the documents cannot drift apart silently. The launcher SHALL additionally document the caller's half of the workflow: the **delivery check** (compare the report's definition-version stamp against the repository file) and the **strand-recovery protocol** — if a sweep ends without a final report, the caller reconstructs state from the run's on-disk evidence and **resumes the same agent** rather than spawning a fresh run, recording the resume in the run's review document so a resurrected run is distinguishable from a clean one.

#### Scenario: A verify task is delegated

- **WHEN** an OpenSpec change's verify task requires running the suite (locally or on the VM rigs) during apply
- **THEN** the task is executed by spawning the test-validation agent, and the task is ticked with the report's verbatim counts/classification rather than inline execution flooding the session

#### Scenario: The delegation rule is documented

- **WHEN** a contributor or agent reads the canonical project guide
- **THEN** it states both spawn scenarios and the deference chain for the test-validation tooling

#### Scenario: A stranded sweep is recovered, not rerun

- **WHEN** the agent's task ends without a final report while tier work is still running or partial evidence exists on disk
- **THEN** the caller follows the documented recovery protocol — resuming the same agent with the on-disk state rather than starting a fresh sweep — and the resume is recorded in the run's review document

### Requirement: Validation-discipline guardrails

The agent SHALL encode the measured validation discipline: **no retry flags or in-run retries** (retry tolerance masks per-launch races); **clone-per-run** against the golden test image, never booting or mutating the golden itself (with a unique clone name per run, since kept clones make name reuse collide); **serialized** VM runs (concurrent clones on one host distort the constrained-CPU race timing that gives the VM tier its meaning); **observe-never-repair** (the agent never edits tests, configuration, or product code to change an outcome — an out-of-envelope result is reported, not fixed); a **hands-off warning** before the local bare-metal tier (live mouse/keyboard interference is a measured flake source); and **continuous execution** — the agent SHALL remain actively driving its tools for the entire sweep, bridging long-running tiers with bounded, reissued waits, and SHALL NOT end its turn to await any external notification while tier work is executing (a subagent whose turn ends is never re-invoked; ending the turn mid-sweep strands the run — measured three times before this discipline was encoded). A genuinely wedged tier (prolonged zero progress) is reported as a blocker with its live processes documented, rather than either waiting forever or abandoning the sweep silently.

#### Scenario: Retries are never used

- **WHEN** a VM tier is executed, including a requested multi-run sweep
- **THEN** each run is a single execution per test with no retry flag, and repeated runs are separate sequential full runs

#### Scenario: The golden image is never touched

- **WHEN** any VM tier runs
- **THEN** the sweep operates on a fresh clone of the golden image and the golden itself is never booted or modified

#### Scenario: Long waits do not strand the sweep

- **WHEN** a tier's execution outlasts any single tool call's time limit
- **THEN** the agent bridges the wait by remaining continuously active (bounded waits, reissued on timeout) and the sweep proceeds to its final report or a blocker report without requiring external resurrection

