## ADDED Requirements

### Requirement: OSC 133 command-boundary capture

The application SHALL register an OSC 133 handler on the headless engine (the engine has no built-in handling for code 133) and parse the FinalTerm semantic-prompt actions to recognize command boundaries. The parser SHALL recognize action `A` (prompt start), `B` (prompt end / input start), `C` (input end / output start), and `D` (command end), SHALL also accept `P` as a prompt-start, and SHALL ignore unknown action bytes. For action `D`, the exit code SHALL be read as a bare positional integer immediately following `D` (a bare `D` with no code SHALL mean "no exit code"). On action `C`, a `cmdline` (shell-quoted) or `cmdline_url` (percent-encoded) parameter SHALL be decoded to the command text, falling back to the raw value when decoding fails. A `k=s` parameter SHALL mark a continuation/secondary prompt. The parser SHALL be a view-free, unit-testable component in `XttyCore`.

#### Scenario: Command boundaries are recognized
- **WHEN** the engine receives `OSC 133 ; A`, then `;B`, then `;C`, then `;D ; 0`
- **THEN** the parser reports prompt-start, input-start, output-start, and command-end with exit code 0

#### Scenario: Exit code is a bare positional integer
- **WHEN** the engine receives `OSC 133 ; D ; 1`
- **THEN** the parser reports command-end with exit code 1
- **AND** a bare `OSC 133 ; D` reports command-end with no exit code

#### Scenario: Command text is decoded from cmdline parameters
- **WHEN** an output-start mark carries `cmdline` (shell-quoted) or `cmdline_url` (percent-encoded)
- **THEN** the decoded command text is captured for that command
- **AND** a value that cannot be decoded is captured as its raw form rather than dropped

#### Scenario: Unknown actions and continuation prompts do not start commands
- **WHEN** the engine receives an unknown action byte, or a prompt mark with `k=s`
- **THEN** no new command block is started for it

#### Scenario: Parser runs without the app
- **WHEN** the test suite runs
- **THEN** the OSC 133 parsing (actions, exit code, cmdline decoding) is exercised by a unit test that does not launch the app or create a terminal view

### Requirement: Per-session command-block model

`XttyCore` SHALL maintain, per session, a view-free list of command blocks driven by a lifecycle state machine over the parsed OSC 133 marks. A block SHALL record the command text (when known), the exit code (when reported), the working directory at the time it ran, start and end timestamps, and a state of running, succeeded, failed, or opaque (full-screen). A block SHALL be opened only on an output-start (`C`) mark and closed only on the first command-end (`D`) mark following it; a `D` with no open block SHALL be a no-op. A prompt with no intervening command (e.g. an empty line or interrupted input) SHALL NOT produce a block. The block list SHALL feed downstream consumers (the future session-progress sidebar) and SHALL NOT store fragile screen coordinates.

#### Scenario: A run command becomes a completed block
- **WHEN** the user runs a command that starts (`C`) and finishes (`D ; 0`)
- **THEN** a block is recorded with that command, exit code 0, state succeeded, the cwd it ran in, and start/end timestamps

#### Scenario: A failed command is marked failed
- **WHEN** a command finishes with a non-zero exit code
- **THEN** its block's state is failed and the exit code is recorded

#### Scenario: Pressing Return at an empty prompt produces no block
- **WHEN** the user presses Return at a prompt without entering a command (no output-start mark)
- **THEN** no block is added to the session's list

#### Scenario: Only the first end mark after a start counts
- **WHEN** more than one command-end (`D`) mark arrives for a single command
- **THEN** only the first `D` after the output-start closes the block

#### Scenario: Block model runs without the app
- **WHEN** the test suite runs
- **THEN** the block lifecycle (open on C, close on first D, discard prompt-only regions, record fields) is exercised by a unit test that does not launch the app or create a terminal view

### Requirement: Alternate-screen suppression and best-effort degradation

The application SHALL detect entering and leaving the alternate screen buffer using the engine's public alternate-buffer state, and SHALL suppress command-block creation while the alternate screen is active, so full-screen applications (e.g. `vim`, `htop`, `less`) do not become command blocks. A command that switches to the alternate screen while running SHALL be finalized as opaque (full-screen) when it completes. OSC 133 capture SHALL be treated as best-effort: when marks are absent (e.g. under tmux or over ssh without remote integration), the terminal SHALL display output normally with no blocks, and SHALL NOT gate rendering or any core terminal behavior on the presence of marks.

#### Scenario: A full-screen app does not become a block
- **WHEN** the user runs a full-screen program that switches to the alternate screen (e.g. `vim`)
- **THEN** no command block is created from its full-screen drawing
- **AND** when it exits and the next prompt appears, normal block capture resumes

#### Scenario: Absent marks degrade to plain output
- **WHEN** a session produces output with no OSC 133 marks (e.g. inside tmux or a non-integrated ssh session)
- **THEN** the output is displayed normally and no blocks are created
- **AND** terminal rendering and input are unaffected
