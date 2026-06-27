# Wave Terminal

> **Provenance:** Generated 2026-06-27 from a 39-agent research workflow (10-terminal survey + adversarial fact-check + 8 architecture deep-dives + synthesis), 281 web lookups. Claims marked surprising/marketing-flavored were independently fact-checked (see [fact-checks](../03-analysis/fact-checks.md)).

**TL;DR — A block/widget-based terminal that pulls files, previews, an editor, a web browser, and AI into one workspace to eliminate context switching, rather than chasing raw rendering speed**

## At a glance

| | |
|---|---|
| **Developer** | Command Line Inc. (the "wavetermdev" open-source project / team behind Wave) |
| **First released** | Late 2023 (original "Wave Legacy" beta, Show HN Dec 2023); current rewritten codebase began public releases at v0.8.0 in Sep 2024 |
| **Language** | Go (~48%) backend + TypeScript (~43%) frontend, with CSS/SCSS; built on Electron |
| **License** | Apache-2.0 |
| **Platforms** | macOS 11+ (Apple Silicon arm64 and Intel x64), Windows 10 1809+ (x64), Linux glibc-2.28+ (arm64, x64) via Snap, AppImage, .deb, .rpm, .zip, pacman |
| **Renderer** | CPU-based via Electron (Chromium) with xterm.js v6 for the terminal grid; not a custom GPU-accelerated renderer like Ghostty/Alacritty/Kitty |

## Key features

- Block-based / widget workspace: terminal, editor, web browser, file preview, and AI panels arranged as draggable blocks
- Inline file previews (CSV as tables, images, PDFs, Markdown, audio/video, HTML)
- Built-in VSCode-style (Monaco) editor for local and remote files
- Wave AI: context-aware assistant that can read terminal scrollback and read/write/edit files with approval; BYO API keys for OpenAI/Claude/Gemini/Azure/Perplexity or local via Ollama/LM Studio
- Durable SSH sessions that survive network changes and app restarts, with SSH manager and WSL support
- wsh command-line helper for controlling workspaces/blocks
- Built-in web browser block
- Local-first data storage (no account required); native OS secret storage
- Quake Mode global hotkey, vertical tabs, searchable persistent history

## Strengths

- Strong inline file/media preview support, often cited as the standout feature
- Block layouts can be saved and restored per project/context, reducing context-switching
- Flexible AI integration with bring-your-own-key and local model options, no mandatory account or cloud
- Cross-platform with a polished modern UI
- Open source under permissive Apache-2.0 license
- Good remote/SSH workflow with durable sessions and integrated remote editing

## Weaknesses

- Electron-based: higher memory footprint (~400-800MB) and resize lag/jank versus native GPU terminals like Ghostty or Alacritty
- Block paradigm has a learning curve and can fight traditional terminal muscle memory
- Default AI is described by reviewers as a fairly thin layer over OpenAI, not a best-in-class coding agent
- Not the fastest renderer; performance-focused users may notice the difference
- Relatively young project with rapid version churn (still pre-1.0)

## macOS notes

First-class macOS support (Apple Silicon and Intel). Uses Electron/Chromium rather than native AppKit/Metal, so it is not a native Cocoa app and has no custom Metal renderer. macOS-specific touches: improved first-click focus handling, "New Window" on dock icon right-click, optional Option-as-Meta key, and native Keychain-based secret storage. As of recent releases the Universal macOS binary was dropped (separate arm64/x64 builds) since the team states ~90% of Mac users are on Apple Silicon.

## Performance notes

Electron app; reviewers report memory usage roughly 400-800MB and occasional resize lag/jank, noticeably heavier than native GPU terminals. Terminal grid rendering uses xterm.js (upgraded to v6.0.0), with COLORTERM=truecolor set for color fidelity. Adequate for general/data-shaped work but not positioned as a speed champion.

## Fact-checks

#### ✅ CONFIRMED

**Claim:** Wave Terminal markets SSH sessions as "durable" that "survive connection interruptions, network changes, and Wave restarts."

**Finding:** The marketing claim is accurate as a description of what Wave Terminal officially states. Wave's own documentation (Durable Sessions, introduced in v0.14) uses essentially this exact language: durable sessions "allow your remote terminal sessions to survive connection interruptions, network changes, and Wave restarts," maintaining shell state, running programs, and full scrollback. The mechanism is a lightweight Go-based "job manager" launched on the remote host that keeps the shell running independently and communicates over Unix domain sockets through the existing SSH connection (no extra open ports) — conceptually similar to built-in tmux/screen. So this is a verified vendor claim, not marketing puffery beyond what is documented. Important caveats the bare claim omits: (1) durable sessions are DISABLED BY DEFAULT and must be opted into via config (global/per-connection/per-block); (2) they apply ONLY to remote SSH connections — local terminals and WSL use standard, non-durable sessions; (3) switching between standard and durable mode RESTARTS the shell and terminates running processes; (4) sessions still end when you close the block, switch connections, or delete the workspace/tab; (5) durability is not absolute — sessions can be "Lost" if the remote server reboots or the job manager process is killed, and reconnection requires a working SSH connection plus a resync of buffered output. The author's instinct that it is "worth testing how robust reconnection actually is in practice" is reasonable: the documented behavior is plausible and matches the architecture, but the guarantees are bounded (e.g., a server reboot loses the session), and this is a relatively new feature, so empirical reliability across flaky networks/sleep/updates is the appropriate thing to validate.

**Sources:**
- https://docs.waveterm.dev/durable-sessions
- https://docs.waveterm.dev/connections
- https://docs.waveterm.dev/releasenotes
- https://github.com/wavetermdev/waveterm

#### ✅ CONFIRMED

**Claim:** Wave Terminal release notes claim that Wave AI (v0.12, Nov/Dec 2025) was 'powered by GPT-5' and later 'GPT-5.1 with thinking modes' - version/date-sensitive and tied to OpenAI model availability.

**Finding:** Substantially accurate, with a minor date refinement. Wave Terminal's official release notes (docs.waveterm.dev/releasenotes) state for v0.12.0: "Wave Terminal v0.12.0 introduces a completely redesigned AI experience powered by OpenAI GPT-5." That release was dated October 16, 2025 (the v0.12 series, not strictly Nov/Dec). The GPT-5.1 + thinking modes part lands in v0.12.3 (dated November 17, 2025), which notes upgrading to OpenAI's GPT-5.1 model and adds a "Thinking Mode Toggle" with Quick/Balanced/Deep modes. So the GPT-5.1/thinking-modes change is the Nov 2025 update, while the initial GPT-5 launch was October 2025. The claim is therefore confirmed in substance; the only nuance is that v0.12.0's GPT-5 launch was October 2025 rather than Nov/Dec, with GPT-5.1 arriving mid-November 2025. The claim is indeed version/date-sensitive and tied to OpenAI model availability (earlier v0.11.x notes reference GPT-5 support in Aug 2025 and a gpt-5-mini cloud proxy).

**Sources:**
- https://docs.waveterm.dev/releasenotes
- https://github.com/wavetermdev/waveterm/releases/tag/v0.12.0
- https://github.com/wavetermdev/waveterm/releases


## Sources

- https://github.com/wavetermdev/waveterm
- https://www.waveterm.dev/
- https://docs.waveterm.dev/releasenotes
- https://github.com/wavetermdev/waveterm/releases
- https://news.ycombinator.com/item?id=38701899
- https://moltamp.com/blog/wave-terminal-review-2026/
- https://blog.openreplay.com/warp-wave-terminal-ai-powered/
- https://4sysops.com/archives/wave-a-modern-terminal-with-ai-features/
