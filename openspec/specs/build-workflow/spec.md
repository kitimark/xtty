# build-workflow Specification

## Purpose

The build/setup contract for xtty — how a contributor goes from a fresh clone to a running, tested app. It defines: reproducible reconstruction of the patched-but-pinned SwiftTerm dependency from version-controlled inputs alone (a pinned ref + a tracked patch, without committing the upstream tree); generation of the **untracked** Xcode project from the tracked `project.yml`; single-command build/run/test entry points that perform any prerequisite reconstitution and generation automatically (plus a fast view-free `XttyCore` test path); a prerequisite check for the components that can't be auto-installed; self-documenting entry points; the requirement that the canonical build docs stay accurate (no superseded mechanism described as current); and a reproducible minimal local VM test image (built from pinned inputs plus a one-time human-provided Xcode archive, simulator- and Metal-toolchain-free) for CI-parity in-guest build+test. This is a **meta/tooling** capability — it constrains the developer workflow and its documentation, not app runtime behavior — recorded as a source of truth so the build contract (previously only drift-prone prose) has something authoritative to fail against. Parallels the `verification-harness` spec. The concrete entry point is the top-level `Makefile`.
## Requirements
### Requirement: Reproducible patched-SwiftTerm reconstitution

The build SHALL reconstitute the patched SwiftTerm dependency from version-controlled inputs alone — a pinned upstream ref plus a tracked patch — without committing the upstream source tree. Reconstitution SHALL be idempotent and SHALL enforce the pin on every run so the working checkout cannot drift. When the pin and the patch are unchanged since the last reconstitution, a subsequent build SHALL NOT need to re-run reconstitution.

#### Scenario: Fresh checkout reconstitutes before compiling
- **WHEN** the build entry point runs on a fresh clone where the upstream SwiftTerm tree is absent
- **THEN** it reconstitutes the tree from the pinned ref and the tracked patch before compiling, with no manual steps beyond the documented entry point

#### Scenario: Reconstitution is idempotent and pin-enforcing
- **WHEN** reconstitution runs again over an existing checkout
- **THEN** it restores a pristine tree at the pinned ref and re-applies the patch without error (no drift and no duplicate/failed patch application)

#### Scenario: Reconstitution is skipped when inputs are unchanged
- **WHEN** the pin and the patch have not changed since the last successful reconstitution
- **THEN** a subsequent build does not re-run reconstitution

### Requirement: Generated Xcode project from a tracked source of truth

The Xcode project SHALL be generated from the tracked project definition (`project.yml`) and SHALL NOT itself be tracked in version control. A build SHALL regenerate the project when the project definition has changed (or the generated project is absent) and SHALL NOT require the developer to regenerate it manually in that case.

#### Scenario: Project is regenerated when its definition changes
- **WHEN** the tracked project definition is newer than the generated project, or the generated project is missing
- **THEN** the build regenerates the project before compiling

#### Scenario: Generated project is never committed
- **WHEN** version control status is inspected
- **THEN** the generated `.xcodeproj` is ignored and not tracked

### Requirement: Single-command build, test, and run entry points

The project SHALL provide a single documented command each to build the app, run the app, run the fast view-free `XttyCore` unit tests, and run the app UI tests. Each entry point SHALL automatically perform any prerequisite reconstitution and project generation. The fast core-test path SHALL be runnable without building the full app target.

#### Scenario: One command builds the app
- **WHEN** a developer runs the build entry point on a machine with prerequisites satisfied
- **THEN** the app builds without the developer invoking reconstitution or project generation separately

#### Scenario: Fast core tests run without the app
- **WHEN** a developer runs the core-test entry point
- **THEN** the `XttyCore` unit tests run without building the app target

#### Scenario: Run builds then launches
- **WHEN** a developer runs the run entry point
- **THEN** the app is built (reconstituting/generating as needed) and then launched

### Requirement: Prerequisite check

