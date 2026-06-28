## Why

xtty's milestone P6 (requirement **H2**) is the user's "Zed habit" — seeing changed files and their diffs *before committing*, without leaving the terminal. The keystone it needs is already shipped: P4a gives a live local cwd (OSC 7) and P4b-1 gives safe click-to-open-in-editor. The differentiated, agent-host slice of H2 — *review what changed (including what an agent just edited), then commit* — is a small, lean addition on top of that, and **no lean terminal ships it today**. The full file-tree browser is the separable, more-IDE-ish half and is explicitly deferred. Decisions: `research/03-analysis/p6-file-diff-decisions.md`.

## What Changes

- **New read-only git-review panel (P6a).** A collapsible panel (trailing/right edge, leaving the left edge for the P5 session sidebar) that lists the focused pane's changed files for its local git repository, grouped by status category (**Changes / Untracked / Conflicts**), and shows a read-only **unified diff** of a selected file.
- **Click-to-diff / ⌘-click-to-open.** Clicking a changed file shows its diff in the panel; ⌘-clicking opens it in the user's editor at the line (reusing the existing `link-opener` plumbing from P4b-1).
- **Toggleable, default-collapsed.** A View-menu item + a default ⌃⌘G chord toggle the panel (mirroring the session sidebar's fixed ⌃⌘S shortcut). It starts collapsed so it never costs terminal width or any work until invoked.
- **Lean, agent-aware refresh.** The panel refreshes when a command finishes (OSC 133), plus a low-frequency periodic backstop so a long-running agent editing files *mid-command* isn't invisible, plus on focus-change and a manual refresh — all debounced, rate-limited, and gated to "panel visible AND focused session is a local repo".
- **Read-only.** No staging / commit / discard / any write op in this milestone (pair with `lazygit`); the data model stays forward-compatible with a later stage toggle.
- **One new config key** `diff-context` (unified-diff context lines; default 3). The editor opener reuses the existing `link-opener` key (no new key for that).
- **Verification:** a new `gitReview` DEBUG state-dump field + e2e scenarios (the custom-drawn terminal exposes nothing to accessibility, so observable behavior is asserted via the state dump).
- **Out of scope (deferred):** full project file-tree browser (P6b); syntax highlighting and word-level intra-line diff; side-by-side diff; ahead/behind counts; FSEvents file watching; any new third-party/SPM dependency (git is read via the system binary).

## Capabilities

### New Capabilities
- `git-review`: the read-only git-review panel — lists the focused local repo's changed files grouped by status category, shows a selected file's read-only unified diff, opens a file in the editor on ⌘-click, is toggleable and starts collapsed, refreshes leanly on command-finish + periodic backstop + focus + manual, and degrades to an empty state for remote/non-repo/git-unavailable sessions. View-free git status/diff parsing lives in `XttyCore`.

### Modified Capabilities
- `terminal-configuration`: add the `diff-context` config key (recognized schema key with a default; invalid value falls back to the default). No new editor key — the opener reuses the existing `link-opener`.
- `verification-harness`: the DEBUG state dump SHALL expose a `gitReview` snapshot (repo/remote flags, changed-files paths+statuses, selected-diff summary, a refresh counter — never full diff text, read from a cached snapshot), with e2e scenarios for the changed-files listing, click→diff, and ⌘-click→editor.

## Impact

- **New code (App):** a SwiftUI git-review panel hosted beside the terminal area (a peer of `SessionSidebar.swift`), wired into `TerminalWindowController`'s layout (reworking the `terminalContainer` trailing constraint to add a right slot) and the View menu; an App-layer `GitRunner` side effect that execs the system `git` (reusing `FileOpener`'s login-shell-PATH + literal-argv pattern, with stdout capture).
- **New code (XttyCore, view-free):** git status (porcelain) + diff parsers producing typed, unit-testable value snapshots; an observable git-status store driven off the existing main-actor OSC 133 hook.
- **Reuses (no change):** P4a `liveLocalDirectory` (cwd + remote guard), P4b-1 `LinkRouter`/`FileOpener` (⌘-click→editor), the `@Observable` revision + provider-closure pattern from the session sidebar, the OSC 133 `commandEnd` mark.
- **Dependencies:** none added — git is the system binary; no libgit2/SPM dependency.
- **Config:** `~/.config/xtty/config` gains `diff-context`.
- **Tests:** new `XttyCore` unit tests (status/diff parsers) + a new XCUITest suite driving a real injected zsh in a temp repo.
