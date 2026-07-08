## MODIFIED Requirements

### Requirement: Committed test-validation agent tooling

The repository SHALL provide **version-controlled** Claude Code tooling that runs xtty's test suite across the validation environments — the fast core tier, the local bare-metal suite, the headless (bash) VM rig, the graphics (bash) VM rig, and the **zsh real-coverage VM rig** — in an **isolated agent context** so the execution noise (polling, remote-shell output, build/test logs) does not enter the invoking session, which receives only the agent's report. The **zsh rig** exists because ~half the suite is shell-dependent (OSC 133/7 capture is zsh-only; bracketed paste needs a readline the bash rigs' macOS bash 3.2 lacks): the full suite runs on every rig, with each shell-dependent test taking its **capability-present assertion arm** on the zsh rig and its **capability-absent arm** (asserting the correct alternative behavior, or — as a last resort — skipping) on a bash rig, so a bash-rig **skip** is an *expected* last-resort outcome covered for real on the zsh rig, never a coverage gap. The tooling SHALL include the **agent** and a **thin launcher command**; the launcher SHALL invoke the agent rather than restating its content. The agent SHALL support running any requested subset of tiers, with documented defaults (a quick-confirm subset by default; a full sweep — including at least two headless VM runs — for product-code changes, because per-launch races are not settled by a single run).

#### Scenario: The tooling is version-controlled

- **WHEN** the repository is cloned and the committed tooling files are inspected
- **THEN** the test-validation agent and its launcher command are present and tracked by git (not gitignored), while machine-local and tool-generated `.claude` files remain ignored

#### Scenario: Execution noise stays out of the invoking session

- **WHEN** a validation sweep is run through the agent
- **THEN** the tier execution (VM boots, remote-shell polling, build/test logs) happens in the agent's own context and the invoking session receives only the verdict report

#### Scenario: Shell-dependent coverage comes from the zsh rig

- **WHEN** the shell-dependent tests are validated
- **THEN** they run on the zsh VM rig, where the shell capability is present so each asserts its capability-present arm for real, and the corresponding bash-rig outcome (the asserted capability-absent arm, or a last-resort skip) is classified as **expected** — its real coverage carried by the zsh rig — rather than as an unexplained gap
