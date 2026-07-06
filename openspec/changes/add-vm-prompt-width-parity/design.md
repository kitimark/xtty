## Context

The hosted runner and our Tart guest build their shell prompt by the **identical** mechanism — stock macOS `/etc/bashrc` `PS1='\h:\W \u\$ '` under a bash login shell (`runner-images` sets no `PS1`; our image already `chsh`-es to bash). The *only* differing field is `\h` (`gethostname`): ~61 chars on the runner (`sjc22-be105-…`, a datacenter name injected at runtime — not in the `runner-images` build, which sets only `Mac-<epoch>.local`), 24 chars in our guest (`Manageds-Virtual-Machine`). Prompt width = `len(\h) + ~11`, so the runner wraps a typed marker at ~80 columns and our guest does not. This is why `findbar-marker-wrap` was invisible to the VM. Full mechanism + probes + fates: [`ci-runner-prompt-width-forensics.md`](../../../research/03-analysis/ci-runner-prompt-width-forensics.md).

## Goals / Non-Goals

**Goals:**
- Make the guest reproduce the runner's prompt width so prompt-width-sensitive assertions surface **in-guest** before CI.
- Do it with the lever that actually governs width — hostname **length** — which we fully control; we do **not** need (and cannot derive) the runner's exact name.
- Keep the change **image + docs only**; preserve the bash login shell and the (bash-gated) absence of the Local Network prompt.
- Re-establish the acceptance envelope by **measurement**, not prediction.

**Non-Goals:**
- Product/app code; the find-bar assertion fix (`harden-findbar-wrap-assertion`); the paste residual fix; any `.github/workflows/` change.
- Matching the runner's *exact* hostname string (irrelevant — only length drives the wrap).

## Decisions

### D1: Set a long guest hostname via `scutil`, mirroring `runner-images`

Add a Packer provisioner to `packer/xtty-test.pkr.hcl` (alongside the existing `chsh` one) that sets a **~60-char single-label hostname** on all three keys — `scutil --set HostName / LocalHostName / ComputerName` — mirroring `runner-images`' `configure-hostname.sh` (which sets all three). A single fixed long name suffices: unlike the runner fleet, we have one image and don't need the per-boot epoch-randomization the runner uses to de-dup across a fleet. Target length ≥ ~58 chars (a single DNS label caps at 63) so that `len(\h) + prompt-tail + a ~13-char marker` exceeds the guest's column width — matching the runner's ~61.

### D2: Set all three keys, and **verify by effect** (the gethostname spike)

Bash `\h` reads `gethostname(3)`, whose backing key on macOS is not fixed: on the dev host, `\h` rendered `LocalHostName + .local` while `HostName` was *unset*. So which key wins **inside a NAT'd Tart guest** is unverified — hence set all three defensively, then **verify by effect**: boot a guest, type a marker at the prompt, and confirm the grid dump splits it across ≥2 physical rows (not a read-back of the `PS1` string). If it does not wrap, the guest `\h` is reading an unset/short key or the guest window is wider than assumed → adjust (lengthen the name / confirm the effective key) before trusting the re-baseline. This is the one open unknown and it is a precondition for the rest of the change.

### D3: Re-establish the acceptance envelope by measurement (validator-delegated)

A wide prompt shifts the *failing signature* of prompt-typing tests, so the envelope must be re-measured on **both** rigs (headless + graphics), delegated to `xtty-test-validator`. Expected outcome (to confirm, not assume): applied **alone** (before the fix), `testFindBarOpensLocatesAndDismisses` **reds under the wide prompt** — the repro proof (D5); after `harden-findbar-wrap-assertion` it **greens**. The `testMultiLinePasteIsNotAutoExecuted` residual's failing line shifts from the `command not found` check (`:87`) to the wrap (`:84`), matching the runner; the final count (find-bar green) likely stays `39/1/1`. The measurement's purpose is to catch a *previously-hidden* wrap in some other type-at-prompt assertion — if one appears, it is a newly-surfaced (real, benign-or-not) residual to classify, exactly the fidelity this change buys.

