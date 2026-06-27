## 1. De-risk the menu/responder seam (spike first)

- [ ] 1.1 Add a Find menu command via SwiftUI `.commands` whose action is `performFindPanelAction:`, and confirm Cmd+F reaches the AppKit key window's terminal view (the SwiftUI→AppKit responder hop)
- [ ] 1.2 If the menu action does not reach the AppKit window, add a fallback (local key handling / `NSEvent` monitor in the terminal view) and keep the menu item for discoverability; record the chosen routing approach in `design.md`

## 2. Config model in XttyCore (view-free)

- [ ] 2.1 Define a toolkit-independent `XttyConfig` value (font family + size, theme name, scrollback, option-as-meta) with built-in defaults — no AppKit types
- [ ] 2.2 Implement the `key = value` line parser: `#` comments, blank lines, whitespace trimming; unknown keys ignored; invalid value → that key's default + logged
- [ ] 2.3 Implement config file discovery: `$XDG_CONFIG_HOME/xtty/config` when set, else `~/.config/xtty/config`; missing/unreadable → all defaults (no crash)
- [ ] 2.4 Define the built-in theme palettes (default dark + light) as 16-ANSI + fg/bg/cursor RGB sets in `XttyCore`; unknown theme name → default
- [ ] 2.5 Unit tests (`swift test`): missing file → defaults; parse with comments/whitespace; `XDG_CONFIG_HOME` override; unknown key ignored; invalid value fallback; theme name resolution — all without launching the app or a view

## 3. Apply config to the live terminal (App layer)

- [ ] 3.1 Map `XttyConfig` font (family + size) → `NSFont` and set `terminal.font` at launch
- [ ] 3.2 Map the resolved theme palette → SwiftTerm `Color` and install via `installColors` at launch
- [ ] 3.3 Set the engine scrollback from config **at terminal/engine creation** with a finite default cap (M1); confirm retention is bounded under heavy output
- [ ] 3.4 Set `optionAsMetaKey` from config
- [ ] 3.5 Load the config once at startup in `TerminalWindowController` init and apply 3.1–3.4 before/at `startProcess`

## 4. Find in scrollback

- [ ] 4.1 Add a Find menu group (Find / Find Next / Find Previous) wired to SwiftTerm's `performFindPanelAction:` / `showFindBar`
- [ ] 4.2 Confirm next/previous navigation, Escape/close dismissal, and focus returning to the terminal

## 5. Live font sizing

- [ ] 5.1 Add View-menu commands Cmd + / Cmd − / Cmd 0 → controller actions that adjust `terminal.font` size ephemerally; Cmd 0 resets to the configured size (not persisted to the file)

## 6. Verify (harness)

- [ ] 6.1 XCUITest: Cmd+F opens the find bar and a query locates a match (assert via grid dump / screenshot attachment)
- [ ] 6.2 Verify config is applied: bounded scrollback under heavy output, plus font/theme/option-as-meta in effect (grid dump + screenshot)
- [ ] 6.3 Verify 24-bit truecolor, emoji/wide-character handling, and ligatures (record the ligature finding — may be a no-op) via harness screenshots/grid dump

## 7. Metal renderer evaluation (no commitment)

- [ ] 7.1 Spike: toggle `useMetalRenderer` behind a throwaway flag; compare key-to-photon feel and scroll smoothness vs the default path
- [ ] 7.2 Write a dated `research/` note capturing the finding; leave the default renderer unchanged (decision stays with the P7 measurement gate)

## 8. Sample config, docs, and trackers

- [ ] 8.1 Add a commented example config (all P2 keys + defaults) so users can copy it to `~/.config/xtty/config`
- [ ] 8.2 Resolve the design Open Questions (default font/size, theme set, scrollback default + ceiling) and reflect the chosen values in code + example config
- [ ] 8.3 On completion: tick these tasks, update **Current status** in `AGENTS.md`, advance P2 in `research/04-design/02-milestones.md`, run `openspec validate "add-daily-driver-baseline"`, and prepare to archive
