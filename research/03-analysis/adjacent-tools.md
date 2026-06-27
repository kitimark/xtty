# Adjacent Tools — Agent Multiplexers & Terminal-Layer Tooling

> **Provenance:** Researched 2026-06-27 from official sites, GitHub, and Terminal Trove. These are **not terminal emulators** — they run *inside* an emulator (the layer `xtty` would host). Tracked here because the agent-orchestration layer directly shapes [agents-and-xtty](agents-and-xtty.md).

This file covers tools that sit between the terminal emulator and the user/agent — multiplexers, agent runtimes, orchestrators. They matter to `xtty` because they define what a great emulator should *host* and interoperate with.

---

## Herdr — terminal-native agent multiplexer

**TL;DR — "tmux for coding agents": persistent, agent-aware panes that run inside your existing terminal, with a socket API agents can drive themselves.** It is explicitly *not* a terminal emulator or desktop app.

### At a glance

| | |
|---|---|
| **Author** | ogulcancelik |
| **What it is** | Terminal-native **agent multiplexer** (runs inside any emulator) |
| **Language** | Rust (~90%), single binary, no external dependencies |
| **License** | Dual — AGPL-3.0-or-later (open source) + commercial licenses available |
| **Version** | 0.7.1 (June 2026), 65 releases |
| **Traction** | ~7.6k GitHub stars, 469 forks |
| **Platforms** | Linux + macOS (stable); Windows (preview beta) |
| **Install** | `brew install herdr`, mise, Nix, direct installer (auto-update, stable/preview channels) |
| **Links** | [herdr.dev](https://herdr.dev/) · [GitHub](https://github.com/ogulcancelik/herdr) · [compare](https://herdr.dev/compare/) |

### Problem it solves

Running multiple coding agents (Claude Code, Copilot CLI, Cursor Agent, …) in parallel is awkward: plain tmux gives persistence but has no idea what agents are *doing*; GUI managers (Warp-style) lock you to one machine and replace your terminal. Herdr adds **tmux-style persistence + semantic agent-awareness without replacing the terminal**, working anywhere you can ssh (reattach from mobile included).

### Key features

- **Server/client architecture** — background server owns the PTYs; detaching closes only the client, agents keep running; reattach from anywhere.
- **Workspaces → Tabs → Panes** — project-level organization over real terminal processes (not rewritten interpretations).
- **Agent-state sidebar** — per-agent status: 🔴 blocked / 🟡 working / 🔵 done / 🟢 idle. Detection via process-name matching + terminal-output heuristics; official integrations add native session identity + semantic state reporting.
- **Agent-shaped socket/CLI API** — `read, send, wait, split, attach` over a Unix socket. Agents orchestrate their *own* environment: create workspaces, spawn helper agents, read output. Bidirectional, not passive observation.
- **14+ officially supported agents** — Claude Code, GitHub Copilot CLI, Cursor Agent, Devin, Pi, and others.
- Mouse-native (click panes, drag borders, right-click split/switch), 18 themes, copy-friendly selection, optional screen-history restore on reattach, remote SSH with fallback keepalives, mobile-responsive TUI.

### Positioning (from its compare page)

- **vs tmux / Zellij** — adds semantic agent state they lack
- **vs Warp / cmux** — stays terminal-native instead of becoming a desktop app
- **vs Conductor / Emdash / Superset** — live terminal orchestration, not just git-worktree isolation + code review
- **vs Solo** — persistent interactive agent panes rather than general dev-stack supervision

### Why it matters for `xtty`

1. **Validates the "agent-host" model as a layer.** Herdr complements the Ghostty approach: a fast native emulator + Herdr inside it delivers persistence and agent-awareness *without* anyone building a Warp. A strong play for `xtty` is to be an excellent **host** for tools like Herdr, not to reinvent them.
2. **Its detection is a coarser cousin of OSC 133.** Herdr infers *whole-agent* state (working/blocked/done) from process names + output heuristics; OSC 133 gives precise *per-command* boundaries. If `xtty` emits clean shell-integration signals (OSC 7/133), tools like Herdr could detect state far more reliably than heuristics — a concrete interop win and an argument for building semantic capture early (see [agents-and-xtty](agents-and-xtty.md)).
3. **Confirms the thesis that the API is the substrate.** Herdr's socket API (`read/send/wait/split/attach`) is exactly the kind of agent-drivable surface the [agents-and-xtty](agents-and-xtty.md) note argues `xtty` should expose — and proves you don't need to be a full GUI app to deliver it.

---

## Related

- [Agents & xtty design note](agents-and-xtty.md)
- [Warp deep-dive](../01-terminals/warp.md) (the GUI-app, integrated-agent contrast)
- [Multiplexing & session features](../02-internals/07-multiplexing-sessions.md) (tmux fundamentals Herdr builds on)
