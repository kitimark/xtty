# build-workflow — delta for retire-metal-renderer

## MODIFIED Requirements

### Requirement: Prerequisite check

The project SHALL provide a command that verifies the prerequisites it cannot install automatically — the project generator and a full Xcode toolchain — and reports clearly which are missing along with how to install each, without attempting privileged installation itself.

#### Scenario: Missing prerequisite is reported
- **WHEN** a required prerequisite is not present
- **THEN** the check names the missing prerequisite and the command to install it, and exits non-zero

#### Scenario: Check passes when prerequisites are present
- **WHEN** all prerequisites are present
- **THEN** the check reports success and exits zero, without attempting any privileged install
