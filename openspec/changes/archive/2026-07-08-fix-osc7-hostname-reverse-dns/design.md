## Context

xtty classifies an OSC 7 working directory as local vs. remote by testing the reported authority against a set of "names that denote the local machine." That set — `PaneController.localHostNames` (`App/PaneController.swift:92`) — is built today from `ProcessInfo.processInfo.hostName`, which resolves via **reverse-DNS** (`-[NSHost blockingResolveUntil:]` → `getnameinfo` → PTR queries for every local address). The static initializes on the **first OSC 7 event**, reachable only under a zsh login (xtty injects OSC 7/133 into zsh only). Consequences, measured in `research/03-analysis/local-network-privacy-forensics.md`:

- **Local Network privacy modal** on first launch for real zsh users (the reverse-DNS PTR volley hits macOS's `mdns:trust` gate → `nehelper` prompts).
- **Main-actor block of 38–62 s** on the first prompt (the resolver runs on the OSC 7 delegate's thread, blocked on a semaphore while the gated lookup hangs).
- **Latent misclassification:** the shell emits its OSC 7 authority from `$HOST` = `gethostname(3)`; the reverse-DNS name only overlaps `$HOST` via the short-form fallback (`host.split(".").first`). On a corporate network where reverse-DNS returns a DHCP FQDN (`dhcp-10-0-0-5.corp.example.com`), neither the full name nor the short form matches `$HOST`, so a **local** cwd is flagged **remote** — silently breaking relative file-link open and the git-review panel.

The consumer chain is tiny and already well-factored: `PaneController.localHostNames` (the only definition of "local") → `PaneController.swift:265` → `XttyCore.OSC7.decode(_:localHostNames:)`, which is a **pure function parameterized on the set** (`OSC7.swift:70` `isRemote = !localHostNames.contains(host.lowercased())`). Only the *source* of the set is at issue.

## Goals / Non-Goals

**Goals:**
- Compute the local-name set **without a network resolution**, sourced from the **same system host name the shell emits** (`gethostname`), so classification matches by construction — removing the modal, the main-thread block, and the corporate-DNS misclassification.
- Keep the name-derivation logic **view-free and unit-testable** (mirroring `OSC7.decode`), so the App layer holds only the syscall.
- Be **behavior-preserving** on every observable the DEBUG state dump exposes (a local cwd still classifies local).

**Non-Goals:**
- No change to `OSC7.decode` or the cwd-update delegate wiring — the classification *algorithm* is unchanged; only the input set's source moves.
- No async/threading rework: removing the reverse-DNS call removes the block; there is no remaining slow call to offload.
- No new DEBUG state-dump field (see D3) and no test-plan / harness restructuring.
- Not the zsh test image or the suite split — those are `add-zsh-test-image` / `split-shell-dependent-testplan`. This change *enables* the former by removing the trigger, but does not depend on it.

## Decisions

### D1 — Source the set from `gethostname(2)`, not `ProcessInfo.hostName` (and not `SCDynamicStoreCopyLocalHostName`)

Build `localHostNames` from `gethostname(2)` — the exact syscall behind zsh's `$HOST`, so the set and the emitted OSC 7 authority always agree. It returns a usable name instantly with **zero** dnssd traffic even when the static `HostName` key is unset (measured, forensics §2b/§8d). **Why not `SCDynamicStoreCopyLocalHostName()`:** that is the Bonjour `LocalHostName`, which can differ from `$HOST`; `gethostname` is the correct, guaranteed match. **Why not keep `ProcessInfo.hostName`:** it is the reverse-DNS path that *is* the trigger, and `scutil --set HostName` was measured not to short-circuit it (forensics T4). *Alternatives rejected:* rig-level LN neutralization (`/etc/hosts` daemon, `defaults write` exemptions, NE-store pre-seed, SSH-child) — all refuted by effect (forensics §8b/§8c/§8e, T7–T10).

### D2 — Extract the name derivation into a pure `XttyCore` seam; leave only the syscall in App

Add a small pure helper to `XttyCore` — e.g. `LocalHost.names(from rawHostName: String) -> Set<String>` — that reproduces today's derivation (`{"", "localhost", name.lowercased(), shortForm}`) from a **given** host-name string. `PaneController.localHostNames` becomes: read `gethostname()` once, pass the string to the helper. **Why:** `App` has no unit-test target (only XCUITests), so the forensics doc's "one unit test" has no clean home in App; extracting the logic mirrors the existing `OSC7.decode` pattern and makes the derivation assertable in `make test-core` (the fast tier), while the untestable part shrinks to a one-line syscall that the existing OSC 7 XCUITest exercises end-to-end. *Alternative rejected:* add an App-layer unit-test bundle just for this — heavier than a 5-line pure function, and it would be the only such bundle.

### D3 — Acceptance is by-effect (the forensics recipe), with **no** new `verification-harness` field

The change's novel property is the *absence* of a network call — invisible to the DEBUG state dump by nature. Everything the dump *can* see is behavior-preserving (a local cwd still classifies local, already assertable via the working-directory / git-review `isRemote` observables). So this change adds **no** `verification-harness` spec delta; that is a deliberate G1 call ("verify the effect, not the syntax"), not an omission. Acceptance is the forensics doc's pre-written re-verify recipe (§8g): apply the swap → run the **fixed build on a fresh `xtty-test-zsh:26.5` graphics clone** under `log stream` (P1) → the P2 greps read **0 / 0 / 0** (no reverse-DNS volley, no `policy 'pending'`, no modal), with **no** `com.xtty.app` NE-store record created (P5 — the query never happens). This is **delegated to `xtty-test-validator`** (marker on task 2.1) as the **red→green complement** to `add-zsh-test-image` task 4.1 (same graphics zsh rig, the *unfixed* build → 40 `pending` + modal): the validator already performs LN-gate-by-effect graphics-VM captures there, so this reuses a proven capability rather than growing the agent. It is scoped to the **LN-gate capture**, not the full-suite envelope — that stays `add-zsh-test-image`'s deliverable (no scope bleed).

### D4 — Regression coverage rides existing tests; no remote-arm test is added

The three XCUITests touching classification (`XttyFileLinkOpenUITests` relative-link, `XttyGitReviewUITests` non-repo empty-state, `XttySemanticCaptureUITests` live-cwd) all assert the **local** case; the swap makes local classification equal-or-more-reliable, so they continue to pass unchanged. There is no `isRemote == true` test (ssh is not reachable in a hermetic XCUITest), so no test can break from "more reliably local." The new `XttyCore` unit test (D2) covers the derivation directly. **Why no new remote test:** it would require a network fixture the suite deliberately avoids; the remote arm stays covered by the `OSC7.decode` unit tests that inject a set not containing the host.

## Risks / Trade-offs

- **`gethostname` returns a name the shell's `$HOST` doesn't match** → would misclassify local as remote. **Mitigation:** they are the *same syscall in the same OS*, so they cannot diverge except across an ssh boundary (correctly remote). Confirmed behavior-preserving in forensics §8d.
- **A user relied on a reverse-DNS FQDN being treated as "local"** → pathological; the short-form fallback already only caught the common case, and `gethostname` is strictly closer to what the shell emits. Non-issue.
- **The by-effect verification is manual, not in CI** → the bash rig can't exercise it (no OSC 7) and there is no zsh CI job yet. **Mitigation:** the forensics §8g recipe is copy-paste and captured with artifacts; the future zsh rig (`add-zsh-test-image`) makes a graphics-modal-free run the standing proof.
- **Refactor touches the `PaneController` ↔ `OSC7` seam** → small surface, covered by the existing OSC 7 XCUITest + the new unit test. Low.

## Migration Plan

Additive and reversible: a one-call-site source swap plus a new pure helper + its test. No data model, no persisted state, no shipping-config change. Rollback is reverting the swap. On the bash CI/VM rig the changed code path never executes, so the acceptance envelope cannot regress. Recommended ordering: land this **before** re-scoping `add-zsh-test-image` (so that change can delete its refuted LN machinery and enable its graphics tier), but the two are independently mergeable.

## Open Questions

- **Naming of the `XttyCore` seam** (`LocalHost.names(from:)` vs. folding it onto `OSC7`/a new `HostName` type) — a cosmetic call settled at apply time; the contract (pure, `String → Set<String>`) is fixed.
- **Does `gethostname` ever need the `SCDynamicStoreCopyComputerName` form for display elsewhere?** Out of scope — this change only feeds `localHostNames`; no other caller of the hostname exists (`grep` confirms `PaneController.swift:94` is the sole `ProcessInfo.hostName` use).
