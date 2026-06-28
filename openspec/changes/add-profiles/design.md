## Context

`add-profiles` is the second half of **P3** (the first, `add-quick-terminal`, is archived). P3a shipped the launch path this builds on: `TerminalWindowController` → `PaneController.init(config:registry:frame:)` → `ShellResolver.resolve()` + `TerminalConfigurator.apply(config:)` + `view.startProcess(…)`, with a view-free pane model (`Pane` = `PaneID` + `TerminalSession`) in a shared `SessionRegistry`. Config today is a **flat** `key = value` file: `XttyConfigLoader.parse` → `[String:String]` consumed by three resolvers (`XttyConfigLoader.resolve` → `XttyConfig`, `KeybindResolver`, `HotKeyResolver`).

Profiles turn that single config into **named bundles** (appearance + launch), selectable per tab/window/split. All the durable explore + research decisions are in **`research/03-analysis/p3b-shell-ux-decisions.md`** (Profiles section + "Command execution model"); this design is the implementation-facing distillation.

Two hard facts shape the design, both verified against the SwiftTerm checkout (`XttyCore/.build/checkouts/SwiftTerm`):
- The app compiles the **forkpty** path (`LocalProcess.swift` `#if false //canImport(Subprocess)`), which ends in **`execve`** (`Pty.swift`) — **no PATH search**.
- Our seed environment deliberately **omits PATH** (the login shell rebuilds it); `startProcess(…, currentDirectory:)` is honored (`chdir` before exec).

## Goals / Non-Goals

**Goals:**
- Named profiles in the existing config file with **zero migration** — a flat config resolves byte-for-byte as today.
- A profile carries **appearance** (inherits base) + **launch** (`command`/`cwd`/`env`).
- A `command` profile resolves bare names against the user's **real PATH + dotfiles** (`ssh box`, `claude` just work).
- Selection: `default-profile`, a "New Tab with Profile ▸" menu, split-inherits-profile.
- Keep the engine seam pure: all parsing/resolution lives in `XttyCore`, unit-tested with `swift test`; only the AppKit wiring is in the app target.
- Fail-soft + read-once (the P2 posture).

**Non-Goals:**
- Hot-reload / a settings GUI (read-once stays; relaunch to apply).
- Multi-level inheritance (`inherit = <other-profile>`) — base ⊕ profile only (future option).
- Per-profile keybindings or quick-terminal hotkeys (those stay global/base).
- A `quick-terminal-profile` for the quake (deferred; quake uses base appearance).
- OSC 7 cwd / file:line matching (P4).

## Decisions

### D1 — Profiles live in `terminal-configuration`, not a new capability or file
Profiles are sectioned config, so they extend the config capability rather than introduce a new one. **Base** = the lines before the first header (== today's flat config); `[profile "name"]` starts a named block. *Alternative rejected:* separate per-profile files / a `config-file` include model (Ghostty's approach) — heavier, and a single file keeps "read once at launch" trivial.

### D2 — A new case-preserving `parseSections`, with the base dict feeding the existing resolvers unchanged
`parseSections(text) -> (base: [String:String], profiles: [(name, [String:String])])`. The **base** dict is passed to the existing `XttyConfigLoader.resolve`, `KeybindResolver`, and `HotKeyResolver` **unchanged** — so a header-less file behaves exactly as today (backward-compat is structural, and a unit test asserts `flat == base`). Keybindings + quick-terminal keys are **base-only** (global); they are ignored inside profile blocks.

**Case preservation is mandatory:** today's `parse` lowercases every key, which would corrupt `env-EDITOR` → `env-editor` (env-var names are case-sensitive). `parseSections` keeps **original-case** keys; matching lowercases only the *known* keys, and the `<NAME>` in `env-<NAME>` is taken verbatim. *Alternative rejected:* reuse `parse` per section — silently breaks env var casing.

### D3 — Models: `LaunchOverride` / `XttyProfile` / `XttyConfigSet`; inheritance via `resolve(from:base:)`
```
LaunchOverride { command: String?; cwd: String?; env: [String:String] }
XttyProfile    { name: String; config: XttyConfig; launch: LaunchOverride }
XttyConfigSet  { base: XttyProfile; profiles: [String: XttyProfile]; defaultProfileName: String? }
```
Inheritance reuses the existing per-key validation: refactor `XttyConfigLoader.resolve` to `resolve(from:base:warn:)` (default `base = .default`, so existing callers are unchanged); a profile's appearance = `resolve(from: profilePairs, base: baseConfig)`. A new set-resolver assembles the `XttyConfigSet`. All pure/`swift test`-able.

### D4 — `command` runs through the user's login + interactive shell (the centerpiece)
`command = X` launches **`<login shell> -l -i -c '<X verbatim>'`**, passing `X` as a *single* `-c` argument.

- **Why not exec-style argv (the earlier call):** `execve` does no PATH search and the seed env has no PATH, so `command = ssh box` / `claude` would fail ENOENT. Empirically (Darwin 25.2.0): `zsh -l -c` sources `/etc/zprofile` (path_helper) + `~/.zprofile` but **not** `~/.zshrc`; `zsh -l -i -c` sources **both** — and `~/.zshrc` is where nvm/pyenv/conda (and many `claude`/npm installs) put PATH. A real pty exists per pane, so `-i` is safe (the "no job control" warning only fires on a tty-less pipe). Peers agree: Ghostty/iTerm2/WezTerm run shells login (Ghostty: login **+ interactive**).
- **Why a single `-c` arg:** xtty does **no tokenizing/escaping** — the shell parses `X` at runtime, so pipes/globs/`~`/env-prefixes work and the quote-grammar question disappears.
- **Exact spec:** `executable = <login shell>`, `args = ["-l","-i","-c", X]`, `execName = "-"+basename`, `currentDirectory = <expanded cwd>`, `environment = seed ⊕ profile env`.
- **Trade-offs accepted:** no argv[0] control; one dormant login shell per *command* pane (rare; exits with the command — negligible vs "lean memory"); `~/.zshrc` side-effects (neofetch/MOTD) print once. *Alternatives:* (A) strict abs-path exec — breaks bare names; (D) self-resolve PATH — needs a shell probe anyway, then reimplements `execvp`. Both rejected for v1. `-l`-only is a documented fallback if `-i` side-effects bite.

