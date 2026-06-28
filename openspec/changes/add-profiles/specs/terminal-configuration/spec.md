## MODIFIED Requirements

### Requirement: Config file discovery and parsing
xtty SHALL read a single user configuration file at startup, located at `$XDG_CONFIG_HOME/xtty/config` when `XDG_CONFIG_HOME` is set, otherwise `~/.config/xtty/config`. The file format SHALL be line-oriented `key = value` pairs, where lines beginning with `#` are comments, blank lines are ignored, and surrounding whitespace around keys and values is trimmed. A missing or unreadable file SHALL be treated as "all defaults" and MUST NOT prevent the app from launching.

The file MAY additionally contain profile **section headers** of the form `[profile "<name>"]`. All `key = value` lines before the first header constitute the **base** profile; each header begins a named profile block whose lines apply to that profile. Parsing SHALL preserve the original case of keys (so the `<NAME>` in an `env-<NAME>` key is case-sensitive), lowercasing only when matching recognized keys. A malformed or unquoted profile header (e.g. `[profile work]` or `[profile ""]`) SHALL be logged and skipped while the rest of the file continues to load; it MUST NOT abort parsing. A file with no section headers SHALL be parsed exactly as before (entirely the base profile).

#### Scenario: Missing config file falls back to defaults
- **WHEN** no config file exists at the resolved path
- **THEN** the app launches normally using the built-in default for every setting

#### Scenario: Key/value lines and comments are parsed
- **WHEN** the config file contains `font-size = 14`, a `# comment` line, a blank line, and `  theme = dark  ` with extra whitespace
- **THEN** the parser yields `font-size` = `14` and `theme` = `dark`, ignoring the comment and blank line

#### Scenario: XDG_CONFIG_HOME overrides the default location
- **WHEN** `XDG_CONFIG_HOME` is set to a directory containing `xtty/config`
- **THEN** that file is read instead of `~/.config/xtty/config`

#### Scenario: Profile sections are parsed into base and named blocks
- **WHEN** the config has `theme = dark` before any header and a `[profile "work"]` block setting `theme = light`
- **THEN** the parser yields a base profile with `theme = dark` and a `work` profile block with `theme = light`

#### Scenario: Environment-variable key case is preserved
- **WHEN** a profile block contains `env-EDITOR = nvim`
- **THEN** the parsed env key preserves the name `EDITOR` (it is not lowercased to `editor`)

#### Scenario: Malformed profile header is skipped, not fatal
- **WHEN** the config contains an unquoted or empty profile header (e.g. `[profile work]`)
- **THEN** that header is logged and skipped, and the rest of the file (base plus any valid profile blocks) still loads

### Requirement: Configuration schema with defaults and per-key fallback
xtty SHALL recognize the following appearance keys, each with a built-in default: `font-family`, `font-size`, `theme`, `scrollback`, and `option-as-meta`. It SHALL additionally recognize the launch keys `command`, `cwd`, and repeated `env-<NAME>` keys (valid in the base profile and in any profile block), and the global keys `default-profile` and `confirm-close` (honored only in the base profile). Unrecognized keys SHALL be ignored so older/newer configs remain loadable (forward-compatible). A recognized key whose value is invalid (e.g. a non-numeric `font-size`) SHALL fall back to that key's default and SHALL be logged, without aborting startup.

#### Scenario: Recognized values are applied
- **WHEN** the config sets `font-family`, `font-size`, `theme`, `scrollback`, and `option-as-meta` to valid values
- **THEN** each resolved setting reflects the configured value rather than its default

#### Scenario: Unknown keys are ignored
- **WHEN** the config contains a key xtty does not recognize
- **THEN** the unknown key is ignored and all recognized settings still load

#### Scenario: Invalid value falls back to the key default
- **WHEN** a recognized key has an unparseable value (e.g. `font-size = huge`)
- **THEN** that key resolves to its default, the issue is logged, and the app still launches

#### Scenario: Launch and global keys are recognized
- **WHEN** the config sets `command`, `cwd`, an `env-<NAME>`, `default-profile`, and `confirm-close` to valid values
- **THEN** each is parsed into the resolved configuration (launch keys per profile; `default-profile`/`confirm-close` globally) rather than being ignored as unknown

