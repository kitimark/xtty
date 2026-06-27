## Why

P1 gave us a real, interactive terminal — but every visible choice is a SwiftTerm default: a fixed font, a default theme, an unbounded-by-our-standards scrollback, and no way to search output or tune behavior. That blocks the P2 milestone goal: *switch your own daily terminal to xtty and have it not annoy you.* It also leaves a hard product value unmet — **lean memory (M1)** depends on a deliberately bounded scrollback, which we have not set. This change makes xtty configurable enough to daily-drive, in a way that fits a dotfile-driven workflow.

## What Changes

- **Add a config file** at `~/.config/xtty/config` (`$XDG_CONFIG_HOME` respected), Ghostty-style `key = value` lines with `#` comments. Read once at launch; a missing file means all-defaults.
- **Define the P2 config schema:** `font-family`, `font-size`, `theme`, `scrollback`, `option-as-meta`. Unknown keys are ignored (forward-compatible); an invalid value falls back to that key's default (and logs), never aborting startup.
- **Apply config to the live terminal:** resolve an `NSFont` from family+size, install a theme color palette, set the engine's scrollback cap **at creation**, and set option-as-meta.
- **Bound scrollback (M1):** default to a sane finite cap (e.g. 10 000 lines) instead of the SwiftTerm default — satisfying the lean-memory product value.
- **Find in scrollback:** wire **Cmd+F** to SwiftTerm's built-in native find bar (`showFindBar` / `performFindPanelAction`) plus next/previous and close, via the app's menu/responder chain.
- **Live font sizing:** **Cmd +**, **Cmd −**, **Cmd 0** adjust the current session's font size as an ephemeral override on top of the config value (not written back to the file in P2).
- **Verify, don't build:** confirm 24-bit truecolor, emoji/wide-character, and (where the font supports them) ligature handling render correctly — asserted through the existing verification harness.
- **Evaluate (no commitment):** flip SwiftTerm's experimental `useMetalRenderer`, note latency/feel, and capture the finding as a `research/` doc. The default renderer choice is **not** changed by this milestone.

Non-goals (deferred): a Settings/Preferences window UI; config hot-reload on file change; multiple/named profiles; writing runtime changes back to the config file; per-theme custom palettes beyond a small built-in set. These belong to P3 (profiles) or later.

## Capabilities

### New Capabilities
- `terminal-configuration`: discovery and parsing of the xtty config file, the P2 configuration schema with defaults and per-key fallback, a view-free config component in `XttyCore`, and application of the resolved config (font, theme palette, scrollback cap, option-as-meta) to the live terminal — including ephemeral live font-size adjustment.

### Modified Capabilities
- `terminal-session`: add **find-in-scrollback** as a supported interaction (Cmd+F opens SwiftTerm's native find bar; next/previous/close), extending the existing interactive-terminal behavior set.

## Impact

- **Code:** new config parser + schema in `XttyCore` (view-free, unit-tested via `swift test`); `TerminalWindowController` reads the resolved config and applies font/theme/scrollback/option-as-meta and owns Find + live-resize actions; `XttyApp` adds menu commands (Find, font size) that route through the AppKit window's responder chain.
- **Dependencies:** none new — uses SwiftTerm's existing `font`, `installColors`, `TerminalOptions.scrollback`, `optionAsMetaKey`, and find-bar APIs.
- **Product values:** advances **M1** (bounded scrollback) and **M5** (native macOS feel + keep-your-setup, now extended to xtty's own dotfile-style config).
- **Tests/harness:** add XCUITest coverage for find and (config-applied) behavior where assertable via the grid-dump channel; truecolor/emoji verification recorded via screenshots/grid dump.
- **Docs:** update `research/04-design/02-milestones.md` (P2 state) and add a `research/` note for the Metal-renderer evaluation, per the project's research/progress conventions.
