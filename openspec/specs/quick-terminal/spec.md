# quick-terminal Specification

## Purpose

A global-hotkey "quake" drop-down terminal: a borderless, non-activating panel summoned and dismissed from anywhere — even when xtty is unfocused — by a user-configured hotkey (Carbon `RegisterEventHotKey`, no Accessibility/TCC prompt), hosting one persistent single scratch shell. It is an **accessory** session: created lazily on first summon, persisting across hide/show, and owning a private session registry so it is excluded from the main multiplexing inventory (and the future session sidebar) and never keeps the app alive or blocks quit. Its two config keys (`quick-terminal`, `quick-terminal-hotkey`) and its view-free hotkey parsing (a toolkit-independent `HotKeySpec` carrying a positional virtual keycode, parsed in `XttyCore` and sharing the modifier grammar with the keybindings) live in this capability, leaving the `terminal-configuration` schema untouched. Read once at startup and fail-soft: an unparseable or system-rejected hotkey disables the feature and is logged, without aborting launch.
## Requirements
### Requirement: Configurable global-hotkey activation
xtty SHALL provide a quick terminal that is summoned and dismissed by a user-configured global hotkey which functions even when xtty is not the frontmost application. The feature SHALL be off by default and enabled by the `quick-terminal` config key; the chord SHALL be set by the `quick-terminal-hotkey` config key. Registering the hotkey SHALL NOT require any Accessibility/TCC permission. An unparseable chord, or an OS registration failure (e.g. a system-reserved combo), SHALL disable the feature and be logged, without aborting startup. These keys SHALL be read once at startup from the existing config file and SHALL NOT alter the `terminal-configuration` schema.

#### Scenario: Disabled by default
- **WHEN** the `quick-terminal` key is not enabled in the config
- **THEN** no global hotkey is registered
- **AND** no quick terminal panel exists

#### Scenario: Hotkey summons from another application
- **WHEN** the quick terminal is enabled with a valid `quick-terminal-hotkey` and the user presses that hotkey while a different application is frontmost
- **THEN** the quick terminal panel appears and receives keyboard input
- **AND** xtty's main windows are not activated

#### Scenario: Invalid or unavailable hotkey fails soft
- **WHEN** `quick-terminal-hotkey` cannot be parsed, or the OS rejects the hotkey registration
- **THEN** the quick terminal feature is disabled, the issue is logged, and the app still launches

### Requirement: Drop-down panel summon and dismiss
The quick terminal SHALL be hosted in a borderless, non-activating panel that floats above normal windows and appears on the current Space (including over full-screen apps). Toggling SHALL summon the panel on the screen under the mouse pointer and SHALL dismiss it when it is already showing on that screen; if it is showing on a different screen, toggling SHALL move it to the screen under the mouse instead of hiding. The panel frame SHALL be recomputed from the target screen on every summon so it adapts to display changes. Summoning SHALL NOT deactivate the user's frontmost application, and dismissing SHALL return focus to the previously active context.

#### Scenario: Toggle shows then hides on the same screen
- **WHEN** the user toggles the quick terminal and then toggles it again with the pointer on the same screen
- **THEN** the panel appears on the first toggle and hides on the second

#### Scenario: Summon-to-active across screens
- **WHEN** the panel is visible on one screen and the user toggles with the pointer on a different screen
- **THEN** the panel is shown on the screen under the pointer rather than hidden

#### Scenario: Frame adapts to display changes
- **WHEN** the target screen's geometry has changed (resolution change or a monitor unplugged) since the last summon
- **THEN** the panel is positioned from the current screen geometry on the next summon

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

### Requirement: Accessory session lifecycle
The quick terminal SHALL be an accessory session: it SHALL be excluded from the main `SessionRegistry`, so it is not counted in the multiplexing inventory and does not appear in session enumeration (such as a future session sidebar). A hidden quick terminal panel SHALL NOT keep the application alive or block termination, and the application SHALL still terminate when its last main window closes even when the quick terminal is enabled.

#### Scenario: Excluded from the session inventory
- **WHEN** the quick terminal is showing alongside a single main window that has one pane
- **THEN** the main multiplexing inventory reports only the main window's pane(s) and does not count the quick terminal

#### Scenario: Hidden quick terminal does not block quit
- **WHEN** the user closes the last main window while the quick terminal is enabled (whether the panel is hidden or showing)
- **THEN** the application terminates

### Requirement: View-free hotkey model in XttyCore
The quick-terminal hotkey parsing SHALL live in a view-free `XttyCore` component that does not import the app/UI target and produces a toolkit-independent hotkey specification (a positional virtual key code plus a modifier mask, carrying no AppKit key or modifier types), exercisable by unit tests without launching the app. A valid chord MUST contain at least one modifier and exactly one non-modifier key.

#### Scenario: Parser is unit-testable without the app
- **WHEN** the test suite runs
- **THEN** a unit test parses hotkey chord strings into the hotkey specification and asserts the result without launching the app or creating a terminal view

#### Scenario: Modifier-only or keyless chord is rejected
- **WHEN** a hotkey string has no non-modifier key, or no modifier
- **THEN** parsing returns no specification so the caller disables the feature

#### Scenario: Model is independent of UI types
- **WHEN** `XttyCore` is built
- **THEN** the hotkey component does not import the app/UI target, and its specification type carries no AppKit key or modifier types

