## 1. XttyCore — view-free git model + parsers

- [ ] 1.1 Add `GitFileStatus` + `GitStatusCategory` (Changes / Untracked / Conflicts) and a `GitChangedFile` value (repo-root-relative path, status, optional +/- counts) — toolkit-independent, `Sendable`.
- [ ] 1.2 Implement `GitStatusParser`: parse `git status --porcelain=v1 -z --untracked-files=all --no-renames` (NUL records, raw UTF-8 paths) → `[GitChangedFile]`; classify the 7 unmerged XY combos → Conflicts; skip trailing-slash dir entries; sort+dedup by path.
- [ ] 1.3 Implement `DiffParser`: parse `git diff` (unified) → `Patch { header, hunks:[Hunk{oldStart,newStart,context,lines:[DiffLine{kind,content}]}] }`; classify lines (context/add/del/hunkHeader/noNewline) by leading char + `@@` regex; detect binary ("Binary files … differ"); apply a per-line char cap + a per-file line cap (truncated flag).
- [ ] 1.4 Parse `--numstat -z` into per-file added/removed (binary → `-\t-`) for badges.
- [ ] 1.5 Unit tests: status fixtures (modified/added/deleted/untracked/binary/conflict/dup), diff fixtures (multi-hunk, binary, truncation caps), numstat — all without launching the app or a terminal view.

## 2. XttyCore — observable git-status store

- [ ] 2.1 Add an `@Observable GitStatusStore` keyed by repo toplevel, holding the cached snapshot (repo/remote flags, repoRoot, branch, `[GitChangedFile]`, selected file's parsed diff + summary, a refresh counter); a `revision` for SwiftUI; a `noteRefresh()` entry point.
- [ ] 2.2 Define the request/result seam (a value describing a refresh request: toplevel, diff-context, optional selected path) so the App-layer runner stays out of `XttyCore`.
- [ ] 2.3 Unit tests for snapshot/selection state transitions (no app).

## 3. App — GitRunner (Process side effect)

- [ ] 3.1 Implement `GitRunner` reusing `FileOpener`'s login-shell `command -v git` PATH resolution (cached) + literal-argv rule, but **capturing stdout** (a `run`-with-output variant); set `GIT_OPTIONAL_LOCKS=0`; all diffs `--no-ext-diff --no-color`.
- [ ] 3.2 Implement the invocations: `rev-parse --show-toplevel` (discovery), `status … porcelain=v1 -z`, `symbolic-ref --short HEAD` (branch; detached → short SHA), `diff --numstat -z`, `diff [--unified=N] -- <path>` + `diff --no-index -- /dev/null <path>` (untracked; **exit 1 == success**). Run off the main actor; publish results to the store on main.
- [ ] 3.3 Gate every run on focused `liveLocalDirectory != nil` and resolve the repo toplevel; map "not a repo" / "git not found" / remote to the corresponding empty-state snapshot.

## 4. App — git-review panel + layout + toggle

- [ ] 4.1 Build `GitReviewView` (SwiftUI peer of `SessionSidebarView`): status-category groups (hide-when-empty), per-file glyph+color (deleted muted), +/- badges, branch header; selecting a file shows its read-only unified diff (one styled row per `DiffLine`, `List`/`LazyVStack` virtualization); "diff too large → open in editor" + "binary file" fallbacks; empty states (non-repo / remote / git-not-found).
- [ ] 4.2 Rework `TerminalWindowController.buildLayout()` to add a trailing `gitPanelHost` `NSHostingView` with its own width constraint (repoint `terminalContainer.trailingAnchor` → host leading); add `toggleGitPanel()` (clone of `toggleSidebar()`), **default-collapsed**; provider closure + store revision wiring (per-window, focused-pane-driven).
- [ ] 4.3 Add the View-menu "Toggle Git Review" item with a default **⌃⌘G** key equivalent (mirror Toggle Sidebar in `MainMenu.swift`).
- [ ] 4.4 Wire ⌘-click (and the open gesture) on a changed file / diff line → existing `LinkRouter`/`FileOpener`, resolved against the repo (reuse `link-opener`; no new editor key).

## 5. App — lean refresh wiring

- [ ] 5.1 In `PaneController`'s OSC-133 handler, branch `if case .commandEnd = mark` → notify the `GitStatusStore` (separate from `noteActivityChange()`); inject the store into `PaneController` like `registry`.
- [ ] 5.2 Add the ~5 s periodic poll backstop (while visible), focus-change refresh (via `setActivePane`/`focusPane` + window becomeKey), panel-open refresh, and a manual-refresh affordance.
- [ ] 5.3 Add debounce (~200 ms), min-spacing (~5 s) + serialize (one in-flight + one pending), visible/local/idle gating, dedup by toplevel, and pause-during-the-user's-own-foreground-git.

## 6. Configuration — diff-context

- [ ] 6.1 Recognize `diff-context` in the config schema (`XttyConfig`/`XttyConfigLoader`): non-negative int, default 3, fail-soft fallback + log on invalid; thread it into the diff invocation (`--unified=N`).
- [ ] 6.2 Unit test: `diff-context` parsed, defaulted when absent, fell back when invalid (no app).
- [ ] 6.3 Document `diff-context` in `config.example`.

## 7. Verification harness

- [ ] 7.1 Add the cached `gitReview` field to `writeStateDump()` (repo/remote flags, repoRoot, branch, changedFiles[path,status,added,removed], selectedDiff summary, refreshCount) — read from the store snapshot only, **never** exec git in the dump path, never full diff text.
- [ ] 7.2 Add the `XTTY_TEST_GIT_SELECT` env-file trigger (mirror `routePendingTestLink`/`routePendingTestSpatialOp`) to drive click→diff selection; reuse `XTTY_TEST_LINK_PATH` + `lastLinkOpen` for ⌘-click→editor.
- [ ] 7.3 New XCUITest suite (`XttyGitReviewUITests`): drive a real injected zsh in a temp repo (`git init`; commit; modify + add untracked) → assert `gitReview.changedFiles` + categories; trigger select → assert `selectedDiff` summary; trigger open → assert `lastLinkOpen`; assert non-repo + remote empty-state flags. Degrade to screenshots when the hook is absent.

## 8. Spikes (settle during build — see design Open Questions)

- [ ] 8.1 Confirm the XCUITest runner can `Process`-exec `git` into a HOME-relative temp repo (else drive setup via the live shell).
- [ ] 8.2 Confirm login-shell `command -v git` resolves with CLT-only installs.
- [ ] 8.3 Sanity-check large-repo `git status` latency + the 200 ms / 5 s / 5 s windows; confirm off-main is sufficient.

## 9. Wrap-up

- [ ] 9.1 `openspec validate add-git-review` clean; full `XttyCore` unit suite + the app XCUITests green (`make test-core` / `make test`).
- [ ] 9.2 Update trackers (AGENTS.md Current status, milestone P6 state) per "Keep progress current" when implementation lands.
- [ ] 9.3 (Deferred, not in this change) note the P6a+ / P6b follow-ups (word-level diff, syntax highlighting, FSEvents, file tree, staging) remain captured in the decisions doc.
