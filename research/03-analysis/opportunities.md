# Opportunities & Design Implications for `xtty`

> **Provenance:** Generated 2026-06-27 from a 39-agent research workflow (10-terminal survey + adversarial fact-check + 8 architecture deep-dives + synthesis), 281 web lookups. Claims marked surprising/marketing-flavored were independently fact-checked (see [fact-checks](../03-analysis/fact-checks.md)).

## The tradeoff spectrum (what you're choosing between)

- **Throughput vs input latency** — weakly correlated. vtebench measures only throughput and disclaims latency. Felt responsiveness is dominated by **frame pacing / vsync alignment**, not parse speed. Optimize the latency axis explicitly.
- **Features vs nativeness vs leanness** — iTerm2 maxes features (latency/RAM cost); Alacritty maxes leanness (offloads tabs/splits to tmux); Ghostty tries to refuse the tradeoff (native + Metal + low latency + good defaults) but is young. Electron terminals trade all performance for web-stack extensibility.
- **Native splits vs tmux** — native panes feel better but die with the app/SSH link; tmux's client/server design gives persistence + reattach + multi-client. iTerm2's `tmux -CC` control mode is the gold-standard bridge.

## Open / interesting opportunities

1. **Native Metal where rivals lag.** kitty and Alacritty rely on Apple's *deprecated* OpenGL — no native ProMotion 120Hz, worse power efficiency on Apple Silicon. A native-Metal renderer is a real differentiator (Ghostty already exploits this).
2. **Latency-first design.** Few terminals optimize the axis users actually feel. vsync-aligned frame pacing + a dedicated render thread is a credible "fastest *feeling*" claim that throughput benchmarks miss.
3. **Protocol unification.** Sixel / iTerm2 OSC 1337 / kitty graphics are fragmented, and tmux-passthrough for images is unsolved for most. kitty's Unicode-placeholder approach to multiplexer survival is worth building on.
4. **AI grounded in semantics, locally & privately.** Warp's agent loop is powerful but cloud-tied and proprietary. OSC 133 semantic capture + BYOK/local models (Wave's direction, done well) is open ground.
5. **Embeddable cores.** `libghostty` and `librio` point to terminals-as-libraries — a reusable C-ABI VT/render engine decoupled from the native GUI, letting one engine power many frontends. Arguably the most strategically interesting bet in the space.

## If building `xtty` (macOS-native) — the non-negotiable foundations

- **PTY plumbing:** master/slave pair via `posix_openpt`/`grantpt`/`unlockpt`/`ptsname` (or `forkpty`); the `setsid` + `TIOCSCTTY` controlling-terminal dance; `TIOCSWINSZ`/SIGWINCH for resize; a kqueue-driven read/write loop. Watch the macOS ~1024-byte canonical input buffer (chunk writes / bracketed paste).
- **VT parser:** don't hand-roll — reuse Paul Williams' DEC state machine via `alacritty/vte`, `vtparse`, or `libghostty-vt`. Keep syntactic parse separate from the semantic grid layer.
- **GPU rendering:** glyph atlas (grayscale + RGBA, maybe BGR subpixel), instanced draws, `CAMetalLayer` with correct `contentsScale` for Retina, damage tracking, ideally a dedicated render thread.
- **Text:** CoreText (native) or HarfBuzz (cross-platform parity); shape in style-batched runs for ligatures; wide/emoji 2-cell handling; grayscale AA with correct gamma (macOS dropped subpixel AA in Mojave/Big Sur).
- **Semantic capture (OSC 7 / 133) is foundational, not bolted-on** — every modern feature, including AI, depends on it.

## The one-paragraph thesis

GPU rendering is now commodity. The live frontiers are **native-platform integration** (Metal + real AppKit/SwiftUI), **latency over throughput**, and **semantic capture as the substrate for AI and IDE-like features**. Ghostty is the current high-water mark for "refuse the tradeoffs," Warp for "AI-native," iTerm2 for "feature-complete but aging" — and the embeddable-core trend may matter more in five years than any single app.
