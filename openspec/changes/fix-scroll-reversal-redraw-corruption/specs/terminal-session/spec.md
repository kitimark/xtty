## MODIFIED Requirements

### Requirement: Interactive terminal input and output

The terminal SHALL support the core interactions of a usable terminal: keyboard input, window resize, multi-line paste, scrollback, and text selection, without display corruption. This SHALL include redraw correctness for a full-screen program's own scroll-driven redraws — not only the terminal's own resize/reflow — so that a full-screen program that scrolls its own content (e.g. via a mouse-wheel gesture routed to it) continues to display correctly across repeated redraws, including when the scroll direction reverses.

#### Scenario: Keyboard input reaches the shell

- **WHEN** the terminal is focused and the user types a command and presses Return
- **THEN** the command runs in the shell and its output is displayed

#### Scenario: Resize reflows and updates the PTY

- **WHEN** the window is resized
- **THEN** the terminal's columns/rows update to match the new size
- **AND** a full-screen program (e.g. `vim` or `htop`) redraws correctly at the new size

#### Scenario: Multi-line paste does not auto-execute

- **WHEN** the user pastes multi-line text into a shell that has enabled bracketed paste
- **THEN** the text is inserted as input and is not executed line-by-line until the user submits it

#### Scenario: Scrollback and selection

- **WHEN** output exceeds the visible area
- **THEN** the user can scroll back to view earlier output
- **AND** the user can select text without corrupting the display

#### Scenario: Wheel-driven scroll reversal over a full-screen program does not corrupt its redraw

- **WHEN** a full-screen mouse-tracking program (e.g. `htop`) is scrolled via a wheel gesture some distance in one direction, and the gesture then reverses direction
- **THEN** the program's display continues to show correct content after the reversal — no stale characters from earlier scroll positions persist in place of what the program actually drew, and no row appears duplicated at two positions
- **AND** this holds for the shallowest possible reversal (a single wheel notch each direction), not only a deep scroll
