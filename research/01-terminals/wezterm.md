# WezTerm

> **Provenance:** Generated 2026-06-27 from a 39-agent research workflow (10-terminal survey + adversarial fact-check + 8 architecture deep-dives + synthesis), 281 web lookups. Claims marked surprising/marketing-flavored were independently fact-checked (see [fact-checks](../03-analysis/fact-checks.md)).

**TL;DR — A fully cross-platform, Rust-based terminal that bundles a tmux-style multiplexer and deep Lua scripting into one GPU-accelerated app.**

## At a glance

| | |
|---|---|
| **Developer** | Wez Furlong (and community contributors); repo at github.com/wezterm/wezterm |
| **First released** | ~2019 (first public GitHub releases date to 2019; project work began ~2018) — contested, some sources cite 2022 |
| **Language** | Rust (~99% of codebase) |
| **License** | MIT License |
| **Platforms** | macOS (Universal: Apple Silicon + Intel), Linux, Windows 10+, FreeBSD, NetBSD |
| **Renderer** | GPU-accelerated. Multiple backends: a WebGPU front end (uses Metal on macOS, Vulkan/DX12 elsewhere) and an OpenGL front end (the long-standing default); software fallback available. |

## Key features

- Built-in multiplexer: panes, tabs, windows on local and remote hosts (alternative to tmux)
- Lua-based configuration with hot-reloading
- Ligatures, color emoji, font fallback, true color, dynamic color schemes
- Built-in/native SSH client with integrated tabs; remote multiplexing over SSH or TLS/TCP
- Image protocols: iTerm2 (imgcat), Kitty graphics, and experimental Sixel
- Searchable scrollback, hyperlinks, bracketed paste, SGR mouse selection
- Serial port connections (e.g. Arduino/embedded)

## Strengths

- Strong cross-platform consistency — same config and behavior across macOS, Linux, Windows, BSD
- Highly scriptable/programmable configuration via Lua
- Integrated multiplexer means no separate tmux needed
- Rich feature set (image protocols, ligatures, SSH/serial) out of the box
- Universal macOS binary; GPU rendering via Metal/WebGPU enabled by default
- Open source under permissive MIT license

## Weaknesses

- Less native macOS feel — window behavior, font rendering, and system menu integration feel non-native vs. iTerm2/Ghostty
- Reports of occasional visual tearing on macOS; not as consistently smooth on ProMotion/120Hz as Ghostty
- Lua config has a learning curve for newcomers
- Slow stable release cadence — last tagged stable was Feb 2024, prompting 'is it abandoned?' questions (maintainer calls it a spare-time project; nightly builds continue)
- Some reports of high GPU usage per window on macOS Tahoe (GitHub issue #7271)

## macOS notes

Ships as a Universal binary (Apple Silicon + Intel) since release 20210203; drag-to-Applications .app bundle, also via Homebrew. Uses Metal (through WebGPU) for rendering. Works well but is not a native Cocoa app — menus, window chrome, and font rendering feel somewhat foreign compared to iTerm2 or Ghostty, and some users see tearing/GPU-usage issues on recent macOS versions.

## Performance notes

GPU-accelerated rendering on by default; performance is broadly comparable to Alacritty and Kitty while offering more features. On macOS it can use Metal via the WebGPU front end. Caveats: occasional tearing reported on macOS and a 2025 GitHub issue (#7271) about high per-window GPU usage on macOS Tahoe.

## Fact-checks

#### ✅ CONFIRMED

**Claim:** WezTerm's first public release date is inconsistent across sources (one claimed Sept 4, 2022, while GitHub release tags exist from 2019) — verify the actual earliest release.

**Finding:** The verifiable core of the claim holds: WezTerm GitHub tags do exist from 2019, so any "Sept 4, 2022" first-release date is wrong. Querying the repo directly (git ls-remote --tags github.com/wezterm/wezterm), the earliest dated tags are from March 24, 2019: 20190324-160658, 20190324-175217, 20190324-182322, followed by more tags throughout 2019 (e.g. 20190507, 20190520, 20190602, 20190622, 20190623, 20190626, 20191124, 20191218, 20191229). WezTerm uses a date-stamped versioning scheme (YYYYMMDD-HHMMSS-githash), so the tag name itself encodes the release date. Note: the official wezterm.org changelog only documents releases back to 20191124-233250 (Nov 24, 2019), but actual tags/builds go back to March 24, 2019. The repo's own git history (initial commits) predates that. A "September 4, 2022" date does not correspond to any first release and is refuted as the earliest. Earliest tagged release: 20190324-160658 (March 24, 2019).

**Sources:**
- https://github.com/wezterm/wezterm/tags
- https://github.com/wezterm/wezterm/releases
- https://wezterm.org/changelog.html
- https://wezterm.org/config/lua/wezterm/version.html

#### ❌ REFUTED

**Claim:** WezTerm's last stable release was February 2024, and the project is effectively in spare-time/nightly-only maintenance limbo and possibly abandoned (as of 2026).

**Finding:** The claim is mixed: one part is true, but the central "possibly abandoned / limbo" framing is false. TRUE part: the last tagged STABLE release is indeed 20240203-110809-5046fc22, dated February 3, 2024, and it is still marked "Latest" stable as of June 2026 — so there has been no new versioned stable release in ~2.4 years. However, "possibly abandoned / maintenance limbo" is REFUTED by primary evidence: the project is actively developed. The GitHub main branch shows frequent commits merged from many contributors, including commits dated June 27, 2026 (the day of this check) and a steady stream through June 2026. A continuously-built "nightly" prerelease is published and was last updated June 27, 2026, with fresh artifacts across macOS, Fedora, CentOS, Alpine, and Android. The maintainer (wez) explicitly documents that the bleeding-edge/nightly build is rebuilt continuously and is "usually the best available version" because he daily-drives it. Accurate framing: WezTerm follows a rolling/nightly release model with an infrequent stable-tag cadence (the stable tag has been stale since Feb 2024), but the codebase is under active, ongoing development — not abandoned. Community issues (e.g., #7299, #7451) ask about the long gap between tagged releases, but that reflects release-tagging cadence, not project inactivity.

**Sources:**
- https://wezterm.org/changelog.html
- https://github.com/wezterm/wezterm/releases
- https://api.github.com/repos/wezterm/wezterm/releases/tags/nightly
- https://api.github.com/repos/wezterm/wezterm/commits?per_page=5
- https://github.com/wezterm/wezterm/issues/7299
- https://github.com/wezterm/wezterm/issues/7451


## Sources

- https://wezterm.org/index.html
- https://wezterm.org/features.html
- https://wezterm.org/install/macos.html
- https://github.com/wezterm/wezterm
- https://github.com/wezterm/wezterm/releases
- https://github.com/wezterm/wezterm/issues/7271
- https://wezfurlong.org/wezterm/index.html
- https://medium.com/@dynamicy/choosing-a-terminal-on-macos-2025-iterm2-vs-ghostty-vs-wezterm-vs-kitty-vs-alacritty-d6a5e42fd8b3
- https://scopir.com/posts/ghostty-vs-wezterm-2026/
- https://www.terminal.guide/tools/terminal-emulator/wezterm/
