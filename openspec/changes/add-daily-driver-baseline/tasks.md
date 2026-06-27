## 1. De-risk the menu/responder seam (spike first)

- [x] 1.1 Add a Find menu command and confirm Cmd+F reaches the AppKit key window's terminal view — **done via an AppKit `NSMenu` (`NSApp.mainMenu`), not SwiftUI `.commands`** (SwiftTerm's find needs an `NSMenuItem` sender + tag). Verified empirically: Cmd+F opens SwiftTerm's native find bar.
- [x] 1.2 No fallback needed — the AppKit menu + `target: nil` responder routing works and SwiftUI does not clobber `NSApp.mainMenu`. Chosen routing approach recorded in `design.md` (D5).

## 2. Config model in XttyCore (view-free)

- [x] 2.1 Define a toolkit-independent `XttyConfig` value (font family + size, theme name, scrollback, option-as-meta) with built-in defaults — no AppKit types (`XttyCore/XttyConfig.swift`)
- [x] 2.2 Implement the `key = value` line parser: `#` comments, blank lines, whitespace trimming; unknown keys ignored; invalid value → that key's default + warn callback (`XttyConfigLoader.parse`/`resolve`)
- [x] 2.3 Implement config file discovery: `$XDG_CONFIG_HOME/xtty/config` when set, else `~/.config/xtty/config`; missing/unreadable → all defaults (no crash) (`XttyConfigLoader.configPath`/`load`)
- [x] 2.4 Define the built-in theme palettes (default dark + light) as 16-ANSI + fg/bg/cursor RGB sets in `XttyCore`; unknown theme name → default (`TerminalTheme`)
- [x] 2.5 Unit tests (`swift test`): 19 tests covering missing file → defaults, parse w/ comments/whitespace, XDG override, unknown key ignored, invalid-value fallback, clamping, theme resolution — all view-free. **33/33 pass.**

## 3. Apply config to the live terminal (App layer)

- [x] 3.1 Map `XttyConfig` font (family + size) → `NSFont` and set `terminal.font` at launch (`TerminalConfigurator.makeFont`/`apply`)
- [x] 3.2 Map the resolved theme palette → SwiftTerm `Color` and install via `installColors` at launch; also set `nativeBackgroundColor`/`nativeForegroundColor`/`caretColor` (`TerminalConfigurator.apply`)
- [x] 3.3 Set the engine scrollback from config via `terminal.getTerminal().changeScrollback(config.scrollback)` with a finite default cap (default 10000, ceiling 100000)
- [x] 3.4 Set `optionAsMetaKey` from config (`TerminalConfigurator.apply`)
- [x] 3.5 Load the config once at startup in `TerminalWindowController` init (`XttyConfigLoader.load`) and apply 3.1–3.4 before `startProcess`. Verified end-to-end: light-theme config (white bg + Menlo 18) applied via `XDG_CONFIG_HOME`

## 4. Find in scrollback

- [x] 4.1 Add a Find menu group (Find / Find Next / Find Previous) wired to `#selector(NSTextView.performFindPanelAction(_:))` via `NSMenuItem` sender + tag (`showFindPanel`/`.next`/`.previous`), `target: nil` for responder routing (`MainMenu.swift`)
- [x] 4.2 Confirmed: Cmd+F opens the native find bar, a query locates a match (row highlighted), Return advances next match (row 2 → row 4), and Escape dismisses + restores terminal focus (typed input reaches the shell)

## 5. Live font sizing

- [x] 5.1 Added View-menu commands Cmd + / Cmd − / Cmd 0 → `AppDelegate` font handlers → `TerminalWindowController.adjustFontSize(by:)`/`resetFontSize()`, clamped to 6...72, resetting to the configured base size (ephemeral, not persisted). Verified: live increase + reset

## 6. Verify (harness)

- [x] 6.1 `XttyUITests.testFindBarOpensLocatesAndDismisses`: Cmd+F opens SwiftTerm's native find bar (matched by `searchFields.firstMatch` + the `Aa` option checkbox — no a11y IDs on the bar), query typed, Escape dismisses, and a post-dismiss marker reaches the grid (focus restored). Highlight captured via screenshot. **Passes.**
- [x] 6.2 `XttyConfigUITests`: `testConfigFileIsAppliedAtLaunch` injects a config via `XDG_CONFIG_HOME` and asserts theme/font/size/option-as-meta/scrollback-cap from the new DEBUG state dump; `testScrollbackIsBoundedUnderHeavyOutput` floods 5000 lines with `-UITestScrollback 200` and asserts scrollback depth saturates at exactly the cap (`depth == cap`, `bufferLines <= cap + rows`). **Both pass.**
- [x] 6.3 `XttyUITests.testTruecolorEmojiAndWideChars`: 24-bit truecolor via SGR (color screenshot-verified; text in grid), emoji 🚀/✅ + wide CJK 日本語 asserted via the **fixed** grid dump (`skipNullCellsFollowingWide` + `characterProvider` — without these CJK is NUL-separated and non-BMP emoji collapse to spaces). **Ligature finding:** SwiftTerm's default CoreText grid path applies no ligature substitution to the monospaced grid, so ligatures are a no-op for P2 (recorded; to be expanded in the §7 research note). **Passes.**

## 7. Metal renderer evaluation (no commitment)

- [x] 7.1 Spiked SwiftTerm's `setUseMetal(true)` behind a throwaway `-SpikeMetal` DEBUG flag: the experimental Metal path **renders correctly in xtty's AppKit NSWindow host** (truecolor/emoji/CJK/ANSI `ls`, not black — P1's black-render was SwiftUI-hosting-specific), `isUsingMetalRenderer == true`, stable. Key-to-photon/scroll left unmeasured (no instrumentation yet → deferred to P7). Throwaway flag removed.
- [x] 7.2 Wrote `research/03-analysis/swiftterm-metal-renderer-spike.md` (dated, indexed in `research/README.md`); default renderer unchanged (CoreGraphics). Decision stays at the P7 measurement gate, now with two measurable options (SwiftTerm Metal vs custom Metal view).

## 8. Sample config, docs, and trackers

- [x] 8.1 Added `config.example` (repo root) — every P2 key commented with its default + copy-to path (`~/.config/xtty/config`).
- [x] 8.2 Resolved design Open Questions in `design.md`: default **SF Mono 13** (nil family → `monospacedSystemFont`), **dark + light** themes (default dark), scrollback **10 000 default / 100 000 ceiling** (with M1 memory sanity note), **Cmd 0 = size only**. Values already reflected in code + `config.example`.
- [x] 8.3 Ticked all tasks; updated **Current status** + open-changes note in `AGENTS.md`; advanced Phase 2 to ✅ done in `research/04-design/02-milestones.md`; `openspec validate "add-daily-driver-baseline"` → **valid**. Ready to archive (`/opsx:archive`).
