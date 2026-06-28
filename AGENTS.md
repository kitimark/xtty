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
- ✅ **P3a `add-tabs-and-splits`** — implemented **and archived**: native macOS tabs + custom `NSSplitView` splits/panes + multiple windows; a view-free pane/session model in `XttyCore` (`Pane`/`PaneNode`/`SessionRegistry`); unified close/exit escalation (pane → tab/window → quit, confirm-close on a running foreground job); **configurable keybindings** (`iterm`/`ghostty` presets + per-action `keybind-<action>` overrides, view-free `KeybindParser`); clickable URL links (SwiftTerm-inherited; non-`http(s)` guard deferred — see the archived change's design D7). 52 `XttyCore` unit tests + 12 XCUITests green.
- ✅ **P3b** — ✅ **`add-quick-terminal`** — implemented **and archived**: a global-hotkey "quake" drop-down — a borderless non-activating `NSPanel` toggled by a Carbon `RegisterEventHotKey` hotkey (no TCC prompt), hosting one persistent scratch shell; a view-free `HotKeyParser`/`HotKeySpec`/`HotKeyResolver` in `XttyCore` (positional `kVK_*` codes, reusing `ModifierSet` + a shared `ChordTokenizing` grammar with `KeybindParser`); accessory lifecycle via a **private `SessionRegistry`** (excluded from the main inventory + quit accounting); `quick-terminal` + `quick-terminal-hotkey` config keys kept out of `terminal-configuration`. 69 `XttyCore` unit + 13 XCUITests green. ✅ **`add-profiles`** — implemented **and archived**: named `[profile "name"]` sections in the existing config file (case-preserving `parseSections`, backward-compatible — flat file == base), each a `LaunchOverride` + inherited `XttyConfig` assembled into an `XttyConfigSet`; a `command` runs through the user's login+interactive shell (`$shell -l -i -c '<command>'` — `execve`/no-PATH reality) with `cwd` + additive `env` (PATH off-limits); `PaneController` takes a resolved `XttyProfile` and retains it so a split inherits it; `Pane` carries `profileName`; `default-profile` + a dynamic "New Tab with Profile ▸" menu; quake uses base appearance + a plain login shell; `confirm-close` wired (D10). 91 `XttyCore` unit + 14 XCUITests green. Decisions: `research/03-analysis/p3b-shell-ux-decisions.md`.
- ✅ **P4a `add-semantic-capture`** — implemented **and archived**: the keystone's data half, fork-free on SwiftTerm's public API. **OSC 7** live cwd captured via the wired `hostCurrentDirectoryUpdate` delegate + view-free `OSC7` decoder (`file://`/`kitty-shell-cwd://`, remote-host flag); **splits open in the focused pane's live cwd**. **OSC 133** registered on the engine; view-free `OSC133` parser (A/B/C/D/P, bare-positional exit code, `cmdline`/`cmdline_url`, `k=s`) → view-free `BlockTracker` state machine + per-session `Block` list (command/exit/cwd/timestamps/state — **no fragile row coords**). **Auto-injects zsh** via `ZDOTDIR` redirection (bundled `.zshenv` restores the user's config; additive `add-zsh-hook`; skipped for `command` one-shots; manual fallback in `config.example`). **Alt-screen gating** via an `open bufferActivated` override + public `isCurrentBufferAlternate` (full-screen apps → `opaque`; OSC 133 best-effort, tmux/ssh → plain output). 126 `XttyCore` unit + 17 XCUITests green (block/cwd e2e drive a real injected zsh). **P4b split in two:** **P4b-1 `add-file-link-open`** + **P4b-2 `add-spatial-blocks`** both shipped (next bullets); gutter fail-marks dropped (folded into the P5 sidebar). Decisions: `research/03-analysis/p4-semantic-capture-decisions.md` + `research/03-analysis/p5-sidebar-and-p4b-sequencing.md`.
- ✅ **P5 `add-session-sidebar`** — implemented **and archived**, fork-free on P4a's block model. View-free additions in `XttyCore`: `BlockTracker.runningBlock` (the in-flight command, no coordinates), a `SessionActivity` enum + pure `derive` (fullScreen→running→failed→succeeded→idle) surfaced on `TerminalSession.activity`/`runningCommand`, and an `@Observable SessionRegistry` with a `revision` bumped on register/unregister/focus + `noteActivityChange()` (called from the main-actor OSC handlers). App: a SwiftUI `Tab ▸ Pane` sidebar (`SessionSidebar.swift`) hosted in a collapsible left panel (Auto-Layout `terminalContainer` refactor in `TerminalWindowController`), click → `focusPane` (reuses `setActivePane`, never scroll-to-row), live duration via `TimelineView`, View ▸ Toggle Sidebar (⌃⌘S). State dump gains `sessionActivity` + `runningCommand`; new sidebar e2e. 134 `XttyCore` unit + 18 XCUITests green.
- ✅ **P4b-1 `add-file-link-open`** — implemented **and archived**, the fork-free agent-CLI half of P4b on SwiftTerm `v1.13.0`. **Cmd-click a `file:line[:col]`** (or bare/relative/rooted path) → opens in the user's editor at that line, resolved against the focused session's live OSC-7 cwd; plus the deferred **D7 scheme guard** (only `http`/`https`/`mailto` auto-open; other schemes blocked). View-free `XttyCore` `LinkOpen.swift` — classify (URL vs `path:line:col`) → scheme guard → cwd-relative resolution → opener-invocation build (template tokenization + `$VISUAL`/`$EDITOR` editor-inference table), composed in `LinkRouter`; new `link-opener` config key. Interception is a **vetted `terminalDelegate` proxy** (`LinkRoutingTerminalDelegate`) that forwards the other 9 delegate methods to the view and routes only `requestOpenLink` — because `requestOpenLink` is *not* forwarded to `processDelegate` and its protocol-extension default can't be subclass-overridden (design D1). `FileOpener` execs the editor via `Process` with login-shell PATH resolution; the path is always a literal argv element, never a shell string (D4). Harness: DEBUG dump gains `lastLinkOpen`; an `XTTY_TEST_LINK_PATH` launch-env file trigger drives routing in-process (the sandboxed runner can't write `/tmp`). 148 `XttyCore` unit + 20 XCUITests green (validated robust under deliberate mouse interference — the mis-click surfaced as a 50s `Synthesize event` timing anomaly, not a failure).
- ✅ **P4b-2 `add-spatial-blocks`** — implemented **and lit up** (pending archive). **Jump-to-prompt** (Cmd+Shift+↑/↓ → `scrollTo` an earlier prompt) + **copy-command-output** (Cmd+Shift+C → engine-only `getText`→clipboard, trailing prompt excluded, + a non-modal `SpatialToast`). Built on a **2-accessor** SwiftTerm addition (`getScrollInvariantCursorLocation` + `scrollbackBase`) shipped via a **pinned gitignored upstream clone + `git apply`'d patch — no fork repo** (`external/SwiftTerm` @ `v1.13.0` pinned via `patches/swiftterm/UPSTREAM_CONFIG.sh` + `git apply`'d `patches/swiftterm/xtty-accessors.diff` via `scripts/bootstrap-swiftterm.sh` + a local-path SPM dep; the Playwright-style patch-in-repo, see `research/03-analysis/swiftterm-fork-vs-patch-strategy.md`). View-free `XttyCore`: optional best-effort `BlockAnchor` (prompt/output-start/output-end rows captured at OSC-133 A/C/D, epoch-stamped) + pure `BlockNavigation` (reverse-map, stateless prev/next, copy range); **invalidation** = `bumpEpoch` on `sizeChanged` (resize/reflow) + `liveTop` high-water-drop on `scrolled`/marks (clear/reset) + validate-at-use, all degrading gracefully to no-op. Built behind a **deferred injectable seam** (Phase 1 nil → no-op, fake-tested; Phase-2 light-up = a 2-line seam swap). **Tier-2 visual-select deferred** (forks the view, P7-gated); upstream PR prepared (the accessor file), not yet filed. 162 `XttyCore` unit + 23 XCUITests green (3 spatial e2e on real injected zsh). Decisions: `research/03-analysis/p4b-2-spatial-blocks-decisions.md`. **(Archived.)**
- ✅ **P6a `add-git-review`** — implemented **and archived**: a read-only **git-review panel** — the focused pane's changed files grouped **Changes / Untracked / Conflicts** → click-to-diff (a plain **unified** SwiftUI diff), ⌘-click → editor (reuses P4b-1 `LinkRouter`/`FileOpener`), in a new collapsible **trailing-edge** panel (the left edge stays the P5 session sidebar), **default-collapsed** (View ▸ Toggle Git Review, ⌃⌘G). Git via **shell-out** (no libgit2): view-free `XttyCore` `GitStatusParser`/`NumstatParser`/`DiffParser` + an `@Observable GitReviewStore`; App-layer `GitRunner` (login-shell PATH, `GIT_OPTIONAL_LOCKS=0`, **porcelain v1 `-z`**, `--no-ext-diff --no-color`, `git diff HEAD` / `--no-index` exit-1-ok) + a `GitReviewController` (refresh on OSC-133 `commandEnd` + a ~5 s poll backstop + focus + manual, **debounced + serialized + visible/local-gated**). New `diff-context` config key (editor reuses `link-opener`). Read-only (staging deferred, model forward-compatible). `gitReview` DEBUG dump + e2e. **185 `XttyCore` unit + 25 XCUITests green.** Decisions: `research/03-analysis/p6-file-diff-decisions.md`.
- 📋 **Established specs** (`openspec/specs/`): `app-shell`, `build-workflow`, `terminal-configuration`, `terminal-keybindings`, `terminal-links`, `terminal-multiplexing`, `quick-terminal`, `terminal-session`, `terminal-semantics`, `shell-integration`, `session-sidebar`, `git-review`, `terminal-spatial-blocks`, `verification-harness`.

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

