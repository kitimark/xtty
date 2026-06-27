## MODIFIED Requirements

### Requirement: Native application window
The application SHALL launch as a native macOS app and present a single window on startup that hosts a live terminal session, and SHALL support opening additional top-level windows and native macOS tabs after launch (each hosting its own live terminal session).

#### Scenario: App launches showing a terminal
- **WHEN** the user launches the built app
- **THEN** a native macOS window appears
- **AND** the window hosts a terminal session running the user's shell (see the `terminal-session` capability)

#### Scenario: Additional windows and tabs can be opened
- **WHEN** the user opens a new window or a new tab after launch
- **THEN** a new native window — or a native macOS tab grouped by window tabbing — appears hosting its own live terminal session
- **AND** the additional sessions are independent of one another (see the `terminal-multiplexing` capability)
