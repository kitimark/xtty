## MODIFIED Requirements

### Requirement: Committed coherence-review agent tooling

The repository SHALL provide **version-controlled** Claude Code tooling that reviews an OpenSpec change for coherence in an **isolated agent context**, so the rule-checking, disk inspection, and cross-change comparison do not enter the invoking session, which receives only the agent's findings report. The tooling SHALL include the **agent** and a **thin launcher command**; the launcher SHALL invoke the agent rather than restating its content. Given a reference to a change (a change name, or an "all active" scope), the agent SHALL review it across three passes — **single-change coherence** (the project guide's change-coherence and spec-delta-format rules), **disk-drift** (repository state versus what the artifacts and guide prose claim), and **cross-change coherence** (relationships among the changes currently open) — producing a single fixed-skeleton verdict. The single-change pass SHALL include a **heuristic (REVIEW-severity) check** for whether a change that adds or modifies a regression test states, in `design.md`, the specific claim the test proves, the layer/mechanism that claim lives in, and why the chosen driver (a real program or a direct/synthetic input) actually reaches that layer — never as a BLOCKER, since this is a semantic judgment call, not a mechanical gate. The single-change pass SHALL also include a **heuristic (REVIEW-severity) check** for whether a change's tracker reconcile appends a per-change narrative to a status-surface row or paragraph that the project guide designates as category-keyed (edited only when a genuinely new category is introduced, never per-change) — never as a BLOCKER, since distinguishing a category summary from a narrative append is a semantic judgment call, not a mechanical gate. The single-change pass SHALL additionally include a **design-claim code-accuracy check**: the agent SHALL verify the **concrete code claims** a change's `design.md` and `tasks.md` make about the *existing* codebase — named files, types, fields, functions, symbols, and "mirrors `X`" assertions — against the actual source, read-only, reporting a **BLOCKER** when a claimed symbol is **absent or contradicted** (for example a field asserted to live on one type that the source shows living on another) and a **REVIEW** when the claim cannot be located precisely. This check fact-checks the design's assertions *about* the codebase; it SHALL NOT re-review the code's own correctness, and it SHALL make no edit. The single-change pass SHALL additionally include a **cross-review-gate-task check** whose severity follows the **authority of the scope call available to it**: the agent SHALL run the **committed mechanical scope classifier** against the change, and when the classifier resolves the change as **in scope**, the agent SHALL verify that the change's `tasks.md` tail carries the **blocking human-attestation cross-review task** with its **human-only (model-must-stop)** wording and SHALL report a **BLOCKER** when that task is **absent** or **lacks the human-only wording** — a mechanical in-scope determination carrying blocker force. When the classifier resolves the change as **out of scope**, the agent SHALL NOT flag the task's absence. When the classifier **cannot resolve** the change — as it cannot for a change whose artifacts are not yet committed, because the classifier derives scope from committed history — the agent SHALL fall back to a **semantic** in-scope judgment, report at most a **REVIEW** (never a BLOCKER, since a semantic scope call cannot carry blocker force), and **state that the classifier could not resolve the change**, so a newly-proposed change still receives the nudge rather than an unexplained silence.

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

#### Scenario: A status-surface reconcile is checked for category-keyed compliance

- **WHEN** the agent reviews a change whose tracker reconcile edits a category-keyed status-surface row or paragraph in the canonical project guide by appending change-specific narrative rather than leaving its category summary as-is (or updating it only because the category itself changed)
- **THEN** the agent reports a REVIEW (not BLOCKER) finding naming the row/paragraph and the narrative that should instead route to the history log

#### Scenario: A design's code claim is fact-checked against source

- **WHEN** the agent reviews a change whose `design.md` or `tasks.md` asserts a concrete code fact about the existing codebase (e.g. a config field is carried on a named type) that the actual source contradicts (the field lives on a different type)
- **THEN** the agent reports a BLOCKER naming the claim and the contradicting source location, and a change whose code claims match the source is not flagged

#### Scenario: A mechanically in-scope change missing the gate task is blocked

- **WHEN** the agent reviews a change that the committed mechanical scope classifier resolves as **in scope**, and the change's `tasks.md` tail lacks the blocking human-attestation cross-review task (or that task lacks the human-only, model-must-stop wording)
- **THEN** the agent reports a **BLOCKER** naming the missing task or wording — so the change cannot receive a coherent verdict — while a change carrying the task, or one the classifier resolves as out of scope, is not flagged

#### Scenario: An unresolvable scope call degrades to a REVIEW, never a silent pass

- **WHEN** the agent reviews a change whose scope the committed classifier **cannot resolve** because the change is not yet committed, and the agent's semantic judgment is that the change is in scope while its tail lacks the gate task
- **THEN** the agent reports a **REVIEW** (never a BLOCKER, since the scope call is semantic) and states that the classifier could not resolve the change — so the newly-proposed change is still nudged rather than silently passed
