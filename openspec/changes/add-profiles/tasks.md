## 1. Core: sectioned parsing (XttyCore, pure)

- [ ] 1.1 Add `XttyConfigLoader.parseSections(_:) -> (base: [String: String], profiles: [(name: String, pairs: [String: String])])`: lines before the first header = base; `^\[profile\s+"([^"]+)"\]$` starts a named block. Preserve **original key case** (lowercase only when matching known keys; take `<NAME>` in `env-<NAME>` verbatim). Skip + warn malformed/unquoted/empty headers; merge duplicate profile names (later keys win) + warn; ignore unknown section types (forward-compat).
- [ ] 1.2 Unit tests (`XttyConfigTests`): base/named split; `env-EDITOR` case preserved; malformed/empty header skipped (rest still loads); duplicate-name merge; flat file → base only with empty profiles; comments/blank/whitespace honored inside sections.

## 2. Core: profile model + inheritance (XttyCore, pure)

- [ ] 2.1 Add `LaunchOverride { command: String?; cwd: String?; env: [String: String] }`, `XttyProfile { name: String; config: XttyConfig; launch: LaunchOverride }`, `XttyConfigSet { base: XttyProfile; profiles: [String: XttyProfile]; defaultProfileName: String? }` (Equatable + Sendable).
- [ ] 2.2 Refactor `XttyConfigLoader.resolve` to `resolve(from:base:warn:)` (default `base = .default`) so a profile resolves as `base ⊕ overrides`; existing callers unchanged.
- [ ] 2.3 Add a set-resolver that builds `XttyConfigSet` from `parseSections`: per-profile appearance via inheritance; parse launch keys (`command`, `cwd`, repeated `env-<NAME>`; `env-PATH` → warn + ignore); `default-profile`/`confirm-close` honored **base-only** (in a profile block → warn + ignore); unknown `default-profile` → warn + fall back to base.
- [ ] 2.4 Unit tests: inheritance (override wins, rest inherited); **flat == base** (set's base config equals the old flat `resolve`); default-profile selection + unknown fallback; launch keys parsed; env additive + case preserved + `env-PATH` ignored; `confirm-close` parsed.

## 3. Core: launch resolution (XttyCore — ShellResolver, pure)

- [ ] 3.1 Add `cwd: String?` to `ShellLaunchConfig`.
- [ ] 3.2 Add a pure cwd-expansion helper (`~` / `$HOME` only; injected existence probe; missing dir → `nil` + warn).
- [ ] 3.3 Add `ShellResolver.resolve(override:environment:)` (+ a pure `launchConfig(override:forShell:environment:)`): `command` present → `executable = <login shell>`, `args = ["-l","-i","-c", command]`, `execName = "-" + base`; absent → the existing plain login-shell config. Merge `env` additively (profile wins; `PATH` excluded). Set `cwd`.
- [ ] 3.4 Unit tests (`ShellResolverTests`): command-wrap argv is exactly `["-l","-i","-c","ssh box"]` with login `execName`; no-command path == today's login shell; env merge + `PATH` excluded; cwd expansion + missing-dir fallback.

## 4. Core: pane identity (XttyCore, pure)

- [ ] 4.1 Add `profileName: String?` to `Pane`; add `SessionRegistry.makePane(for:profileName:)` (keep the existing `makePane(for:)` as `profileName: nil`).
- [ ] 4.2 Unit test (`PaneModelTests`): a pane records its profile name; a base pane's `profileName` is `nil`.

## 5. App wiring: profile-driven launch

- [ ] 5.1 `PaneController.init` takes a resolved `XttyProfile` (config + launch + name): resolve launch via `ShellResolver.resolve(override:)`, `TerminalConfigurator.apply(profile.config, …)`, pass `currentDirectory: launch.cwd` to `startProcess`, register via `makePane(for:profileName:)`, and **retain the `XttyProfile`** for split inheritance. `configuredFontSize` = the profile's size.
- [ ] 5.2 `AppDelegate` resolves + owns the `XttyConfigSet` (extend `loadConfigAndKeybindings`); the first window launches with the default (or base) profile.
- [ ] 5.3 `WindowCoordinator.openNewWindow`/`openNewTab` gain a `profile:` parameter (default = the set's default); `TerminalWindowController` launches its root with the given profile; `splitFocusedPane` reuses the focused pane's retained profile.
- [ ] 5.4 Wire `confirm-close` (base config) into `TerminalWindowController`, replacing the hardcoded `confirmCloseEnabled` (design D10).

## 6. App wiring: selection menu + quick terminal

- [ ] 6.1 Build a dynamic **"New Tab with Profile ▸"** submenu in `XttyMainMenu.build` from the set's profile names (item `representedObject` = name → an `AppDelegate` action that opens a tab with that profile).
- [ ] 6.2 `QuickTerminalController` uses the **base** profile's appearance and always launches a plain login shell, ignoring `command`/`cwd` (design D9).

## 7. Harness + docs

- [ ] 7.1 Extend the DEBUG state dump (`TerminalWindowController.writeStateDump`) with the focused pane's `profileName` and `cwd`.
- [ ] 7.2 Add an XCUITest: launch with a config that defines a named profile (non-default theme/font + `cwd`) selected via `default-profile` (and/or the New-Tab-with-Profile menu) and assert the state dump reports the profile name + cwd/appearance.
- [ ] 7.3 Update `config.example` with a Profiles section: base vs `[profile "name"]`, `command`/`cwd`/`env-<NAME>`, `default-profile`, `confirm-close` — with the login-shell + `PATH`-is-built-by-the-shell note.
- [ ] 7.4 `xcodegen generate` (if files were added); then `cd XttyCore && swift test`, and build + run the app XCUITest target — all green.

## 8. Trackers

- [ ] 8.1 Tick these checkboxes as work lands; refresh **Current status** in `AGENTS.md` and the P3b state in `research/04-design/02-milestones.md` when the change is complete.
