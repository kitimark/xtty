## MODIFIED Requirements

### Requirement: Mouse-wheel routing to the terminal

The terminal SHALL route a mouse-wheel gesture according to the focused pane's current mouse-reporting and screen state, so that full-screen programs that request the mouse scroll correctly instead of the gesture being silently swallowed. The routing SHALL follow this priority order:

1. **Mouse reporting active** — when the program has enabled a button-reporting mouse mode (VT200 / button-event / any-event tracking; X10-only and no-tracking states are excluded), a wheel notch SHALL be delivered to the program as a **wheel mouse-report** (the xterm wheel buttons — up/down — in the program's currently negotiated mouse encoding, reported as a press with no matching release), located at the cell under the pointer. This is what lets programs such as htop, vim, tmux, and fzf scroll.
2. **Alternate screen, mouse reporting off** — when the pane is on the alternate screen and no mouse reporting is active (e.g. a pager without mouse mode), a wheel notch SHALL be delivered as a **cursor Up/Down key**, honoring application-cursor-keys (DECCKM) mode (the application-cursor form when DECCKM is set, the normal form otherwise), so that pagers and editors on the alternate screen scroll by the wheel.
3. **Primary screen, mouse reporting off** — the wheel SHALL move the pane's **local scrollback viewport** (the existing behavior), unchanged.

Additionally: holding **Shift** while scrolling SHALL bypass mouse reporting and move the local scrollback viewport even when a program has mouse reporting active, so the user can always read scrollback under a full-screen program. A gesture with no vertical component SHALL NOT produce a vertical wheel report or scroll (horizontal wheel reporting is out of scope). The **inertial-coast (momentum) portion** of a trackpad or precise-pointer gesture SHALL be routed on the same branch as its finger-driven portion — it SHALL NOT be dropped — so scrolling retains the platform's native inertial coast after the fingers lift, on every branch (mouse-report, alternate-screen cursor-key, and local scrollback alike). Wheel emission SHALL be bounded by **whole-cell quantization**: precise sub-cell movement accumulates with a carried remainder that is **never discarded**, at most roughly one report/key is emitted per whole cell of travel, and the accumulated remainder SHALL reset at the start of each new user-driven gesture so it cannot leak across separate gestures — so a fast flick tracks the gesture's real distance without either losing travel or flooding the program, and the anti-flood bound is quantization, not a fixed per-gesture cap. This requirement extends the interactive-terminal behavior set without changing existing keyboard, resize, paste, scrollback, or selection behavior.

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

#### Scenario: Trackpad inertial coast keeps scrolling after the fingers lift

- **WHEN** the user flicks a trackpad (or precise pointer) over a focused pane and lifts their fingers so the gesture enters its inertial-coast (momentum) phase
- **THEN** the terminal keeps routing the coast on the gesture's branch — wheel reports to a mouse-tracking program, cursor keys on the alternate screen, or local-scrollback movement — until the coast decays, rather than stopping the instant the fingers lift

#### Scenario: A fast gesture does not lose scroll distance

- **WHEN** the user makes a fast precise-pointer gesture that accumulates several whole cells of travel within a short span
- **THEN** the terminal emits a report/key for each whole cell traversed and carries the sub-cell remainder forward, rather than discarding travel beyond a fixed per-event cap
