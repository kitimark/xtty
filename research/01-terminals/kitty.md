# kitty

> **Provenance:** Generated 2026-06-27 from a 39-agent research workflow (10-terminal survey + adversarial fact-check + 8 architecture deep-dives + synthesis), 281 web lookups. Claims marked surprising/marketing-flavored were independently fact-checked (see [fact-checks](../03-analysis/fact-checks.md)).

**TL;DR — A "terminal as a platform": GPU-accelerated, highly hackable, and the originator of the kitty graphics protocol plus the kittens extension framework now influencing the broader terminal ecosystem.**

## At a glance

| | |
|---|---|
| **Developer** | Kovid Goyal (creator of Calibre); maintained as an open-source project with 400+ contributors |
| **First released** | 2017 |
| **Language** | C, Python, and Go (with some Objective-C for macOS and GLSL shaders) |
| **License** | GPL-3.0 |
| **Platforms** | Linux, macOS, FreeBSD/some BSDs |
| **Renderer** | GPU-accelerated OpenGL; on macOS via deprecated OpenGL compatibility layer (no native Metal) |

## Key features

- GPU-based glyph rendering with cached glyphs and a separate rendering thread
- Kitty graphics protocol for displaying images/PNG/JPEG/GIF in the terminal (via icat kitten); protocol since adopted by Ghostty, WezTerm and others
- Tiling layouts: split/tab multiple windows side by side in different layouts
- Kittens extension framework (small terminal programs) e.g. icat, diff, unicode_input, hints, ssh, clipboard
- True color, OpenType ligatures, Unicode, mouse protocol, focus tracking, bracketed paste
- Kitty keyboard protocol (disambiguated/extended key reporting)
- Remote control over a socket for scripting
- Cross-session/cross-machine config and startup sessions
- Ligature and font fallback control, per-glyph font features

## Strengths

- Class-leading throughput: docs claim it is roughly twice as fast as the next-best terminal at parsing/processing output (~134 MB/s vs ~62 MB/s for gnome-terminal in their benchmark)
- Very low keyboard-to-screen latency (third-party tests rate it best-in-class on Linux; ties Terminal.app on macOS)
- Rich, mature feature set and extensibility via kittens
- Originated the now widely-adopted kitty graphics protocol
- Highly configurable; powerful remote-control/scripting
- Smooth scrolling at low CPU cost

## Weaknesses

- On macOS relies on deprecated OpenGL rather than native Metal, so no native ProMotion 120Hz / adaptive sync and less power-efficient than Metal-based terminals like Ghostty
- Limited native macOS UI conventions; configuration is text-file based with no GUI settings
- Opinionated design choices (e.g. its own protocols) can clash with user expectations
- No native Windows support (WSL only)
- Steeper learning curve than Terminal.app or iTerm2

## macOS notes

Fully supported on macOS (Intel and Apple Silicon) with a native .app bundle and Homebrew distribution, and some Objective-C for OS integration. However, rendering uses OpenGL via Apple's deprecated compatibility layer rather than Metal, so it lacks native ProMotion/adaptive-sync benefits and is less power-efficient on Apple Silicon than Metal-native terminals. Latency on macOS is reported as among the best (tying Apple's Terminal.app). It does not adopt many native macOS UI conventions (config is via kitty.conf text file).

## Performance notes

Official docs emphasize optimizing perceived typing latency, scrolling smoothness, and CPU usage. Claims: ~2x throughput vs next-best terminal (134.55 MB/s avg vs gnome-terminal 61.83 MB/s in their own benchmark); best-in-class keyboard-to-screen latency in third-party Typometer tests on Linux; on macOS ties Terminal.app for best latency. Independent 2025-2026 reviews put kitty's key-to-screen latency around ~3ms, effectively tied with Alacritty and just behind/at Ghostty. Kitty itself notes benchmark caveats (rendering suppressed, feature parity differences between terminals).

## Fact-checks

#### ✅ CONFIRMED

