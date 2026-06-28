# `xtty` Research

Research library on terminal emulators — competitive landscape, internals, and design implications for building a macOS-native terminal (`xtty`).

> **Provenance:** Generated 2026-06-27 from a 39-agent research workflow (10-terminal survey + adversarial fact-check + 8 architecture deep-dives + synthesis), 281 web lookups. Claims marked surprising/marketing-flavored were independently fact-checked (see [fact-checks](../03-analysis/fact-checks.md)).

## How to navigate

### 00 — Overview (start here)
- [Landscape synthesis](00-overview/landscape-synthesis.md) — trends, how terminals cluster, the tradeoff spectrum
- [Comparison matrix](00-overview/comparison-matrix.md) — side-by-side attribute tables

### 01 — Terminals (deep dives)
- [iTerm2](01-terminals/iterm2.md) — The most feature-complete, deeply macOS-integrated terminal for power users, with best-in-class tmux control-mode integration and extensive scripting/automation.
- [Apple Terminal.app (macOS built-in)](01-terminals/apple-terminal.md) — The zero-install, Apple-supported default terminal that ships with macOS — maximally reliable and integrated, but feature-conservative compared to third-party emulators.
- [Ghostty](01-terminals/ghostty.md) — A terminal that refuses to trade off speed, features, or native-platform feel simultaneously, built on a reusable C-ABI core (libghostty) with a true Metal/SwiftUI macOS app rather than a cross-platform widget toolkit.
- [kitty](01-terminals/kitty.md) — A "terminal as a platform": GPU-accelerated, highly hackable, and the originator of the kitty graphics protocol plus the kittens extension framework now influencing the broader terminal ecosystem.
- [Alacritty](01-terminals/alacritty.md) — A deliberately minimalist, GPU-accelerated terminal that does one thing — render text fast — and offloads tabs/splits/multiplexing to tools like tmux.
- [WezTerm](01-terminals/wezterm.md) — A fully cross-platform, Rust-based terminal that bundles a tmux-style multiplexer and deep Lua scripting into one GPU-accelerated app.
- [Warp](01-terminals/warp.md) — An AI-native, blocks-based terminal that has evolved into a full "agentic development environment" — combining a polished native terminal with multi-agent orchestration, rather than just a fast text grid.
- [Rio Terminal](01-terminals/rio.md) — A Rust, GPU-accelerated terminal with a custom Sugarloaf/wgpu renderer that targets desktops, FreeBSD, and the browser (WebAssembly) from one codebase, with an emerging embeddable engine (librio) and a native-Swift macOS frontend (Super Rio).
- [Wave Terminal](01-terminals/wave.md) — A block/widget-based terminal that pulls files, previews, an editor, a web browser, and AI into one workspace to eliminate context switching, rather than chasing raw rendering speed
- [Hyper](01-terminals/hyper.md) — A fully web-tech terminal (Electron + React + Redux + xterm.js) whose entire UI and plugin/theme system is built and customized with HTML/CSS/JavaScript via npm.

### 02 — Internals (how to build one)
- [PTY Fundamentals — the byte shuffler](02-internals/01-pty-fundamentals.md)
- [VT/ANSI Escape-Sequence Parsing](02-internals/02-vt-ansi-parsing.md)
- [GPU Rendering & Metal (cell grid + glyph atlas)](02-internals/03-gpu-rendering-metal.md)
- [Fonts & Text Shaping](02-internals/04-fonts-text-shaping.md)
- [Graphics Protocols — Sixel / iTerm2 / kitty](02-internals/05-graphics-protocols.md)
- [Performance — Latency vs Throughput](02-internals/06-performance-latency.md)
- [Multiplexing & Session Features](02-internals/07-multiplexing-sessions.md)
- [Modern Innovations — Blocks, AI, OSC integration](02-internals/08-modern-innovations.md)

### 03 — Analysis
- [Fact-checks](03-analysis/fact-checks.md) — verified/refuted/uncertain claims with corrections
- [Opportunities & design implications](03-analysis/opportunities.md) — gaps and what they mean for `xtty`
- [Agents & xtty](03-analysis/agents-and-xtty.md) — the integrated-agents vs agent-host fork, and OSC 133 as the foundation
- [Adjacent tools](03-analysis/adjacent-tools.md) — agent multiplexers & terminal-layer tooling that xtty would host (Herdr, …)
- [Native-app testing tooling](03-analysis/native-app-testing-tooling.md) — how an agent drives/inspects a native macOS app (Peekaboo + XCUITest), and the AX-content ceiling that forces engine-grid assertions
- [SwiftTerm Metal renderer spike](03-analysis/swiftterm-metal-renderer-spike.md) — P2 finding: SwiftTerm's GPU path works in xtty's AppKit host; adoption deferred to the P7 latency gate
- [P3b shell-UX decisions](03-analysis/p3b-shell-ux-decisions.md) — explore-phase decisions for the deferred half of P3 (Quick-Terminal + Profiles); error-matching moved to P4
- [P4 semantic-capture decisions](03-analysis/p4-semantic-capture-decisions.md) — explore-phase decisions for the keystone (OSC 7 cwd + OSC 133 blocks): ship P4a (data model, fork-free) and defer P4b (jump/select/marks — needs a SwiftTerm fork); auto-inject zsh via `ZDOTDIR`; protocol grammar
- [xtty requirements](03-analysis/xtty-requirements.md) — the opinionated product target: must-haves, features, non-goals

### 04 — Design
- [Stack sketch](04-design/01-stack-sketch.md) — primary All-Swift stack + researched alternative stacks and when to switch
- [Milestones](04-design/02-milestones.md) — phased build plan, SwiftTerm L3-start (P0 skeleton → P1 integrate → P2 daily-driver → P4 OSC keystone → P5 sidebar → P7 measure → P8 conditional own-renderer)

### Reference
- [Consolidated sources](sources.md)

## Folder structure

```
research/
├── README.md                  # this file
├── 00-overview/               # synthesis + comparison
├── 01-terminals/              # one deep-dive per terminal
├── 02-internals/              # architecture topics (PTY, parsing, GPU, fonts, ...)
├── 03-analysis/               # fact-checks, opportunities, requirements
├── 04-design/                 # the build plan: stack sketch + alternatives
└── sources.md                 # deduped source URLs
```

## Conventions

- Each terminal/internals file carries a **Provenance** note and a **Sources** list.
- Fact-checked claims use ✅ confirmed / ❌ refuted / ❓ uncertain.
- Research snapshot date: **2026-06-27**. Version/latency/star-count figures are time-sensitive — re-verify before quoting.
