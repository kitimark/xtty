# Landscape Synthesis — Terminals in 2024–2026

> **Provenance:** Generated 2026-06-27 from a 39-agent research workflow (10-terminal survey + adversarial fact-check + 8 architecture deep-dives + synthesis), 281 web lookups. Claims marked surprising/marketing-flavored were independently fact-checked (see [fact-checks](../03-analysis/fact-checks.md)).

# Terminal Emulators in 2024–2026: A Synthesis

## 1. The Forces Reshaping the Space

Five trends define this era, and they reinforce each other.

**GPU rendering became the default, and Metal became the dividing line.** Treating the screen as a grid of cells stamped from a cached glyph atlas via instanced draws is now table stakes — Alacritty, kitty, WezTerm, Ghostty, Warp, and Rio all do it. But on macOS the meaningful distinction is *Metal vs. deprecated OpenGL*. Ghostty (native Metal), Warp (Metal), and WezTerm/Rio (Metal via WebGPU/wgpu) get ProMotion 120Hz adaptive sync and power efficiency on Apple Silicon; kitty and Alacritty still ride Apple's deprecated OpenGL compatibility layer and forfeit those benefits. Apple's own Terminal.app remains conspicuously CPU-bound (Core Text, no GPU) even in macOS 26.

**AI moved from feature to architecture.** Warp is the clearest case: it rebuilt the UI around "blocks" and an agentic loop, and its agent capability is only possible *because* the terminal captures command boundaries, output, and exit codes as structured data. Wave bolts on BYOK/local-model AI as a thinner layer over OpenAI. iTerm2 keeps AI at arm's length (separate plugin, your own API key). The lesson is that AI usefulness is downstream of semantic capture, not the other way around.

**Graphics protocols matured but stayed fragmented.** Three live standards — Sixel (DCS, palette-limited, no alpha), iTerm2's OSC 1337 inline images (send a whole file, simplest to produce), and the kitty protocol (APC-based, image IDs, reusable placements, z-ordering, shm transfer, animation, Unicode placeholders for tmux survival). kitty's is the most capable; WezTerm is notable as the only one speaking all three; Terminal.app supports none.

