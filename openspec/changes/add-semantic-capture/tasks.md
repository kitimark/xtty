## 1. OSC 7 live working directory (smallest, half-wired)

- [x] 1.1 Add a view-free OSC 7 URL decoder in `XttyCore` (accept `file://` percent-decoded and `kitty-shell-cwd://` raw; host up to first `/`; flag a non-local host as remote; no `~` expansion) with unit tests covering both schemes, percent-encoded paths, and a remote host.
- [x] 1.2 Add a per-session **live working directory** to `TerminalSession` (distinct from `launchConfig.cwd`), defaulting to the launch directory until OSC 7 arrives; update it from the decoded OSC 7 value.
- [x] 1.3 Fill the no-op `hostCurrentDirectoryUpdate(directory:)` delegate in `PaneController` to decode + store the live cwd on the session (do NOT register a custom OSC 7 handler — keep the built-in trust-gated path).
- [x] 1.4 Make `splitFocusedPane` start the new pane in the focused pane's live cwd (fallback: inherited profile launch cwd → default). Thread the resolved start directory into `PaneController`/`startProcess(currentDirectory:)`.

## 2. Shell-integration injection (zsh)

- [x] 2.1 Author the bundled zsh integration dir: a bootstrap `.zshenv` (restore `XTTY_ORIG_ZDOTDIR`, source the user's real `.zshenv`, then interactive-only source the hook installer) and a hook installer using `add-zsh-hook precmd/preexec` to emit OSC 133 A/C/D + OSC 7 (model on Ghostty/Kitty, additive hooks).
- [x] 2.2 Add the integration dir as an app-bundle resource in `project.yml` (folder reference, preserves `.zshenv`) and a runtime `Bundle` lookup helper (`ShellIntegration`, fail-soft + logged if missing).
- [x] 2.3 Extend `ShellResolver` to accept an injected integration-directory path and add `ZDOTDIR` + `XTTY_ORIG_ZDOTDIR` to the seed env — reading any inherited `ZDOTDIR` BEFORE the wholesale seed; skip injection for profile `command` one-shots and non-zsh shells. Unit-tested (with/without inherited `ZDOTDIR`, command-one-shot skip, non-zsh skip).
- [x] 2.4 Wire the bundle path from the app layer (`ShellIntegration.zshDirectory`) into `ShellResolver` at pane launch. (Hands-on emit/dotfile check happens with the e2e in 6.x / the build in 7.1.)
- [x] 2.5 Document the manual-source fallback (for `/etc/zshenv`-override / opt-out) in `config.example`.

## 3. OSC 133 parser (view-free)

- [x] 3.1 Implement a pure `XttyCore` OSC 133 parser: `action = byte[0]` ∈ `{A,B,C,D,P}` (ignore unknown); split options on `;` then first `=`; `D`'s exit code is a bare positional `Int32` (bare = none); decode `cmdline`/`cmdline_url` with raw fallback; recognize `k=s` continuation.
- [x] 3.2 Unit-test the parser against the byte forms emitted by the shipped script plus the Ghostty/Kitty corpus (A/B/C/D/P, `D;0`, `D;12;aid=foo`, bare `D`, negative code, `cmdline`/`cmdline_url`, split-on-first-`=`, `k=s`, unknown bytes).

## 4. Alternate-screen detection

- [x] 4.1 Override `bufferActivated(source:)` on `XttyTerminalView` (call `super`, then read `source.isCurrentBufferAlternate`) and surface enter/exit to the session; expose the alt-screen flag.
- [x] 4.2 Add a harness/manual check that the override fires on a real alt-screen app (e2e 6.3 drives `tput smcup`/`rmcup` and asserts the dump's alt-screen flag), with `Terminal.isCurrentBufferAlternate` polling as the documented fallback.

## 5. Block lifecycle model

- [x] 5.1 Add `Block` (`command`, `exitCode`, `cwd`, `startedAt`, `endedAt`, `state ∈ {running,succeeded,failed,opaque}`) and a per-session `BlockTracker` in `XttyCore` — storing durable fields only, no screen coordinates.
- [x] 5.2 Implement the view-free lifecycle state machine (`idle`/`atPrompt`/`running`): open on `C`, close on first `D` after `C` (record exit code → succeeded/failed), discard prompt-only regions, defensive no-op on stray `D`, treat `k=s` continuation as same command.
- [x] 5.3 Gate on alt-screen: suppress create/close while alternate; finalize a command that entered alt mid-run as `opaque` on the `D` after returning to primary. (Output-text capture is intentionally NOT done in P4a — it needs the output's row coordinates, which are exactly the internal-API gap deferred to P4b; the block's required fields are command/exit/cwd/time/state only.)
- [x] 5.4 Register the OSC 133 handler on the engine in the app layer (`registerOscHandler(code: 133)`), feed it to the parser → state machine on the engine feed path (confine model mutation via `MainActor.assumeIsolated`). Unit-tested the state machine end-to-end (mark sequences → block list).

## 6. Verification harness

- [x] 6.1 Extend the DEBUG state dump (`writeStateDump`) with the focused pane's live `currentDirectory`, `isAlternateScreen`, `lastSemanticAction`, and a `blocks` array (`command`, `exitCode`, `state`).
- [x] 6.2 Add an XCUITest driving a real injected zsh: run a succeeding + a failing command and assert blocks form with correct exit codes/state. (Verified asserting, not degrading — `true`→succeeded/0, `false`→failed/nonzero.)
- [x] 6.3 Add XCUITest coverage that `cd` updates the live working directory, and that a full-screen app (`tput smcup`/`rmcup`) sets the alt-screen flag and produces no normal block. Block/cwd tests degrade gracefully when capture/hook is absent; alt-screen detection asserts unconditionally.

## 7. Build, test, and wrap-up

- [x] 7.1 `xcodegen generate` (resource folder ref + new sources); `cd XttyCore && swift build && swift test` green (126 tests); `xcodebuild -project xtty.xcodeproj -scheme xtty -destination 'platform=macOS' build` and `test` green (17 XCUITests).
- [x] 7.2 Ticked this `tasks.md`, refreshed **Current status** in `AGENTS.md`, and advanced Phase 4 (P4a done / P4b deferred) in `research/04-design/02-milestones.md` — re-cutting P4's "Done when" to the data-model + cwd value (jump/select/marks are P4b).