The project SHALL provide a command that verifies the prerequisites it cannot install automatically — the project generator and a full Xcode toolchain — and reports clearly which are missing along with how to install each, without attempting privileged installation itself.

#### Scenario: Missing prerequisite is reported
- **WHEN** a required prerequisite is not present
- **THEN** the check names the missing prerequisite and the command to install it, and exits non-zero

#### Scenario: Check passes when prerequisites are present
- **WHEN** all prerequisites are present
- **THEN** the check reports success and exits zero, without attempting any privileged install

### Requirement: Self-documenting entry points

Invoking the entry point with no target (or an explicit help target) SHALL list the available commands with a one-line description for each, so the workflow is discoverable without reading external documentation.

#### Scenario: Help lists the available targets
- **WHEN** the developer invokes the entry point with no target
- **THEN** it prints the available targets each with a short description of what it does

### Requirement: Build/setup documentation is accurate and current

The canonical build/setup documentation SHALL describe the *current* mechanism accurately and SHALL NOT present a superseded mechanism as current. On every surface that states how things work now, the SwiftTerm dependency SHALL be described as a gitignored upstream clone reconstituted from a pinned ref with an applied tracked patch — and no superseded form (a git submodule, a `cp` drop-in copy, or a removed patch file) SHALL be named as the current mechanism. The single-command entry points SHALL be documented as the primary path, with the underlying raw commands retained for reference.

#### Scenario: Current-truth surfaces name only the current mechanism
- **WHEN** any "how it works now" surface (build scripts and their headers, the project/package manifests, and the canonical build docs) describes how the SwiftTerm dependency is consumed
- **THEN** it describes the current mechanism and names no superseded form (submodule, drop-in copy, or a deleted patch file) as current

#### Scenario: Single-command path is the documented primary
- **WHEN** a contributor reads the canonical build documentation
- **THEN** the single-command entry points are presented as the primary path and the underlying raw commands remain documented for reference

### Requirement: Optional stable local code-signing identity

The project SHALL provide an **opt-in** way to build with a stable local code-signing identity so that operating-system permission grants tied to the app's code identity (e.g. the Screen Recording grant the performance harness needs) persist across rebuilds instead of re-prompting. It SHALL include a helper that creates a self-signed **code-signing** certificate in the developer's keychain without modifying the system trust store or requiring privileged installation, and a build-entry-point override that, **when explicitly enabled**, signs the app with that identity. When the override is **not** enabled, the build SHALL retain the default ad-hoc ("Sign to Run Locally") signing so a fresh clone and CI are unaffected (no developer-specific signing configuration is committed). This affordance covers local development only; Developer ID, Hardened Runtime, and notarization remain out of scope.

#### Scenario: Default build stays ad-hoc and portable

- **WHEN** the stable-signing override is not enabled
- **THEN** the build signs ad-hoc as before, and no developer-specific signing identity is required or committed

#### Scenario: Enabling the override signs with the stable identity

- **WHEN** the developer has created the local signing identity and enables the override for a build
- **THEN** the app is signed with that identity (a cert-based code identity stable across rebuilds) rather than ad-hoc

#### Scenario: The identity helper needs no privileged install or system trust change

- **WHEN** the developer runs the identity-creation helper
- **THEN** it creates a self-signed code-signing certificate usable by the local signing toolchain without modifying the system trust store and without a privileged (sudo) installation

#### Scenario: A persisted grant survives a rebuild

- **WHEN** an OS permission keyed to the app's code identity has been granted for a build made with the stable identity, and the app is rebuilt with the same identity
- **THEN** the grant still applies to the rebuilt app without re-prompting

### Requirement: Reproducible minimal local VM test image

