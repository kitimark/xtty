# research-orchestration Specification

## Purpose

Committed, version-controlled Claude Code tooling for the **doing** phase of the project's source-research — the multi-agent fan-out that clones external source, reads its build/internals machinery, compares across sources, adversarially critiques, and verifies by effect. It is the counterpart of `research-capture` (the **write-up** phase, which scopes the research-doing method out): the two compose as research-orchestration → research-capture. The launcher (`/xtty:research`, `.claude/commands/xtty/research.md`) is a **thin recipe** whose worker is a **per-invocation multi-agent Workflow** (not a standing agent, so no definition-delivery lag), documenting the role→model tiering and staged pattern while deferring to AGENTS.md as the single source of truth for the delegation boundary.

## Requirements
### Requirement: Committed source-research launcher tooling

The repository SHALL provide **version-controlled** Claude Code tooling that launches the project's source-research fan-out (the *doing* phase of research — cloning external source, reading it, comparing across sources, and verifying), complementing the `research-capture` tooling (the *write-up* phase). The tooling SHALL be a **thin launcher** that **defers to the canonical project guide (AGENTS.md)** for the delegation boundary and the rules rather than duplicating them. Its worker SHALL be a **multi-agent Workflow** (a fan-out orchestrated per invocation), **not a standing committed agent** — so there is no agent-definition to keep in sync and no per-spawn definition-delivery lag to verify. The tooling SHALL be committed (not machine-local), so it is durable and shared across the contributor's machines.

#### Scenario: The launcher is version-controlled

- **WHEN** the repository is cloned and the committed tooling is inspected
- **THEN** the source-research launcher command is present and tracked by git (not gitignored)

#### Scenario: The launcher defers to AGENTS.md and drives a Workflow, not a standing agent

- **WHEN** the launcher is invoked
- **THEN** it delegates the fan-out to a per-invocation Workflow and relies on AGENTS.md for the delegation boundary and rules, without introducing a new committed agent definition

### Requirement: Documented role-to-model tiering for the research fan-out

The launcher SHALL document a **role → model tiering by cognitive load** for the research fan-out, so each stage runs on a model suited to its work rather than all stages defaulting to one tier. The **source readers** (parallel clone/read/extract) SHALL be assigned a mid capability tier (search/extract), the **synthesis** and **adversarial critique** stages SHALL be assigned the most-capable authoring/judging tier, and any optional **mechanical scout** (enumerating sources) SHALL be assigned the cheapest tier. The main-loop **orchestrator** stage SHALL remain in the session (never delegated). The tiering SHALL be consistent with the project's existing committed agents (its run/classify agents at the mid tier, its authoring/coherence agent at the top tier).

#### Scenario: Each stage names a model tier suited to its cognitive load

- **WHEN** the launcher recipe is read
- **THEN** it assigns the readers a mid (search/extract) tier, the synthesis and critique the top (authoring/judging) tier, any scout the cheapest tier, and keeps orchestration in the main session

### Requirement: Source-research delegation boundary

The launcher SHALL define, deferring to AGENTS.md, **when a research task is delegated to the fan-out versus kept inline**. Source-heavy, multi-source research whose own noise (external clones, many-file reads, cross-source comparison) exceeds the subagent context-inheritance floor SHALL be delegated; light work — reading existing `research/` docs or a single-file lookup — SHALL stay inline in the main loop or a fork. The boundary SHALL live in AGENTS.md as the single source of truth, with the launcher pointing to it.

#### Scenario: Heavy multi-source research is delegated; light reads stay inline

- **WHEN** a research task is source-heavy and spans multiple external sources
- **THEN** the boundary directs it to a `/xtty:research`-launched fan-out
- **WHEN** a research task is a single-file lookup or a read of existing repository docs
- **THEN** the boundary keeps it inline (main loop or fork), not delegated

### Requirement: The fan-out includes adversarial critique, verify-by-effect, and a capture hand-off

The launcher's documented pattern SHALL include, after the parallel readers and the synthesis, an **adversarial critic** stage that refutes claims and flags unverified assertions, and a **verify-by-effect** step that closes the critic's load-bearing unknowns by running real probes (never a read-back), defaulting to the main loop and escalating to a delegated verify stage only when the probes are many or isolated. On conclusion the pattern SHALL **hand off to the existing research-capture tooling** for writing the result into `research/` and reconciling the trackers, rather than duplicating that tail.

#### Scenario: The pattern critiques, verifies by effect, then hands off to capture

- **WHEN** a source-research fan-out completes its readers and synthesis
- **THEN** an adversarial critic stage reviews the synthesis and names the load-bearing unknowns, those unknowns are closed by running real probes (verify-by-effect), and the settled result is handed to the research-capture tooling for write-up and tracker reconciliation