**Claim:** kitty's own performance docs claim it is 'twice as fast as the next best' terminal in throughput (134.55 MB/s vs gnome-terminal 61.83 MB/s) - this is a self-reported benchmark with acknowledged methodological caveats (rendering suppressed, uneven feature support), so treat as vendor-favorable rather than neutral.

**Finding:** All elements of the claim are directly supported by kitty's official performance documentation (sw.kovidgoyal.net/kitty/performance), which is self-published by kitty's author Kovid Goyal. The docs state verbatim "kitty is twice as fast as the next best" and list kitty 0.33 at 134.55 MB/s average throughput versus gnome-terminal 3.50.1 at 61.83 MB/s. The methodological caveats are explicitly acknowledged: (1) the benchmark kitten by default suppresses actual rendering "to better focus on parser speed"; (2) gnome-terminal, konsole and xterm do not support the Synchronized update escape code used to suppress rendering, and "if and when they gain support for it their numbers are likely to improve by 20-50%"; (3) uneven feature support is noted (e.g., Alacritty "isn't remotely comparable to any of the other terminals feature wise without tmux"). Measurements used the same font, font size, window size, default settings, and same computer. One minor nuance: this is a true/throughput-only benchmark of parser speed, not a holistic real-world performance measure, and the figures are version-specific (kitty 0.33), so they may shift with releases. Treating the benchmark as vendor-favorable rather than neutral is appropriate given it is published by the project itself.

**Sources:**
- https://sw.kovidgoyal.net/kitty/performance/
- https://github.com/kovidgoyal/kitty/blob/master/docs/performance.rst

#### ✅ CONFIRMED

**Claim:** Claim that kitty has 'best-in-class' keyboard-to-screen latency - true in some third-party Linux Typometer tests, but on macOS it reportedly only ties Apple Terminal.app, and 2025-2026 reviews show Ghostty/Alacritty as roughly equal, so 'best' is contested/context-dependent.

**Finding:** The claim is accurate and, if anything, understates how contested "best-in-class" is. Key nuances: (1) The "best-in-class" / "far and away the best" framing originates primarily from kitty's OWN documentation (sw.kovidgoyal.net/kitty/performance), which cites unspecified third-party Typometer measurements rather than being an independent consensus. (2) The macOS "tie" is also self-reported by kitty's docs: "kitty and Apple's Terminal.app share the crown for best latency" (measured at default input_delay of 3ms). (3) 2025-2026 reviews consistently place kitty, Alacritty, Ghostty and foot in a single "fastest" cohort with only ~5-15% differences that are imperceptible in real use; some give Ghostty a slight edge (~2ms key-to-screen). (4) Critically, at least one independent third-party Linux benchmark (beuke.org) directly contradicts "best-in-class": it measured Alacritty at ~6.9ms, xterm ~5.3ms, st ~5.2ms, versus kitty ~23.8ms in default config and ~10.7ms even when tuned -- i.e., kitty ranked behind several competitors. So "best" is genuinely context-dependent (default vs tuned config, OS, measurement method) and partly a vendor self-claim.

**Sources:**
- https://sw.kovidgoyal.net/kitty/performance/
- https://beuke.org/terminal-latency/
- https://github.com/ghostty-org/ghostty/discussions/4837
- https://blog.codeminer42.com/modern-terminals-alacritty-kitty-and-ghostty/
- https://www.lkhrs.com/blog/2022/07/terminal-latency/
- https://news.ycombinator.com/item?id=39967335


## Sources

- https://github.com/kovidgoyal/kitty
- https://sw.kovidgoyal.net/kitty/
- https://sw.kovidgoyal.net/kitty/performance/
- https://en.wikipedia.org/wiki/Kitty_(terminal_emulator)
- https://medium.com/@dynamicy/choosing-a-terminal-on-macos-2025-iterm2-vs-ghostty-vs-wezterm-vs-kitty-vs-alacritty-d6a5e42fd8b3
- https://akmatori.com/blog/ghostty-vs-kitty-comparison
- https://vibehackers.io/blog/best-terminal-for-mac
