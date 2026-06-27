# Ghostty

> **Provenance:** Generated 2026-06-27 from a 39-agent research workflow (10-terminal survey + adversarial fact-check + 8 architecture deep-dives + synthesis), 281 web lookups. Claims marked surprising/marketing-flavored were independently fact-checked (see [fact-checks](../03-analysis/fact-checks.md)).

**TL;DR — A terminal that refuses to trade off speed, features, or native-platform feel simultaneously, built on a reusable C-ABI core (libghostty) with a true Metal/SwiftUI macOS app rather than a cross-platform widget toolkit.**

## At a glance

| | |
|---|---|
| **Developer** | Mitchell Hashimoto (co-founder of HashiCorp), originally a solo passion project started in 2021; now an open-source project with a community of contributors under the ghostty-org organization. |
| **First released** | Public 1.0 released December 26, 2024 (development began ~2021; private beta through 2024). |
| **Language** | Core terminal engine and Linux GUI in Zig (~79% of codebase); macOS GUI in Swift/SwiftUI/AppKit (~11%); plus C and C++ for bindings/dependencies. Core exposed as a C-ABI library, libghostty. |
| **License** | MIT |
| **Platforms** | macOS, Linux (GTK) |
| **Renderer** | GPU-accelerated. Metal renderer on macOS; OpenGL on Linux. Multi-threaded design with separate read, write, and render threads per terminal surface. |

## Key features

- Platform-native UI: SwiftUI/AppKit on macOS, GTK on Linux (no Electron, no custom widget toolkit)
- Native tabs, splits/panes, and multi-window support
- Quick Terminal: Quake-style global drop-down terminal (default global:ctrl+backtick on macOS)
- Kitty graphics protocol support (inline images) and Kitty keyboard protocol
- Zero/minimal configuration philosophy with sane defaults; ships JetBrains Mono and bundles Nerd Font glyphs
- Automatic light/dark theme switching following system appearance
- SIMD-optimized terminal parser (utf8/vt sequence parsing)
- macOS-specific: CoreText font discovery, Quick Look, Force Touch, Secure Input, AppleScript/Shortcuts support
- 1.3+ adds scrollback search, native scrollbars, click-to-move-cursor, command/notification features, and modal keybindings via key tables

## Strengths

