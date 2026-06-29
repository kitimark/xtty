# research-capture Specification

## Purpose

Defines xtty's **research-capture** development tooling and the workflow it drives: committed Claude Code tooling (the auto-triggering `xtty-capture-research` skill + the thin `/xtty:capture-research` command) plus the documented capture-and-reconcile checklist. It covers writing settled research into `research/` (following the Provenance/Sources/✅❌❓ doc conventions; a dated addendum, not a rewrite, for an evolving decision), indexing it in `research/README.md`, reconciling the related trackers (AGENTS.md **Current status** + `research/04-design/02-milestones.md`), and — the step that catches stale trackers — **verifying the trackers against the actual repository state** (`openspec list` / `ls openspec/changes/archive/` / `ls openspec/specs/`). The tooling is version-controlled via a precise `.gitignore` exception (the committed `.claude/commands/xtty/` + `.claude/skills/xtty-*/` are tracked while machine-local and tool-generated `.claude` files stay ignored); AGENTS.md is the source of truth for the rules and the skill defers to it. The research-*doing* method (OSS cloning, multi-agent workflows, adversarial verification) is explicitly out of scope.
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

The canonical project guide (AGENTS.md) SHALL document the capture-and-reconcile workflow as an explicit checklist: write the research into the correct `research/` location following the research-doc conventions, index it, reconcile the related trackers (the status/milestone documents), and **verify the trackers against the actual repository state** so a stale status (e.g. a change still marked pending after it was archived) is caught. AGENTS.md SHALL also state the precise tracked-tooling exception to the `.claude/` ignore policy (replacing any blanket "do not track `.claude/`" statement), so contributors and agents understand what is committed and why.

#### Scenario: The workflow checklist is documented

- **WHEN** a contributor or agent reads the project guide for how to capture research and keep trackers current
- **THEN** it describes writing + indexing the research doc, reconciling the trackers, and a verify-against-disk step that compares the trackers to the real repository state

#### Scenario: The tracking convention reflects reality

- **WHEN** the project guide's `.claude/` tracking convention is read
- **THEN** it states that machine-local Claude files are ignored **except** the committed project tooling, rather than a blanket claim that all of `.claude/` is ignored

