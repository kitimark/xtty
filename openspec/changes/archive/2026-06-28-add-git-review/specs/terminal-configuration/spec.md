## MODIFIED Requirements

### Requirement: Configuration schema with defaults and per-key fallback
xtty SHALL recognize the following appearance keys, each with a built-in default: `font-family`, `font-size`, `theme`, `scrollback`, and `option-as-meta`. It SHALL additionally recognize the launch keys `command`, `cwd`, and repeated `env-<NAME>` keys (valid in the base profile and in any profile block), the global keys `default-profile` and `confirm-close` (honored only in the base profile), and the git-review key `diff-context` — the number of unified-diff context lines shown in the git-review panel, a non-negative integer defaulting to `3`. Unrecognized keys SHALL be ignored so older/newer configs remain loadable (forward-compatible). A recognized key whose value is invalid (e.g. a non-numeric `font-size`, or a non-integer `diff-context`) SHALL fall back to that key's default and SHALL be logged, without aborting startup.

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

#### Scenario: diff-context is recognized with a default and fallback
- **WHEN** the config sets `diff-context` to a valid non-negative integer
- **THEN** the resolved configuration uses that value for git-review diff context
- **AND WHEN** `diff-context` is absent or unparseable, the resolved value is the default (`3`), the issue (if any) is logged, and the app still launches
