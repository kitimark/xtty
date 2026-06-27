# AGENTS.md — xtty

Guidance for AI agents (and humans) working in this repository. This is the canonical project guide; `CLAUDE.md` imports it.

## What this project is

**xtty** is a **native macOS terminal emulator**. It is greenfield and in the **build** phase: the app already launches a live terminal (the user's login shell in a SwiftTerm engine hosted in AppKit). The direction, requirements, and design are documented in `research/`; implementation proceeds milestone-by-milestone via the OpenSpec workflow.

## Current status

- ✅ Landscape + internals research, requirements, and a design (stack + milestones) — in `research/`.
- ✅ Spec-driven workflow scaffolded — `openspec/`.
- ✅ Build system live: `project.yml` (XcodeGen) → `xtty.xcodeproj` (gitignored), `XttyCore` SPM package. See **Building** below.
- ✅ **P0 `add-app-skeleton`** — implemented **and archived**.
- ✅ **P1 `integrate-swiftterm`** — implemented **and archived**: live login shell in a SwiftTerm view hosted in an AppKit `NSWindow` (SwiftUI hosting renders the view black on macOS 26), engine routed through `XttyCore`, window opens on the built-in display.
- ✅ **`add-verification-harness`** — implemented **and archived** (13/14 tasks; optional Peekaboo-MCP registration deferred): an XCUITest e2e target (terminal content asserted via a DEBUG engine grid-dump, since the custom-drawn view exposes no text to accessibility) plus Peekaboo for manual driving.
- ✅ **P2 `add-daily-driver-baseline`** — implemented **and archived** (23/23 tasks): a view-free `XttyCore` config loader (`~/.config/xtty/config` → font/theme/scrollback/option-as-meta, unit-tested) applied to the live view; bounded scrollback (default 10 000 / ceiling 100 000); Cmd+F find via SwiftTerm's native bar; live Cmd +/−/0 font sizing. Harness (8/8 UI tests) asserts config-applied + bounded-scrollback (new DEBUG state dump), find, and truecolor/emoji/wide (grid dump fixed for CJK + non-BMP emoji). Ligatures are a no-op in SwiftTerm's grid path; SwiftTerm's Metal renderer evaluated and **deferred to the P7 gate** (`research/03-analysis/swiftterm-metal-renderer-spike.md`).
- 🚧 **P3a `add-tabs-and-splits`** — implemented (pending archive): native macOS tabs + custom `NSSplitView` splits/panes + multiple windows; a view-free pane/session model in `XttyCore` (`Pane`/`PaneNode`/`SessionRegistry`); unified close/exit escalation (pane → tab/window → quit, confirm-close on a running foreground job); **configurable keybindings** (`iterm`/`ghostty` presets + per-action `keybind-<action>` overrides, view-free `KeybindParser`); clickable URL links (SwiftTerm-inherited; non-`http(s)` guard deferred — see the change's design D7). 52 `XttyCore` unit tests + 12 XCUITests green. (P3b — Quick-Terminal + profiles — remains: `research/03-analysis/p3b-shell-ux-decisions.md`.)
- 📋 **Established specs** (`openspec/specs/`): `app-shell`, `terminal-configuration`, `terminal-session`, `verification-harness`.

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

## Building

The Xcode project is generated from a committed `project.yml` via **XcodeGen**; the resulting `xtty.xcodeproj` is **gitignored** (never commit it).

- **Prerequisite:** XcodeGen — `brew install xcodegen` (developed against **v2.45.4**). Building/testing the app target needs **full Xcode** (the Command Line Tools alone lack `xcodebuild`, `XCTest`, and swift-testing). Verified against **Xcode 26.6**.
- **Metal Toolchain (one-time):** SwiftTerm bundles a `.metal` shader, so even though we don't use its renderer yet, the build compiles it. On Xcode 26+ the Metal compiler is a separate component — install it once with `sudo xcodebuild -downloadComponent MetalToolchain` (or Xcode → Settings → Components) or the build fails with `cannot execute tool 'metal'`.
- **Generate the project:** `xcodegen generate` (re-run after editing `project.yml` or adding/removing source files).
- **Build & run:** open `xtty.xcodeproj` in Xcode, or `xcodebuild -project xtty.xcodeproj -scheme xtty build`.
- **Core package:** `XttyCore` is a local SPM package (the engine-facing seam). It builds/tests standalone from `XttyCore/` via `swift build` / `swift test` (tests need Xcode's toolchain for XCTest).

Signing posture (P0): **App Sandbox OFF** (`App/xtty.entitlements`), **Sign to Run Locally** (ad-hoc identity), Hardened Runtime/notarization deferred.

## Product values (hard requirements)

- **Lean memory** — nowhere near Warp; bound scrollback, manage the glyph atlas, avoid retain cycles.
- **No account / no login, free and open, no paywalled features.**
- **Native macOS feel**; keep the user's existing zsh/tmux/dotfiles working.
- **Great host for agent CLIs** (Claude Code, etc.) — agents pluggable/local, not vendor-locked.

Signature features: at-a-glance per-session progress sidebar (from OSC 133); a *lightweight* in-terminal file/diff view (not a full IDE). Full list: `research/03-analysis/xtty-requirements.md`.

## How to work here

- **Implementation follows the phased plan** in `research/04-design/02-milestones.md` (P0 skeleton → P5 daily-driver → **P7 OSC capture (keystone)** → P8 sidebar → P10 polish). P8/P9 depend on P7.
- **Use OpenSpec for non-trivial changes** (see the OpenSpec workflow section below). The project `context` in `openspec/config.yaml` is shown to the AI on every artifact.
- **Research is background, not spec.** `research/` records *why*; `openspec/specs/` will record *what is true*. When they conflict once code exists, specs win.
- **Write up research in `research/` when it's done.** Whenever an investigation or spike produces durable findings — a tooling landscape, a comparison, an internals discovery, a dead end worth remembering — capture it as a `research/` doc *as soon as it settles* (even mid-build), in the right subfolder (`03-analysis/` for analysis, `02-internals/` for internals, `04-design/` for build-plan shifts). Follow the research-doc conventions (Provenance + Sources + ✅/❌/❓) and add it to `research/README.md`. Keep the *why/landscape* in `research/`; the actionable *decision* belongs in the OpenSpec change.
- **Keep progress current when implementation lands.** When a change (or a milestone's tasks) is done, update the trackers in the same session: tick the `tasks.md` checkboxes, refresh **Current status** above, and advance the milestone state in `research/04-design/02-milestones.md`. Don't leave finished work looking pending or stale.

## OpenSpec workflow

We do **spec-driven development**: formalize *what* changes as reviewable artifacts, approve, then implement. Don't write feature code straight from a chat prompt — capture it as a change first.

**The loop** (one change per milestone from `research/04-design/02-milestones.md`):

```
explore ──▶ propose ──▶ apply ──▶ archive
(think)    (artifacts) (implement) (merge into specs/)
```

**Slash commands** (preferred entry points):
- `/opsx:explore <topic>` — thinking/investigation mode. **Never implements**; may read code/clone OSS to `/tmp` for understanding and may create OpenSpec artifacts. Use it before committing to an approach.
- `/opsx:propose <name>` — create a change and generate all artifacts (`proposal.md` → `design.md` + `specs/` → `tasks.md`).
- `/opsx:apply` — implement a proposed change by walking its `tasks.md` checkboxes. This is where real code gets written.

**Underlying CLI** (`openspec`, v1.4.x):
- `openspec list` — active changes · `openspec list --specs` — established specs
- `openspec new change "<name>"` — scaffold a change
- `openspec status --change "<name>" [--json]` — artifact build order & paths
- `openspec instructions <artifact> --change "<name>" --json` — template + rules for an artifact (follow these; do NOT copy the `context`/`rules` blocks into the file)
- `openspec validate "<name>"` — validate before committing
- `openspec archive "<name>"` — on completion, merge spec deltas into `openspec/specs/`

**Artifact order & dependencies:** `proposal` → (`design` + `specs`) → `tasks`. `tasks` is the apply gate.

**Spec delta format** (in `changes/<name>/specs/<capability>/spec.md`):
- Use `## ADDED Requirements` / `## MODIFIED Requirements` / `## REMOVED Requirements`.
- `### Requirement: <name>` with **SHALL/MUST** (avoid should/may); every requirement needs ≥1 scenario.
- `#### Scenario: <name>` with **WHEN/THEN** — scenarios MUST use exactly **4 hashtags** (3 fails silently).

**Lifecycle rule:** `openspec/specs/` is the source of truth and only grows via `openspec archive` after a change is implemented. In-flight work lives in `openspec/changes/<name>/`. Commit proposal artifacts as `docs(openspec): …`; commit the implementation under the relevant `feat`/`chore` scope.

**After archiving, finish the merge by hand:** `openspec archive` merges spec deltas mechanically, so check the result before committing — (1) fill in the `## Purpose` of any **newly-created** spec (archive stubs it with `TBD - … Update Purpose after archive.`); (2) make the merged requirement text reflect *what actually shipped*, not what the proposal guessed (specs record what is true — e.g. correct the delta if the implementation diverged); (3) `openspec validate --all --type spec` and skim the diff for collapsed blank lines. Then commit as `docs(openspec): archive …`.

**Current open changes:** `add-tabs-and-splits` (P3a) — **implemented, pending `/opsx:archive`** (tabs/splits/windows + configurable keybindings + clickable links; tests green). The architectural seam (all logic talks to the `Terminal` engine via `XttyCore`, never the view) and the staged SwiftTerm L3-start decision are in place — see `research/04-design/01-stack-sketch.md`. Next: archive P3a, then scope **P3b** (`add-quick-terminal` + `add-profiles`) — decisions captured in `research/03-analysis/p3b-shell-ux-decisions.md`.

## Conventions

- **Commits: [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/)** — `type(scope): description`. Types used so far: `docs` (research/design/openspec content), `feat`/`test` (implementation), `chore` (tooling). Scopes: `research`, `design`, `openspec`, `app`. End commit messages with the `Co-Authored-By` trailer when authored with an AI.
- **Research docs** carry a **Provenance** note (date + how produced) and a **Sources** list; fact-checked claims use ✅/❌/❓. Snapshots are dated and time-sensitive — re-verify versions/latency/pricing before quoting.
- **Engineering bias:** macOS-first; **reuse battle-tested components over hand-rolling** (especially the VT parser — use the Williams state machine via a library); favor **latency and low memory** in every tradeoff.
- **Don't track local tooling:** `.claude/` is gitignored.

## Key references

- Requirements: `research/03-analysis/xtty-requirements.md`
- Stack & alternatives: `research/04-design/01-stack-sketch.md`
- Build plan: `research/04-design/02-milestones.md`
- Agent strategy: `research/03-analysis/agents-and-xtty.md`
- Internals deep-dives: `research/02-internals/`
