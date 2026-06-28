## Context

P4 is the keystone milestone (`research/04-design/02-milestones.md`). The full decision record — four open questions researched against the SwiftTerm checkout and Ghostty/Kitty emit-side source, with the two gating claims adversarially verified — lives in **`research/03-analysis/p4-semantic-capture-decisions.md`**. This design distills the *what/how*; that note holds the *why* and the file:line evidence.

Current state this builds on:
- The engine seam is in place: `XttyCore.TerminalSession` holds an observe-only `SwiftTerm.Terminal`; `Pane`/`SessionRegistry` model the tree; `PaneController` (app layer) is the `LocalProcessTerminalViewDelegate`.
- `hostCurrentDirectoryUpdate(directory:)` already exists as a **no-op stub** (`PaneController.swift:127`).
- `ShellResolver` (pure, `XttyCore`) builds the launch config and **replaces the child env wholesale** from a small seed whitelist.
- Splits inherit the focused pane's `XttyProfile` (with a *static* `profile.launch.cwd`).
- The DEBUG state dump already emits `cwd` (the static launch cwd), `profileName`, `theme`, `scrollbackCap`.

## Goals / Non-Goals

**Goals:**
- Capture the shell's **live cwd** (OSC 7) per session; new splits/tabs start there.
- Capture **command blocks** (OSC 133): command text, exit code, cwd, start/end times, state.
- **Auto-inject** zsh integration so this works out-of-the-box without dotfile edits.
- **Suppress** block-building on the alternate screen; degrade gracefully when marks are absent.
- Keep all logic **view-free in `XttyCore`** (unit-tested), with a DEBUG dump for e2e.
- **Add no dependencies and no SwiftTerm fork** — public API only.

**Non-Goals (deferred to P4b, behind a SwiftTerm fork):**
- jump-to-prompt, select-a-command's-output, gutter fail-marks (need internal `yBase`/`linesTop` for stable anchors + the internal `SelectionService`).
- bash/fish auto-injection; OSC 633 (VSCode); the click-to-open half of file:line matching.

## Decisions

### D1 — Two consumers, one emitter, on public API
- **OSC 7 → fill the existing delegate, do NOT register a custom handler.** SwiftTerm's built-in OSC 7 path stores the cwd and fires `hostCurrentDirectoryUpdate`, gated on `isProcessTrusted` (already `true`). A custom handler would bypass that and stop populating `hostCurrentDirectory`.
- **OSC 133 → register `engine.registerOscHandler(code: 133, …)`.** SwiftTerm has no built-in 133; user handlers run first; the handler receives bytes *after* the first `;` (e.g. `D;1;aid=foo`).
- *Alternative rejected:* a custom OSC 7 handler for symmetry — loses the trust gate and the engine's stored `hostCurrentDirectory`.

### D2 — zsh injection via `ZDOTDIR` redirection (auto, from v1)
Set `ZDOTDIR=<bundle>/shell-integration/zsh` in the child env. The bundled `.zshenv` restores the user's original `ZDOTDIR` (forwarded as `XTTY_ORIG_ZDOTDIR`), sources their real `.zshenv`, then (interactive only) autoloads + runs the hook installer and `unfunction`s it — so `.zprofile`/`.zshrc`/`.zlogin` still load from the user's real dir; only `.zshenv` is intercepted. Hooks use `add-zsh-hook precmd/preexec` (additive → coexists with p10k/starship) to emit OSC 133 A/B/C/D + OSC 7.
- **Why:** env-var-only → fully compatible with our forkpty/`execve`/no-PATH launch and the `-zsh` login `execName`; the smallest diff; exactly what Ghostty/Kitty do.
- **Gotcha (must honor):** `ShellResolver` replaces env wholesale and would drop a pre-existing `ZDOTDIR` — read `environment["ZDOTDIR"]` **before** seeding and forward it. Thread the **bundle path in as an injected parameter** (keeps `ShellResolver` pure/testable). **Skip injection** when a profile sets `command` (one-shot). Ship a **manual fallback** (source the installer) for the `/etc/zshenv`-override / opt-out cases.
- *Alternatives rejected:* manual-snippet-first (the sidebar would silently do nothing until users edit dotfiles); bash/fish now (more mechanisms — POSIX-mode+`ENV`+`bash-preexec`, `XDG_DATA_DIRS` — deferred until targeted; macOS `/bin/bash` 3.2 can't auto-inject at all).

### D3 — Block lifecycle: a view-free state machine, public alt-screen gating
- A pure `XttyCore` state machine `{idle, atPrompt, runningCommand}` driven by parsed marks, producing a `BlockRegistry` per `TerminalSession`.
- **Rules:** open a block only on `C`; close only on the **first `D` after a `C`** (kitty emits multiple), recording the exit code; on `A`/`P` (k≠s) with no intervening `C`, discard the prompt-only region (empty-Enter / Ctrl-C → no block); `D` with no open `C` is a defensive no-op; `k=s`/`P` continuation marks belong to the same command.
- **Alt-screen gating (public, no fork):** override `open func bufferActivated(source:)` on `XttyTerminalView` (`super` first, then read `source.isCurrentBufferAlternate` to derive enter/exit); while alternate, suppress block create/close; if alt is entered mid-command, mark it full-screen/opaque and finalize on the `D` after returning to primary. The public `Terminal.isCurrentBufferAlternate` is the truth source + polling fallback. Verified: `bufferActivated` is a `TerminalDelegate` requirement satisfied by an `open` method, so the engine's internal `tdel` dispatches to our subclass override (iOS ships the same override as precedent).
- *Alternatives rejected:* a Warp-style block graph (high-risk, brittle under tmux/ssh); forking for a view-delegate callback (unnecessary — the `open` override already gives a push hook with a public polling fallback).

### D4 — Data model stores durable fields, never fragile coordinates
`Block { command: String?, exitCode: Int32?, cwd: String?, startedAt, endedAt, state }` where `state ∈ {running, succeeded, failed, opaque}`. All fields come from the OSC byte stream; output **text** is captured **eagerly at `D`** via the public `getText(start:end:)` (public `Position`/`BufferLine`). **No absolute row anchor is persisted** — it's uncomputable from public API (internal `yBase`/`linesTop`), and the bottom-anchored `y + getTopVisibleRow()` proxy is correct only when scrolled-to-bottom and rots on trim. (Stable anchors + selection are P4b's fork.)

