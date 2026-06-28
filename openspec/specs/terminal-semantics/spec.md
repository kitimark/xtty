# terminal-semantics Specification

## Purpose

Defines xtty's capture of semantic command structure from the OSC 133 byte stream: a view-free OSC 133 parser (FinalTerm `A`/`B`/`C`/`D` plus `P`, with `D`'s bare positional exit code, `cmdline`/`cmdline_url` command text, and `k=s` continuation marks), a per-session block-lifecycle state machine and block model in `XttyCore` (each block's command, exit code, working directory, timestamps, and state — succeeded/failed/opaque — and deliberately no fragile screen coordinates), and alternate-screen gating so full-screen applications never become command blocks. OSC 133 capture is best-effort: when marks are absent (tmux, ssh without integration) the terminal degrades to plain output and never gates rendering on them. This is the consume side of the P4a keystone — the data foundation the session-progress sidebar (P5) builds on. The spatial operations over blocks (jump-to-prompt, select-output, gutter marks) are deferred to P4b (they need stable absolute row anchors unavailable via SwiftTerm's public API).
## Requirements
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

### Requirement: Alternate-screen suppression and best-effort degradation

The application SHALL detect entering and leaving the alternate screen buffer using the engine's public alternate-buffer state, and SHALL suppress command-block creation while the alternate screen is active, so full-screen applications (e.g. `vim`, `htop`, `less`) do not become command blocks. A command that switches to the alternate screen while running SHALL be finalized as opaque (full-screen) when it completes. OSC 133 capture SHALL be treated as best-effort: when marks are absent (e.g. under tmux or over ssh without remote integration), the terminal SHALL display output normally with no blocks, and SHALL NOT gate rendering or any core terminal behavior on the presence of marks.

#### Scenario: A full-screen app is recorded as opaque, not chopped into blocks
- **WHEN** the user runs a full-screen program that switches to the alternate screen mid-run (e.g. `vim`)
- **THEN** its full-screen drawing is not chopped into command blocks
- **AND** the command is finalized as a single opaque block, and normal block capture resumes after it exits

#### Scenario: A command started on the alternate screen creates no block
- **WHEN** a command's output-start (`C`) arrives while the session is already on the alternate screen
- **THEN** no command block is created for it

#### Scenario: Absent marks degrade to plain output
- **WHEN** a session produces output with no OSC 133 marks (e.g. inside tmux or a non-integrated ssh session)
- **THEN** the output is displayed normally and no blocks are created
- **AND** terminal rendering and input are unaffected