> **Measured outcome (2026-07-07, validator full sweep — this is why D3 says "measured, not predicted").** Interim VM envelope = **`38/2/1` of 41**, identical on headless ×2 + graphics. `testFindBarOpensLocatesAndDismisses` reds in-guest as predicted (repro proof; D2 verified by effect — the marker soft-wraps, grid dump `…admin$ AFTERFIND`/`786`). **The paste prediction was refuted:** its failing line did **not** shift `:87`→`:84` — it **stayed `:87`**, because bash 3.2 executes the pasted newline so line B echoes contiguously and fits before col 80 (the `:84` check still passes). No *other* type-at-prompt test newly wrapped. Trackers updated same session: `packer/README.md` Acceptance/matrix + `ci-runner-prompt-width-forensics.md` §4 (T6) / §6. Evidence: `~/Downloads/xtty-vm-poc/artifacts/2026-07-06-vm-prompt-width-parity-rebaseline/`.

### D4: Safety — the Local Network prompt stays gone

Lengthening `\h` cannot resurrect the LN modal: the reverse-DNS path is `ProcessInfo.hostName` → PTR of every local **address** (address count, not hostname length) and runs only under a zsh OSC 7 emission; the guest is bash, so the path is dead regardless of hostname (`local-network-privacy-forensics.md`; `scutil --set HostName` measured inert for that gate). The change keeps `chsh -s /bin/bash`. The spec carries a scenario asserting the modal still does not appear.

### D5: Sequence BEFORE `harden-findbar-wrap-assertion` — reproduce the red first

Apply this change first, then `harden-findbar-wrap-assertion`, as a **red→green pair on one rebuilt image**:
- **After #2 alone** (wide prompt, find-bar assertion still strict): `testFindBarOpensLocatesAndDismisses` **reds in-guest** — the same failure CI shows. This red is the *acceptance signal for #2*: it proves the guest now reproduces the runner's prompt width (the parity worked).
- **After #1** (wrap-tolerant matcher; same image, no rebuild — the source is not baked in): find-bar **greens in-guest**, proving the fix against the live repro.

This is a stronger proof than measuring with the fix already present, and it costs one image rebuild for both. The interim find-bar red is a **pre-registered, transient repro observation, not a documented residual**; the *final* documented envelope (find-bar green) is established after #1. This is an ordering constraint on *apply*, not a spec dependency (both changes remain independently valid).

### D6: Reverse-duty tracker updates land in the same session

Update `packer/README.md` Acceptance + the expected-difference matrix to the re-measured envelope (record the paste residual now failing at the wrap line under the wide prompt), and add a dated Option-C line to the forensics doc.

## Risks / Trade-offs

- **The gethostname effective key in the Tart guest is unverified** (D2) → *Mitigation:* set all three keys; verify by effect (marker wraps) before relying on it; the change cannot be accepted until the wrap is observed in-guest.
- **The image rebuild is heavy and human-gated** (`make image`: Packer + the one-time Apple-ID Xcode `.xip`) → *Mitigation:* the provisioner edit is tiny; the rebuild is an owner step, like other image work; the re-baseline runs on the rebuilt image.
- **A previously-hidden wrap in another type-at-prompt test could newly red under the wide prompt** → *Mitigation:* this is the intended fidelity; the validator-delegated re-baseline surfaces and classifies it rather than it lurking until CI.
- **Marginal value overlaps `harden-findbar-wrap-assertion`'s guard** — once find-bar is fixed, this won't catch find-bar; its value is *general* prompt-width fidelity for future type-at-prompt tests → *Accepted:* deliberate harness investment, priced against the re-baseline.

## Open Questions

- ~~Which of `HostName` / `LocalHostName` / `ComputerName` backs bash `\h` inside the NAT'd Tart guest?~~ **Resolved (2026-07-07, forensics T6 closed):** setting **all three** keys makes the NAT'd guest's `\h` read the long 59-char name — verified by effect (the marker wraps) on all three clones. D2's defensive "set all three" was the right call; the effective key didn't need to be isolated.