### D5 — `cwd`: `ShellLaunchConfig.cwd`, `~`/`$HOME` expansion, missing → warn + fall back
`ShellLaunchConfig` gains `cwd: String?`, threaded to `startProcess(currentDirectory:)`. Expansion handles `~` / `$HOME` only (not full shell expansion); a non-existent dir warns and falls back to the default (nil → shell's default), never failing the launch. Existence is an injected probe (matching `ShellResolver`'s testable style). Composes with D4: SwiftTerm `chdir`s before exec, so both the login shell and the command start in `cwd`.

### D6 — `env`: additive, profile wins, `PATH` off-limits
`env-<NAME> = value` (repeated keys) merge additively onto the seed env; the profile wins on conflict. `env-PATH` warns + is ignored (the login shell owns PATH — and D4 makes this uniform across base/command launches). `env-FOO =` (empty) sets `FOO` to the empty string. Casing comes from D2.

### D7 — Pane identity carries its profile; `AppDelegate` owns the `XttyConfigSet`
`Pane` gains `profileName: String?` (nil = base) for registry identity / the future sidebar. `PaneController.init` takes a resolved **`XttyProfile`** (config + launch + name) instead of a bare `XttyConfig`, and **retains it** so a split can relaunch identically. `AppDelegate` resolves and owns the `XttyConfigSet`; `WindowCoordinator.openNewWindow/openNewTab` gain a `profile:` parameter (default = the set's default). *Alternative rejected:* store only the name + re-look-up the set on split — the base profile has no name to look up, and threading the set everywhere is noisier.

### D8 — Selection UX
New tab/window → `default-profile` (else base). A **dynamic "New Tab with Profile ▸"** submenu is built from the set's profile names (item `representedObject` = name; routed to `AppDelegate`); `XttyMainMenu.build` takes the names. A **split inherits the focused pane's profile** (`splitFocusedPane` reuses the focused `PaneController`'s `XttyProfile`). Per-profile font size rides P2 cleanly: `PaneController.configuredFontSize` = the profile's size, so Cmd-0 resets correctly per pane.

### D9 — The quick terminal uses base appearance + a plain login shell
`QuickTerminalController` reads the **base** profile's appearance only and always launches a plain interactive login shell, **ignoring** any `command`/`cwd` (even base's) — a scratch terminal must not silently become an ssh/profile session. `quick-terminal-profile` stays deferred. (Small `quick-terminal` spec clarification.)

### D10 — `confirm-close` config key (carried over from P3a D5)
Wire the currently-hardcoded `TerminalWindowController.confirmCloseEnabled` to a base-level boolean `confirm-close` (default `true`), parsed with the existing `parseBool`. Closes the breadcrumb the P3a code left.

### D11 — Parsing edge cases (strict-but-recoverable)
- Header grammar `^\[profile\s+"([^"]+)"\]$`; only this defines a profile. A malformed/unquoted header (`[profile work]`, `[profile ""]`) → **loud warning (file+line+text) + skip that section**, keep loading. Don't abort (git) and don't silently accept (the systemd `name=` footgun). Profile names are **case-sensitive** (git/TOML/systemd precedent).
- Duplicate profile name → merge (later keys win) + warn. `default-profile` inside a profile block → ignored (base-only) + warn. Unknown `default-profile = nope` → warn + fall back to base. Unknown section types (future `[keybind]`) → ignored (forward-compat, like unknown keys). Single-level inheritance only.

### D12 — Fail-soft + read-once preserved
Every invalid value/header degrades to a warning + a sane fallback; the app always launches. Config (incl. profiles) is read **once** at launch (relaunch to apply edits).

## Risks / Trade-offs

- **`-i` side-effects** (a `~/.zshrc` that prints, or does `exec tmux`) run before/instead of the command for a `command` profile → at worst cosmetic noise; at extreme, an aggressive `.zshrc exec` shadows the command. Same exposure Ghostty's login+interactive default has. **Mitigation:** documented; `-l`-only fallback available.
- **Non-POSIX login shell** (fish/nushell) may not accept `-l -i -c`. **Mitigation:** the shell's own error surfaces in the pane (fail-soft); the default-shell path (no command) is unaffected. Most users are zsh/bash.
- **`GLOBAL_RCS` disabled / PATH only in `.zshrc`** edge configs can still miss PATH. **Mitigation:** `-l -i` covers the overwhelming common case; out-of-scope to chase exotic setups.
- **Scope/spec churn** is the largest in P3 (5 capabilities touched). **Mitigation:** tasks grouped (core parse → core model → core launch → app wiring → harness/docs); core is pure and lands behind tests before app wiring.
- **`env-<NAME>` casing regression** if any code path reuses the lowercasing `parse`. **Mitigation:** a unit test asserts `env-EDITOR` survives as `EDITOR`.

## Open Questions

None blocking. Deferred by decision: multi-level inheritance (`inherit =`), a `quick-terminal-profile`, and whether to later cache a probed PATH and `execvp` ourselves (an optimization over the per-command shell — only if the dormant shell ever proves costly).