The project SHALL provide a reproducible way to build a **minimal local macOS virtual-machine test image** capable of building xtty and running the **full test suite, including the UI tests**, inside the guest. The image SHALL require **neither the iOS/watchOS/tvOS simulator platforms nor the Metal toolchain**. It SHALL be buildable from **pinned, version-controlled inputs** — the operating-system base image and the Xcode version — plus a **one-time human-provided official Apple installer archive**, and the image build itself SHALL NOT require Apple credentials. The image SHALL be generic: it SHALL NOT bake in the project source — the source arrives in a per-run copy of the image at test time.

#### Scenario: Building from pinned inputs yields a full-suite-capable image

- **WHEN** the image is built from its pinned inputs (the pinned OS base and the pinned Xcode version) with the pre-downloaded Apple installer archive present
- **THEN** the build completes and produces an image in which the project builds and the full test suite, including the UI tests, can run in-guest

#### Scenario: The image build requires no Apple credentials

- **WHEN** the image build runs
- **THEN** it installs Xcode from the pre-downloaded official Apple installer archive and completes without authenticating to Apple (the archive download is a separate one-time, human-performed, Apple-ID-authenticated step)

#### Scenario: The guest has no Metal toolchain yet builds xtty

- **WHEN** the resulting guest is inspected for the Metal toolchain component and the project is then built there
- **THEN** the Metal toolchain component is reported as not installed, and the project build nevertheless succeeds

### Requirement: Test image matches the hosted-runner login shell

The local VM test image SHALL configure the guest's default interactive login shell to **bash**, matching the GitHub-hosted macOS runner environment (whose provisioning sets the runner account's shell to `/bin/bash`). This SHALL apply to the account under which the in-guest test suite runs (the auto-login account). The intent is fidelity: under bash, the shell environment the suite runs in matches CI, and — as a consequence — xtty performs no OSC 7 working-directory reporting, so a graphics UI run does not surface the macOS Local Network privacy prompt that a zsh login shell otherwise triggers. Reproducing what the image tests (e.g. the per-launch main-menu race) SHALL NOT depend on the login shell.

#### Scenario: The guest login shell is bash

- **WHEN** a guest cloned from the built image is inspected for the auto-login account's login shell
- **THEN** it is `/bin/bash`, matching the GitHub-hosted runner

#### Scenario: A graphics UI run does not surface the Local Network prompt

- **WHEN** the full UI suite runs in a graphics session in a guest cloned from the image
- **THEN** no "Allow … to find devices on local networks?" modal appears to steal focus, and the run reproduces the same menu-race result as the reference (hosted-runner / frozen-xcode) rigs

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

### Requirement: Test image supports a zsh login-shell variant

The test-image build SHALL support producing, **in addition to the bash variant** (which matches the hosted-runner login shell — see "Test image matches the hosted-runner login shell"), a **zsh login-shell variant**, selected by a build parameter and produced from the **same pinned inputs and the same template**. The zsh variant SHALL configure the auto-login account's interactive login shell to **zsh**, so the guest exercises xtty's zsh-only OSC 7/133 shell integration exactly as a real user (and local development) does. The two variants SHALL coexist — the zsh variant **supplements** the bash variant (which remains the CI-parity, acceptance-bearing rig) rather than replacing it. The macOS Local Network privacy prompt that xtty's zsh-only OSC 7 host-name path can raise is a **product-level** concern that the image build does **not** resolve at the rig level; the zsh variant's standalone shell-dependent divergence SHALL therefore be exercisable **headless**, where that graphics-only prompt does not arise.

#### Scenario: The build produces a zsh-login-shell variant from the same template

- **WHEN** the image is built with the zsh shell parameter selected
- **THEN** a guest cloned from the resulting image has the auto-login account's login shell set to `/bin/zsh`, while the bash variant built from the same template still yields `/bin/bash`

#### Scenario: The zsh variant exercises the real shell-integration arm

- **WHEN** the test suite runs in a guest cloned from the zsh variant
- **THEN** xtty's OSC 133/7 semantic capture goes live (the guest's zsh emits the injected shell integration), so the shell-dependent family runs against a live integration and takes its real asserting path rather than the bash variant's early-returning (vacuous) arm

