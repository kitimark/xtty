## Context

The VM/CI rig runs Apple's bash 3.2.57 by deliberate choice (`packer/xtty-test.pkr.hcl` `chsh -s /bin/bash`): it matches the GitHub-hosted runner *and* it dodges the zsh-only Local Network privacy modal that xtty's OSC 7 hostname path triggers (`research/03-analysis/local-network-privacy-forensics.md`). The cost, quantified in `research/03-analysis/shell-dependent-test-partitioning.md`: ~half the suite is shell-dependent, and under bash the 19-method semantic-capture family early-returns before asserting (vacuous passes) while `testMultiLinePasteIsNotAutoExecuted` hard-fails on bash 3.2's missing bracketed paste. This change builds a **zsh** image variant so the shell-dependent half can be exercised for real, and runs the *existing* suite on both rigs to observe the divergence — the measurement that justifies the follow-up suite split. The in-guest suite runs via `xcodebuild test-without-building -xctestrun *.xctestrun` (no test-plan), so the zsh image runs today's suite unmodified; this change stands alone.

## Goals / Non-Goals

**Goals:**
- Produce a `xtty-test-zsh:26.5` image from the same pinned inputs / same template as the bash `xtty-test:26.5`, selected by a build parameter.
- Neutralize the Local Network gate on the zsh guest **at the rig level, without touching xtty product code**, so a graphics UI run doesn't surface the modal.
- Run the current suite on both rigs and record the **divergence** (bash: paste red + family vacuous; zsh: paste green + family asserting), proving the zsh rig takes the real arm *by effect*.
- Keep both rigs as a supplement pair (bash = CI-parity/acceptance; zsh = real-user coverage) and update `packer/README.md` + §19b accordingly.

**Non-Goals:**
- No test-code changes (test plans, `XCTSkip`, the `bracketedPasteMode` state-dump field) — that is `split-shell-dependent-testplan`.
- No product fix to xtty's OSC 7 reverse-DNS trigger (owner-dropped; documented fallback only).
- No GitHub-Actions zsh job (future).
- Not making the zsh rig a *standing* validator sweep environment — that rides with change 2 (see Open Questions).

## Decisions

### D1 — Parameterize the one template (`shell = bash | zsh`), don't fork a second `.pkr.hcl`

Add a Packer variable `shell` (default `bash`) to `xtty-test.pkr.hcl`; the shell-selection provisioner (`chsh`) and the output tag (`xtty-test` vs `xtty-test-zsh`) key off it. **Why:** the two images differ only in a login shell + one LaunchDaemon; the ~40 GB of macOS+Xcode is identical. One source keeps them from drifting and guarantees `shell=bash` stays byte-identical to today's image. *Alternative rejected:* a separate `xtty-test-zsh.pkr.hcl` — duplicates the whole provisioner chain, invites drift.

### D2 — Neutralize the LN gate with a per-boot `/etc/hosts` seeding LaunchDaemon (rig-level, fix-class (b))

A `LaunchDaemon` (`RunAtLoad`, root) runs a script at each boot that enumerates every local interface address (`ifconfig` inet + inet6, incl. link-local/ULA) and writes `<addr> <name>` lines into `/etc/hosts`, so `getnameinfo` answers the reverse-PTR from the **files** module before it ever reaches mDNS — the query that trips the gate never goes multicast. **Why this mechanism:** `local-network-privacy-forensics.md` P7 measured this as **0 gate events**, and G9 ("remove the arbiter's input") argues for eliminating the gated operation over arguing with the un-pre-seedable arbiter (`tccutil`/MDM/NE-plist edits all refuted, §2a). **Why per-boot, not a static file:** the addresses are DHCP/link-local-dynamic, so a baked static `/etc/hosts` goes stale on the next clone/boot. *Alternatives rejected:* (a) `scutil --set HostName` — measured inert (still 20 reverse lookups/launch); (b) TN3179 exemption arrays — screenshot-refuted; (c) the product `gethostname` fix — owner-dropped, product-scope, kept only as the Open-Question fallback.

### D3 — Acceptance is the measured divergence + proof-of-real-arm, not an all-green count

