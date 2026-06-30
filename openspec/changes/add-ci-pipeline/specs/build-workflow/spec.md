## ADDED Requirements

### Requirement: Continuous integration on every push and pull request

The project SHALL run automated checks on hosted continuous integration for every push and every pull request, exercising the established build/test entry points and requiring **no repository secrets** (using the default ad-hoc "Sign to Run Locally" signing posture). CI SHALL provide a **fast gate** that runs the view-free `XttyCore` unit tests without building the app target, and a **separate non-blocking** job that builds the app and runs the UI tests; the non-blocking job MAY retry flaky tests and SHALL NOT block merges while its hosted-runner reliability is unproven. CI SHALL reconstitute the pinned/patched SwiftTerm dependency through the existing reconstitution path before compiling, and SHALL cache high-value inputs — at least the reconstituted dependency keyed on its pin plus patch — so routine runs avoid redundant work. CI SHALL be resilient to the runner environment not preinstalling a required build component (for example the Metal toolchain) by ensuring that component is present before building, rather than assuming it.

#### Scenario: Every push and pull request triggers CI

- **WHEN** a commit is pushed or a pull request is opened/updated
- **THEN** the continuous-integration checks run automatically without any manual trigger

#### Scenario: The fast core-test job is the gate and needs no app build

- **WHEN** CI runs on a change
- **THEN** the `XttyCore` unit tests run as a fast job that does not build the app target, and that job is the designated required gate (its failure marks the run failed)

#### Scenario: The UI-test job runs but does not block merges

- **WHEN** CI runs the app build + UI-test job
- **THEN** that job builds the app and runs the UI tests with retry tolerance, and a failure in it does not block the change from merging while its hosted-runner reliability is unproven

#### Scenario: CI requires no secrets

- **WHEN** CI builds and tests the app
- **THEN** it uses the default ad-hoc signing posture and requires no repository secrets or Apple credentials

#### Scenario: CI reconstitutes and caches the pinned dependency

- **WHEN** CI runs on a fresh runner
- **THEN** it reconstitutes the pinned/patched SwiftTerm dependency before compiling and caches it keyed on the pin plus patch, so a subsequent run with an unchanged pin/patch restores it instead of re-fetching

#### Scenario: CI is resilient to a missing build component

- **WHEN** the runner environment does not preinstall a build component the compile needs (e.g. the Metal toolchain)
- **THEN** CI ensures that component is present before building rather than failing, so the build succeeds regardless of whether the runner preinstalled it

### Requirement: Pull-request titles are checked against Conventional Commits

The project's continuous integration SHALL verify that pull-request titles conform to the repository's Conventional Commits convention, failing the check when a title does not match an allowed `type(scope): description` form and passing when it does. This check applies to pull requests (it does not gate direct pushes).

#### Scenario: A non-conforming pull-request title fails the check

- **WHEN** a pull request has a title that does not follow the Conventional Commits form
- **THEN** the title-convention check fails, signaling the title must be corrected

#### Scenario: A conforming pull-request title passes the check

- **WHEN** a pull request has a title of the form `type(scope): description` using an allowed type
- **THEN** the title-convention check passes
