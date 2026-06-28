## MODIFIED Requirements

### Requirement: Per-session command-block model

`XttyCore` SHALL maintain, per session, a view-free list of command blocks driven by a lifecycle state machine over the parsed OSC 133 marks. A block SHALL record the command text (when known), the exit code (when reported), the working directory at the time it ran, start and end timestamps, and a state of running, succeeded, failed, or opaque (full-screen). A block SHALL be opened only on an output-start (`C`) mark and closed only on the first command-end (`D`) mark following it; a `D` with no open block SHALL be a no-op. A prompt with no intervening command (e.g. an empty line or interrupted input) SHALL NOT produce a block. In addition to the list of finished blocks, the tracker SHALL expose the **in-flight running block** while a command is executing — between its output-start (`C`) and command-end (`D`), and not while suppressed by the alternate screen — as a block in the running state carrying the open command's text, its working directory, and its start timestamp (with no end timestamp). The block list and the running block SHALL feed downstream consumers (the session-progress sidebar) and SHALL NOT store fragile screen coordinates.

#### Scenario: A run command becomes a completed block
- **WHEN** the user runs a command that starts (`C`) and finishes (`D ; 0`)
- **THEN** a block is recorded with that command, exit code 0, state succeeded, the cwd it ran in, and start/end timestamps

#### Scenario: A failed command is marked failed
- **WHEN** a command finishes with a non-zero exit code
- **THEN** its block's state is failed and the exit code is recorded

#### Scenario: An in-flight command is observable as running
- **WHEN** a command has started (`C`) but not yet finished (no `D` yet) and the session is not on the alternate screen
- **THEN** the tracker exposes a running block carrying that command's text, cwd, and start timestamp, with no end timestamp
- **AND** once the command finishes (`D`) the running block is cleared and a finished block is appended

#### Scenario: Pressing Return at an empty prompt produces no block
- **WHEN** the user presses Return at a prompt without entering a command (no output-start mark)
- **THEN** no block is added to the session's list

#### Scenario: Only the first end mark after a start counts
- **WHEN** more than one command-end (`D`) mark arrives for a single command
- **THEN** only the first `D` after the output-start closes the block

#### Scenario: Block model runs without the app
- **WHEN** the test suite runs
- **THEN** the block lifecycle (open on C, expose the running block, close on first D, discard prompt-only regions, record fields) is exercised by a unit test that does not launch the app or create a terminal view
