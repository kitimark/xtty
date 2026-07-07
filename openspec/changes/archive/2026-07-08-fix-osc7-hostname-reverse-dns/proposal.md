## Why

xtty derives "the local machine" (for classifying an OSC 7 working directory as local vs. remote) from `ProcessInfo.hostName` — a **reverse-DNS** call. Under a zsh login (the shipping path), the first prompt's OSC 7 event triggers it, which (a) raises the macOS **Local Network privacy modal** on first launch and (b) **blocks the main actor 38–62 s** on a semaphore while the gated lookup hangs. It is also *less* correct: the shell emits its OSC 7 authority from `$HOST` = `gethostname(3)`, so the reverse-DNS name only matches via a short-form fallback and misclassifies a local cwd as **remote** whenever a corporate reverse-DNS FQDN diverges from `$HOST`. Sourcing the local-name set from `gethostname()` instead is behavior-preserving in the common case, strictly more correct, and removes the trigger entirely. Root-cause forensics: `research/03-analysis/local-network-privacy-forensics.md` (§2b, §8d, §8g).

## What Changes

- **Source the local-host name set from `gethostname()`, not reverse-DNS.** The App-layer static that defines "local" (`PaneController.localHostNames`) stops calling `ProcessInfo.hostName`. This removes the reverse-DNS query on the first OSC 7 event — killing the Local Network modal and the main-thread block on every shell, for every user — and makes the set match the exact syscall behind the shell's emitted `$HOST` authority.
- **Extract the name-derivation into a view-free `XttyCore` seam** so the local-vs-remote logic is unit-testable without launching the app (mirroring the existing `OSC7.decode` pattern); the App does the single `gethostname()` syscall and passes the raw name in.
- **Refine the `terminal-session` "Live working-directory capture from OSC 7" requirement** to state that the local-machine determination SHALL be made **without a network name resolution** and **consistently with the OSC 7 authority the shell emits**, so a local cwd is never misclassified remote and the determination neither blocks the UI nor triggers the OS Local Network privacy prompt.
- **Acceptance is by-effect, not a new harness field** (deliberate): the change is behavior-preserving on everything the DEBUG state dump can observe (a local cwd still classifies local — already assertable); its novel property is the *absence* of a network call, verified by the forensics doc's own recipe (the fixed build on a fresh zsh **graphics** VM clone under `log stream` shows 0 reverse-DNS / 0 `pending` / 0 modal — §8g), delegated to `xtty-test-validator` as the red→green complement to `add-zsh-test-image` task 4.1.

## Capabilities

### New Capabilities

<!-- none — no new spec is introduced -->

### Modified Capabilities

- `terminal-session`: **MODIFY** the "Live working-directory capture from OSC 7" requirement — the set of names denoting the local machine SHALL be determined without a network name resolution and consistently with the shell's emitted OSC 7 authority (so local cwd is never misclassified remote, and no reverse-DNS lookup / Local Network prompt is triggered); add a view-free unit-test scenario for the local-name derivation and a by-effect "no network lookup on first OSC 7" scenario.

## Impact

- **App:** `App/PaneController.swift` — `localHostNames` (`:92`) sources the name via `gethostname()` and the extracted seam instead of `ProcessInfo.hostName` (`:94`). One call site; the sole consumer (`:265` → `OSC7.decode`) is unchanged.
- **XttyCore:** a new small pure helper (`LocalHost.names(from:)` or similar) + its unit test. `OSC7.decode` is already parameterized on `localHostNames` and is **untouched**; the 20 existing `OSC7Tests` inject their own set and cannot see the swap.
- **No SwiftTerm, no test-plan, no shipping-behavior change** beyond removing the reverse-DNS trigger. On the **bash** VM/CI rig the swapped code never executes (bash emits no OSC 7), so the acceptance envelope is untouched by construction.
- **User-facing:** real zsh users stop getting the first-launch Local Network modal and the 38–62 s first-prompt freeze; corporate-DNS users stop having local directories misclassified as remote (file-link open + git-review panel now work there).
- **Enables `add-zsh-test-image`:** removing the trigger dissolves that change's failed rig-level LN-neutralization (D2 daemon + `defaults write` block) and unblocks its graphics tier modal-free — an enabling dependency, not a hard block.
