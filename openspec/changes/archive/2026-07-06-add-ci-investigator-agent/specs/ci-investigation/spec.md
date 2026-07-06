## ADDED Requirements

### Requirement: Committed CI-investigation agent tooling

The repository SHALL provide **version-controlled** Claude Code tooling that investigates a failed CI run in an **isolated agent context** so the evidence-gathering noise (failing-job logs, result-bundle parsing, exported attachments) does not enter the invoking session, which receives only the agent's report. The tooling SHALL include the **agent** and a **thin launcher command**; the launcher SHALL invoke the agent rather than restating its content. Given a reference to a CI run (a URL or run id), the agent SHALL handle the whole CI-failure space — including UI-test failures (retrieving and reading the run's structured test results and captured attachments), build/compile breaks, a failing **required gate**, and PR-title-lint failures — producing a single fixed-skeleton verdict.

#### Scenario: The tooling is version-controlled

- **WHEN** the repository is cloned and the committed tooling files are inspected
- **THEN** the CI-investigation agent and its launcher command are present and tracked by git (not gitignored), while machine-local and tool-generated `.claude` files remain ignored

#### Scenario: Evidence-gathering noise stays out of the invoking session

- **WHEN** a CI run is investigated through the agent
- **THEN** the log retrieval, result-bundle parsing, and attachment export happen in the agent's own context and the invoking session receives only the verdict report

#### Scenario: The failure type is triaged

- **WHEN** the referenced run's failing job is a build break, a required-gate red, a UI-test red, or a PR-title-lint red
- **THEN** the agent gathers the evidence appropriate to that failure type (compile error with file and line; the structured test results and captured attachments for a UI-test red; the offending title for a lint red) and reports it verbatim

### Requirement: Runtime deference to a durably-recorded CI expected-difference matrix

