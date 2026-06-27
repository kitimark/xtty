# Comparison Matrix

> **Provenance:** Generated 2026-06-27 from a 39-agent research workflow (10-terminal survey + adversarial fact-check + 8 architecture deep-dives + synthesis), 281 web lookups. Claims marked surprising/marketing-flavored were independently fact-checked (see [fact-checks](../03-analysis/fact-checks.md)).

## Core attributes

| Terminal | Lang | Renderer (macOS) | License | Platforms |
|---|---|---|---|---|
| **iTerm2** | Primarily Objective-C, with increasing S | Dual renderer: legacy CPU/Core Graphics path plus an optiona | GPL-2.0-or-later | macOS only |
| **Apple Terminal.app (macOS built-in)** | Objective-C / Cocoa (proprietary; source | CPU-based rendering via Cocoa/Core Text (no GPU/Metal accele | Proprietary (bundled with macOS; not sep | macOS only (built-in, ships with every m |
| **Ghostty** | Core terminal engine and Linux GUI in Zi | GPU-accelerated. Metal renderer on macOS; OpenGL on Linux. M | MIT | macOS, Linux (GTK) |
| **kitty** | C, Python, and Go (with some Objective-C | GPU-accelerated OpenGL; on macOS via deprecated OpenGL compa | GPL-3.0 | Linux, macOS, FreeBSD/some BSDs |
| **Alacritty** | Rust (~96% of codebase); dual-licensed A | GPU-accelerated via OpenGL (requires at least OpenGL ES 2.0) | Apache License 2.0 OR MIT (dual-licensed | macOS, Linux, Windows, BSD |
| **WezTerm** | Rust (~99% of codebase) | GPU-accelerated. Multiple backends: a WebGPU front end (uses | MIT License | macOS (Universal: Apple Silicon + Intel) |
| **Warp** | Rust (~98% of the open-sourced client),  | GPU-accelerated. On macOS it renders via Apple's Metal API ( | Source-available/open source as of April | macOS 10.14+ (Intel and Apple Silicon),  |
| **Rio Terminal** | Rust (~97% of codebase; rendering shader | GPU-accelerated via a custom renderer called "Sugarloaf" bui | MIT | macOS, Linux, Windows, FreeBSD, Web/brow |
| **Wave Terminal** | Go (~48%) backend + TypeScript (~43%) fr | CPU-based via Electron (Chromium) with xterm.js v6 for the t | Apache-2.0 | macOS 11+ (Apple Silicon arm64 and Intel |
| **Hyper** | TypeScript/JavaScript (Electron app; Rea | xterm.js inside Electron/Chromium | MIT | macOS (x64 and arm64), Windows (x64), Li |

## Differentiators (one-liner each)

| Terminal | What makes it distinct |
|---|---|
| **iTerm2** | The most feature-complete, deeply macOS-integrated terminal for power users, with best-in-class tmux control-mode integration and extensive scripting/automation. |
| **Apple Terminal.app (macOS built-in)** | The zero-install, Apple-supported default terminal that ships with macOS — maximally reliable and integrated, but feature-conservative compared to third-party emulators. |
| **Ghostty** | A terminal that refuses to trade off speed, features, or native-platform feel simultaneously, built on a reusable C-ABI core (libghostty) with a true Metal/SwiftUI macOS app rather than a cross-platform widget toolkit. |
| **kitty** | A "terminal as a platform": GPU-accelerated, highly hackable, and the originator of the kitty graphics protocol plus the kittens extension framework now influencing the broader terminal ecosystem. |
| **Alacritty** | A deliberately minimalist, GPU-accelerated terminal that does one thing — render text fast — and offloads tabs/splits/multiplexing to tools like tmux. |
| **WezTerm** | A fully cross-platform, Rust-based terminal that bundles a tmux-style multiplexer and deep Lua scripting into one GPU-accelerated app. |
| **Warp** | An AI-native, blocks-based terminal that has evolved into a full "agentic development environment" — combining a polished native terminal with multi-agent orchestration, rather than just a fast text grid. |
| **Rio Terminal** | A Rust, GPU-accelerated terminal with a custom Sugarloaf/wgpu renderer that targets desktops, FreeBSD, and the browser (WebAssembly) from one codebase, with an emerging embeddable engine (librio) and a native-Swift macOS frontend (Super Rio). |
| **Wave Terminal** | A block/widget-based terminal that pulls files, previews, an editor, a web browser, and AI into one workspace to eliminate context switching, rather than chasing raw rendering speed |
| **Hyper** | A fully web-tech terminal (Electron + React + Redux + xterm.js) whose entire UI and plugin/theme system is built and customized with HTML/CSS/JavaScript via npm. |

## Reading this table

- **Renderer** is the macOS dividing line: _native Metal_ (Ghostty, Warp, WezTerm/Rio via wgpu) gets ProMotion 120Hz + power efficiency; _OpenGL_ (kitty, Alacritty) rides Apple's deprecated compat layer; _CPU_ (Terminal.app) and _xterm.js/Electron_ (Wave, Hyper) leave performance on the table.
- See per-terminal deep-dives in [`../01-terminals/`](../01-terminals/) for strengths/weaknesses, macOS notes, and performance detail.
- "Speed" splits into throughput vs input latency — see [`../02-internals/06-performance-latency.md`](../02-internals/06-performance-latency.md).
