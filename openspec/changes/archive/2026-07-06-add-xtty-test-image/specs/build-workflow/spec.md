# build-workflow — Delta for add-xtty-test-image

## ADDED Requirements

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
