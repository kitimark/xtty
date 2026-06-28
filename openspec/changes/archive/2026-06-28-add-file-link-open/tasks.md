## 1. XttyCore — config key

- [x] 1.1 Add `linkOpener: String?` to `XttyConfig` (default `nil`) and its initializer; keep `Equatable`/`Sendable`.
- [x] 1.2 Parse `link-opener` in `XttyConfigLoader.resolve(from:)` (trim; empty → `nil`); unknown keys still ignored.
- [x] 1.3 Unit tests: `link-opener` set / empty / absent → expected `linkOpener`; inherited by a profile via `resolve(from:base:)`.

## 2. XttyCore — link classification + scheme guard (view-free)

- [x] 2.1 Add `LinkTarget` (`.url(scheme:String, raw:String)` / `.file(path:String, line:Int?, column:Int?)`) and `classify(_ link: String) -> LinkTarget` — detect `scheme://`/`mailto:`/`file:`; otherwise treat as a path, stripping a trailing `(:\d+){1,2}` as line[:col].
- [x] 2.2 Add the scheme guard: `http`/`https`/`mailto` → open URL; `file:` → file; any other scheme → blocked.
- [x] 2.3 Unit tests: `https://…`, `mailto:…`, `file:///p:10`, `/abs/x`, `./rel`, `~/x`, `src/foo.swift`, `foo.swift:42:7`, `foo:42`, and a blocked `x-foo://…`; colon-in-filename best-effort.

## 3. XttyCore — path resolution + opener invocation (view-free)

- [x] 3.1 `FileLinkResolver.resolve(path:cwd:home:) -> String?` — expand `~`, make absolute against `cwd`; `nil` when relative and `cwd` is `nil`; colon-in-filename preference handled in `LinkRouter.resolve` (prefer the interpretation that exists on disk).
- [x] 3.2 `OpenerBuilder.build(file:line:column:template:environment:) -> OpenerInvocation` (`.editorArgv` / `.systemOpenFile` / `.openURL`) — tokenize the template into argv, substitute `${file}`/`${line}`/`${column}` as whole tokens, collapse missing line/column (and adjacent separators). Composed by `LinkRouter.resolve → LinkOpenResolution`.
- [x] 3.3 Editor-inference table for unset/empty template: `$VISUAL` then `$EDITOR` → known GUI editors (code/cursor/code-insiders/windsurf/codium, subl, idea & JetBrains, mate, emacs/emacsclient); terminal editors (vim/nvim/vi/nano/…) and unknown → macOS `open`.
- [x] 3.4 Unit tests: configured template substitution (with/without line/column), each known editor's invocation, `$VISUAL` preferred over `$EDITOR`, terminal-editor + unknown → `open`, URL target → `.openURL`, blocked scheme → `.blocked`, colon-in-filename preference.

## 4. App — fork-free interception (the vetted proxy)

- [x] 4.1 Add `LinkRoutingTerminalDelegate` (`NSObject, TerminalViewDelegate`): weak `inner` (the original delegate) + an `onOpenLink(String, [String:String])` closure; forward the other 9 `TerminalViewDelegate` methods verbatim to `inner`; route only `requestOpenLink`. Comment enumerates the forwarded set with a "keep in sync with SwiftTerm" note (design D1).
- [x] 4.2 In `PaneController`: after `processDelegate`/`commands` are set, capture the view (the original `terminalDelegate`) as `inner`, install the proxy as `view.terminalDelegate`, retain it, and wire `onOpenLink` → `openLink`.

## 5. App — routing + opener execution

- [x] 5.1 On open: `LinkRouter.resolve` (classify → scheme guard → resolve against `session.liveLocalDirectory` → build invocation) with the profile's `linkOpener` + process environment; record `lastLinkOpen`.
- [x] 5.2 `FileOpener.perform`: URLs via `NSWorkspace.shared.open`; `open` via `/usr/bin/open`; an editor `argv` via `Process`, resolving `argv[0]` to an absolute path with a cached login-shell `command -v` lookup (reuse the `ShellResolver` login-shell pattern — the no-PATH reality, design D4); never run through a shell. Log + no-op on blocked/unresolved.

## 6. App — DEBUG observability + harness

- [x] 6.1 Record the last resolved link-open action (target kind, resolved path, line/column, action opened/blocked/no-op) and add it to the window controller's DEBUG state dump (`#if DEBUG`, `-UITestGridDump`).
- [x] 6.2 Add a DEBUG-only trigger: the dump timer polls a link file whose path comes from the `XTTY_TEST_LINK_PATH` launch env (the sandboxed runner can't write `/tmp`), routes it through the real pipeline via `routeTestLinkOnActivePane` → `PaneController.routeTestLink` (resolve + record only, no editor launch).
- [x] 6.3 Add `AppUITests/XttyFileLinkOpenUITests.swift`: `cd` to a unique dir, route a synthetic `name:line` link → assert the dump's resolved path/line + action "opened"; route `x-foo://…` → assert "blocked". Degrade gracefully (screenshot) when the hook/capture is absent. **Both pass.**

## 7. Docs, validation, regenerate

- [x] 7.1 Document `link-opener` in `config.example` (template + `${file}`/`${line}`/`${column}`; the `$VISUAL`/`$EDITOR` fallback; terminal-editor note).
- [x] 7.2 `xcodegen generate` (new app + test files added); `swift test` (XttyCore, 148 tests) and `xcodebuild … test` (20 XCUITests) green.
- [x] 7.3 `openspec validate add-file-link-open` → valid.

## 8. Archive prep (at `/opsx:archive`, not now)

- [x] 8.1 At archive: correct the `terminal-links` spec **Purpose** (drop the stale "non-overridable protocol-extension default … needs the own-renderer or a vetted delegate proxy" note — the vetted proxy is exactly what shipped, fork-free) and confirm the merged requirement text matches what shipped.
- [x] 8.2 Update trackers: tick these tasks, refresh AGENTS.md "Current status" (P4b-1 implemented) + "Next:" (→ P4b-2), and advance Phase 4 in `research/04-design/02-milestones.md`.
