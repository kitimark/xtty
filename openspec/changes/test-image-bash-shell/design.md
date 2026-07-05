## Context

The `xtty-test` image is meant to reproduce the GitHub-hosted-runner / tahoe-xcode environment locally for CI-parity runs (the menu-clobber race). A confound appeared: a *graphics* UI run in the `xtty-test` guest raises the macOS Local Network privacy modal, which steals focus and disturbs the Cmd-key tests. The reference rigs don't show it.

The mechanism was traced and measured (see `research/03-analysis/local-macos-vm-ci-reproduction.md` §12 and the 2026-07-05 investigation):

- xtty computes its local host names (to classify OSC 7 cwd as local vs remote) via `ProcessInfo.processInfo.hostName`, which runs `NSHost` → `blockingResolveUntil:` → a **reverse-DNS lookup of every local interface address** (~20 dnssd queries). lldb backtrace confirmed on macOS 26.2.
- This only runs when the shell emits **OSC 7**, which xtty injects into **zsh** only (not bash).
- On a stock guest (no static `HostName`), those reverse queries hit macOS Local Network privacy → the modal.

Controlled measurement on the 26.5 rig (`xtty-verify`), plain-launching the app under a `log stream`:

| Guest config | reverse-DNS (xtty) | dialog |
| --- | --- | --- |
| zsh, `HostName` unset (image default) | 20 | yes |
| zsh, `HostName` **set** (long runner name) | **20** (unchanged) | flaky (arbiter state) |
| **bash**, `HostName` set | **0** | no |

And the reference: GitHub `runner-images/images/macos/scripts/build/configure-shell.sh` runs `sudo chsh -s /bin/bash $USERNAME` (+ root) — "Configure shell to use bash." So on CI, xtty spawns bash → no OSC 7 → no reverse-DNS → no dialog.

## Goals / Non-Goals

**Goals:**
- Make the `xtty-test` image reproduce the hosted-runner shell environment (bash), deterministically eliminating the Local Network modal confound from graphics UI runs.
- Correct the template's and README's stale/incorrect Local Network notes.

**Non-Goals:**
- **Not** a product fix. This change touches only the image; it does not alter xtty's behavior for real users (zsh users still trigger the reverse-DNS + dialog — a separate concern, deliberately out of scope here).
- Not changing what the image tests (the menu-clobber race reproduces regardless of shell).

## Decisions

**D1 — Set the guest login shell to bash via `chsh`, mirroring runner-images.** Add `sudo chsh -s /bin/bash admin` as a packer provisioner (the `admin` user is the one the golden-clone auto-logs-in and under which the suite runs). This is the *same* mechanism GitHub uses, so the local rig matches CI at the source rather than papering over the symptom. *Alternatives considered:* (a) set a static `HostName` — **rejected, measured ineffective**: the reverse-DNS still fired 20× (the dialog's absence in that run was arbiter state-carryover, not the hostname); (b) seed `/etc/hosts` reverse entries at boot so the lookup resolves locally without mDNS — works and keeps zsh, but is more moving parts (a boot-time daemon regenerating from live addresses) and does **not** match how CI is actually configured; (c) bake a Local Network grant — per-app-identity-keyed, breaks on ad-hoc cdhash churn, fragile.

**D2 — Match root too, optional.** runner-images also `chsh`'s root; the suite runs as `admin`, so `admin` is sufficient. Include root for closer parity but it is not load-bearing.

**D3 — Rewrite the template's Local Network comment.** The existing block (lines ~113–127) attributes the modal to the "XCUITest runner↔app IPC over the routable vmnet address" and cites the refuted TN3179 defaults. Both are now disproven. Replace with the measured cause (xtty OSC 7 → reverse-DNS on zsh) and the bash rationale, so the template documents reality.

## Risks / Trade-offs

- **Semantic-capture UI tests degrade under bash** (OSC 133 / OSC 7 arms fall back to graceful degradation). → This is exactly CI's behavior (CI is bash), so it is *more* faithful, not a regression. The zsh semantic path is still exercised on bare-metal `make test`.
- **bash deprecation banner** could corrupt grids. → Already handled by the shipped `silence-bash-deprecation` product fix (`BASH_SILENCE_DEPRECATION_WARNING=1`).
- **Shared template with `add-xtty-test-image`.** → Both ADD to `build-workflow` with distinct requirement names (no merge conflict); apply after that change's template exists (it already does). Note the interaction in both changes' trackers.

## Migration Plan

Rebuild the image (`make image`) to pick up the shell change; existing clones can be re-cloned from the rebuilt golden image. No product or CI-workflow impact. Rollback = drop the provisioner and rebuild.

## Verification

- After rebuild, in a fresh clone: `dscl . -read /Users/admin UserShell` → `/bin/bash`.
- A graphics UI run in the clone shows **0** `client pid … (xtty)` reverse-DNS requests in a `log stream` capture and **no** Local Network modal (contrast the pre-change capture in `~/Downloads/xtty-vm-poc/artifacts/ln-diagnosis/`), while still reproducing the menu-clobber 34/7/1 result.

## Open Questions

- None. (Whether to *also* fix xtty's product code so zsh users stop hitting the dialog was considered and deliberately excluded from this test-image change.)
