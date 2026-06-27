# Warp

> **Provenance:** Generated 2026-06-27 from a 39-agent research workflow (10-terminal survey + adversarial fact-check + 8 architecture deep-dives + synthesis), 281 web lookups. Claims marked surprising/marketing-flavored were independently fact-checked (see [fact-checks](../03-analysis/fact-checks.md)).

**TL;DR — An AI-native, blocks-based terminal that has evolved into a full "agentic development environment" — combining a polished native terminal with multi-agent orchestration, rather than just a fast text grid.**

## At a glance

| | |
|---|---|
| **Developer** | Warp Dev, Inc. (founder/CEO Zach Lloyd, ex-Google Sheets engineering lead) |
| **First released** | Company founded 2020; public beta April 2022 (macOS first) |
| **Language** | Rust (~98% of the open-sourced client), with some Objective-C, Shell, Python, and PowerShell. Custom in-house UI framework (warpui/warpui_core). |
| **License** | Source-available/open source as of April 28, 2026: client is dual-licensed — UI framework crates (warpui_core, warpui) under MIT, the rest under AGPL v3. The cloud backend and AI services remain proprietary. App itself is free to download; account previously required, login requirement later lifted. |
| **Platforms** | macOS 10.14+ (Intel and Apple Silicon), Linux (Debian/Ubuntu, Red Hat/Fedora, SUSE, Arch), Windows 11/10 (x64 and ARM64) |
| **Renderer** | GPU-accelerated. On macOS it renders via Apple's Metal API (chosen over OpenGL) for high frame rates including on 4K displays. |

## Key features

- Blocks: each command + its output, exit code, duration, and stable shareable ID grouped as a navigable unit
- IDE-style command input editor with syntax highlighting, multi-line editing, and editor-like text selection
- AI/Agent Mode: natural-language command generation, error/diff suggestions, and multi-step agentic task execution with step approval
- Warp 2.0 'Agentic Development Environment' (2025): multi-agent orchestration, model routing, codebase indexing, and Oz cloud orchestrator for background agents
- MCP (Model Context Protocol) server support to connect agents to tools like Linear, Sentry, Postgres
- Bring Your Own Key (BYOK) for OpenAI, Anthropic, Google; model choice across providers (Bedrock, LiteLLM, OpenRouter)
- Workflows (saved parameterized commands), themes, and team sharing/collaboration
- Network Log to inspect telemetry/network events; toggle to opt out of telemetry/crash reporting; Secret Redaction for AI interactions

## Strengths

- Polished, modern UX out of the box (blocks, autocomplete, editor-style input) with low learning curve
- Native Rust + Metal rendering for smooth GPU-accelerated drawing on macOS
- Deep, well-integrated AI/agent tooling — among the more capable agentic terminals
- Cross-platform with reasonably consistent feature set
- Now source-available, addressing prior closed-source criticism; BYOK and telemetry controls for privacy-conscious users

## Weaknesses

- Higher memory usage (~300-500 MB) than lean terminals (Alacritty, Ghostty, iTerm2)
- Poor tmux interoperability — doesn't run well inside tmux, and tmux inside Warp loses Warp features
- Existing custom shell prompts/configs and tmux layouts don't carry over (switching cost)
- Account/login historically required (later lifted) and AI features tie into cloud services; telemetry must be on for AI on the Free plan
- AI-credit-based pricing has drawn criticism — reports of credit allotments cut sharply (e.g., 10,000 to 1,500) without proportional price changes
- Backend/AI remains proprietary despite client open-sourcing

## macOS notes

macOS was the original and lead platform (launched here first in 2022). Built as a native Mac app in Rust with Metal-based GPU rendering rather than Electron. Supports Apple Silicon and Intel. Install via .dmg or `brew install --cask warp`. Despite being native, its memory footprint (~300-500 MB) is closer to Electron apps than to lean native terminals like Alacritty/Ghostty/iTerm2. The IDE-style input editor (cursor movement, selection, multi-line edit, copy-paste) mimics modern editors. Linux/Windows builds reportedly reached macOS feature parity in 2024-2025.

