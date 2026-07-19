# cross-model-review Specification

## Purpose

A substantive change gets a **second, differently-modeled soundness axis** on top of the single-model conformance review — and a **human**, never a model, decides whether that review was good enough to archive. (The motivating evidence: the Opus conformance critic returned COHERENT on a change where a GPT adversarial pass caught a real config-ownership bug. The two reviewers cover different axes — conformance vs soundness — and are complementary, not redundant.)

The capability is two layers separated by a hard authority boundary:

- An **authority-free cross-model review worker** — a committed, human-launched main-loop protocol that reviews an in-scope change over a deterministic, ledger-named commit range by composing a conformance pass with **two soundness passes on distinct model families**, merges them into one union ledger (with a *heuristic* two-model consensus flag), may iterate a **bounded** fix→re-review loop, and **degrades detectably** when the external reviewer is unavailable. **Everything it produces is advisory**: no verdict, ledger, consensus flag, or recorded dismissal carries gate force or is read mechanically by any downstream step. "Converged" has no gate force; a dismissal is a *proposal*, not an accepted state; there is no receipt.
- A **mechanically-scoped, human-attested, fail-closed archive gate** — applicability is decided by a committed **path-based classifier** (any path outside the docs/tracker allowlist ⇒ in scope; ambiguous ⇒ in scope, fail-closed), never a model judgment. An in-scope change carries exactly one blocking **human-only** attestation task the model may neither tick nor compute the value for, and archive **refuses** unless all hold: the attestation exists and is well-formed; the reviewed-state digest **independently recomputes** to the attested value; the tree is clean; and the attestation line is **singular and unrewritten** since its introducing commit (exempt-by-act).

The split is the whole point: **the worker may be arbitrarily helpful but carries zero authority; the gate is authority-complete but has near-zero machinery and reads no model-authored artifact.** An earlier self-policing shape — a model that ran the review, wrote a "converged" receipt, and let archive check that receipt — was refuted: every such receipt is model-authored, so checking it still trusts the model, which could dismiss every finding and self-certify.

The mechanical checks are **accident tripwires and human-legibility aids**, *not* adversarial-integrity guarantees. Mechanizing provenance integrity against a repository-controlling model is **non-terminating** (each closure opens the next git-manipulation narrowing), so the claim is deliberately thin: adversarial resistance rests on **the human reading the complete ledger**, plus the accepted residual that a repo-controlling model could perform an affirmative forbidden act — the same trust class every committed procedure in this repo already assumes.
## Requirements
### Requirement: Authority-free cross-model review worker

The repository SHALL provide **version-controlled** tooling that reviews an OpenSpec change **in scope for cross-model review** (see the archive-gate requirement) by composing multiple review passes across **two independently-modeled reviewers** and surfacing a single merged result. Because the worker must both invoke a long-running external reviewer and **apply fixes between rounds**, it SHALL run in the **invoking (main) session**, not inside a review subagent — a subagent cannot own a detached background reviewer without stranding it — and the individual review passes remain observe-only. The tooling SHALL include a **thin launcher command** that invokes the protocol rather than restating it.

Given such a change, the worker SHALL run a **conformance** pass (the committed coherence-review agent) and **two soundness** passes carried out on **distinct model families**, and merge their findings into a **single union ledger**, each finding tagged by its source pass, flagging a finding raised by **both soundness passes** as a **heuristic two-model consensus** signal of higher confidence (the same-finding match across differently-modeled reviewers is an irreducibly semantic judgment, not a mechanical join). Both soundness passes SHALL emit findings in a **common structured schema** so their outputs are comparable, and the soundness pass sharing the conformance agent's model family SHALL run **inline** within the worker rather than as a new standing committed agent, unless recurring friction later justifies promoting it.

