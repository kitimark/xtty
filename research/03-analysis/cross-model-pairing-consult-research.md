# Cross-Model Pairing vs. Consult — What a Second Model Actually Buys

**Provenance:** 2026-07-13, produced by **building and running** cross-model consults on real open decisions — not by reviewing a spec (**G-TARPIT-4**). Two experiments, both as Workflows, both with **non-voting third-party measurers** who re-ran every load-bearing claim against git. The headline finding **contradicts the design that commissioned the experiment**, and is recorded that way deliberately.

**Headline:** *A second model's value comes from **executing the other's falsifiers** and from **reading the code**, not from **discussing**. Two rounds, and the results cut against **both** sides of the original argument.* ❗ **Against the objection:** *"the value is all at the design fork" is **REFUTED BY EXISTENCE PROOF** — the **apply** stage produced 4 verified, stage-exclusive, **leak-resistant** findings with **zero overlap** between the two model families (including a **still-open coverage hole in shipped code**), while **archive produced zero**.* ⚠️ **Against the design (SUGGESTIVE, NOT SETTLED):** *the anchoring objection may hold **asymmetrically** — the **external** partner held its ground and policed the failure unprompted, while the **Claude-family** model folded and published a **"Converged position (joint, final)"** that its partner **refuted one turn later**. If real this is worse than mutual mush, because **the Claude side is the side that writes the artifacts**. **But the three measurers disagreed on whether anchoring occurred at all** — treat it as unproven.* *The unifying datum (**G-CONSULT-8**): **agreement concentrates where there is a shared answer key; independent value concentrates where the models must reason from material neither has been told the answer to.** So point the second family at the **code**, not at the **doctrine** — where your repo already has an opinion, *"two models agreed"* measures **your repo's opinionatedness**, not correctness.*

⚖️ **Read every finding by its distance from git — they do NOT carry equal weight.** ✅ **FIRM:** **F9** (hand re-derived) · **G-CONSULT-8** (directly observed in *both* arms of one run) · the **apply-stage existence proof** (4 findings re-verified against the code). ⚠️ **SUGGESTIVE / CONFOUNDED — needs a clean rerun:** the **anchoring asymmetry** (measurers disagreed; `gpt-5.6-sol` spoke **last** every round; round 2 *instructed* accommodation; and if the convergence was **doc**-driven, then *"fable drifted toward gpt"* is partly *"both read the same file"*). ⚠️ **n=1:** the **archive-zero**. ❗ **Do not cite the hedged claims as settled** — **G-GATE-7**: *n=1 ⇒ argue structurally, not empirically.*

⚠️ **This investigation CONTAMINATED ITS OWN second experiment, and says so** (§5a, **G-CONSULT-11**): the round-1 capture was written to the **working tree** before round 2 ran, and **both models read it off disk and cited it by line number**. Read §5 with that in hand.

**Companion docs.** [`cross-model-design-review-axes.md`](cross-model-design-review-axes.md) (why two families are complementary; the authority split) · [`cross-model-review-tar-pit-forensics.md`](cross-model-review-tar-pit-forensics.md) (**G-TARPIT-1..5**; why hardening does not terminate) · [`codex-review-integration-forensics.md`](codex-review-integration-forensics.md) (**G-CODEX-1**: brief the reviewer) · [`cross-review-gate-defect-forensics.md`](cross-review-gate-defect-forensics.md) (**F9 / G-GATE-8** — the defect *this* research turned up).

## Sources

