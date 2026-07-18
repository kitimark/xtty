## ADDED Requirements

### Requirement: The guide's leanness bound has a mechanical backstop and a refusal protocol

The tracker-reconcile step's leanness bound on the always-loaded canonical guide SHALL be backed by a **mechanical gate at the publication boundary**, not by advisory instruction alone. Advisory statements of the bound — in specs, in point-of-action skill text, and in review agents — SHALL remain, but the project SHALL NOT rely on them as the enforcement mechanism: all three predated two full regrowths of the guide and were overridden by *instructed* writing each time.

When an append to the always-loaded guide is refused by that gate, the reconcile step SHALL **park** the finding: the content is committed to its named, tracked, lazily-loaded destination (the history log or a research capture), and the guide retains only a bounded pointer to it. A refused append SHALL NOT be discarded, and SHALL NOT be worked around by relocating the content to another eagerly-loaded surface.

#### Scenario: A reconcile that would breach the bound is refused, not merely discouraged

- **WHEN** a tracker reconcile grows the always-loaded guide past its ceiling and the result is pushed
- **THEN** the push is refused by the mechanical gate, independently of whether any advisory surface flagged it

#### Scenario: The refused finding survives

- **WHEN** an append to the always-loaded guide is refused
- **THEN** the finding is recorded on its lazily-loaded destination and the guide keeps a bounded pointer, so nothing is lost from the repository

#### Scenario: Growth is not displaced onto another eager surface

- **WHEN** content refused from the canonical guide is instead placed in another surface that is also loaded at session start
- **THEN** the push is still refused, because the gate meters the whole eagerly-injected surface rather than a single file
