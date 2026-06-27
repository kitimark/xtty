# app-shell Specification

## Purpose

Defines the foundational native macOS application shell for xtty: how the app launches and presents its window, its signing/sandboxing posture, the engine-facing core seam (`XttyCore`), the availability of the SwiftTerm dependency, and reproducible Xcode project generation. This establishes the P0 skeleton that later milestones build upon.
## Requirements
### Requirement: Native application window
The application SHALL launch as a native macOS app and present a single window on startup that hosts a live terminal session.

#### Scenario: App launches showing a terminal
- **WHEN** the user launches the built app
- **THEN** a native macOS window appears
- **AND** the window hosts a terminal session running the user's shell (see the `terminal-session` capability)

### Requirement: Non-sandboxed signing posture
The application SHALL be configured with App Sandbox disabled so that later milestones can spawn an arbitrary shell and access the user's filesystem.

#### Scenario: Sandbox is not enabled
- **WHEN** the built app's entitlements are inspected
- **THEN** the `com.apple.security.app-sandbox` entitlement is absent or set to false

#### Scenario: Local development signing
- **WHEN** the app is built for local development
- **THEN** it is signed to run locally without requiring notarization (notarization is deferred to a later milestone)

### Requirement: Engine-facing core seam
Core logic SHALL reside in a dedicated `XttyCore` module, decoupled from any terminal view, so that the rendering layer remains swappable.

#### Scenario: Core module exists and is independent of UI
- **WHEN** the project is built
- **THEN** an `XttyCore` package target exists
- **AND** `XttyCore` does not import the app/UI target or a concrete terminal view

#### Scenario: Core is independently testable
- **WHEN** the test suite runs
- **THEN** at least one `XttyCore` test executes without launching the app

### Requirement: SwiftTerm dependency available
The project SHALL declare SwiftTerm as a dependency that resolves and builds, and SHALL host SwiftTerm's terminal view in the application window.

#### Scenario: Dependency resolves
- **WHEN** the project is generated and built
- **THEN** the SwiftTerm package resolves and compiles

#### Scenario: SwiftTerm view is hosted in the window
- **WHEN** the app launches
- **THEN** SwiftTerm's terminal view is presented in the window via an AppKit window (`NSWindow`)
- **AND** xtty logic accesses the underlying `Terminal` engine only through `XttyCore` (the engine-facing seam)

### Requirement: Reproducible project generation
The Xcode project SHALL be produced from a committed XcodeGen specification, and the generated `.xcodeproj` SHALL NOT be tracked in version control.

#### Scenario: Project is generated from spec
- **WHEN** a contributor runs the project generator on a fresh checkout
- **THEN** a working `xtty.xcodeproj` is produced from the committed `project.yml`

#### Scenario: Generated project is ignored by git
- **WHEN** the repository status is checked after generating the project
- **THEN** `xtty.xcodeproj` is not listed as a tracked or untracked file (it is gitignored)

