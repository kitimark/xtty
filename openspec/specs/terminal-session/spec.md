# terminal-session Specification

## Purpose

Defines xtty's live terminal session: launching the user's login shell over a PTY (so existing dotfiles and PATH are in effect), view-free shell resolution and launch configuration in `XttyCore`, the core interactive behaviors (keyboard input, resize/reflow, bracketed-paste, scrollback, selection — without display corruption), the shell process lifecycle (spawned exactly once, keyboard focus, no orphaned processes), the shell-exit policy, and the rule that all engine access flows through the `XttyCore` seam (observe-only) while the SwiftTerm view + PTY drive the engine. This is the P1 milestone that turns the P0 skeleton into a real, interactive terminal.

## Requirements
### Requirement: Live terminal running the user's login shell
The application SHALL present, on launch, a single interactive terminal that runs the user's login shell over a PTY, so that the user's existing dotfiles and PATH are in effect.

#### Scenario: Shell starts on launch
- **WHEN** the user launches the app
- **THEN** an interactive terminal is shown in the window
- **AND** the user's shell is running and accepts a typed command (e.g. `echo $0` reflects the shell)

#### Scenario: Dotfiles and PATH are in effect
- **WHEN** the shell has started
- **THEN** it was launched as a login + interactive shell (argv[0] begins with `-`)
- **AND** PATH and aliases defined in the user's shell startup files are available (e.g. a user alias or a PATH entry from `~/.zprofile`/`~/.zshrc` resolves)

### Requirement: Shell resolution and launch configuration
`XttyCore` SHALL provide a view-free component that resolves which shell to launch and how, independent of any terminal view, so it is unit-testable without launching the app.

#### Scenario: Resolve from environment with fallback
- **WHEN** `$SHELL` is set to an executable path
- **THEN** the resolver selects that path
- **AND** when `$SHELL` is unset or not executable, it falls back to the account's shell (`getpwuid`) and then to `/bin/zsh`

#### Scenario: Login argv and seed environment
- **WHEN** the resolver produces a launch configuration for a resolved shell at `/bin/zsh`
- **THEN** argv[0] is `-zsh` (login convention)
- **AND** the seed environment includes `TERM`, `COLORTERM`, and `LANG` and does not attempt to fully reconstruct PATH (the login shell builds it)

#### Scenario: Runs without launching the app
- **WHEN** the test suite runs
- **THEN** the resolver's behavior is exercised by a unit test that does not launch the app or create a terminal view

### Requirement: Interactive terminal input and output
The terminal SHALL support the core interactions of a usable terminal: keyboard input, window resize, multi-line paste, scrollback, and text selection, without display corruption.

#### Scenario: Keyboard input reaches the shell
- **WHEN** the terminal is focused and the user types a command and presses Return
- **THEN** the command runs in the shell and its output is displayed

#### Scenario: Resize reflows and updates the PTY
- **WHEN** the window is resized
- **THEN** the terminal's columns/rows update to match the new size
- **AND** a full-screen program (e.g. `vim` or `htop`) redraws correctly at the new size

#### Scenario: Multi-line paste does not auto-execute
- **WHEN** the user pastes multi-line text into a shell that has enabled bracketed paste
- **THEN** the text is inserted as input and is not executed line-by-line until the user submits it

#### Scenario: Scrollback and selection
- **WHEN** output exceeds the visible area
- **THEN** the user can scroll back to view earlier output
- **AND** the user can select text without corrupting the display

### Requirement: Terminal process lifecycle
The application SHALL manage the shell process lifecycle correctly: start it exactly once, keep keyboard focus on the terminal, and terminate the child process when its window closes.

#### Scenario: Shell is spawned exactly once
- **WHEN** the UI updates or the window redraws after the terminal is created
- **THEN** no additional shell process is spawned (the shell is started only once, at window/terminal creation)

#### Scenario: Terminal has keyboard focus
- **WHEN** the window becomes key
- **THEN** the terminal is the first responder and receives keystrokes without an extra click

#### Scenario: No orphaned process on close
- **WHEN** the window or app is closed
- **THEN** the shell child process is terminated (no orphaned shell remains)

### Requirement: Shell exit policy
When the shell process exits, the application SHALL close the terminal's window and record the process exit code on the session.

#### Scenario: Window closes when the shell exits
- **WHEN** the running shell exits (e.g. the user types `exit`)
- **THEN** the terminal's window closes
- **AND** the session's recorded exit status reflects the shell's exit code

### Requirement: Engine accessed only through the core seam
xtty logic SHALL access the terminal's `Terminal` engine only through `XttyCore` (observe-only), while the SwiftTerm view and PTY drive the engine; `XttyCore` SHALL NOT import a concrete terminal view.

#### Scenario: Session holds the engine handle via the seam
- **WHEN** the terminal is created
- **THEN** an `XttyCore` session holds the engine handle obtained from the view's `getTerminal()`
- **AND** `XttyCore` does not import or reference the concrete terminal view type

#### Scenario: Core observes, view drives
- **WHEN** terminal output is processed
- **THEN** byte feeding/driving of the engine is performed by the SwiftTerm view + PTY, not by `XttyCore`

