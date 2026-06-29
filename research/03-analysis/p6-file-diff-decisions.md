# P6 File/Diff View — Engineering Decisions

> **Provenance.** Authored 2026-06-29. Two-pass research: pass-1 (web + xtty-codebase grounded) produced the decision skeleton; pass-2 deep-read the *actual source* of comparable OSS (zed, vscode, lazygit, gitui, delta, waveterm; clones inspected file-by-file) to confirm / correct / enrich it. xtty citations are `repo-relative:line` and were re-verified against `main` (commit `902f41a`). Borrowed-pattern citations name the tool + its in-repo path.
> **Confidence legend:** ✅ confirmed by real source · ❌ corrected by real source · ❓ open / spike.

## Headline decision

Ship **P6a: a read-only git-review panel** as P6 v1 — a **changed-files list grouped by status category** (Changes / Untracked / Conflicts) with **click-to-diff**, rendered as a **unified diff in plain SwiftUI** (red/green line backgrounds, no syntax highlighting), hosted in a **new collapsible trailing-edge (right) panel**, **default-collapsed** behind a toggle (⌃⌘G). Git data comes from **shelling out to the `git` binary** (reusing `FileOpener`'s login-shell-PATH + literal-argv pattern — zero new deps, no libgit2), parsed by a **pure view-free `XttyCore` module**.

Two source-grounded changes from pass-1 shape the build: (1) use **porcelain v1 `-z`** (`git status --porcelain=v1 -z --untracked-files=all --no-renames`), *not* v2 `--branch` — every mature tool uses v1; branch/ahead-behind are separate commands; and (2) the panel refreshes on a **`.commandEnd`-gated, debounced** OSC-133 fast-path **plus a gated ~5 s poll backstop** (not OSC-133 alone) so a long-running agent editing files *mid-command* isn't invisible — the agent-host gap both git TUIs solve with exactly this poll. FSEvents stays **deferred** (the two TUI analogs poll, not watch). Both are gated on panel-visible AND focused-session `liveLocalDirectory != nil` AND idle. Defer the **full file-tree browser (P6b)** and **staging/commit (indefinitely — pair with lazygit)**, but keep the data model forward-compatible with a later stage toggle.

## Source-grounded changes vs pass-1

**Confirmed by reading real source (no change):**
- ✅ Shell out to `git`, not libgit2 — lazygit, VS Code, zed all spawn the CLI (`git/repository.rs`, `extensions/git/src/git.ts`); gitui is the lone libgit2 user but needs a linked lib (no SPM path in Swift). Stands.
- ✅ Plain unified diff, no syntax model — lazygit (`patch/patch_line.go:5-19`) and gitui (`asyncgit/src/sync/diff.rs:53-121`) ship *exactly* the minimal tagged-line model pass-1 proposed.
- ✅ Lazy/virtualized rendering, large-diff caps, per-file lazy diff — gitui viewport-only `get_text` (`src/components/diff.rs:331-392`); delta line caps.
- ✅ Both parser self-corrections: rename byte order (target-first) and `--no-index` exit-1-as-success — confirmed empirically *and* in lazygit (`working_tree.go:386-424`).
- ✅ No lean terminal ships a git-review panel — waveterm's only diff surfaces are a Monaco generic viewer and an AI-tool-call diff, neither reads `git status`/`git diff`. xtty's panel is a genuine differentiator.
- ✅ Refresh should be debounced + visibility-gated — VS Code's literal pipeline confirms (`@debounce(1000)` → wait-for-focus → wait-for-idle → status).

**Corrected by real source (changed the call):**
- ❌ **MATERIAL — porcelain v2 + `--branch` → porcelain v1 `-z`, branch fetched separately.** No mature tool uses v2 for the file list (VS Code `git status -z`, lazygit `--porcelain`, zed `--porcelain=v1 --no-renames`), and none folds `--branch` into it (branch/upstream/ahead-behind come from `symbolic-ref` / `for-each-ref` / `rev-list --left-right --count`). The v2-rename-order fix stays true but is **moot under v1 + `--no-renames`**.
- ❌ **MATERIAL — OSC-133-D alone is weaker than every tool studied; add a gated poll backstop.** D only fires *after* a command completes, so an agent editing mid-command is invisible for the whole run — undercutting the agent-host value. Both TUIs solve this with a cheap low-frequency poll (lazygit 10 s files / 2 s refs-snapshot; gitui 5 s). Add a 5 s poll backstop to v1; keep FSEvents deferred.
- ❌ **MATERIAL — group by status *category*, not staged/unstaged.** VS Code has 4 groups (merge/index/workingTree/untracked); zed has 3 sections (Conflicts/Tracked/Untracked). A staged/unstaged frame only makes sense once staging exists. P6a groups **Changes / Untracked / Conflicts** (hide-when-empty).
- ❌ **MATERIAL — read-only is a deliberate narrowing, not the norm.** *Every* comparable tool (incl. the user's habit, zed) is read-WRITE. Keep read-only for leanness, but keep the file/status data model forward-compatible with a later stage toggle.
- ❌ **MINOR — word-level intra-line diff is a separable, cheap-if-gated cost**, not lumped with syntax highlighting. delta/zed both ship it behind hard gates. Keep it deferred, but as an *optional gated overlay* on the unchanged line model, not a blanket "skip for cost."
- ❌ **MINOR — left-edge is the IDE norm; right-edge is xtty's own choice** (left is taken by the session sidebar). Don't cite zed/vscode as precedent for right placement.
- ❌ **MINOR — debounce floor.** Pass-1's ~200 ms is right to coalesce a D-burst, but borrow VS Code's **~5 s minimum spacing between actual `git status` spawns** + serialize (single in-flight + one pending) so the D fast-path and the poll never stack.

**Added by real source (new, borrow-worthy):**
- `GIT_OPTIONAL_LOCKS=0` env (VS Code) / `--no-optional-locks` (lazygit) on every read — zero-side-effect reader, never races `.git/index.lock`.
- `--no-ext-diff --no-color` on every parsed diff so user `diff.external`/pager/color config can't corrupt output; `-z` auto-disables `core.quotepath` (raw UTF-8, no octal escapes).
- `--numstat -z` for cheap per-file +/- badges without parsing the diff (binary → `-\t-`).
- `--untracked-files=all`; skip trailing-slash dir entries; sort+dedup parsed entries by path (git can emit duplicates); explicit unmerged-XY handling (DD/AU/UD/UA/DU/AA/UU → Conflicts).
- Deleted files rendered **muted, not red** (zed: "so we don't get a bunch of red labels").
- `diff-context` config key (lazygit threads `--unified=%d`).
- Read-only **next/prev-hunk keyboard nav** (zed's GoToHunk idea, minus editing/staging).

## Decisions table

| Open question | Decision | Confidence | Key evidence |
|---|---|---|---|
| **Layout / placement** | New **trailing-edge** collapsible panel (~260–300 pt own width), default-collapsed; left sidebar stays session-progress only | ✅ High | xtty `App/TerminalWindowController.swift:158` buildLayout, `:211-214` toggleSidebar, `:176` `terminalContainer.trailing` pinned to container (**rework, not copy-paste**). Right-edge is xtty's own (left taken); IDEs default LEFT — zed `git_panel.rs:7350-7358` dock Left\|Right |
| **Git access** | **Shell out to `git`** (Process + login-shell PATH), **not** libgit2 | ✅ High | xtty `App/FileOpener.swift:60-76` Process+ShellResolver+literal-argv; `XttyCore/Package.swift:29` single dep; lazygit `git_commands/file_loader.go`, VS Code `git.ts`, zed `git/repository.rs` all CLI; gitui uses libgit2 but needs a linked lib (no SPM) |
| **Status invocation** | `git --no-optional-locks -C <top> status --porcelain=v1 -z --untracked-files=all --no-renames`; branch name via separate `symbolic-ref` | ✅ High (was ❌ v2/`--branch`) | VS Code `git.ts:2746`; lazygit `file_loader.go:180-181`; zed `git/repository.rs:3426-3429`; branch fetched separately VS Code `git.ts:3230-3234` |
| **Diff render** | **Unified**, plain monospaced SwiftUI rows, **no syntax highlighting** v1; pure Files→Hunks→Lines parser in `XttyCore`; `--no-ext-diff --no-color` | ✅ High | lazygit `patch/patch_line.go:5-19` + `patch/parse.go:10-85`; gitui `sync/diff.rs:53-121`; delta `handlers/hunk_header.rs:213`; xtty `SessionSidebar.swift` value-snapshot precedent |
| **Refresh model** | **`.commandEnd`-gated + ~200 ms debounce + ~5 s poll backstop + ~5 s min spacing**, serialized; visible+local+idle-gated; **FSEvents deferred** | ✅ High (poll backstop ❌ added) | OSC-133-D-only too weak (agent mid-command); lazygit `gui/background.go:131-139` (10 s) + `:161-224` (2 s refs-snapshot), gitui `main.rs:114,187-191` (5 s) both poll; VS Code `repository.ts:3169-3218` debounce pipeline; xtty `App/PaneController.swift:131,141` |
| **Grouping** | Status-category groups **Changes / Untracked / Conflicts** (hide-when-empty), flat list (no tree), per-file glyph+color, **deleted=muted** | ✅ High (was ❌ staged/unstaged) | VS Code `repository.ts:1006-1009` ("Changes"), `:3060-3066` unmerged map; zed `git_panel.rs:422-428` sections, `:6602-6620` color (deleted=muted) |
| **Scope / v1 boundary** | **P6a git-review (lead)**, read-only; defer **P6b file tree**; defer staging indefinitely (forward-compatible model) | ✅ High | H2 "lightweight, not a full IDE"; all comparables are read-WRITE → read-only is a deliberate bet; zed `git_panel_settings.rs:30-37` tree-toggle = the P6b increment |
| **Edge cases** | Rename(via add/del)/delete/untracked/binary/conflict/dedup/dir-skip from porcelain; cap huge diffs → "open in editor"; numstat badges; empty states | ✅ High | zed `git/status.rs:451-487` dir-skip+dedup; lazygit `working_tree.go:401` untracked `--no-index`; gitui `diff.rs:394-424` binary summary; delta `delta.rs:221-234` 3000-char cap |
| **Harness** | **State-dump-first** (`gitReview` field, cached snapshot), env-file trigger `XTTY_TEST_GIT_SELECT`; reuse `XTTY_TEST_LINK_PATH`+`lastLinkOpen` for ⌘-click→editor | ✅ High | xtty `App/XttyApp.swift:101-105,118,129`; `App/TerminalWindowController.swift:517,557` writeStateDump (0.15 s timer → must read cache) |

---

## Decision detail

### 1. Layout — trailing-edge collapsible panel

Place the git panel on the **right**, leaving the left edge uncontested for the #1 feature (the session-progress sidebar). Real source shows IDEs default their SCM surface **left** (zed `crates/git_ui/src/git_panel.rs:7350-7358`, dock Left|Right; VS Code is a left activity-bar viewlet) — so the right-edge placement is **xtty's own** choice (left is occupied), not a mirror of those tools; don't cite them as precedent.

Reuse — but do **not** blind-copy — the proven sidebar mechanism (`App/TerminalWindowController.swift`): an `NSHostingView` pinned with its own width constraint, a `toggleGitPanel()` clone of `toggleSidebar()` (`:211-214`), wired to a View-menu item + ⌃⌘G. **Correction (verified):** `buildLayout()` pins `terminalContainer.trailingAnchor` to the *container's* trailing (`:176`), so a right slot means **repointing that constraint** to the new host's leading anchor — a constraint rework, not a symmetric paste.

**Why default-collapsed:** the default window is 900×560; left 220 + terminal + right 260 leaves ~420 pt of terminal on the built-in display. Default-collapsed + own width + on-demand hotkey protects LEAN/native-feel for free given the constraint mechanism. The panel is **per-window, focused-pane-driven** via the same provider-closure + `@Observable` revision contract the sidebar uses, reading the focused session's `liveLocalDirectory` (`XttyCore/.../TerminalSession.swift:92-93`); `nil` (remote/ssh) → empty state for free.

> ❓ Optional spike: native SwiftUI `.inspector` (deployment target macOS 14) would be leaner than the hand-rolled mirror. Pick during implementation; the AppKit mirror is acceptable for `buildLayout` consistency.

### 2. Git access — shell out, not libgit2

Shelling out carries **zero new dependencies** (serving M1 LEAN), reuses the verified `App/FileOpener.swift` Process + `ShellResolver` login-shell-PATH + literal-argv pattern (`:60-76`), and is what every comparable CLI tool does (lazygit `pkg/commands/git_commands/file_loader.go`, VS Code `extensions/git/src/git.ts`, zed `crates/git/src/repository.rs`). gitui is the lone libgit2 user (`asyncgit/src/sync/diff.rs:38-45`) but that needs a *linked* lib — and Swift's SwiftGit2 has no SPM support (it vendors libgit2 as a submodule, Carthage + Xcode-project build), confirming the libgit2 path is heavy. The dep edit pass-1 feared would land in `XttyCore/Package.swift:29` (today a single `.package(path: ../external/SwiftTerm)`) — and we avoid it.

**Canonical invocations** (git resolved to an absolute path via cached login-shell `command -v git`; every path a literal argv element after `--`; `GIT_OPTIONAL_LOCKS=0` env on all reads):

1. **Discovery:** `git -C <cwd> rev-parse --show-toplevel` (empty/nonzero → not a repo → empty state).
2. **Status:** `git --no-optional-locks -C <top> status --porcelain=v1 -z --untracked-files=all --no-renames`.
3. **Branch (separate, optional):** `git -C <top> symbolic-ref --short HEAD` (detached → fall back to short SHA). Ahead/behind via `rev-list --left-right --count <branch>...<upstream>` is **deferred to P6a+** (not needed for the changed-files list).
4. **Counts:** `git --no-optional-locks -C <top> diff --numstat -z [-- <path>]` → `added\tdeleted\tpath` (binary → `-\t-`) for cheap +/- badges.
5. **Diff (lazy, per file on selection):** tracked → `git -C <top> diff --no-ext-diff --no-color [--unified=N] -- <path>`; untracked → `git -C <top> diff --no-ext-diff --no-color --no-index -- /dev/null <path>` (**exit 1 == success**).

**Why v1 not v2 (source-grounded ❌ correction):** No mature tool uses porcelain v2 for the file list — VS Code `git status -z` (v1 default, `git.ts:2746`), lazygit `--porcelain` (v1, `file_loader.go:180-181`), zed `--porcelain=v1 --no-renames` (`repository.rs:3426-3429`). v1 is a fixed `XY␠<path>` per `-z` record (+ an optional next NUL-element only for renames, which `--no-renames` removes), simpler than v2's mode/oid/submodule columns — dead weight for a read-only panel. The two pass-1 self-corrections survive: the **rename byte order** fix is now moot under `--no-renames` (a rename surfaces as `D <old>` + `?? <new>`); the **`--no-index` exit-1-as-success** fix stands (lazygit `working_tree.go:422-424` discards the error and uses stdout).

**Parser gotchas (source-grounded):** `-z` auto-disables `core.quotepath` → paths are raw NUL-terminated UTF-8, never octal-escaped (no `-c core.quotepath=false` needed). **Skip trailing-slash entries** (untracked dirs; VS Code `git.ts:878`, zed `status.rs:451-453`). **Sort+dedup by path** — git can emit duplicate `?? file` lines and `D `+`??` pairs for delete-then-recreate (zed `status.rs:464-487`). **Map the 7 unmerged XY combos** (DD/AU/UD/UA/DU/AA/UU) to a Conflicts group *before* the per-side switch (VS Code `repository.ts:3060-3066`) — they won't diff cleanly against one ref.

**Seam split:** pure porcelain/numstat/diff parsing lives in a new view-free `XttyCore` module (`GitStatusParser`/`DiffParser`, unit-tested like `OSC133`/`LinkOpen`); the Process exec is an App-layer `GitRunner` side effect (like `FileOpener`), keeping `XttyCore` free of Process/AppKit. **Note:** `FileOpener.run()` (`:89-96`) does **not** capture stdout — only the *pattern* (Process + Pipe + login-shell PATH, as in the `command -v` resolver at `:66-76`) is reusable; `GitRunner` needs a stdout-capturing variant.

### 3. Diff rendering — unified, plain, in SwiftUI

A narrow panel makes side-by-side unusable, and unified is delta's own default. **No syntax highlighting in v1** is the literal "lightweight, not a full IDE" point and the only zero-dep choice (Splash=Swift-only, Highlightr ships a JavaScriptCore+highlight.js runtime, tree-sitter bundles grammar blobs — all fail LEAN).

**Minimal data model (the exact shape two shipping TUIs use — drop-in for SwiftUI):**

```
Patch { header: [String], hunks: [Hunk] }
Hunk  { oldStart: Int, newStart: Int, headerContext: String, lines: [DiffLine] }
DiffLine { kind: .context | .add | .del | .hunkHeader | .noNewline, content: String }  // keep leading +/-/space
```

Parse = split on `\n`; match `@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@(.*)` for hunk starts (lazygit's regex, `pkg/commands/patch/parse.go:10-85`), else classify by first char (lazygit `patch/patch_line.go:5-19`, gitui `asyncgit/src/sync/diff.rs:53-121`, delta `handlers/hunk.rs:255-272`). A pre-classified `DiffLine` array is exactly what a SwiftUI `List`/`LazyVStack` should render — one `Text` per line styled by `.kind`. Git already did the semantic work; nothing richer is needed for a read-only view (lazygit's *display* path doesn't even parse — it streams `git diff --color` ANSI; it only parses for staging. Our SwiftUI panel isn't an ANSI engine, so it parses, but the parse stays trivial).

**Render cheaply via virtualization + lazy-per-file.** SwiftUI `LazyVStack`/`List` virtualizes row construction for free (gitui hand-rolls the equivalent: viewport-only `get_text` materializes only `[scrollTop, scrollTop+height]` and skips off-screen hunks, `src/components/diff.rs:331-392` + `:480-499`). Keep **each file's diff an independent array, lazy-loaded on selection** (mirrors zed's per-path excerpt model, `crates/git_ui/src/project_diff.rs`), so an unopened 50k-line file is never parsed.

**Large-diff safety caps (concrete defaults from delta):** truncate any single line longer than **~3000 chars** with an ellipsis marker (delta `src/delta.rs:221-234`, `cli.rs:613`); per-file rendered-line cap → "diff too large — N lines, click to open in editor" guard (reuse `FileOpener`/`LinkRouter`); binary → "Binary file (no preview)" summary (gitui `diff.rs:394-424`), never attempt to render.

**Reject reusing a SwiftTerm view to render the diff** — a second VT engine/grid (memory vs M1), loses structure (no click-to-line, no granular refresh), violates the `XttyCore` no-view-import seam. The structured-value path gives click-to-open-line for free via existing `LinkRouter`/`FileOpener`.

**Word-level intra-line diff (❌ reframed, still deferred to P6a+):** it is a *separable, characterizable* cost — Wagner–Fischer/Needleman–Wunsch O(m·n) per minus/plus line-pair (delta `src/align.rs:18-115`, driven by `src/edits.rs:24-106`), **cheap enough to ship if gated**. Both mature tools gate hard rather than defer: zed only computes it when added==removed line count AND ≤5 lines (`crates/buffer_diff/src/buffer_diff.rs:20,1210-1214`); delta bounds it with a 32-line subhunk buffer (`handlers/hunk.rs:70-77`) + a distance-threshold pairing (default 0.6) + the 3000-char cap. For xtty it remains a clean **optional overlay** on the unchanged line model — defer to P6a+, but know it's a small, bounded add, not an open-ended one.

> Borrowed structure (optional even without word-diff): delta's **subhunk-boundary buffering** (`handlers/hunk.rs:61-132`) — buffer consecutive minus then plus lines, flush the group on a context line — is the clean way to render a removed block then an added block together. Useful for hunk grouping; not required for a pass-through line list.

### 4. Refresh model — `.commandEnd` fast-path + gated poll backstop

The OSC-133 hook is wired on a main-actor path (`App/PaneController.swift:131,141`), so "refresh when a command finishes" needs no new plumbing in principle. **Critical correction (carried from pass-1, confirmed):** do **not** drive git off `registry.revision` — it bumps on *every* OSC-133 mark (A/B/C/D), alt-screen flips (`:128`), and register/unregister/focus, with **no debounce in the repo**. Re-spawning git on that firehose is a LEAN violation.

**The source-grounded ❌ that resolves the "FSEvents-vs-command-boundary" challenge:** OSC-133-D *alone* is weaker than every tool studied — it fires only *after* a command completes, so a long-running agent (Claude Code) or external editor changing files **mid-command** is invisible for the command's whole duration, directly undercutting xtty's agent-host value. Both git TUIs — the true analogs — solve exactly this with a cheap low-frequency **poll backstop** (lazygit 10 s files / 2 s refs-snapshot, `pkg/gui/background.go:131-224`; gitui 5 s ticker default, `src/main.rs:114,187-191`), and **neither watches the filesystem by default** (lazygit's fsnotify is `// indirect`; gitui's `--watcher` is opt-in). **Final call (✅ High):** keep FSEvents **deferred** (TUI-consistent, lean, M1-friendly), and **add a ~5 s poll backstop to v1** alongside the D fast-path. `git status --porcelain` is inherently `.gitignore`-aware, so the poll never sees `node_modules` churn — far cheaper than a raw recursive watcher (gitui's unfiltered recursive watch leans entirely on a 2 s debounce to survive event storms, `src/watcher.rs:67-82`). This catches mid-command agent edits at a fraction of FSEvents' cost.

**The pipeline (proven values borrowed from VS Code `extensions/git/src/repository.ts:3169-3218`):**
- **Fast-path:** branch `if case .commandEnd = mark.action` in the handler (`PaneController.swift:131`; mark already in scope, `OSC133.swift:12` `commandEnd(exitCode:)`) → notify a dedicated `@Observable GitStatusStore` in `XttyCore` (separate from `noteActivityChange()`). `PaneController` needs the store injected, like it already holds `registry` (`:42`).
- **Backstop:** a ~5 s repeating timer, same gates, same funnel.
- **Debounce ~200 ms** (trailing) on the trigger so `&&`-chains/loops coalesce to one invocation. VS Code uses 1000 ms but on raw fs events (far noisier); 200 ms suits a meaningful command boundary.
- **~5 s minimum spacing** between actual `git status` spawns + **serialize** (single in-flight `Task` + one pending flag, dropping intermediate triggers — VS Code's `@throttle`, `decorators.ts:39-66`) so the D fast-path and the poll never stack subprocesses. Run git **off the main actor**, publish the snapshot back on main (the handler runs under `MainActor.assumeIsolated`).
- **Gate (all required before spawning git):** panel-visible AND focused-session `liveLocalDirectory != nil` AND idle (no in-flight git op). Zero work when collapsed or remote (VS Code's "wait for window focus + op-idle", `repository.ts:3203-3217`).
- **Pause during xtty's own foreground git** (lazygit `pauseRefreshesCount`, `background.go`) — suppress refresh while the user is running git in the terminal, to avoid self-triggering churn.
- **Fallbacks:** refresh on focus-change (single funnel `setActivePane`/`focusPane` + window becomeKey), on panel open/expand, and explicit **manual refresh** (the only thing that works over ssh).
- **Dedup:** two panes/tabs in the same worktree both fire D → `GitStatusStore` keys by repo toplevel to avoid double-spawning.

> ❓ If dogfooding later shows the 5 s poll is too slow during long agent sessions, the upgrade path is FSEvents scoped to worktree root with the VS Code ignore-set (drop `index.lock`, worktree `index.lock`, `.watchman-cookie`; `repository.ts:453-503`) — documented, not built.

### 5. Grouping & file list — status categories, flat, color-coded

**❌ correction:** group by **status category, not staged/unstaged** (a staged frame only exists once staging does). P6a renders up to three groups, **hide-when-empty** for Conflicts/Untracked, always-show Changes (VS Code's `hideWhenEmpty` model, `repository.ts:1006-1009,1044-1045`; zed sections `git_panel.rs:422-428`):
- **Changes** — tracked modified/deleted (VS Code literally titles the working-tree group "Changes").
- **Untracked** — `??` entries (from `--untracked-files=all`).
- **Conflicts** — the 7 unmerged XY combos.

**Flat list only** for P6a (no tree) — the simplest, leanest shape; a flat-vs-tree toggle is the natural P6b increment (zed `git_panel_settings.rs:30-37`). Model rows behind a single `GitListEntry` enum (`Status`/`Header`, later `Directory`) like zed (`git_panel.rs:432-437`) so the tree increment is additive.

**Per-file glyph + color** derived from the porcelain status (M/A/D/?/U), mapped onto xtty's theme. **Borrow zed's deliberate tweak: render deleted files muted, not red** (`git_panel.rs:6602-6620` — "so we don't get a bunch of red labels"). Conflict/added/modified get distinct theme colors. Show the numstat +/- badges per file.

**Read-only is a product bet, not the norm (❌):** every comparable tool — including the user's habit (zed `git_panel.rs:34-35` Stage/Unstage/Stash/Discard) — is full read-WRITE. Keep read-only for leanness, but make the `GitFile`/status value type **forward-compatible with a later per-file stage state** so a future toggle doesn't reshape the model.

### 6. Scope — P6a leads, P6b deferred

`git status` is already a scoped changed-files list, so "changed-files + click-to-diff" is simultaneously the scoped file view **and** the diff view — matching the literal H2 habit ("git diff before commit") and the agent-review framing, and confirmed differentiated (no lean terminal ships this; waveterm's only diffs are a Monaco generic viewer `frontend/app/view/codeeditor/diffviewer.tsx` and an AI-tool-call diff `aifilediff.tsx`, neither git). The **full file-tree browser** is the separable, more-IDE-ish half → **P6b**. Staging/commit/inline-edit is the IDE-creep gravity → **deferred indefinitely; pair with lazygit**, which the agent-host/native-zsh values endorse.

**Borrow in read-only form, not the IDE form:** zed's diff review is an *editable* multibuffer with per-hunk staging (`crates/git_ui/src/project_diff.rs:9-21`) — the "full IDE" line to avoid. Take only the **next/prev-hunk keyboard navigation** idea over the plain SwiftUI unified-diff view (no editing, no per-hunk staging).

### 7. Edge cases

| Case | v1 behavior |
|---|---|
| Remote/ssh (`liveLocalDirectory == nil`) | Empty state "Remote session — review unavailable" (free via existing guard) |
| Not a git repo | Empty state "Not a git repository" (`rev-parse` nonzero) |
| Deep inside repo | `rev-parse --show-toplevel`, repo-root-relative paths |
| Huge repo / status latency | git off-main + debounce + spacing + timeout; spinner, never block UI |
| Huge diff | Per-file line cap + 3000-char line truncation → "diff too large — open in editor" (`FileOpener` escape hatch) |
| Binary file | "Binary file (no preview)" (numstat `-\t-` / "Binary files differ") |
| Renamed | `--no-renames` → surfaces as `D <old>` + `?? <new>` (no two-path parse) |
| Deleted / untracked | Listed with glyph (deleted=muted); untracked diffed via `--no-index` (exit 1 = success) |
| Merge conflict (7 XY combos) | Conflicts group, conflict marker; **do not** build a merge tool |
| Untracked dir entry (`path/`) | Skipped (trailing slash) — `--untracked-files=all` lists the real files |
| Duplicate / delete-recreate entries | Sort+dedup by path |
| Detached HEAD | Branch header shows short SHA (`symbolic-ref` fails → fall back) |
| git not installed / not on PATH | Login-shell resolve like `FileOpener`; on failure empty state "git not found" + `NSLog` |

**Deferred:** bare repo (treat as not-a-repo), rebase/merge-in-progress banner, submodule inner-diff, ahead/behind counts, full file tree (P6b).

### 8. Harness — state-dump-first

Follow the DEBUG state-dump convention, **not** AX (the P5 sidebar is SwiftUI yet asserts via the JSON dump). The dump lets tests assert the git *model* (status codes, counts) rather than fragile rendered strings.

- **One compact `gitReview` dump field** on `writeStateDump()` (`App/TerminalWindowController.swift:517`, alongside `sessionActivity:554`/`lastLinkOpen:557`): `{ isRepo, isRemote, repoRoot, branch, changedFiles:[{path,status,added,removed}], selectedDiff:{path,added,removed,isBinary,truncated} }` — counts/paths/statuses only, **never full diff text**. **Critical:** `writeStateDump` fires on the 0.15 s repeating timer (`App/XttyApp.swift:129`), so `gitReview` MUST read a **cached** `GitStatusStore` snapshot — never trigger a git exec inside the dump path.
- **New env-file trigger** `XTTY_TEST_GIT_SELECT` mirroring `routePendingTestLink`/`routePendingTestSpatialOp` (`App/XttyApp.swift:101-105,118`) for click→diff selection.
- **⌘-click→editor needs no new surface** — reuse `XTTY_TEST_LINK_PATH` + `lastLinkOpen` verbatim (same `LinkRouter`/`FileOpener` path).
- **Refresh assertion:** add a git-refresh counter (+ last-status hash) to the dump so XCUITests can assert a D-driven refresh deterministically despite async git timing.
- **e2e setup:** drive the real injected zsh (`cd <HOME/xtty-gittest-UUID>; git init; commit; modify`), wait for `currentDirectory` in the dump, assert `gitReview.changedFiles`, trigger select → assert `selectedDiff`, trigger link → assert `lastLinkOpen`. Degrade to screenshot when capture/hooks inactive, like the sidebar/semantic suites.

---

## V1 scope

**IN (P6a):**
- Trailing-edge collapsible git-review panel (default-collapsed, ⌃⌘G + View menu item).
- Changed-files list from `git status --porcelain=v1 -z --untracked-files=all --no-renames`, grouped **Changes / Untracked / Conflicts** (hide-when-empty), per-file glyph+color (deleted=muted) + numstat +/- badges, branch name header.
- Click a file → read-only **unified** diff inline (plain red/green, `--no-ext-diff --no-color`, lazy-per-file).
- ⌘-click a file → open in editor at line (reuse `LinkRouter`/`FileOpener`); next/prev-hunk keyboard nav.
- Refresh: `.commandEnd` fast-path (debounced) + ~5 s gated poll backstop + focus + panel-open + manual; serialized, ~5 s min spacing, visible+local+idle-gated, pause-during-own-git.
- Large-diff/line caps (3000-char line truncation, per-file line cap → "open in editor"), binary summary, empty/degraded states (remote, non-repo, git-not-found).
- Pure `XttyCore` parser module(s) + App-layer `GitRunner`; cached `GitStatusStore`; `gitReview` dump field + e2e.
- `diff-context` config key (defaults to git's 3).

**OUT (v1):**
- Syntax highlighting; word-level intra-line diff (gated overlay, P6a+).
- Side-by-side diff; ahead/behind counts.
- Staging / unstaging / commit / discard / any write op.
- Full project file-tree browser.
- FSEvents file watcher.
- libgit2 / any new SPM dependency.
- Inline comments-to-agent; merge/rebase tooling.

**Deferred increments:**
- **P6b** — full file-tree browser (lazy-load, expand/collapse, flat-vs-tree toggle). **Scope narrowed; see the "P6b addendum" below** — P6b is the *flat↔tree toggle over the changed-files list* (Scope A); the *full project* file-tree browser (Scope B) is rejected as off-mission IDE-creep.
- **P6a+** — gated word-level diff overlay (zed/delta gates) — **now decided as token-level emphasis; see the "P6a+ addendum" below** (`add-git-review-polish`) — and syntax highlighting (forces the tree-sitter-vs-Highlightr dep choice); ahead/behind via `rev-list --count`.
- **P6a+** — FSEvents auto-refresh (only if the 5 s poll proves too slow mid-agent-session; scoped to worktree root + VS Code ignore-set).
- **Indefinite** — staging/commit (pair with lazygit; model kept forward-compatible).

---

## ASCII mockup (panel expanded)

```
+--------+-----------------------------+-------------------------+
| Tab A  | user@host ~/proj %          | Changes        main     |
|  shell | $ claude edit ...           |  M App/Foo.swift   +8 -2 |
|  *run  |                             |  M App/Bar.swift   +0 -3 |
| Tab B  |   [ terminal / panes ]      | Untracked               |
|  vim   |                             |  ? docs/new.md          |
|        |                             | Conflicts               |
| (left  |                             |  U App/Baz.swift        |
| session|                             | ----------------------- |
| sidebar|                             | @@ -10,6 +10,8 @@        |
|  220pt)|                             |   context line          |
|        |                             | +  added line           |
|        |                             | -  removed line  (muted)|
|        |                             |   context line          |
|        |                             |  [⌘-click → editor]     |
|        |                             |  [ ↑/↓ prev/next hunk ] |
|        |                             |        (~260-300pt)     |
+--------+-----------------------------+-------------------------+
  leading          terminalContainer            trailing
  (#1 feature)                       (toggle ⌃⌘G, default collapsed)
```

---

## Residual unknowns / cheap manual spikes

1. ❓ **Sandboxed runner exec-git (10 min):** can the XCUITest runner `Process`-exec `git` directly into a HOME-relative temp repo for a hermetic test, or must setup drive the live shell?
2. ❓ **git PATH with CLT-only (quick):** does login-shell `command -v git` reliably resolve when only Xcode Command Line Tools are installed (incl. the CLT install-prompt when absent)?
3. ❓ **Large-repo `git status` latency (spike):** cold (GUI-launched) vs warm-cache timing on the user's largest repo, to confirm the 200 ms debounce + 5 s spacing + 5 s poll windows and that off-main is mandatory; whether `--untracked-files=no` is ever needed.
4. ❓ **Poll-backstop interval (dogfood):** is 5 s the right floor for mid-agent-session freshness, or does it need 2–3 s (lazygit's refs-snapshot cadence)? Decide from real Claude-Code sessions before considering FSEvents.
5. ❓ **Diff readability at ~260–300 pt (visual):** legible inline on the built-in display at the 900 pt default when `terminalContainer` is also split into panes? Determines whether side-by-side ever needs a wider/detached host.
6. ❓ **OSC-133 mark cardinality (quick):** confirm which marks the bundled injected zsh emits per command (does B/promptEnd fire? PS2 `k=s`?) to size the over-refresh the `.commandEnd` gate avoids.
7. ❓ **`.inspector` vs hand-rolled mirror (optional):** native SwiftUI `.inspector` (macOS 14) is leaner; benchmark vs the AppKit mirror during implementation.

---

## Proposed OpenSpec capabilities touched (mechanism-neutral)

- **`git-review`** (NEW capability spec) — the panel: lists changed files for the focused local repo grouped by status category; click → read-only diff; ⌘-click → open in editor; empty states for remote/non-repo/git-not-found; refresh on command-finish + periodic backstop + focus + manual. Requirements stay mechanism-neutral (the *what*); v1-vs-v2, shell-out-vs-libgit2, trailing-panel, debounce+poll+spacing mechanics live in `design.md`.
- **`verification-harness`** (MODIFIED) — DEBUG dump SHALL expose the `gitReview` snapshot (counts/paths/statuses + selectedDiff summary + refresh counter, never full diff text); new e2e scenarios for known-state listing, click→diff (`XTTY_TEST_GIT_SELECT`), and ⌘-click→editor (reusing `lastLinkOpen`).
- **`terminal-keybindings`** + **`app-shell`** (MODIFIED) — a Toggle-Git-Review action / View-menu item / default ⌃⌘G chord; next/prev-hunk actions.
- **`terminal-configuration`** (MODIFIED) — add a **`diff-context`** key (and optionally a per-file diff line cap). Editor-open reuses the existing **`link-opener`** key (`XttyCore/.../XttyConfigLoader.swift:158`), so **no new config key for the editor path**.

**Decisive guardrails the proposal must encode** (under-specified in the raw findings): (a) refresh git **only on `.commandEnd` + a gated periodic poll**, debounced, ~5 s-spaced, serialized, visible+local+idle-gated — **never** on `registry.revision`; (b) status is **porcelain v1 `-z --no-renames -uall`** with branch fetched separately, **not** v2 `--branch`; (c) `git diff --no-index` **exit 1 == success**; (d) all reads carry `GIT_OPTIONAL_LOCKS=0` and diffs carry `--no-ext-diff --no-color`; (e) `gitReview` dump reads a **cached** snapshot, never exec; (f) the right-panel slot **reworks** `terminalContainer.trailing` (`TerminalWindowController.swift:176`), it is not a free mirror; (g) the file/status data model stays **forward-compatible with a later stage toggle** though staging ships nothing in v1.

---

## P6a+ addendum — intra-line diff emphasis decided (`add-git-review-polish`)

> **Provenance.** Authored 2026-06-29, a third research pass on top of the P6a doc above. Method: a 6-reader source-grounded multi-agent workflow (zed, gitui + the Rust `similar` crate, Google diff-match-patch, SwiftUI/Apple-docs rendering, lazygit pause-refresh; **delta dropped out on a tool error**) → 4 adversarial refutations of the decision-driving claims → synthesis, **cross-checked against a hand-read of delta** (`src/edits.rs`, `src/align.rs`, `src/cli.rs`), zed (`crates/buffer_diff/src/buffer_diff.rs`, `crates/language/src/text_diff.rs`, `crates/editor/src/element.rs`), and diff-match-patch (`diff_main`). Confidence legend unchanged (✅ confirmed · ❌ corrected · ❓ open).

P6a (above) **deferred** word-level intra-line diff to "P6a+". This addendum **decides** it — as the headline of a small follow-on change, `add-git-review-polish`, bundled with one refresh-policy guard.

### Headline

Ship **token-level intra-line emphasis**: tokenize each changed line (word / punctuation / whitespace classes), run a small **LCS/Wagner–Fischer DP over the tokens**, and highlight the changed-token spans with `Text(AttributedString)` per-run `.backgroundColor`. Gated, pure-`XttyCore` algorithm + one render swap, **zero new deps**. Bundle a **one-line poll-skip-during-own-git** guard (also reconciles an over-claimed P6a task checkbox). **Defer** syntax highlighting, FSEvents, and unbalanced-run emphasis.

### Resolved forks

| Fork | Decision | Confidence |
|---|---|---|
| **Algorithm** | Real diff on the changed middle — **token-level DP** (delta/zed shape). *Not* trim-only; *not* char-level. | ✅ High |
| **Gate** | Replacement-run; line cap ≤5; **byte cap 512**; 1:1 positional pairing (v1); **ratio-gate** ~60% (skip near-total rewrites); both-sides-non-empty | ✅ High |
| **Rendering** | `Text(AttributedString)` + per-run `.backgroundColor`; **macOS 12+ → no availability guard, no `NSViewRepresentable` fallback** | ✅ High |
| **pause-own-git** | **Drop** lazygit's mechanism; add **one poll-skip guard** via existing OSC-133 `runningCommand` | ✅ High |

The adversarial pass returned **MIXED on all four** claims — but reading the reasoning, each "mixed" was an *overstatement of a true core*, not a wrong core; every verdict confirmed the direction and tightened one guardrail.

### The token-vs-char correction (why the divergence matters)

- ❌ **Trim-only is insufficient.** Every reference uses common-prefix/suffix trim as a *speedup preamble*, then a **real diff on the residue** — diff-match-patch `diff_main` trims, then runs full Myers (`diff_bisect`) on the middle, then `cleanupSemantic`. Trim-only over-highlights any multi-edit line (`foo(a,b,c)` → `foo(x,b,y)` lights up the whole `,b,` interior) — exactly the agent-review case the panel exists for.
- ❌ **Char-level (the workflow synthesis's pick) needs a word-snap pass** — the synthesis itself ranked snap-raggedness its #1 risk. That pick **skewed char-level because delta dropped out of the workflow**, leaving general-*text* diff-match-patch as the dominant single-line source. Hand-reading delta corrected it.
- ✅ **Token-level wins for code.** The two *code-focused* tools both tokenize (delta on `\w+`, `src/edits.rs:140-165`; zed via `CharClassifier`, `text_diff.rs:391-419`). Tokenizing **is** the word-boundary handling, so it is word-aligned by construction — no snap pass, fewer moving parts, leaner. **The lever that makes a real diff cheap is tokenization** (DP over ~tens of tokens ≈ hundreds of cells), *not* trimming: char-level DP over the 3000-char cap is ~9M cells; token-level is ~400. Char-level stays a clean upgrade (same DP, swap the unit) if sub-token precision is ever wanted.

### Gate (source-grounded)

Operate on a **replacement run** = a maximal block of consecutive `.deletion` lines immediately followed by consecutive `.addition` lines *within one hunk* (context lines split runs — the detector must handle that; it is the part most likely to mis-pair, unit-test it directly).

- **Line cap ≤5** (zed `MAX_WORD_DIFF_LINE_COUNT`, `buffer_diff.rs:20`) and **byte cap 512** (zed `MAX_WORD_DIFF_LEN`, `text_diff.rs:10`) are the **real cost bounds**.
- **1:1 positional pairing** (`del[i] ↔ add[i]`, requires `delCount == addCount`) is the **v1 mechanism** — line-local ranges, simplest to test. The equal-count requirement is a *pairing-mechanism precondition*, **not** a cost gate.
- **Ratio-gate** (`similar`'s `min_ratio` idea): if the emphasized fraction > ~60 %, drop to whole-line tint (an unrelated rewrite, not an edit). **Both-sides-non-empty:** skip pure-add/pure-del runs.
- Source nuance worth recording: zed has **two** gates — the live `buffer_diff` path (**GATE A**: equal-count AND ≤5 lines, *no* byte cap, `buffer_diff.rs:1210-1214`) and the standalone `text_diff` path (**GATE B**: ≤512 bytes, ≤8 lines, *no* equal-count, `text_diff.rs:329-342`). We take **A's equal-count** (for the simple positional pairing) **+ B's byte cap** (belt-and-suspenders against one pathological long line inside an otherwise small hunk — the gap the adversarial verdict flagged in GATE A).
- **Named upgrade (deferred):** unbalanced runs (e.g. 2→3 lines) → diff the run's *concatenated* deletion-text vs addition-text in one pass (GATE B shape — no pairing, handles unequal counts), behind the same caps.

### Rendering (source-grounded)

`Text(AttributedString)` with per-run `.backgroundColor` over the changed spans — native, dependency-free, **macOS 12.0+** (`AttributeScopes.SwiftUIAttributes.backgroundColor`), so the 14–26 target needs **no availability guard and no fallback**. The widely-cited "SwiftUI AttributedString is not there yet" critique explicitly **exempts** `backgroundColor` as one of the few attributes `Text` honors. Two-layer model (zed's): the existing lighter whole-line tint (`green/red .opacity(0.18)`) as the row background **+** a **darker** changed-span `.backgroundColor` run on top — maps cleanly to a cell-background highlight, no glyph reshaping, no underline/strikethrough.

Guardrails (all granularity-independent; adopt regardless of algorithm):
- **Marker offset.** `DiffLine.text` keeps the leading `+`/`-`/space. Compute emphasis on the **marker-stripped content** (offset 0 = first content char); render the marker as a **separate fixed-width leading `Text`** in an `HStack` so it is *structurally never tinted* (also fixes column alignment in the ~240–300 pt panel).
- **Grapheme unit-match end-to-end.** Diff and render in the **same** grapheme/`Character` unit; map offsets via `index(_:offsetByCharacters:)`. Unit mismatch is the documented cause of torn runs on emoji/CJK — and xtty already round-trips CJK + non-BMP emoji in its grid dump.
- **Memoize.** Build the styled `AttributedString` once in the `XttyCore` model (carry emphasis spans on `DiffLine`), never in `body` — construction is the real per-row cost, not the CoreText pass.
- **Container.** Keep the existing `LazyVStack` in the 2-axis `ScrollView` (horizontal scroll for long lines; `List` doesn't give that cleanly); the no-recycle memory hazard is already bounded by the `maxLines: 5000` per-file cap + lazy-per-file load. Pin a **fixed monospaced row height**. `NSViewRepresentable`/`List`/`HStack`-of-segments are rejected (the last breaks monospaced alignment + inflates view count).

### pause-during-own-git (drop the mechanism, add one guard)

lazygit's `pauseRefreshesCount` does **not** transfer: grepping its machinery for `lock`/`GIT_OPTIONAL_LOCKS` finds nothing — its rationale is bracketing lazygit's **own** multi-step git operations (rebase/reword) so a background read never lands on intermediate state. xtty **orchestrates no git** — the poller is a passive read-only observer with `GIT_OPTIONAL_LOCKS=0`, so there is no lock contention and no write race. The premise is absent; the only residual value is cosmetic (suppress a transient file-list **flash** if the 5 s poll fires mid-operation — and the OSC-133 `commandEnd` refresh self-corrects it the instant the command finishes).

**Minimal correct rule (bundle this, not the mechanism):** in `GitReviewController.performRefresh`, skip **only the poll-timer tick** (never `commandEnd`, never focus/manual) when the focused session's OSC-133 `runningCommand` is a git invocation. One guard, one existing signal. Do **not** port `pauseRefreshesCount`/`WithWaitingStatusImpl`.

It stays *in* the change only because it is ≈free **and** it reconciles an over-claim: P6a `tasks.md` 5.3 is checked but the shipped `GitReviewController` has **no** min-spacing, dedup-by-toplevel, or pause-own-git. Honest reconciliation — min-spacing is **subsumed by the existing serialize** (in-flight + pending), dedup-by-toplevel is **moot** (the controller only ever refreshes the single *focused* target), and pause-own-git is **now actually built**.

### Best-benefit ranking / scope of `add-git-review-polish`

| Item | Call | Note |
|---|---|---|
| **Intra-line emphasis** (token-DP) | **IN — core** | highest agent-review value; bounded cost; the reason for the change |
| **pause-own-git** (poll-skip guard) | **IN — minimal** | ≈free; reuses `runningCommand`; reconciles the 5.3 checkbox |
| next/prev-hunk nav | **OPTIONAL (lean: defer)** | nav is cheap, but drags in keybinding-config surface (presets + per-action overrides + a `terminal-keybindings` delta) — fast-follow, not core |
| ahead/behind counts | **OPTIONAL (marginal)** | one `rev-list --count` + a header label; lowest priority |
| syntax highlighting · FSEvents · unbalanced-run emphasis | **DEFER (P6a+)** | dep cost / dogfood-gated / named upgrade |

### Spike + harness (do before committing the algorithm)

- ❓ **~1–2 h spike:** run tokenize→DP on ~10 representative pairs — single edit, multi-edit-with-shared-interior, near-total rewrite, CJK, non-BMP emoji, combining marks — eyeball emphasis quality **and** confirm grapheme offsets render aligned through a real `Text(AttributedString)`. Validates algorithm + render unit-match together.
- **Harness:** emphasis is new observable behavior → `gitReview` dump gains the selected diff's emphasis spans (counts/ranges, never text) + an e2e, plus `XttyCore` unit tests on the tokenizer, the DP, and replacement-run detection.

### Spec surface (mechanism-neutral)

- **`git-review`** (MODIFIED) — the read-only-diff requirement gains *optional, gated, bounded* intra-line emphasis; the lean-gated-refresh requirement gains the poll-skip-during-own-git refinement.
- **`verification-harness`** (MODIFIED) — `gitReview` dump emphasis field + e2e scenario.
- **`terminal-keybindings`** (MODIFIED) — **only if** next/prev-hunk nav is folded in.

---

## P6b addendum — file-tree scope decided (Scope A; Scope B rejected)

> **Provenance.** Authored 2026-06-29, a 4th pass on this doc — codebase-grounded `/opsx:explore p6b` (read the shipped `GitReviewStore`/`GitStatus`/`GitReviewController`/`GitRunner`/`GitReviewView` + both trackers), no new OSS clone. Resolves a contradiction *between this doc and the milestone* over what "P6b" means. Confidence legend unchanged (✅ confirmed · ❌ corrected · ❓ open).

P6a deferred "the full file-tree browser" to P6b, but the two trackers described **two different features** under that one name. This addendum picks one.

### The contradiction

- `02-milestones.md:76` framed P6b as **"browse *all* files (lazy tree, expand/collapse)"** — a full project Explorer (**Scope B**).
- This doc (`:50`, `:135`) framed P6b as **"a flat-vs-tree toggle"** citing zed `git_panel_settings.rs:30-37` — a tree *view of the changed files we already list* (**Scope A**).

These are not two sizes of one feature: **Scope B is a new data source** (filesystem walk + lazy children + a watcher story, wanting the still-deferred FSEvents), **Scope A is a presentation transform** over the existing `git status → [GitChangedFile]` list.

### Decision

| Option | Call | Confidence | Why |
|---|---|---|---|
| **Scope B — full project file-tree browser** | ❌ **reject** | ✅ High | Phase 6's hard non-goal is *"not a full IDE"*; a standing browse-every-file pane is the most IDE-ish thing left. It **duplicates the shell** (`ls`/`eza --tree`/`cd`/`fzf`/`zoxide`) and the **⌘-click-any-`path:line`** opener (P4b-1 `terminal-links`) xtty already ships, at a persistent-memory + chrome cost that fights M1 (lean). Off-mission. |
| **Scope A — flat↔tree toggle over the *changed* files** | ✅ **this is P6b** | ✅ High | Pure **view-free transform** over the existing flat `[GitChangedFile]` (split each path on `/`, fold into nodes). On-mission precisely for the **agent-host keystone**: a large agent-generated refactor (40 files across 15 dirs) makes the flat Changes/Untracked/Conflicts list a long scroll; a collapsible directory tree makes it reviewable. Literally zed's cited tree-toggle. |
| **Defer P6b until after P7-measure** | 🟡 **recommended default** | ✅ High | P6b is "convenience, not the keystone" (this doc, `:50`); the git-review keystone already shipped (P6a/P6a+). **P7 (measure) is the actual gate.** Nothing here is urgent. |

So: **P6b ≔ Scope A** (correct the milestone's "browse all files" wording, which overstates it), **sequenced after P7** unless dogfooding a big agent changeset makes the flat list painful sooner.

### Build shape if/when P6b lands (mechanism notes, not a spec)

- ❌ **Model-honesty correction.** This doc earlier claimed the model was kept "forward-compatible with a `GitListEntry` enum (Status/Header, later Directory)" (`:135`). **That enum was never built** — the shipped `GitChangedFile` (`XttyCore/.../GitStatus.swift:33`) is a flat struct, and `GitReviewView` groups by category in the *view* via `snapshot.files(in:)` + `GitStatusCategory.allCases`. **It doesn't matter:** Scope A needs **no model reshape** — a directory tree is a pure function over the flat list.
- ✅ Add a view-free, unit-testable `XttyCore` helper (e.g. `GitFileTree.build(_ files: [GitChangedFile]) -> [TreeNode]`) — paths → nested nodes, leaves carry the `GitChangedFile` (status glyph + numstat badges unchanged). Tested like the other parsers, no app/view.
- ✅ App layer: a SwiftUI `OutlineGroup`/`DisclosureGroup` swap in `GitReviewView` behind a header toggle (and/or a `git-review-layout: flat|tree` `terminal-configuration` key — zed has the setting; a UI toggle alone is also fine). **No `GitRunner` change, no new git invocation, no FSEvents, no filesystem walk.**
- Harness: tree is presentation over the same `gitReview` dump (`changedFiles` already reported); at most assert the layout mode — minimal `verification-harness` surface.
- Effort: ~a day, low risk (Scope A). Scope B would be multi-day + a whole FS-enumeration side-effect layer — another reason it stays rejected.

### Spec surface if proposed (mechanism-neutral)

- **`git-review`** (MODIFIED) — the changed-files list MAY be presented either flat-by-category or as a collapsible directory tree of the same changed files; the tree is presentation only (no new files surfaced, no write op, read-only unchanged).
- **`terminal-configuration`** (MODIFIED) — *only if* the layout is config-exposed (`git-review-layout`).
- **`verification-harness`** (MODIFIED) — *only if* the dump needs the active layout mode.
- ✅ **Resolved:** built as `add-git-review-tree` (implemented; pending archive) — a view-free `GitFileTree` builder + a `GitReviewLayout` on `GitReviewStore`, a `git-review-layout = flat|tree` global config key (default `flat`), a SwiftUI `DisclosureGroup` tree branch + header toggle in `GitReviewView`, and a `layout` field on the `gitReview` dump. No new git/FS call, no new dep.

---

## Sources

- **xtty codebase** (re-verified `main`@`902f41a`): `App/TerminalWindowController.swift`, `App/PaneController.swift`, `App/FileOpener.swift`, `App/XttyApp.swift`, `XttyCore/Sources/XttyCore/{OSC133,TerminalSession,XttyConfigLoader}.swift`, `XttyCore/Package.swift`.
- **lazygit** (Go): `pkg/commands/patch/{patch_line,parse}.go`, `pkg/commands/git_commands/{file_loader,diff,working_tree}.go`, `pkg/gui/background.go`, `pkg/gui/controllers/helpers/diff_helper.go`, `go.mod`.
- **gitui** (Rust): `asyncgit/src/sync/diff.rs`, `src/components/diff.rs`, `src/main.rs`, `src/watcher.rs`.
- **delta** (Rust): `src/align.rs`, `src/edits.rs`, `src/delta.rs`, `src/cli.rs`, `src/handlers/{hunk,hunk_header}.rs`, `src/paint.rs`. *(P6a+ addendum: re-read `edits.rs` token-DP + `align.rs` Needleman–Wunsch/Wagner–Fischer + `cli.rs:594` `max-line-distance` default 0.6.)*
- **zed** (Rust): `crates/git/src/{repository,status}.rs`, `crates/git_ui/src/{git_panel,git_panel_settings,project_diff}.rs`, `crates/buffer_diff/src/buffer_diff.rs`, `crates/project_panel/src/project_panel.rs`. *(P6a+ addendum: `buffer_diff.rs:20,1210-1238` GATE A + `crates/language/src/text_diff.rs:10-11,185-220,329-419` word tokenizer/GATE B + `crates/editor/src/element.rs:4547-4607` word-diff highlight render.)*
- **VS Code** (TS): `extensions/git/src/{git,repository,decorators}.ts`.
- **waveterm** (TS): `frontend/app/view/codeeditor/{diffviewer,aifilediff}.tsx`, `frontend/app/view/term/termsticker.tsx`.
- **SwiftGit2**: no `Package.swift` (vendors libgit2 submodule + Carthage/Xcode-project) → confirms libgit2 is heavy for Swift.

**P6a+ addendum, additional sources** (2026-06-29 intra-line-emphasis pass):
- **Google diff-match-patch** (`python3/diff_match_patch.py`): `diff_main` (prefix/suffix trim → `diff_compute`/`diff_bisect` Myers on the residue → `diff_cleanupMerge`), `diff_cleanupSemantic`/`diff_cleanupSemanticLossless` (word-boundary scoring) — the reference that **trim is a preamble, not the algorithm**.
- **Rust `similar` crate** (mitsuhiko/similar): `TextDiff`/`ChangeTag`, Myers/Patience/LCS, grapheme/word/char granularities, `min_ratio` — borrowed the ratio-gate idea, rejected the crate (dep).
- **Apple Developer docs**: `AttributeScopes.SwiftUIAttributes.backgroundColor` (macOS 12.0+); the "AttributedString is not there yet" survey exempting `backgroundColor`; `AttributedString.index(_:offsetByCharacters:)`.
- **lazygit** (Go): `pkg/gui/background.go` `pauseRefreshesCount` — confirmed *not* lock-related (brackets lazygit's own multi-step ops), so it does not transfer to xtty's read-only poller.
- **Method:** 6-reader source-grounded workflow (`wf_11d118f8-14c`) → 4 adversarial verifications → synthesis, cross-checked against hand-reads of delta/zed/diff-match-patch (delta dropped from the workflow on a tool error and was supplied by hand-read).

**P6b addendum, additional sources** (2026-06-29 file-tree-scope pass):
- **xtty codebase** (shipped P6a/P6a+): `XttyCore/Sources/XttyCore/{GitStatus,GitReviewStore,GitDiff}.swift` (flat `GitChangedFile`, no `GitListEntry` enum — confirms the model-honesty correction), `App/{GitReviewView,GitReviewController,GitRunner}.swift`.
- **zed** (Rust): `crates/git_ui/src/git_panel_settings.rs:30-37` (the flat-vs-tree toggle = Scope A) vs `crates/project_panel/src/project_panel.rs` (the full Explorer = Scope B, rejected).
- **Method:** codebase-grounded `/opsx:explore p6b` resolving a milestone-vs-decisions-doc contradiction; no new OSS clone.