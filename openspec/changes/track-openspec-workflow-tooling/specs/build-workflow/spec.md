## ADDED Requirements

### Requirement: Tracked, version-pinned OpenSpec workflow tooling

The generated OpenSpec workflow tooling that the spec-driven workflow depends on — the `opsx` command launchers and the `openspec-*` skills the CLI writes into the agent-tooling directory — SHALL be tracked in version control, so a fresh clone has the workflow available without a generation step. This is the deliberate counterpart to the *untracked* generated Xcode project: unlike that project (regenerated on every build from a tracked in-repo source of truth, and never needed present for the workflow itself), the workflow tooling has no in-repo source of truth, is regenerated only by an explicit CLI step, and must be physically present for the agent to surface the workflow at all.

The tracked tooling SHALL be **pinned to a recorded generator version** (the version stamp the generator writes into the files), and updating it SHALL be a **deliberate, reviewable act**: regenerating the tooling (only via the explicit CLI generation/update step) and committing the result on a generator-version bump, rather than an incidental or automatic rewrite. Machine-local agent files that are not workflow tooling — local settings and runtime lock files — SHALL remain untracked.

#### Scenario: Fresh clone has the workflow tooling present

- **WHEN** version control status is inspected on a fresh clone
- **THEN** the `opsx` command launchers and the `openspec-*` skills are tracked and present, so the spec-driven workflow is available without running any generator step first

#### Scenario: Machine-local agent files stay untracked

- **WHEN** version control status is inspected
- **THEN** the agent tooling's machine-local files (local settings and runtime lock files) remain ignored and untracked, while the workflow tooling is tracked

#### Scenario: Routine workflow use does not rewrite the tooling

- **WHEN** the routine spec-driven workflow commands run (listing, validating, and checking status of changes and specs)
- **THEN** the tracked workflow tooling files are left byte-identical, so they change only on a deliberate generator regeneration/update

#### Scenario: A generator bump is a reviewable re-commit

- **WHEN** the generator is upgraded and the workflow tooling is regenerated via its explicit generation/update step
- **THEN** the regenerated tooling is committed deliberately as a reviewable change (its recorded generator version stamp updated), rather than drifting silently under the workflow
