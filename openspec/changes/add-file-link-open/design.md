## Context

P4a captured the live cwd (OSC 7) and command blocks (OSC 133), all view-free in `XttyCore`. P4b — the spatial half of the keystone — was thought to need a SwiftTerm fork in full. A post-P5 sweep (see [`p5-sidebar-and-p4b-sequencing`](../../../research/03-analysis/p5-sidebar-and-p4b-sequencing.md#update-2026-06-28-post-p5-p4b-splits-in-two--fileline-click-to-open-is-fork-free)) found that **file:line click-to-open needs no fork**, splitting P4b into P4b-1 (this change, fork-free) and P4b-2 (`add-spatial-blocks`, the fork). This is the agent-CLI win (agents emit `file:line` constantly) and the plumbing the P6 file/diff view reuses.

**Verified ground truth (SwiftTerm `v1.13.0`, the pinned version):**
- Implicit link detection is **on by default** — `linkReporting = .implicit` (`Mac/MacTerminalView.swift:599`); the ported Ghostty matcher (`Terminal.swift:6106`) already detects bare/relative/rooted paths and keeps a `:line:col` suffix (`:` is in `pathChars`; only a *trailing* colon is trimmed).
- On click, the view calls `terminalDelegate?.requestOpenLink(source:link:params:)` (`Mac/MacTerminalView.swift:2005`).
- `requestOpenLink` is a `TerminalViewDelegate` **protocol requirement** (`Apple/TerminalViewDelegate.swift:59`) with a macOS protocol-extension default that calls `NSWorkspace.open` (`Mac/MacTerminalView.swift:2418`).
- `LocalProcessTerminalView` sets `terminalDelegate = self` and forwards only a **curated subset** to `processDelegate` (`sizeChanged`, `setTerminalTitle`, `hostCurrentDirectoryUpdate`, `send`, `scrolled`, `rangeChanged`, `clipboardCopy`, `processTerminated`) — **`requestOpenLink` is NOT forwarded** (`Mac/MacLocalTerminalView.swift`).
- `public weak var terminalDelegate: TerminalViewDelegate?` is **publicly settable** (`Mac/MacTerminalView.swift:96`).
- `session.liveLocalDirectory` already gives the resolution base (local cwd, or `nil` when remote/over-ssh).

## Goals / Non-Goals

**Goals:**
- Cmd-click a `file:line[:col]` (or bare/relative/rooted path) in output → open it in the user's editor at that line, resolved against the focused session's live local cwd.
- Add the deferred D7 scheme guard so only safe schemes auto-open.
- Keep all decision logic (classification, guard, path resolution, invocation building) **view-free and unit-tested** in `XttyCore`.
- **No SwiftTerm fork.** Stay pinned at `v1.13.0`.

**Non-Goals:**
- Jump-to-prompt, copy/select a command's output (P4b-2 — the fork).
- The in-terminal P6 file/diff view (this opens in the *external* editor; P6 reuses the same path+cwd plumbing later).
- Opening **terminal** editors (`vim`/`emacs -nw`) in a new xtty tab — falls back to `open` for now (see D3/Open Questions).
- Reimplementing SwiftTerm's hit-testing, hover-underline, or detection regex.

## Decisions

### D1 — Interception via a vetted `terminalDelegate` proxy (not a delegate method, subclass override, or fork)

The naive plan ("implement `requestOpenLink` on `PaneController`") **does not work**: `requestOpenLink` is not forwarded to `processDelegate`, and a subclass cannot override a protocol-extension default that already satisfied `LocalProcessTerminalView`'s conformance (the witness is statically dispatched). The P3a `terminal-links` Purpose note ("non-overridable protocol-extension default") was correct.

**Chosen:** install a small `LinkRoutingTerminalDelegate` (an `NSObject: TerminalViewDelegate`) as the view's `terminalDelegate`, holding a weak reference to the original delegate (the `XttyTerminalView` itself). It **forwards the other 9 `TerminalViewDelegate` methods verbatim** to the original — preserving SwiftTerm's process plumbing (`send` to the PTY, `sizeChanged`, `hostCurrentDirectoryUpdate`, etc.) — and routes **only `requestOpenLink`** to xtty's handler. This intercepts at SwiftTerm's own decision point, so we inherit its accurate hit-testing, hover-underline, and detection for free; we only redirect the *action*.

**Alternatives rejected:**
- *Plain `processDelegate` method* — `requestOpenLink` isn't in `LocalProcessTerminalViewDelegate` and isn't forwarded.
- *Subclass override in `XttyTerminalView`* — can't override the protocol-extension default; also `mouseUp` is `public` not `open`, so the click path can't be overridden either.
- *NSEvent local monitor + the public `link(at:mode:)`* — fork-free and viable, but forces xtty to reimplement point→cell geometry (padding/retina/scroll) and to disambiguate click-vs-selection, racing SwiftTerm's `mouseUp`. More surface, more fragile. Kept as a documented fallback only.
- *One-line upstream fork* (forward `requestOpenLink` to `processDelegate`) — clean, but a fork; defeats the fork-free goal. Revisit only if the proxy proves fragile.

**Risk of the proxy:** if SwiftTerm later adds an 11th `TerminalViewDelegate` method with side effects, the proxy silently uses its extension default instead of forwarding. Mitigation: the protocol is small and stable (10 methods); the existing e2e suite types/resizes/reads, so a dropped `send`/`sizeChanged`/cwd forward fails loudly; a code comment enumerates the forwarded set with a "keep in sync" note.

### D2 — All decision logic is view-free in `XttyCore`

The app layer does only the AppKit-bound parts (installing the proxy, launching a `Process`/`NSWorkspace`). Everything else is a pure pipeline in `XttyCore`, unit-tested with `swift test`:
- `LinkTarget.classify(_ link:) -> LinkTarget` → `.url(scheme:raw:)` or `.file(path:line:column:)`.
- `SchemeGuard.policy(for:) -> .open | .openInEditor | .blocked`.
- `FileLinkResolver.resolve(path:relativeTo:) -> String?` (absolute, `~` expanded; `nil` if it escapes to a non-existent target and no cwd).
- `OpenerInvocation.build(target:template:environment:) -> .argv([String]) | .systemOpen(URL) | .blocked` — template tokenization + the editor-inference table.

This honors the architecture seam (logic talks to the engine via `XttyCore`, never the view) and keeps the render layer swappable.

### D3 — `link-opener` config key + smart `$VISUAL`/`$EDITOR` default

A new `link-opener` config key holds a command **template** (e.g. `code --goto ${file}:${line}:${column}`). When unset, infer from `$VISUAL` then `$EDITOR` using a known-editor table:

| editor (basename) | invocation |
|---|---|
| `code` / `code-insiders` / `cursor` / `windsurf` | `<e> --goto ${file}:${line}:${column}` |
| `subl` | `subl ${file}:${line}:${column}` |
| `idea` (& JetBrains) | `idea --line ${line} --column ${column} ${file}` |
| `mate` | `mate --line ${line} ${file}` |
| `emacs` / `emacsclient` | `<e> +${line}:${column} ${file}` |
| `vim` / `nvim` / `vi` / `nano` (terminal editors) | **fall back to `open ${file}`** (can't usefully GUI-launch; see Open Questions) |
| unknown / unset | macOS `open ${file}` |

Tokens (`${file}`/`${line}`/`${column}`) substitute as whole argv elements. Missing line/column collapse the token (and any adjacent `:`), so `code --goto ${file}:${line}:${column}` with no line opens `code --goto ${file}`. Prefer `$VISUAL` over `$EDITOR` (the GUI/full-screen convention).

### D4 — Security: argv tokenization + login-shell PATH resolution, never a shell string

The link string comes from terminal output — i.e. **potentially hostile** (a program can print `$(rm -rf ~)` as a "path"). So:
- The template is **tokenized into argv** by `XttyCore` (split on whitespace; `${file}` etc. are discrete tokens). The path is passed as a **literal argv element**, never concatenated into a shell command — no shell ever interprets it.
- GUI-launched xtty has a minimal PATH (the P3b "no-PATH reality"), so `argv[0]` (the editor binary) is resolved to an absolute path via a **login-shell `command -v` lookup** (reusing the `ShellResolver` login-shell pattern), cached per opener string. Then `Process` execs the resolved binary directly with the argv — PATH-found **and** injection-safe.
- macOS `open` uses `/usr/bin/open` (absolute) or `NSWorkspace`. URLs use `NSWorkspace.shared.open` after the guard.

### D5 — Relative resolution against the live local cwd; best-effort

Relative/bare paths resolve against `session.liveLocalDirectory` (P4a). A **remote** cwd (over ssh) yields `nil` → the bare path can't be resolved → no-op (don't open a path that doesn't exist locally). Resolution is best-effort and reflects the *current* cwd, not the cwd when the line scrolled past (the standard OSC 7 caveat). If the resolved path doesn't exist, prefer an interpretation that does (e.g. treat a trailing `:42` as part of the filename if `foo:42` exists but `foo` doesn't); otherwise open best-effort.

### D6 — Scheme guard (the deferred D7)

- `http`, `https`, `mailto` → open via `NSWorkspace` (unchanged behavior).
- `file:` → strip to a path → treat as a file (editor).
- No scheme → file path.
- **Any other scheme** (`x-foo://`, `vscode://`, `tel:`, `javascript:`, …) → **blocked** (logged, not opened). This closes the hole where a program prints a custom-scheme link that `NSWorkspace` would launch. Clicked text is never executed as a shell command (preserved).

### D7 — Keep SwiftTerm's activation gesture

Don't reimplement gestures. SwiftTerm already governs activation (Cmd-click for implicit links, plain click for explicit OSC 8) and hover-underline; the proxy only changes what the activation *does*. Documented as inherited behavior.

### D8 — Testing: unit-test the pure pipeline; one DEBUG-seam e2e for the cwd integration

- **Unit (the bulk):** classification, scheme guard, path resolution, invocation building + the editor table — exhaustive `XttyCore` tests.
- **e2e (integration seam):** the DEBUG state dump gains `lastLinkOpen` (target kind, cwd-resolved path, line/column, action = opened/blocked/no-op). A **DEBUG-only programmatic trigger** (e.g. a hidden action that feeds a synthetic link string through the *real* app routing + live session cwd) lets one XCUITest assert routing + cwd resolution **without** click-coordinate fragility and **without launching a real editor** (the opener executor is injected/no-op in the DEBUG path). Synthesizing a real Cmd-click over a detected link in the custom-drawn view is too fragile to assert (the AX ceiling), so it stays a documented manual check.

## Risks / Trade-offs

- **Proxy completeness** → covered by D1's mitigation (small stable protocol, loud e2e failure, keep-in-sync comment).
- **Terminal editors (`$EDITOR=vim`) fall back to `open`** → for now, users set `link-opener` for full control; "open in a new xtty tab" is a future enhancement (Open Questions). Mitigation: prefer `$VISUAL`; document clearly in `config.example`.
- **Login-shell `command -v` latency per new opener** (~50–150ms) → cached per opener string; only on first use; user-initiated and infrequent.
- **`path:line` ambiguity** with colons in filenames → best-effort heuristic with an existence check (D5); rare on macOS.
- **Hostile path strings** → neutralized by argv tokenization + direct exec (D4); no shell interpretation.

## Migration Plan

Additive and fork-free. SwiftTerm stays at `v1.13.0`. No config migration — `link-opener` is optional (absent → the smart default). `config.example` documents it. Rollback = revert the change; URL-clicking returns to SwiftTerm's `NSWorkspace` default (losing only the new guard + file handling).

## Open Questions

- **Terminal editors in a new xtty tab?** Cmd-click `foo.swift:42` with `$EDITOR=nvim` → spawn a new xtty tab running `nvim +42 foo.swift`. Native and compelling, but pulls in tab-spawning integration; deferred (a fast follow once the opener pipeline lands).
- **Confirm vs block unknown schemes?** D6 blocks silently (logged). A future "Open `x-foo://…`?" confirmation sheet could relax this; out of scope for the first cut.
- **`link-opener` per-profile?** It resolves through `resolve(from:base:)`, so a profile *can* override it; left implicit (no extra spec) unless a use case appears.
