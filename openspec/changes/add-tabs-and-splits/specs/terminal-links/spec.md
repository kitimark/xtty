## ADDED Requirements

### Requirement: Clickable URL links in terminal output
The terminal SHALL detect URLs in its output — both explicit OSC 8 hyperlinks and implicitly detected `http(s)` URLs — visually indicate them on hover, and open the target in the user's default handler when the user activates the link.

#### Scenario: Hover indicates a link
- **WHEN** the pointer hovers over a URL (explicit OSC 8 or an implicitly detected `http(s)` URL) in the terminal
- **THEN** the link is visually indicated (e.g. underlined/highlighted)

#### Scenario: Activating an http(s) link opens it
- **WHEN** the user activates a detected `http(s)` link
- **THEN** the URL opens in the user's default browser/handler

### Requirement: Security guard for non-http(s) link schemes
Before opening a link whose scheme is not `http` or `https`, the application SHALL ask the user to confirm, so that terminal output cannot silently trigger arbitrary URL-scheme handlers. The application SHALL NOT execute clicked text as a shell command under any circumstances.

#### Scenario: Non-http(s) scheme prompts for confirmation
- **WHEN** the user activates a link whose scheme is not `http`/`https` (e.g. a custom application scheme)
- **THEN** the application asks the user to confirm before opening it
- **AND** the link is opened only if the user confirms

#### Scenario: Clicked text is never executed
- **WHEN** the user activates any detected link
- **THEN** the target is handed to the system URL opener (subject to the confirmation guard) and is never run as a shell command
