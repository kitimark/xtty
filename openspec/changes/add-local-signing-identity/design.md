## Context

The P7a latency probe (`make bench`) uses ScreenCaptureKit, which needs the **Screen Recording** TCC grant. xtty's ad-hoc signature (`Signature=adhoc`, `TeamIdentifier=not set`) gives the app a cdhash-based designated requirement that changes every rebuild, so the grant re-prompts each build. A stable self-signed cert makes the designated requirement cert-based (`identifier "com.xtty.app" and certificate leaf = H"…"`), which is constant across rebuilds → the grant persists. Verified during the P7a apply session (two rebuilds, zero re-prompts). This change captures that experiment as a reusable, opt-in dev affordance.

## Goals / Non-Goals

**Goals:**
- A one-time, scriptable way to create a local code-signing identity.
- An **opt-in** build override that signs with it, leaving the default build untouched.
- Keep the committed signing posture ad-hoc/portable (CI + other devs unaffected).

**Non-Goals:**
- Developer ID, Hardened Runtime, notarization (deferred P7-distribution work).
- Changing the default/committed signing identity.
- Trusting the cert for Gatekeeper distribution (local signing only).

## Decisions

### D1 — Opt-in via an environment-gated Makefile variable (not project.yml)
Hard-coding a personal cert name in the tracked `project.yml` would break every other clone/CI. Instead, `make` reads `XTTY_SIGN_IDENTITY` from the environment and, only when set, passes `CODE_SIGN_IDENTITY=… CODE_SIGN_STYLE=Manual CODE_SIGNING_ALLOWED=YES` to `xcodebuild`. Unset → the project's ad-hoc default. Portable by construction (a dry-run confirms the flags appear only when the var is set).

### D2 — Import a combined key+cert PEM, not a PKCS#12
macOS's `security import` cannot verify the MAC of a PKCS#12 produced by the system's LibreSSL / OpenSSL 3 ("MAC verification failed during PKCS12 import"). The script therefore generates the key + self-signed cert with OpenSSL (a config-file form for `req` extensions, portable across LibreSSL/OpenSSL) and imports a **combined key+cert PEM** in one `security import … -T /usr/bin/codesign`, sidestepping p12 entirely.

### D3 — An untrusted self-signed cert is sufficient for *signing*
The cert shows `CSSMERR_TP_NOT_TRUSTED` and is excluded from `security find-identity -v -p codesigning` ("valid"), but `codesign -s xtty-dev` **still signs successfully** — trust only affects Gatekeeper *verification*, not the ability to sign locally. So the script does **not** modify the system trust store (no sudo, no admin trust prompt). Key access is granted via `-T /usr/bin/codesign` on import; `set-key-partition-list` is attempted best-effort, and if it can't run non-interactively the first signed build simply shows a one-time "codesign wants to use key → Always Allow" dialog.

### D4 — The harness e2e stays prompt-free without any signing
Independently of this change, the benchmark e2e is gated behind `XTTY_RUN_BENCH_E2E=1` (it is the only test that drives ScreenCaptureKit), so routine `make test` never prompts — signing setup is purely for the manual `make bench` workflow.

## Risks / Trade-offs

- [Self-signed cert in the user's keychain] → reversible (`security delete-identity -c xtty-dev`); documented; created only when the user runs the script.
- [`set-key-partition-list` may need the keychain password] → best-effort; falls back to the one-time "Always Allow" GUI on first build.
- [Someone hard-codes the identity into committed config] → mitigated by the env-gated design; the default path stays ad-hoc.

## Migration Plan

Additive and opt-in. No migration: contributors who don't set `XTTY_SIGN_IDENTITY` see no change. Removal = delete the script + the `SIGN_FLAGS` lines; nothing depends on it.

## Open Questions

None. Full Developer ID + notarization remain explicitly deferred to the P7-distribution work.
