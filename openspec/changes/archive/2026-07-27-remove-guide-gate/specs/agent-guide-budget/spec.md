## REMOVED Requirements

### Requirement: The eagerly-injected agent guide is bounded by a mechanical gate below the agent

**Reason**: The owner has retired the guide-gate because its maintenance and CI surface are not worth the protection it provides.

**Migration**: No replacement gate is provided. Keep current-status text bounded by the remaining advisory research-capture convention.

### Requirement: The meter measures the whole eagerly-injected surface, from the committed tree

**Reason**: The byte meter is removed with the guide-gate.

**Migration**: None.

### Requirement: The comparator permits shrinking and unchanged pushes, and never freezes unrelated work

**Reason**: The push comparator is removed with the guide-gate.

**Migration**: None.

### Requirement: The guide cannot be vaporized, deleted, or re-routed past the gate

**Reason**: The deletion and vaporization checks are removed with the guide-gate.

**Migration**: Normal Git review is responsible for detecting unintended guide deletion.

### Requirement: The gate fails closed on its own failure, and never claims an action it did not take

**Reason**: There is no longer a repository-managed guide gate.

**Migration**: None.

### Requirement: The gate acts only on the repository it was installed for

**Reason**: The hook installer and repository identity stamp are removed.

**Migration**: `git config --unset xtty.guide-gate` alone fully disarms an already-installed hook — its identity guard exits 0 without that stamp, regardless of the hook file's content or vintage. To also remove the installed file itself, verify ownership by version-proof comparison — `git hash-object "$(git rev-parse --git-common-dir)/hooks/pre-push"` against that clone's own recorded `xtty.guide-gate-hook-sha`, **not** byte-identity to the now-deleted tracked source (the hook had 8 tracked revisions, so a legitimately-owned older install will not match the final one and would otherwise be misclassified as foreign) — then delete only a match and run `git config --unset xtty.guide-gate-hook-sha`. If `core.hooksPath` was ever set locally to point at this repository's own hooks directory (the installer's global-`core.hooksPath` accommodation), also restore or remove that local override.

### Requirement: The ceiling is a measured ratchet

**Reason**: The guide-size ceiling and ratchet are retired.

**Migration**: None.

### Requirement: A refused append is parked, never lost

**Reason**: Pushes will no longer be refused for guide size.

**Migration**: Continue placing full narratives in `HISTORY.md` and durable findings in `research/`; this remains an advisory documentation convention.
