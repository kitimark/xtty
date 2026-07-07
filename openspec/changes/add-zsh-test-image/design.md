## Context

The VM/CI rig runs Apple's bash 3.2.57 by deliberate choice (`packer/xtty-test.pkr.hcl` `chsh -s /bin/bash`): it matches the GitHub-hosted runner *and* it dodges the zsh-only Local Network privacy modal that xtty's OSC 7 hostname path triggers (`research/03-analysis/local-network-privacy-forensics.md`). The cost, quantified in `research/03-analysis/shell-dependent-test-partitioning.md`: ~half the suite is shell-dependent, and under bash the 19-method semantic-capture family early-returns before asserting (vacuous passes) while `testMultiLinePasteIsNotAutoExecuted` hard-fails on bash 3.2's missing bracketed paste. This change builds a **zsh** image variant so the shell-dependent half can be exercised for real, and runs the *existing* suite on both rigs to observe the divergence — the measurement that justifies the follow-up suite split. The in-guest suite runs via `xcodebuild test-without-building -xctestrun *.xctestrun` (no test-plan), so the zsh image runs today's suite unmodified; this change stands alone.

## Goals / Non-Goals

**Goals:**
- Produce a `xtty-test-zsh:26.5` image from the same pinned inputs / same template as the bash `xtty-test:26.5`, selected by a build parameter.
- Run the current suite on both rigs **headless** and record the **divergence** (bash: paste red + family vacuous; zsh: family asserting), proving the zsh rig takes the real arm *by effect*. Headless is the standalone measurement path because the Local Network modal is graphics-only and the gate is **not neutralizable at the rig level** (D2, refuted).
- Keep both rigs as a supplement pair (bash = CI-parity/acceptance; zsh = real-user coverage) and update `packer/README.md` + §19b accordingly.

**Non-Goals:**
- No test-code changes (test plans, `XCTSkip`, the `bracketedPasteMode` state-dump field) — that is `split-shell-dependent-testplan`.
- No product fix to xtty's OSC 7 reverse-DNS trigger here — that is the sibling change `fix-osc7-hostname-reverse-dns`, which this change *enables* (its graphics real-arm run) but does not depend on for the headless measurement.
- No rig-level Local Network gate neutralization (D2 — refuted every way).
- No GitHub-Actions zsh job (future).
- Not making the zsh rig a *standing* validator sweep environment — that rides with change 2 (see Open Questions).

## Decisions

### D1 — Parameterize the one template (`shell = bash | zsh`), don't fork a second `.pkr.hcl`

Add a Packer variable `shell` (default `bash`) to `xtty-test.pkr.hcl`; the shell-selection provisioner (`chsh`) and the output tag (`xtty-test` vs `xtty-test-zsh`) key off it. **Why:** the two images differ only in a login shell + one LaunchDaemon; the ~40 GB of macOS+Xcode is identical. One source keeps them from drifting and guarantees `shell=bash` stays byte-identical to today's image. *Alternative rejected:* a separate `xtty-test-zsh.pkr.hcl` — duplicates the whole provisioner chain, invites drift.

### D2 — The LN gate is **not neutralizable at the rig level** (every mechanism refuted) → measure headless; the durable fix is the product change

The change was originally designed to neutralize the gate on the zsh guest with a per-boot `/etc/hosts`-seeding `LaunchDaemon` (enumerate every local interface address so `getnameinfo` answers the reverse-PTR from the **files** module before mDNS). That mechanism was **built and refuted by effect** (task 4.1): macOS answers the IPv6 ULA/link-local reverse PTR from `/etc/hosts` but does **not** preempt the **routable-IPv4** reverse PTR, so `getnameinfo(192.168.64.x)` escapes to the local-network nameserver and *that* send is what the trust gate evaluates → `pending` → modal (40 events measured). Seeding more lines cannot fix it. The subsequent refutation sweep closed every remaining rig-level lever: TN3179 `Allowed*LocalNetworkAddresses` arrays (destination-address exemption, orthogonal to the reverse-DNS *query* — T7), an NE-store pre-seed (boot-pruned by `nesessionmanager` — T8/T9), and the SSH/CLI-child auto-grant (a GUI bundle is its own responsible code — T10). Full fates + probes: `local-network-privacy-forensics.md` §8 (T7–T10, guideline G11).