**Quick start — use the `Makefile`.** It is the single entry point; run `make` (no target) to list everything. It only wraps the commands documented below.

| Command | What it does |
| --- | --- |
| `make doctor` | check the prerequisites you must install yourself (XcodeGen, full Xcode, Metal toolchain) and print how to get each |
| `make setup` | first-time, post-clone: `doctor` → bootstrap SwiftTerm → generate the project |
| `make build` / `make run` | build (then launch) the app — **auto-bootstraps SwiftTerm and regenerates the project only when their tracked inputs changed** |
| `make test-core` | the fast `XttyCore` unit loop (no app build) |
| `make test` | the app XCUITests |
| `make bootstrap` / `make generate` | force a re-run after editing the SwiftTerm pin/patch or `project.yml` |
| `make clean` / `make reset` | remove build outputs / nuke + rebuild the SwiftTerm checkout |

The targets are thin wrappers — reach for the underlying commands below directly if you're not using `make`, or to understand what a target does:

- **Prerequisite:** XcodeGen — `brew install xcodegen` (developed against **v2.45.4**). Building/testing the app target needs **full Xcode** (the Command Line Tools alone lack `xcodebuild`, `XCTest`, and swift-testing). Verified against **Xcode 26.6**.
- **SwiftTerm checkout (one-time, P4b-2):** SwiftTerm is consumed as a **gitignored upstream clone** at `external/SwiftTerm`, pinned via `patches/swiftterm/UPSTREAM_CONFIG.sh` (currently `v1.13.0`) with an add-only **patch** applied — the no-fork "patch in repo" mechanism, Playwright-style (see `research/03-analysis/swiftterm-fork-vs-patch-strategy.md`). After cloning xtty, run **`scripts/bootstrap-swiftterm.sh`** — it clones `external/SwiftTerm`, checks out + cleans to the pinned ref (enforced every run), and `git apply`s `patches/swiftterm/xtty-accessors.diff`. Re-run it after editing the pin or the patch. The build fails to resolve `../external/SwiftTerm` until this runs. Nothing under `external/SwiftTerm` is tracked (it's `.gitignore`d build infra); only the pin + the `.diff` + the script are version-controlled. Retire the whole mechanism once the accessors land in an upstream SwiftTerm release.
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

**Keeping a change coherent — what to update when a requirement changes.** The four artifacts are a dependency chain (`proposal → design + specs → tasks`), so a requirement edit rarely lives alone. When you add/modify/remove a requirement in `changes/<name>/specs/`, walk this list, then run `openspec validate "<name>"` (it catches missing deltas/scenarios):
- **`proposal.md` → Capabilities** is the contract with `specs/`: every capability a spec delta touches MUST appear under **New** or **Modified Capabilities** (and vice-versa — no orphan spec dir, no listed-but-absent capability). Refresh **What Changes** / **Impact** if scope moved.
- **`specs/<capability>/spec.md`** — keep requirements **mechanism-neutral (the *what*)**; the *how* (fork vs seam, file/type names, concrete APIs) belongs in `design.md`, never inside a requirement. A **MODIFIED** requirement MUST paste the **entire** existing block from `openspec/specs/<capability>/spec.md` and edit it (partial content silently loses detail at archive). A behavioral change usually spans **multiple capabilities** — e.g. a new keybind action also touches `terminal-keybindings`; a new config key touches `terminal-configuration`.
- **`verification-harness` (almost always, in this repo)** — the custom-drawn view exposes nothing to accessibility, so any **new observable behavior** needs *both* a `verification-harness` spec delta (a new DEBUG state-dump field/observation + an e2e scenario) **and** a harness task. 7 of the 10 archived changes carried a harness delta for exactly this reason — if the harness can't see it, it isn't done.
- **`design.md`** — re-check that decisions and requirements still justify each other *both ways*: a changed decision can leave a requirement over-/under-specified (neutralize it — e.g. drop a hard-coded mechanism), and a new requirement may need a decision plus a Risks / Migration / Open-Questions update.
- **`tasks.md`** — every requirement needs build **and** verify tasks; add or re-order them when requirements change (and split deferred work into its own task group rather than blurring scope).
- **`research/`** — the *why* stays in `research/` (update the relevant doc **and** its `research/README.md` line when a decision/finding shifts); the actionable *decision* stays in the change. Trackers (AGENTS **Current status**, the milestone state) are updated on completion per **Keep progress current**.

**Lifecycle rule:** `openspec/specs/` is the source of truth and only grows via `openspec archive` after a change is implemented. In-flight work lives in `openspec/changes/<name>/`. Commit proposal artifacts as `docs(openspec): …`; commit the implementation under the relevant `feat`/`chore` scope.

**After archiving, finish the merge by hand:** `openspec archive` merges spec deltas mechanically, so check the result before committing — (1) fill in the `## Purpose` of any **newly-created** spec (archive stubs it with `TBD - … Update Purpose after archive.`); (2) make the merged requirement text reflect *what actually shipped*, not what the proposal guessed (specs record what is true — e.g. correct the delta if the implementation diverged); (3) `openspec validate --all --type spec` and skim the diff for collapsed blank lines. Then commit as `docs(openspec): archive …`.

**Current open changes:** none. **`add-git-review` (P6a)** is implemented **and archived**; **P6a+ `add-git-review-polish`** is **decided** (research captured in `research/03-analysis/p6-file-diff-decisions.md` → "P6a+ addendum") and **pending proposal**. P0/P1/P2/**P3a** + **P3b (`add-quick-terminal` + `add-profiles`)** + the verification harness + **P4a (`add-semantic-capture`)** + **P5 (`add-session-sidebar`)** + **P4b-1 (`add-file-link-open`)** + **P4b-2 (`add-spatial-blocks`)** + **P6a (`add-git-review`)** are implemented and archived. P4b-2 was the **first non-fork-free change** — it adds a 2-accessor SwiftTerm addition via a gitignored upstream clone + `git apply` patch (no fork repo; see `research/03-analysis/swiftterm-fork-vs-patch-strategy.md`). P6a is fork-free again (git via the system binary, no new deps). **Next: P6a+ `add-git-review-polish` (decided — token-level intra-line diff emphasis + a pause-during-own-git poll guard; syntax highlighting / FSEvents stay deferred), then the deferred P6b file-tree browser**, the **Tier-2 visual on-screen selection** (forks the view; P7-gated), the optional **clickable per-block sidebar (P4b-3)**, and **P7 (measure)**. Sequencing rationale: `research/03-analysis/p5-sidebar-and-p4b-sequencing.md`. Outstanding manual-only checks: the quake's real global keypress / multi-monitor / focus-return; P4a/P5 shell-integration with *uncooperative* host zsh configs (the e2e degrades gracefully there); the sidebar's real cross-tab focus + collapse on a live multi-tab window. The architectural seam (all logic talks to the `Terminal` engine via `XttyCore`, never the view) holds — see `research/04-design/01-stack-sketch.md`.

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
