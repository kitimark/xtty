## ADDED Requirements

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
