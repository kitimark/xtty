## ADDED Requirements

### Requirement: The eagerly-injected agent guide is bounded by a mechanical gate below the agent

The project SHALL enforce a byte ceiling on the **eagerly-injected agent guide** by a mechanism that operates **below the agent** — one that cannot be routed around by the choice of editing tool, the choice of push invocation, or any wrapper. Enforcement SHALL occur at the **push boundary**, refusing publication rather than advising against it. Advisory surfaces (specs, skills, review agents) SHALL NOT be relied upon as the enforcement mechanism.

The gate's only bypass SHALL be an explicit forbidden act (a deliberate verification-skipping flag). The gate SHALL be documented as an **accident tripwire**, NOT as an adversarial guarantee against a repository-controlling actor.

#### Scenario: A push that grows the guide past the ceiling is refused

- **WHEN** a push carries a committed tree whose eagerly-injected guide exceeds the ceiling and is larger than the guide at the push's baseline
- **THEN** the push is refused, and the refusal names the offending source and the baseline it was compared against

#### Scenario: The gate does not depend on which tool wrote the file

- **WHEN** the guide is grown by a shell command rather than an editing tool, and then pushed
- **THEN** the push is refused exactly as if an editing tool had written it

#### Scenario: The gate does not depend on how the push was invoked

- **WHEN** a push is invoked through a directory-changing flag, a config-overriding flag, a wrapper, or a build target
- **THEN** the gate still evaluates the push

### Requirement: The meter measures the whole eagerly-injected surface, from the committed tree

The gate's meter SHALL measure the **committed blob of the pushed tree**, never the working copy. It SHALL resolve the complete **eager-root set** — the project guide root, the alternate project-guide location, the local project guide, and every project rule that is **not** scoped by path frontmatter — and SHALL follow the guide's transitive imports, resolving each import **relative to the file containing it**, ignoring imports that appear inside code spans or fenced code blocks, up to the documented maximum import depth.

The meter SHALL count **bytes**, obtained from version control, and SHALL follow a symlinked guide to its target content rather than measuring the link itself.

A rule carrying **path-scoping frontmatter** is loaded on demand rather than at launch and SHALL NOT be metered. Frontmatter SHALL be recognised only as a properly delimited block; a document whose body merely mentions the frontmatter key SHALL still be metered.

#### Scenario: A symlinked guide is measured by its content

- **WHEN** the guide root is a symlink to the real guide file
- **THEN** the meter reports the target's byte count, not the length of the link's target path

#### Scenario: Content moved into an unscoped rule is still metered

- **WHEN** guide content is relocated into a project rule that carries no path-scoping frontmatter, and the rule grows past the ceiling
- **THEN** the push is refused, because that rule is eagerly injected

#### Scenario: A path-scoped rule is not metered

- **WHEN** a project rule carrying path-scoping frontmatter grows
- **THEN** the push is allowed, because that rule is loaded on demand rather than at launch

#### Scenario: A guide with no root file but an alternate eager root is still metered

- **WHEN** the guide exists only at the alternate project-guide location and grows past the ceiling
- **THEN** the push is refused, and the gate does not report that there is no guide

#### Scenario: A multibyte edit that grows the file is caught

- **WHEN** an edit leaves the character count unchanged but increases the byte count past the ceiling
- **THEN** the push is refused

### Requirement: The comparator permits shrinking and unchanged pushes, and never freezes unrelated work

While the guide is **over** the ceiling, the gate SHALL refuse a push only if the guide **grew relative to the push's baseline**; a shrinking or unchanged guide SHALL always be permitted. Once the guide is **under** the ceiling, the gate SHALL refuse a push whose guide exceeds the ceiling.

The gate SHALL resolve a baseline for every pushed ref such that a ref carrying **inherited history** is never refused for growth it did not introduce, and a push that introduces **no guide bytes the remote does not already have** is permitted.

#### Scenario: An unrelated push during the over-ceiling window is allowed

- **WHEN** the guide is over the ceiling and a push changes no guide content
- **THEN** the push is allowed

#### Scenario: A ref anchored in pre-diet history is allowed

- **WHEN** a new ref pinned at a historical commit whose guide exceeds the current ceiling is first pushed, and the guide is unchanged relative to that ref's own base
- **THEN** the push is allowed, because the ref introduced no growth

#### Scenario: Growth on a historical ref is still refused

- **WHEN** that same ref then grows its guide
- **THEN** the push is refused

#### Scenario: A ref with unrelated history and no guide is allowed

