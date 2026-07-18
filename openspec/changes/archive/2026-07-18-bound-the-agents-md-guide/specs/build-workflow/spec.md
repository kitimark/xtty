## ADDED Requirements

### Requirement: The clone arms its own repository hooks

The project SHALL provide a documented entry point that installs the repository's tracked git hooks into the clone. Because repository hook configuration is **not cloned**, no committed file can make a fresh clone self-arm; the install SHALL therefore be reachable from **routine** developer commands, not from first-time setup alone — a hook armed only at setup leaves every **already-bootstrapped** clone, including the maintainer's own, permanently unarmed.

The install entry point SHALL be an **unconditional, order-only, cannot-fail** prerequisite of the routine build, test, and run entry points: it SHALL run on every routine invocation, SHALL NOT cause the build to be considered out of date, and SHALL NOT be able to fail the build.

The tracked hook source SHALL be the reviewable source of truth, and the installed copy SHALL be placed **outside the working tree**, so that checking out a revision predating the hook cannot disarm it. The installer SHALL refuse to write into a hooks directory the project does not own, and SHALL NOT overwrite a pre-existing foreign hook.

#### Scenario: A routine build arms an already-bootstrapped clone

- **WHEN** a developer with an existing, fully bootstrapped clone pulls the change and runs any routine build or test entry point
- **THEN** the repository's hooks are installed, without a re-bootstrap and without the developer invoking the install step explicitly

#### Scenario: The install cannot fail the build

- **WHEN** the hook install cannot complete (for example, outside a repository)
- **THEN** the entry point that depends on it still succeeds

#### Scenario: Checking out a revision that predates the hook does not disarm it

- **WHEN** a developer checks out a branch or commit whose tree does not contain the tracked hook source, and then pushes
- **THEN** the hook still runs

#### Scenario: A foreign hooks configuration is not hijacked

- **WHEN** the clone is configured to read hooks from a directory the project does not own, or already has a hook of its own at the install path
- **THEN** the installer declines to write, reports why, and states how to arm the gate manually

### Requirement: Continuous integration verifies the hook installer

The CI pipeline SHALL verify that the install entry point produces an installed hook that is **byte-identical** to the tracked source. This check SHALL be documented for what it is — an **installer regression test over CI's own clone** — and SHALL NOT be described as a detector of unarmed developer clones, which it cannot be.

#### Scenario: A drifted or broken installer fails CI

- **WHEN** the installer no longer reproduces the tracked hook source exactly
- **THEN** CI fails

#### Scenario: The check's scope is stated honestly

- **WHEN** the CI check is documented
- **THEN** it is described as verifying the installer, not as detecting unarmed developer clones
