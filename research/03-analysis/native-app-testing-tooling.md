# Native-App Testing & Automation Tooling — How an Agent Drives a macOS GUI

> **Provenance:** Established 2026-06-28 during the P1 build (`integrate-swiftterm`) while wiring a verification harness, from **hands-on use on this machine** plus vendor docs/GitHub. Unlike the pre-build landscape research, most claims here were verified in practice (marked ✅). This file records the *landscape and why*; the concrete harness **decisions** live in the OpenSpec change [`add-verification-harness`](../../openspec/changes/add-verification-harness/design.md).

The question that started this: a web app has [chrome-devtools-mcp]/Playwright and Android has `adb`/`uiautomator` — what is the **macOS-native equivalent** for an agent to *inspect and drive* a native app, and can Claude Code do it at all? Short answer: Claude Code has no built-in native-AX bridge, but it can **shell out to CLIs and read screenshots**, which is enough to drive a native macOS app through the OS automation substrate.

---

## The substrate: everything sits on three OS primitives

Native macOS GUI automation reduces to three system facilities. Every tool below is a different wrapper over some combination of them.

| Primitive | What it does | Framework |
|---|---|---|
| **Accessibility (AX)** | Read the UI element tree (roles, values, identifiers); perform actions (press, focus) | `AXUIElement` / `ApplicationServices` |
| **Event synthesis** | Inject synthetic keyboard/mouse events | `CGEvent` (Quartz) |
| **Screen capture** | Pixels of a window/display | `CGWindowList` / `screencapture` / ScreenCaptureKit |

All three are **TCC-gated**: they require the *spawning* process (here, the host terminal — Warp) to hold **Accessibility** + **Screen Recording** permissions. ✅ (verified: grants are attributed to Warp, not to the tool it launches).

---

## The tooling landscape

| Tool | Layer | Reads content? | Injects input? | Verdict for xtty |
|---|---|---|---|---|
| **XCUITest** (`XCUIApplication`) | Apple first-party e2e | AX tree only | ✅ `typeKey`/`typeText` | **Committed e2e layer** — repeatable `xcodebuild test`; needs Aqua + TCC, not headless/CI-able |
| **Peekaboo** (CLI + MCP) | 3rd-party GUI automation | AX tree + screenshots | ✅ CGEvent (bg-inject or foreground) | **Manual/agent loop** — Claude Code shells out; not deterministic enough for CI |
| **ax-cli / AX dumpers** | raw AX tree dump | AX tree only | ❓ varies | Diagnostic only; same AX ceiling (below) ❓ |
| **AppleScript / `osascript`** | app scripting dictionary | only what the app exposes | via app's dictionary | N/A — xtty isn't scriptable, and won't be soon ✅ |
| **`cliclick` / raw CGEvent** | low-level input | ✗ | ✅ coordinates only | Too low-level; Peekaboo wraps this better |
| *[chrome-devtools-mcp]/Playwright* | web only | DOM | DOM | ❌ not applicable to a native app |
| *`adb` / `uiautomator`* | Android only | — | — | ❌ wrong platform |

**What we settled on:** **Peekaboo for manual/exploratory** driving (Claude Code shells out to the CLI) + **XCUITest for committed e2e**. Peekaboo install/config stays out of git; XCUITest is a real target in `project.yml`.

---

## The keystone finding: the AX-content ceiling

The decisive constraint, and the reason this isn't as simple as "use the accessibility tree":

> **A custom-drawn view exposes no per-cell content to Accessibility.** SwiftTerm's `LocalProcessTerminalView` rasterizes the grid itself (CoreText/Metal into a hand-managed `CALayer`); from AppKit's perspective it is **at most one opaque element** — no per-character text, cursor, or selection in the AX tree. ✅ (verified: `XCUIElement.value` yields nothing usable).

This ceiling is **permanent for this view type** and **tool-independent** — XCUITest, Peekaboo, and ax-cli all hit it, because they all read the same AX tree. It is the same family of problem as why SwiftTerm renders black under SwiftUI hosting (see [SwiftUI-hosting note] in the OpenSpec design): the content lives in a layer the standard macOS plumbing doesn't introspect.

