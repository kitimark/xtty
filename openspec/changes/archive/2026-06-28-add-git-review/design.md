## Context

P6 (requirement H2) is the file/diff view. The keystone it needs already shipped: P4a exposes a live local cwd (`TerminalSession.liveLocalDirectory`, with a remote guard) and P4b-1 exposes safe click-to-open-in-editor (`LinkRouter`/`FileOpener`, login-shell PATH, literal-argv D4 rule). This change implements **P6a** only — a read-only git-review panel — and defers the full file-tree browser (P6b) and all write operations.

The decisions below are the distilled, **source-grounded** conclusions of a two-pass research effort (web + xtty-codebase, then a deep-read of the actual source of zed, vscode, lazygit, gitui, delta, waveterm). Full evidence + file:line citations: **`research/03-analysis/p6-file-diff-decisions.md`**. The architectural seam (all logic in `XttyCore`, the view renders plain value snapshots) and the panel-hosting pattern come from the P5 session sidebar (`App/SessionSidebar.swift` + `TerminalWindowController.buildLayout`).

## Goals / Non-Goals

**Goals:**
- A lean, read-only "review what changed (incl. agent edits) before commit" panel that reuses the cwd + editor-open plumbing already shipped.
- Zero new third-party dependencies; honor the lean-memory / latency-first / not-a-full-IDE / agent-host values.
- Keep all git parsing view-free and unit-testable in `XttyCore`; keep the panel a SwiftUI peer of the session sidebar.

