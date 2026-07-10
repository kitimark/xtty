# coherence-review Specification

## Purpose
Keep OpenSpec changes coherent by delegating full coherence review to a committed, version-controlled Claude Code agent (`xtty-openspec-critic`) and its thin launcher, so the rule-checking, disk inspection, and cross-change comparison run in an isolated agent context and the invoking session receives only a fixed-skeleton findings verdict. The agent reviews a change (or the whole active change-set) across three passes — single-change coherence, disk-drift, and change-set-aware coherence — deferring at run time to the canonical project guide for the coherence rulebook and to the live repository state for drift ground-truth (never hardcoding either), reporting exact locations with BLOCKER/REVIEW severity, and observing-and-reporting only (never repairing). This capability formalizes the validate-vs-review delegation boundary: mechanical `openspec validate` stays inline, while a full coherence review is delegated via a per-task marker.
## Requirements
### Requirement: Committed coherence-review agent tooling

The repository SHALL provide **version-controlled** Claude Code tooling that reviews an OpenSpec change for coherence in an **isolated agent context**, so the rule-checking, disk inspection, and cross-change comparison do not enter the invoking session, which receives only the agent's findings report. The tooling SHALL include the **agent** and a **thin launcher command**; the launcher SHALL invoke the agent rather than restating its content. Given a reference to a change (a change name, or an "all active" scope), the agent SHALL review it across three passes — **single-change coherence** (the project guide's change-coherence and spec-delta-format rules), **disk-drift** (repository state versus what the artifacts and guide prose claim), and **cross-change coherence** (relationships among the changes currently open) — producing a single fixed-skeleton verdict. The single-change pass SHALL include a **heuristic (REVIEW-severity) check** for whether a change that adds or modifies a regression test states, in `design.md`, the specific claim the test proves, the layer/mechanism that claim lives in, and why the chosen driver (a real program or a direct/synthetic input) actually reaches that layer — never as a BLOCKER, since this is a semantic judgment call, not a mechanical gate.

#### Scenario: The tooling is version-controlled

- **WHEN** the repository is cloned and the committed tooling files are inspected
- **THEN** the coherence-review agent and its launcher command are present and tracked by git (not gitignored), while machine-local and tool-generated `.claude` files remain ignored

#### Scenario: Review noise stays out of the invoking session

- **WHEN** a change is reviewed through the agent
- **THEN** the rule-checking, disk inspection, and cross-change comparison happen in the agent's own context and the invoking session receives only the verdict report

#### Scenario: A change is reviewed across the three passes

- **WHEN** the agent reviews a named change
- **THEN** it reports single-change coherence findings, disk-drift findings, and (when other changes are open) cross-change coherence findings, or states that a pass found nothing

#### Scenario: A test-adding change is checked for stated test precision

- **WHEN** the agent reviews a change whose diff adds or modifies a test file, and `design.md` does not state the test's target claim, the layer that claim lives in, and why the chosen driver reaches it
- **THEN** the agent reports a REVIEW (not BLOCKER) finding naming the missing statement, and a change that does state these is not flagged

### Requirement: Runtime deference to the guide's coherence rulebook and live repository state

The agent SHALL NOT hardcode the coherence rule set. It SHALL read, at run time, the **canonical project guide's** change-coherence and spec-delta-format sections as the authoritative rules, and the **live repository state** (the established specs directory, the active-change list, the change artifacts, and the trackers) as the ground truth for drift — so that a change to the rules, the specs, or the trackers is reflected without editing the agent. The agent MAY encode only the *operationalization* of each rule (how to check it); a rule it cannot mechanically check SHALL be **flagged for human review**, never silently dropped. The agent SHALL treat any count or fraction asserted in guide prose (e.g. "N of M changes carry a harness delta") as re-derivable against disk and flag a mismatch as drift.

#### Scenario: A rule change propagates without editing the agent

- **WHEN** the guide's coherence rules change and a review runs afterwards
- **THEN** the agent checks against the updated rules without any modification to the agent's own definition

#### Scenario: A stale prose count is flagged as drift

- **WHEN** the guide asserts a count or fraction about the repository (e.g. how many archived changes carry a given spec delta) that disagrees with what the disk yields when re-derived
- **THEN** the agent reports the mismatch as a disk-drift finding

#### Scenario: An un-checkable rule is flagged, not dropped

- **WHEN** a coherence rule in the guide cannot be verified mechanically by the agent
- **THEN** the agent flags it for human review rather than omitting it or asserting a pass

### Requirement: Change-set-aware coherence

The agent SHALL, when more than one change is open, review coherence **across** the open changes, not only within a single change. It SHALL surface relationships that a single-change review cannot see: two changes editing the **same established requirement** (a shared-requirement collision that constrains archive order), a declared **apply/archive ordering** between changes (including a reproduce-then-fix "red→green" pair), and a change whose artifacts reference another change as a dependency or sequencing constraint. This cross-change state SHALL be **computed on demand** from the active-change list and the change artifacts, never read from a cached ledger.

#### Scenario: A shared-requirement collision is surfaced

- **WHEN** two open changes both modify the same requirement in the same established capability
- **THEN** the agent reports the collision and notes that it constrains the archive/merge order

#### Scenario: A declared ordering between changes is checked

- **WHEN** one open change's artifacts declare that it must be applied or archived before or after another open change (e.g. a red→green pair)
- **THEN** the agent reports the declared ordering as a cross-change finding so the sequencing is not lost

#### Scenario: Cross-change state is computed, not cached

