## Why

P4 is the **keystone milestone**: the first time xtty reads *meaning* from the byte stream instead of only rendering it. Capturing the shell's working directory (OSC 7) and command boundaries (OSC 133) is the foundation every differentiator depends on — the P5 session-progress sidebar, the P6 file/diff view, and the deferred P3b file:line error-matching all need this data. This change ships **P4a**: the capture + data model, achievable entirely on SwiftTerm's public API. The spatial operations that need a SwiftTerm fork (jump-to-prompt, select-a-command's-output, gutter fail-marks) are deliberately carved out as a later **P4b** change. Rationale and source-grounded decisions: `research/03-analysis/p4-semantic-capture-decisions.md`.

## What Changes

- **Auto-inject shell integration for zsh** so the user's shell emits OSC 7 + OSC 133 with zero dotfile edits: redirect `ZDOTDIR` to a bundled integration dir whose bootstrap restores the user's original `ZDOTDIR` and sources their real config (the Ghostty/Kitty mechanism). Forward a pre-existing `ZDOTDIR` as `XTTY_ORIG_ZDOTDIR`; skip injection for profile `command` one-shots; ship a documented manual-source fallback. (zsh only in v1; bash/fish deferred.)
- **Capture the live working directory from OSC 7**: fill the existing no-op `hostCurrentDirectoryUpdate` delegate, decode the raw URL (`file://` percent-decoded vs `kitty-shell-cwd://` raw; host vs local-hostname to flag remote/ssh), and store a per-session **live cwd** distinct from the static launch cwd.
- **New splits/tabs open in the focused pane's live cwd** (falling back to the profile/home cwd), replacing today's static-profile-cwd inheritance.
- **Capture command blocks from OSC 133**: register a handler on the engine (`registerOscHandler(code: 133)`), parse actions `A`/`B`/`C`/`D` (+ `P`; ignore unknown) with `D`'s bare positional exit code and `cmdline`/`cmdline_url` text, and drive a view-free block-lifecycle state machine producing a per-session block list (command, exit code, cwd, start/end timestamps, state: running/succeeded/failed).
- **Suppress block-building on the alternate screen** (vim/htop/less never become blocks): detect via the public `isCurrentBufferAlternate` + an `open bufferActivated` override. Treat OSC 133 as best-effort — absent marks (tmux / ssh-without-integration) degrade to plain output, never gating rendering.
- **DEBUG verification dump** exposes the live cwd, alt-screen state, and the block list so the XCUITest harness can assert capture (the custom-drawn view exposes nothing to accessibility).
- **Non-goals (deferred to P4b):** jump-to-prompt, select-a-command's-output, gutter fail-marks — all require stable absolute row anchors (internal `yBase`/`linesTop`) and the internal `SelectionService`, i.e. a SwiftTerm fork. Also deferred: OSC 633 (VSCode), bash/fish injection, the click-to-open half of file:line matching.

## Capabilities

### New Capabilities
- `shell-integration`: auto-injection of xtty's shell-integration hooks (zsh `ZDOTDIR` redirection preserving the user's dotfiles, original-`ZDOTDIR` forwarding, skip for `command` one-shots, manual fallback) so the shell emits OSC 7 + OSC 133.
- `terminal-semantics`: OSC 133 command-block capture — handler registration, the A/B/C/D parser, the view-free block-lifecycle state machine, alt-screen gating, and the per-session block data model (command/exit/cwd/timestamps/state).

### Modified Capabilities
- `terminal-session`: captures and exposes a per-session **live working directory** from OSC 7 (decoded), separate from the static launch cwd.
- `terminal-multiplexing`: a new split/tab starts in the focused pane's **live** cwd (fallback to the inherited profile/home cwd) rather than the static profile cwd.
- `verification-harness`: the DEBUG state dump adds the live cwd, alt-screen flag, and the captured block list (with exit codes) for e2e assertions.

## Impact

- **New code (`XttyCore`, view-free + unit-tested):** an OSC 133 parser, a block-lifecycle state machine + `Block`/`BlockRegistry` model on `TerminalSession`, OSC 7 URL decoding, and `ShellResolver` injection of `ZDOTDIR`/`XTTY_ORIG_ZDOTDIR`.
- **App layer:** wire the `hostCurrentDirectoryUpdate` delegate (`PaneController`), register the OSC 133 handler on the engine, override `bufferActivated` on `XttyTerminalView`, make `splitFocusedPane` read the live cwd, and extend the DEBUG dump.
- **App bundle:** ship a `shell-integration/zsh` resource dir (bootstrap `.zshenv` + hook installer emitting OSC 133 A/B/C/D + OSC 7); requires `xcodegen` to bundle the resources.
- **Dependencies:** none added — uses SwiftTerm's public `registerOscHandler`, `isCurrentBufferAlternate`, `open bufferActivated`, and the existing OSC 7 delegate. No SwiftTerm fork (that's P4b).
- **Concurrency:** OSC handlers + `bufferActivated` run on the engine feed path (`nonisolated` + `MainActor.assumeIsolated`); block-model mutation must be confined to that context.
- **Risks:** `linesTop=0` on `clear` has no callback; tmux/ssh degrade to no-blocks; p10k instant-prompt edge cases — all documented in the design.
