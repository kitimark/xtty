# `xtty` Requirements

> **Provenance:** Drafted 2026-06-27 from the user's hands-on Warp evaluation + the terminal research. This is the opinionated product target for `xtty` — it picks a side in the [agents-and-xtty](agents-and-xtty.md) fork: lean / free / no-lock-in (Ghostty-style), plus the two things Warp got right (visible per-session progress, in-terminal file/diff view).

## Guiding principle

A fast, native, **free and accountless** macOS terminal that stays out of your way — with at-a-glance per-session progress and an optional in-terminal file/diff view. Win as a great host for agent tooling rather than becoming a heavy AI desktop app.

## Origin of these requirements

From trying Warp, the user found:

- **Liked:** left-side list showing each terminal's progress; an in-app project file view (previously used the Zed editor to see file structure + git diff before committing).
- **Disliked:** ~1 GB memory use; login/account required to unlock features; paywalled features.

These map directly to the [research conclusions](opportunities.md): GPU rendering is commodity; the live edges are native integration, latency over throughput, and semantic capture — and the open opportunity is *"AI grounded in semantics, locally and privately."*

## Must-haves

| # | Requirement | Why / source |
|---|---|---|
| M1 | **Low memory footprint** — lean native, nowhere near Warp's ~300MB–1GB | User dislike; Warp's documented memory-leak/regression bugs |
| M2 | **No account / no login** — fully usable with zero sign-in | User dislike of Warp's login gate |
| M3 | **Free / open, no paywalled features** | User dislike of Warp's paid AI-credit model |
| M4 | **Native macOS + Metal renderer, latency-first** | Research: Metal is the macOS dividing line; latency is what users feel |
| M5 | **Keep the user's existing setup** — zsh/dotfiles, Starship/p10k, tmux work unchanged | Research: Warp's switching cost is a top complaint |
| M6 | **Great host for agent CLIs** (Claude Code, etc.) — solid TUI/alt-screen handling, low latency | [agents-and-xtty](agents-and-xtty.md): win as a host first |

## High-value features

| # | Feature | Why / source |
|---|---|---|
| H1 | **At-a-glance per-session progress** — sidebar/tab list showing each terminal's state (idle / working / done / failed) | User's favorite Warp feature; mirrors [Herdr](adjacent-tools.md)'s agent-state sidebar. (State vocabulary settled in [P5 sidebar + P4b sequencing](p5-sidebar-and-p4b-sequencing.md): "failed" replaces "blocked" — xtty has no native needs-human signal.) |
| H2 | **In-terminal file/diff view** — project file tree + git diff before commit | User's Zed habit; the one thing Warp got right that plain terminals lack |
| H3 | **Semantic capture (OSC 7 / OSC 133)** with auto-injection + robust fallback | Foundation for H1, jump-to-prompt, failed-command marks, and any future agent features ([agents-and-xtty](agents-and-xtty.md)) |

## Nice-to-haves / later

| # | Feature | Notes |
|---|---|---|
| N1 | **Agent-drivable local API** (read/send/wait/split) | Pluggable, local-first agents — not vendor-locked; see [Herdr](adjacent-tools.md)'s socket API as a model |
| N2 | **Pluggable / BYOK + local-model AI**, off by default | "AI grounded in semantics, locally and privately" — the open opportunity |
| N3 | **Native splits/tabs + Quick-Terminal dropdown** | Table-stakes native UX (cf. Ghostty) |

## Explicit non-goals

- **Not** a heavyweight AI desktop app (the Warp model) — no mandatory cloud, no account, no telemetry-to-use-AI.
- **Not** a replacement for the user's editor — H2 is a *lightweight* file/diff view, not a full IDE. (Pairing with `lazygit` / `yazi` / an editor remains valid.)
- **Not** chasing raw throughput benchmarks at the expense of latency (research: throughput barely affects felt speed).

## How the pieces fit

- H1 (session progress) + H3 (OSC 133) reinforce each other: clean shell-integration signals let `xtty` show accurate per-session state natively, and let external tools like [Herdr](adjacent-tools.md) detect state far better than heuristics.
- M6 + N1: being a great *host* with a local API means `xtty` captures the agent-integration upside without the lock-in/weight of the Warp model.

## Related

- [Agents & xtty](agents-and-xtty.md) · [Adjacent tools (Herdr)](adjacent-tools.md)
- [Opportunities & design implications](opportunities.md)
- [Landscape synthesis](../00-overview/landscape-synthesis.md)