**The escape hatch — assert against the engine, not the GUI.** xtty already routes the engine through `XttyCore.TerminalSession` (an observe-only handle to SwiftTerm's *headless* `Terminal` grid). That grid is the ground-truth content source, reachable **in-process without the GUI**. So content assertions read a `#if DEBUG`, launch-arg-gated **grid-dump** of the engine to a temp file; **screenshots** are the human/vision record; **AX identifiers** are used *only* to locate the view/window and route input. ✅ (4/4 XCUITest assertions pass on this channel; no TCC prompt needed).

```
        ┌─────────────── what the agent can reach ───────────────┐
 input  │  CGEvent  ──▶  view (AX id locates it)  ──▶  PTY        │
        │                     │ custom-drawn → AX sees 1 element  │
 truth  │   XttyCore.TerminalSession ──▶ headless Terminal grid ──┼─▶ grid-dump file
 pixels │   screencapture / Peekaboo image ─────────────────────▶│   (substring asserts)
        └────────────────────────────────────────────────────────┘
```

---

## Practical gotchas (verified on this machine)

- **Built-in-display coordinates.** xtty opens on the built-in display, which AppKit places in an off-main global coordinate region (origin ~2354,1292). Peekaboo flags the window **off-screen** and `peekaboo image` can come back blank. ✅ Reliable pixel capture: `screencapture -x -D <n>` of the built-in display; input still works via background injection to the PID.
- **Peekaboo `type` drops characters.** Per-character background injection races ("htop" → "ht"). ✅ Use `peekaboo paste "text" --foreground` for multi-char text; `press`/`hotkey` for keys/chords.
- **XCUITest TCC churn.** First `xcodebuild test` triggers a one-time runner approval; ad-hoc-signing churn on clean rebuilds can reset it (symptom: "typing did nothing"). ❓ (documented risk; pre-grant where possible).

---

## Why it matters for `xtty`

1. **The reliable test substrate is the engine + a debug channel, not the rendered pixels.** Any product that draws its own content (terminals, editors, canvases) inherits the AX-content ceiling. Keeping a clean engine seam (`XttyCore`) pays off twice: it's the architecture *and* the test oracle.
2. **Shell integration doubles as a test signal.** Once xtty emits OSC 7/133 (P4 keystone), command boundaries/cwd become assertable engine state — richer than scraping pixels. The agent-host thesis ([agents-and-xtty](agents-and-xtty.md)) and the testability thesis converge on the same "expose semantic state" move.
3. **A future own-renderer owns its own accessibility.** If xtty ever builds a custom Metal renderer (P8 conditional), the AX-content ceiling becomes *ours to fix* — we could expose real per-cell accessibility that SwiftTerm doesn't. A genuine differentiation opportunity, not just a chore. → see [opportunities](opportunities.md).

---

## Related

- OpenSpec change: [`add-verification-harness`](../../openspec/changes/add-verification-harness/design.md) — the decisions, target wiring, and example commands
- [Agents & xtty](agents-and-xtty.md) — the "expose agent-drivable semantic state" thesis
- [Opportunities](opportunities.md) — own-renderer / accessibility differentiation
- Build plan: [Milestones](../04-design/02-milestones.md) — P4 OSC keystone, P8 conditional own-renderer

## Sources

- Peekaboo — [github.com/steipete/peekaboo](https://github.com/steipete/peekaboo) (v3.5.2; Homebrew tap `steipete/tap`)
- Apple — [XCUIApplication / XCTest UI testing](https://developer.apple.com/documentation/xctest/user-interface-tests)
- Apple — [Accessibility (`AXUIElement`)](https://developer.apple.com/documentation/applicationservices/axuielement_h) · [`CGEvent`](https://developer.apple.com/documentation/coregraphics/cgevent)
- Contrast: [chrome-devtools-mcp](https://github.com/ChromeDevTools/chrome-devtools-mcp) (web) · Android [`adb`/UI Automator](https://developer.android.com/training/testing/other-components/ui-automator) (Android)

[chrome-devtools-mcp]: https://github.com/ChromeDevTools/chrome-devtools-mcp
[SwiftUI-hosting note]: ../../openspec/changes/integrate-swiftterm/design.md