The worker SHALL locate the external soundness reviewer by a **version-independent, version-ordered** resolution (comparing versions numerically, not lexically). Because a focus hint does **not** restrict what the external reviewer reviews, the worker SHALL scope the review by a **deterministic best-effort commit range**: the review base SHALL be the **parent of the commit that introduced the change** (a purely positional git rule requiring no ownership metadata), the range SHALL run to HEAD, and the worker SHALL **name that range in the ledger header** — the base, the HEAD, and the reviewed file list — so the reviewed scope is transparent to the human reader rather than asserted by a trusted metadata chain. The worker MAY iterate a **bounded** number of rounds (a single human launch authorizing the whole bounded run), adjudicating and applying fixes between rounds; bounded iteration is **worker behavior only** and carries no archive-eligibility meaning.

The two soundness passes SHALL run on **distinct model families**, at an effort suitable to deep adversarial design review; the concrete model pin SHALL live in the design document (not this requirement) so the family-diversity invariant and effort floor survive model-version drift. The worker SHALL pin the external pass's model **explicitly at invocation** (not inherit it silently from a contributor's configuration) and SHALL **record the effective model of each soundness pass — and its effort where the reviewer's interface exposes it (the external adversarial reviewer may expose no per-call effort control, in which case its effort is governed by the reviewer's own configuration and reported as such) — in the ledger header**, so a human reader can see whether the run was genuinely cross-family.

When the external soundness reviewer is unavailable — no companion resolvable by the version-ordered resolution, the reviewer binary absent from PATH, or a genuinely logged-out workstation — the worker SHALL **skip that pass, complete on the remaining passes, and state plainly in the ledger header which passes ran, which did not, and why**. Degradation SHALL be **reported, never gating**: no availability state, coverage label, verdict, consensus flag, or ledger the worker produces SHALL auto-satisfy or auto-block archive, and none SHALL be read mechanically by any downstream step. The worker's output is **advisory in its entirety** — a human reads it; a dismissal recorded by the worker is a *proposal*, not an accepted state.

Because the human attestation (see the archive-gate requirement) is the **sole acceptance authority** and rests entirely on the human reading the ledger, the worker SHALL surface the **complete** union ledger — every finding with its resolution, **every dismissal with its recorded rationale**, and any residual escalated at the round bound — to the human on **every** run, never a filtered subset.

#### Scenario: The worker tooling is version-controlled

- **WHEN** the repository is cloned and the committed tooling files are inspected
- **THEN** the cross-model review launcher command, the reviewed-state digest tool, and the scope classifier are present and tracked by git (not gitignored), while machine-local and tool-generated `.claude` files remain ignored

#### Scenario: The worker runs in the main session, not a review subagent

- **WHEN** a cross-model review is run for a change
- **THEN** the parallel review passes and the between-round fixes are driven from the invoking session, and no review subagent owns the detached external reviewer (which would strand it)

#### Scenario: A change in scope is reviewed by conformance plus two-family soundness over a named range

- **WHEN** the worker reviews a change in scope for cross-model review
- **THEN** it runs a conformance pass and two soundness passes on distinct model families, reviews the commit range from the parent of the change-introducing commit to HEAD, and names that range — base, HEAD, and the reviewed file list — together with the effective model of each soundness pass (and its effort where the reviewer exposes it) in the ledger header

#### Scenario: Findings merge into a union ledger with a heuristic consensus flag

- **WHEN** the passes complete
- **THEN** the worker merges their findings into one source-tagged union ledger and flags a finding raised by both soundness passes as a heuristic two-model consensus signal of higher confidence, without asserting a mechanical join

#### Scenario: The diversity pass runs inline, not as a new standing agent

- **WHEN** the worker runs the soundness pass that shares the conformance agent's model family
- **THEN** it is executed inline within the worker rather than by introducing a new committed standing agent, consistent with the guide's rule against a speculative agent roster

#### Scenario: An unavailable external reviewer degrades detectably, never as a gate

