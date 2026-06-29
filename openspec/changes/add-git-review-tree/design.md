# Design — add-git-review-tree (P6b, Scope A)

The full rationale (Scope A vs Scope B, why-not-a-project-browser, the model-honesty note) lives in `research/03-analysis/p6-file-diff-decisions.md` → "P6b addendum". This file records the *how* for the implementation.

## Context

P6a/P6a+ shipped a read-only git-review panel: `GitReviewController` (per window) runs `git` off-main via `GitRunner`, publishes a `GitReviewSnapshot` into an `@Observable GitReviewStore`, and `GitReviewView` renders the snapshot — a flat `List` of `GitStatusCategory` sections (`snapshot.files(in:)`), each row a `GitFileRow`, with a `DiffPane` below. This change adds a second **presentation** of the same `snapshot.files` (`[GitChangedFile]`): a collapsible directory tree. No new git data, no new git/filesystem call.

## Decisions

### D1 — The tree is a pure view-free transform; no model reshape
A directory tree is a pure function over the existing flat `[GitChangedFile]`. Add a view-free, unit-tested `XttyCore` helper:

```swift
public indirect enum GitTreeNode: Identifiable, Equatable, Sendable {
    case directory(path: String, name: String, children: [GitTreeNode])
    case file(GitChangedFile)
    public var id: String { switch self { case .directory(let p, _, _): return "d:" + p
                                           case .file(let f): return "f:" + f.path } }
}
public enum GitFileTree { public static func build(_ files: [GitChangedFile]) -> [GitTreeNode] }
```

`build` splits each file's repo-root-relative `path` on `/`, folds the components into nested `directory` nodes, and hangs the `GitChangedFile` as a `file` leaf. Directory `path` is the cumulative prefix (e.g. `App/sub`) — a **stable id across refreshes** so SwiftUI preserves expansion. **Note (model honesty):** the P6a doc once spoke of a `GitListEntry` enum kept "forward-compatible"; it was never built and is not needed — `GitChangedFile` stays a flat struct and this transform sits beside it.

### D2 — Tree mode is one unified directory tree (drops the category sections)
Flat mode keeps the three `GitStatusCategory` sections unchanged. Tree mode shows a **single** directory tree of *all* changed files (a directory commonly holds both a modified and an untracked file, so per-category trees would fragment it — zed's tree mode is also unified). Category is still legible per file via the existing `GitFileRow` **status glyph + color** (conflicts/untracked stay distinguishable). Leaves reuse `GitFileRow` verbatim → identical glyph, numstat badges, selection highlight.

### D3 — Node ordering: directories first, then files, each alphabetical
IDE convention and stable/deterministic (also makes `GitFileTree.build` output trivially assertable). Sorting is inside `build` (pure), so the view does none.

### D4 — Rendering: SwiftUI `DisclosureGroup`/`OutlineGroup`, default-expanded
Render the `[GitTreeNode]` with `OutlineGroup`(children:) inside the existing `List` (tree mode replaces the `ForEach`-over-categories branch). Default **all-expanded** so tree mode starts with the same full visibility as the flat list. Expansion is user-collapsible; the stable `GitTreeNode.id` (D1) lets SwiftUI keep expansion across snapshot refreshes that return the same dirs. Leaves are `GitFileRow` wrapped in the same selection `Button { onSelect } .contextMenu { onOpen }` the flat rows use → **selection + ⌘-click-open work identically** (spec scenario), zero new routing.

### D5 — Layout state lives on `GitReviewStore`, not in the snapshot
`GitReviewSnapshot` stays the pure, `Sendable`, off-main-computed **git-data** value. The layout is UI state, so add it to the `@MainActor @Observable GitReviewStore`:

```swift
public enum GitReviewLayout: String, Equatable, Sendable, CaseIterable { case flat, tree }
// in GitReviewStore:
public private(set) var layout: GitReviewLayout = .flat
public func setLayout(_ l: GitReviewLayout)   // bumps `revision`
```

`GitReviewView` reads `store.layout` to pick the branch; a header control calls `setLayout`. Per-window, **not persisted** back to config (mirrors live font-size — a live change, default seeded from config).

### D6 — `git-review-layout` config key seeds the default (global, base-only)
Add a recognized global key `git-review-layout = flat | tree` (default `flat`), parsed in the view-free config component like `confirm-close`/`default-profile` (base-profile-only — it is a global UI preference, not a per-pane behavior; contrast `diff-context`, which legitimately varies per profile because it shapes the git query). Invalid/absent → `flat`, logged, non-fatal. The window seeds `store.setLayout(config.gitReviewLayout)` once when wiring the controller. Document it in `config.example`.

### D7 — Header toggle UI
A small control in `GitReviewView.headerBar` next to the refresh button — a 2-state segmented/icon toggle (e.g. `list.bullet` ↔ `list.bullet.indent`) bound to `store.layout`. Flips live. No keybinding, no View-menu item (deliberately minimal — same reasoning that kept next/prev-hunk nav out of P6a+).

### D8 — Harness: a `layout` field on the `gitReview` dump
The custom chrome exposes nothing to AX, so add `layout` (`"flat"`/`"tree"`) to the `gitReview` state-dump (read from `store.layout` — cached, no git exec, consistent with the rest of the dump). The e2e launches with `git-review-layout = tree` and asserts the dump reports `tree`. **Tree-structure correctness is unit-tested in `XttyCore`** (`GitFileTree.build`), not e2e — the view transform needs no app to verify. This keeps the harness surface to one field + one scenario.

## Risks / tradeoffs

- **Small changesets look the same or slightly worse as a tree** → that's why `flat` stays the default; tree is opt-in for the big-refactor case it's designed for.
- **`OutlineGroup` expansion reset on refresh** → mitigated by the stable `GitTreeNode.id` (D1); if SwiftUI still resets, fall back to an explicit `@State expanded: Set<String>` keyed by directory path. Low risk, contained to the view.
- **Scope creep toward Scope B** → guarded by the spec ("no additional files, no unchanged files") and by adding **no** new git/FS call; the tree can only ever show what `git status` already returned.

## Migration / compatibility

Default `flat` == today's behavior exactly; a config without `git-review-layout` and a user who never touches the toggle see no change. Pure addition — no data migration, no new dependency, read-only scope preserved.

## Open questions

- ❓ Compact single-child folder chains (VS Code "compact folders", `app/sub` as one row) — a readability nicety; **deferred** (note in `tasks.md`, not built).
- ❓ Per-directory rollup badges (aggregate +/-) — **deferred**; directory rows show name only in v1.