**Non-Goals:**
- Full project file-tree browser (P6b); staging / commit / discard / any write op (pair with `lazygit`).
- Syntax highlighting; word-level intra-line diff; side-by-side diff; ahead/behind counts; FSEvents file watching.
- Any libgit2 / SPM dependency. A configurable keybind action for the toggle (it's a fixed View-menu shortcut, like Toggle Sidebar).

## Decisions

### D1 — Read git by shelling out to the system `git` (not libgit2)
Reuse the `App/FileOpener.swift` pattern (Process + `ShellResolver` login-shell `command -v` PATH resolution + literal argv) in a new App-layer `GitRunner` — but with **stdout capture** (`FileOpener.run` discards stdout, so only the pattern is reused). *Why:* zero new deps (M1 lean), and every comparable CLI tool shells out (zed `crates/git/src/repository.rs`, VS Code `extensions/git/src/git.ts`, lazygit). The lone libgit2 user (gitui) needs a linked native lib; Swift's SwiftGit2 has **no SPM support** (vendors libgit2 as a submodule + Carthage/Xcode-project) — confirmed by inspection. *Alternative rejected:* a libgit2 binding — binary weight + a CMake/XCFramework build step on top of the XcodeGen+Metal-only build, for parse-robustness a read-only panel doesn't need.

Canonical invocations (git resolved to an absolute path; every path a literal argv element after `--`; `GIT_OPTIONAL_LOCKS=0` on all reads; `--no-ext-diff --no-color` on all diffs):
1. Discovery: `git -C <cwd> rev-parse --show-toplevel` (empty/nonzero → not a repo).
2. Status: `git --no-optional-locks -C <top> status --porcelain=v1 -z --untracked-files=all --no-renames`.
3. Branch header (optional): `git -C <top> symbolic-ref --short HEAD` (detached → short SHA).
4. Per-file +/- badges: `git --no-optional-locks -C <top> diff --numstat -z [-- <path>]` (binary → `-\t-`).
5. Diff (lazy, on selection): tracked → `git -C <top> diff --no-ext-diff --no-color [--unified=N] -- <path>`; untracked → `… diff --no-index -- /dev/null <path>` (**exit 1 == success**, not failure).

### D2 — Status: porcelain **v1** `-z`, not v2; branch fetched separately
Source-grounded correction from the first pass's v2 guess: **no mature tool uses porcelain v2 for the file list** (VS Code/lazygit/zed all use v1), and none folds `--branch` into status (branch/upstream come from `symbolic-ref`/`for-each-ref`). v1 is a fixed `XY␠<path>` per `-z` record — simpler than v2's mode/oid/submodule columns. `-z` auto-disables `core.quotepath` (raw UTF-8 paths, no octal escapes). Parser gotchas (all from real parsers): skip trailing-slash dir entries; sort+dedup by path (git can emit duplicates / delete-recreate pairs); map the 7 unmerged XY combos (DD/AU/UD/UA/DU/AA/UU) → Conflicts before the per-side switch. With `--no-renames`, a rename surfaces as `D <old>` + `?? <new>` (no two-path parse needed). *Alternative rejected:* porcelain v2 — dead-weight columns for a read-only panel.

### D3 — Layout: a trailing-edge collapsible panel, default-collapsed
Place it on the **right** edge (left stays the session sidebar). Mirror — but do not blind-copy — the sidebar mechanism: an `NSHostingView` with its own width constraint + a `toggleGitPanel()` clone of `toggleSidebar()`, wired to a View-menu item + a default **⌃⌘G** (parallels the sidebar's ⌃⌘S; ⌘G is Find Next, no conflict). *Integration note:* `buildLayout()` pins `terminalContainer.trailingAnchor` to the container's trailing (`TerminalWindowController.swift:176`); adding a right slot means **repointing that constraint** to the new host's leading anchor — a constraint rework, not a symmetric paste. **Default-collapsed** because the 900×560 default window with both panels open leaves the terminal cramped (~420 pt) and the panel is only useful in a repo. *Alternative considered:* native SwiftUI `.inspector` (macOS 14, leaner) — left as an implementation-time spike; the AppKit mirror keeps `buildLayout` consistent. *Alternative rejected:* left-edge or a mode-switched single sidebar (competes with the #1 feature); a full-height overlay (less native).

### D4 — Diff rendering: plain unified, in SwiftUI
Unified (a narrow panel can't fit side-by-side; unified is delta's default). **No syntax highlighting** in v1 — the only zero-dep choice (Splash=Swift-only, Highlightr ships a JS runtime, tree-sitter bundles grammars; all fail M1). Parse `git diff` into a view-free `Files→Hunks→Lines` model (the exact minimal shape lazygit `patch/patch_line.go` + gitui `sync/diff.rs` ship: classify each line by leading char; `@@` regex for hunk headers). The SwiftUI view renders one `Text` per `DiffLine` styled by kind in a `List`/`LazyVStack` (free virtualization). **Large-diff caps:** ~3000-char per-line truncation (delta's default), a per-file rendered-line cap → "diff too large — open in editor" (reuse `FileOpener`), binary → "Binary file (no preview)" summary, each file's diff lazy-loaded on selection. *Rejected:* reusing a SwiftTerm view to render the diff (a second VT engine = memory vs M1, loses structure/click-to-line, violates the no-view-import seam). Word-level intra-line diff is a bounded, cheap-if-gated P6a+ overlay (zed/delta both gate it hard), not v1.

### D5 — Refresh: `.commandEnd` fast-path + gated poll backstop, debounced/serialized
Do **not** drive git off `registry.revision` (it bumps on every OSC-133 mark + alt-screen + focus, no debounce — a LEAN violation). Instead, branch `if case .commandEnd = mark` in the existing main-actor OSC-133 handler (`PaneController.swift:131`) → notify a dedicated `@Observable GitStatusStore` in `XttyCore` (keyed by repo toplevel to dedup panes in the same worktree). Source-grounded correction: **OSC-133-D alone is too weak** — it fires only *after* a command, so an agent editing files mid-command is invisible the whole run. Both git TUIs solve this with a low-frequency **poll** (lazygit ~10 s, gitui ~5 s) and neither watches the FS by default → add a **~5 s poll backstop** (cheap: `git status` is `.gitignore`-aware, no `node_modules` storm), keep **FSEvents deferred**. Borrow VS Code's pipeline (`repository.ts`): **~200 ms debounce** (coalesce a D-burst) + **~5 s minimum spacing** between actual spawns + **serialize** (one in-flight + one pending) + run git off-main, publish on main. **Gate** (all required): panel-visible AND focused `liveLocalDirectory != nil` AND idle. Plus refresh on focus-change + panel-open + manual; **pause during the user's own foreground git**. *Escalation path (deferred):* FSEvents scoped to worktree root with VS Code's ignore-set, only if the 5 s poll proves too slow in real agent sessions.

### D6 — Grouping by status category; read-only; deleted muted
Group by **Changes / Untracked / Conflicts** (hide-when-empty), not staged/unstaged (a staged frame needs staging, which we don't have) — VS Code's resource-group model, zed's section model. Flat list (no tree) in v1; model rows behind a single enum so the P6b tree is additive. Per-file glyph+color from the status; **render deleted files muted, not red** (zed's deliberate tweak). **Read-only** is a conscious narrowing — every comparable tool is read-write — so keep the `GitFile`/status value type **forward-compatible with a later per-file stage state** even though nothing writes in v1.

### D7 — Seam split: XttyCore parsers + App GitRunner
View-free `XttyCore`: a `GitStatusParser` (porcelain v1) + a `DiffParser` (unified diff), each unit-tested like `OSC133`/`LinkOpen`; an `@Observable GitStatusStore` holding the cached snapshot. App layer: `GitRunner` (the Process side effect) + a SwiftUI `GitReviewView` (peer of `SessionSidebarView`) fed via a provider closure + the store's revision. `XttyCore` stays free of Process/AppKit.

### D8 — Harness: state-dump-first, cached snapshot, reuse link-open
Follow the established DEBUG state-dump convention (the SwiftUI sidebar already asserts via the dump, not AX). Add one compact, **cached** `gitReview` field to `writeStateDump()` (`TerminalWindowController.swift:517`) — `{ isRepo, isRemote, repoRoot, branch, changedFiles:[{path,status,added,removed}], selectedDiff:{path,added,removed,isBinary,truncated}, refreshCount }`, **never full diff text**, and **never** triggering a git exec inside the dump path (it fires on the 0.15 s timer). A new env-file trigger `XTTY_TEST_GIT_SELECT` (mirroring `routePendingTestLink`/`routePendingTestSpatialOp`) drives click→diff; ⌘-click→editor reuses `XTTY_TEST_LINK_PATH` + the existing `lastLinkOpen` field verbatim. e2e drives a real injected zsh in a temp repo.

### D9 — Config + toggle
One new config key `diff-context` (non-negative int, default 3; `terminal-configuration` schema). The editor opener reuses the existing `link-opener` key — **no new editor key**. The toggle is a **fixed View-menu item + ⌃⌘G**, specified in the `git-review` capability (like the session sidebar's toggle) — **not** a configurable `keybind-<action>`; `terminal-keybindings` (the preset+override system) is intentionally left untouched.

## Risks / Trade-offs

- **Repeated `git` spawns churn on a hot command loop** → debounce (~200 ms) + min-spacing (~5 s) + serialize + visible/idle gating + pause-during-own-git; git runs off-main.
- **Poll backstop (5 s) may feel stale during long agent sessions** → it's an interval spike (D5); escalate to FSEvents (worktree-scoped, VS Code ignore-set) only if dogfooding shows it. Keep it configurable-from-code.
- **`git` not on a GUI-launched app's PATH** → login-shell `command -v` like `FileOpener`; on failure show a "git not found" empty state.
- **Default-collapsed hurts discoverability** → View-menu item + a documented ⌃⌘G; accepted for lean/real-estate reasons.
- **Read-only diverges from every comparable tool (which writes)** → deliberate (lean, not-an-IDE, pair with lazygit); the data model stays stage-toggle-ready so a later change isn't a reshape.
- **Huge diffs/repos block the UI** → off-main + line/char caps + "open in editor" escape hatch + a spinner, never a blocking call.

## Migration Plan

Additive only. The `diff-context` key is forward-compatible (absent → default 3; existing configs unaffected). No data migration, no behavior change to existing panes. The panel ships default-collapsed, so existing windows look identical until toggled. Rollback = revert the change; nothing persisted.

## Open Questions

Cheap spikes to settle **during** build (not blockers — see `research/03-analysis/p6-file-diff-decisions.md` §Residual unknowns):
1. Can the XCUITest runner `Process`-exec `git` into a HOME-relative temp repo for a hermetic test, or must setup drive the live shell?
2. Does login-shell `command -v git` resolve reliably when only Xcode Command Line Tools are installed?
3. Large-repo `git status` latency (cold GUI-launched vs warm) — confirms the 200 ms debounce / 5 s spacing / 5 s poll windows and that off-main is mandatory.
4. Poll-backstop interval — is 5 s the right floor for mid-agent-session freshness, or 2–3 s? Decide from real Claude-Code sessions before considering FSEvents.
5. Diff readability at ~260–300 pt inline on the built-in display when `terminalContainer` is also split — determines whether side-by-side ever needs a wider/detached host.
6. `.inspector` (macOS 14) vs the hand-rolled AppKit mirror — benchmark during implementation.
