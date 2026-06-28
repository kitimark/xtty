## 1. OSC 7 live working directory (smallest, half-wired)

- [ ] 1.1 Add a view-free OSC 7 URL decoder in `XttyCore` (accept `file://` percent-decoded and `kitty-shell-cwd://` raw; host up to first `/`; flag a non-local host as remote; no `~` expansion) with unit tests covering both schemes, percent-encoded paths, and a remote host.
- [ ] 1.2 Add a per-session **live working directory** to `TerminalSession` (distinct from `launchConfig.cwd`), defaulting to the launch directory until OSC 7 arrives; update it from the decoded OSC 7 value.
- [ ] 1.3 Fill the no-op `hostCurrentDirectoryUpdate(directory:)` delegate in `PaneController` to decode + store the live cwd on the session (do NOT register a custom OSC 7 handler — keep the built-in trust-gated path).
- [ ] 1.4 Make `splitFocusedPane` start the new pane in the focused pane's live cwd (fallback: inherited profile launch cwd → default). Thread the resolved start directory into `PaneController`/`startProcess(currentDirectory:)`.

## 2. Shell-integration injection (zsh)

- [ ] 2.1 Author the bundled zsh integration dir: a bootstrap `.zshenv` (restore `XTTY_ORIG_ZDOTDIR`, source the user's real `.zshenv`, then interactive-only autoload + run the hook installer + `unfunction`) and a hook installer using `add-zsh-hook precmd/preexec` to emit OSC 133 A/B/C/D + OSC 7 (model on Ghostty/Kitty, additive hooks).
- [ ] 2.2 Add the integration dir as an app-bundle resource in `project.yml` and a runtime `Bundle` lookup helper (fail-soft + logged if missing).
- [ ] 2.3 Extend `ShellResolver` to accept an injected integration-directory path and add `ZDOTDIR` + `XTTY_ORIG_ZDOTDIR` to the seed env — reading any inherited `ZDOTDIR` BEFORE the wholesale seed; skip injection for profile `command` one-shots. Unit-test the produced environment (with and without an inherited `ZDOTDIR`, and the command-one-shot skip).
- [ ] 2.4 Wire the bundle path from the app layer into `ShellResolver` at pane launch; verify hands-on that a plain shell emits OSC 7/133 and the user's `.zshrc` (alias/prompt) still loads.
- [ ] 2.5 Document the manual-source fallback (for `/etc/zshenv`-override / opt-out) in `config.example` or a README note.

## 3. OSC 133 parser (view-free)

- [ ] 3.1 Implement a pure `XttyCore` OSC 133 parser: `action = byte[0]` ∈ `{A,B,C,D,P}` (ignore unknown); split options on `;` then first `=`; `D`'s exit code is a bare positional `Int32` (bare = none); decode `cmdline`/`cmdline_url` with raw fallback; recognize `k=s` continuation.
- [ ] 3.2 Unit-test the parser against the exact byte forms emitted by the shipped script plus the Ghostty/Kitty corpus (A/B/C/D, `D;0`, `D;12;aid=foo`, bare `D`, `cmdline`/`cmdline_url`, `k=s`, unknown bytes).

## 4. Alternate-screen detection

- [ ] 4.1 Override `open func bufferActivated(source:)` on `XttyTerminalView` (call `super`, then read `source.isCurrentBufferAlternate`) and surface enter/exit to the session; expose the alt-screen flag.
- [ ] 4.2 Add a harness/manual check that the override fires on a real alt-screen app, with `Terminal.isCurrentBufferAlternate` polling as the documented fallback.

## 5. Block lifecycle model

- [ ] 5.1 Add `Block` (`command`, `exitCode`, `cwd`, `startedAt`, `endedAt`, `state ∈ {running,succeeded,failed,opaque}`) and a per-session `BlockRegistry` in `XttyCore` — storing durable fields only, no screen coordinates.
- [ ] 5.2 Implement the view-free lifecycle state machine (`idle`/`atPrompt`/`runningCommand`): open on `C`, close on first `D` after `C` (record exit code → succeeded/failed), discard prompt-only regions, defensive no-op on stray `D`, treat `k=s`/`P` continuation as same command.
- [ ] 5.3 Gate on alt-screen: suppress create/close while alternate; finalize a command that entered alt mid-run as `opaque` on the `D` after returning to primary. Capture output text eagerly at `D` via the public `getText(start:end:)`.
- [ ] 5.4 Register the OSC 133 handler on the engine in the app layer (`registerOscHandler(code: 133)`), feed it to the parser → state machine on the engine feed path (confine model mutation to that context; `nonisolated` + `MainActor.assumeIsolated`). Unit-test the state machine end-to-end (mark sequences → block list).

## 6. Verification harness

- [ ] 6.1 Extend the DEBUG state dump (`writeStateDump`) with the focused pane's live `currentDirectory`, `isAlternateScreen`, `lastSemanticAction`, and a `blocks` array (`command`, `exitCode`, `state`).
- [ ] 6.2 Add an XCUITest driving a real injected zsh: run a succeeding + a failing command and assert blocks form with correct exit codes/state.
- [ ] 6.3 Add XCUITest coverage that `cd` updates the live working directory, and that a full-screen app (`vim`/`tput smcup`) sets the alt-screen flag and produces no block. Degrade gracefully when the DEBUG hook is absent.

## 7. Build, test, and wrap-up

- [ ] 7.1 `xcodegen generate` (resource dir + any new app/test sources); `cd XttyCore && swift build && swift test` green; `xcodebuild -project xtty.xcodeproj -scheme xtty -destination 'platform=macOS' build` and `test` green.
- [ ] 7.2 Tick this `tasks.md`, refresh **Current status** in `AGENTS.md`, and advance Phase 4 (P4a done / P4b deferred) in `research/04-design/02-milestones.md` — including re-cutting P4's "Done when" to the data-model + cwd value (jump/select/marks are P4b).
