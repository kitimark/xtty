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
The application SHALL manage each session's shell process lifecycle correctly: start each session's shell exactly once, keep keyboard focus on the focused pane, and terminate a session's child process when its pane (or the window containing it) closes — leaving no orphaned shells.

#### Scenario: Each session's shell is spawned exactly once
- **WHEN** the UI updates or a window redraws after a pane is created
- **THEN** no additional shell process is spawned for that pane (its shell is started only once, at pane creation)

#### Scenario: Focused pane has keyboard focus
- **WHEN** a window becomes key
- **THEN** the focused pane's terminal is the first responder and receives keystrokes without an extra click

#### Scenario: No orphaned process on close
- **WHEN** a pane is closed, or the window/app is closed
- **THEN** the affected session's shell child process is terminated (no orphaned shell remains)

### Requirement: Shell exit policy
When a session's shell process exits, the application SHALL close that session's pane and record the process exit code on the session. Closing the last pane in a tab SHALL close that tab/window, and closing the last window SHALL terminate the app.

#### Scenario: Pane closes when its shell exits
- **WHEN** a pane's shell exits (e.g. the user types `exit`) while other panes remain in the tab
- **THEN** that pane closes and the remaining panes reflow to fill the space
- **AND** the session's recorded exit status reflects the shell's exit code

#### Scenario: Closing the last pane escalates to the window
- **WHEN** the shell in the only remaining pane of a window exits
- **THEN** the window closes
- **AND** if it was the last window, the app terminates

### Requirement: Engine accessed only through the core seam
xtty logic SHALL access the terminal's `Terminal` engine only through `XttyCore` (observe-only), while the SwiftTerm view and PTY drive the engine; `XttyCore` SHALL NOT import a concrete terminal view.

#### Scenario: Session holds the engine handle via the seam
- **WHEN** the terminal is created
- **THEN** an `XttyCore` session holds the engine handle obtained from the view's `getTerminal()`
- **AND** `XttyCore` does not import or reference the concrete terminal view type

#### Scenario: Core observes, view drives
- **WHEN** terminal output is processed
- **THEN** byte feeding/driving of the engine is performed by the SwiftTerm view + PTY, not by `XttyCore`

### Requirement: Find in terminal output
The terminal SHALL support searching its visible screen and scrollback for text, surfaced through a native find bar opened with **Cmd+F**. The user SHALL be able to navigate to the next and previous matches and dismiss the find bar, returning keyboard focus to the terminal. This extends the interactive-terminal behavior set without changing existing input/resize/paste/scrollback/selection behavior.

#### Scenario: Cmd+F opens the find bar
- **WHEN** the terminal is focused and the user presses Cmd+F
- **THEN** a find bar appears and accepts a search query

#### Scenario: Matches are located and navigable
- **WHEN** the user enters a query that occurs in the visible screen or scrollback
- **THEN** a match is located, and next/previous controls move the selection between matches

#### Scenario: Dismissing the find bar restores terminal focus
- **WHEN** the user closes the find bar (e.g. Escape or its close control)
- **THEN** the find bar is hidden and keyboard input is routed to the terminal again

### Requirement: Profile-driven shell launch
When a pane is launched with a profile that specifies launch overrides, `XttyCore` SHALL produce the pane's launch configuration from those overrides, view-free and unit-testable. A `command` SHALL be run through the user's login + interactive shell — `<login shell> -l -i -c '<command>'` with the command passed as a single argument — so it resolves against the user's real PATH and dotfiles; a profile with no `command` SHALL launch a plain interactive login shell as before. A `cwd` SHALL set the launched process's working directory, expanding `~`/`$HOME`; a non-existent directory SHALL be logged and fall back to the default without failing the launch. `env-<NAME>` entries SHALL be merged additively onto the seed environment (the profile winning on conflict), except `PATH`, which SHALL be ignored with a warning (the login shell builds it).

#### Scenario: Command profile runs via the login shell and resolves PATH
- **WHEN** a profile sets `command = ssh box`
- **THEN** the pane launches `<login shell> -l -i -c 'ssh box'` (the command as a single argument)
- **AND** a bare command name resolves against the user's login-shell PATH (e.g. a Homebrew-installed tool starts)

#### Scenario: No command launches a plain login shell
- **WHEN** a profile has no `command`
- **THEN** the pane launches the user's interactive login shell (argv[0] begins with `-`), exactly as a base session does

#### Scenario: cwd sets the working directory and expands home
- **WHEN** a profile sets `cwd = ~/src/work` and the directory exists
- **THEN** the launched process starts in `~/src/work` (with `~` expanded)
- **AND** if the directory does not exist, the issue is logged and the launch falls back to the default directory without failing

#### Scenario: env is additive and PATH is protected
- **WHEN** a profile sets `env-EDITOR = nvim` and `env-PATH = /tmp`
- **THEN** the launched shell environment includes `EDITOR=nvim`
- **AND** `env-PATH` is ignored with a warning (the login shell builds PATH)

#### Scenario: Launch resolution runs without the app
- **WHEN** the test suite runs
- **THEN** the override-aware launch resolution (command wrap, cwd expansion, env merge) is exercised by a unit test that does not launch the app or create a terminal view

### Requirement: Live working-directory capture from OSC 7

Each session SHALL capture the shell's reported working directory from OSC 7 and expose it as a per-session **live working directory**, distinct from the static launch directory. The application SHALL consume OSC 7 through the existing engine cwd-update delegate (not a custom OSC handler, so the engine's trust gating and stored host directory remain in effect). The raw OSC 7 URL SHALL be decoded view-free: the `file://` and `kitty-shell-cwd://` schemes SHALL both be accepted; for `file://` the path SHALL be percent-decoded; for `kitty-shell-cwd://` the path SHALL be taken raw; and a host that is not the local machine SHALL be flagged as remote rather than treated as a local filesystem path. Until an OSC 7 update arrives, the live working directory SHALL be the session's launch directory.

#### Scenario: cd updates the live working directory
- **WHEN** the shell reports a new directory via OSC 7 (e.g. after `cd /tmp`)
- **THEN** the session's live working directory updates to `/tmp`

#### Scenario: Both OSC 7 URL forms decode correctly
- **WHEN** the OSC 7 payload is `file://host/Users/me/My%20Project` or `kitty-shell-cwd://host/Users/me/My Project`
- **THEN** the decoded path is `/Users/me/My Project` (percent-decoded only for the `file://` form)

#### Scenario: A remote host is flagged, not treated as local
- **WHEN** the OSC 7 host is not the local machine (e.g. a directory reported over ssh)
- **THEN** the live working directory is flagged as remote and is not treated as a local filesystem path

#### Scenario: Decoding runs without the app
- **WHEN** the test suite runs
- **THEN** the OSC 7 URL decoding (scheme handling, percent-decoding, remote-host detection) is exercised by a unit test that does not launch the app or create a terminal view

