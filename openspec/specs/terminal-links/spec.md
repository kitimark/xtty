# terminal-links Specification

## Purpose

Clickable links in terminal output: xtty detects URLs — explicit OSC 8 hyperlinks and implicitly detected `http(s)` URLs — indicates them on hover, and opens the target in the user's default handler on activation, never executing clicked text as a shell command. This surfaces SwiftTerm's built-in link handling. A confirmation guard for non-`http(s)` schemes and file:line error-matching are deferred (the change's design D7): SwiftTerm dispatches link opening through a non-overridable protocol-extension default, so clean interception needs the own-renderer or a vetted delegate proxy.

## Requirements
### Requirement: Clickable URL links in terminal output
The terminal SHALL detect URLs in its output — both explicit OSC 8 hyperlinks and implicitly detected `http(s)` URLs — visually indicate them on hover, and open the target in the user's default handler when the user activates the link. Activating a link SHALL hand the target to the system URL opener; clicked text SHALL NOT be executed as a shell command.

#### Scenario: Hover indicates a link
- **WHEN** the pointer hovers over a URL (explicit OSC 8 or an implicitly detected `http(s)` URL) in the terminal
- **THEN** the link is visually indicated (e.g. underlined/highlighted)

#### Scenario: Activating an http(s) link opens it
- **WHEN** the user activates a detected `http(s)` link
- **THEN** the URL opens in the user's default browser/handler

#### Scenario: Clicked text is never executed
- **WHEN** the user activates any detected link
- **THEN** the target is handed to the system URL opener and is never run as a shell command

