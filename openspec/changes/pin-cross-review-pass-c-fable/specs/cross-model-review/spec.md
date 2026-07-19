## ADDED Requirements

### Requirement: Pass C's model choice is documented as in-family, and its comparative value is human-evaluated

When Pass C is pinned to a Claude-family checkpoint other than Pass A's, the worker's documentation SHALL state plainly that this is an in-vendor checkpoint choice made for cheap diversity within the inline pass, not an additional independent model family — the review's only cross-vendor diversity SHALL continue to be attributed to Pass B. Where that checkpoint choice differs from a model-tiering decision recorded elsewhere in the project's committed tooling (for example, a decision that a given checkpoint is not used for a different, analytical-ranking purpose), the documentation SHALL state that the two decisions govern different concerns and SHALL NOT be read as contradicting one another. Comparative evaluation of Pass C's checkpoint choice against Pass A's SHALL be conducted by a human reading the union ledger across multiple review runs for genuine finding disjointness between Pass A and Pass C — weighing that within-family disjointness may reflect ordinary prompt variance rather than a real diversity signal — and SHALL NOT be computed or asserted by any model, since a model computing its own disjointness score for its own review pass edges toward the self-certification shape the human-attestation gate exists to refuse.

#### Scenario: Pass C's checkpoint choice is not mistaken for a third family, or for a conflicting tiering decision

- **WHEN** cross-review's documentation records Pass C's pinned model
- **THEN** it states that Pass C sharing Pass A's model family is an in-vendor checkpoint choice (only Pass B provides cross-vendor diversity in the review), and that this choice governs a different concern than any separate model-tiering decision recorded elsewhere in the project's tooling, so the two are not read as contradicting one another

#### Scenario: Pass C's comparative value is judged by a human, weighing within-family noise, never computed

- **WHEN** an evaluator wants to know whether Pass C's specific checkpoint choice is earning its keep against Pass A
- **THEN** the judgment is made by a human reading several review runs' union ledgers for genuine Pass-A/Pass-C finding disjointness, treating within-family disjointness as potentially just prompt variance rather than a confirmed diversity signal, and never by a model-computed or model-asserted disjointness metric