- **WHEN** a ref carrying no guide and sharing no history with the main line is pushed
- **THEN** the push is allowed

### Requirement: The guide cannot be vaporized, deleted, or re-routed past the gate

The gate SHALL refuse a push that **destroys** the eagerly-injected guide, independently of the mechanism by which it was destroyed. A guide that had substantive content at the baseline and has almost none at the pushed tip SHALL be refused as a collapse, whether the cause is a deleted root, a deleted import target, a replaced symlink, or an emptied file.

An import that **resolved at the baseline and no longer resolves** at the tip SHALL be treated as a deletion. An import that **never resolved**, or that is inherently unpushable, SHALL be weighed as zero and reported, and SHALL NOT be treated as a deletion.

#### Scenario: Deleting the guide is refused

- **WHEN** a push deletes the guide from any ref that had one at its baseline
- **THEN** the push is refused

#### Scenario: Deleting an imported guide behind a surviving root is refused

- **WHEN** a push deletes the file an eager import points at, leaving the root in place so the meter would read a large shrink
- **THEN** the push is refused

#### Scenario: A newly-added broken import does not refuse the push

- **WHEN** a push adds an import that does not resolve, without removing anything that previously resolved
- **THEN** the push is allowed and the unresolvable import is reported

#### Scenario: A pre-existing broken import does not disable the gate

- **WHEN** a guide containing an unresolvable import has been published, and a later push grows the guide past the ceiling
- **THEN** that later push is refused

### Requirement: The gate fails closed on its own failure, and never claims an action it did not take

If the gate cannot produce a measurement, it SHALL **refuse** the push. The gate SHALL NOT allow a push as a consequence of its own internal error, and SHALL NOT emit a message asserting a refusal on a push it then permits.

#### Scenario: A malformed ceiling refuses the push

- **WHEN** the gate is configured with a ceiling that is not a number
- **THEN** the push is refused

#### Scenario: A permitted push makes no refusal claim

- **WHEN** the gate permits a push
- **THEN** its output contains no statement that the push was refused

### Requirement: The gate acts only on the repository it was installed for

The gate SHALL act only on a repository explicitly marked as armed by its installer, and SHALL take **no action of any kind** — including refusing — in an unmarked repository. The identity check SHALL be evaluated **before** any configuration parsing, and SHALL NOT be derived from the presence of guide content (which a stranger's repository may also have) nor from the checked-out working tree (which a guide deletion would alter).

#### Scenario: An unrelated repository is never gated

- **WHEN** the hook is reachable from a repository that was not armed by the installer — including one that has an agent guide of its own — and a push is made
- **THEN** the gate takes no action and the push proceeds

#### Scenario: A misconfiguration does not leak into an unrelated repository

- **WHEN** the gate's ceiling is misconfigured in the environment and a push is made from an unarmed repository
- **THEN** the push is not refused

#### Scenario: Deleting the guide does not disable the identity check

- **WHEN** a push deletes the guide from the armed repository
- **THEN** the gate still evaluates the push and refuses it

### Requirement: The ceiling is a measured ratchet

The ceiling SHALL be set from an **achieved, measured** guide size, never from an estimate, and — once the gate is installed and armed — SHALL only ever be lowered. Lowering the ceiling SHALL require a measured reduction to have already landed. *(This invariant governs the ceiling from the point the gate is armed onward; the authoring-time process of arriving at that installed value — including re-measuring against a guide still being edited before the gate ships — is not itself a "raise" of an installed ratchet.)*

The project SHALL document that the byte ceiling is a **proxy**: the objective is the guide's contribution to session and subagent context, which bytes do not track monotonically.

#### Scenario: The gate is green on arrival

- **WHEN** the gate is first installed
- **THEN** the current guide satisfies the ceiling, so no existing work is frozen

#### Scenario: The ceiling is not raised to accommodate growth

- **WHEN** an append would exceed the ceiling
- **THEN** the append is refused and the ceiling is not raised

### Requirement: A refused append is parked, never lost

When the gate refuses an append to the eagerly-injected guide, the finding SHALL be **recorded on a named, tracked, lazily-loaded surface** rather than discarded. The refusal message SHALL name the recovery procedure and the destination, and SHALL NOT require the author to improvise one.

#### Scenario: The refusal message anchors the recovery

- **WHEN** the gate refuses a push
- **THEN** its message states how to withdraw only the guide growth while keeping every other change, and where to park the finding

#### Scenario: No finding is dropped

- **WHEN** an append is refused
- **THEN** the content is committed to its lazily-loaded destination and the guide retains a bounded pointer to it
