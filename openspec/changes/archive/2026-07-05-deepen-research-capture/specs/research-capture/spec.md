## MODIFIED Requirements

### Requirement: Documented capture-and-reconcile workflow with verify-against-disk

The canonical project guide (AGENTS.md) SHALL document the capture-and-reconcile workflow as an explicit checklist: write the research into the correct `research/` location following the research-doc conventions, index it, reconcile the related trackers (the status/milestone documents), and **verify the trackers against the actual repository state** so a stale status (e.g. a change still marked pending after it was archived) is caught. AGENTS.md SHALL also state the precise tracked-tooling exception to the `.claude/` ignore policy (replacing any blanket "do not track `.claude/`" statement), so contributors and agents understand what is committed and why.

The documented research-doc conventions SHALL include a **capture-depth bar, scaled to the finding**: any capture that records **measured claims or retired theories** SHALL settle the *mechanism* (not just the conclusion), make its measured claims **reproducible** (the probes/commands used, including what each can and cannot prove and instruments that did not work), record each **retired theory alongside the evidence that refuted it**, and state how to **re-verify the headline claim by its effect** (never by a syntax or read-back check). When a finding generalizes to a class of future problems, the capture SHALL distill the method as a reusable guideline. Lightweight captures (e.g. a tooling landscape or comparison with no measurements) are NOT required to carry these elements.

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
