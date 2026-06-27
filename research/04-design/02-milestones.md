# `xtty` Phased Build Plan

> **Provenance:** Drafted 2026-06-27 from the [stack sketch](01-stack-sketch.md), [requirements](../03-analysis/xtty-requirements.md), and [internals](../02-internals/) research. A milestone roadmap for the **All-Swift** primary stack — incremental, each phase ends in something you can run.

## Principle: thin vertical slice first

Get bytes flowing end-to-end (shell → PTY → VT engine → screen → input back) as early as possible, then deepen each layer. Avoid building any one layer "fully" before the whole loop works. Each milestone has a concrete **Done when** so you know it's finished.

Requirement tags reference [xtty-requirements](../03-analysis/xtty-requirements.md) (M = must-have, H = high-value, N = nice-to-have).

---

## Phase 0 — Skeleton
**Goal:** a buildable native macOS app window.
- Create the Xcode app / Swift package; one `NSWindow` with a blank `NSView`.
- Add **SwiftTerm** as a dependency (used headless later).
- Set up git workflow, basic CI/build, app entitlements.

**Done when:** the app launches and shows an empty window.
**Refs:** [stack sketch](01-stack-sketch.md)

## Phase 1 — "Hello PTY" (the byte loop)  ·  M5, M6 foundation
**Goal:** spawn a real shell and prove the read/write loop.
- `posix_openpt`/`grantpt`/`unlockpt`/`ptsname` (or `forkpty`); fork+exec `zsh` on the slave.
- kqueue-driven read loop: read master → log bytes. Write keystrokes → master.
- Set `TERM=xterm-256color`; basic env.

**Done when:** you can type a command, it runs in the shell, and raw output bytes appear in the Xcode console.
**Refs:** [01-pty-fundamentals](../02-internals/01-pty-fundamentals.md)
**Risks:** controlling-terminal dance (`setsid` then `TIOCSCTTY`); chunk writes (macOS ~1024-byte canonical buffer).

## Phase 2 — VT engine wired (text on screen)
**Goal:** parse the byte stream into a screen grid and draw it (naively first).
- Feed PTY bytes into SwiftTerm's headless `Terminal` core (parser + grid).
- Draw the grid with a placeholder path (e.g. `CATextLayer`/`NSAttributedString`) — correctness over speed for now.
- Handle the cursor, colors (16/256), basic line wrap.

**Done when:** `ls`, `vim`, and `htop` render legibly (even if slow/ugly).
**Refs:** [02-vt-ansi-parsing](../02-internals/02-vt-ansi-parsing.md)

## Phase 3 — Input & resize (interactive)  ·  M5
**Goal:** a genuinely usable interactive terminal.
- Keyboard → byte encoding (arrows `ESC[A`, modifiers, function keys, Alt/Meta).
- Window resize → recompute cols/rows → `TIOCSWINSZ` → SIGWINCH.
- Bracketed paste; copy/paste; mouse reporting (optional now).

**Done when:** you can run a full session — edit in vim, resize the window, paste multi-line text — without corruption.
**Refs:** [01-pty-fundamentals](../02-internals/01-pty-fundamentals.md), [07-multiplexing](../02-internals/07-multiplexing-sessions.md) (reflow notes)

## Phase 4 — Metal renderer (the real draw path)  ·  M4
**Goal:** replace the placeholder with a GPU cell renderer.
- `MTKView`/`CAMetalLayer`; glyph atlas rasterized via **CoreText**; instanced draws.
- Background → text → cursor passes; damage tracking; correct Retina `contentsScale`.
- Move rendering to a **dedicated render thread**, vsync-aligned (latency-first).

**Done when:** smooth scrolling, sharp text on Retina, fast `cat bigfile`, and ProMotion-smooth typing.
**Refs:** [03-gpu-rendering-metal](../02-internals/03-gpu-rendering-metal.md), [06-performance](../02-internals/06-performance-latency.md)
**Risks:** atlas eviction without frame stalls; subpixel vs grayscale AA (use grayscale + correct gamma on macOS).

## Phase 5 — Text quality & daily-driver baseline  ·  M5
**Goal:** good enough to use every day.
- CoreText shaping in style-batched runs; **ligatures** (opt-in); wide/emoji 2-cell handling.
- Truecolor (24-bit); configurable font/size/theme; sane defaults.
- **Scrollback** with a bounded default + cap; search.

