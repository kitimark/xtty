## Why

xtty is **ad-hoc signed** ("Sign to Run Locally"), so its code identity (cdhash) changes on **every rebuild**. macOS keys TCC grants — notably **Screen Recording**, which the P7a latency probe (`make bench`) requires — to the app's code identity, so the grant is invalidated and **re-prompts on every build**. This is disruptive when iterating on anything that needs a TCC permission. A stable, self-signed local code-signing identity keeps the identity constant across rebuilds so the grant persists. This is the lightweight slice of the deferred P7-distribution signing work — *not* Developer ID / notarization.

## What Changes

- Add **`scripts/create-signing-cert.sh`** — creates a one-time self-signed **code-signing** certificate (`xtty-dev`) in the user's login keychain (idempotent; reversible with `security delete-identity`).
- Add an **opt-in `XTTY_SIGN_IDENTITY` Makefile override** — when set, `make build` / `make test` / `make bench` sign with that identity (`CODE_SIGN_IDENTITY` + manual style); **unset, the build stays ad-hoc and portable**, so CI and other contributors are unaffected.
- Document the affordance in the canonical build docs (AGENTS → Building).

Out of scope: Developer ID, Hardened Runtime, notarization (still deferred); changing the default (committed) signing posture, which remains ad-hoc.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `build-workflow`: adds an **optional stable local code-signing identity** affordance (a creation helper + an opt-in build override that persists TCC grants across rebuilds), while the default build stays ad-hoc/portable.

## Impact

- **New file:** `scripts/create-signing-cert.sh` (dev tooling).
- **`Makefile`:** an `XTTY_SIGN_IDENTITY`-gated `SIGN_FLAGS` appended to the build/test entry points (no-op when unset).
- **Docs:** AGENTS → Building gains the signing note; the experiment write-up lives in `research/03-analysis/p7-measurement-methodology.md` (2026-06-29 addendum).
- **No app/runtime change**; no change to the committed default signing posture; no new third-party dependency.