### Requirement: View-free configuration component in XttyCore
The discovery, parsing, and resolution of configuration SHALL live in a view-free `XttyCore` component, exercisable by unit tests without launching the app or creating a terminal view. The component SHALL produce a typed, toolkit-independent **configuration set**: a base profile plus zero or more named profiles (each with a resolved appearance configuration and a launch override) and an optional default-profile selection. Each profile's resolved appearance SHALL express font family + size, RGB color values, and a named/standard palette, and SHALL NOT depend on AppKit view types.

#### Scenario: Parser is unit-testable without the app
- **WHEN** the test suite runs
- **THEN** a unit test resolves the configuration set from in-memory or fixture input and asserts the base profile, named profiles, and default selection without launching the app or instantiating a terminal view

#### Scenario: Resolved config is independent of UI types
- **WHEN** `XttyCore` is built
- **THEN** the configuration component does not import the app/UI target or a concrete terminal view, and the resolved configuration set carries no AppKit font/color types

### Requirement: Configuration applied to the live terminal
On launch, xtty SHALL apply a resolved profile's configuration to each pane's terminal: set the terminal font from `font-family` + `font-size`, install the color palette named by `theme`, set the engine's scrollback retention to the configured `scrollback` **at engine/terminal creation**, and set option-as-meta per `option-as-meta`. A pane SHALL use the configuration of the profile it was launched with; panes launched with different profiles MAY show different appearance.

#### Scenario: Appearance and behavior reflect config at launch
- **WHEN** the app launches with a config that sets a non-default font, theme, and `option-as-meta`
- **THEN** the rendered terminal uses that font and palette, and Option-key behavior matches the configured `option-as-meta`

#### Scenario: Scrollback is bounded for lean memory
- **WHEN** output far exceeding the configured `scrollback` is produced
- **THEN** the engine retains at most the configured number of scrollback lines (a finite default cap applies when `scrollback` is unset), so memory stays bounded (product value M1)

#### Scenario: A profiled pane reflects its profile's appearance
- **WHEN** a pane is launched with a profile whose `theme`/`font-size` differ from the base
- **THEN** that pane renders with the profile's theme and font size, independent of base-profile panes

## ADDED Requirements

### Requirement: Named configuration profiles
xtty SHALL support named configuration profiles defined by `[profile "<name>"]` section blocks in the config file. Each profile SHALL resolve its appearance by inheriting the base profile and applying its own overrides (single level: base ⊕ profile). A profile MAY also carry launch overrides (`command`, `cwd`, `env-<NAME>`). A config file with no profile sections SHALL resolve identically to the same file parsed under the pre-profiles (flat) rules — the base profile alone — so existing configs are unaffected (migration-free). Profile names SHALL be case-sensitive. The `default-profile` key (base only) SHALL name the profile used for newly opened sessions; an unknown name SHALL be logged and fall back to the base profile.

#### Scenario: Profile inherits base and overrides it
- **WHEN** the base sets `font-family = JetBrains Mono` and `theme = dark`, and `[profile "work"]` sets only `theme = light`
- **THEN** the `work` profile resolves to `font-family = JetBrains Mono` (inherited) and `theme = light` (overridden)

#### Scenario: A flat config resolves as base only (backward-compatible)
- **WHEN** a config file contains no `[profile …]` headers
- **THEN** it resolves to a single base profile equal to the pre-profiles resolution of the same file, and no named profiles exist

#### Scenario: default-profile selects the new-session profile
- **WHEN** the base sets `default-profile = work` and a `[profile "work"]` exists
- **THEN** a newly opened session uses the `work` profile

#### Scenario: Unknown default-profile falls back to base
- **WHEN** `default-profile` names a profile that is not defined
- **THEN** the issue is logged and new sessions use the base profile

#### Scenario: Duplicate profile names merge with later keys winning
- **WHEN** two `[profile "work"]` blocks set the same key to different values
- **THEN** the later value wins and the duplication is logged

#### Scenario: Per-profile font size governs reset
- **WHEN** a pane is launched with a profile whose `font-size` differs from base, the user adjusts the live size, then presses Cmd 0
- **THEN** the font size resets to that profile's configured size, not the base size
