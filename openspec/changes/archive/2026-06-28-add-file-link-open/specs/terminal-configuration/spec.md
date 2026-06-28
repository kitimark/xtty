## ADDED Requirements

### Requirement: Configurable file/link opener
The configuration SHALL support a `link-opener` key holding a command template used to open activated file links, with `${file}`, `${line}`, and `${column}` substitution tokens. The tokens SHALL be substituted as whole, discrete command arguments (so the file path is never re-split or shell-interpreted). When `link-opener` is unset or empty, xtty SHALL infer the opener from the `$VISUAL` then `$EDITOR` environment variables for recognized GUI editors (e.g. VS Code / Cursor, Sublime Text, JetBrains, TextMate, Emacs), falling back to the macOS `open` command (no line) for an unrecognized or terminal-only editor. The `link-opener` value SHALL be resolvable view-free in `XttyCore` (parsed and tokenized without launching the app or creating a terminal view), and SHALL be documented in `config.example`.

#### Scenario: Configured template is used with substitution
- **WHEN** the config sets `link-opener = code --goto ${file}:${line}:${column}` and the user activates `src/x.swift:42:7`
- **THEN** xtty invokes the editor with the resolved file, line 42, and column 7 as discrete arguments

#### Scenario: Missing line/column collapses its token
- **WHEN** the template references `${line}`/`${column}` but the activated path has no line/column suffix
- **THEN** the missing tokens (and any adjacent separators) are omitted from the invocation rather than passed empty

#### Scenario: Unset opener infers from the environment
- **WHEN** `link-opener` is not set and `$VISUAL` (or `$EDITOR`) names a recognized GUI editor
- **THEN** xtty builds the editor's known line-aware invocation; and when the editor is unrecognized or terminal-only, it falls back to macOS `open`

#### Scenario: Opener resolution is unit-tested without the app
- **WHEN** the test suite runs
- **THEN** template tokenization, the environment-inference table, and the `open` fallback are exercised by unit tests that do not launch the app or create a terminal view