## Performance notes

Renders on the GPU via Metal on macOS, claiming smooth high-frame-rate output even at 4K. No official independent benchmark of raw throughput vs. peers surfaced; it does not market itself as the literal "fastest" terminal. Memory consumption is notably higher than minimalist native terminals. Performance value-add is more about UX/AI than raw I/O speed.

## Pricing & feature gating

> Researched 2026-06-27 from [Warp pricing](https://www.warp.dev/pricing), [plans & billing docs](https://docs.warp.dev/support-and-community/plans-and-billing/plans-pricing-refunds/), and [lifting the login requirement](https://www.warp.dev/blog/lifting-login-requirement). Pricing is in flux (Warp recently collapsed Pro/Turbo/Lightspeed into a single "Build" plan) — re-verify before quoting.

**The model has three layers. All terminal features are free; only AI is gated, and AI has a free escape hatch (BYOK).**

### Layer 1 — Free, no login (anonymous)
All core terminal features: blocks, IDE-style input editor, native tabs/panes, autocomplete, Workflows, themes, project file view, GPU/Metal rendering — plus a preview/taste of AI. Caveat: an anonymous ID is still attached, and Warp has said more features *may* be gated to logged-in users over time.

### Layer 2 — Logging in (free account, $0)
Login unlocks **cloud-connected** features at no cost (within limits):
- **Warp Drive** — sync/share Workflows, Notebooks, Sessions, Prompts, Preferences, env vars across machines/teams
- Collaboration / "multiplayer" sharing
- Cloud conversation storage (limited on free)
- Fuller AI surface than the logged-out preview

### Layer 3 — Paid subscription (AI usage)
Paid plans are almost entirely about **AI credits**.

| Plan | Price | AI credits | Key inclusions |
|---|---|---|---|
| **Free** | $0 | Small allowance only (reported ~150/mo first 2 months, then ~75/mo; **no bundled credits for the full Warp Agent**) | All terminal features, limited Warp Drive/cloud, BYOK option |
| **Build** | $20/mo ($18/mo annual) | **1,500/mo** | Full Warp Agent (frontier OpenAI/Anthropic/Google models), extended cloud agents, highest codebase-indexing limits, **unlimited** Warp Drive + cloud storage, email support |
| **Business** | $50/user/mo ($45 annual, ≤25 seats) | 1,500/mo per user | Build + team usage metrics, admin data controls, **SAML SSO** |
| **Enterprise** | Custom | Custom shared pool | Unlimited seats, BYO-LLM, self-hosted cloud agents, spend controls, governance, dedicated support |

**Credits pay for:** code generation, debugging, and multi-agent / agentic workflows (the Warp 2.0 "Agentic Development Environment", Oz background orchestrator, etc.). Each AI action consumes credits. "Reload Credits" can be purchased and roll over for up to 12 months with an active subscription.

### BYOK escape hatch
You can use Warp's AI **without a subscription** by bringing your own inference: a personal **API key** (OpenAI/Anthropic/Google), a custom inference endpoint, or a SuperGrok / X Premium subscription. You pay your model provider directly instead of Warp's $20/mo.

### Takeaways
- The **terminal never costs money**; login is optional unless you want sync/collab; only AI + cloud are gated.
- Free-tier AI is deliberately thin — a taste, not something to rely on. Real AI use assumes Build ($20) or BYOK.
- The **credit-based pricing is the most-criticized part** (allotments cut over time); BYOK sidesteps it.

**Relevance to xtty:** Warp monetizes AI credits, gates sync/collab behind login, and keeps the terminal free. xtty's target (free/open, no login, no paywall — see [xtty-requirements](../03-analysis/xtty-requirements.md)) deliberately rejects all three gates; BYOK + local models is the "AI grounded in semantics, locally and privately" opportunity minus the credit meter.

## Fact-checks

#### ✅ CONFIRMED

**Claim:** Warp scored 75.6% on SWE-bench Verified in November 2025, claimed top-5 among AI dev tools — a self-reported, version-sensitive benchmark to verify independently

**Finding:** The 75.6% figure is accurate and appears in Warp's own "2025 in Review" post tied to the Agents 3.0 release in November 2025 ("75.6% on SWE-bench Verified", alongside 61.2% on Terminal-Bench). The framing is correct: it is self-reported by Warp and version-sensitive. One nuance: Warp reported several different scores over 2025 — 71% (June 23, 2025, explicitly described as "top 5 on the leaderboard"), 75.8% (September 1, 2025, described as roughly #3), and 75.6% (November 2025, Agents 3.0). So the 75.6% is slightly LOWER than the earlier 75.8% September figure, underscoring the version-sensitivity. The "top-5" characterization is supported by Warp's own leaderboard claims. All scores are self-reported on Warp's blog rather than from an independent third-party evaluation of Warp's agent, so the call to verify independently is well-founded.

**Sources:**
- https://www.warp.dev/blog/2025-in-review
- https://www.warp.dev/blog/swe-bench-verified-update
- https://www.warp.dev/blog/swe-bench-verified
- https://www.swebench.com/verified.html

#### ✅ CONFIRMED

**Claim:** 'Fully native' Metal-rendered Mac app, yet uses ~300-500 MB RAM (Electron-like) — the 'lightweight native' framing is contestable

**Finding:** Both factual halves check out, but two nuances matter. (1) The "fully native / Metal / no Electron" part is literally Warp's own marketing: their launch post is titled "Warp is a fully native, GPU-accelerated, Rust-based terminal. No Electron," and their engineering blog confirms a custom Rust UI framework rendering via Metal on macOS (Vulkan/DirectX elsewhere). This architecture is genuinely NOT Electron/Chromium — so "Electron-like" applies only to the RAM footprint, not the technical design. (2) The 300-500 MB figure is real and documented in numerous official GitHub issues, but it is the higher/regressed end rather than a universal baseline. Reported idle usage starts around ~100 MB on a fresh launch and ~200 MB after a day with a few tabs; a v0.2025.10.29 regression pushed idle usage from ~100 MB to 500 MB+, and worse memory-leak bugs (3.6 GB, even 113 GB) have been filed. Warp maintainers themselves discuss a target budget of "RSS under 500 MB with 4 panes idle," implicitly acknowledging that 300-500 MB is heavier than ideal for a terminal. So the critique that the "lightweight native" framing is contestable is fair: Warp is authentically native but its memory footprint is in Electron-app territory.

**Sources:**
- https://news.ycombinator.com/item?id=30922442
- https://www.warp.dev/blog/how-warp-works
- https://github.com/warpdotdev/Warp/issues/7938
- https://github.com/warpdotdev/Warp/issues/2611
- https://github.com/warpdotdev/warp/issues/9595
- https://github.com/warpdotdev/warp/issues/7520
- https://github.com/warpdotdev/Warp/issues/7892


## Sources

- https://www.warp.dev/
- https://www.warp.dev/mac-terminal
- https://github.com/warpdotdev/warp
- https://www.warp.dev/blog/warp-is-now-open-source
- https://www.warp.dev/blog/how-warp-works
- https://www.warp.dev/blog/reimagining-coding-agentic-development-environment
- https://www.warp.dev/blog/lifting-login-requirement
- https://docs.warp.dev/getting-started/quickstart/installation-and-setup/
- https://thenewstack.io/warp-goes-agentic-a-developer-walk-through-of-warp-2-0/
- https://www.helpnetsecurity.com/2026/04/30/warp-open-source-client/
- https://fossforce.com/2026/05/after-years-of-teasing-warp-finally-goes-open-source/
- https://www.techbloat.com/warp-scraps-tiered-plans-as-ai-coding-tools-face-pricing-reckoning.html
- https://vibehackers.io/blog/best-terminal-for-mac