- **WHEN** the agent performs the cross-change pass
- **THEN** it derives the relationships from the current active-change list and the change artifacts at run time, rather than from any stored index that could be stale

### Requirement: Fixed findings-report contract

The agent's report SHALL follow a fixed skeleton so both a human and an apply/propose-loop caller can act on it: a **definition-version stamp** as the first line (agent-definition edits propagate to spawns with unpredictable lag, so every report self-identifies which definition produced it and the caller can detect a stale-served definition); an overall **verdict** (coherent / issues-found / blocked-prerequisite); the **review scope** (which change(s) were reviewed); a **per-finding** list where each finding names the **rule**, its **location** (file and, where applicable, the requirement/scenario/task), and a **severity** — **BLOCKER** for a hard rule violation or **REVIEW** for a heuristic flag — so heuristics inform without false-failing; a distinct **cross-change** findings section when multiple changes are open; and an actionable **recommendation** (proceed / fix-then-proceed / blocked-prerequisite). A change with any BLOCKER finding SHALL NOT receive a coherent verdict.

#### Scenario: A clean change yields a coherent verdict

- **WHEN** a reviewed change satisfies every hard rule and no heuristic flag rises to a blocker
- **THEN** the verdict is coherent, with any heuristic observations listed as REVIEW findings and a proceed recommendation

#### Scenario: A hard-rule violation blocks the verdict

- **WHEN** a change violates a hard coherence rule (e.g. a MODIFIED requirement that does not paste the entire established block, or a scenario using three hashtags)
- **THEN** the finding is tagged BLOCKER, the verdict is issues-found, and the recommendation is fix-then-proceed

#### Scenario: A heuristic concern informs without failing

- **WHEN** the only findings are heuristic (e.g. suspected mechanism-specific detail inside a requirement)
- **THEN** each is tagged REVIEW, and the verdict may still be coherent with those observations noted

#### Scenario: A stale-served definition is detectable

- **WHEN** a review executes under an agent definition older than the file in the repository
- **THEN** the report's version stamp does not match the repository file's stamp, and the caller treats the run as invalid rather than silently trusting it

### Requirement: Observe-never-repair guardrails

The agent SHALL review and report only. It SHALL NOT edit change artifacts, specs, trackers, or product code to fix a finding — a coherence problem is **reported with a fix-then-proceed recommendation**, never silently corrected. It SHALL report exact locations and rule names rather than vague summaries. A missing prerequisite that blocks the review (e.g. an artifact that does not yet exist, or an established spec it cannot read) SHALL be reported as a **blocked-prerequisite** finding rather than worked around by guessing.

#### Scenario: No repair is attempted

- **WHEN** the review finds a coherence violation
- **THEN** the agent reports it with a fix-then-proceed recommendation and makes no edit to any artifact, spec, tracker, or code

#### Scenario: A blocked prerequisite is reported, not improvised around

- **WHEN** the agent cannot complete the review because a required input is missing (e.g. a not-yet-created artifact, or an unreadable established spec)
- **THEN** it reports a blocked-prerequisite finding stating what is missing, rather than fabricating a verdict

### Requirement: Two documented spawn scenarios and the validate-vs-review boundary

The canonical project guide SHALL document the two ways the agent is spawned: (a) **direct user request** (via the launcher command or natural language), and (b) **apply/propose-task delegation** — a rule that a task which *reviews a change for coherence* is delegated to the agent, with the loop consuming the agent's report and recording its verbatim findings when ticking the task. The guide SHALL define the **validate-vs-review boundary** so the rule is actionable: running `openspec validate` (a cheap, mechanical check) MAY run **inline**, while a **full coherence review** (the rule passes plus drift and cross-change) MUST be **delegated**. To carry that boundary to the point of action, a task in the **delegate** set SHALL be authored with an explicit **per-task delegation marker** naming the agent and the change/scope, so the delegation instruction sits in the task line the loop reads and ticks. The task-authoring configuration SHALL instruct that such tasks carry the marker, **deferring to the guide for the boundary definition**. The guide SHALL also state the **deference chain** — the agent defers to the guide for the coherence rules and to the live repository state for drift. The launcher SHALL document the caller's **delivery check**: compare the report's definition-version stamp against the repository file, and treat a mismatch as a stale-served definition rather than a valid run.

#### Scenario: A coherence-review task is delegated

- **WHEN** a task during apply or propose requires a full coherence review of a change
- **THEN** the task is executed by spawning the coherence-review agent, and the task is ticked with the report's verbatim findings/verdict rather than the review flooding the session

#### Scenario: A review task is authored with a delegation marker

- **WHEN** a change's `tasks.md` is authored with a task that reviews a change for coherence
- **THEN** that task carries an explicit per-task delegation marker naming the agent and the change/scope, and the task-authoring configuration that prompts this defers to the project guide for the boundary rather than restating it

#### Scenario: Running validate stays inline

- **WHEN** a task only runs `openspec validate` for a mechanical pass/fail
- **THEN** it carries no delegation marker and may run inline

#### Scenario: The boundary and deference chain are documented

- **WHEN** a contributor or agent reads the canonical project guide
- **THEN** it states both spawn scenarios, the validate-vs-review boundary, the per-task marker convention, and the deference chain (rules in the guide; drift ground-truth in the live repository)

#### Scenario: The caller performs the delivery check

- **WHEN** the launcher relays a review report
- **THEN** the caller compares the report's definition-version stamp against the repository agent file and treats a mismatch as a stale-served definition rather than a valid run