- **WHEN** no external reviewer is resolvable, the reviewer binary is absent from PATH, or the workstation is logged out
- **THEN** the worker skips the external soundness pass, completes on the remaining passes, and states in the ledger header which passes ran, which did not, and why — and nothing about the skip blocks or satisfies any archive gate

#### Scenario: The worker's output carries no gate semantics

- **WHEN** the worker produces its ledger, consensus flags, coverage description, and any recorded dismissals
- **THEN** every one of these is advisory information a human reads, and no downstream step (in particular the archive gate) reads any of them mechanically or treats any of them as authority to archive

#### Scenario: The complete ledger is surfaced on every run

- **WHEN** a review run completes — including a run in which findings were resolved by dismissal-with-rationale, or a residual was escalated at the round bound
- **THEN** the worker surfaces the complete union ledger — every finding with its resolution, every dismissal rationale, and any escalated residual — to the human, never a filtered subset, since the human attestation that gates archive rests entirely on reading it

### Requirement: Mechanically-scoped, human-attested, fail-closed archive gate

The cross-model review's **applicability** SHALL be decided by a **mechanical classifier over the change's reviewed range**, computed by committed deterministic tooling — **not a model judgment**: if **any path in that range** falls **outside a fixed allowlist of documentation and tracker surfaces** the change SHALL be **in scope**, and an **unrecognized or ambiguous path SHALL default to in scope (fail-closed)**, so an accidental out-of-scope slip is mechanically detectable and no ambiguity judgment remains a scoping surface. A range all of whose paths fall inside the allowlist SHALL leave the change eligible for the single-agent coherence review alone. The review runs at **pre-archive** (and MAY run post-propose), not per-edit.

The classifier's verdict SHALL be understood as a property of the **range**, not of the change, and it is **neither attributive nor stable**:

- it is **non-attributive** — the reviewed range is `parent(<the change's proposal commit>)..HEAD`, which is **repo-wide**, so the classifier **cannot tell whether an out-of-allowlist path belongs to the change under review or to unrelated work**; an **in-scope** verdict asserts only that *some* path in the range is out-of-allowlist, never *whose*;
- it is **retrospective** — it reads **committed** paths only, so a **not-in-scope** verdict on a change whose implementation has not yet landed means **not yet knowable to be in scope**, never *out of scope*, and SHALL NOT suppress a finding;
- it is **monotone under intervening archives** — merging any change's spec deltas writes `openspec/specs/**`, which is **not** allowlisted, so **any change left open across any other change's archive becomes in-scope permanently**, regardless of its own content.

Consequently an **in-scope** verdict SHALL NOT be read as evidence that the change's own implementation has landed, nor that the change's own paths are out-of-allowlist, and no check SHALL use it as a proxy for either.

Because the worker carries no authority, archive eligibility SHALL rest entirely on an **explicit human attestation**, never on any artifact a model authored. An in-scope change's task tail SHALL keep the standard single-agent coherence-review delegation marker as its own task, and SHALL additionally carry **exactly one blocking human-attestation cross-review task**, placed after the coherence-review task and before the archive task. That task SHALL be **human-only**: the model SHALL NOT tick it, and SHALL NOT derive, compute, or fill in the attested value; reaching it never auto-fires the paid external reviewer (there is no auto-firing cross-model delegation marker, because the apply loop's point-of-tick grammar can express only delegate-to-subagent or run-inline, and a paid review that must not fire on task-arrival is neither). The human deliberately runs the review, reads the complete ledger, runs the **committed deterministic reviewed-state digest tool** themselves, and ticks the task, **recording the reviewed-state digest on a delimited attestation line** — a stable marker precisely bounding the attested surface within the task file, so that surface is exactly identifiable for exclusion and integrity checks.

