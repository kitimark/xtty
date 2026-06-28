## Why

Today every xtty pane launches the same login shell with the same appearance. Real workflows want *named setting bundles* — "work" with a light theme starting in `~/src`, "ssh-box" that drops straight into a remote host, an agent profile that runs `claude` — selectable per tab/window. This is the second half of P3 (the first, `add-quick-terminal`, shipped). It is buildable now that P3a's launch path (`PaneController` → `ShellResolver` → `TerminalConfigurator`) and pane model exist, and it directly serves the product value *"be a great host for agent CLIs"* (`command = claude` should just work).

## What Changes

- **Profiles in the existing config file.** Lines before the first header remain the **base** profile (today's flat config); `[profile "name"]` blocks add named bundles. A flat P2 config has no headers → it is entirely base → resolves **byte-for-byte as today** (migration-free).
- **Each profile carries appearance + launch.** Appearance keys (font/theme/scrollback/option-as-meta) inherit base ⊕ overrides (single level). New **launch** keys: `command`, `cwd`, repeated `env-<NAME>`. A `default-profile` key (base-only) selects what new tabs/windows use.
- **`command` runs through the user's login + interactive shell** — `<login shell> -l -i -c '<command string>'` — so bare names (`ssh box`, `claude`) resolve against the user's real PATH and dotfiles, and pipes/globs/`~` work. (xtty execs via `execve` with no PATH search and a PATH-less seed env, so a direct exec would break bare commands — see design.) `cwd` is honored via SwiftTerm's `currentDirectory:` (`chdir` before exec); `env-<NAME>` is additive (profile wins; `PATH` off-limits — the login shell builds it).
- **Selection.** New tab/window launches `default-profile` (else base); a **"New Tab with Profile ▸"** menu lists profiles; a **split inherits the focused pane's profile**. A pane remembers the profile it launched with (registry identity), so per-profile font size resets correctly (Cmd-0).
- **The quick terminal uses base appearance + a plain login shell**, ignoring `command`/`cwd` (a scratch terminal must not silently become an ssh/profile session).
- **`confirm-close` config key** (carried over from P3a design D5): wire the currently-hardcoded "confirm closing a pane with a running job" to a base-level boolean.
- **Fail-soft throughout** (P2 posture): malformed `[profile …]` headers warn + skip while the rest of the file loads; an unknown `default-profile` warns + falls back to base; an `env-PATH` warns + is ignored. **Read-once** preserved (relaunch to pick up edits).

## Capabilities

### New Capabilities
<!-- none — profiles is added as a requirement within terminal-configuration, where the config schema + discovery already live -->

### Modified Capabilities
- `terminal-configuration`: sectioned discovery/parsing (base + `[profile "name"]`, case-preserving); schema additions (`command`/`cwd`/`env-<NAME>`/`default-profile`/`confirm-close`); the view-free component now yields a profile **set** (base + named profiles + default) instead of a single config; per-profile application; **ADDED** a "Profiles" requirement (named bundles, inheritance, backward-compat).
- `terminal-session`: profile-driven launch — the login-shell `command` wrap, `cwd`, additive `env`, and the login-vs-command rule.
- `terminal-multiplexing`: a pane carries its launching profile as identity; a split inherits the focused pane's profile; a new tab/window launches with a chosen or default profile.
- `quick-terminal`: the quake reads the **base** profile's appearance and always launches a plain login shell, ignoring launch overrides.
- `verification-harness`: the DEBUG state-dump inventory adds per-pane `profileName` + `cwd`; an e2e test asserts a profile-launched tab reflects its profile.

## Impact

- **`XttyCore` (view-free, unit-tested):** new sectioned parser (`parseSections`, case-preserving); `LaunchOverride`, `XttyProfile`, `XttyConfigSet` models; `XttyConfigLoader.resolve(from:base:)` for inheritance + a profile-set resolver; `ShellResolver` gains `cwd` on `ShellLaunchConfig` and an override-aware resolve (the login-shell command wrap, `~`/`$HOME` cwd expansion, env merge); `Pane` gains `profileName`.
- **App target:** `PaneController.init` takes a resolved profile; `AppDelegate` owns the `XttyConfigSet` and routes new-tab/window/split to a profile; a dynamic "New Tab with Profile ▸" menu; `QuickTerminalController` uses base appearance; `confirm-close` read from config.
- **Harness:** state-dump fields + one XCUITest; `config.example` gains a Profiles section.
- **No new dependencies.** SwiftTerm already supports `currentDirectory:`. No breaking changes — existing flat configs are unaffected.
