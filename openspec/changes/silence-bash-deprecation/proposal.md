## Why

When xtty launches **bash** as the user's shell, macOS's system `/etc/bashrc` prints a three-line deprecation banner ("The default interactive shell is now zsh. / To update your account… `chsh -s /bin/zsh` / …HT208050") on every session. xtty hands the child shell a *curated, minimal* environment (`ShellResolver.seedEnvironment` passes through only `TERM`/`COLORTERM`/`LANG`/`HOME`/`USER`/`LOGNAME`), so it never carries the documented suppression variable `BASH_SILENCE_DEPRECATION_WARNING` — meaning **every bash user sees this banner**, not just CI. The GitHub Actions `build-and-test` job (run `28425122861`) made the latent papercut visible: the async banner corrupts the terminal grid and is the proven cause of `testFocusTypingOnActivateWithoutClicking` failing as a false negative and of grid noise in the truecolor/paste tests (see `research/03-analysis/github-actions-ci-cd.md` §11).

## What Changes

- When xtty resolves a launch configuration **for a bash login shell**, the seed environment SHALL include `BASH_SILENCE_DEPRECATION_WARNING=1`, suppressing the macOS deprecation banner before `/etc/bashrc` runs. The fix lives **inside** the `seedEnvironment` wall (the only place the child shell's environment is built) — a CI-workflow or `launchEnvironment` setting would be stripped by the seed and silently no-op.
- The variable is **gated to bash** (`base == "bash"`) so it is a no-op for zsh and other shells, and is idempotent (harmless if the user already exports it).
- No shell switch, no change to argv/login behavior, no new config key. Real bash users stop seeing the banner; the CI grids stop being corrupted by it.
- Not a BREAKING change.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `terminal-session`: the **Shell resolution and launch configuration** requirement gains a scenario — a bash login shell's seed environment includes `BASH_SILENCE_DEPRECATION_WARNING=1` (shell-gated); other shells are unaffected.

## Impact

- **Code:** `XttyCore/Sources/XttyCore/ShellResolver.swift` — add the bash-gated seed entry in `launchConfig` (where the resolved shell `base` is known), immediately after `seedEnvironment` builds the seed and **before** the `override.env` merge (so it sits with the seed defaults and a profile `env` still overrides it).
- **Tests:** `XttyCore/Tests/XttyCoreTests/ShellResolverTests.swift` — a view-free unit test asserting the launch config's `environment` contains `BASH_SILENCE_DEPRECATION_WARNING=1` for a `/bin/bash` resolution and omits it for `/bin/zsh`. (No `verification-harness` delta: the behavior is on the pure, view-free `ShellResolver` and is unit-testable; it also adds no DEBUG dump field. The existing grid-corrupted CI XCUITests serve as the incidental e2e confirmation once the banner is gone.)
- **Docs:** `config.example` note (optional) that bash's deprecation banner is suppressed by xtty.
- **Unblocks:** the §11f "fix the shell first" step of the `add-ci-pipeline` / `harden-xcuitests-for-ci` follow-up — clears the focus-typing false negative and de-noises the truecolor/paste grids, leaving only the genuine Bucket-B (Cmd-key/menu) failures.