**Done when:** you switch your own daily terminal to xtty and it doesn't annoy you.
**Refs:** [04-fonts](../02-internals/04-fonts-text-shaping.md), [07-multiplexing](../02-internals/07-multiplexing-sessions.md)

## Phase 6 — Native shell UX  ·  M6, N3
**Goal:** the native macOS conveniences.
- Native tabs, splits/panes; window management.
- (Optional) Quick-Terminal dropdown; profile/config file.
- Clickable links, file/error detection.

**Done when:** tabs + splits feel native and stable.

## Phase 7 — Semantic capture (OSC 7 / OSC 133)  ·  H3
**Goal:** the foundation for every differentiator.
- Parse and store OSC 7 (cwd) and OSC 133 (prompt/command/output/exit-code boundaries).
- Ship shell-integration snippets (zsh/bash/fish) + auto-injection with robust fallback.
- Internal "blocks" model: each command + output + exit code + cwd.

**Done when:** new splits open in the right cwd; you can jump-to-prompt and select one command's output; failed commands are marked.
**Refs:** [08-modern-innovations](../02-internals/08-modern-innovations.md), [agents-and-xtty](../03-analysis/agents-and-xtty.md)
**Risks:** fragile prompt hooks (Starship/p10k); tmux/ssh passthrough; alt-screen apps must NOT be chopped into blocks.

## Phase 8 — Session-progress sidebar  ·  H1 (the favorite feature)
**Goal:** at-a-glance per-session state — the thing you liked most in Warp.
- SwiftUI sidebar listing sessions/panes with state (idle / running / done / failed), derived from OSC 133 boundaries + exit codes.
- Click to focus; show last command / duration.

**Done when:** you can glance at the sidebar and see what each terminal is doing.
**Refs:** [adjacent-tools (Herdr)](../03-analysis/adjacent-tools.md) (state-sidebar model)

## Phase 9 — File / diff view  ·  H2 (the Zed habit)
**Goal:** lightweight in-terminal project files + git diff before commit.
- File-tree panel for the current project (cwd from OSC 7).
- Git status + diff view (read-only is fine first). Keep it *lightweight* — not a full IDE (non-goal).

**Done when:** you can browse files and review a diff without leaving xtty.

## Phase 10 — Polish: latency, memory, stability  ·  M1, M4
**Goal:** hit the lean + fast requirements deliberately.
- Latency pass: frame pacing, measure key-to-photon; tune the render thread.
- Memory pass: scrollback cap, atlas eviction, **retain-cycle/leak audit** (Instruments).
- Crash/stability hardening; notarization for distribution.

**Done when:** footprint stays lean (nowhere near Warp), typing feels instant, no leaks over a long session.
**Refs:** [06-performance](../02-internals/06-performance-latency.md), [xtty-requirements](../03-analysis/xtty-requirements.md)

---

## Later / opt-in (post-MVP)
- **Agent-drivable local API** (N1) — read/send/wait/split over a socket; model on [Herdr](../03-analysis/adjacent-tools.md).
- **Pluggable / BYOK + local-model AI**, off by default (N2) — "AI grounded in semantics, locally and privately."
- **Graphics protocols** (kitty/iTerm2/Sixel) ([05-graphics-protocols](../02-internals/05-graphics-protocols.md)).
- Reflow-on-resize refinement; tmux-control-mode-style integration (stretch).

## Suggested MVP line
**Phases 0–5 = a usable terminal.** **Phases 0–8 = an xtty that's distinctly yours** (lean, native, with the session sidebar). Phase 9+ are the editor-adjacent and agent extras.

## Critical path & dependencies
```
P0 → P1 → P2 → P3 → P4 → P5 → P6
                      └→ P7 → P8 (needs P7)
                              P9 (needs P7 cwd)
P10 polish spans P4–P9
```
P7 (OSC capture) is the keystone — P8 and P9 both depend on it, so don't defer it too long.

## Related
- [Stack sketch](01-stack-sketch.md) · [requirements](../03-analysis/xtty-requirements.md) · [agents-and-xtty](../03-analysis/agents-and-xtty.md)
