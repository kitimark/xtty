## Why

xtty's terminal output is full of `file:line` references — compiler errors, stack traces, grep results, and (especially) the agent CLIs xtty is meant to host emit them constantly. Today clicking one does nothing useful: SwiftTerm's implicit link detector already finds the path, but xtty inherits SwiftTerm's default handler, which hands *any* clicked link straight to `NSWorkspace.open` (no line number, no cwd resolution, and no guard on dangerous schemes — the deferred P3a "D7" gap). This is the P4b-1 milestone: the fork-free, agent-CLI half of P4b, and the on-ramp to the P6 file/diff view.

## What Changes

- **Click a `file:line[:col]` (or bare/relative/rooted path) → open it in the user's editor** at that line, resolved against the focused session's live local cwd (from P4a's OSC 7 capture). Plain file paths open the file; `http(s)`/`mailto` keep opening in the system handler.
- **Add a `link-opener` config key** — a command template with `${file}`/`${line}`/`${column}` substitution. When unset, xtty infers the invocation from `$VISUAL`/`$EDITOR` for known editors (`code`/`vim`/`nvim`/`emacs`/`subl`/`idea`), falling back to macOS `open`.
- **Add the deferred D7 scheme guard** — only `http(s)`/`mailto` (and `file:` → editor) are auto-opened; other schemes (custom app-launching `x-*://`, etc.) are not silently handed to `NSWorkspace`. Clicked text is still never executed as a shell command.
- **Mechanism (fork-free):** install a *vetted* `TerminalViewDelegate` proxy as the view's `terminalDelegate` that forwards the other delegate methods back to SwiftTerm and routes only `requestOpenLink` to xtty. (`requestOpenLink` is not forwarded to `processDelegate`, so a plain delegate method or subclass override cannot intercept it — see design D1.) No SwiftTerm fork.
- **View-free logic in `XttyCore`:** link classification (URL vs `path[:line[:col]]`), the scheme guard, relative→absolute path resolution, and opener-invocation building (template tokenization + the editor-inference table) — all pure and unit-tested.

## Capabilities

### New Capabilities
<!-- none — this extends existing capabilities -->

### Modified Capabilities
- `terminal-links`: add clickable **file-path** opening (resolved against the live cwd, opened in the editor at line/column) and the non-`http(s)` **scheme guard**; correct the Purpose's stale "non-overridable" note (interception is done via a vetted `terminalDelegate` proxy).
- `terminal-configuration`: add the `link-opener` config key (command template + `$VISUAL`/`$EDITOR` fallback; invalid/empty → the inferred default).
- `verification-harness`: the DEBUG state dump exposes the **last resolved link-open action** (target kind, cwd-resolved path, line/column, opened-vs-blocked) so routing + cwd resolution are assertable without click-coordinate fragility or launching a real editor.

## Impact

- **`XttyCore`** (new, view-free): `LinkTarget` classifier + scheme guard, file-path resolver, `OpenerInvocation` builder + editor-inference table; `XttyConfig.linkOpener` + `link-opener` parsing in `XttyConfigLoader`. New unit tests.
- **App**: a `LinkRoutingTerminalDelegate` proxy installed on `XttyTerminalView`/`PaneController`; the open side-effect (argv launch via the login shell for PATH, or `NSWorkspace` for URLs); a DEBUG `lastLinkOpen` field in the window controller's state dump.
- **Dependencies**: none — SwiftTerm stays pinned at `v1.13.0` (no fork). Implicit link detection is already on by default.
- **Docs**: `config.example` documents `link-opener`; `terminal-links` Purpose corrected at archive.
- **Out of scope (P4b-2, the fork):** jump-to-prompt, copy/select a command's output. **Out of scope here:** the in-terminal P6 file/diff view (this opens in the *external* editor; P6 later reuses the same path + cwd plumbing).
