# Agents & `xtty` — Design Note

> **Provenance:** Synthesized 2026-06-27 from the terminal research (esp. [Warp](../01-terminals/warp.md), [Ghostty](../01-terminals/ghostty.md), and [modern innovations](../02-internals/08-modern-innovations.md)) plus a design discussion. This is a design-decision note, not a survey — it frames the agent-integration fork `xtty` will face.

## The core fork

There are two coherent ways a terminal relates to AI agents. They are not points on a slider — they are different products.

1. **Agents as part of the product (the Warp model).** The terminal *is* an agentic environment. The UI, data model, and rendering are built so an agent can read structured command/output/exit-code context and act with approval. The terminal vendor owns the agent experience.
2. **Agent-agnostic host (the Ghostty model).** The terminal has zero AI. It is fast, native, and invisible, and users run whatever agent CLI they want inside it (Claude Code, Aider, Codex CLI, …). The agent is decoupled from the terminal; no lock-in.

Both are legitimate. The mistake is building halfway — a mediocre built-in agent that's worse than the CLI agents users already have, on top of a terminal that's slower than the lean ones.

## The two reference models

| | **Warp (integrated agents)** | **Ghostty (agent-agnostic host)** |
|---|---|---|
| AI in the terminal | First-class: Agent Mode, multi-agent orchestration, model routing, MCP, BYOK | None by design |
| What the agent sees | Structured "blocks" (command + output + exit code + duration) | Whatever the CLI agent captures itself |
| Lock-in | Agent tied to the vendor/product | User brings any agent; swappable |
| Footprint | ~300–500MB; UX-first, not latency-first | Lean; latency-first; native Metal |
| Why it works | Blocks architecture gives the agent semantic context | The terminal is just a great place to run a TUI agent |

**Key insight from the research:** Warp's AI is good *because* of semantic capture, not the other way around. AI usefulness is downstream of the terminal knowing where commands, output, and exit codes are. (See [`08-modern-innovations.md`](../02-internals/08-modern-innovations.md).)

## The technical foundation either way: semantic capture

Whether or not `xtty` ships a built-in agent, the differentiating substrate is the same: **OSC 7 and OSC 133 shell integration.**

- **OSC 7** — current working directory as a percent-encoded `file://` URL, emitted by the shell on every prompt. Survives nested shells and ssh (unlike parsing `cd`). Lets new splits/tabs open in the right dir and tells an agent *where* it is.
- **OSC 133** — command-lifecycle boundaries:
  - `133;A` prompt start
  - `133;B` end of prompt / start of user input
  - `133;C` command output start
  - `133;D;<exit_code>` command finished (with exit status)

With OSC 133, `xtty` can reconstruct Warp-style "blocks" from a *normal* shell stream — which unlocks, in increasing order of ambition:

1. Jump-to-prompt nav, select-one-command's-output, red-gutter failed commands (pure UX, no AI)
2. "Explain this error" / "fix this command" — feed the failed block (command + output + exit code) to a model
3. Full agentic loop — agent proposes commands, `xtty` runs them, captures the resulting blocks, agent self-corrects, user approves steps

Steps 1–2 are cheap and valuable even if `xtty` never becomes "an AI terminal." Step 3 is the Warp bet.

### Implementation notes / pitfalls (from [`08-modern-innovations.md`](../02-internals/08-modern-innovations.md))

- Shell integration is **opt-in and fragile** — it hooks the user's prompt (`PROMPT_COMMAND` in bash; `precmd`/`preexec` in zsh; fish events; PowerShell `prompt`). Heavily customized prompts (Starship, Powerlevel10k, oh-my-zsh) or anything that resets `PROMPT_COMMAND` can silently break the marks. Auto-injection helps but can conflict with user rc files.
- Sequences must survive **tmux/screen and ssh**. tmux historically needs passthrough for OSC 133/7; remote shells need integration installed too; OSC 7's hostname matters so a remote cwd isn't opened locally.
- **Boundary detection without OSC 133** (the Warp heuristic approach) must handle multi-line input, alt-screen apps (vim/top/less should NOT be chopped into blocks), and bracketed paste. Prefer real OSC 133; fall back to heuristics only with alt-screen detection.

## Recommendation for `xtty`

Given the macOS-native, latency-first positioning already in the research ([opportunities](opportunities.md)), the strongest play is **layered**, in this order:

1. **Win as a host first.** Be the fastest, most native, lowest-friction terminal that runs agent CLIs (Claude Code et al.) beautifully — low latency, solid TUI/alt-screen handling, ProMotion. This is table stakes and where Ghostty already wins; don't lose here.
2. **Build semantic capture early.** Ship OSC 7 + OSC 133 (with auto-injection and robust fallback) from the start. It's foundational and pays off immediately in non-AI UX (blocks, jump-to-prompt, failed-command marks).
3. **Make agents pluggable, not proprietary.** If/when `xtty` adds AI, expose blocks via a local API / MCP so *any* agent (including user-chosen, local, or BYOK models) can read command context and propose actions. This captures Warp's integration benefit without Warp's lock-in or cloud/telemetry baggage — directly matching the open opportunity: *"AI grounded in semantics, locally and privately."*

This sequencing means every stage is independently valuable: a great terminal at step 1, a great *structured* terminal at step 2, and an open agentic terminal at step 3 — without ever betting the product on the AI working.

## The one-line thesis

Don't choose "AI terminal vs. fast terminal." Build a fast native terminal with semantic capture (OSC 7/133) as a foundation, keep agents pluggable and local-friendly, and you get Warp's integration upside, Ghostty's speed and zero-lock-in, and the open ground neither fully occupies.

## Related

- [Warp deep-dive](../01-terminals/warp.md) · [Ghostty deep-dive](../01-terminals/ghostty.md)
- [Adjacent tools](adjacent-tools.md) — agent multiplexers (e.g. Herdr) that prove the agent-host model as a layer
- [Modern innovations: blocks, AI, OSC integration](../02-internals/08-modern-innovations.md)
- [Opportunities & design implications](opportunities.md)
