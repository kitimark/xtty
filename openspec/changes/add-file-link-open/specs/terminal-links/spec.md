## MODIFIED Requirements

### Requirement: Clickable URL links in terminal output
The terminal SHALL detect URLs in its output — both explicit OSC 8 hyperlinks and implicitly detected `http(s)` URLs — visually indicate them on hover, and open the target in the user's default handler when the user activates a link whose scheme the link scheme guard permits (`http`, `https`, `mailto`). Activating such a link SHALL hand the target to the system URL opener; clicked text SHALL NOT be executed as a shell command. Interception SHALL be done through a vetted `TerminalViewDelegate` proxy installed as the view's delegate (which forwards all other delegate methods unchanged), not by overriding the engine's default — so xtty controls the open action without forking SwiftTerm.

#### Scenario: Hover indicates a link
- **WHEN** the pointer hovers over a URL (explicit OSC 8 or an implicitly detected `http(s)` URL) in the terminal
- **THEN** the link is visually indicated (e.g. underlined/highlighted)

#### Scenario: Activating an http(s) link opens it
- **WHEN** the user activates a detected `http(s)` link
- **THEN** the URL opens in the user's default browser/handler

#### Scenario: Clicked text is never executed
- **WHEN** the user activates any detected link
- **THEN** the target is handed to the system opener or editor and is never run as a shell command

## ADDED Requirements

### Requirement: Clickable file-path links open in the editor
The terminal SHALL treat an activated link that is a file reference — a `file:` URL, an absolute/`~`/relative/bare path, optionally with a trailing `:line` or `:line:column` suffix — as a request to open that file in the user's editor rather than the system URL opener. A relative or bare path SHALL be resolved against the focused session's live local working directory (captured via OSC 7). The file path SHALL be passed to the opener as a literal argument (never interpreted by a shell), and clicked text SHALL NOT be executed as a shell command. When the session's working directory is remote (e.g. over ssh) and the path is not absolute, xtty SHALL NOT open a (nonexistent local) path.

#### Scenario: Activating a file:line opens the editor at that line
- **WHEN** the user activates a detected `path:line:column` (or `path:line`) reference whose path resolves against the live local working directory
- **THEN** xtty opens that file in the resolved editor positioned at the given line (and column when supported)

#### Scenario: A relative path resolves against the live working directory
- **WHEN** the user activates a bare/relative path (e.g. `src/foo.swift`) while the session's live local working directory is a known local directory
- **THEN** xtty resolves the path against that directory before opening it

#### Scenario: A relative path with a remote working directory does not open
- **WHEN** the user activates a relative path while the session's working directory is remote (over ssh) and no matching local file exists
- **THEN** xtty does not open a path and performs no shell execution

### Requirement: Link scheme guard
xtty SHALL guard which link schemes are auto-opened on activation. Only `http`, `https`, and `mailto` SHALL be handed to the system URL opener; a `file:` link SHALL be treated as a file path and opened in the editor; any other scheme (e.g. a custom `x-*://`, `tel:`, or `javascript:` link, including one delivered via an explicit OSC 8 hyperlink) SHALL NOT be auto-opened. This closes the previously deferred gap where SwiftTerm's default handler passed any clicked scheme to `NSWorkspace`.

#### Scenario: A non-permitted scheme is not opened
- **WHEN** the user activates a detected link whose scheme is not `http`/`https`/`mailto`/`file` (e.g. `x-launch://do-something`)
- **THEN** xtty does not hand the link to the system opener and does not execute anything

#### Scenario: A file: URL opens in the editor
- **WHEN** the user activates a `file:///path/to/x:10` link
- **THEN** xtty treats it as the file `/path/to/x` at line 10 and opens it in the editor
