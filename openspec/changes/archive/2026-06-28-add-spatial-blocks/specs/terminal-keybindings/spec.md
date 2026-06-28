## MODIFIED Requirements

### Requirement: Keybindings applied to menu commands
The resolved keybindings SHALL drive the key equivalents of xtty's menu commands for the multiplexing actions (split, focus, new tab, new window, close) and the pane-scoped actions (font size, find, and the spatial-block actions: jump-to-previous-prompt, jump-to-next-prompt, copy-command-output). Activating a command's configured chord SHALL invoke that command. The default chords for the jump actions SHALL be **Cmd+Shift+Up** (previous prompt) and **Cmd+Shift+Down** (next prompt) in both presets — the iTerm2/Ghostty macOS convention — and copy-command-output SHALL have a default chord; each remains overridable via its `keybind-<action>` key. Because these chords are bound as menu key equivalents, the menu SHALL intercept them ahead of the terminal view (so a system text-editing default for the same chord does not shadow the action).

#### Scenario: Configured chord triggers its command
- **WHEN** the user presses the chord configured for the new-tab action
- **THEN** a new tab opens (the new-tab command runs)

#### Scenario: Menu reflects the configured chords
- **WHEN** the application builds its menu at launch
- **THEN** each command's displayed key equivalent matches the resolved keybinding for that action

#### Scenario: Jump-to-prompt is bound by default
- **WHEN** the user presses Cmd+Shift+Up (or Cmd+Shift+Down) with no override configured
- **THEN** the focused pane jumps to the previous (or next) command prompt

#### Scenario: A spatial action can be rebound
- **WHEN** the config sets `keybind-copy-command-output` (or `keybind-jump-prev-prompt` / `keybind-jump-next-prompt`) to a custom chord
- **THEN** that action uses the custom chord and the other actions keep their preset chords
