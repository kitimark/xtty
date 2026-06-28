## ADDED Requirements

### Requirement: Automatic zsh shell-integration injection

The application SHALL automatically inject its shell-integration hooks into the user's zsh session so the shell emits OSC 7 (cwd) and OSC 133 (command boundaries) without the user editing any dotfiles. Injection SHALL use `ZDOTDIR` redirection: the launched shell's environment SHALL set `ZDOTDIR` to a bundled integration directory whose bootstrap restores the user's original `ZDOTDIR` (forwarded as `XTTY_ORIG_ZDOTDIR`), sources the user's real startup files, and then installs the hooks for interactive sessions. The user's own `.zshenv`/`.zprofile`/`.zshrc`/`.zlogin` SHALL still be loaded. Injection SHALL be additive and SHALL NOT replace the user's existing prompt or `precmd`/`preexec` hooks (so Starship/powerlevel10k continue to work). Injection SHALL be skipped for a profile that runs a one-shot `command`. When the integration resource is unavailable, the shell SHALL still launch normally (fail-soft, logged) — only semantic capture is lost.

#### Scenario: A plain zsh session is auto-injected
- **WHEN** a pane launches the user's interactive zsh login shell
- **THEN** the child environment sets `ZDOTDIR` to xtty's bundled integration directory
- **AND** at a prompt the shell emits OSC 133 and OSC 7 sequences without the user having edited any dotfile

#### Scenario: The user's dotfiles still load and original ZDOTDIR is preserved
- **WHEN** the user has a custom `ZDOTDIR` and a `.zshrc` (e.g. defining an alias or prompt) and a pane launches
- **THEN** the user's original `ZDOTDIR` is forwarded as `XTTY_ORIG_ZDOTDIR` and restored before the user's startup files are sourced
- **AND** the user's `.zshrc` customizations (alias/prompt) are in effect in the session

#### Scenario: Existing prompt hooks are preserved
- **WHEN** the user's configuration installs its own `precmd`/`preexec` hooks (e.g. powerlevel10k)
- **THEN** xtty's hooks are added alongside them and both run (the existing prompt is not replaced)

#### Scenario: Command profiles are not injected
- **WHEN** a profile launches a one-shot `command` (e.g. `ssh box`)
- **THEN** shell-integration injection is skipped for that pane

#### Scenario: Missing integration resource fails soft
- **WHEN** the bundled integration resource cannot be located
- **THEN** the shell still launches and is interactive
- **AND** the condition is logged and the session simply has no semantic capture

### Requirement: View-free injection seam and manual fallback

`XttyCore` SHALL compute the injection environment view-free and unit-testably: the integration directory path SHALL be supplied to the shell resolver as an injected parameter (not hard-coded), and the resolver SHALL add `ZDOTDIR`/`XTTY_ORIG_ZDOTDIR` to the seed environment, reading any inherited `ZDOTDIR` before the seed replaces the environment. A documented manual-setup fallback SHALL exist for configurations where automatic `ZDOTDIR` redirection cannot take effect (e.g. a system `/etc/zshenv` that overrides `ZDOTDIR`).

#### Scenario: Resolver injects ZDOTDIR without launching the app
- **WHEN** the shell resolver is given an integration directory and an environment that already contains a `ZDOTDIR`
- **THEN** the produced environment sets `ZDOTDIR` to the integration directory and `XTTY_ORIG_ZDOTDIR` to the inherited value
- **AND** this is exercised by a unit test that does not launch the app or create a terminal view

#### Scenario: Manual fallback is documented
- **WHEN** automatic redirection cannot apply
- **THEN** the user can enable integration by sourcing the documented installer from their own shell startup file
