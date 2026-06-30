## MODIFIED Requirements

### Requirement: Shell resolution and launch configuration
`XttyCore` SHALL provide a view-free component that resolves which shell to launch and how, independent of any terminal view, so it is unit-testable without launching the app. The seed environment SHALL be deterministic and MAY include shell-specific entries keyed on the resolved shell's base name.

#### Scenario: Resolve from environment with fallback
- **WHEN** `$SHELL` is set to an executable path
- **THEN** the resolver selects that path
- **AND** when `$SHELL` is unset or not executable, it falls back to the account's shell (`getpwuid`) and then to `/bin/zsh`

#### Scenario: Login argv and seed environment
- **WHEN** the resolver produces a launch configuration for a resolved shell at `/bin/zsh`
- **THEN** argv[0] is `-zsh` (login convention)
- **AND** the seed environment includes `TERM`, `COLORTERM`, and `LANG` and does not attempt to fully reconstruct PATH (the login shell builds it)

#### Scenario: Suppress the macOS bash deprecation banner
- **WHEN** the resolver produces a launch configuration for a shell whose base name is `bash`
- **THEN** the seed environment includes `BASH_SILENCE_DEPRECATION_WARNING=1`, so the macOS system `/etc/bashrc` does not print the "default interactive shell is now zsh" banner into the terminal
- **AND** when the resolved shell's base name is not `bash` (e.g. `/bin/zsh`), the seed environment does not include `BASH_SILENCE_DEPRECATION_WARNING`

#### Scenario: Runs without launching the app
- **WHEN** the test suite runs
- **THEN** the resolver's behavior is exercised by a unit test that does not launch the app or create a terminal view
