## Why

P6a's git-review panel lists changed files in three flat status-category sections (Changes / Untracked / Conflicts). That is ideal for a small pre-commit diff, but it is exactly the wrong shape for the panel's signature case: when an agent CLI (Claude Code) does a **large refactor touching many files across many directories**, the flat list becomes a long, structureless scroll. The P6b scope decision (`research/03-analysis/p6-file-diff-decisions.md` → "P6b addendum") narrows the long-deferred "file-tree browser" to **Scope A** — a flat↔tree toggle over the *changed* files, a pure presentation transform — and **rejects Scope B** (a full project file-tree browser) as off-mission IDE-creep (the shell + ⌘-click-any-path already cover browsing; Phase 6's non-goal is "not a full IDE"). This change ships Scope A.

## What Changes

- **Directory-tree layout for the changed-files list.** The panel can present the focused repository's changed files either as today's status-category grouping (flat, the default) or as a **collapsible directory tree** of the *same* changed files, organized by repository-root-relative directory path. The tree is **presentation only** — the same change set, the same per-file status glyph + numstat badges, the same selection/⌘-click-to-open behavior, the same read-only nature; **no file beyond those `git status` already reports is surfaced** (this is not a project browser).
- **Toggle + configurable default.** A control in the panel header flips between flat and tree live (per-window, not persisted — like live font-size). A new global `git-review-layout = flat | tree` config key sets the default (defaulting to `flat`, i.e. unchanged behavior).
- **View-free tree model.** A new view-free, unit-tested `XttyCore` helper folds the flat `[GitChangedFile]` into nested directory nodes (no new git invocation, no filesystem walk, no `GitRunner` change, no FSEvents).
- **Harness.** The `gitReview` DEBUG state-dump gains the active list **layout** (flat vs tree) so an e2e can assert the config-driven default; tree correctness is covered by `XttyCore` unit tests.
- **Out of scope (kept deferred):** the full project file-tree browser (Scope B — rejected), browsing unchanged files, compact single-child folder chains, per-directory rollup badges, FSEvents, syntax highlighting, staging/commit. No new keybinding.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `git-review`: the panel's changed-files list MAY be presented either as the default status-category grouping or as a **collapsible directory tree** of the same changed files, with the user able to switch between them and a configurable default; the tree is presentation only (same change set, same per-file status, same read-only scope, no additional files surfaced) — selection and open-in-editor behave identically in either layout.
- `terminal-configuration`: adds a global `git-review-layout` key (`flat` | `tree`, default `flat`) selecting the git-review panel's default list layout, with the usual unknown-key/invalid-value fallback.
- `verification-harness`: the `gitReview` state-dump snapshot additionally exposes the active list layout (flat vs tree); git-review e2e coverage gains a layout scenario.

## Impact

- **`XttyCore`** (view-free, unit-tested): a new `GitFileTree` builder + `GitTreeNode` value type folding `[GitChangedFile]` → nested directory nodes; a `GitReviewLayout` enum (`flat`/`tree`) and a `layout` property on the existing `@Observable GitReviewStore` (UI state, kept **out of** the pure `GitReviewSnapshot` git-data value); a `git-review-layout` key on the resolved configuration. No new dependency.
- **App layer:** `GitReviewView.swift` renders either the existing category sections or a SwiftUI disclosure/outline directory tree (leaves reuse `GitFileRow`; same `onSelect`/`onOpen`), plus a header toggle; `GitReviewController`/window seed `store.layout` from the config default; the `gitReview` dump gains the layout field.
- **Refresh / git access:** unchanged — the tree consumes the same cached snapshot; no extra `git` calls, no filesystem watch.
- **Read-only and lean preserved:** no write operations, no new deps, no new git/FS work; a pure in-memory transform over data the panel already holds.
