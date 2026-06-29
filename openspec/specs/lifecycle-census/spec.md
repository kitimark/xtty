# lifecycle-census Specification

## Purpose

Defines xtty's **lifecycle leak guard** — the P7c hardening behind the "lean memory / avoid retain cycles" product value. The durable deliverable is a DEBUG-only **live-instance census**: a per-type count of the lifecycle-bearing objects (the window controller, pane controller, terminal-view wrapper, the git-review and quick-terminal accessory controllers, and the view-free terminal session), incremented on creation and decremented on destruction, surfaced through the verification harness's state dump. A **churn assertion** that those counts return to their pre-churn baseline after panes/splits/tabs/windows are created and destroyed is the gated leak-regression net — deterministic (a stuck count is a leaked instance / retain cycle), unlike a noisy memory-footprint delta. In-process **deallocation tests** cover the view-free model types where a test can hold a weak reference (the App-layer controllers/views run out-of-process under XCUITest and can only be observed via the census). A re-runnable, **non-gating** OS leak/allocation audit command surfaces what the per-type census cannot name (third-party engine/renderer internals — notably SwiftTerm's unbounded glyph/font caches). All census instrumentation is DEBUG-only with no shipping-build overhead. Observability of the census through the state dump is specified by `verification-harness`; the renderer/memory-measurement gate is a separate concern (`performance-harness`).

## Requirements
### Requirement: Live-instance census of lifecycle-bearing types

The app SHALL maintain, **in DEBUG builds only**, a live-instance count for each lifecycle-bearing type — at minimum the window controller, the pane controller, the terminal-view wrapper, the git-review controller, the quick-terminal accessory controller, and the (view-free) terminal session — incremented when an instance is created and decremented when it is destroyed. The census MUST be a deterministic integer count (not a memory estimate). The census and its counters SHALL be absent — no code and no runtime overhead — in shipping (non-DEBUG) builds, and SHALL NOT alter any user-visible behavior.

#### Scenario: Census reflects creation and destruction

- **WHEN** a DEBUG build creates a lifecycle-bearing instance (e.g. a new pane) and later destroys it
- **THEN** that type's live-instance count rises by one on creation and falls by one on destruction

#### Scenario: Census is absent from shipping builds

- **WHEN** a non-DEBUG (shipping) build runs
- **THEN** the census counters and their increment/decrement hooks are not present, and no user-visible behavior depends on them

### Requirement: No leaked instances across lifecycle churn

After repeatedly creating and destroying panes, splits, tabs, and windows and returning to the starting layout, the live-instance counts SHALL return to their pre-churn baseline. A count that fails to return to baseline indicates a retained instance — a leak or retain cycle — and MUST be observable (not silently absorbed), so it can fail an automated check. This deterministic instance check — not a memory-footprint measurement — is the gated leak-regression assertion.

#### Scenario: Counts return to baseline after churn

- **WHEN** a sequence of create-then-destroy cycles over panes/splits/tabs/windows runs and the layout returns to its starting point
- **THEN** every lifecycle type's live-instance count returns to the pre-churn baseline

#### Scenario: A retained instance is detectable

- **WHEN** a lifecycle-bearing instance is retained past its expected destruction (e.g. a reintroduced retain cycle)
- **THEN** its live-instance count stays elevated above baseline after churn, so an automated check can detect the leak rather than missing it silently

### Requirement: In-process deallocation tests for view-free model types

The view-free model types in the engine-facing package (the terminal session, the session registry, and the pane) SHALL be covered by **in-process** unit tests that assert an instance is deallocated once released — i.e. no retained reference survives teardown. These tests SHALL be exercisable without launching the app or creating a terminal view, complementing the out-of-process census (which cannot hold a reference to an in-app object).

#### Scenario: A released model instance is confirmed deallocated

- **WHEN** an in-process unit test creates a view-free model instance, holds only a weak reference, releases the strong reference, and runs teardown
- **THEN** the weak reference becomes nil, confirming the instance was deallocated (no retain cycle)

### Requirement: Re-runnable leak/allocation audit command

The project SHALL provide a single documented command that runs the operating system's leak/allocation detection against the built app and records the output for review. It SHALL require no privileged installation and no entitlement beyond what a local debug build already carries. It SHALL be a **diagnostic aid only — explicitly not a pass/fail CI gate**: the normal build and test entry points MUST NOT depend on it, and a finding from it MUST NOT fail the standard build/test path. Its purpose is to surface allocation/leak behavior the per-type census cannot name (notably third-party engine/renderer internals), whose findings inform the census and are recorded in research, not this spec.

#### Scenario: The audit command runs the OS leak detector and writes a report

- **WHEN** a developer runs the leak-audit command against the built app
- **THEN** it runs the operating system's leak/allocation detection headlessly and writes its output to a file for review, without requiring a privileged install

#### Scenario: The audit is a diagnostic, not a gate

- **WHEN** the standard build and test entry points run
- **THEN** they do not invoke the leak-audit command, and a leak-audit finding does not fail the standard build/test path

