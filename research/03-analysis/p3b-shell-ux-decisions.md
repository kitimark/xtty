# P3b shell-UX extras — explore-phase decisions (Quick-Terminal + Profiles)

> **Provenance:** Drafted 2026-06-28 during an `/opsx:explore` session for **P3 native-shell-UX**, after the P3a spine was captured + committed (`add-tabs-and-splits`, commit `34bd409`) and the deferred P3b subsystems were drilled. These are **explore-phase, pre-implementation** decisions: P3b is **gated on P3a landing** and its detailed design/specs will be sharper once P3a's real types (`PaneController`, `SessionRegistry`, the config→pane launch path) exist. Grounded in reads of `XttyCore` (`ShellResolver`, `XttyConfigLoader`, `XttyConfig`) and the SwiftTerm checkout. No code written.

> _Topic scope:_ Lock the decisions for the **deferred half of P3** so they aren't lost between now and implementation. P3a (tabs/splits/windows/URL links) is specced in `openspec/changes/add-tabs-and-splits/`; this note covers what was carved out of it. Background: [milestones P3](../04-design/02-milestones.md), [requirements N3 + M6](xtty-requirements.md).

> **Update 2026-06-28 (research) —** Now that **`add-quick-terminal` has shipped** and `add-profiles` is next, the four remaining profiles open questions were researched (peer terminals, macOS shell startup/PATH, INI grammar) and resolved below. The biggest shift: the **`command` execution model reverses to "run through the user's login + interactive shell"** — the old "exec-style argv" call was made before confirming SwiftTerm execs via **`execve` with no PATH search** (see _Command execution model_). Also resolved: unquoted headers are **strict-but-recoverable**, the quake uses **base appearance + a plain login shell**, and the **base section carries `cwd`/`env`**. Verified via a research + adversarial-verify workflow plus direct web checks.

## The re-cut: what P3b actually is

P3's milestone bundles tabs, splits, links, **Quick-Terminal, profiles, and file:line error-matching**. Sorting the deferred features by their real dependencies changed the scope:

| Feature | Depends on | Placement |
|---|---|---|
| Quick-Terminal | P3a (one persistent pane) only | ✅ **P3b** |
| Profiles | P2 config + `ShellResolver` (done) + P3a launch path | ✅ **P3b** |
| file:line error-matching | grid read (done) + **cwd = OSC 7 = P4** for relative paths | ⚠️ **moved to P4** |