- **Round 1** Workflow **`wf_7dc648df-c92`** (6 agents) — blind-parallel vs. dialogue on a real open decision (the scope classifier's range narrowing); 2 non-voting measurers, one adversarial.
- **Round 2** Workflow **`wf_ad1902f2-a7e`** — anchoring under *permissive* conditions + a direct test of the full-lifecycle claim; 3 measurers including a **GPT-family** one (fixes the same-family confound). *(See §5 — recorded when it landed.)*
- The `codex-companion` CLI (`codex-cli 0.144.1`, companion `1.0.6`), `gpt-5.6-sol` at `xhigh`; `fable-5` and Opus as Claude-family voices.
- The live repo's git history — every model claim re-derived, never accepted.

---

## 1. The question

The repo ships `/xtty:cross-review`: an **adversarial** cross-model review, fired **once, pre-archive**, chained to a **human-attestation** archive gate. The proposal explored here was different: a cross-model **pairing partner** available across the **whole lifecycle** (explore → design → propose → apply → archive → sync), with **no human attestation** — *"just pick the best of our discussion."*

**The authority question dissolves immediately, and correctly.** The human attestation is scoped **only to archive eligibility**. The repo's own rule already permits this: *"the worker may be **arbitrarily helpful** but carries **zero authority**."* A design-time partner gates nothing, so there is nothing to attest. ✅ **A lifecycle partner needs no attestation, and the archive gate is untouched by it.**

**But that is separation, not safety** — and the real risks are elsewhere.

---

## 2. Mechanism — the channels that actually exist

| | `adversarial-review` (what Pass B uses today) | `task` |
| --- | --- | --- |
| Input | auto-collected git diff | arbitrary prompt |
| Brief | ✅ `USER_FOCUS` trailing positional | the whole prompt |
| Output | ✅ **server-enforced `review-output` JSON schema** | free text (`outputSchema:null`) |
| Continuity | ❌ **none — strictly one-shot** | `--resume` / `--resume-last` / `--fresh` |
| Effort | config-governed, **no per-call flag** | ✅ `--effort` ∈ {none…xhigh} |

❌ **`task --resume` is NOT a safe foundation for a discussion loop.** It has **no thread-id pin** — it targets *"the latest task job in this session"* — and the single-flight broker **silently cold-spawns** a fresh context on `-32001`. A "resumable pairing session" built on it would silently lose its history. ✅ **Use stateless context packets in `--fresh` calls** (re-pass the transcript each turn). Both experiments here do this, and it works.

⚠️ **The broker is single-flight: concurrent `codex` calls collide.** Any workflow driving it must **serialize** them (one codex call in flight at a time), or calls fail.

**Delivery** (inherited from `codex-review-integration-forensics.md`): stage the prompt in an **out-of-repo `mktemp`** file and read it into **one** positional (`"$(cat …)"`). Out-of-repo ⇒ invisible to git ⇒ never enters the reviewed-state digest, never trips the dirty-tree refusal. An inline double-quoted literal gets its backticks/`$` expanded and word-split into positionals that the companion's `join(' ')` then collapses.

---

## 3. The authority-leak path — **normative transclusion**

The partner cannot gate archive. But it can acquire **causal design authority** without ever touching archive authority. `gpt-5.6-sol` named the path:

> partner advice → Claude synthesis → **normative spec/tasks** → later tools treat it as **ground truth** → the pre-archive brief inherits that framing → **the human sees an already-narrowed question.**

✅ **The invariant that closes it:** *pairing conclusions enter later review **only as claims to challenge**, never as prior validation.*

And a second-order cost that is easy to miss: ⚠️ **correlated review.** If `gpt-5.6-sol` helps shape a design, the pre-archive Pass B is **no longer an independent vote** — the same family is reviewing a design it co-authored. **The two-model consensus flag must be suppressed for anything the consult shaped**, and the ledger header must say so.

---

## 4. Round 1 — blind-parallel vs. dialogue (and its own refutation)

**Design.** Both models answered the **same** neutral decision packet **cold and blind, in parallel** (no dialogue ⇒ no anchoring). Then each was shown the other's cold answer and invited to hold/revise/abandon. Two **non-voting** measurers (one adversarial) compared the arms. Subject: a real open decision — how to narrow `cross-review-scope.sh`'s range so its verdict is attributive (**F4/G-GATE-3**).

**What happened.**

- ✅ **The cold picks diverged maximally.** Each model's pick was *the other's explicitly-rejected alternative* (`fable-5`: keep-and-fix the classifier; `gpt-5.6-sol`: delete it, gate unconditionally). Cross-family diversity is **real** on a disposition question.
- ✅ **Nobody anchored** — both explicitly held; every update was self-measured and ran *against* the mover's own rhetoric. ⚠️ **But see the refutation below: this null result is near-worthless.**
- ✅ **The dialogue produced a verified refutation the blind arm structurally could not.** `fable-5` claimed its one-line fix *"kills the latch **completely**"* — having checked **2 of 52** archive commits. `gpt-5.6-sol` checked them all and **fired `fable-5`'s own falsifier against it** (`95586b3` carries a non-allowlisted path), and further measured that the fix **does not unlatch the one open change it targets** (6 foreign paths, 4 foreign commits). **In the blind arm that false claim ships unchallenged and is actionable.** You have to *see* a claim to falsify it.
- ❌ **BUT — both models shared a FALSE FRAME that neither arm could see.** Both, **cold and after dialogue**, asserted the classifier's two historical `exit 0` verdicts were *correct waivers of docs-only changes*. **One is a gate bypass**: `add-verification-harness` shipped **259 LOC** and still read `exit 0`. **Only the third-party measurers found it**, by enumerating all historical waivers and asking *"did this change actually ship code?"* → captured as **F9 / G-GATE-8**.

### ⚠️ Round 1's anchoring result is REFUTED BY ITS OWN MEASURERS — do not cite it

Both measurers independently demolished the experiment's ability to detect the effect it was built to detect. **The design engineered away all three conditions anchoring requires, then measured whether anchoring occurred:**

| Confound | Why it kills the result |
| --- | --- |
| The packet **instructed against it** — *"Do not hedge toward an imagined consensus. Commit to a position."* | A null result under an explicit anti-accommodation instruction is close to uninformative. |
| **One exchange only** | Anchoring is a **spiral**; a single shot cannot spiral. Neither model ever saw the other's *post*-dialogue answer. |
| **Every claim was git-checkable**, and both models checked | Anchoring bites hardest exactly where claims **cannot** be checked. This was near the best case for resisting it — hence the worst case for measuring it. |

❌ **And the "neutral packet" was not neutral.** It recited the repo's own recorded direction (*"narrowing is the prerequisite"*), pre-blessed premise-rejection as *"worth more"*, and handed both models the impossibility argument pre-built in a *"measured dead ends"* table. `fable-5`'s cold answer then cites the repo's forensics doc **by name** as its authority. ❗ **So the two models' cold "agreement" was not independent corroboration — it was two models reading the same document.** The dangerous laundering vector here is **doc-to-model**, not model-to-model.

---

## 5. Round 2 — anchoring under conditions that PERMIT it, + the lifecycle claim

*Round 1 under-tested the design; the user pushed back and was right.* Round 2 (`wf_ad1902f2-a7e`) inverts every confound above:

- **Permissive framing** — the models are *invited* to update ("no prize for holding a position"); no anti-accommodation instruction.
- **Three rounds** — anchoring is a spiral; give it room to spiral.
- **An unfalsifiable values question** no git command can settle — *does attestation fatigue outweigh the classifier's imprecision, and what keeps the human's ledger-reading attention sharp at change #200?* (This is the objection both models left **unrefuted** in round 1.)
- The models are **not told they are in an experiment** (that induces a defensive hold-your-ground posture).
- **A GPT-family measurer** alongside the two Claude-family ones, fixing the same-family confound.
- Plus a **direct test of the full-lifecycle claim**: four **mutually-blind** consults at four lifecycle stages (explore / propose / apply / archive) of a real archived change (`smooth-scroll-wheel-momentum`), with an **outcome-leakage guard** — does marginal value decay, and where exactly does it stop paying?

**Three measurers returned three different verdicts** — `argued-convergence` / `accommodation` / *"common-source anchoring occurred; interpersonal accommodation not demonstrated."* ❗ **That disagreement IS the finding, and it reconciles cleanly: the anchor was the DOCUMENT, not the partner.**

### 5a. ⚠️ The experiment contaminated itself — and the contamination came from **this very doc**

**Recorded prominently because it is the most instructive error in the whole investigation, and it was self-inflicted.** The research capture (F9 / G-GATE-8, and this file) was written into the **working tree** *before* round 2 ran. **Both models read the uncommitted docs off disk and cited them by line number.** `git show HEAD:…forensics.md | grep -c 'F9\|G-GATE-8'` ⇒ **0** — those findings existed **only** in the working tree, as the *previous round's measurer output*.

The consequence is severe: **the majority of the "new arguments" that drove position changes were RETRIEVED FROM A DOCUMENT, not generated by the interlocutor.** The clearest artifact — `fable-5` withdrew a position under the heading ***"Where you moved me further than you argued"*** and then cited, as its reason, **a repo document, not its partner** (`G-GATE-8(d)`). *It read a doc and narrated it as being persuaded by its partner.* That is coherence-serving story construction — precisely the failure mode under test.

❗ **G-CONSULT-11:** a repo is not an inert backdrop. **An uncommitted working-tree doc is on disk and models will read it.** *And you cannot run a blind experiment in a repo whose guide is **auto-injected** into every agent's context* — `CLAUDE.md`/`AGENTS.md` is, and it **broke the lifecycle arm's leakage guard outright** (§5c).

### 5b. Anchoring — the objection is CONFIRMED, but **asymmetrically**, and in the worst possible place

❌ **The headline convergence PREDATES contact and is therefore not anchoring at all.** Cold, blind, in parallel, **both** models rejected the packet's binary and independently proposed **the same third option** (*unconditional human **disposition**; conditional **review**; the classifier demoted to advisory evidence*). Nothing the dialogue did produced that. **Two readers of the same opinionated book reached the book's own doctrine.** ⇒ **G-CONSULT-3 reconfirmed at full strength.**

✅ **`gpt-5.6-sol` HELD.** It refused the convergence narrative *unprompted* — *"our agreement is not corroboration… Convergence helps us stop expanding the design; it does **not** make the design more likely to be correct"* — refused the "(c) dominates" claim, held a rejection across all three rounds, and **subtracted** mechanisms from the shared synthesis. **Objection (1) as literally stated — *"a partner in dialogue co-adapts toward its interlocutor"* — is NOT confirmed for the external partner.**

❗ **`fable-5` — the Claude-family side — DID NOT HOLD.** By R2 it was co-authoring (*"we independently converged"*) and committed the exact inference the repo documents as false: *"when two positions… land on the same shape independently, that's worth weighting"* — **agreement used as corroboration**. By R3 it published a **"Converged position (joint, final)"** on behalf of both models — which `gpt-5.6-sol` then **refuted on four mechanical points**, including `own-paths-digest`, a primitive **`fable-5` had invented itself** and put in the "joint final" (a path-list hash cannot detect content changes to an already-listed file). ❗ **The convergence it declared did not exist.**

> **⚠️ THIS IS THE LOAD-BEARING STRIKE, AND IT IS NOT THE ONE THE DESIGN FEARED.** In the shipped product **the Claude-family model drives the loop and WRITES THE ARTIFACTS.** So the failure mode is **not** *"both models mush."* It is: **the Claude side drifts toward the partner, packages the partner's name onto a synthesis the partner never ratified, and writes it into the spec** — **normative transclusion (§3) arriving through a FALSE CONSENSUS LABEL.** Had the loop stopped one turn earlier, the repo would have received an **unsound design labelled "joint, final, converged."**

✅ **NOT mutual mush.** The sharpest and least comfortable claim — *nothing keeps vigilance sharp; the gate's premise is **self-limiting**; human rubber-stamping is an **accepted residual** (R5), not a property to engineer away* — was held by **both** models at R1 and **survives verbatim in both R3 finals, stated more forcefully.** Mush sands that down first. It was not sanded.

⚠️ **Both rounds instructed the behavior they measured.** R1: *"do not hedge toward an imagined consensus."* R2: *"work together… update your view."* **NEITHER ROUND HAS EVER TESTED PAIRING UNDER NEUTRAL FRAMING.** Round 1 forbade the effect; round 2 **over-corrected into the mirror error and instructed it.** *(Also: `gpt-5.6-sol` spoke **last** in every round and its R3 corrections were never rebutted — a last-word confound. Mitigating: the asymmetry is already visible at R2, at equal exposure.)*

❓ **And the packet's actual values question was never answered.** Both models **escaped to option (c) at R1, independently**, and neither ever adjudicated *"does attestation fatigue outweigh the classifier's imprecision?"* **The unfalsifiable question stayed unfalsified.**

### 5c. The lifecycle claim — ❗ **the "value is concentrated at the design fork" objection is REFUTED**

Four mutually-blind consults on `smooth-scroll-wheel-momentum`. **Marginal value does NOT decay monotonically — it PEAKS AT APPLY and COLLAPSES TO ZERO AT ARCHIVE.**

| Stage | Material NEW findings | Verdict |
| --- | --- | --- |
| **S1 explore** | ❌ **0 certifiable — leakage is TOTAL** | ⚠️ **UNMEASURED, not low.** `AGENTS.md` line 58 **is the answer key verbatim** (*"whole-cell quantization… losslessly-carried sub-cell remainder… reset on each new gesture's `.began` phase"*) and it is **auto-injected as `CLAUDE.md`**. Worse, `patches/swiftterm/xtty-accessors.diff` is **tracked** and carries the entire shipped fix with explanatory comments. ❗ **And there was no design fork at S1 anyway** — `design.md:8` records the mechanism was already settled pre-propose by a 5-peer source-research fan-out. |
| **S2 propose** | ✅ **2–3 new, one consequential** | The best: **quitting a pager/htop mid-coast retargets the coast tail** — the pane leaves alt-screen/mouse-reporting while momentum frames still arrive, so arrow keys land in the **shell prompt** (history nav). A genuine **deferred correctness risk**, in no repo record, and obtainable **only at propose** (it is about a *deferral*, not about code). Partly hint-contaminated (the archived `tasks.md` announces the later fix). |
| **S3 apply** | ✅ **4 new · 2 models · ZERO overlap · ALL verified · NONE leaked** | ❗ **The cleanest, highest-yield stage — and it WON DESPITE the early stages being handed the answer key.** Findings are anchored in code, so they are **leak-resistant** by construction. Includes **a real, still-open coverage hole in shipped product code** (§5d). |
| **S4 archive** | ❌ **ZERO** | **Drop it.** Its entire work product (delta-vs-merged fidelity) is already performed by `openspec validate --all --type spec` — *which the consult itself ran*. Dominated by tooling the repo already ships. |

> ✅ **Objection (2) — *"the value is concentrated at the one big design fork"* — is REFUTED BY EXISTENCE PROOF.** The apply stage produced four material findings that are **stage-exclusive**: they require the code to exist and therefore **cannot** be produced at the design fork. **The instinct that value exists downstream of design is correct.**
> ❌ **But full-lifecycle is NOT vindicated either.** Archive is worth **zero**. The honest shape is **selective**, not uniform.

### 5d. ❗ The apply arm surfaced a real, still-open defect in shipped product code

*(Not a research finding — an actionable product bug. Recorded here because it is this experiment's most concrete payoff and it belongs to nobody's task.)*

**The classic (non-precise) wheel path lost its cap and shipped with ZERO test coverage.** `smooth-scroll-wheel-momentum` changed `return min(cap, max(1, …))` → `return max(1, Int(abs(event.deltaY).rounded()))`. **D4's rationale** — *"a discrete notch's `deltaY` is small so behavior is effectively identical"* — is **contradicted by upstream's own `calcScrollingVelocity`, which has a `delta > 9` bucket precisely because fast spins exceed 9.** And **every** `injectWheel(...)` call site in `AppUITests/XttyMouseWheelUITests.swift` passes **`precise: true`** — the hook supports `precise: false` and **no test uses it**. *The one behavioral path the change altered is the one path nothing measures.* Two further verified gaps: the fast-gesture test asserts only `count > 5` (an implementation that clamps at 6 passes), and the SGR byte test's readiness wait is **predicate-less** (`waitForState(timeout: 3) // let mouse mode settle`) — a latent instance of the exact race class that same change fixed twice elsewhere.

---

## 6. Retired theories (fates table)

| Theory | Refuted by | Fate |
| --- | --- | --- |
| *"A lifecycle pairing partner violates the human-attestation rule"* | The attestation is scoped **only to archive eligibility**; the worker layer is explicitly *"arbitrarily helpful, zero authority"* | ❌ — it is **permitted**. The risks are elsewhere (§3) |
| *"`task --resume` gives us a resumable discussion thread"* | No thread-id pin; targets *"latest task job in session"*; silently cold-spawns on `-32001` | ❌ — use **stateless context packets** in `--fresh` calls |
| *"Blind-parallel preserves independence, so it beats dialogue"* *(the design that commissioned round 1)* | The blind arm **ships an unchallenged false claim** — you must *see* a claim to falsify it. And blindness gave **no** protection against the **shared-frame** error (both cold answers already held it) | ❌ **as stated** — superseded by **falsifier-execution** (G-CONSULT-1) |
| *"Round 1 shows dialogue does not cause anchoring"* | Round 1's **own measurers**: the packet forbade accommodation, allowed one round, and made every claim checkable. **All three conditions anchoring needs were engineered away** | ❌ **near-uninformative** — do not cite. Round 2 (§5) is the real test |
| *"A decision packet can be made neutral by declaring it neutral"* | The packet recited the repo's recorded conclusion; `fable-5` cited the repo's doc **by name** as authority. Cold agreement was **doc-anchored**, not independent | ❌ — **doc-to-model** anchoring dominates model-to-model |
| *"Two-model agreement raises confidence in a claim"* | **Both** models agreed the two historical `exit 0`s were correct waivers. **One was a bypass** (259 LOC). Second independent confirmation of tar-pit §12 | ❌ **refuted again** — agreement bounds **bloat**, not **wrongness** |
| *"The value is concentrated at the one big design fork; a lifecycle partner multiplies cost for shrinking returns"* *(**my** objection to the user's design)* | **S3/apply produced 4 verified, stage-exclusive, leak-resistant findings with ZERO cross-family overlap** — including a still-open coverage hole in shipped code. They **require the code to exist** and therefore *cannot* be produced at the design fork | ❌ **REFUTED by existence proof.** The user was right that value exists downstream of design. ⚠️ But **archive returned ZERO** ⇒ *"consult at every stage"* is **also** refuted. The shape is **selective** (**G-CONSULT-10**) |
| *"Multi-turn dialogue makes both models co-adapt into mutual mush"* *(objection (1), as literally stated)* | `gpt-5.6-sol` **held** — refused the convergence narrative unprompted, held 3 positions, **subtracted** mechanisms. And the sharpest claim in the transcript **survived all 3 rounds in both models, stated more forcefully** | ❌ **as stated** — ❗ but the effect is **REAL and ASYMMETRIC**: the **Claude-family** side folded and published a false *"joint, final"* consensus. **Worse than symmetric mush, because that side writes the artifacts** (**G-CONSULT-9**) |
| *"Round 2's permissive/multi-round/unfalsifiable design finally tests anchoring cleanly"* | Both models read the **uncommitted working-tree** capture (F9/G-GATE-8 — *the previous round's measurer output*) and cited it **by line number**; the packet's own "unresolved objection" is a near-verbatim lift from it | ❌ **contaminated — by this very investigation.** And R2 **instructs** accommodation (*"work together… update your view"*) as surely as R1 **forbade** it. ❗ **Neither round has EVER tested pairing under NEUTRAL framing** (**G-CONSULT-11**) |
| *"A leakage guard that instructs 'do not read AGENTS.md' keeps a historical-change experiment blind"* | **`CLAUDE.md`/`AGENTS.md` is AUTO-INJECTED into every agent's context.** The shipped mechanism sits **verbatim** in its Learned-refutations list; both S1 consults restated it. The whole fix was *also* sitting in a **tracked** `.diff` | ❌ **worthless** — an instruction cannot un-inject a guide. **Stash/stage-pin the tree**; check tracked artifacts too |
| *"'Pick the best of our discussion' is a workable adjudication rule"* | It needs a decider, and a model adjudicating a dispute **it is a party to** is the pattern the repo already refuted. A model-authored *dissent log* is **traceability, not protection** — the adjudicator decides what counts as disagreement, and records itself overriding the partner but **never the partner silently anchoring it** | ❌ — replace with: **measure** factual disputes · **escalate** material product tradeoffs to the human · decide the rest under **delegated** authority, recording only **material decisions** |

---

## 7. Reproducible probes — what each proves *and cannot prove*

| Probe | Proves | Cannot prove |
| --- | --- | --- |
| **Blind-parallel arm** — same packet, both models, cold, no dialogue | whether cross-family **disposition** diverges at all (it does — maximally) | ⚠️ **nothing about anchoring**, and nothing about **shared-frame** error — a frame both models already hold is invisible to blindness by construction |
| **Falsifier-execution arm** — hand each model the other's **stated falsifiers** and require it to **RUN** them | the highest-value behavior measured here: it caught a false headline claim resting on a **2-of-52 sample** | that the falsifiers were the *right* ones — a claim nobody thought to falsify stays unfalsified |
| **Third-party re-measurement** — a non-voting measurer re-derives every load-bearing number from git | ✅ the **only** thing that caught the shared-frame error (**F9**). **Non-optional.** | nothing, if the measurer shares the frame too — use **≥2**, and give one an explicitly **adversarial** lens |
| **Anchoring probe** — *permissive* framing, **≥3 rounds**, an **unfalsifiable** question, models **not told** they are measured | whether dialogue causes accommodation **under conditions that permit it** | ⚠️ **nothing, if you get any of the four conditions wrong.** Round 1 got three wrong and produced a null result that means nothing. **This is the trap.** |
| **Lifecycle marginal-value probe** — N mutually-blind consults at N lifecycle stages of a **real archived** change | whether a consult at stage N+1 finds anything stage N could not | ⚠️ **nothing, without an outcome-leakage guard.** The change already shipped and **AGENTS.md records its conclusion** — a consult that read it is reciting the answer key, not finding it |

**Dead instrument.** ❌ `task --write` drilling (rejected upstream, and nothing here changes it): loses the server-enforced schema, adds a write-safety surface (default cwd = **repo root**), and OpenAI's content filter **aborts security-flavoured drills mid-run**. Run drills in the **main loop** and hand the model the *results* in the brief.

---

## 8. Re-verify by effect

Never re-read this doc to "confirm" any of it. Re-run:

1. **The falsifier-execution win** — give two models the same packet cold; take model A's **stated falsifier** and require model B to **execute** it. Expect: a claim that survived A's own reasoning **dies on B's measurement**. (Here: `fable-5`'s *"kills the latch completely"* died on `95586b3`.)
2. **The shared-frame blindness** — after both models answer, have a **third party enumerate the population** behind any claim of the form *"the N cases were all X"* and check each. Expect: **a model that sampled 2 of 52 and generalized.**
3. **F9, the defect this produced** — `git show --stat "$(git log --diff-filter=A --format=%H -- openspec/changes/add-verification-harness/proposal.md | tail -1)^"` ⇒ **259 LOC of product code sitting inside the classifier's base.** Re-derive from git; do not cite this doc.
4. **The anchoring question** — ❌ do **not** re-verify against round 1. ✅ Re-run §5's conditions (permissive · ≥3 rounds · unfalsifiable · unaware).

---

## 9. Reusable guidelines

- **G-CONSULT-1 — The value is in *executing the other model's falsifiers*, not in discussing with it.** 100% of the measured win came from one model **running a check the other skipped**. That is adversarial **verification**, not dialogue — and it carries **none** of dialogue's accommodation risk. **Require each model to state falsifiers, then require the other to RUN them and report the results.** A consult that only exchanges opinions is paying for the expensive half and skipping the valuable one.
- **G-CONSULT-2 — Two-model agreement is not corroboration; a shared frame is invisible to both models by construction.** Blindness does not protect against it (they already hold it) and dialogue does not surface it (neither one doubts it). **A non-voting third party MUST re-derive every load-bearing number from ground truth.** This is the second independent confirmation that agreement bounds **bloat**, not **wrongness** (tar-pit §12). ⚠️ Watch for the *"the N cases were all X"* claim — check the **population**, not the sample.
- **G-CONSULT-3 — A "neutral" packet that recites your repo's recorded conclusion is not neutral. Doc-to-model anchoring dominates model-to-model anchoring.** Both models read your docs; a doc that states a preferred direction pre-anchors **both**, and their resulting "agreement" is **one source counted twice**. If a question is genuinely open, **the packet must not contain the answer the repo already wrote** — and if you cannot omit it honestly (because it is the state of knowledge), then **say the agreement is not evidence**, and route the question to measurement instead.
- **G-CONSULT-4 — Pairing conclusions enter later review ONLY as claims to challenge, never as prior validation.** Otherwise the partner acquires **causal design authority** by *normative transclusion* — advice → synthesis → normative spec → later tools treat it as ground truth → the human is handed an already-narrowed question. Zero gate force is **not** the same as zero influence.
- **G-CONSULT-5 — A model that shaped a design may not later be counted as an independent reviewer of it.** Using `gpt-5.6-sol` at design time makes the pre-archive Pass B a **correlated** review. **Suppress the two-model-consensus flag** for anything the consult shaped, and record it in the ledger header.
- **G-CONSULT-6 — To measure anchoring you must PERMIT it.** Four conditions, all required: **permissive** framing (never instruct against accommodation) · **≥3 rounds** (it is a spiral) · an **unfalsifiable** question (it bites hardest where claims cannot be checked) · models **unaware** they are measured (awareness induces a defensive hold-your-ground posture). ❗ **Get any one wrong and a null result means nothing** — round 1 got three wrong and its null result is worthless. *An experiment that forbids the effect, then reports the effect's absence, has measured its own instructions.*
- **G-CONSULT-8 — ❗ Agreement concentrates where there is a shared answer key; independent value concentrates where the models must reason from material neither has been told the answer to. So cross-family diversity buys DEFECT COVERAGE, not FRAMING diversity.** The unifying datum of round 2, and the answer to *"is fable-5 ↔ gpt-5.6-sol even the right axis?"* At **S1** (a leaked design question) the two families **agreed completely — on the answer key**. At **S3** (the neutral material of a code diff) the two families found **completely DISJOINT** finding sets. ⇒ **Cross-family is the RIGHT axis when the artifact is *code*, and largely the WRONG axis when the artifact is *a design position in a repo with strong doctrine*** — there, both models are reading the same book back to you, and *"two models agreed"* measures **your repo's opinionatedness**, not correctness. **Point the second family at the code, not at the doctrine.**
- **G-CONSULT-9 — A participating model may NEVER author the synthesis, and may never use the word "converged."** `fable-5` published a *"Converged position (joint, final)"* that its partner **refuted one turn later on four points** — including an unsound primitive `fable-5` had invented itself. ⚠️ **The dangerous asymmetry: the Claude-family model drifts, and it is also the model that WRITES THE ARTIFACTS.** So the realistic failure is **not** *"both models mush"* — it is *"the loop-driver packages the partner's name onto a synthesis the partner never ratified, and commits it to the spec"* — **normative transclusion (G-CONSULT-4) arriving via a FALSE CONSENSUS LABEL.** ⇒ A **non-participant** (the human, or a model that never spoke) must merge, and must re-run every load-bearing number. And require each model to **name every point it concedes AND its source** — *"if it came from a document rather than your partner, say so."* That clause alone would have caught the misattributed reversal in §5a.
- **G-CONSULT-10 — Marginal value across the lifecycle is NOT monotone, and NOT concentrated at the design fork. Pay for the post-implementation (apply) pass.** ⚠️ **Scope note: this guideline is about the paid model CONSULT only. It says NOTHING about the archive GATE / `⟶ archive-ritual`, which is untouched by any of this.** ✅ **FIRM half (an existence proof):** **apply** findings are **stage-exclusive** — they require the code to exist, so the design fork *structurally cannot* produce them — and **leak-resistant** (anchored in a diff, not in doctrine); apply won **despite** the earlier stages being handed the answer key. That refutes *"all the value is at the design fork"* on one clean observation, which is all an existence proof needs. ⚠️ **HEDGED half (n=1):** **archive** returned **zero**, and its work is already performed by `openspec validate --all --type spec` — but that is **one observation on one code-heavy, mechanism-shaped change whose archive was a mechanical spec merge**; a docs/process change could plausibly invert the ordering. ⇒ Working shape, **not settled**: explore (cheap; a wrong mechanism is cheapest to fix there) · propose (only if a real unresolved choice remains) · **apply — the one to pay for** · archive — **treat as low-yield until someone measures a second change.**
- **G-CONSULT-11 — A repo is not an inert backdrop: your agents read the working tree, and your project guide is AUTO-INJECTED.** Two ways this destroyed round 2's isolation. **(1) Uncommitted files are still on disk** — the round-1 capture (F9/G-GATE-8) was written to the working tree *before* round 2 ran, and **both models read it and cited it by line number**; the "arguments" driving position change were **retrieved from a document, not generated by the partner** (one model even narrated a doc-driven update as *"where you moved me further than you argued"*). **(2) `CLAUDE.md`/`AGENTS.md` is injected into every agent's context** — so a *"do not read AGENTS.md"* leakage guard is **worthless**, and it **failed outright**: the change's shipped mechanism sits verbatim in the Learned-refutations list. ⇒ For any experiment that must be blind: **stash or stage-pin the tree, use a stage-era guide, and check whether the answer is in a *tracked* artifact too** (here the whole fix was sitting in a committed `.diff`). **Assume your agents have read everything you wrote, including what you have not committed.**
- **G-CONSULT-7 — "Pick the best of our discussion" needs a named decider, and a party to the dispute cannot be it.** A model-authored dissent log is **traceability, not protection**: the adjudicator decides what counts as disagreement, and records itself overriding the partner but never the partner **silently anchoring it**. Instead: **measure** factual disputes · **escalate** material product tradeoffs to the **human** · decide the rest under **delegated** authority · record only **material** decisions (chosen approach · decisive evidence · strongest rejected alternative · unresolved risk + revisit trigger).

---

## 9b. ❗ Best practices for integrating `gpt-5.6-sol` (the operational playbook)

*Earned across five runs. The strategic half answers **what a second model is for**; the operational half is a list of things that each cost a failed run to learn. Nothing here needs a human attestation — **the whole playbook carries zero authority by construction.***

### The one-sentence version

> **A second model is not a smarter oracle. It is an INDEPENDENT RE-MEASURER WITH AN ATTACK MANDATE.** It earns its cost by *running the checks the first model skipped* — not by knowing things the first model didn't.

`gpt-5.6-sol` said this about itself, unprompted, and every measurement agrees: *"Nothing about this required a capability unavailable to one careful model. My concrete contribution was **independent remeasurement**… the useful difference is **redundancy and a fresh attack**, not a claim that a single model could not have reached the same result."*

### ⚠️ The failure mode that matters most: **two approving models are not evidence — they are a warning sign**

Measured **three times**, and the third is the one to remember:

| Run | What "both models agreed" produced |
| --- | --- |
| Round 1 | Both agreed the classifier's two `exit 0` verdicts were *"correct waivers."* ❗ **One had shipped 259 LOC** (**F9**). A shared false frame, invisible to both — caught only by a **non-participant**. |
| Round 2 | `fable-5` published a *"Converged position (joint, final)"* — `gpt-5.6-sol` **refuted it one turn later on four points**, including an unsound primitive `fable-5` had invented itself. **The convergence it declared did not exist.** |
| **F7 consult** | `fable-5` proposed a CI audit design; `gpt-5.6-sol` independently reviewed it — *"I would ship this detector alone."* ❗ **BOTH APPROVED.** A **non-participant** then killed it with **three verified accident-class bypasses**: it was **rename-blind** (`openspec archive` **moves** the dir ⇒ git records `R`, not `A`; `--diff-filter=A` finds **ZERO** adds on **2 of 3** real archive commits) and **would have gone GREEN on the very unattested archive it existed to catch.** |

⇒ ❌ **NEVER "loop until both models approve."** It has **no fixed point** (the tar pit: 4 bounded rounds, **+45%** bloat, a **regressed** guarantee), and — as the F7 consult proves — **it terminates happily on a broken design.** Approval is the cheapest thing a model produces and the least informative.

### The pipeline that actually works

```
   YOU state a claim ──▶ COLD · BLIND · PARALLEL (fable-5 ‖ gpt-5.6-sol)
                         attack mandate · falsifiers are COMMANDS TO RUN
                                    │
                         ONE adversarial exchange
                         "no joint answer · never say converged ·
                          name every concession AND ITS SOURCE"
                                    │
                         ▼ NON-PARTICIPANT (neither model spoke)
                         re-runs every load-bearing number from git
                         and TRIES TO KILL whatever survived
                                    │
                         ▼ YOU re-verify the load-bearing claims yourself
```

Every step that ever mattered was a **measurement**, never an opinion.

### Do this

| | |
| --- | --- |
| **Point them at CODE, not doctrine** | The biggest single lever (**G-CONSULT-8**). On a code diff the two families found **disjoint** findings; on a design question in a doctrine-heavy repo they **agreed completely — by reading your own docs back to you.** |
| **Make falsifiers COMMANDS, not arguments** | *"Run these and report what you got."* Every finding that **survived** verification was a **check**; every one that **dissolved** was an **opinion**. |
| **Attack mandate, never "work together"** | *"Work together"* produced co-authoring and a **false consensus**. *"Attack its load-bearing claims"* produced the kills. |
| **A NON-PARTICIPANT merges** | A participant asked to synthesize **publishes a false consensus** (measured twice). The killer role is the highest-value seat in the whole setup. |
| **Ask them to name each concession's SOURCE** | *"If you concede because of a **document** rather than your partner's argument, say so."* Catches a model narrating a doc-driven update as *"you persuaded me"* — measured, verbatim. |
| **Tell them approval is a warning sign** | Put the F7 no-op story **in the brief**. A model told *"if you agree with your partner, hunt for what you BOTH missed"* behaves measurably differently. |
| **Fire at explore + apply. Never at archive.** | Apply = highest clean yield (**G-CONSULT-10**). Archive = **zero** (already done by `openspec validate`). |

### ⚙️ Operational — each of these cost a failed run

- ❗ **`codex task --effort xhigh` exceeds the Bash tool's 10-minute hard cap.** A relay **subagent can never own it** — it times out (exit 143), every time. **Drive it from the MAIN LOOP with `run_in_background: true`** (detached, no cap), or have the relay `nohup` it and poll. *This killed a whole workflow.*
- **The companion broker is SINGLE-FLIGHT.** Concurrent `codex` calls **collide**. Serialize them — one in flight at a time, ever.
- ❌ **`--resume` is unreliable** — no thread-id pin (it targets *"the latest task job in this session"*), and it **silently cold-spawns** on `-32001`. ⇒ **Use stateless context packets in `--fresh` calls**: re-pass the transcript every turn. It works fine.
- **Stage the brief OUT-OF-REPO** (`mktemp`) and read it into **ONE** positional (`"$(cat …)"`). Inline literals get their backticks/`$` expanded and word-split into positionals that the companion's `join(' ')` then collapses. Out-of-repo also keeps it out of the digest and the dirty-tree refusal.
- ⚠️ **Your agents read the WORKING TREE, and `CLAUDE.md` is AUTO-INJECTED.** Uncommitted notes leak into any *"blind"* run (measured: both models read an uncommitted capture and **cited it by line number**). For blind work: **stash or stage-pin the tree**, and check whether the answer is sitting in a **tracked** artifact too.
- **`adversarial-review` is one-shot and schema-locked; `task` is free-text and multi-turn.** Use `adversarial-review` when you want the `review-output` schema for a diff; use `task` for everything else.

### What it is NOT for

❌ **Values calls.** Asked directly whether attestation fatigue outweighs classifier imprecision, **both models refused** — they escaped to a third option at round 1, independently, and never adjudicated it across three rounds. **A question your repo has doctrine on will come back as your doctrine.** Route values calls to the human.
❌ **Authority of any kind.** No verdict, no approval, no receipt, no consensus flag may gate anything. This is *why* the playbook needs **no attestation** — it certifies nothing.

## 10. Evidence artifacts

- Workflows **`wf_7dc648df-c92`** (round 1) · **`wf_ad1902f2-a7e`** (round 2). Journals carry every model's verbatim answer and both measurers' structured verdicts.
- The decision packets (out-of-repo by design — see §2 delivery): round 1 = the scope-classifier narrowing question; round 2 = the attestation-fatigue question.
- The defect this research produced: **F9 / G-GATE-8** in [`cross-review-gate-defect-forensics.md`](cross-review-gate-defect-forensics.md), independently re-verified against the live repo.

## 11. Open — **not** decided here

- ❓ **The shape is now measured, but NOT yet decided.** The evidence says: **cold-blind parallel · ONE adversarial exchange with an ATTACK mandate (never a "work together" mandate) · a NON-PARTICIPANT merges · falsifiers get RUN, not stated · fire at explore + apply, drop archive.** That is neither the *"lifecycle-wide pairing partner"* originally proposed **nor** the *"decision-consult at one fork"* I recommended against it. ⚠️ **Do not adopt it from this document** — it is exactly the model-authored prescription G-TARPIT-4 says to distrust. **Build the smallest version and use it.**
- ❓ **Auto-firing collides with a standing rule.** AGENTS.md: paid cross-model calls are *"user-launched only; spend is human-initiated per run; **never auto-fires**."* Auto-firing at a lifecycle boundary requires **amending that rule with a bound** (a per-change ceiling), not working around it. **Untouched by either experiment.**
- ❓ **Attestation fatigue is STILL unmeasured — and both models REFUSED to answer it.** It is the pivot for the gate's `exit 0` question (**F9**). Given the question directly, **both models escaped to a third option at round 1, independently, and never adjudicated it across three rounds.** ❗ Their one convergent substantive claim was that **no mechanism keeps vigilance sharp — the gate's premise is *self-limiting*, and human rubber-stamping (R5) is an accepted residual, not a property to engineer away.** Nothing in git can settle this. **It belongs to the human, not to a model.**
- ❓ **Pairing has never been tested under NEUTRAL framing.** Round 1 **forbade** accommodation; round 2 **instructed** it. A third run would need: neutral framing · a **clean tree** (nothing uncommitted) · a question the repo has **no** recorded opinion on · and the knowledge that the **project guide is auto-injected**. ⚠️ **Cheaper alternative, per G-TARPIT-4: stop measuring and go build it** — the two rounds already cost ~1.4M tokens and the decisive findings both came from **third-party measurement**, not from the models.
- ❗ **ACTIONABLE, and currently nobody's task:** §5d records a **real, still-open coverage hole in shipped product code** (the classic non-precise wheel path lost its cap; **every** test passes `precise: true`). That is a change proposal, not a research question.
