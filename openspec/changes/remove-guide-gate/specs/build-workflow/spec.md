## REMOVED Requirements

### Requirement: The clone arms its own repository hooks

**Reason**: The repository-managed guide-gate hook and its installer are retired.

**Migration**: Routine `make` commands no longer install or update a repository pre-push hook. `git config --unset xtty.guide-gate` alone disarms an already-installed hook; see the `agent-guide-budget` migration note for the full version-proof file-removal sequence, including the local `core.hooksPath` override case.

### Requirement: Continuous integration verifies the hook installer

**Reason**: The installer and tracked hook no longer exist, so their CI regression job has no purpose.

**Migration**: Remove `guide-gate` from required-check configuration if it was configured externally; the repository continues to publish `test-core` and `build-and-test`.
