## Why

A "quake-style" drop-down terminal — summoned by a global hotkey from anywhere, even when xtty is unfocused — is the fastest path to a scratch shell and a signature native-macOS convenience. It is the smaller, self-contained half of P3b (the larger half, profiles, is a separate change): it depends only on the P3a pane spine (one persistent `PaneController`), touches no existing config schema, and gives a visible win while the schema stays frozen for the profiles work.

## What Changes

- **New global-hotkey drop-down panel.** A borderless, non-activating `NSPanel` that toggles in/out on a user-configured global hotkey, slides in from the top of the screen under the mouse, and hosts a single persistent scratch shell.
- **New config keys (in the `quick-terminal` capability, not `terminal-configuration`):** `quick-terminal` (on/off, default off) and `quick-terminal-hotkey` (the chord, e.g. `cmd+grave`). Read once at startup from the same config file, fail-soft. Positioning/size/screen/autohide/profile keys are deferred to defaults.
- **New view-free `HotKeyParser` in `XttyCore`** that turns a hotkey string into a toolkit-independent `HotKeySpec` (positional Carbon virtual keycode + Carbon modifier mask + display string), unit-testable without the app. The actual `RegisterEventHotKey` binding is the only app-layer, untestable piece. It reuses the modifier-token grammar already established by `KeybindParser`.
- **Accessory lifecycle.** The quake shell is lazily created on first summon and persists across hide/show. It is excluded from the `SessionRegistry` (so it never appears in the future P5 sidebar) and from app-termination accounting: a hidden panel never keeps the app alive or blocks quit, and the app still quits with its last *main* window even when the quake is enabled.
- **DEBUG harness hook.** A `#if DEBUG` "Toggle Quick Terminal" action that invokes the identical `toggle()` the hotkey does, so CI exercises the real show/type/hide path minus the un-synthesizable global keypress, and asserts the quake is excluded from the multiplexing inventory.

Non-goals for v1: positioning/size/screen/autohide config, a split tree inside the quake (single pane only), a `quick-terminal-profile` key (waits on the profiles change), and a persistent background/status-bar app identity that survives with no main windows (a future option, not this change).

## Capabilities

### New Capabilities
- `quick-terminal`: a global-hotkey drop-down ("quake") terminal — its config keys, the view-free hotkey parsing, the global-hotkey registration, the non-activating drop-down panel, the persistent single scratch shell, multi-monitor summon behavior, and the accessory (excluded, never-blocks-quit) lifecycle.

### Modified Capabilities
- `verification-harness`: extend the committed e2e coverage with a DEBUG "Toggle Quick Terminal" action (a real global hotkey can't be synthesized by XCUITest) that drives the actual `toggle()`, and assert the quake shows/accepts-typed-text/hides while staying excluded from the DEBUG multiplexing inventory.

## Impact

- **New `XttyCore` source:** `HotKeyParser` + `HotKeySpec` (pure, `swift test`-able); reuses the modifier-token vocabulary from the existing `KeybindParser`.
- **New app sources:** a Carbon `RegisterEventHotKey` shim (~40 lines, `@convention(c)` trampoline via an `Unmanaged` `self`), and a `QuickTerminalController` owning the `NSPanel`, a private `SessionRegistry`, and one `PaneController`.
- **Modified app sources:** `XttyApp`/`AppDelegate` (resolve the two new keys from the already-performed single config read; own the quake controller; register/unregister the hotkey; ensure the hidden panel doesn't gate quit), `MainMenu` (DEBUG toggle item).
- **Config:** two additive keys parsed from the existing flat key→value map; `config.example` documents them. No change to `terminal-configuration`'s schema or to the `XttyConfig` type.
- **Harness:** one DEBUG action + new XCUITest assertions; reuses the existing `-UITestGridDump` grid/state-dump channel.
- **Dependencies:** no new SPM dependency (hand-rolled Carbon shim, consistent with the lean-dependencies product value).
- **Platform:** uses Carbon HIToolbox `RegisterEventHotKey` (no Accessibility/TCC prompt, unlike global event monitors or a CGEventTap).
