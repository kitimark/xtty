## ADDED Requirements

### Requirement: Design-tool linkage entry point

The project SHALL provide a single documented command that registers the committed design-system package with the installed design tool, so a contributor can reach a working design-drafting setup without hand-running API calls or hand-creating filesystem links. The registration SHALL be by **reference**, not by copy, so the version-controlled package and the tool's copy cannot diverge.

The command SHALL be **idempotent** — re-running it against an already-registered package SHALL succeed and change nothing. It SHALL detect a registration that has become stale (for example, one pointing at a path that no longer resolves after the checkout moved) and repair it rather than reporting success.

The command SHALL require the design tool to already be running and SHALL NOT launch it. When the tool is not running the command SHALL fail with a message that says so plainly, distinguishing that case from a genuine registration failure.

The command SHALL verify its own result against the filesystem and the tool's own catalogue rather than trusting the response of the call it made, and SHALL report what remains for a human to do that cannot be automated. It SHALL also report whether the committed design base binds every token name the design tool's schema requires, reporting any shortfall as a warning that names the missing tokens.

#### Scenario: First registration succeeds and is verified independently

- **WHEN** the developer invokes the design-linkage command with the design tool running and the package not yet registered
- **THEN** the package is registered by reference to the version-controlled directory
- **AND** the command confirms the registration from the filesystem and the tool's catalogue, not from the response of its own call
- **AND** it reports what remains for a human: any step it could not complete automatically, and the closing verification by effect

#### Scenario: Re-running changes nothing

- **WHEN** the developer invokes the design-linkage command against an already-registered, healthy package
- **THEN** the command succeeds and reports the existing registration
- **AND** no filesystem or tool state is altered

#### Scenario: A stale registration is repaired, not reported as healthy

- **WHEN** the command runs while an existing registration points at a path that no longer resolves
- **THEN** the command repairs the registration rather than reporting success

#### Scenario: The design tool is not running

- **WHEN** the developer invokes the design-linkage command while the design tool is not running
- **THEN** the command fails with a message identifying that the tool is not running
- **AND** it does not attempt to launch the tool

#### Scenario: The design base is verified for completeness at link time

- **WHEN** the design-linkage command runs
- **THEN** it reports whether the committed design base binds every token the design tool's schema requires
- **AND** a shortfall is reported as a warning naming the missing tokens

### Requirement: Scripted project creation deduplicates, verifies by effect, and falls back to manual instructions

The design-linkage entry point SHALL create the design tool's mockups project when none exists, using the design tool's own first-party command-line interface — it SHALL NOT hand-mint authentication tokens, read secrets from process state, or bypass the tool's import gate; when the scripted route is unavailable the fallback is printed manual instructions, never a workaround of the gate. Before creating, the command SHALL resolve existing projects by the canonical (symlink-resolved) path of their base directory — never by name — and SHALL treat an existing match as the project, reporting it instead of creating a duplicate, because the design tool itself enforces no uniqueness on project names or base directories.

The command SHALL verify creation by effect: re-reading the project from the tool and confirming a folder-backed project at the canonical path of the committed project folder, and confirming the import wrote nothing into the repository. It SHALL NOT treat the creating call's exit status as evidence. In the same invocation it SHALL configure the project's design system and platform through the tool's update route, each setting verified by re-read.

#### Scenario: An existing project is reported, not duplicated

- **WHEN** the design-linkage command runs while a project already points at the committed project folder
- **THEN** the command reports that project and creates nothing
- **AND** re-running the command remains a no-op

#### Scenario: Creation is verified by effect

- **WHEN** the command creates the project via the design tool's own CLI
- **THEN** it re-reads the project from the tool and confirms a folder-backed project at the canonical path of the committed project folder
- **AND** it confirms the import wrote zero bytes into the repository
- **AND** the creating call's exit status is not treated as evidence

#### Scenario: A created project is configured in the same invocation

- **WHEN** the command creates the mockups project
- **THEN** the same invocation sets the project's design system and platform
- **AND** each setting is verified by re-reading it from the tool

#### Scenario: Multiple projects at the same folder stop the command

- **WHEN** the command finds more than one project pointing at the committed project folder
- **THEN** it refuses to create or configure anything and reports each duplicate, deferring deletion to a human

#### Scenario: Failure falls back to manual instructions

- **WHEN** scripted creation cannot proceed for any reason
- **THEN** the command prints the manual GUI import instructions as the documented fallback
- **AND** the design-system registration outcome is unaffected

### Requirement: Read-only design-linkage status reporting

The project SHALL provide a documented command that reports the current design-tool linkage without modifying any state, so a contributor can diagnose the setup safely. Its result SHALL be distinguishable between at least: linked and usable, not linked, and unable to determine because the design tool is not running. Invoking it in an ordinary not-yet-linked state SHALL NOT present as a build failure.

#### Scenario: Status distinguishes not-linked from cannot-determine

- **WHEN** the developer invokes the status command while the design tool is not running
- **THEN** the result is reported as indeterminate rather than as "not linked"

#### Scenario: Status modifies nothing

- **WHEN** the developer invokes the status command in any state
- **THEN** no filesystem, tool, or repository state is altered

#### Scenario: An unlinked repository is not reported as an error

- **WHEN** the developer invokes the status command through the project's entry point in a repository that has never been linked
- **THEN** the output reports the unlinked state without presenting it as a build failure

### Requirement: Design-tool teardown avoids the tool's own delete path

The project SHALL provide a documented command that removes the design-tool registration. Because the registration is a reference into the version-controlled tree, teardown SHALL remove that reference directly and SHALL NOT invoke the design tool's own delete operation, whose behavior on a referenced directory is unverified and whose failure mode would reach the working tree.

Teardown SHALL leave the version-controlled package untouched.

#### Scenario: Teardown removes only the reference

- **WHEN** the developer invokes the teardown command against a registered package
- **THEN** the reference is removed directly
- **AND** the version-controlled package directory is unmodified
- **AND** the design tool's own delete operation is not invoked
