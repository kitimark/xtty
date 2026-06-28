# `xtty` Phased Build Plan

> **Provenance:** Drafted 2026-06-27 from the [stack sketch](01-stack-sketch.md), [requirements](../03-analysis/xtty-requirements.md), and [internals](../02-internals/) research. **Re-mapped 2026-06-27** to the **SwiftTerm adoption decision: staged, start at Level 3** (see the stack sketch's Spike findings → Decision). Earlier drafts assumed a build-it-ourselves renderer; that work is now deferred to a *conditional* late phase.

## Principle: reuse the engine + view, build the differentiators

Starting at **Level 3** (wrap SwiftTerm's `TerminalView`), the PTY loop, VT parsing, rendering, input, selection, scrollback, search, and graphics protocols are **already done**. So the early milestones collapse into "integrate & configure," and real effort moves up to what makes xtty *xtty*: tabs/splits, OSC 133 blocks, the session sidebar, and the file/diff view.

**The load-bearing rule (set at P0):** all xtty logic talks to the **`Terminal` engine** (`view.getTerminal()`), never to `TerminalView` internals — so the render layer stays swappable and the L3→L1 escape hatch (P8) is a contained refactor, not a rewrite.

Requirement tags reference [xtty-requirements](../03-analysis/xtty-requirements.md) (M = must-have, H = high-value, N = nice-to-have).

---

## Phase 0 — Skeleton + the seam  ·  M2, M3  ✅ **done** (`add-app-skeleton`, archived)
**Goal:** a buildable native macOS app with the architecture's seam drawn.
- Xcode app (or generated project) + window; **App Sandbox OFF**, "Sign to Run Locally."
- Stand up **`XttyCore`** as a local SPM package (near-empty) — the engine-facing seam.
- Add **SwiftTerm** as a dependency.

**Done when:** the app launches an empty window and `swift build` is green.
**Refs:** [stack sketch](01-stack-sketch.md); sandbox detail in its Spike findings.

## Phase 1 — Integrate SwiftTerm → a working terminal  ·  M5, M6 *(collapses old P1–P3)*  ✅ **done** (`integrate-swiftterm`)
**Goal:** a real, interactive terminal, fast.
- Wrap SwiftTerm's `LocalProcessTerminalView` (PTY + view) in an `NSViewRepresentable`, hosted in the SwiftUI window.
- Spawn `zsh`; confirm input/resize/paste/selection/scrollback all work (SwiftTerm provides these).
- Expose the underlying `Terminal` via `getTerminal()` through `XttyCore` (enforce the seam now).

**Done when:** you can run `vim`/`htop`, resize, paste multi-line, scroll back, and select text — no corruption.
**Refs:** [01-pty-fundamentals](../02-internals/01-pty-fundamentals.md), [02-vt-ansi-parsing](../02-internals/02-vt-ansi-parsing.md)
**Note:** this single phase replaces the old "hello-PTY → VT engine → input/resize" sequence — all free via SwiftTerm.
**Shipped as:** the view is hosted in an **AppKit `NSWindow`**, *not* the planned SwiftUI `NSViewRepresentable` — SwiftTerm renders black under SwiftUI hosting on macOS 26 (both CoreGraphics and Metal paths). The window opens on the built-in display. See [`integrate-swiftterm/design.md`](../../openspec/changes/integrate-swiftterm/design.md). Interactive behaviors verified hands-on + via the XCUITest harness ([`add-verification-harness`](../../openspec/changes/add-verification-harness/design.md), [native-app testing tooling](../03-analysis/native-app-testing-tooling.md)).

## Phase 2 — Daily-driver baseline  ·  M5 *(collapses old P4–P5)*  ✅ **done** (`add-daily-driver-baseline`)
**Goal:** good enough to use every day — mostly *configure & verify*, not build.
- ✅ Font/size/theme config via `~/.config/xtty/config` (view-free loader in `XttyCore`); live Cmd +/−/0 font sizing. Confirmed 24-bit truecolor + wide/emoji (CJK 日本語, 🚀✅) via the harness; **ligatures are a no-op** in SwiftTerm's grid path (see [Metal spike note](../03-analysis/swiftterm-metal-renderer-spike.md)).
- ✅ Bounded **scrollback cap** (default 10 000 / ceiling 100 000), asserted saturating under a flood; Cmd+F find bar wired + verified.
- ✅ Evaluated SwiftTerm's experimental `setUseMetal` — works in the AppKit host; adoption deferred to the P7 latency gate ([spike note](../03-analysis/swiftterm-metal-renderer-spike.md)).

**Done when:** you switch your own daily terminal to xtty and it doesn't annoy you.
**Refs:** [04-fonts](../02-internals/04-fonts-text-shaping.md), [05-graphics-protocols](../02-internals/05-graphics-protocols.md) (Kitty/Sixel already supported)

## Phase 3 — Native shell UX  ·  M6, N3  *(P3a ✅ implemented; P3b ✅ implemented, archive pending)*
**Goal:** the multiplexing/native conveniences SwiftTerm's single view doesn't provide.
- ✅ **P3a (`add-tabs-and-splits`)** — native **tabs** (native `NSWindow` tabbing, Ghostty-style) + custom **splits/panes** (`NSSplitView` tree over a view-free `XttyCore` pane model) + multiple windows + unified close/exit escalation; **configurable keybindings** (`iterm`/`ghostty` presets + per-action overrides); clickable URL links (SwiftTerm-inherited; non-`http(s)` guard deferred). 52 unit + 12 UI tests green.
- ✅ **P3b** — Quick-Terminal dropdown (`add-quick-terminal`: global-hotkey quake panel, view-free `HotKeyParser`, accessory/private-registry exclusion) **and** profiles (`add-profiles`: named `[profile "name"]` bundles inheriting base, login-shell `command` wrap + `cwd` + additive `env`, per-pane profile identity + split inheritance, "New Tab with Profile" menu, quake on base, `confirm-close`; 91 unit + 14 UI tests green — archive pending); **file:line error-matching deferred to P4** (needs OSC 7 cwd). Decisions: [`p3b-shell-ux-decisions`](../03-analysis/p3b-shell-ux-decisions.md).

**Done when:** tabs + splits feel native and stable. *(P3a meets this; P3b adds the extras.)*

## Phase 4 — Semantic capture / blocks  ·  H3 *(keystone — old P7)*
**Goal:** the foundation for every differentiator.
- **OSC 7 cwd** is free (`hostCurrentDirectoryUpdated`) — use it for new-split cwd.
- Register **OSC 133** on the engine: `terminal.registerOscHandler(code: 133, …)`; parse A/B/C/D + exit code.
- Build the **blocks model** in `XttyCore`: each command + output range (engine buffer rows) + exit code + cwd. Ship shell-integration snippets (zsh/bash/fish) + auto-injection w/ fallback.

**Done when:** new splits open in the right cwd; you can jump-to-prompt, select one command's output, and failed commands are marked.
**Refs:** [08-modern-innovations](../02-internals/08-modern-innovations.md), [agents-and-xtty](../03-analysis/agents-and-xtty.md)
**Risks:** fragile prompt hooks (Starship/p10k); tmux/ssh passthrough; alt-screen apps must NOT be chopped into blocks.

## Phase 5 — Session-progress sidebar  ·  H1 *(the favorite feature — old P8)*
**Goal:** at-a-glance per-session state — what you liked most in Warp.
- SwiftUI sidebar listing sessions/panes with state (idle / running / done / failed), from OSC 133 boundaries + exit codes.
- **Bonus:** wire SwiftTerm's **OSC 9;4 progress** (`progressReport`/`Terminal.ProgressReport`) into the sidebar for live progress bars.
- Click to focus; show last command / duration.

**Done when:** you glance at the sidebar and see what each terminal is doing.
**Refs:** [adjacent-tools (Herdr)](../03-analysis/adjacent-tools.md) (state-sidebar model)

## Phase 6 — File / diff view  ·  H2 *(the Zed habit — old P9)*
**Goal:** lightweight in-terminal project files + git diff before commit.
- File-tree panel for the current project (cwd from OSC 7).
- Git status + diff view (read-only first). Keep it *lightweight* — not a full IDE (non-goal).

**Done when:** you can browse files and review a diff without leaving xtty.

## Phase 7 — Polish + MEASURE (decision gate)  ·  M1, M4 *(old P10)*
**Goal:** verify the lean + fast requirements with data — this gates Phase 8.
- **Measure** key-to-photon latency and memory (scrollback + atlas + panes) against M1/M4.
- If short: first flip `useMetalRenderer` + tune frame pacing (cheap); re-measure.
- Memory pass: scrollback cap, retain-cycle/leak audit (Instruments). Crash hardening.
- **Hardened Runtime + Developer ID + notarization** for distribution.

**Done when:** footprint is lean and typing feels instant — OR you've decided Phase 8 is needed.
**Refs:** [06-performance](../02-internals/06-performance-latency.md), [xtty-requirements](../03-analysis/xtty-requirements.md)

## Phase 8 — *(conditional)* Drop to Level 1: own Metal renderer  ·  M4
**Goal:** only if Phase 7 measurement misses the bar after cheap fixes.
- Replace SwiftTerm's view with an `MTKView`/`CAMetalLayer` renderer reading the **same engine** (`getCharData`/`getLine`/`CharData`), with glyph atlas (CoreText), instanced draws, damage tracking (`getScrollInvariantUpdateRange`), dedicated render thread.
- SwiftTerm's own `MetalTerminalRenderer` is the reference/vendoring source.

**Done when:** latency/memory meet M1/M4. **Skip entirely if Phase 7 already passes.**
**Refs:** [03-gpu-rendering-metal](../02-internals/03-gpu-rendering-metal.md)

---

## Later / opt-in (post-MVP)
- **Agent-drivable local API** (N1) — read/send/wait/split over a socket; model on [Herdr](../03-analysis/adjacent-tools.md).
- **Pluggable / BYOK + local-model AI**, off by default (N2).
- Graphics protocols are **already supported** (Kitty/Sixel) — just surface/polish.
- Reflow-on-resize refinement (engine handles the basics); tmux-control-mode-style integration (stretch).

## Suggested MVP line
**Phases 0–2 = a usable terminal** (much faster than the old plan — days/weeks). **Phases 0–5 = an xtty that's distinctly yours** (lean, native, with the session sidebar). Phase 6 = the editor-adjacent extra. Phase 8 is a *conditional* escape hatch, not default work.

## Critical path & dependencies
```
P0 → P1 → P2 → P3
              └→ P4 (keystone) → P5 (needs P4)
                                 P6 (needs P4 cwd)
P7 (measure) spans P1–P6  ──gate──▶  P8 (only if needed)
```
P4 (OSC capture) is the keystone — P5 and P6 depend on it. P8 is reachable cheaply *because* of the P0 engine seam.

## Related
- [Stack sketch](01-stack-sketch.md) (esp. Spike findings → Decision) · [requirements](../03-analysis/xtty-requirements.md) · [agents-and-xtty](../03-analysis/agents-and-xtty.md)
