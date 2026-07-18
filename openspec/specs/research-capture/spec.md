# research-capture Specification

## Purpose

Defines xtty's **research-capture** development tooling and the workflow it drives: committed Claude Code tooling (the auto-triggering `xtty-capture-research` skill + the thin `/xtty:capture-research` command) plus the documented capture-and-reconcile checklist. It covers writing settled research into `research/` (following the Provenance/Sources/✅❌❓ doc conventions; a dated addendum, not a rewrite, for an evolving decision), indexing it in `research/README.md`, reconciling the related trackers (the bounded AGENTS.md **Current status** table/snapshot + the full narrative appended to `HISTORY.md` + `research/04-design/02-milestones.md`), and — the step that catches stale trackers — **verifying the trackers against the actual repository state** (`openspec list` / `ls openspec/changes/archive/` / `ls openspec/specs/`). The tooling is version-controlled via a precise `.gitignore` exception (the committed `.claude/commands/xtty/` + `.claude/skills/xtty-*/` + `.claude/agents/xtty-*` are tracked — the agents entry added by the `test-validation` capability's tooling — while machine-local and tool-generated `.claude` files stay ignored); AGENTS.md is the source of truth for the rules and the skill defers to it. The research-*doing* method (OSS cloning, multi-agent workflows, adversarial verification) is explicitly out of scope.
## Requirements
### Requirement: Committed research-capture tooling

The repository SHALL provide **version-controlled** Claude Code tooling that guides capturing settled research into `research/` and reconciling the related trackers. The tooling SHALL include an **auto-triggering skill** (offered when a research investigation or decision settles, or a change is archived) and a **slash command** that launches it. The skill SHALL be the single source of the workflow content and SHALL **defer to the canonical project guide (AGENTS.md)** for the actual rules rather than duplicating them; the command SHALL be a thin launcher of the skill. The tooling SHALL be committed (not machine-local), so it is durable and shared across the contributor's machines.

#### Scenario: The tooling is version-controlled

- **WHEN** the repository is cloned and the committed tooling files are inspected
- **THEN** the capture-research skill and its launching command are present and tracked by git (not gitignored)

#### Scenario: The command launches the skill, not a second copy

- **WHEN** the capture-research command is invoked
- **THEN** it runs the capture-research skill (the workflow content lives in one place; the command does not restate it)

#### Scenario: The skill defers to the project guide

- **WHEN** the skill's content is read
- **THEN** it points to AGENTS.md as the source of truth for the conventions rather than copying them, so the two cannot drift

### Requirement: Track project tooling without leaking machine-local files

The version-control ignore configuration SHALL track the project's committed `.claude` tooling while continuing to **ignore** machine-local Claude files (e.g. local settings, lock files) and tool-generated Claude artifacts (the openspec-generated commands/skills). Adding the tooling SHALL NOT cause any machine-local or generated file under `.claude/` to become tracked.

#### Scenario: Committed tooling is tracked

- **WHEN** git is asked whether the committed capture-research tooling paths are ignored
- **THEN** they are not ignored (they are tracked)

#### Scenario: Machine-local and generated Claude files stay ignored

- **WHEN** git is asked whether local Claude settings/lock files and the tool-generated openspec commands/skills are ignored
- **THEN** they remain ignored after the tooling is added

### Requirement: Documented capture-and-reconcile workflow with verify-against-disk

The canonical project guide (AGENTS.md) SHALL document the capture-and-reconcile workflow as an explicit checklist: write the research into the correct `research/` location following the research-doc conventions, index it, reconcile the related trackers (the status/milestone documents and the history log), and **verify the trackers against the actual repository state** so a stale status (e.g. a change still marked pending after it was archived) is caught. AGENTS.md SHALL also state the precise tracked-tooling exception to the `.claude/` ignore policy (replacing any blanket "do not track `.claude/`" statement), so contributors and agents understand what is committed and why.

The reconcile-and-archive step at a change's **completion** SHALL be driven by an **explicit point-of-tick task** in the change's `tasks.md` carrying an archive marker (`⟶ archive-ritual`), so the signal reaches the apply loop that walks the checkboxes, rather than left implicit in an "on completion" clause. The procedure the marker names SHALL be **committed** — the project guide's archive / finish-by-hand / keep-progress-current sections and the `openspec archive` CLI — and SHALL NOT be a machine-local or tool-generated helper. A machine-local archive helper (e.g. the openspec-generated archive skill) MAY be used as an optional accelerator when present, but SHALL NOT be the anchor a committed task depends on. AGENTS.md SHALL document this **standard change tail** (a pre-archive coherence-review task followed by the marked archive + reconcile task) and, at propose time, `openspec/config.yaml` `rules.tasks` SHALL seed the archive marker while deferring to AGENTS.md for the ritual (no restatement).

