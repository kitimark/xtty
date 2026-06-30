## 1. Implement the bash-gated seed entry

- [x] 1.1 In `XttyCore/Sources/XttyCore/ShellResolver.swift`, in `launchConfig(...)`, immediately after the seed is built and **before** the `override.env` merge, add `if base == "bash" { seed["BASH_SILENCE_DEPRECATION_WARNING"] = "1" }` (gated to the resolved shell's base name; no-op for other shells; profile `env` still overrides it).

## 2. Verify (view-free unit tests)

- [x] 2.1 In `XttyCore/Tests/XttyCoreTests/ShellResolverTests.swift`, add a test asserting the launch config's `environment` contains `BASH_SILENCE_DEPRECATION_WARNING=1` when the resolved shell is `/bin/bash`.
- [x] 2.2 Add a test asserting the launch config's `environment` does NOT contain `BASH_SILENCE_DEPRECATION_WARNING` when the resolved shell is `/bin/zsh` (and confirm the existing zsh seed-env scenario still passes — argv[0] `-zsh`, `TERM`/`COLORTERM`/`LANG` present). Also added a profile-`env`-overrides test.
- [x] 2.3 Run `make test-core` (the fast `XttyCore` unit loop) and confirm green. → 235 tests, 0 failures.

## 3. Docs & tracker reconciliation

- [x] 3.1 Add a one-line note to `config.example` that xtty suppresses bash's macOS deprecation banner (`BASH_SILENCE_DEPRECATION_WARNING`).
- [x] 3.2 On completion, reconcile trackers per AGENTS.md "Keep progress current": tick these checkboxes, refresh AGENTS.md **Current status**, and add a short forward-pointer from `research/03-analysis/github-actions-ci-cd.md` §11f noting the "fix the shell first" step shipped as `silence-bash-deprecation`.
- [x] 3.3 Run `openspec validate "silence-bash-deprecation"` and confirm it passes before archiving.
