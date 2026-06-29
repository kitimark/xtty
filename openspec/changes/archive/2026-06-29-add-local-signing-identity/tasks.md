## 1. Identity-creation helper

- [x] 1.1 Add `scripts/create-signing-cert.sh` — idempotent, generates a self-signed code-signing cert (`xtty-dev`) via OpenSSL (config-file extensions for LibreSSL/OpenSSL portability) and imports a **combined key+cert PEM** into the login keychain with `-T /usr/bin/codesign` (no PKCS#12, no system-trust change, no sudo); best-effort `set-key-partition-list`, else first-build "Always Allow"
- [x] 1.2 Make it executable and print the next steps (`export XTTY_SIGN_IDENTITY=…`)

## 2. Opt-in build override

- [x] 2.1 Add an `XTTY_SIGN_IDENTITY`-gated `SIGN_FLAGS` to the `Makefile` (`CODE_SIGN_IDENTITY` + `CODE_SIGN_STYLE=Manual` + `CODE_SIGNING_ALLOWED=YES`), appended to the `build` and `test` entry points; a no-op when the variable is unset
- [x] 2.2 Verify portability: `make -n build` shows no signing flags by default and the flags only when `XTTY_SIGN_IDENTITY` is set

## 3. Documentation

- [x] 3.1 Document the affordance in AGENTS → Building (creation helper + the opt-in override + the ad-hoc default); cross-link the experiment write-up in `research/03-analysis/p7-measurement-methodology.md`

## 4. Validate

- [x] 4.1 End-to-end verified during the P7a apply session: built signed as `xtty-dev` (cert-based designated requirement), granted Screen Recording once, and confirmed the grant persisted across two rebuilds with zero re-prompts
- [x] 4.2 `openspec validate "add-local-signing-identity"` clean