- Genuinely native macOS app feel (SwiftUI/AppKit) rather than a cross-platform toolkit, unlike Kitty/Alacritty/WezTerm
- Native Metal renderer (not OpenGL via Apple's deprecated compatibility layer), enabling ProMotion/120Hz and power-efficient rendering
- Very fast: roughly on par with Alacritty in benchmarks while keeping rich GUI features
- Low key-to-screen latency
- Works well out of the box with little configuration
- Open source under permissive MIT license; large active user base and community

## Weaknesses

- No native Windows support (only macOS and Linux); Windows users must use WSL/other means
- No built-in tmux control-mode integration like iTerm2, which is a draw for heavy tmux users
- Younger project (1.0 only Dec 2024) so ecosystem, documentation, and third-party tooling are less mature than iTerm2
- GUI feature surface still expanding release-to-release; some features are macOS-only or Linux-only
- Configuration is file-based; settings GUI is limited compared to iTerm2's extensive preferences

## macOS notes

Strong native integration: SwiftUI/AppKit app with real macOS windowing, menu bar, and native tabs/fullscreen. Uses a true Metal renderer (Apple's current GPU API, not the deprecated OpenGL compatibility path), which reviewers credit with ProMotion/120Hz adaptive sync and efficient rendering on Apple Silicon. CoreText is used for font discovery/rendering. macOS-only niceties include the Quick Terminal drop-down, Quick Look, Force Touch, Secure Input API, and AppleScript/Apple Shortcuts automation. Runs natively on Apple Silicon and Intel.

## Performance notes

The project itself avoids claiming to be the single fastest terminal; its docs say it "aims to be in the same class as the fastest terminal emulators." Ghostty's own benchmarks state it and Alacritty are "usually within a few percentage points of each other" and "something like 100x faster than Terminal.app and iTerm." Some third-party reviews go further (e.g., claiming "fastest terminal tested," ~0.7s to cat 100,000 lines, ~2ms key-to-screen latency) — these are reviewer claims, not from the project, and benchmark methodology varies.

## Fact-checks

#### ✅ CONFIRMED

**Claim:** Reviewers call Ghostty the "fastest terminal emulator tested" (~0.7s to cat 100,000 lines, ~2ms key-to-screen latency), while Ghostty's own docs are more modest — claiming only to be "in the same class as the fastest" terminals (roughly on par with Alacritty) — and the benchmark numbers are method-dependent and contested.

**Finding:** The claim is substantially accurate, with two minor nuances. (1) Review numbers vary by source rather than being a single fixed figure: e.g. DevToolReviews reports ~0.6s for cat 100k lines and ~1.8ms latency; other 2026 reviews cite ~0.7s and ~1.2-2ms. So "~0.7s" and "~2ms" are fair round-figures but not canonical. (2) Ghostty's official About page (ghostty.org/docs/about) does indeed use the modest framing — verbatim: "Ghostty aims to be in the same class as the fastest terminal emulators" and "In some benchmarks it is faster, in others it is slower, but in every case it should be impossible to say that Ghostty is slow" — but that specific page does NOT name Alacritty. The "within a few percentage points of Alacritty / ~100x faster than Terminal.app and iTerm" comparison comes from Ghostty's broader docs/FAQ and community material, not the About page itself. The "contested/method-dependent" point is well supported: Ghostty maintainer Mitchell Hashimoto acknowledges (discussion #4837) that input latency was "never once reliably measured or optimized" and that Ghostty does worse on pathological synthetic benchmarks; Hacker News critics note input-latency benchmarks are unreliable without a camera and that cat/IO-throughput tests don't reflect real-world use, with results often within ~15% across Alacritty/Ghostty/Kitty.

**Sources:**
- https://ghostty.org/docs/about
- https://www.devtoolreviews.com/reviews/ghostty-terminal-review-2026
- https://github.com/ghostty-org/ghostty/discussions/4837
- https://news.ycombinator.com/item?id=42526221
- https://scopir.com/posts/best-terminal-emulators-developers-2026/
- https://vibehackers.io/blog/best-terminal-for-mac

#### ❌ REFUTED

**Claim:** Ghostty is the 'only' macOS terminal using Apple's Metal natively, while Kitty/Alacritty use OpenGL via Apple's deprecated compatibility layer.

**Finding:** The "only" is false. Two halves of the claim must be separated:

1) RENDERER FACTS ON KITTY/ALACRITTY (accurate): Alacritty bills itself as "A cross-platform, OpenGL terminal emulator" and Kitty renders with OpenGL; macOS deprecated OpenGL in 10.14 (2018), so on macOS both run through Apple's deprecated OpenGL compatibility path. This part checks out.

2) GHOSTTY AS "ONLY" METAL TERMINAL (false): Ghostty does use Metal natively on macOS (confirmed by ghostty.org docs), but it is NOT the only one. Warp is built in Rust and "renders directly on the GPU using Metal," using wgpu which targets Metal on macOS — Warp's team explicitly states "Metal was chosen over OpenGL as the GPU API since Warp was going to target macOS as its first platform" (warp.dev/blog/how-warp-works). WezTerm also reaches Metal on macOS via its WebGpu front_end (wgpu backend), per WezTerm's own docs. So at minimum Warp (natively Metal) and WezTerm (Metal via wgpu/WebGPU) also use Metal on macOS. A precise statement: "Among the popular GPU terminals, Ghostty and Warp use Metal natively on macOS (WezTerm can too via its WebGPU backend), whereas Kitty and Alacritty use OpenGL through Apple's deprecated compatibility layer." Reviews repeating the "only" wording are overstated, likely because they only compared Ghostty against Kitty/Alacritty and omitted Warp/WezTerm.

**Sources:**
- https://www.warp.dev/blog/how-warp-works
- https://ghostty.org/docs/features
- https://github.com/alacritty/alacritty
- https://wezterm.org/config/lua/config/front_end.html
- https://developer.apple.com/documentation/Metal/migrating-opengl-code-to-metal
- https://sw.kovidgoyal.net/kitty/


## Sources

- https://ghostty.org/
- https://ghostty.org/docs/about
- https://ghostty.org/docs/features
- https://github.com/ghostty-org/ghostty
- https://mitchellh.com/ghostty
- https://mitchellh.com/writing/ghostty-is-coming
- https://mitchellh.com/writing/libghostty-is-coming
- https://ghostty.org/docs/install/release-notes/1-0-1
- https://github.com/ghostty-org/ghostty/releases
- https://medium.com/@dynamicy/choosing-a-terminal-on-macos-2025-iterm2-vs-ghostty-vs-wezterm-vs-kitty-vs-alacritty-d6a5e42fd8b3
- https://vibehackers.io/blog/best-terminal-for-mac
- https://sesamedisk.com/ghostty-terminal-emulator-review/