**Shell integration via OSC sequences became foundational infrastructure.** OSC 7 (cwd as a file:// URL) and OSC 133 (prompt/command/output/exit-code boundaries) let terminals understand an otherwise undifferentiated byte stream. This unlocks jump-to-prompt, per-command output selection, failed-command marking, and is the substrate AI agents read. iTerm2, WezTerm, Ghostty (1.3+), kitty, and VS Code all consume OSC 133.

**"IDE-ification."** Command palettes (popularized by VS Code's Cmd-Shift-P), clickable links/error matchers, completions, sticky prompts, and blocks blur the editor/terminal/IDE line — with Warp and VS Code's integrated terminal at the leading edge.

## 2. How the Terminals Cluster

- **Native-Mac, GPU-first:** Ghostty (SwiftUI/AppKit + true Metal, libghostty C-ABI core) and iTerm2 (mature Cocoa, optional Metal). These feel like Mac apps. Rio's experimental "Super Rio" (native Swift on librio) aspires to join.
- **Cross-platform GPU, non-native chrome:** Alacritty (minimalist, OpenGL, no tabs/splits by design), kitty (hackable platform, OpenGL, originated the graphics protocol + kittens), WezTerm (Lua-scriptable, built-in multiplexer, WebGPU/Metal), Rio (wgpu/Sugarloaf, even targets WASM/browser and FreeBSD). Same config everywhere; foreign-feeling menus and window chrome on macOS.
- **Electron / web-tech:** Wave (block/widget workspace with inline previews, xterm.js) and Hyper (React/Redux, npm plugin ecosystem, development effectively stalled since 2023). High memory (~400–800MB), latency penalties, no Metal.
- **AI-first / agentic:** Warp stands largely alone — native Rust + Metal, but a proprietary cloud/AI backend, blocks model, ~300–500MB footprint, and poor tmux interop.
- **First-party baseline:** Apple Terminal.app — zero-install, reliable, feature-conservative, CPU-rendered.

## 3. The Tradeoff Spectrum

**Speed is two axes, weakly correlated.** Throughput (PTY read/parse, what vtebench measures) and input latency (keypress-to-photon) diverge sharply: vtebench's own README disclaims measuring latency or frame rate. Dan Luu's hardware measurements found Alacritty fast on throughput yet ~31ms latency, while Terminal.app posted ~6ms latency on unremarkable throughput. iTerm2 is often the *slowest* on latency (~12ms reported) despite being the most feature-complete. The real lever for felt responsiveness is frame pacing/vsync alignment, not parsing speed (GNOME VTE's jump to near-Alacritty latency in v46 came from drawing every refresh instead of a 40Hz timer).

**Features vs. nativeness vs. leanness pull apart.** iTerm2 maximizes features (tmux control mode, triggers, Python API) at the cost of latency, memory, and complexity. Alacritty maximizes leanness (~20MB) by offloading tabs/splits to tmux. Ghostty is the rare attempt to refuse the tradeoff — native feel, Metal speed, low latency, good defaults — but is young (1.0 only Dec 2024) with a thinner ecosystem and no tmux control mode. Electron terminals trade all performance for web-stack extensibility and rich previews.

**The tmux axis is its own decision.** Native splits feel better but die with the app/SSH link because the emulator owns the PTYs; tmux's client/server design gives persistence, reattach, and multi-client sharing. iTerm2's `tmux -CC` control mode is the standout bridge — real tmux sessions rendered as native panes. Warp notably fights tmux; heavy multiplexer users should weigh this.

## 4. What to Understand Before Building One — and Where the Opportunities Are

**The non-negotiable foundations:**
- **PTY plumbing:** the master/slave pair, `posix_openpt`/`grantpt`/`unlockpt`/`ptsname` (or `forkpty`), the controlling-terminal dance (`setsid` + `TIOCSCTTY`), wiring stdio, `TIOCSWINSZ`/SIGWINCH for resize, and the kqueue-driven read/write loop. This is more subtle than it looks (e.g., EOF handling, SIGHUP on master close).
- **A robust VT parser:** don't hand-roll it. Use Paul Williams' DEC state machine (~14 states, total transition function so it never hangs on garbage) via a battle-tested library — alacritty/vte, vtparse, or Ghostty's zero-dependency, SIMD-optimized libghostty-vt. Keep the syntactic parser separate from the semantic grid/terminal layer.
- **GPU rendering details that bite:** glyph atlas with separate grayscale/RGBA/(BGR subpixel) formats, instanced draws, CAMetalLayer with correct `contentsScale` for Retina, Metal's downward +Y, shared vs. managed buffer storage by GPU architecture, and damage tracking (Alacritty redraws everything; kitty marks dirty lines; Ghostty snapshots dirty regions on a dedicated render thread).
- **Text is still hard on a grid:** CoreText (or HarfBuzz for cross-platform parity), shaping in style-batched *runs* to enable ligatures, monospace metrics from advance width, wide/emoji 2-cell handling, font fallback cascades, and grayscale-only AA with correct gamma blending (macOS dropped subpixel AA in Mojave/Big Sur).
- **Treat semantic capture (OSC 7/133) as foundational, not bolted-on** — every modern feature, including AI, depends on it.

**Open / interesting opportunities:**
- **Native Metal where rivals lag:** kitty and Alacritty's reliance on deprecated OpenGL is a standing gap on Apple Silicon — power efficiency and 120Hz are differentiators Ghostty already exploits.
- **Latency-first design:** few terminals optimize the axis users actually feel; proper vsync-aligned frame pacing plus a separate render thread is a credible "fastest *feeling*" claim that throughput benchmarks miss.
- **Protocol unification:** fragmentation across Sixel/iTerm2/kitty graphics and the tmux-passthrough problem is unsolved for most; kitty's Unicode-placeholder approach to multiplexer survival is worth building on.
- **AI grounded in semantics, locally and privately:** Warp's agentic loop is powerful but cloud-tied and proprietary; an open terminal that pairs OSC 133 capture with BYOK/local models (Wave's direction, done well) is open ground.
- **Embeddable cores:** libghostty and librio point toward terminals-as-libraries — reusable C-ABI engines that decouple the VT/render core from native GUIs, letting one engine power many native frontends. This is arguably the most strategically interesting architectural bet in the space.

The synthesis: GPU rendering is now commodity; the live frontiers are *native-platform integration* (Metal, real AppKit/SwiftUI), *latency over throughput*, and *semantic capture as the substrate for AI and IDE-like features*. Ghostty represents the current high-water mark for "refuse the tradeoffs," Warp for "AI-native," and iTerm2 for "feature-complete but aging" — and the embeddable-core trend may matter more in five years than any single app.