The archive step SHALL, for a change the mechanical classifier deems in scope, evaluate a **fail-closed precondition** whose inputs are the human's attestation line, a digest computed by committed deterministic tooling, and git ground truth — and which **reads no model-authored review artifact** (no ledger, verdict, or coverage label). So that a gate-tooling edit does not accidentally validate itself, the archive step SHALL run the digest and scope tooling **as of the reviewed base state** wherever a prior committed version exists — including when the change *modifies* that tooling. **Only where the change itself introduces that tooling does no prior version exist, and the honest trust anchor is human code review of the committed scripts** — an accepted, stated boundary, not mechanically closed. Archive SHALL be refused unless **all** hold: (1) the human attestation **exists and is well-formed**; (2) the reviewed-state digest, **independently recomputed** over the reviewed content excluding only the review's bookkeeping surfaces (the advisory ledger and the delimited attestation surface), **equals** the attested value; (3) the working tree and index are **clean**; and (4) **exempt-by-act** — the delimited attestation line appears **exactly once** and stays **byte-identical from its introducing commit through archive** (any later add/delete/modify of it invalidates the attestation), that commit's task-file change is confined to the **attestation line and checkbox-state ticks**, and every later commit touches only the remaining bookkeeping surfaces, altering **no reviewed artifact and no gate implementation** — so an accidental post-review mutation of a reviewed artifact, the attestation record, or the gate tooling is caught rather than riding the attestation act. A design-time **optional strong form** MAY require the attestation act to be cryptographically signed and verify that signature when present; it SHALL NOT be the default. These mechanical checks are **accident tripwires and human-legibility aids** — they catch accidental post-review drift and surface the reviewed range and attested state for the human to judge — and adversarial resistance rests on the human reading the complete ledger plus the accepted model-only-loop residual, not on any mechanical git-provenance check.

The canonical project guide SHALL document the **worker protocol** (the passes, the advisory union-with-heuristic-consensus ledger and its header contract, the complete-ledger-every-run surfacing rule, bounded rounds, the one-launch-authorizes-the-bounded-run spend rule, the model-family diversity rule, and the detectable non-gating degradation behavior), the **mechanical path-based scope classifier** (the allowlist and the ambiguous-is-in-scope, fail-closed rule), and the **human-attestation gate with its fail-closed archive precondition** (the four checks, the reviewed-base tooling rule and its bootstrap boundary, the exempt-by-act rule, and the optional-not-default signing form).

#### Scenario: A behavior-altering change is classified in scope mechanically, never by a semantic call

- **WHEN** the archive step evaluates a change whose changed paths include one outside the documentation/tracker allowlist (product code, a non-doc spec delta, or review/verification/CI tooling), or an unrecognized/ambiguous path
- **THEN** the mechanical classifier deems it in scope — an ambiguous path defaulting to in scope — and the fail-closed human-attestation precondition applies, leaving no semantic scoping judgment by which an in-scope change could accidentally slip past the gate

#### Scenario: A pure-documentation range needs only the single-agent review

- **WHEN** every path in a change's reviewed range falls inside the documentation/tracker allowlist (docs, tracker reconciliation, a rename)
- **THEN** the mechanical classifier deems it out of scope for cross-model review and it is eligible for the single-agent coherence review alone

#### Scenario: An in-scope verdict driven by foreign paths is not read as a claim about the change

