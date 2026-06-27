# AGENTS.md — xtty

Guidance for AI agents (and humans) working in this repository. This is the canonical project guide; `CLAUDE.md` imports it.

## What this project is

**xtty** is a **native macOS terminal emulator**. It is greenfield and currently transitioning from the **research/exploration** phase into the **build** phase — there is no application code yet, but the direction, requirements, and design are documented in `research/`.

## Current status

- ✅ Landscape + internals research, requirements, and a design (stack + milestones) — in `research/`.
- ✅ Spec-driven workflow scaffolded — `openspec/`.
- ⬜ No application code, build system, or tests yet. (Don't reference build/test commands until they exist.)

## Repository structure

```
xtty/
├── AGENTS.md        # this file — canonical project guide
├── CLAUDE.md        # imports AGENTS.md (Claude Code entry point)
├── research/        # exploratory background (read before proposing direction)
│   ├── 00-overview/ #   landscape synthesis + comparison matrix
│   ├── 01-terminals/#   per-terminal deep-dives (iTerm2, Ghostty, Warp, …)
│   ├── 02-internals/#   how terminals work (PTY, VT parsing, GPU/Metal, fonts, …)
│   ├── 03-analysis/ #   fact-checks, opportunities, requirements, agents-and-xtty
│   └── 04-design/   #   the build plan: stack sketch + phased milestones
└── openspec/        # spec-driven implementation workflow
    ├── config.yaml  #   project context shown to AI when creating artifacts
    ├── specs/       #   established specs (source of truth) — grows as changes land
    └── changes/     #   in-flight change proposals (+ archive/ for completed)
```

Start here: `research/README.md` (index), `research/03-analysis/xtty-requirements.md` (what we're building), `research/04-design/01-stack-sketch.md` + `02-milestones.md` (how).

## Tech stack (primary: "All-Swift")

- **UI/chrome:** Swift + SwiftUI/AppKit
- **Renderer:** custom Metal view (`MTKView`/`CAMetalLayer`), CoreText glyph atlas, dedicated render thread, **latency-first** (frame pacing > throughput)
- **VT engine:** reuse **SwiftTerm**'s headless `Terminal` core (parser + grid)
- **PTY:** Darwin `posix_openpt`/`forkpty` + kqueue read/write loop
- **Shell integration:** OSC 7 (cwd) + OSC 133 (command boundaries) capture

Researched alternatives if we hit limits (Rust core + Swift, Zig/libghostty + Swift, Swift + libghostty-vt) are in `research/04-design/01-stack-sketch.md` with switch triggers.

## Product values (hard requirements)

- **Lean memory** — nowhere near Warp; bound scrollback, manage the glyph atlas, avoid retain cycles.
- **No account / no login, free and open, no paywalled features.**
- **Native macOS feel**; keep the user's existing zsh/tmux/dotfiles working.
- **Great host for agent CLIs** (Claude Code, etc.) — agents pluggable/local, not vendor-locked.

Signature features: at-a-glance per-session progress sidebar (from OSC 133); a *lightweight* in-terminal file/diff view (not a full IDE). Full list: `research/03-analysis/xtty-requirements.md`.

## How to work here

- **Implementation follows the phased plan** in `research/04-design/02-milestones.md` (P0 skeleton → P5 daily-driver → **P7 OSC capture (keystone)** → P8 sidebar → P10 polish). P8/P9 depend on P7.
- **Use OpenSpec for non-trivial changes:** create a change in `openspec/changes/<name>/` (proposal + tasks + spec deltas), get it approved, implement, then archive into `openspec/specs/`. The project `context` in `openspec/config.yaml` is shown to the AI on every artifact.
- **Research is background, not spec.** `research/` records *why*; `openspec/specs/` will record *what is true*. When they conflict once code exists, specs win.

## Conventions

- **Commits: [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/)** — `type(scope): description`. Types seen so far: `docs` (research/design content), `chore` (tooling). Scopes: `research`, `design`, `openspec`. End commit messages with the `Co-Authored-By` trailer when authored with an AI.
- **Research docs** carry a **Provenance** note (date + how produced) and a **Sources** list; fact-checked claims use ✅/❌/❓. Snapshots are dated and time-sensitive — re-verify versions/latency/pricing before quoting.
- **Engineering bias:** macOS-first; **reuse battle-tested components over hand-rolling** (especially the VT parser — use the Williams state machine via a library); favor **latency and low memory** in every tradeoff.
- **Don't track local tooling:** `.claude/` is gitignored.

## Key references

- Requirements: `research/03-analysis/xtty-requirements.md`
- Stack & alternatives: `research/04-design/01-stack-sketch.md`
- Build plan: `research/04-design/02-milestones.md`
- Agent strategy: `research/03-analysis/agents-and-xtty.md`
- Internals deep-dives: `research/02-internals/`
