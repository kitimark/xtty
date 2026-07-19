## ADDED Requirements

### Requirement: Pass C's model choice is documented as in-family, and its comparative value is human-evaluated

When Pass C is pinned to a Claude-family checkpoint other than Pass A's, the worker's documentation SHALL state plainly that this is an in-vendor checkpoint choice made for cheap diversity within the inline pass, not an additional independent model family — the review's only cross-vendor diversity SHALL continue to be attributed to Pass B. Comparative evaluation of Pass C's checkpoint choice against Pass A's SHALL be conducted by a human reading the union ledger across multiple review runs for genuine finding disjointness between Pass A and Pass C, and SHALL NOT be computed or asserted by any model, since a model computing its own disjointness score for its own review pass edges toward the self-certification shape the human-attestation gate exists to refuse.

#### Scenario: Pass C's checkpoint choice is not mistaken for a third family

- **WHEN** cross-review's documentation records Pass C's pinned model
- **THEN** it states that Pass C sharing Pass A's model family is an in-vendor checkpoint choice, and that only Pass B provides cross-vendor diversity in the review

#### Scenario: Pass C's comparative value is judged by a human, not computed

- **WHEN** an evaluator wants to know whether Pass C's specific checkpoint choice is earning its keep against Pass A
- **THEN** the judgment is made by a human reading several review runs' union ledgers for genuine Pass-A/Pass-C finding disjointness, never by a model-computed or model-asserted disjointness metric