### Requirement: Stable local install of the optimized build

The project SHALL provide a single documented command that builds the **optimized (Release) configuration** and installs a **self-contained copy** of the app into a target applications directory, so a contributor can daily-drive a stable build independent of the volatile build-output directory. The default target directory SHALL be the system `/Applications`, overridable by the contributor without editing tracked files. The installed app SHALL be a **copy**, not a symlink or other reference into the build-output directory, so it survives cleaning of build outputs. Any existing installed bundle SHALL be preserved (backed up) before it is replaced. The install SHALL reuse the project's existing signing posture — ad-hoc by default, or the opt-in stable local identity — and SHALL require **no notarization and no Apple credentials**. This command SHALL NOT alter the existing Debug build/run entry points, which remain the iteration path.

#### Scenario: Install builds the optimized configuration and copies it to the target directory

- **WHEN** a contributor runs the install command on a machine with prerequisites satisfied
- **THEN** the app is built in the optimized (Release) configuration and a self-contained copy of it is placed in the target applications directory (default `/Applications`), performing any prerequisite reconstitution/generation automatically

#### Scenario: The installed app survives cleaning of build outputs

- **WHEN** the build-output directory is subsequently removed (e.g. the clean entry point runs)
- **THEN** the installed app in the applications directory still exists and still launches (it is a copy, not a reference into the build outputs)

#### Scenario: An existing install is preserved before replacement

- **WHEN** the install command runs while a previously installed bundle is already present in the target directory
- **THEN** the existing bundle is backed up before the new copy replaces it

#### Scenario: The default install requires no Apple credentials

- **WHEN** the install command runs without the opt-in stable-signing override enabled
- **THEN** the app is signed ad-hoc as usual and installs and launches without any Apple account, Developer ID, or notarization step, and no Gatekeeper approval prompt is required (a locally built app is not quarantined)

#### Scenario: The target directory is overridable

- **WHEN** the contributor invokes the install command with an alternate applications directory selected
- **THEN** the app is installed into that directory instead of the default, without editing any tracked file

### Requirement: Installed build is version-stamped from version control

The install SHALL stamp the installed app with a version derived from version control: a **human-facing short version** taken from the latest reachable release tag, **falling back to the committed project version** when no tag is reachable, plus a **monotonic build number**. Both stamped values SHALL be valid for the platform's version fields — in particular the short version SHALL be numeric (up to three dot-separated integers) rather than an arbitrary descriptive string. The stamping SHALL occur in the install build path itself and SHALL NOT be deferred to a separate release-only path (so the locally installed app never carries an unstamped placeholder). Any richer descriptive build identifier (e.g. one carrying a commit hash or dirty-tree marker) SHALL be carried in a field **separate** from the two platform version fields, leaving those numeric.

#### Scenario: The installed app is stamped from the latest tag

- **WHEN** the install command runs on a commit reachable from a release tag
- **THEN** the installed app's short version reflects that tag (as a numeric version) and its build number reflects a monotonic value derived from version control

#### Scenario: Version falls back when no tag is reachable

- **WHEN** the install command runs where no release tag is reachable (or version control is unavailable)
- **THEN** the installed app's short version falls back to the committed project version rather than an empty or non-numeric value

#### Scenario: The stamped short version is a valid numeric version

- **WHEN** the installed app's short version field is inspected
- **THEN** it is a numeric version string (up to three dot-separated integers), and any commit-hash/dirty descriptive identifier appears only in a separate field

### Requirement: Reinstall and relaunch helper

The project SHALL provide a documented helper command that relaunches the freshly installed app, terminating any currently running instance first, so the build → install → run loop is a single step.

#### Scenario: The helper relaunches the installed app

- **WHEN** the contributor runs the relaunch helper after installing
- **THEN** any running instance is terminated and the installed app is launched from the applications directory