The change's acceptance is **not** "the zsh rig is all green." It is: (i) the bash rig still shows its documented `40/1/1` envelope (paste red, family vacuous); (ii) the zsh rig shows the paste test **green** and the semantic family **asserting** — evidenced *by effect*: the `.xcresult` has **no** `"…capture inactive…"` attachments for the family, and the paste grid stages both lines (no `command not found`). A zsh-rig green that still carried "capture inactive" attachments would be another vacuous pass and would **fail** this change's acceptance. Whatever count the zsh rig lands becomes its recorded envelope by measurement (it is a discovery, not a prediction). **Why:** the whole thesis is same-binary divergence across shells; the evidence must distinguish a real arm from a degrade arm, which both report "passed."

### D4 — Keep the guest's 59-char hostname on the zsh variant (inherit the base), treat prompt-width as measured-not-designed

The base image sets a 59-char single-label hostname for bash prompt-width parity (`add-vm-prompt-width-parity`). The zsh variant inherits it. The LN daemon (D2) neutralizes the *reverse-DNS* trigger regardless of hostname length, so length is orthogonal to the modal. Under zsh the prompt differs from bash's `\h:\W \u\$`, so prompt-width behavior is whatever the run shows; the find-bar assertion is already wrap-tolerant (`harden-findbar-wrap-assertion`), so it is robust either way. **Why not tune the hostname for zsh:** no evidence it's needed; changing it would diverge the two images for no measured reason. Recorded as a "measure it" observation, not a design lever.

### D5 — The divergence run is delegated to `xtty-test-validator`, pointed at the zsh golden

Per AGENTS.md, any verify task running a VM tier is delegated to `xtty-test-validator`; the task names the image to clone (`xtty-test-zsh:26.5`) and carries the `⟶ xtty-test-validator` marker. The agent reads the (this-change-updated) envelope/matrix from `packer/README.md` at runtime — no agent-definition edit is required for a run pointed at a named golden. **Why not modify the validator here:** see Open Questions Q1; deferring avoids agent-definition-delivery churn that would collide with change 2's validator-interpretation update.

## Risks / Trade-offs

- **The LN arbiter is documented as irreducible** (`local-network-privacy-forensics.md` §2a) → the `/etc/hosts` daemon is proven (0 events) but relies on enumerating *all* interface addresses; a missed address class could still trip a *silent* gate (or, worse, the modal). **Mitigation:** doing this change first front-loads the risk — verify by effect (a graphics run + `log stream` shows 0 "policy 'pending'" events) before change 2 depends on the rig; fallback = the product `gethostname` fix, surfaced for owner decision, not assumed.
- **The zsh rig may surface *new* zsh-specific behavior** (fresh-guest `~/.zshrc` absent → injected integration must load cleanly; a different prompt width). **Mitigation:** that is exactly what measurement-first is for — record it as the zsh envelope rather than predict it; the find-bar assertion is already wrap-tolerant.
- **A second ~40 GB image** costs disk + a build. **Mitigation:** one parameterized template, APFS CoW clones, and the human-gated prereqs are unchanged from `add-xtty-test-image`.
- **Two goldens invite "which image did this run use?" confusion.** **Mitigation:** distinct tags (`xtty-test` vs `xtty-test-zsh`) and the validator's cleanup manifest naming the clone source.

## Migration Plan

Additive and reversible: a new `shell` var defaulting to `bash` leaves `make image` producing today's image unchanged; the zsh image is built explicitly. No product/runtime change to roll back. If the LN daemon proves insufficient, the zsh variant is simply not adopted (the bash rig is untouched) while the fallback is evaluated.

## Open Questions

- **Q1 — Does the validator agent need a definition update to run the zsh golden, or does naming the clone source in the delegated task suffice?** Assumed sufficient (D5). If apply shows the agent hardcodes the golden name, sequence the definition edit with change 2's validator-interpretation update (one delivery, not two). Recorded so it isn't rediscovered.
- **Q2 — Exact set of addresses the LN daemon must seed** (does `fe80::` link-local need the `%iface` scope in `/etc/hosts`? does the loopback/`vmnet` set suffice?) — resolve empirically during the D2 verify-by-effect, capture the working recipe in `packer/README.md`.
- **Q3 — The zsh rig's headless-vs-graphics parity** (the bash rig matches exactly post-menu-fix) — measure both arms; a mismatch is itself a finding.