**Consequences for this change:** (1) no rig-level gate machinery ships — the LaunchDaemon assets are retained only as a documented dead-end; (2) because the modal is **graphics-only**, the standalone shell-divergence is measured **headless**, where the gate resolves to the default deny without a modal; (3) the durable, correct fix is the **product** change `fix-osc7-hostname-reverse-dns` — source `PaneController.localHostNames` from `gethostname(2)` (matches the shell's injected `${HOST}`; behavior-preserving + more correct), which removes the trigger entirely and unblocks a modal-free **graphics** real-arm run. That graphics run is the red→green pair: this change's unfixed-build red baseline (task 4.1) ↔ `fix-osc7-hostname-reverse-dns` task 2.1's fixed-build green.

### D3 — Acceptance is the measured divergence + proof-of-real-arm (measured **headless**), not an all-green count

The change's acceptance is **not** "the zsh rig is all green." It is, measured **headless** on both rigs (D2 — the graphics modal is un-neutralizable at the rig level, so the standalone measurement avoids it): (i) the bash rig still shows its documented `40/1/1` envelope (paste red, family vacuous); (ii) the zsh rig shows the semantic family **asserting** — evidenced *by effect*: the `.xcresult` has **no** `"…capture inactive…"` attachments for the family. A zsh-rig pass that still carried "capture inactive" attachments would be another vacuous pass and would **fail** this change's acceptance. Whatever count the zsh rig lands becomes its recorded envelope by measurement (it is a discovery, not a prediction) — and which arm each individual test takes under the headless-denied gate (e.g. whether the OSC 7 cwd-classification tests still resolve local) is itself part of that measured record, not a prediction. **Why:** the whole thesis is same-binary divergence across shells; the evidence must distinguish a real arm from a degrade arm, which both report "passed." The clean **graphics** real-arm run (modal-free, correct OSC 7 classification) rides the sibling product fix `fix-osc7-hostname-reverse-dns` and is its task 2.1 — not measured here.

### D4 — Keep the guest's 59-char hostname on the zsh variant (inherit the base), treat prompt-width as measured-not-designed

The base image sets a 59-char single-label hostname for bash prompt-width parity (`add-vm-prompt-width-parity`). The zsh variant inherits it. Hostname length is orthogonal to the LN modal (the trigger is the reverse-DNS *query*, not the name's length — D2), so inheriting the base name is safe. Under zsh the prompt differs from bash's `\h:\W \u\$`, so prompt-width behavior is whatever the run shows; the find-bar assertion is already wrap-tolerant (`harden-findbar-wrap-assertion`), so it is robust either way. **Why not tune the hostname for zsh:** no evidence it's needed; changing it would diverge the two images for no measured reason. Recorded as a "measure it" observation, not a design lever.

### D5 — The divergence run is delegated to `xtty-test-validator`, pointed at the zsh golden, run **headless**

Per AGENTS.md, any verify task running a VM tier is delegated to `xtty-test-validator`; the task names the image to clone (`xtty-test-zsh:26.5`) and carries the `⟶ xtty-test-validator` marker. The standalone divergence run is **headless** (D2 — the graphics modal is un-neutralizable at the rig level, so a graphics acceptance arm on the unfixed build would just re-trigger it). The agent reads the (this-change-updated) envelope/matrix from `packer/README.md` at runtime — no agent-definition edit is required for a run pointed at a named golden. **Why not modify the validator here:** see Open Questions Q1; deferring avoids agent-definition-delivery churn that would collide with change 2's validator-interpretation update.

## Risks / Trade-offs

- **The LN arbiter is irreducible at the rig level** (`local-network-privacy-forensics.md` §2a, §8) → **materialized** — the `/etc/hosts` daemon fired the modal (routable-IPv4 PTR escapes to the local nameserver), and T7–T10 refuted every remaining rig-level lever. **Resolution (not just mitigation):** stop trying to neutralize at the rig — measure **headless** (modal is graphics-only) and take the durable fix at the product seam (`fix-osc7-hostname-reverse-dns`, the *active* sibling change). This risk is now a settled decision, not an open exposure.
- **Headless denies the gate rather than granting it, so OSC 7-dependent arms may degrade under the unfixed build** (the reverse-DNS lookup resolves to the default deny instead of a modal). **Mitigation:** that is a *measured* outcome, not a blocker — headless still exercises the OSC 133 command-boundary family live (no network), which is the bulk of the shell-dependent divergence; the OSC 7 cwd-classification arm is cleanly measured only on the fixed build's graphics run (`fix-osc7` task 2.1). Record which arm each test takes as the zsh envelope.
- **The zsh rig may surface *new* zsh-specific behavior** (fresh-guest `~/.zshrc` absent → injected integration must load cleanly; a different prompt width). **Mitigation:** that is exactly what measurement-first is for — record it as the zsh envelope rather than predict it; the find-bar assertion is already wrap-tolerant.
- **A second ~40 GB image** costs disk + a build. **Mitigation:** one parameterized template, APFS CoW clones, and the human-gated prereqs are unchanged from `add-xtty-test-image`.
- **Two goldens invite "which image did this run use?" confusion.** **Mitigation:** distinct tags (`xtty-test` vs `xtty-test-zsh`) and the validator's cleanup manifest naming the clone source.

## Migration Plan

Additive and reversible: a new `shell` var defaulting to `bash` leaves `make image` producing today's image unchanged; the zsh image is built explicitly. No product/runtime change to roll back. The LN daemon proved insufficient (D2) and ships no acceptance-path machinery; the zsh rig's standalone value is its **headless** divergence measurement, and its modal-free graphics run is unlocked by the sibling product fix `fix-osc7-hostname-reverse-dns` (land order: either first — this change is independently mergeable for the headless measurement).

## Open Questions

- **Q1 — Does the validator agent need a definition update to run the zsh golden, or does naming the clone source in the delegated task suffice?** Assumed sufficient (D5). If apply shows the agent hardcodes the golden name, sequence the definition edit with change 2's validator-interpretation update (one delivery, not two). Recorded so it isn't rediscovered.
- ~~**Q2 — Exact set of addresses the LN daemon must seed**~~ — **RESOLVED / MOOT** (D2). The daemon was refuted regardless of address set (routable-IPv4 PTR escapes the files module); no seeding recipe ships. Superseded by the headless-measurement + product-fix decision.
- **Q3 — The zsh rig's headless-vs-graphics parity** (the bash rig matches exactly post-menu-fix) — the standalone measurement is **headless only** (D2), so graphics parity on the *unfixed* build is not measured here; it is measured on the fixed build's graphics run (`fix-osc7` task 2.1). A headless-vs-graphics mismatch there is itself a finding.
