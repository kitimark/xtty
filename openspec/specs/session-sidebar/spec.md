# session-sidebar Specification

## Purpose

Defines xtty's at-a-glance per-session progress sidebar (requirements H1, the user's favorite Warp feature) — the first differentiator built on the P4a semantic-capture keystone. It covers the sidebar's `Tab ▸ Pane` structure (the key window's tab group), the view-free session-activity vocabulary (`idle`/`running`/`succeeded`/`failed`/`fullScreen`) and how each state is derived from the per-session block model plus the alternate-screen flag, the displayed fields (last command, live running duration), click behavior (clicking a pane row focuses it without scrolling; pane rows are expandable into a per-pane list of recent command blocks, and selecting a block focuses its pane and scrolls the viewport to that block — P4b-3), per-block menu actions (copy output / copy command / reveal working directory), the live "actionable" check that dims a block whose scroll/copy target no longer resolves (trimmed or epoch-stale), and the lean, event-driven update model (observe the registry revision; one self-pausing timer per running row). It is fully fork-free on SwiftTerm's public API; the keyboard in-terminal spatial operations (jump-to-prompt, copy-output) live in `terminal-spatial-blocks` (which the block list reuses for its scroll/copy), and view-layer visual on-screen selection remains the deferred P4b concern.
## Requirements
### Requirement: Session-progress sidebar

The application SHALL present a session-progress sidebar that lists the key window's panes grouped as a **`Tab ▸ Pane`** tree whose pane rows are **expandable to reveal that pane's recent command blocks** (a third `Tab ▸ Pane ▸ Block` level, collapsed by default), showing for each pane its current activity state, its most recent command (when known), and — for a running command — a live elapsed duration. The sidebar SHALL be hosted as SwiftUI chrome beside the AppKit terminal area (it contains no terminal view), SHALL be toggleable, and SHALL exclude the quick-terminal scratch session (which lives in a separate private registry). Activating (clicking) a **pane** row SHALL focus that pane — bringing its tab/window forward when it is not frontmost — and SHALL NOT scroll the terminal to any row (selecting a **block** row is specified separately and does scroll to the block).

#### Scenario: Sidebar lists tabs and their panes
- **WHEN** the key window has multiple tabs and a tab is split into multiple panes
- **THEN** the sidebar shows each tab with its panes nested beneath it, each pane row showing its activity state and last command

#### Scenario: Pane rows expand to reveal recent blocks
- **WHEN** a pane has captured command blocks and the user expands its row
- **THEN** the sidebar reveals that pane's recent command blocks nested beneath the pane row, and the row is collapsed by default until expanded

#### Scenario: Clicking a pane focuses it
- **WHEN** the user clicks a pane's row in the sidebar
- **THEN** that pane becomes the active/focused pane, its tab/window is brought forward if needed, and the terminal is not scrolled to any prompt row

#### Scenario: A running command shows live state and duration
- **WHEN** a command is executing in a pane
- **THEN** that pane's row shows the running state and an elapsed duration that advances while it runs

#### Scenario: The quick terminal is not listed
- **WHEN** the quick-terminal panel is open with its scratch session
- **THEN** the sidebar does not list the quick-terminal session among the window's panes

### Requirement: Session activity state derivation

`XttyCore` SHALL expose a view-free session activity state with the values **idle**, **running**, **succeeded**, **failed**, and **fullScreen**, derived from the per-session block model and the alternate-screen flag with a fixed precedence: fullScreen when the session is on the alternate screen; otherwise running when a command is in flight; otherwise failed when the most recent finished command had a non-zero exit; otherwise succeeded when the most recent finished command succeeded; otherwise idle. The derivation SHALL be a pure, unit-testable function that does not launch the app or create a terminal view.

#### Scenario: A failed last command yields a failed session state
- **WHEN** the most recent finished command in a session exited non-zero and the session is not on the alternate screen and nothing is currently running
- **THEN** the session activity state is failed

