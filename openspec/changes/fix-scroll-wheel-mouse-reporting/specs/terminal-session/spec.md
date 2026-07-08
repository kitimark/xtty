## ADDED Requirements

### Requirement: Mouse-wheel routing to the terminal

The terminal SHALL route a mouse-wheel gesture according to the focused pane's current mouse-reporting and screen state, so that full-screen programs that request the mouse scroll correctly instead of the gesture being silently swallowed. The routing SHALL follow this priority order:

1. **Mouse reporting active** — when the program has enabled a button-reporting mouse mode (VT200 / button-event / any-event tracking; X10-only and no-tracking states are excluded), a wheel notch SHALL be delivered to the program as a **wheel mouse-report** (the xterm wheel buttons — up/down — in the program's currently negotiated mouse encoding, reported as a press with no matching release), located at the cell under the pointer. This is what lets programs such as htop, vim, tmux, and fzf scroll.
2. **Alternate screen, mouse reporting off** — when the pane is on the alternate screen and no mouse reporting is active (e.g. a pager without mouse mode), a wheel notch SHALL be delivered as a **cursor Up/Down key**, honoring application-cursor-keys (DECCKM) mode (the application-cursor form when DECCKM is set, the normal form otherwise), so that pagers and editors on the alternate screen scroll by the wheel.
3. **Primary screen, mouse reporting off** — the wheel SHALL move the pane's **local scrollback viewport** (the existing behavior), unchanged.

Additionally: holding **Shift** while scrolling SHALL bypass mouse reporting and move the local scrollback viewport even when a program has mouse reporting active, so the user can always read scrollback under a full-screen program. A gesture with no vertical component SHALL NOT produce a vertical wheel report or scroll (horizontal wheel reporting is out of scope). Wheel emission SHALL be bounded — at most a small, whole-row number of reports/keys per gesture, with trackpad momentum collapsed — so a fast flick cannot flood the program with input. This requirement extends the interactive-terminal behavior set without changing existing keyboard, resize, paste, scrollback, or selection behavior.

#### Scenario: Wheel scrolls a mouse-tracking program on the alternate screen

- **WHEN** a program that has enabled button-event mouse reporting on the alternate screen (e.g. htop) is focused and the user scrolls the wheel over it
- **THEN** the terminal delivers a wheel mouse-report (up on scroll-up, down on scroll-down) to the program at the pointer cell, and the program scrolls — it does not stay motionless

#### Scenario: Wheel scrolls an alternate-screen program without mouse reporting

- **WHEN** a program on the alternate screen that has NOT enabled mouse reporting (e.g. a pager) is focused and the user scrolls the wheel
- **THEN** the terminal delivers cursor Up/Down keys to the program (in the application-cursor or normal form per DECCKM), and the program scrolls its content

#### Scenario: Wheel moves local scrollback when no program wants the mouse

- **WHEN** the pane is on the primary screen with no mouse reporting active and the user scrolls the wheel
- **THEN** the local scrollback viewport moves (earlier output comes into view on scroll-up), exactly as before this change

#### Scenario: Shift+wheel reads scrollback under a mouse-tracking program

- **WHEN** a program with mouse reporting active is focused and the user scrolls the wheel while holding Shift
- **THEN** no wheel mouse-report is sent to the program and the local scrollback viewport moves instead

#### Scenario: A purely horizontal gesture produces no vertical scroll

- **WHEN** the user makes a wheel/trackpad gesture with a horizontal component but no vertical component
- **THEN** the terminal emits no vertical wheel report and performs no vertical scroll
