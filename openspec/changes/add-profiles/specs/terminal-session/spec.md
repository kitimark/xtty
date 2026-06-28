## ADDED Requirements

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
