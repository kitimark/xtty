## 1. XttyCore — tree model + layout state

- [ ] 1.1 Add `GitTreeNode` (`indirect enum`: `.directory(path:name:children:)` / `.file(GitChangedFile)`, `Identifiable` with a stable `id` — `d:`+cumulative-path / `f:`+file-path — `Equatable`, `Sendable`) and `enum GitFileTree { static func build(_:) -> [GitTreeNode] }` in a new `XttyCore/Sources/XttyCore/GitFileTree.swift`. `build` splits each `GitChangedFile.path` on `/`, folds components into nested directory nodes, hangs the file as a leaf; ordering = directories first then files, each alphabetical (design D1/D3).
- [ ] 1.2 Add `public enum GitReviewLayout: String, Equatable, Sendable, CaseIterable { case flat, tree }` and, on `GitReviewStore`, `public private(set) var layout: GitReviewLayout = .flat` + `public func setLayout(_:)` that bumps `revision` (design D5). Keep `GitReviewSnapshot` unchanged (layout is UI state, not git data).
- [ ] 1.3 Unit tests (no app, no view) for `GitFileTree.build`: empty → empty; single root-level file; multiple files one directory; deeply nested paths; files + subdirs in the same directory (ordering: dirs before files, each alphabetical); two files sharing a directory prefix collapse under one node; the **same input set is preserved exactly** (no file added/dropped); a leaf carries its `GitChangedFile` (status + numstat intact). Plus a small `GitReviewStore.setLayout` test (flips layout, bumps revision).

## 2. XttyCore — git-review-layout config key

- [ ] 2.1 Recognize `git-review-layout` in the view-free config component (base-profile-only global key, like `confirm-close`): parse `flat`/`tree`, default `.flat`, invalid/absent → `.flat` + logged, non-fatal (design D6). Surface it on the resolved configuration (a `gitReviewLayout: GitReviewLayout` on the base/global config).
- [ ] 2.2 Unit tests: `git-review-layout = tree` resolves to `.tree`; absent → `.flat`; an invalid value (e.g. `git-review-layout = grid`) → `.flat` and is logged; case-insensitive key match consistent with the other keys.

## 3. App — render the tree layout + header toggle

- [ ] 3.1 In `App/GitReviewView.swift`, branch `fileListAndDiff` on `store.layout`: `.flat` → the existing `GitStatusCategory` sections (unchanged); `.tree` → a single `OutlineGroup`/`DisclosureGroup` over `GitFileTree.build(snap.files)` inside the same `List`, leaves rendered with the **existing `GitFileRow`** wrapped in the same selection `Button { onSelect } .listRowBackground(selected) .contextMenu { onOpen }` as the flat rows (design D2/D4). Default-expanded.
- [ ] 3.2 Add a 2-state layout toggle to `headerBar` (next to refresh; e.g. `list.bullet` ↔ `list.bullet.indent`) bound to `store.layout` via `setLayout` (design D7). No keybinding, no View-menu item.
- [ ] 3.3 Seed the default once when wiring the panel: the window/`GitReviewController` calls `store.setLayout(config.gitReviewLayout)` at setup so the configured default applies before first render (design D6). Confirm the tree branch consumes only the cached snapshot — **no** new `GitRunner`/`git` call.

## 4. Harness — dump field + e2e

- [ ] 4.1 Add `layout` (`"flat"`/`"tree"`) to the `gitReview` DEBUG state-dump (read from `store.layout`; cached, no git exec) in `App/TerminalWindowController.swift` `gitReviewDump`.
- [ ] 4.2 Add an XCUITest scenario (`AppUITests/XttyGitReviewUITests.swift`): launch with config `git-review-layout = tree`, drive the injected zsh to create a repo with changed files, show the panel, and assert the dump's `gitReview.layout == "tree"`; degrade to screenshot when capture/hook is absent (Release).

## 5. Validation + docs

- [ ] 5.1 `swift test --package-path XttyCore` green (new `GitFileTree` + config + store tests); `xcodebuild test -project xtty.xcodeproj -scheme xtty -destination 'platform=macOS' -only-testing:xttyUITests/XttyGitReviewUITests` green.
- [ ] 5.2 `openspec validate add-git-review-tree` clean.
- [ ] 5.3 Add `git-review-layout` to `config.example` with a one-line comment. On completion, reconcile the trackers (AGENTS Current status + Next, milestone P6b state, `research/03-analysis/p6-file-diff-decisions.md` P6b addendum from "decided/not-yet-a-change" → "implemented") per the repo convention.

## 6. Deferred (out of scope — do NOT build here)

- [ ] 6.1 *(note only)* Compact single-child folder chains (VS Code "compact folders"), per-directory rollup +/- badges, a layout keybinding/View-menu item, and the full project file-tree browser (Scope B — rejected) stay deferred; record nothing beyond this note.
