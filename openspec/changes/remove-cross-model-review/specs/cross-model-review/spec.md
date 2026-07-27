## REMOVED Requirements

### Requirement: Authority-free cross-model review worker

**Reason**: The owner has retired the cross-model-review capability entirely; its cost (maintenance surface, the recorded re-attestation/digest-fragility/exempt-by-act friction) was judged not worth the assurance it provided for this project.

**Migration**: None. `/xtty:cross-review` is no longer available, not even as an optional advisory tool. The `xtty-openspec-critic` agent's single-agent coherence review remains the sole review path for OpenSpec changes.

### Requirement: Mechanically-scoped, human-attested, fail-closed archive gate

**Reason**: The mechanical archive gate is retired with the worker it gated.

**Migration**: `openspec archive` no longer evaluates any scope classification or attestation precondition for any change, in scope or not. Normal human review of the archived diff is responsible for catching an unintended premature archive; there is no mechanical backstop.

### Requirement: Soundness passes are briefed

**Reason**: There are no soundness passes to brief; the worker that ran them is retired.

**Migration**: None.

### Requirement: The inline diversity pass's checkpoint choice is documented as in-family, and its comparative value is human-evaluated

**Reason**: There is no inline diversity pass; the worker is retired.

**Migration**: None.

### Requirement: Attestation-line emission is a print-only, authority-free convenience

**Reason**: There is no attestation line to emit; the digest tool that emitted it is retired.

**Migration**: None.
