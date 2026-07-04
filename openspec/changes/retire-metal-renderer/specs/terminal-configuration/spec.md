# terminal-configuration — delta for retire-metal-renderer

## MODIFIED Requirements

### Requirement: Configuration schema with defaults and per-key fallback
xtty SHALL recognize the following appearance keys, each with a built-in default: `font-family`, `font-size`, `theme`, `scrollback`, and `option-as-meta`. It SHALL additionally recognize the launch keys `command`, `cwd`, and repeated `env-<NAME>` keys (valid in the base profile and in any profile block), the global keys `default-profile` and `confirm-close` (honored only in the base profile), and the git-review keys `diff-context` — the number of unified-diff context lines shown in the git-review panel, a non-negative integer defaulting to `3` — and `git-review-layout` (honored only in the base profile) — the git-review panel's default changed-files list layout, one of `flat` (status-category grouping) or `tree` (directory tree), defaulting to `flat`. Unrecognized keys SHALL be ignored so older/newer configs remain loadable (forward-compatible). A recognized key whose value is invalid (e.g. a non-numeric `font-size`, a non-integer `diff-context`, or a `git-review-layout` that is neither `flat` nor `tree`) SHALL fall back to that key's default and SHALL be logged, without aborting startup.

#### Scenario: Recognized values are applied
- **WHEN** the config sets `font-family`, `font-size`, `theme`, `scrollback`, and `option-as-meta` to valid values
- **THEN** each resolved setting reflects the configured value rather than its default

#### Scenario: Unknown keys are ignored
- **WHEN** the config contains a key xtty does not recognize
- **THEN** the unknown key is ignored and all recognized settings still load

#### Scenario: A retired renderer key is ignored as unrecognized
- **WHEN** a config written for an earlier xtty version contains `renderer = metal` (the retired rendering-backend key)
- **THEN** the key is unrecognized and ignored under the forward-compatibility rule, all recognized settings still load, and the app launches with its standard rendering path

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

#### Scenario: git-review-layout is recognized with a default and fallback
- **WHEN** the config sets `git-review-layout` to `tree`
- **THEN** the resolved configuration uses the directory-tree layout as the git-review panel's default list layout
- **AND WHEN** `git-review-layout` is absent or is neither `flat` nor `tree`, the resolved value is the default (`flat`), the issue (if any) is logged, and the app still launches
