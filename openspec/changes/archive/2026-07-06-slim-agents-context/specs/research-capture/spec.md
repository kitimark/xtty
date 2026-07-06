# research-capture — spec delta (slim-agents-context)

## MODIFIED Requirements

### Requirement: Documented capture-and-reconcile workflow with verify-against-disk

The canonical project guide (AGENTS.md) SHALL document the capture-and-reconcile workflow as an explicit checklist: write the research into the correct `research/` location following the research-doc conventions, index it, reconcile the related trackers (the status/milestone documents and the history log), and **verify the trackers against the actual repository state** so a stale status (e.g. a change still marked pending after it was archived) is caught. AGENTS.md SHALL also state the precise tracked-tooling exception to the `.claude/` ignore policy (replacing any blanket "do not track `.claude/`" statement), so contributors and agents understand what is committed and why.

The documented research-doc conventions SHALL include a **capture-depth bar, scaled to the finding**: any capture that records **measured claims or retired theories** SHALL settle the *mechanism* (not just the conclusion), make its measured claims **reproducible** (the probes/commands used, including what each can and cannot prove and instruments that did not work), record each **retired theory alongside the evidence that refuted it**, and state how to **re-verify the headline claim by its effect** (never by a syntax or read-back check). When a finding generalizes to a class of future problems, the capture SHALL distill the method as a reusable guideline. Lightweight captures (e.g. a tooling landscape or comparison with no measurements) are NOT required to carry these elements.

The tracker-reconcile step SHALL keep the always-loaded canonical guide **lean**: the guide's status surface is a bounded orientation layer — a current-state snapshot, a tabular per-change entry (state, one-line summary, pointer to detail), and inline one-line statements of **learned refutations** (decisions expensively settled in the negative, stated with their conclusion so they cannot be silently re-proposed) — while the **full per-change narrative** is recorded in a dedicated history log that is **not loaded at session start**. Reconciling a completed change SHALL NOT grow the guide's status surface beyond a bounded entry; narrative content moves to the history log with nothing lost.

#### Scenario: The workflow checklist is documented

- **WHEN** a contributor or agent reads the project guide for how to capture research and keep trackers current
- **THEN** it describes writing + indexing the research doc, reconciling the trackers, and a verify-against-disk step that compares the trackers to the real repository state

#### Scenario: The tracking convention reflects reality

- **WHEN** the project guide's `.claude/` tracking convention is read
- **THEN** it states that machine-local Claude files are ignored **except** the committed project tooling, rather than a blanket claim that all of `.claude/` is ignored

#### Scenario: Measured findings are captured reproducibly

- **WHEN** a capture records an investigation that measured something or retired a theory
- **THEN** the documented conventions require it to include the mechanism, the reproduction/verification probes (with their limits and dead ends), each retired theory with its refuting evidence, and an effect-based re-verification of the headline claim
- **AND** a capture with no measured claims is not required to carry those elements

#### Scenario: Status stays lean while history is preserved

- **WHEN** a change completes and the trackers are reconciled
- **THEN** the canonical guide's status update is a bounded entry (snapshot/table row with a detail pointer, plus an inline refutation line only when the change settled one), the full narrative is appended to the history log, and no narrative content is lost from the repository

#### Scenario: Learned refutations survive the slimming

- **WHEN** the canonical guide's status surface is read after history has been moved to the history log
- **THEN** the expensively-learned refutations remain stated inline with their conclusions (not as bare pointers), so a session that never opens the history log still cannot re-propose them
