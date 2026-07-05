# test-validation — add-test-validation-agent delta

## ADDED Requirements

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

The agent's report SHALL follow a fixed skeleton so both a human and an apply-loop caller can act on it: an overall **verdict** (in-envelope / out-of-envelope / regression); **verbatim** per-tier counts and failing-test sets (never paraphrased); a per-failure **classification** mapping every red to a named known bucket or **UNEXPLAINED** — and any UNEXPLAINED red SHALL prevent an in-envelope verdict; a **cross-environment consistency** assessment against the expected-difference matrix (an unexplained cross-tier delta is itself a reportable finding); **evidence paths** (the agent SHALL preserve result bundles and write a review document); actionable **feedback** for the caller; and a **cleanup manifest** enumerating everything the sweep created or left running with the commands to remove it. The agent SHALL NOT delete rigs, clones, or evidence itself — follow-on review and re-verification take precedence over tidiness.

#### Scenario: A known-benign residual does not fail the verdict

- **WHEN** a sweep's only reds match documented known-benign buckets (e.g. an environment-capability gap recorded in the matrix)
- **THEN** the report classifies each red to its named bucket and the verdict is in-envelope, with the residuals listed verbatim

#### Scenario: An unexplained red forces a non-green verdict

- **WHEN** any failing test cannot be mapped to a documented bucket
- **THEN** the verdict is not in-envelope and the feedback section recommends stop-and-investigate before proceeding

#### Scenario: Nothing is deleted; the manifest says what may be

- **WHEN** a sweep completes (fully or partially)
- **THEN** every clone/rig/artifact created is still present and the report's cleanup manifest lists each with the exact removal command, so the user decides what to keep for further verification

### Requirement: Two documented spawn scenarios

The canonical project guide SHALL document the two ways the agent is spawned: (a) **direct user request** (via the launcher command or natural language), and (b) **spec-workflow verify tasks** — a delegation rule that change-verification tasks which execute the test suite are delegated to the agent, with the apply loop consuming the agent's report and recording its verbatim results when ticking the task. The guide SHALL also state the deference chain (the agent defers to the project guide for rules and to the test-image documentation for numbers) so the documents cannot drift apart silently.

#### Scenario: A verify task is delegated

- **WHEN** an OpenSpec change's verify task requires running the suite (locally or on the VM rigs) during apply
- **THEN** the task is executed by spawning the test-validation agent, and the task is ticked with the report's verbatim counts/classification rather than inline execution flooding the session

#### Scenario: The delegation rule is documented

- **WHEN** a contributor or agent reads the canonical project guide
- **THEN** it states both spawn scenarios and the deference chain for the test-validation tooling

### Requirement: Validation-discipline guardrails

The agent SHALL encode the measured validation discipline: **no retry flags or in-run retries** (retry tolerance masks per-launch races); **clone-per-run** against the golden test image, never booting or mutating the golden itself; **serialized** VM runs (concurrent clones on one host distort the constrained-CPU race timing that gives the VM tier its meaning); **observe-never-repair** (the agent never edits tests, configuration, or product code to change an outcome — an out-of-envelope result is reported, not fixed); and a **hands-off warning** before the local bare-metal tier (live mouse/keyboard interference is a measured flake source).

#### Scenario: Retries are never used

- **WHEN** a VM tier is executed, including a requested multi-run sweep
- **THEN** each run is a single execution per test with no retry flag, and repeated runs are separate sequential full runs

#### Scenario: The golden image is never touched

- **WHEN** any VM tier runs
- **THEN** the sweep operates on a fresh clone of the golden image and the golden itself is never booted or modified