The agent SHALL NOT hardcode known-benign failure buckets, failing-test expectations, or which jobs gate merges. It SHALL read, at run time, the **CI expected-difference matrix** and the **required-gate/non-blocking job map** from their repository home (the CI analysis documentation), so that changes landing elsewhere (a test added or removed, an environment fix, a job's required status changing) update the agent's judgments without editing the agent. The repository documentation SHALL therefore durably record the CI expected-difference matrix — the hosted-runner-specific failures that are *legitimately* environment-caused (e.g. a long runner prompt soft-wrapping a test's marker, or a runner shell lacking bracketed paste), each mapped to its cause and bucket, alongside which jobs are required gates versus non-blocking. Any change that alters the set of expected CI residuals (adds/removes a test, fixes a known-benign residual, changes a job's gate status) SHALL update this matrix in the same session, so the agent's runtime read does not silently relocate staleness.

#### Scenario: Matrix changes propagate without editing the agent

- **WHEN** the documented CI expected-difference matrix changes (e.g. a known-benign residual is fixed, or a new one is recorded) and an investigation runs afterwards
- **THEN** the agent classifies the run's failures against the updated matrix without any modification to the agent's own definition

#### Scenario: The CI matrix has a durable repository home

- **WHEN** a contributor reads the CI analysis documentation
- **THEN** it records the expected hosted-runner differences with their causes and buckets, next to the map of which jobs are required gates versus non-blocking

#### Scenario: A residual-changing change updates the matrix

- **WHEN** a change lands that adds or removes a test, fixes a known-benign CI residual, or changes a job's required-gate status
- **THEN** the CI expected-difference matrix is updated in the same session so the agent's later runtime read reflects reality

### Requirement: Fixed verdict-report contract

The agent's report SHALL follow a fixed skeleton so both a human and an apply-loop caller can act on it: a **definition-version stamp** as the first line (agent-definition edits propagate to spawns with unpredictable lag, so every report self-identifies which definition produced it and the caller can detect a stale-served definition); an overall **verdict** (in-envelope / out-of-envelope / regression); the **run identity** — the failing job(s) with each marked **required-gate or non-blocking**, the triggering commit, and whether that commit touched product/test code (a regression pre-check); **verbatim** failing-test/step names and their assertion or error messages (never paraphrased); a per-failure **classification** mapping every failure to a named bucket from the CI matrix or to **UNEXPLAINED** — and any UNEXPLAINED failure SHALL prevent an in-envelope verdict; **evidence paths** for the retrieved bundle and any key attachments; and an actionable **recommendation** (proceed / stop-and-investigate / blocked-prerequisite). A failure on a **required gate** SHALL be treated as a stop signal (verdict regression or, at minimum, a stop-and-investigate recommendation) regardless of bucket, because that job gates merges.

#### Scenario: A known-benign residual on a non-blocking job does not fail the verdict

- **WHEN** the only failures are on a non-blocking job and each maps to a documented known-benign bucket in the CI matrix
- **THEN** the report classifies each failure to its named bucket, states the job is non-blocking, and the verdict is in-envelope with a proceed recommendation

#### Scenario: An unexplained failure forces a non-green verdict

- **WHEN** any failing test or step cannot be mapped to a documented bucket
- **THEN** the verdict is not in-envelope and the recommendation is stop-and-investigate

#### Scenario: A required-gate failure is a stop signal

- **WHEN** the failing job is a required merge gate
- **THEN** the report marks it as such and issues a stop-and-investigate (or regression) verdict regardless of how the individual failures classify

#### Scenario: A stale-served definition is detectable

- **WHEN** an investigation executes under an agent definition older than the file in the repository
- **THEN** the report's version stamp does not match the repository file's stamp, and the caller treats the run as invalid rather than silently trusting it

#### Scenario: A docs-only run short-circuits without deep forensics

- **WHEN** the triggering commit touched no product or test code and every failure maps to a known-benign bucket
- **THEN** the report may reach its verdict without a full deep-dive, still mapping each failure to its bucket and noting the commit touched no product/test code

### Requirement: Observe-never-repair guardrails

The agent SHALL diagnose and classify only. It SHALL NOT edit tests, configuration, or product code to change an outcome, and SHALL NOT re-run, retry, or cancel any CI job to alter or mask a result — an out-of-envelope or regression result is **reported with a stop-and-investigate recommendation**, never fixed or hidden. It SHALL report exact failing-test/step names and messages verbatim rather than rounding or paraphrasing them. A missing prerequisite that blocks evidence retrieval (e.g. unavailable run access, or a result-bundle tool whose output shape it does not recognize) SHALL be reported as a **blocked-prerequisite** finding rather than worked around by guessing.

#### Scenario: No repair is attempted

- **WHEN** the investigation finds a genuine regression or an unexplained failure
- **THEN** the agent reports it with a stop-and-investigate recommendation and makes no edit to product, test, or configuration code and triggers no CI re-run

#### Scenario: A blocked prerequisite is reported, not improvised around

- **WHEN** the agent cannot retrieve or parse the run's evidence (run access unavailable, or the result-bundle tooling output is unrecognized)
- **THEN** it reports a blocked-prerequisite finding stating what is missing, rather than fabricating or guessing a classification

### Requirement: Two documented spawn scenarios and the watch-vs-investigate boundary

The canonical project guide SHALL document the two ways the agent is spawned: (a) **direct user request** (via the launcher command or natural language), and (b) **spec-workflow / CI-task delegation** — a rule that a task which *investigates a failed CI run* during apply is delegated to the agent, with the apply loop consuming the agent's report and recording its verbatim results when ticking the task. The guide SHALL define the **watch-vs-investigate boundary** so the rule is actionable: *watching* CI or reading a run's status (e.g. following a run to completion) is a cheap check that MAY run **inline**, while *investigating a failed run* MUST be **delegated**. To carry that boundary to the point of action, a task in the **delegate** set SHALL be authored with an explicit **per-task delegation marker** naming the agent and the run/scope, so the delegation instruction sits in the task line the apply loop reads and ticks. The task-authoring configuration SHALL instruct that such tasks carry the marker, **deferring to the guide for the boundary definition** so the boundary has a single source of truth. The guide SHALL also state the **deference chain** — the agent defers to the project guide for rules and to the CI analysis documentation for the matrix and job map — so the documents cannot drift apart silently. The launcher SHALL document the caller's **delivery check**: compare the report's definition-version stamp against the repository file, and treat a mismatch as a stale-served definition rather than a valid run.

#### Scenario: A CI-investigation task is delegated

- **WHEN** a task during apply requires investigating a failed CI run
- **THEN** the task is executed by spawning the CI-investigation agent, and the task is ticked with the report's verbatim verdict/classification rather than the investigation flooding the session

#### Scenario: An investigate task is authored with a delegation marker

- **WHEN** a change's `tasks.md` is authored with a task that investigates a failed CI run
- **THEN** that task carries an explicit per-task delegation marker naming the agent and the run/scope, and the task-authoring configuration that prompts this defers to the project guide for the boundary rather than restating it

#### Scenario: Watching CI stays inline

- **WHEN** a task only watches a CI run or reads its status for iterative feedback
- **THEN** it carries no delegation marker and may run inline

#### Scenario: The boundary and deference chain are documented

- **WHEN** a contributor or agent reads the canonical project guide
- **THEN** it states both spawn scenarios, the watch-vs-investigate boundary, the per-task marker convention, and the deference chain (rules in the project guide; the CI matrix and job map in the CI analysis documentation)

#### Scenario: The caller performs the delivery check

- **WHEN** the launcher relays an investigation report
- **THEN** the caller compares the report's definition-version stamp against the repository agent file and treats a mismatch as a stale-served definition rather than a valid run