- ✅ **P3b = Quick-Terminal + Profiles.** Both are fully buildable once P3a exists.
- ⚠️ **file:line error-matching → P4.** Its core value (clicking `src/foo.swift:42`) needs the pane's cwd, which doesn't exist until P4's OSC 7 capture. The `open-editor-command` config key + matcher land with P4, not here. (URL/OSC-8 links already shipped in P3a; SwiftTerm's implicit matcher is a private, URL-only regex, so file:line is xtty-owned work regardless.)
- ℹ️ **Structure: two tight changes, not one.** Lean toward `add-quick-terminal` + `add-profiles` (independent capabilities; profiles' config-spec churn is large enough to deserve its own review) over a single `add-shell-ux-extras`. One bundled change is acceptable if sequenced as task groups.

## Sequence

```
now:        this note (lock decisions)
then:       /opsx:apply add-tabs-and-splits        (build P3a)
after P3a:  /opsx:propose add-profiles + add-quick-terminal   (full artifacts, referencing this note)
P4:         file:line error-matching rides OSC 7 cwd
```

---

## Quick-Terminal (the "quake" dropdown)

> **✅ Implemented 2026-06-28** as `add-quick-terminal`. Reconciled against the real P3a types during apply: `HotKeySpec` **reuses `ModifierSet`** (mapped to a Carbon mask in the app-layer `GlobalHotKey`, rather than storing a raw mask in core); the parser shares a `ChordTokenizing` helper with `KeybindParser`; accessory exclusion is a **private `SessionRegistry`** in `QuickTerminalController` (no `PaneController` change). v1 ships `quick-terminal` + `quick-terminal-hotkey` only; slide animation deferred. 69 `XttyCore` unit + 13 XCUITests green.

### Mechanism
- ✅ **Global hotkey via Carbon `RegisterEventHotKey`** — no Accessibility permission prompt (unlike `NSEvent.addGlobalMonitorForEvents`, which also can't swallow the key, or `CGEventTap`, which needs the prompt). Registers the combo exclusively; fires when xtty is unfocused.
- ✅ **Hand-rolled ~40-line shim, not the `soffes/HotKey` SPM dep.** The surface is tiny and keeps the dependency list lean (a product value); the reuse-bias is aimed at the VT parser, not a trivial Carbon wrapper. (Reasonable to revisit if touching Carbon is unappealing.)
- ✅ **Panel:** `NSPanel` with `styleMask = [.nonactivatingPanel, .borderless]` (showing it doesn't activate xtty / deactivate the user's app, yet it can become key to receive typing; on hide, focus returns automatically), `level = .mainMenu + 1`, `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]`.

### Behavior decisions
- ✅ **Lifecycle:** lazily create the panel + a `PaneController` + start the shell on first summon; thereafter the **shell persists** across hide/show — toggling only orders the panel in/out.
- ✅ **Which screen:** the **screen under the mouse** (quake convention), with **summon-to-active** — if visible on a different screen than the active one, re-show it there; if on the same screen, hide. (Diverges from the "main window on the built-in display" rule, which governs the *main* window, not this panel.)
- ✅ **Positioning:** recompute the frame **from the target screen on every show** (never cache — survives resolution change / monitor unplug). Slide in from off-screen (top default).
- ✅ **Single pane in v1** (scratch terminal) — reuses `PaneController`, skips the split tree.
- ✅ **Excluded from the `SessionRegistry` / P5 sidebar and from "last window" accounting** — a special, accessory session.
- ✅ **Termination stance (i): accessory.** The app quits with the last *main* window even if the quake is enabled; the quake shell dies with it. A *hidden* panel must never keep the app alive or block quit. (Stance (ii) — persistent background/status-bar app that survives with no main windows — is a bigger identity shift; noted as a **future option**, not P3b.)

### The pure, testable seam
- ✅ **`HotKeyParser` lives in `XttyCore`** (pure, `swift test`-able): string → `HotKeySpec { virtualKeyCode, carbonModifiers, display }`. Only the actual `RegisterEventHotKey` binding is app-layer/untestable. Mirrors the existing `XttyConfigLoader` (pure) vs `TerminalConfigurator` (AppKit) split.
- ✅ **Fixed name → `kVK_*` table** (~60 entries: letters, digits, F-keys, punctuation, arrows, space, escape, tab, return), **not** layout-aware char translation (`UCKeyTranslate`). keyCodes are positional virtual codes (e.g. `kVK_ANSI_Grave = 0x32`), not characters.
- ✅ **Carbon modifiers ≠ Cocoa** — translate to `cmdKey/shiftKey/optionKey/controlKey`. `fn` is **not** supportable (not a standard Carbon modifier) → reject.
- ✅ **Validation:** require **≥1 modifier + exactly 1 non-modifier key** (a bare global key would hijack the system).
- ✅ **Fail-soft** (consistent with the config posture): an unparseable hotkey **or** a `RegisterEventHotKey` returning non-`noErr` (e.g. a system-reserved combo like ⌘Space) → warn + disable the feature, never crash. We can't enumerate reserved combos, so we handle registration failure rather than predict it.
- ✅ **Handler trampoline:** the `@convention(c)` handler bounces through an `Unmanaged` `self` pointer passed as userData.

### Config + harness
- ✅ **Ship a subset in v1:** `quick-terminal` (on/off) + `quick-terminal-hotkey`. Defer `-position` / `-size` / `-screen` / `-autohide` / `-profile` (the last ties to Profiles) to defaults, land incrementally.
- ✅ **Harness:** a global hotkey can't be driven by XCUITest → expose a **DEBUG "Toggle Quick Terminal" action that calls the identical `toggle()`** the hotkey does, so CI exercises the real path minus the keypress. Assert: panel appears, accepts typed text (via the grid dump), hides, and is **excluded from the registry inventory**.

---

## Profiles (named setting bundles)

### Format
- ✅ **INI-style sections in the same config file.** Lines before the first header = the **base** profile (== today's flat P2 config); `[profile "name"]` starts a named block.
- ✅ **Backward-compatible by construction:** a P2 flat config has no headers → it's entirely the base profile → resolves **byte-for-byte as today**. Migration-free (a spec scenario).

```ini
font-family = JetBrains Mono     # base profile
theme = dark
default-profile = work           # global; honored ONLY in base

[profile "work"]
theme   = light
command = /bin/zsh               # launch override
cwd     = ~/src/work
env-EDITOR = nvim                # repeated env-<NAME> keys → env vars

[profile "ssh-box"]
command = ssh box                # runs via login+interactive shell (inherits your PATH)
```

### Parsing edge cases (decisions)
- ✅ Header grammar `^\[profile\s+"([^"]+)"\]$`.
- ✅ Duplicate profile name → **merge** (later keys win) + warn.
- ✅ Empty name `[profile ""]` → warn + ignore.
- ✅ **Unquoted/malformed header** `[profile work]` → **strict-but-recoverable** (resolved 2026-06-28): only `[profile "name"]` defines a profile; a malformed header emits a loud warning (file + line + offending text, _"did you mean `[profile \"name\"]`?"_) and is **skipped**, while the rest of the file still loads — don't abort (git's behavior) and don't silently accept (the systemd `name=`/`Name=` footgun). Rationale: a bare token can't represent a name with spaces, so leniency silently invents a name that disagrees with `default-profile`. Profile names are **case-sensitive** (matches git/TOML/systemd).
- ✅ **`parseSections` preserves key case.** Today's flat `parse` lowercases every key, which would corrupt `env-EDITOR` → `env-editor` (env-var names are case-sensitive). The sectioned parser keeps **original-case** keys and lowercases only the *known* keys for matching, taking the `<NAME>` in `env-<NAME>` verbatim. `env-FOO =` (empty) → set `FOO` to the empty string.
- ✅ `default-profile` inside a profile section → ignored (base-only) + warn.
- ✅ Unknown section type (future `[keybind]`) → ignored, doesn't break the parse (forward-compat, like unknown keys).
- ✅ Unknown `default-profile = nope` → warn + fall back to base.

### Resolution & model
- ✅ A profile splits into **appearance** (→ `XttyConfig`, as today) and **launch** (→ new `LaunchOverride`):

```
XttyProfile   { name; config: XttyConfig; launch: LaunchOverride }
LaunchOverride{ command: String?; cwd: String?; env: [String:String] }
XttyConfigSet { base: XttyProfile; profiles: [name: XttyProfile]; defaultProfileName: String? }

profile.config = resolve(base ⊕ overrides)          # inheritance
pane launch    = (command ? loginShell -l -i -c '<command>' : ShellResolver.resolve())
                 + cwd → startProcess(currentDirectory:)   # SwiftTerm already accepts it
                 + merge env into the seed env
                 + TerminalConfigurator.apply(profile.config)
```

- ✅ **`ShellLaunchConfig` gains `cwd: String?`** threaded to SwiftTerm's `startProcess(currentDirectory:)` (already supported). `ShellResolver` extends with `resolve(override:environment:)` — all pure/testable, matching its existing injected-probe style.
- ✅ **`command` runs through the user's login + interactive shell** — `<login shell> -l -i -c '<command string, verbatim>'` — **not exec-style argv, and not `/bin/sh -c`** (revised 2026-06-28; see _Command execution model_ below). The string is passed as a **single `-c` argument**, so xtty does **no tokenizing/escaping** (the shell parses it at runtime) — pipes/globs/`~`/env-prefixes work and the old quote-grammar question disappears.
- ✅ **Login-vs-command distinction:** *both* go through a login + interactive shell, so PATH + dotfiles are **identical**; the only difference is whether a `-c` command runs. base/default = interactive login shell (`-zsh`); a `command` profile = `<login shell> -l -i -c '<command>'` (the command inherits the same PATH/dotfile env; the `-c` shell then exits with the command's status, closing the pane).
- ✅ **env merge is additive**, profile winning on conflict, **but `PATH` is off-limits** (warn + ignore `env-PATH`; the login shell builds PATH). Now *uniformly* correct: because command profiles also route through the login shell, the rule holds for every launch. Syntax: repeated `env-<NAME> = value` keys (no delimiter ambiguity).
- ✅ **cwd expansion:** `~` / `$HOME` only; a missing dir → warn + fall back to default (don't fail the launch). Composes with the command wrap: SwiftTerm `chdir`s before exec, so the login shell **and** the command start in `cwd`.
- ✅ **Single-level inheritance** (resolved 2026-06-28): a profile = base ⊕ its own overrides; no profile-inherits-profile in v1 (`inherit = <profile>` noted as a future option).
- ✅ **The base section carries launch overrides too** (resolved 2026-06-28): `cwd`/`env` before the first header apply to *all* default launches (always start in `~/projects`; always set `EDITOR`). A `command` in base is **legal but discouraged** — it overrides the default shell globally (still via the login-shell wrap). One rule everywhere: **command present → wrap + run it; absent → plain login shell; `cwd`/`env` always applied.**

### Command execution model (resolved 2026-06-28)

**Decision: route a profile `command` through the user's login + interactive shell** — `<login shell> -l -i -c '<command string>'`, passing the command as a single `-c` argument. This **reverses** the earlier "exec-style argv" call.

**Why it changed.** The app launches children on SwiftTerm's **forkpty** path (`#if false //canImport(Subprocess)` in `LocalProcess.swift`), which ends in **`execve`** (`Pty.swift`) — **no PATH search** — and our seed env **omits PATH** (the login shell rebuilds it). So a bare `command = ssh box` or `command = claude` exec'd directly fails with ENOENT. The exec-style decision predated confirming this.

**Verified shell facts** (empirically tested on macOS, Darwin 25.2.0):
- `zsh -l -c` sources `/etc/zprofile` (path_helper → system + Homebrew base) + `~/.zprofile` but **not** `~/.zshrc`; `zsh -l -i -c` sources **both** — and `~/.zshrc` is where nvm/pyenv/conda (and many `claude`/npm installs) put PATH.
- A real pty exists per pane, so `-i` is **safe** (the "no job control" warning only fires on a tty-less pipe).
- `-c` exits with the command's exit code/signal, so the pane closes correctly when the command ends.

**Peers confirm the direction:** Ghostty runs each shell **login + interactive** on macOS (sources `.zprofile` *and* `.zshrc`); iTerm2 runs even a custom shell as a **login** shell; WezTerm + Terminal.app default to login shells. Ghostty offloads command arg-expansion to `/bin/sh -c`, relying on its *process* PATH — which we can't (our seed env has none), so we use the user's login + interactive shell instead: a stronger form of the same idea.

| approach | `ssh box` | `claude` (rc-only PATH) | pipes/`&&`/`~` | argv[0] | not-found | tokenizer | lingering proc |
|---|---|---|---|---|---|---|---|
| A — strict exec, abs path | ✗ | ✗ | ✗ | ✓ | code 127 | **yes** (+quote grammar) | no |
| **C — `$shell -l -i -c '<str>'`** | ✓ | ✓ | ✓ | ✗ | shell exits 127 | **none** | 1 dormant shell |
| D — self-resolve PATH | ✓ if found | ⚠ needs probe | ✗ | ✓ | our error | yes + PATH probe | no |

**Exact launch spec:**
```
executable = <login shell>           # ShellResolver's resolved path (pw_shell > $SHELL > /bin/zsh)
args       = ["-l", "-i", "-c", "<command string, verbatim>"]
execName   = "-" + basename          # login dash (belt-and-suspenders with -l)
currentDirectory = <expanded cwd>
environment      = seed ⊕ profile env  # PATH off-limits
```
The **one quoting decision**: pass the command as a *single* `-c` argv element — no re-quoting on our side; the shell parses it at runtime. Trade-offs accepted: no argv[0] control, and one dormant login shell per *command* pane (rare; it exits with the command — negligible against "lean memory"). `-l`-only is the conservative fallback if a `.zshrc` that prints (neofetch/MOTD) proves annoying; non-POSIX shells (fish/nushell) usually accept `-l -i -c`, else their own error surfaces in the pane.

### Selection UX + interactions
- ✅ New tab/window → `default-profile` (or base). Menu: **"New Tab with Profile ▸"** submenu.
- ✅ **A split inherits the focused pane's profile** (split an ssh pane → another ssh pane). The profile a pane launched with becomes part of its `Pane` identity in the registry.
- ✅ **Per-profile base font size** ties into P2 cleanly: `PaneController` already holds `configuredFontSize`; for a profiled pane that's the profile's size, so Cmd-0 resets correctly per pane.
- ✅ **Read-once preserved** (P2 policy): config/profiles read at launch; editing needs relaunch (no hot-reload).
- ✅ **The quake uses base appearance + a plain login shell** (resolved 2026-06-28): the quick terminal takes the **base** profile's font/theme but **always launches a plain interactive login shell**, ignoring any `command`/`cwd` (even base's) — a scratch terminal shouldn't silently become an `ssh`/profile session. `quick-terminal-profile` stays deferred.

### Spec churn (why profiles is NOT in P3a)
```
MODIFIED terminal-configuration: discovery/parsing (sections) · schema (command/cwd/env/default-profile)
                                 · view-free component (now yields XttyConfigSet) · applied-to-terminal (per-profile)
ADDED    terminal-configuration: "Profiles" (named bundles, inheritance, selection)
MODIFIED terminal-session:       profile-driven launch (command/cwd/env; login-vs-command)
MODIFIED verification-harness:   per-pane profileName/cwd in the state-dump inventory
```
This is the largest spec churn in all of P3 — the main reason profiles was carved out of the spine.

---

## Testability map (what proves what)

```
swift test (pure, XttyCore):  HotKeyParser ; command wrap (string → loginShell -l -i -c argv) ; cwd expansion ; env merge ;
                              parseSections / inheritance / backward-compat (flat == base)
XCUITest (DEBUG hooks):       quake DEBUG toggle (== hotkey path) → show/type/hide + registry-exclusion ;
                              profile-launched tab → state dump shows theme/font/cwd/profile reflect the profile
untestable (manual/Peekaboo): the real global keypress ; slide animation ; multi-monitor summon
```

## Open questions to resolve at propose/apply time
- ✅ Quick-Terminal v1 keys: `quick-terminal` + `quick-terminal-hotkey` only (resolved; shipped in `add-quick-terminal`). Position/size/screen/autohide/profile deferred to defaults.
- ✅ `add-quick-terminal` and `add-profiles` are **two changes** (resolved; quick-terminal shipped 2026-06-28, profiles still pending).
- ✅ Profiles: unquoted headers = **strict-but-recoverable**; the `command` model = **login-shell wrap** (no tokenizer); quake = **base appearance + plain login shell**; base carries **`cwd`/`env`** — all resolved 2026-06-28 (see _Profiles_ above).
- ❓ Future: the persistent-background quake stance (ii) — out of scope for P3b, revisit if xtty ever wants a status-bar identity.

## Sources
- `XttyCore/Sources/XttyCore/ShellResolver.swift` — `ShellLaunchConfig` (no cwd today), `resolve`/`launchConfig` (pure, injected probes), login `execName = "-" + base`, seed env (no PATH).
- `XttyCore/Sources/XttyCore/XttyConfigLoader.swift` + `XttyConfig.swift` — flat `parse` → `[String:String]`, `resolve` → single `XttyConfig`, fail-soft posture, read-once `load`.
- SwiftTerm checkout (`XttyCore/.build/checkouts/SwiftTerm`): `Mac/MacLocalTerminalView.swift` `startProcess(…, currentDirectory:)`; `Terminal.swift` private URL-only `implicitLinkMatch` / `ghosttyImplicitLinkRegex` (file:line not free); `Mac/MacTerminalView.swift` default `requestOpenLink → NSWorkspace.open`.
- SwiftTerm exec mechanism (confirmed 2026-06-28): `LocalProcess.swift` compiles the **forkpty** path (`#if false //canImport(Subprocess)`); `Pty.swift` execs via **`execve`** (no PATH search) after `chdir(currentDirectory)`; `startProcess(…, currentDirectory:)` is honored.
- Command/PATH research (2026-06-28): zsh manual (startup Files), `path_helper(8)`, Homebrew install docs (`shellenv` in `~/.zprofile`), `exec(3)` (execve vs execvp), `<paths.h>` `_PATH_STDPATH`; git-config docs + `config.c` (strict `[section "subsection"]`), Python `configparser`, `systemd.unit`, TOML v1.0.0; Ghostty [macOS login shells](https://ghostty.org/docs/help/macos-login-shells) + [config reference](https://ghostty.org/docs/config/reference), iTerm2 profile docs, WezTerm + kitty login-shell discussions. Verified via a research + adversarial-verify workflow plus direct web checks.
- Apple Carbon `RegisterEventHotKey` / `kVK_*` virtual keycodes / Carbon modifier masks (HIToolbox).
- P3a change: `openspec/changes/add-tabs-and-splits/` (proposal/design/specs/tasks) — the spine this note's features were deferred from.
- Milestones: [P3 native-shell-UX, P4 OSC capture](../04-design/02-milestones.md). Requirements: [N3 splits/tabs/Quick-Terminal, M6 agent host](xtty-requirements.md).
