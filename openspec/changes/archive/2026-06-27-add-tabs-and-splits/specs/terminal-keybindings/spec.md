## ADDED Requirements

### Requirement: Keybinding preset selection
xtty SHALL support selecting a keybinding preset via the `keybind-style` config key, with built-in presets `iterm` (the default) and `ghostty`. The chosen preset SHALL establish the default chord for every bindable action. An unrecognized `keybind-style` value SHALL fall back to `iterm` and SHALL be logged, without aborting startup.

#### Scenario: Default preset applies when unset
- **WHEN** no `keybind-style` is configured
- **THEN** the `iterm` preset's chords are in effect (e.g. split-right on Cmd+D)

#### Scenario: Selecting a different preset changes the bindings
- **WHEN** `keybind-style = ghostty` is configured
- **THEN** the `ghostty` preset's chords are in effect (e.g. pane focus on Cmd+[ / Cmd+])

#### Scenario: Unknown preset falls back to the default
- **WHEN** `keybind-style` is set to an unknown value
- **THEN** the `iterm` preset is used, the issue is logged, and the app still launches

### Requirement: Per-action keybinding override
xtty SHALL let the user override the chord for an individual action via a `keybind-<action>` config key, layered on top of the selected preset. Only the overridden action SHALL change; all other actions SHALL retain their preset chord.

#### Scenario: An override replaces one action's chord
- **WHEN** the config sets `keybind-split-down` to a custom chord
- **THEN** that action uses the custom chord
- **AND** every other action keeps its preset chord

### Requirement: Fail-soft keybinding parsing
A `keybind-<action>` value that cannot be parsed into a valid chord SHALL fall back to that action's preset chord and SHALL be logged, without aborting startup. A chord MUST include at least one modifier and exactly one non-modifier key.

#### Scenario: Invalid chord falls back to the preset
- **WHEN** a `keybind-<action>` value is unparseable (e.g. empty, or modifiers only)
- **THEN** the action retains its preset chord, the issue is logged, and the app still launches

### Requirement: Keybindings applied to menu commands
The resolved keybindings SHALL drive the key equivalents of xtty's menu commands for the multiplexing actions (split, focus, new tab, new window, close) and the existing pane-scoped actions (font size, find). Activating a command's configured chord SHALL invoke that command.

#### Scenario: Configured chord triggers its command
- **WHEN** the user presses the chord configured for the new-tab action
- **THEN** a new tab opens (the new-tab command runs)

#### Scenario: Menu reflects the configured chords
- **WHEN** the application builds its menu at launch
- **THEN** each command's displayed key equivalent matches the resolved keybinding for that action

### Requirement: View-free keybinding model in XttyCore
The keybinding chord parsing, the built-in presets, and the preset-plus-override resolution SHALL live in a view-free `XttyCore` component that does not import the app/UI target, produces toolkit-independent chords (no AppKit key/modifier types), and is exercisable by unit tests without launching the app.

#### Scenario: Parser and resolution are unit-testable without the app
- **WHEN** the test suite runs
- **THEN** a unit test parses chord strings and resolves a preset-plus-overrides keybinding map, asserting the result without launching the app or creating a terminal view

#### Scenario: Model is independent of UI types
- **WHEN** `XttyCore` is built
- **THEN** the keybinding component does not import the app/UI target, and its chord type carries no AppKit key-equivalent or modifier-flag types
