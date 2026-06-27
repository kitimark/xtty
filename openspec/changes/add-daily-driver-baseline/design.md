## Context

P1 ships a live terminal hosted in a bare AppKit `NSWindow` (`TerminalWindowController`), with all engine access routed through `XttyCore` (the load-bearing seam). Every appearance/behavior choice is currently a SwiftTerm default: fixed font, default theme, SwiftTerm's default scrollback, no find UI. P2 ("daily-driver baseline") is billed as *configure & verify* — and a code audit confirms SwiftTerm already exposes the levers we need: `MacTerminalView.font: NSFont`, `installColors([Color])`, `TerminalOptions.scrollback: Int`, `optionAsMetaKey`, and a built-in macOS find bar (`MacFindBarView` via `showFindBar` / `performFindPanelAction`). So the work is wiring + a config layer, not terminal internals.

The user chose a **config-file** model (Ghostty-style `~/.config/xtty/config`) over hardcoded-defaults or a Settings window — it fits a dotfile-driven workflow and makes the schema a first-class P2 deliverable. Constraints: keep the `XttyCore` seam (config logic is view-free and unit-testable); honor product value **M1** (bounded scrollback); add no new dependencies.

## Goals / Non-Goals

**Goals:**
- A parsed, defaulted config file feeding font, theme, scrollback, and option-as-meta into the live terminal at launch.
- A view-free, unit-tested config component in `XttyCore` whose result is toolkit-independent (no AppKit types).
- Cmd+F find wired to SwiftTerm's native bar; Cmd +/−/0 live font sizing (ephemeral).
- A bounded default scrollback that satisfies M1.
- An evaluation of `useMetalRenderer` captured as a research note (no renderer commitment).

**Non-Goals:**
- A Settings/Preferences window UI; config hot-reload; named/multiple profiles; writing runtime changes back to the file; a large theme library or user-defined palettes (a small built-in set only). All deferred to P3+.
- Changing the default renderer or any P4 OSC capture work.

## Decisions

**D1 — Config format: hand-rolled `key = value`, not TOML/JSON.** A line parser (`#` comments, trim, `key = value`) is ~30 lines, dependency-free, and matches the Ghostty feel. Alternatives: TOML (adds a dependency for a flat file we don't need nested) or JSON (hostile to hand-editing). Forward-compat by ignoring unknown keys.

**D2 — Config lives in `XttyCore`, result is toolkit-independent.** `XttyCore` gains an `XttyConfig` (typed, resolved) plus a parser/loader. It expresses font as `(family, size)`, theme as a named palette of RGB triples, scrollback as `Int`, option-as-meta as `Bool` — **no `NSFont`/`NSColor`**. The App layer maps `XttyConfig` → `NSFont` and → SwiftTerm `Color` palette at apply time. This preserves the seam (core stays UI-free, unit-testable via `swift test`) and keeps the L3→L1 escape hatch clean.

**D3 — Theme = small built-in named set.** P2 ships a couple of built-in palettes (a good default dark, plus light) selected by `theme` name; each is a full 16-ANSI + foreground/background/cursor set defined as RGB in `XttyCore`, installed via `installColors`. User-defined palettes are out of scope. Unknown theme name → default theme (per the invalid-value fallback rule).

**D4 — Scrollback set at engine creation; finite default.** `TerminalOptions.scrollback` is applied when the `Terminal`/view is constructed (changing it post-hoc isn't reliable). Default cap is finite (target 10 000 lines) to honor M1; we disallow an "unlimited" setting in P2 — an out-of-range/huge value is clamped to a sane maximum. (Exact numbers in Open Questions.)

**D5 — Find + font menu commands route through an AppKit main menu (spike-confirmed).** The app keeps SwiftUI's `App` lifecycle, but the menu is built in **AppKit** (`XttyMainMenu`) and installed as `NSApp.mainMenu` in `applicationDidFinishLaunching` — *not* via SwiftUI `.commands`. Reason (found during the task-1 spike): SwiftTerm's `performFindPanelAction(_:)` requires the *sender* to be an `NSMenuItem` whose `.tag` selects show/next/previous; a SwiftUI `Button` closure can't supply that. A real `NSMenuItem` with `target: nil` travels the key window's responder chain straight to the terminal view (first responder). **Verified empirically:** Cmd+F opens SwiftTerm's native find bar, and the AppKit menu is not clobbered by SwiftUI. Find/Copy/Paste/Select-All items use `target: nil`; font-size items (`increaseFontSize:`/`decreaseFontSize:`/`resetFontSize:`) target the app delegate, which owns the controller. Live size changes are ephemeral overrides on top of the configured size; Cmd 0 resets to configured. **No responder-chain fallback was needed** (task 1.2).

**D6 — Metal renderer: evaluate, don't adopt.** Toggle `updateMetalRenderer(enabled:)` behind a throwaway flag, feel latency/scroll, and write a dated `research/` note (per the project's research convention). The renderer decision stays with P7's measurement gate.

## Risks / Trade-offs

- **SwiftUI-command → AppKit-window responder seam may not deliver Cmd+F** (same class of boundary that caused P1's black-render). → Verify early with a spike; if menu actions don't reach the AppKit key window, fall back to handling the shortcut in the terminal view directly (local key handling / `NSEvent` monitor) and keep the menu item for discoverability. This is the one item to de-risk first.
- **Scrollback can't be changed after creation** → set it from config at construction; document that a config change needs an app relaunch in P2 (no hot-reload anyway).
- **Ligatures may be a no-op** — SwiftTerm's CoreText path may not shape programming ligatures; the spec says "where the font supports them." Treat ligature support as a *finding to record*, not a guaranteed feature.
- **Theme fidelity** — a hand-picked palette can look off vs. a known scheme. Mitigation: base the default dark palette on a well-known scheme's RGB values; keep the set tiny so it's easy to get right.
- **option-as-meta default** — SwiftTerm defaults to `true`; we keep `true` as xtty's default to match common expectations (Option sends Meta for emacs/tmux). Configurable to `false` for users who want typographic Option characters.

## Open Questions (resolved)

- **Default font + size → SF Mono 13.** A `nil` `font-family` resolves to `NSFont.monospacedSystemFont(ofSize: 13)` (SF Mono on modern macOS) rather than hardcoding Menlo, so the default tracks the system monospaced face. `font-size` default is 13, clamped to 6…72.
- **P2 theme set → dark + light**, default **dark**. Both share the standard xterm 16-ANSI palette; an unknown `theme` name falls back to dark. (`TerminalTheme.builtIns`.)
- **Scrollback → default 10 000 lines, hard ceiling 100 000.** Values are clamped to `0…100 000`; "unlimited" is disallowed (M1). Memory sanity: at ~100 cols a stored line is a few KB, so the 10 000 default is on the order of tens of MB and the 100 000 ceiling stays in the low hundreds of MB worst-case — acceptable as a hard cap. (`XttyConfig.default.scrollback`, `XttyConfigLoader.scrollbackMax`.)
- **Cmd 0 resets size only**, not family. `resetFontSize()` rebuilds the font from the current descriptor at the configured base size, leaving the family untouched. (`TerminalWindowController.resetFontSize`.)
