## ADDED Requirements

### Requirement: Test image reproduces the hosted-runner prompt width

The local VM test image SHALL configure the guest so that its interactive login-shell prompt is **as wide as the GitHub-hosted macOS runner's**, such that content typed at the prompt soft-wraps across physical grid rows exactly as it does on the hosted runner. The intent is fidelity: a prompt-width-sensitive behavior — such as an out-of-process grid assertion about text typed behind a long prompt — SHALL surface in-guest before it reaches CI, rather than passing in-guest while failing only on the runner. This SHALL NOT change the guest's login shell (which remains bash) and SHALL NOT resurface the macOS Local Network privacy prompt. The image's documented acceptance envelope SHALL be re-established by measurement under the wide prompt (a long prompt could expose a previously-hidden soft-wrap in another type-at-prompt assertion).

#### Scenario: A marker typed at the guest prompt soft-wraps as on the runner

- **WHEN** a unique marker is typed at the interactive login-shell prompt in a guest cloned from the built image and the grid dump is inspected
- **THEN** the prompt is wide enough that the marker soft-wraps across at least two physical rows, matching the hosted-runner condition (rather than fitting on one row as under a short guest hostname)

#### Scenario: A prompt-width-fragile assertion behaves in-guest as on the runner

- **WHEN** the full UI suite runs in a guest cloned from the image
- **THEN** a soft-wrap-robust content assertion passes under the wide prompt while a strict (wrap-intolerant) one fails, matching the hosted-runner outcome — so a prompt-width flake is caught in-guest rather than only on CI — and the image's documented acceptance envelope reflects the re-measured result

#### Scenario: The wide prompt does not resurrect the Local Network prompt

- **WHEN** a graphics UI run executes in a guest cloned from the image with the wide prompt configured
- **THEN** no "Allow … to find devices on local networks?" modal appears (the guest login shell remains bash, so no OSC 7 reverse-DNS path runs regardless of hostname length)
