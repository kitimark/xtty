# Rio Terminal

> **Provenance:** Generated 2026-06-27 from a 39-agent research workflow (10-terminal survey + adversarial fact-check + 8 architecture deep-dives + synthesis), 281 web lookups. Claims marked surprising/marketing-flavored were independently fact-checked (see [fact-checks](../03-analysis/fact-checks.md)).

**TL;DR — A Rust, GPU-accelerated terminal with a custom Sugarloaf/wgpu renderer that targets desktops, FreeBSD, and the browser (WebAssembly) from one codebase, with an emerging embeddable engine (librio) and a native-Swift macOS frontend (Super Rio).**

## At a glance

| | |
|---|---|
| **Developer** | Raphael Amorim (raphamorim) — independent open-source project |
| **First released** | ~2022 (first commits/early 0.0.x releases); reached broader attention with 0.0.x releases through 2023. Latest line is 0.4.x (0.4.7 released June 2026). |
| **Language** | Rust (~97% of codebase; rendering shaders in WGSL/Metal/GLSL/Slang). Optional Swift for the experimental "Super Rio" native macOS frontend built on librio. |
| **License** | MIT |
| **Platforms** | macOS, Linux, Windows, FreeBSD, Web/browser (WebAssembly, experimental) |
| **Renderer** | GPU-accelerated via a custom renderer called "Sugarloaf" built on wgpu (Rust's WebGPU implementation), which maps to Metal on macOS and Vulkan/DX12 on Linux/Windows. As of early 2026 Rio added more direct native Metal support on macOS; wgpu has also become optional behind a feature flag (e.g. for Debian packaging / RetroArch shaders). Also has a WebAssembly/browser build target. |

## Key features

- GPU-accelerated rendering via custom Sugarloaf renderer
- 24-bit true color
- Tabs, multi-window, split panes
- Font ligatures
- Image protocols: Kitty graphics, iTerm2, Sixel
- RetroArch shaders / CRT filters and background blur
- Vi mode, hints, clickable hyperlinks
- Kitty keyboard protocol, IME support
- Shell integration; spawn or fork modes
- Command palette and island-style tabs (recent)
- Cross-platform plus WebAssembly browser build
- librio embeddable engine

## Strengths

- Fast GPU-accelerated rendering across platforms from a single Rust codebase
- Rich modern feature set (image protocols, ligatures, splits, tabs, Vi mode)
- Genuinely cross-platform including FreeBSD and an experimental web/WASM target
- Permissive MIT license and active development (~7k+ GitHub stars, 130+ contributors)
- Recent native Metal work and a native-Swift macOS app (Super Rio) showing macOS investment
- Custom Sugarloaf renderer designed for minimal-overhead render steps

## Weaknesses

- Still pre-1.0 (0.x); described by reviewers as 'under development' with rough edges
- Documentation is thin in places; macOS install docs say little about native integration specifics
- Canary macOS builds are not notarized, requiring Gatekeeper bypass
- Native macOS UI integration historically limited; the 'truly native' experience is the separate experimental Super Rio app, not the main Rio
- Past macOS stability issues (e.g. crash/not-opening on macOS 15 beta, issue #558)
- Smaller ecosystem/community than established peers (iTerm2, Kitty, WezTerm, Alacritty)

## macOS notes

macOS install via Homebrew cask (brew install --cask rio), MacPorts (port install rio), or DMG from GitHub releases. Rendering uses wgpu mapped to Metal, and as of early 2026 Rio added more direct native Metal support for lower overhead and "consistent 60+ FPS." The main Rio app is a cross-platform binary rather than a deeply native AppKit app; a separate experimental project, "Super Rio," is fully native Swift powered by librio and is positioned as the path to a "truly native" macOS experience (with planned AI features). Canary builds are not notarized. Some historical macOS-specific bugs exist.

## Performance notes

Marketed as fast/high-performance via GPU acceleration and the Sugarloaf renderer; recent macOS Metal work claims "consistent 60+ FPS" and "lower overhead." No independent, rigorously sourced benchmark was found in this research confirming it is faster than peers like Alacritty, Kitty, or WezTerm — performance claims are largely first-party.

## Fact-checks

#### ✅ CONFIRMED

**Claim:** First-party performance framing that Rio 'is fast' / high-performance — no independent benchmark found showing it beats Alacritty/Kitty/WezTerm; treat speed claims as marketing.

**Finding:** The claim holds on all three parts. (1) The "fast/high-performance" framing is first-party and unquantified: rioterm.com states "The Rio has fast performance, leveraging the latest technologies including Rust and advanced rendering architectures" and markets it as a "hardware-accelerated GPU terminal emulator," with no benchmark data, comparative numbers, or methodology on either the homepage or the GitHub README. (2) No independent benchmark was found showing Rio beats Alacritty, Kitty, or WezTerm. The most cited independent latency/throughput benchmarks (beuke.org, lkhrs.com, danluu.com) test Alacritty/Kitty/WezTerm/foot/etc. but do NOT include Rio at all. (3) Where Rio is mentioned in comparisons, the assessment is that it does not lead: a Terminal Trove comparison summary states Rio (Rust on a WebGPU backend) does not beat Alacritty or Kitty in performance comparisons. Nuance worth noting: absence of an independent benchmark beating the others is not proof Rio is slow — it simply means the vendor's speed claim is unsubstantiated by neutral testing, so treating it as marketing is appropriate. The architectural basis (Rust + WGPU/WebGPU GPU rendering) is real, but architecture is not a measured performance result.

**Sources:**
- https://rioterm.com/
- https://github.com/raphamorim/rio
- https://beuke.org/terminal-latency/
- https://www.lkhrs.com/blog/2022/07/terminal-latency/
- https://danluu.com/term-latency/
- https://terminaltrove.com/compare/terminals/
- https://terminaltrove.com/terminals/rio-terminal/
- https://github.com/alacritty/vtebench

#### ✅ CONFIRMED

**Claim:** The 'consistent 60+ FPS' and 'lower overhead, better integration' from the March 2026 native-Metal blog post — first-party and version-sensitive (tied to recent 0.3.x/0.4.x releases).

**Finding:** The phrasing is accurate but one detail should be tightened. The quotes come from Rio's own (first-party) blog post "What's coming next?" dated 2026-03-11 at rioterm.com, which states verbatim: "Metal support: Rio now runs natively on Metal, Apple's GPU API. This means lower overhead and better integration on macOS." and "Consistent 60+ FPS: Even when hammering the terminal with empty line breaks, Rio now maintains at least a consistent 60fps." The blog post itself does NOT cite a version number (it refers only to "the next version of Rio"). The native Metal backend (renderer.backend = metal) was actually introduced in the 0.4.0 release as part of a major renderer rewrite, with refinements in later 0.4.x releases (e.g., 0.4.2 transparency). So it is genuinely version-sensitive, but specifically a 0.4.x feature; attributing it to 0.3.x is inaccurate. With that one caveat, the claim is supported.

**Sources:**
- https://rioterm.com/blog/2026/03/11/whats-coming-next
- https://rioterm.com/changelog
- https://github.com/raphamorim/rio/releases


## Sources

- https://rioterm.com/
- https://github.com/raphamorim/rio
- https://rioterm.com/docs/features
- https://rioterm.com/docs/install/macos
- https://rioterm.com/blog/2026/03/11/whats-coming-next
- https://rioterm.com/changelog
- https://github.com/raphamorim/rio/releases
- https://github.com/raphamorim/rio/issues/558
- https://medium.com/@raphamorim/rio-terminal-a-native-and-web-terminal-application-powered-by-rust-webgpu-and-webassembly-76d03a8c99ed
- https://www.terminal.guide/tools/terminal-emulator/rio/
