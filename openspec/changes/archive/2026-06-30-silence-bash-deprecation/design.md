## Context

xtty spawns the user's login shell through `XttyCore.ShellResolver`, which builds a **curated** child environment in `seedEnvironment(environment:)` — it passes through only `TERM`, `COLORTERM`, `LANG`, `HOME`, `USER`, `LOGNAME` and adds `TERM`/`COLORTERM` defaults. Everything else from the parent process is intentionally dropped (the login shell rebuilds PATH etc.). The launch uses an `execName` of `-` + base (e.g. `-bash`), the login-shell convention, so bash sources `/etc/profile` → `/etc/bashrc`.

macOS's system `/etc/bashrc` prints the deprecation banner unless `BASH_SILENCE_DEPRECATION_WARNING` is present in the environment *at shell startup*. Because the seed never includes it, **every bash user sees the banner each session**. The banner is multi-line and asynchronous, so it interleaves with and overwrites grid content — which is why the CI XCUITests (run `28425122861`) surfaced it: `testFocusTypingOnActivateWithoutClicking` is a proven false negative (the typed marker is split across the banner's line wrap), and the truecolor/paste grids are corrupted. Full evidence: `research/03-analysis/github-actions-ci-cd.md` §11.

The environment-flow constraint is the load-bearing fact: the variable must be injected **inside** `seedEnvironment`'s wall. Setting it in `ci.yml` `env:` or in XCUITest `launchEnvironment` is stripped by the seed and silently no-ops.

## Goals / Non-Goals

**Goals:**
- A bash login shell launched by xtty does not print the macOS deprecation banner — for real users and on CI alike.
- The fix is deterministic, view-free, and unit-tested on the pure `ShellResolver` (no app launch).
- Zero effect on non-bash shells and on existing shell-resolution / zsh-integration behavior.

**Non-Goals:**
- Switching the shell (e.g. forcing zsh on CI) — that is a larger behavior change and would conflate "silence a banner" with "change the test shell"; tracked separately.
- Re-enabling OSC shell-integration under bash, or any new shell-integration behavior.
- Fixing the genuine Bucket-B CI failures (Cmd-key/menu key-equivalents not firing) — that is the separate `harden-xcuitests-for-ci` follow-up.
- A new config key or any user-facing knob.

## Decisions

**D1 — Inject `BASH_SILENCE_DEPRECATION_WARNING=1` in `launchConfig`, gated to `base == "bash"`, alongside the seed defaults.**
The seed is built by `seedEnvironment` (which is shell-agnostic), but the resolved shell's `base` is known in `launchConfig` (it already computes `base` and `execName`). Add the entry there, **immediately after `seedEnvironment` builds the seed and before the `override.env` merge** — so it sits with the other seed defaults (`TERM`/`COLORTERM`/`LANG`) and a profile's explicit `env` still overrides it, exactly as `override.env` already overrides those defaults. Gating to `base == "bash"` keeps it intentional and a no-op for zsh/fish/etc.
- *Alternative considered — place it after the `override.env` merge:* would let xtty's `1` win over a user's explicit profile `env`, breaking the established "profile env overrides seed defaults" precedence. Rejected — least surprise says explicit user config wins.
- *Alternative considered — unconditional seed entry:* simpler, harmless for zsh (which ignores the var), but pollutes every shell's env with a bash-only var; gating is tidier and self-documenting. Rejected on cleanliness, not correctness.
- *Alternative considered — put it in `seedEnvironment`:* that function has no `base`, so it can't gate; would force the unconditional variant. Rejected.

**D2 — A seed default, overridable by profile `env`.** The var is set in the seed for bash regardless of the parent's value (the seed drops the parent's copy anyway); `1` is the documented sentinel. Because it lands *before* the `override.env` merge, a profile `env` entry can still override it — consistent with `TERM`/`LANG`. Today a bash user who exports the var themselves is *not* served either (the curated seed drops it), so this is strictly an improvement.

**D3 — Verify on the pure resolver, not the harness.** The behavior is a property of the launch-config value object, so a `ShellResolverTests` unit test (mirroring the existing seed-env tests) asserts the env contains the var for `/bin/bash` and omits it for `/bin/zsh`. No `verification-harness` delta and no DEBUG dump field: there is no new view-observable behavior that isn't already unit-testable, and the existing (previously grid-corrupted) CI XCUITests provide incidental e2e confirmation once the banner is gone.

## Risks / Trade-offs

- **[Suppressing an Apple deprecation notice is a product choice]** → It is the documented, intended suppression mechanism (the banner text itself instructs setting this variable), and matches how GUI terminals quiet it; the user keeps full control via their own `~/.bashrc`/`~/.bash_profile` or a profile `env`. Low risk.
- **[Banner could originate from a path other than the env-gated `/etc/bashrc`]** → On stock macOS the banner is gated solely by `BASH_SILENCE_DEPRECATION_WARNING`; if a future macOS changes the mechanism the unit test still passes (it asserts the env var) but the banner could reappear. Acceptable; revisit if observed.
- **[Only addresses one of the seven CI failures directly]** → By design — this is the "fix the shell first" step (§11f). It removes the focus-typing false negative and de-noises the truecolor/paste grids; the residual Bucket-B failures are explicitly out of scope and tracked separately. Not a regression risk.
- **[Most dev machines run zsh, so the new unit test is the only local signal]** → That is sufficient: the test drives `ShellResolver` with an injected `/bin/bash` path, so it is deterministic regardless of the host's actual shell.

## Migration Plan

Pure additive behavior; no migration. Rollback is removing the one seed entry. No data, config, or API surface changes.

## Open Questions

- None blocking. (Whether to *also* force zsh on CI to light up OSC shell-integration coverage is deliberately deferred to a separate decision, not this change.)
