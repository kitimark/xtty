## Context

P3a shipped the pane spine: a `PaneController` owns one `XttyTerminalView` (its own PTY + shell + engine) and registers a `Pane` in a `SessionRegistry`; the app reads its config once at startup (`XttyConfigLoader.parse` → `resolve` + `KeybindResolver.resolve`) in `AppDelegate`. A quake terminal reuses that spine for a single, persistent, globally-summoned scratch shell hosted in a special panel rather than a normal window.

This design was sharpened against the **shipped** P3a types (see `research/03-analysis/p3b-shell-ux-decisions.md` for the original explore-phase decisions, and the follow-up reconciliation that resolved its open questions). Three findings drive the decisions below: (1) `PaneController.init` hard-couples to a `SessionRegistry` and auto-registers, so exclusion needs a seam; (2) `KeybindParser` now exists with a reusable modifier-token grammar; (3) the global-hotkey path is fundamentally un-synthesizable by XCUITest.

Constraints: lean dependencies (a product value), no Accessibility/TCC permission prompt, keep `terminal-configuration`'s schema frozen for the upcoming profiles change, and the standing "main window opens on the built-in display" rule governs *main* windows, not this panel.

## Goals / Non-Goals

**Goals:**
- Toggle a drop-down scratch terminal with a configurable global hotkey, even when xtty is unfocused, with no TCC prompt.
- A persistent single shell that survives hide/show; lazily created on first summon.
- A view-free, unit-tested hotkey parser in `XttyCore`; only the OS binding is app-layer.
- The quake is an accessory: invisible to the `SessionRegistry`/future sidebar and to quit accounting; a hidden panel never keeps the app alive or blocks quit.
- Verifiable in CI via a DEBUG hook that drives the identical `toggle()` the hotkey does.

**Non-Goals:**
- Positioning/size/screen/autohide config keys (defaults only in v1).
- A split tree inside the quake (single pane only).
- A `quick-terminal-profile` key (waits on the profiles change).
- Layout-aware character translation (`UCKeyTranslate`) for the hotkey — positional virtual keycodes only.
- A persistent background/status-bar app that survives with zero main windows (a future identity shift, explicitly out of scope).

## Decisions

### D1 — Global hotkey via Carbon `RegisterEventHotKey`
Use HIToolbox `RegisterEventHotKey`. It registers the combo exclusively, fires when xtty is unfocused, and needs **no** Accessibility permission. Alternatives rejected: `NSEvent.addGlobalMonitorForEvents` (requires Accessibility, and cannot swallow the key), `CGEventTap` (Accessibility prompt + heavier). Carbon is deprecated but `RegisterEventHotKey` remains the canonical non-TCC global-hotkey API (Ghostty and others use it); the surface is tiny and isolated.

### D2 — Hand-rolled ~40-line shim, no SPM dependency
A small `@convention(c)` handler that bounces through an `Unmanaged` `self` pointer (passed as `userData`) into the controller. We do not add `soffes/HotKey`; the reuse-bias is aimed at the VT parser, not a trivial Carbon wrapper, and lean dependencies is a product value.

### D3 — `HotKeyParser` + `HotKeySpec` in XttyCore, reusing the modifier grammar
`HotKeyParser.parse(_:) -> HotKeySpec?` is pure and `swift test`-able. `HotKeySpec { virtualKeyCode: UInt32; carbonModifiers: UInt32; display: String }`.
- **Positional virtual keycodes**, not characters: a fixed name → `kVK_*` table (~60 entries: letters, digits, F-keys, common punctuation incl. `grave`, arrows, space, escape, tab, return). `cmd+grave` ⇒ `kVK_ANSI_Grave` (the physical backtick key, layout-independent). This is why `KeyChord` (character-based) can't be reused directly.
- **Carbon modifier masks** (`cmdKey`/`shiftKey`/`optionKey`/`controlKey`), not Cocoa flags. `fn` is not a standard Carbon modifier ⇒ rejected.
- **Shared grammar:** the modifier-token vocabulary and the structural rule (split on `+`, **≥1 modifier + exactly 1 non-modifier key**, fail-soft) are identical to `KeybindParser`. Factor the modifier-token recognizer into a small shared helper so the two parsers don't drift; they differ only in the final key→target mapping.