### D5 — OSC 7 decode + live cwd vs static launch cwd
SwiftTerm hands us the **raw** URL. Decode: strip `file://` *or* `kitty-shell-cwd://`; authority up to first `/` = host; rest = path; **percent-decode the path only for `file://`** (leave `kitty-shell-cwd://` raw); compare host to local hostname to **flag remote/ssh** (don't treat as a local path). Store a per-session **`currentDirectory`** (live) distinct from `launchConfig.cwd` (static). `splitFocusedPane` reads the focused pane's live cwd → fallback to inherited profile cwd → home.

### D6 — OSC 133 parser (pure, tolerant)
`action = byte[0]` ∈ `{A,B,C,D,P}` (ignore unknown like kitty `133;k`); if `byte[1]==';'`, split the remainder on `;`, each token on the **first** `=`. For `D`, the first token is a **bare positional `Int32`** exit code (bare `133;D` = none). `cmdline` (shell-quoted) / `cmdline_url` (percent) on `C` carry command text — decode with **raw fallback**. `k=s` = continuation. Ignore `cl`/`redraw`/`click_events` (cosmetics). Unit-tested against the exact byte forms emitted by the shipped script (and the Ghostty/Kitty corpus).

### D7 — Verification (DEBUG dump + e2e)
The custom-drawn view exposes nothing to accessibility, so extend the existing JSON state dump with `currentDirectory` (live), `isAlternateScreen`, `lastSemanticAction`, and a `blocks` array (`command`, `exitCode`, `state`). XCUITests drive **real zsh with injection** to assert: blocks form with captured exit codes; cwd updates on `cd`; `vim`/`tput smcup` suppresses blocks.

## Risks / Trade-offs

- **[Concurrency — Swift 6]** OSC handlers + `bufferActivated` fire on the engine feed path; existing delegate methods are `nonisolated` with `MainActor.assumeIsolated` hops. → Confine block-model mutation to that context; snapshot `buffer` reads there; don't hand the model across actors unguarded.
- **[`linesTop=0` on clear/reset]** `clear`/CSI 3 J resets the trim counter with no callback. → P4a stores no anchors, so unaffected; note it as a hard prerequisite for P4b's anchoring.
- **[tmux/ssh degradation]** No DCS-passthrough unwrap in SwiftTerm; marks may never arrive. → Best-effort by design: no marks → plain output, no blocks; never gate rendering on marks. Document as accepted.
- **[`bufferActivated` stays `open`]** The push hook depends on SwiftTerm not sealing the method (it doesn't today; its own subclassing relies on it). → Harness test asserts the override fired; poll `isCurrentBufferAlternate` as the fully-public fallback.
- **[Injection edge cases]** A system `/etc/zshenv` that overrides `ZDOTDIR` defeats auto-redirect; p10k instant-prompt emits early output. → Manual-source fallback documented; validate p10k empirically (not a blocker).
- **[Bundle resources]** Shipping the `shell-integration/zsh` dir requires `xcodegen` to package the resource and a runtime `Bundle` lookup. → Add to `project.yml`; fail-soft if the resource is missing (no injection → plain shell, logged).

## Migration Plan

Additive, no user-facing migration. Order: (1) OSC 7 cwd (smallest, half-wired) → (2) zsh injection (bundle + `ShellResolver`) → (3) OSC 133 parser → (4) alt-screen override → (5) block lifecycle machine → (6) DEBUG dump + e2e. Each step is independently testable. Rollback = revert; no persisted state. Re-run `xcodegen generate` after adding the resource dir and any new source files to the app/test targets.

## Open Questions

- Bundle layout for the integration scripts (top-level `Resources/shell-integration/zsh` vs an `XttyCore` resource) — resolve at apply time against `xcodegen`'s resource handling; lean app-bundle `Resources`.
- Whether `D` can fire while the user is scrolled up (affects eager text capture timing) — validate empirically during apply; eager capture at `D` reads the engine buffer directly, independent of `yDisp`, so expected to be fine.
