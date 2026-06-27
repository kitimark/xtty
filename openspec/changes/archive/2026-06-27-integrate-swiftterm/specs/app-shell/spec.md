## MODIFIED Requirements

### Requirement: Native application window
The application SHALL launch as a native macOS app and present a single window on startup that hosts a live terminal session.

#### Scenario: App launches showing a terminal
- **WHEN** the user launches the built app
- **THEN** a native macOS window appears
- **AND** the window hosts a terminal session running the user's shell (see the `terminal-session` capability)

### Requirement: SwiftTerm dependency available
The project SHALL declare SwiftTerm as a dependency that resolves and builds, and SHALL host SwiftTerm's terminal view in the application window.

#### Scenario: Dependency resolves
- **WHEN** the project is generated and built
- **THEN** the SwiftTerm package resolves and compiles

#### Scenario: SwiftTerm view is hosted in the window
- **WHEN** the app launches
- **THEN** SwiftTerm's terminal view is presented in the window via an AppKit window (`NSWindow`)
- **AND** xtty logic accesses the underlying `Terminal` engine only through `XttyCore` (the engine-facing seam)
