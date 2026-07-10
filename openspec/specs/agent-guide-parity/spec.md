# agent-guide-parity Specification

## Purpose

Defines xtty's contract for keeping the project's AI-agent/contributor guidance single-sourced: exactly one canonical, tool-agnostic guide (`AGENTS.md`) with no independently-maintained copies. Tool-specific entry points that other tooling expects at a fixed path — currently just Claude Code's `CLAUDE.md` — are structurally guaranteed identical to the canonical guide (a symlink), not kept in sync by import-plus-review-discipline. This is a **meta/tooling** capability — it constrains the repository's own documentation, not app runtime behavior — parallel to `build-workflow`'s and `research-capture`'s framing.
## Requirements
### Requirement: Single canonical AI-agent guide

The project SHALL maintain exactly one canonical, tool-agnostic guide for AI-agent and contributor guidance (`AGENTS.md`). Tool-specific entry points that other tooling expects at a fixed path (e.g. Claude Code's `CLAUDE.md`) SHALL carry no independently-editable content of their own — they SHALL be a symlink to the canonical guide (or an equivalent construct that makes divergence structurally impossible), never a separate file kept in sync by convention or review discipline.

#### Scenario: Claude Code's entry point resolves to the canonical guide

- **WHEN** a contributor or tool reads `CLAUDE.md` at the repository root
- **THEN** its content is byte-identical to `AGENTS.md`, verified by `readlink CLAUDE.md` resolving to `AGENTS.md`

#### Scenario: The entry point is tracked as a symlink, not a duplicated file

- **WHEN** the repository is freshly cloned and `git ls-files -s CLAUDE.md` is inspected
- **THEN** `CLAUDE.md` is tracked with symlink mode `120000`, not as a regular `100644` file

