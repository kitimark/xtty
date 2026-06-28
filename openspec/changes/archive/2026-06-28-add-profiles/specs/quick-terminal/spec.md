## MODIFIED Requirements

### Requirement: Persistent single scratch shell
The quick terminal SHALL host exactly one terminal pane running the user's shell. The shell SHALL be created lazily on the first summon and SHALL persist across hide/show cycles, so toggling only orders the panel in and out while the shell and its scrollback are retained. The quick terminal SHALL NOT support splitting into multiple panes in this version. The quick terminal SHALL use the **base** profile's appearance and SHALL always launch a plain interactive login shell, ignoring any profile launch overrides (`command`/`cwd`) — including the base profile's — so the scratch terminal is never redirected into a command or directory.

#### Scenario: Shell persists across hide and show
- **WHEN** the user summons the quick terminal, runs a command, hides it, and summons it again
- **THEN** the same shell session is shown with its prior output intact

#### Scenario: Single pane only
- **WHEN** the quick terminal is showing
- **THEN** it contains exactly one pane and a split command does not divide it

#### Scenario: Uses base appearance and a plain login shell
- **WHEN** the config defines profiles and launch overrides (e.g. a base or default-profile `command`)
- **THEN** the quick terminal still launches a plain interactive login shell using the base profile's appearance, not any profile command or cwd
