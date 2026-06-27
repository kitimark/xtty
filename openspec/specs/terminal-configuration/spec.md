# terminal-configuration Specification

## Purpose
How xtty is configured: a single user file, read once at startup, that sets the terminal's appearance and a few input behaviors without recompiling. Discovery, parsing, and resolution live in a view-free `XttyCore` component that yields a typed, toolkit-independent configuration (font family + size, an RGB palette named by theme, scrollback retention, option-as-meta); the app layer maps that onto the live SwiftTerm view. The format is line-oriented `key = value` (Ghostty-style), forward-compatible (unknown keys ignored) and fail-soft (a missing file or any invalid value falls back to defaults rather than blocking launch). Also covers ephemeral runtime font-size adjustment (Cmd +/−/0), which is not persisted to the file.

## Requirements
### Requirement: Config file discovery and parsing
xtty SHALL read a single user configuration file at startup, located at `$XDG_CONFIG_HOME/xtty/config` when `XDG_CONFIG_HOME` is set, otherwise `~/.config/xtty/config`. The file format SHALL be line-oriented `key = value` pairs, where lines beginning with `#` are comments, blank lines are ignored, and surrounding whitespace around keys and values is trimmed. A missing or unreadable file SHALL be treated as "all defaults" and MUST NOT prevent the app from launching.

#### Scenario: Missing config file falls back to defaults
- **WHEN** no config file exists at the resolved path
- **THEN** the app launches normally using the built-in default for every setting

#### Scenario: Key/value lines and comments are parsed
- **WHEN** the config file contains `font-size = 14`, a `# comment` line, a blank line, and `  theme = dark  ` with extra whitespace
- **THEN** the parser yields `font-size` = `14` and `theme` = `dark`, ignoring the comment and blank line

#### Scenario: XDG_CONFIG_HOME overrides the default location
- **WHEN** `XDG_CONFIG_HOME` is set to a directory containing `xtty/config`
- **THEN** that file is read instead of `~/.config/xtty/config`

### Requirement: Configuration schema with defaults and per-key fallback
xtty SHALL recognize the following keys, each with a built-in default: `font-family`, `font-size`, `theme`, `scrollback`, and `option-as-meta`. Unrecognized keys SHALL be ignored so older/newer configs remain loadable (forward-compatible). A recognized key whose value is invalid (e.g. a non-numeric `font-size`) SHALL fall back to that key's default and SHALL be logged, without aborting startup.

#### Scenario: Recognized values are applied
- **WHEN** the config sets `font-family`, `font-size`, `theme`, `scrollback`, and `option-as-meta` to valid values
- **THEN** each resolved setting reflects the configured value rather than its default

#### Scenario: Unknown keys are ignored
- **WHEN** the config contains a key xtty does not recognize
- **THEN** the unknown key is ignored and all recognized settings still load

#### Scenario: Invalid value falls back to the key default
- **WHEN** a recognized key has an unparseable value (e.g. `font-size = huge`)
- **THEN** that key resolves to its default, the issue is logged, and the app still launches

### Requirement: View-free configuration component in XttyCore
The discovery, parsing, and resolution of configuration SHALL live in a view-free `XttyCore` component that produces a typed, resolved configuration value, exercisable by unit tests without launching the app or creating a terminal view. The resolved value SHALL express appearance as toolkit-independent data (font family + size, RGB color values, a named/standard palette), and SHALL NOT depend on AppKit view types.

#### Scenario: Parser is unit-testable without the app
- **WHEN** the test suite runs
- **THEN** a unit test resolves configuration from in-memory or fixture input and asserts the typed result without launching the app or instantiating a terminal view

#### Scenario: Resolved config is independent of UI types
- **WHEN** `XttyCore` is built
- **THEN** the configuration component does not import the app/UI target or a concrete terminal view, and the resolved configuration carries no AppKit font/color types

### Requirement: Configuration applied to the live terminal
On launch, xtty SHALL apply the resolved configuration to the terminal: set the terminal font from `font-family` + `font-size`, install the color palette named by `theme`, set the engine's scrollback retention to the configured `scrollback` **at engine/terminal creation**, and set option-as-meta per `option-as-meta`.

#### Scenario: Appearance and behavior reflect config at launch
- **WHEN** the app launches with a config that sets a non-default font, theme, and `option-as-meta`
- **THEN** the rendered terminal uses that font and palette, and Option-key behavior matches the configured `option-as-meta`

#### Scenario: Scrollback is bounded for lean memory
- **WHEN** output far exceeding the configured `scrollback` is produced
- **THEN** the engine retains at most the configured number of scrollback lines (a finite default cap applies when `scrollback` is unset), so memory stays bounded (product value M1)

### Requirement: Live font-size adjustment
xtty SHALL let the user adjust the current session's font size at runtime via **Cmd +** (increase), **Cmd −** (decrease), and **Cmd 0** (reset to the configured size). These adjustments are ephemeral for the running session and SHALL NOT be written back to the config file in this milestone.

#### Scenario: Increase and decrease change the rendered size
- **WHEN** the user presses Cmd + and then Cmd −
- **THEN** the terminal's rendered font size increases and then decreases accordingly, reflowing the grid to the new metrics without corruption

#### Scenario: Reset returns to the configured size
- **WHEN** the user has changed the live font size and presses Cmd 0
- **THEN** the font size returns to the value resolved from configuration

#### Scenario: Live changes are not persisted
- **WHEN** the user changes the live font size and relaunches the app
- **THEN** the font size on the next launch is the configured value, not the last live-adjusted value

