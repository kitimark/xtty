## ADDED Requirements

### Requirement: Test image supports a zsh login-shell variant

The test-image build SHALL support producing, **in addition to the bash variant** (which matches the hosted-runner login shell — see "Test image matches the hosted-runner login shell"), a **zsh login-shell variant**, selected by a build parameter and produced from the **same pinned inputs and the same template**. The zsh variant SHALL configure the auto-login account's interactive login shell to **zsh**, so the guest exercises xtty's zsh-only OSC 7/133 shell integration exactly as a real user (and local development) does. The two variants SHALL coexist — the zsh variant **supplements** the bash variant (which remains the CI-parity, acceptance-bearing rig) rather than replacing it. The macOS Local Network privacy gate that xtty's zsh-only OSC 7 reverse-DNS host-name lookup trips is a **product-level** trigger that **cannot be neutralized at the rig/build level** (measured — no `defaults`/NE-store/`/etc/hosts`/SSH-child mechanism both persists across a clone boot and silences the gate); it is removed by the product change `fix-osc7-hostname-reverse-dns`. Consequently the zsh variant's shell-dependent divergence SHALL be measurable **headless** (where the graphics-only modal is moot), and a modal-free **graphics** UI run depends on that product fix rather than on any rig-level machinery.

#### Scenario: The build produces a zsh-login-shell variant from the same template

- **WHEN** the image is built with the zsh shell parameter selected
- **THEN** a guest cloned from the resulting image has the auto-login account's login shell set to `/bin/zsh`, while the bash variant built from the same template still yields `/bin/bash`

#### Scenario: The zsh variant exercises the real shell-integration arm

- **WHEN** the test suite runs in a guest cloned from the zsh variant
- **THEN** xtty's OSC 133/7 semantic capture goes live (the guest's zsh emits the injected shell integration), so the shell-dependent family runs against a live integration and takes its real asserting path rather than the bash variant's early-returning (vacuous) arm

#### Scenario: The Local Network gate is a product trigger, not neutralizable at the rig level

- **WHEN** the full UI suite runs in a **graphics** session in a guest cloned from the zsh variant, on a product build that still derives the local host name via reverse-DNS
- **THEN** the "find devices on local networks?" modal appears — the trigger is product-level and no build-time mechanism both persists across a clone boot and silences the gate — so standalone shell-divergence measurement runs **headless**, and a modal-free graphics run requires the product-level fix (`fix-osc7-hostname-reverse-dns`) rather than rig-level neutralization
