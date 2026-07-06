## ADDED Requirements

### Requirement: Test image matches the hosted-runner login shell

The local VM test image SHALL configure the guest's default interactive login shell to **bash**, matching the GitHub-hosted macOS runner environment (whose provisioning sets the runner account's shell to `/bin/bash`). This SHALL apply to the account under which the in-guest test suite runs (the auto-login account). The intent is fidelity: under bash, the shell environment the suite runs in matches CI, and — as a consequence — xtty performs no OSC 7 working-directory reporting, so a graphics UI run does not surface the macOS Local Network privacy prompt that a zsh login shell otherwise triggers. Reproducing what the image tests (e.g. the per-launch main-menu race) SHALL NOT depend on the login shell.

#### Scenario: The guest login shell is bash

- **WHEN** a guest cloned from the built image is inspected for the auto-login account's login shell
- **THEN** it is `/bin/bash`, matching the GitHub-hosted runner

#### Scenario: A graphics UI run does not surface the Local Network prompt

- **WHEN** the full UI suite runs in a graphics session in a guest cloned from the image
- **THEN** no "Allow … to find devices on local networks?" modal appears to steal focus, and the run reproduces the same menu-race result as the reference (hosted-runner / frozen-xcode) rigs
