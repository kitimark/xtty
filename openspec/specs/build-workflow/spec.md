# build-workflow Specification

## Purpose

The build/setup contract for xtty — how a contributor goes from a fresh clone to a running, tested app. It defines: reproducible reconstruction of the patched-but-pinned SwiftTerm dependency from version-controlled inputs alone (a pinned ref + a tracked patch, without committing the upstream tree); generation of the **untracked** Xcode project from the tracked `project.yml`; single-command build/run/test entry points that perform any prerequisite reconstitution and generation automatically (plus a fast view-free `XttyCore` test path); a prerequisite check for the components that can't be auto-installed; self-documenting entry points; and the requirement that the canonical build docs stay accurate (no superseded mechanism described as current). This is a **meta/tooling** capability — it constrains the developer workflow and its documentation, not app runtime behavior — recorded as a source of truth so the build contract (previously only drift-prone prose) has something authoritative to fail against. Parallels the `verification-harness` spec. The concrete entry point is the top-level `Makefile`.

## Requirements
### Requirement: Reproducible patched-SwiftTerm reconstitution

The build SHALL reconstitute the patched SwiftTerm dependency from version-controlled inputs alone — a pinned upstream ref plus a tracked patch — without committing the upstream source tree. Reconstitution SHALL be idempotent and SHALL enforce the pin on every run so the working checkout cannot drift. When the pin and the patch are unchanged since the last reconstitution, a subsequent build SHALL NOT need to re-run reconstitution.

#### Scenario: Fresh checkout reconstitutes before compiling
- **WHEN** the build entry point runs on a fresh clone where the upstream SwiftTerm tree is absent
- **THEN** it reconstitutes the tree from the pinned ref and the tracked patch before compiling, with no manual steps beyond the documented entry point

#### Scenario: Reconstitution is idempotent and pin-enforcing
- **WHEN** reconstitution runs again over an existing checkout
- **THEN** it restores a pristine tree at the pinned ref and re-applies the patch without error (no drift and no duplicate/failed patch application)

#### Scenario: Reconstitution is skipped when inputs are unchanged
- **WHEN** the pin and the patch have not changed since the last successful reconstitution
- **THEN** a subsequent build does not re-run reconstitution

### Requirement: Generated Xcode project from a tracked source of truth

The Xcode project SHALL be generated from the tracked project definition (`project.yml`) and SHALL NOT itself be tracked in version control. A build SHALL regenerate the project when the project definition has changed (or the generated project is absent) and SHALL NOT require the developer to regenerate it manually in that case.

#### Scenario: Project is regenerated when its definition changes
- **WHEN** the tracked project definition is newer than the generated project, or the generated project is missing
- **THEN** the build regenerates the project before compiling

#### Scenario: Generated project is never committed
- **WHEN** version control status is inspected
- **THEN** the generated `.xcodeproj` is ignored and not tracked

### Requirement: Single-command build, test, and run entry points

The project SHALL provide a single documented command each to build the app, run the app, run the fast view-free `XttyCore` unit tests, and run the app UI tests. Each entry point SHALL automatically perform any prerequisite reconstitution and project generation. The fast core-test path SHALL be runnable without building the full app target.

#### Scenario: One command builds the app
- **WHEN** a developer runs the build entry point on a machine with prerequisites satisfied
- **THEN** the app builds without the developer invoking reconstitution or project generation separately

#### Scenario: Fast core tests run without the app
- **WHEN** a developer runs the core-test entry point
- **THEN** the `XttyCore` unit tests run without building the app target

#### Scenario: Run builds then launches
- **WHEN** a developer runs the run entry point
- **THEN** the app is built (reconstituting/generating as needed) and then launched

### Requirement: Prerequisite check

The project SHALL provide a command that verifies the prerequisites it cannot install automatically — the project generator, a full Xcode toolchain, and the Metal toolchain — and reports clearly which are missing along with how to install each, without attempting privileged installation itself.

#### Scenario: Missing prerequisite is reported
- **WHEN** a required prerequisite is not present
- **THEN** the check names the missing prerequisite and the command to install it, and exits non-zero

#### Scenario: Check passes when prerequisites are present
- **WHEN** all prerequisites are present
- **THEN** the check reports success and exits zero, without attempting any privileged install

### Requirement: Self-documenting entry points

Invoking the entry point with no target (or an explicit help target) SHALL list the available commands with a one-line description for each, so the workflow is discoverable without reading external documentation.

#### Scenario: Help lists the available targets
- **WHEN** the developer invokes the entry point with no target
- **THEN** it prints the available targets each with a short description of what it does

### Requirement: Build/setup documentation is accurate and current

The canonical build/setup documentation SHALL describe the *current* mechanism accurately and SHALL NOT present a superseded mechanism as current. On every surface that states how things work now, the SwiftTerm dependency SHALL be described as a gitignored upstream clone reconstituted from a pinned ref with an applied tracked patch — and no superseded form (a git submodule, a `cp` drop-in copy, or a removed patch file) SHALL be named as the current mechanism. The single-command entry points SHALL be documented as the primary path, with the underlying raw commands retained for reference.

#### Scenario: Current-truth surfaces name only the current mechanism
- **WHEN** any "how it works now" surface (build scripts and their headers, the project/package manifests, and the canonical build docs) describes how the SwiftTerm dependency is consumed
- **THEN** it describes the current mechanism and names no superseded form (submodule, drop-in copy, or a deleted patch file) as current

#### Scenario: Single-command path is the documented primary
- **WHEN** a contributor reads the canonical build documentation
- **THEN** the single-command entry points are presented as the primary path and the underlying raw commands remain documented for reference

