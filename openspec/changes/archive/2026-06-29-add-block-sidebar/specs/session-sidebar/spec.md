## MODIFIED Requirements

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

## ADDED Requirements

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