The documented research-doc conventions SHALL include a **capture-depth bar, scaled to the finding**: any capture that records **measured claims or retired theories** SHALL settle the *mechanism* (not just the conclusion), make its measured claims **reproducible** (the probes/commands used, including what each can and cannot prove and instruments that did not work), record each **retired theory alongside the evidence that refuted it**, and state how to **re-verify the headline claim by its effect** (never by a syntax or read-back check). When a finding generalizes to a class of future problems, the capture SHALL distill the method as a reusable guideline. Lightweight captures (e.g. a tooling landscape or comparison with no measurements) are NOT required to carry these elements.

The tracker-reconcile step SHALL keep the always-loaded canonical guide **lean**: the guide's status surface is a bounded orientation layer — a current-state snapshot, a tabular per-change entry (state, one-line summary, pointer to detail), and inline one-line statements of **learned refutations** (decisions expensively settled in the negative, stated with their conclusion so they cannot be silently re-proposed) — while the **full per-change narrative** is recorded in a dedicated history log that is **not loaded at session start**. Reconciling a completed change SHALL NOT grow the guide's status surface beyond a bounded entry; narrative content moves to the history log with nothing lost. For a status-surface row or paragraph that has no closing event of its own (an ongoing category of work with no terminal milestone, unlike a closed phase or an archived single change), "bounded entry" SHALL mean **category-keyed**: the entry is edited only when a genuinely new category is introduced, never appended to on every individual change within an already-represented category. A perpetual row that grows on each qualifying change — even while remaining nominally "one row" — violates this bound.

#### Scenario: The workflow checklist is documented

- **WHEN** a contributor or agent reads the project guide for how to capture research and keep trackers current
- **THEN** it describes writing + indexing the research doc, reconciling the trackers, and a verify-against-disk step that compares the trackers to the real repository state

#### Scenario: The tracking convention reflects reality

- **WHEN** the project guide's `.claude/` tracking convention is read
- **THEN** it states that machine-local Claude files are ignored **except** the committed project tooling, rather than a blanket claim that all of `.claude/` is ignored

#### Scenario: A change's completion is driven by a marked archive task

- **WHEN** a change's `tasks.md` is authored (at propose) or walked (at apply) for how the change is completed
- **THEN** it contains an explicit archive + reconcile task carrying the `⟶ archive-ritual` marker, so the apply loop that walks the checkboxes is signalled to run the full ritual rather than leaving archive implicit
- **AND** the standard change tail places that task after a pre-archive coherence-review task

#### Scenario: The archive marker's procedure anchor is committed

- **WHEN** the procedure named by the `⟶ archive-ritual` marker is resolved
- **THEN** it points to committed guidance (the project guide's archive / finish-by-hand / keep-progress-current sections and the `openspec archive` CLI), not a gitignored or tool-generated helper
- **AND** any machine-local archive helper is optional (used only when present) and is never the anchor a committed task depends on

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

#### Scenario: A perpetual row stays bounded by category, not by change

- **WHEN** a change within an already-represented category of an ongoing (non-closing) status-surface row completes and its tracker reconcile runs
- **THEN** the reconcile step leaves that row's existing category summary unchanged (or updates it only if the category itself changed), routes the change's own narrative to the history log, and does not append a new per-change clause to the row

### Requirement: The guide's leanness bound has a mechanical backstop and a refusal protocol

The tracker-reconcile step's leanness bound on the always-loaded canonical guide SHALL be backed by a **mechanical gate at the publication boundary**, not by advisory instruction alone. Advisory statements of the bound — in specs, in point-of-action skill text, and in review agents — SHALL remain, but the project SHALL NOT rely on them as the enforcement mechanism: all three predated two full regrowths of the guide and were overridden by *instructed* writing each time.

When an append to the always-loaded guide is refused by that gate, the reconcile step SHALL **park** the finding: the content is committed to its named, tracked, lazily-loaded destination (the history log or a research capture), and the guide retains only a bounded pointer to it. A refused append SHALL NOT be discarded, and SHALL NOT be worked around by relocating the content to another eagerly-loaded surface.

#### Scenario: A reconcile that would breach the bound is refused, not merely discouraged

- **WHEN** a tracker reconcile grows the always-loaded guide past its ceiling and the result is pushed
- **THEN** the push is refused by the mechanical gate, independently of whether any advisory surface flagged it

#### Scenario: The refused finding survives

- **WHEN** an append to the always-loaded guide is refused
- **THEN** the finding is recorded on its lazily-loaded destination and the guide keeps a bounded pointer, so nothing is lost from the repository

#### Scenario: Growth is not displaced onto another eager surface

- **WHEN** content refused from the canonical guide is instead placed in another surface that is also loaded at session start
- **THEN** the push is still refused, because the gate meters the whole eagerly-injected surface rather than a single file