### D4 — A non-activating borderless `NSPanel`
`styleMask = [.nonactivatingPanel, .borderless]` so summoning does not activate xtty / deactivate the user's frontmost app, yet the panel can become key to receive typing; on hide, focus returns to the previous app automatically. `level = .mainMenu + 1`; `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]` so it appears over the current Space, including full-screen apps.

### D5 — Screen under the mouse, summon-to-active, recompute on show
Target the screen under the mouse pointer (quake convention). **Summon-to-active:** if the panel is visible on a *different* screen than the target, re-show it there; if already on the target screen, hide. Recompute the frame from the target screen on **every** show (never cache) so it survives resolution changes and monitor unplugs. Slide in from off-screen (top edge, default).

### D6 — Single pane v1, reusing `PaneController`
The quake hosts one `PaneController` (its own shell, config-applied, DEBUG dump) and skips the split tree. Splitting/tabs inside the quake are out of scope.

### D7 — Exclusion via a private `SessionRegistry` (no `PaneController` change)
`PaneController.init` requires a registry and auto-calls `makePane`. Rather than add an "ephemeral" flag or make the registry optional, the `QuickTerminalController` owns its **own private `SessionRegistry`**. The app's main registry then excludes the quake *by construction* — `allSessions` stays clean for P5, and `PaneController` is untouched. Cleaner than the explore note's vague "excluded from the registry."

### D8 — Accessory termination (stance i)
The quake is an accessory session. The app quits with its last *main* window even when the quake is enabled; the quake shell dies with it. A hidden panel MUST NOT keep the app alive or block quit. Implementation: the quake panel is not counted in the window/quit accounting that `terminal-multiplexing` escalation uses, and the panel does not adopt behaviors (e.g. a retained visible window) that would gate `applicationShouldTerminateAfterLastWindowClosed`-style logic.

### D9 — Config keys live in the `quick-terminal` capability
`quick-terminal` (bool, default off) and `quick-terminal-hotkey` (chord string, e.g. `cmd+grave`) are resolved from the **same** flat `[String:String]` map `AppDelegate` already parses once at launch — a dedicated resolver (mirroring `KeybindResolver`) reads these two keys. They are documented in `config.example` but do **not** enter the `XttyConfig` type or the `terminal-configuration` schema, following the precedent set by `terminal-keybindings` (which kept `keybind-*` out of `terminal-configuration`). Read-once at startup (P2 policy); editing needs relaunch.

### D10 — DEBUG toggle drives the real path
A `#if DEBUG` "Toggle Quick Terminal" menu action calls the *same* `toggle()` the hotkey handler calls. XCUITest cannot synthesize a true global hotkey, so this exercises the entire show/type/hide path minus the keypress. The harness asserts: the panel appears and accepts typed text (via the panel pane's grid dump), hides on a second toggle, and the **main** multiplexing inventory (pane/tab counts) is unaffected throughout — proving the registry exclusion.

### D11 — Fail-soft registration
An unparseable `quick-terminal-hotkey` **or** a `RegisterEventHotKey` returning non-`noErr` (e.g. a system-reserved combo like ⌘Space) ⇒ warn and disable the feature, never crash. We cannot enumerate reserved combos, so we handle a registration failure rather than try to predict it. Consistent with the config layer's fail-soft posture.

## Risks / Trade-offs

- **Carbon is deprecated** → Mitigation: `RegisterEventHotKey` is still supported and is the only non-TCC option; the shim is ~40 isolated lines, swappable if Apple ever removes it.
- **System-reserved or already-claimed combo** → Mitigation: D11 fail-soft — warn + disable, app still launches normally.
- **Non-activating focus hand-back** → Mitigation: rely on AppKit's automatic key-window restoration when an ordinary (non-activating) panel orders out; verify by manual/Peekaboo check (the focus *return* to another app is not assertable in XCUITest).
- **Global keypress is un-synthesizable in CI** → Mitigation: D10 DEBUG toggle covers the whole path except the OS keypress; the real keypress is a documented manual/Peekaboo check.
- **Multi-monitor summon + slide animation** are manual-only checks → Mitigation: keep frame computation pure where feasible and document the Peekaboo verification.

## Open Questions

- Exact slide animation (duration/easing) and whether v1 ships an animation at all or just an instant order-in — a polish call, not a blocker.
- Whether the shared modifier-token recognizer lands as a new small `XttyCore` helper or as an extension of `KeybindParser`'s internals — decide during apply when both parsers are in view.
