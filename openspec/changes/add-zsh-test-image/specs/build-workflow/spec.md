## ADDED Requirements

### Requirement: Test image supports a zsh login-shell variant

The test-image build SHALL support producing, **in addition to the bash variant** (which matches the hosted-runner login shell — see "Test image matches the hosted-runner login shell"), a **zsh login-shell variant**, selected by a build parameter and produced from the **same pinned inputs and the same template**. The zsh variant SHALL configure the auto-login account's interactive login shell to **zsh**, so the guest exercises xtty's zsh-only OSC 7/133 shell integration exactly as a real user (and local development) does. Because that integration makes xtty read its own host name via a reverse-DNS path that trips the macOS Local Network privacy gate, the zsh variant SHALL **neutralize that gate at the rig level, without modifying xtty's product code**, so the full UI suite is runnable in a graphics session without a "find devices on local networks?" modal stealing focus. The two variants SHALL coexist — the zsh variant **supplements** the bash variant (which remains the CI-parity, acceptance-bearing rig) rather than replacing it.

#### Scenario: The build produces a zsh-login-shell variant from the same template

- **WHEN** the image is built with the zsh shell parameter selected
- **THEN** a guest cloned from the resulting image has the auto-login account's login shell set to `/bin/zsh`, while the bash variant built from the same template still yields `/bin/bash`

#### Scenario: The zsh variant exercises the real shell-integration arm

- **WHEN** the test suite runs in a guest cloned from the zsh variant
- **THEN** xtty's OSC 133/7 semantic capture goes live (the guest's zsh emits the injected shell integration), so shell-dependent tests take their real asserting arm rather than the bash variant's graceful-degradation arm

#### Scenario: A graphics UI run under zsh does not surface the Local Network prompt

- **WHEN** the full UI suite runs in a graphics session in a guest cloned from the zsh variant
- **THEN** no "Allow … to find devices on local networks?" modal appears to steal focus, even though xtty's zsh OSC 7 reverse-DNS path runs — the gate is satisfied at the rig level with no change to xtty's product code