#### Scenario: A full-screen app overrides other states
- **WHEN** the session is on the alternate screen (e.g. running vim)
- **THEN** the session activity state is fullScreen regardless of the last command's exit code

#### Scenario: A fresh session is idle
- **WHEN** a session has produced no command blocks and nothing is running
- **THEN** the session activity state is idle

#### Scenario: Derivation runs without the app
- **WHEN** the test suite runs
- **THEN** the activity-state derivation (precedence over running/failed/succeeded/fullScreen/idle) is exercised by a unit test that does not launch the app or create a terminal view

### Requirement: Lean, event-driven sidebar updates

The sidebar SHALL update from observable model changes rather than polling: session and block transitions SHALL publish synchronously on the main actor (the semantic-capture handlers already run there), and the only periodic work SHALL be the live elapsed-duration display for running rows, which SHALL do no work when no command is running. The sidebar SHALL NOT introduce a global timer or background polling loop, honoring the lean-memory / latency-first product values.

#### Scenario: Idle sidebar does no periodic work
- **WHEN** no command is running in any listed pane
- **THEN** the sidebar performs no periodic duration updates

#### Scenario: State changes propagate without polling
- **WHEN** a command starts or finishes in a pane
- **THEN** the corresponding sidebar row reflects the new state from an observed model change, not from a poll

### Requirement: Per-pane command-block navigation

The sidebar SHALL list, under each expanded pane, that pane's recent command blocks ordered **newest-first** and bounded to the session's retained block history, each row showing a status indicator (matching the session-activity vocabulary), the command text, and its duration (a live elapsed timer while running); the in-flight running command SHALL appear as the newest selectable row. A pane with **no captured blocks** SHALL render as a plain, non-expandable row (no disclosure affordance). Selecting a block row SHALL **focus the block's pane** (bringing its tab/window forward when not frontmost) **and scroll that pane's viewport to the block**, without moving the cursor or creating a text selection. A per-block menu SHALL offer **copying the block's output**, **copying the block's command text**, and **revealing the block's working directory** (the latter unavailable when the block's working directory was never captured). A block whose scroll/copy-output target does not currently resolve to an addressable row — because its anchor is absent, invalidated (e.g. after a resize/reflow), or its row has been trimmed out of scrollback — SHALL remain listed as an informational record — its command, state, duration, and working directory stay shown — with its **scroll-to and copy-output actions disabled**, while copy-command and reveal-working-directory (which need no anchor) remain available; the disabled actions SHALL re-arm as new commands run.

#### Scenario: Selecting a block focuses its pane and scrolls to it
- **WHEN** the user selects a command block under a pane that is not currently focused, and the block has a usable anchor
- **THEN** that pane becomes focused (its tab/window brought forward if needed) and its viewport scrolls to the block, without moving the cursor or selecting text

#### Scenario: The running block is listed and selectable
- **WHEN** a command is currently running in a pane whose row is expanded
- **THEN** the running command appears as the newest block in that pane's list and can be selected to scroll to its prompt

#### Scenario: A pane with no blocks is not expandable
- **WHEN** a pane has no captured command blocks (a fresh shell, an uncooperative/no-integration host, or one that has run only alt-screen apps)
- **THEN** its sidebar row shows no disclosure affordance and reveals no block list

#### Scenario: A stale or trimmed block stays a record with its anchored actions disabled
- **WHEN** a listed block's anchor has been invalidated (e.g. by a resize) **or** its row has scrolled out of the bounded scrollback (trimmed) even though its anchor's epoch is still current
- **THEN** the block remains listed with its command, state, duration, and working directory, but its scroll-to and copy-output actions are disabled rather than scrolling to the top or silently copying nothing

#### Scenario: Copy-command and reveal-working-directory need no anchor
- **WHEN** the user opens a block's menu, including for a block whose scroll/copy-output anchor is unavailable
- **THEN** copy-command-text and reveal-working-directory are available and operate on the block's durable fields