- **WHEN** the classifier reports a change in scope, but the out-of-allowlist paths in its reviewed range were all introduced by unrelated work (for example another change's archive writing `openspec/specs/**`, which is not allowlisted), while the change's own paths are entirely allowlisted
- **THEN** the verdict still applies (fail-closed, over-inclusion is safe), but it is **not** treated as evidence that the change's own implementation has landed or that its own paths are out-of-allowlist — so no check uses an in-scope verdict as a proxy for either

#### Scenario: The human-attestation task is human-only

- **WHEN** the apply loop reaches the blocking human-attestation cross-review task
- **THEN** the model stops at the task — it neither ticks it nor derives, computes, or fills in the attested value — and the task is satisfied only by a direct human act that records the reviewed-state digest on the delimited attestation line after the human has run the review and the digest tool

#### Scenario: Archive fails closed without a human attestation

- **WHEN** the archive step runs for an in-scope change whose task tail carries no ticked human-attestation task recording a reviewed-state digest
- **THEN** it fails closed — refusing to archive and surfacing the missing attestation as an unmet precondition — rather than archiving a change whose cross-model review was never human-attested

#### Scenario: Archive fails closed on a mismatched digest, a dirty tree, or a post-review alteration

- **WHEN** the archive step evaluates an in-scope change and either the recomputed reviewed-state digest does not equal the attested value, or the working tree/index is dirty, or a commit landing after the reviewed state touched a reviewed artifact, rewrote the attestation record, or modified the gate tooling
- **THEN** it fails closed — surfacing the stale or unreviewed state as an unmet precondition requiring a fresh review and attestation — while the attestation-introducing commit, confined to the delimited attestation line and checkbox ticks, does not trip the check

#### Scenario: The archive gate reads no model-authored artifact

- **WHEN** the archive precondition is evaluated
- **THEN** its only inputs are the human's attestation line, the digest recomputed by committed deterministic tooling (run from the reviewed-base version where one exists), and git ground truth — never a ledger, verdict, coverage label, or any other artifact a model authored

#### Scenario: The protocol and gate are documented in the guide

- **WHEN** a contributor or agent reads the canonical project guide
- **THEN** it states the worker protocol (passes, advisory ledger and header contract, complete-ledger-every-run surfacing, bounded rounds, one-launch spend, model-family diversity, detectable non-gating degradation), the mechanical path-based scope classifier (allowlist + ambiguous-is-in-scope), and the human-attestation gate with its fail-closed archive precondition (the four checks, the reviewed-base tooling rule and its bootstrap boundary, exempt-by-act, and the optional-not-default signing form)

### Requirement: Soundness passes are briefed

The cross-model review worker SHALL supply each **soundness pass** — the external pass and the inline diversity pass — with a **brief**, so a soundness reviewer receives the reviewer's design context rather than an unexplained diff. The brief SHALL convey the change's **design intent**, the **specific claims or assumptions the soundness pass is to verify**, and a **compact digest of any experiments the worker itself already ran** (so the reviewer reasons from those results rather than re-deriving them). Briefing SHALL **not** alter the **reviewed range** (the deterministic base rule is unchanged — a brief directs attention, it does not scope which diff is reviewed), SHALL **not** change the pass's **structured output schema** (the brief is input, the schema is unchanged), and SHALL **not** change the pass's **sandbox** (the external soundness pass remains read-only).

The brief SHALL be **additive, never a substitute for open-ended review**: each soundness pass SHALL be instructed to soundness-check the briefed claims **and** to report any material finding **outside** the brief, so a brief that omits a risk does not blind the reviewer to it. Because both soundness passes may share the same brief (and the same worker-run drill digest within it), a finding SHALL NOT be elevated to **two-model consensus** when both passes' findings rest **only** on the same briefed assertion — shared framing is not independent corroboration. To keep the shared framing auditable, the worker SHALL **record the brief** (or a faithful reference to it) in the **advisory ledger**, and SHALL present any worker-supplied drill digest as **claims to challenge**, not established fact.

The brief SHALL be delivered through the reviewer's **focus channel** as a **single inline input**, reaching the reviewer with its **semantic content and internal newlines intact** (delivery is semantic, not byte-identical). A brief SHALL fit the inline budget: if a brief would exceed it, the worker SHALL **compact it and note the compaction** — it SHALL NOT silently under-brief. The worker SHALL NOT introduce any brief-carrying file **that would enter the attested reviewed state**: no new file inside the repository worktree (the gate tooling excludes only the advisory ledger, so any other worktree file would enter the reviewed-state digest or trip the dirty-tree refusal). Staging the brief **outside the repository** and delivering it as a single focus-channel input is permitted, and is the appropriate channel when a brief carries newlines or shell metacharacters that an inline literal would mangle.

The brief SHALL be **advisory in its entirety**, carrying the same authority as the diff and the ledger: **no** archive-eligibility meaning, and read by **no** downstream mechanical step. Briefing the reviewer SHALL **not** require a write-capable reviewer; the worker SHALL NOT trade the read-only soundness path for a write-capable one merely to brief it.

#### Scenario: The external soundness pass receives a brief

- **WHEN** the worker runs the external soundness pass on an in-scope change
- **THEN** it supplies, through the reviewer's focus channel, a brief conveying the change's design intent, the specific claims to verify, and a digest of any experiments the worker already ran — so the reviewer reasons from context rather than from an unexplained diff

#### Scenario: The brief directs attention without changing the reviewed range or the schema

- **WHEN** a brief is supplied to a soundness pass
- **THEN** the reviewed commit range is unchanged (the brief scopes attention, not the diff), the pass still emits the common structured findings schema, and the external pass remains read-only

#### Scenario: The brief is additive, not a substitute for open-ended review

- **WHEN** a soundness pass is briefed and finds a material risk the brief did not mention
- **THEN** it reports that finding as well — the pass is instructed to check the briefed claims **and** to surface anything outside them, so a brief that omits a risk does not blind the reviewer to it

#### Scenario: Shared framing is not independent consensus

- **WHEN** both soundness passes receive the same brief and each raises a finding that rests **only** on the same briefed assertion
- **THEN** the worker does **not** flag that as a two-model consensus signal, and the brief is recorded in the advisory ledger so the human can audit the shared framing behind any consensus flag

#### Scenario: The brief carries no gate force

- **WHEN** the archive gate's fail-closed precondition is later evaluated for the change
- **THEN** it reads no brief — the brief is advisory input to the review, never an input to archive eligibility, and no brief-carrying file enters the reviewed-state digest

### Requirement: The inline diversity pass's checkpoint choice is documented as in-family, and its comparative value is human-evaluated

When the inline diversity pass (the soundness pass sharing the conformance pass's model family) is pinned to a Claude-family checkpoint other than the conformance pass's, the worker's documentation SHALL state plainly that this is an in-vendor checkpoint choice made for cheap diversity within the inline pass, not an additional independent model family — the review's only cross-vendor diversity SHALL continue to be attributed to the external soundness pass. Where that checkpoint choice differs from a model-tiering decision recorded elsewhere in the project's committed tooling (for example, a decision that a given checkpoint is not used for a different, analytical-ranking purpose), the documentation SHALL state that the two decisions govern different concerns and are not in contradiction. Comparative evaluation of the inline diversity pass's checkpoint choice against the conformance pass's SHALL be conducted by a human reading the union ledger — a persisted per-run ledger, or otherwise the human's own recorded per-run judgment — across multiple review runs, with each pass's findings preserved distinguishably by source tag so the human judges from the raw per-pass record rather than a collapsed summary, for genuine finding disjointness between the two passes, weighing that within-family disjointness can reflect ordinary prompt variance rather than a real diversity signal. This comparison is confounded and non-causal — the conformance pass and the inline diversity pass differ in review lens, prompt, and schema, not just checkpoint, so raw disjointness SHALL NOT by itself be read as isolating or proving the checkpoint's comparative value; the human SHALL further discount any apparent disjointness attributable to the shared review brief having pre-disclosed or pre-dismissed the conformance pass's own findings, since brief-sharing alone can manufacture apparent disjointness independent of the checkpoint swap. Even after that discount, the residual signal SHALL be treated as directional, not causal — it cannot by itself distinguish the checkpoint's own contribution from the inline diversity pass's soundness-review role generally; a decisive causal answer would require a same-brief, same-prompt control run of the conformance pass's own checkpoint through the inline diversity pass's role, which remains an optional future strengthening, not a requirement. This comparative judgment SHALL NOT be computed or asserted by any model as a disjointness metric, score, or success judgment, since a model scoring its own review pass's comparative value edges toward the self-certification shape the human-attestation gate exists to refuse.

#### Scenario: The inline diversity pass's checkpoint choice is not mistaken for a third family, or for a conflicting tiering decision

- **WHEN** cross-review's documentation records the inline diversity pass's pinned model
- **THEN** it states that sharing the conformance pass's model family is an in-vendor checkpoint choice (only the external soundness pass provides cross-vendor diversity in the review), and that this choice governs a different concern than any separate model-tiering decision recorded elsewhere in the project's tooling, so the two are not in contradiction

#### Scenario: The inline diversity pass's comparative value is judged by a human from the raw per-pass record, weighing within-family noise, never computed

- **WHEN** an evaluator wants to know whether the inline diversity pass's specific checkpoint choice is earning its keep against the conformance pass
- **THEN** the judgment is made by a human reading several review runs' union ledgers — persisted per run, or the human's own recorded per-run judgment, with each pass's findings preserved distinguishably by source tag — for genuine finding disjointness between the two passes, treating within-family disjointness as potentially just prompt variance rather than a confirmed diversity signal, reading the recorded brief to discount disjointness attributable to the brief's own pre-disclosure or pre-dismissal of the conformance pass's findings, treating the comparison as a directional, non-causal observation rather than a controlled isolation of the checkpoint's effect from the inline diversity pass's role generally, and never by a model-computed or model-asserted disjointness metric, score, or success judgment

### Requirement: Attestation-line emission is a print-only, authority-free convenience

The committed deterministic reviewed-state digest tool MAY additionally emit the **fully-assembled attestation line** — `<!-- cross-review-attestation: base=<B> head=<HEAD> digest=<sha256> reviewed=<date> -->`, every field filled from values the tool already computes or derives mechanically, never authors — as a ready-to-paste convenience for the human performing the attestation, bounded on three sides. **The default stdout contract is untouched:** this emission SHALL NOT alter the tool's default invocation's stdout contract — the default invocation SHALL continue to print the bare 64-hex reviewed-state digest and nothing else on stdout, so anything that already parses that stdout, in particular the archive step's independent recompute-and-compare, is unaffected. **The emitted line is not an attestation and carries no gate force:** printing the assembled line SHALL change nothing about archive eligibility — it is output for a human to read and carry, not a recorded attestation, and only the human act of recording the line on the delimited attestation surface in the task file, per the archive-gate requirement, attests anything. **The convenience is not license to go further:** emitting a ready-to-paste line SHALL NOT be read as permission for the digest tool — or any other committed tooling — to perform the acts that constitute attestation; such tooling SHALL NOT write the attestation line into a task file, SHALL NOT tick the human-attestation task, and SHALL NOT create a commit. Those three acts remain **exclusively human** — a permanent rejection, not a deferral, since a committed script performing any of them would convert the one genuinely forbidden act (a model self-attesting) into a routine-looking command invocation nobody would notice crossing the authority boundary, and git cannot attribute who invoked a command — the affordance itself is the attack.

#### Scenario: The assembled line is emitted without disturbing the default stdout contract or the gate

- **WHEN** the digest tool is invoked in its default form for a change, and in whatever additional form emits the fully-assembled attestation line
- **THEN** the default invocation prints the bare 64-hex digest and nothing else on stdout, byte-identical to the pre-convenience contract, and the emitted line — printed, copied, or discarded — changes nothing about archive eligibility: the fail-closed archive precondition still evaluates only the human-recorded attestation line in the task file, the independently recomputed digest, and git ground truth

#### Scenario: Printing a ready-to-paste line is not license to write, tick, or commit

- **WHEN** the digest tool (or any other committed tooling) emits the assembled attestation line
- **THEN** it writes that line into no task file, ticks no human-attestation task, and creates no commit — the line reaches the task file only through the human's own paste-and-tick act, and any future proposal to automate any of those three acts contradicts this requirement rather than extending its convenience

