## ADDED Requirements

### Requirement: Test image supports a zsh login-shell variant

The test-image build SHALL support producing, **in addition to the bash variant** (which matches the hosted-runner login shell — see "Test image matches the hosted-runner login shell"), a **zsh login-shell variant**, selected by a build parameter and produced from the **same pinned inputs and the same template**. The zsh variant SHALL configure the auto-login account's interactive login shell to **zsh**, so the guest exercises xtty's zsh-only OSC 7/133 shell integration exactly as a real user (and local development) does. The two variants SHALL coexist — the zsh variant **supplements** the bash variant (which remains the CI-parity, acceptance-bearing rig) rather than replacing it. The macOS Local Network privacy prompt that xtty's zsh-only OSC 7 host-name path can raise is a **product-level** concern that the image build does **not** resolve at the rig level; the zsh variant's standalone shell-dependent divergence SHALL therefore be exercisable **headless**, where that graphics-only prompt does not arise.

#### Scenario: The build produces a zsh-login-shell variant from the same template

- **WHEN** the image is built with the zsh shell parameter selected
- **THEN** a guest cloned from the resulting image has the auto-login account's login shell set to `/bin/zsh`, while the bash variant built from the same template still yields `/bin/bash`

#### Scenario: The zsh variant exercises the real shell-integration arm

- **WHEN** the test suite runs in a guest cloned from the zsh variant
- **THEN** xtty's OSC 133/7 semantic capture goes live (the guest's zsh emits the injected shell integration), so the shell-dependent family runs against a live integration and takes its real asserting path rather than the bash variant's early-returning (vacuous) arm
