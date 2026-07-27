# Cross-Model Pairing vs. Consult — What a Second Model Actually Buys

> **Status (2026-07-27): historical.** The `cross-model-review` capability this research fed into
> was retired in full by `remove-cross-model-review`. The pairing-vs-consult finding (a second model
> earns its cost by running falsifiers and reading code, not by discussing) remains a valid general
> lesson, independent of the now-retired mechanism.

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

### ❗ G-CONSULT-12 — A model's finding becomes durable by being **PROMOTED INTO THE REGRESSION SUITE**, never by being **approved**. That is the only way model output legitimately crosses into authority: **by ceasing to be model output.**

*(Settled 2026-07-13 by the consult on "can attestation toil be cut without model self-certification?" — `wf_8028b3c3-911`. The proposal under test: models never approve; they emit **executable falsifiers**; CI runs them; the gate keys on the **machine's exit code**. It **DIED for green, survived for red**, and the escape it revealed is the finding.)*

**Why the falsifier scheme dies as a gate.** A falsifier has three parts — **(a) the CHOICE of what to test · (b) the COMMAND · (c) the ORACLE.** ❗ **The machine guarantees only (b).** (a) and (c) stay model-authored. So *"all falsifiers passed"* is a **deterministic function of a model-authored artifact**, and *laundering authorship through a machine does not change the authorship*:

> **`exit 0` over a model-chosen test set means exactly *"the tests I chose to write, passed."* That is an approval with a hash on it.**

- ✅ **You can automate *refutation*. You cannot automate *confirmation*.** The scheme mechanizes **modus tollens**, not **hypothesis selection**.
- ❗ **GREEN IS TESTIMONY. RED IS EVIDENCE.** A model **cannot fake a red** (anyone re-runs the command; a dismissal must become a *fix* or a *demonstrated mis-aim*, both auditable). It can **trivially manufacture a green**.
- ❗❗ **A BLIND SPOT DOES NOT EMIT A FALSIFIER AGAINST ITSELF.** The killing falsifier for the rename-blind detector is precisely the one **the two approving models did not write — because they could not see the rename.** A falsifier-emitting version of them would not have written it either.
- ⚠️ **The false-green is reachable with NO forbidden act — measured, and it is the subtlest thing in this whole document.** The **same predicate** answers **oppositely** on an invocation detail:
  ```
  git show --diff-filter=A --name-only --format='' c47a5c1                              → 0
  git show --diff-filter=A --name-only --format='' c47a5c1 -- openspec/changes/archive/ → 6
  ```
  A **pathspec suppresses rename pairing**, so destinations degrade to `A`. An **honest** model writing a falsifier to *validate* the detector's premise reaches for the **pathspec'd** form — *because that is how you would naturally look* — gets **GREEN**, and certifies a detector that is **blind**. **Correct oracle · correct command · false green · zero adversarial intent.** ⇒ **ACCIDENT-class, therefore fatal** (this repo's checks claim only to be accident tripwires).
- And the border cannot be policed: an **honest** careless weak-falsifier set and a **deliberately** weak one are **the same git observation**. Intent is not machine-decidable ⇒ **independently sufficient reason green can never gate.**

**⇒ The rule:** if you ever wire falsifiers to anything, **RED may carry force; GREEN may carry NONE.**

**The escape — and it is the whole point.** Both consulted models argued about **EXECUTION** (what the machine does with the result) when the bottleneck is **SELECTION** (what gets tested at all). Neither asked the question that rescues it: ***can the falsifier set be authored by anyone but the reviewed party?***

> ✅ **YES — by PROMOTING the durable checks into the repo's own committed regression suite.** At that moment they **stop being model artifacts**: human-reviewed, repo-owned, and **running on every future change regardless of who proposed them**. It is **not a review-time mechanism** — it is how a finding becomes **permanent**.

**So the shape of a healthy integration is a one-way ratchet:**

```
  model ATTACKS ──▶ emits a falsifier ──▶ a HUMAN reads it and judges it worth keeping
                                                        │
                                                        ▼
                                       COMMITTED to the regression suite
                                       (now repo-owned; no model authority;
                                        runs forever, on everyone's changes)
```

**Honest toil accounting — three layers (do not let anyone sell you layer (b) as layer (a)):**

| Layer | Removable? | |
| --- | --- | --- |
| **(a) The mechanical checks** — re-typing four prose checks, running the digest by hand | ✅ **YES — fully, with ZERO model trust.** ❗ **The largest available cut, and it has NOTHING to do with falsifiers.** The checks are deterministic, committed, and read no model artifact — and **`exempt_by_act()` (check 4) ALREADY EXISTS as working code** (`scripts/test-cross-review-scripts.sh:84`), **living in a test harness, wired to nothing.** *This is **F7**.* |
| **(b) The ledger read** | ⚠️ **Improved, not shortened.** On one measured ledger, **8/14 findings (57%) were CHECK-class** and all 8 survived verification — presenting those as an *executed results table* rather than an *argument to referee* is a real cognitive win. **But findings ≠ minutes** (the **OPINION** ones are the *hard* ones and they all stay), and a **NEW** cost appears: **auditing the falsifiers themselves** for coverage, fixture-vs-history, and invocation mismatch. **Net: better fifteen minutes, probably not fewer.** |
| **(c) Judge sufficiency · Attest** | ❌ **0% removable, forever, for a git-only gate.** The falsifier set is a **positive enumeration** — what you need to know is what is **ABSENT** from it, and absence has no machine-readable form. And recursively: **classifying a finding as CHECK vs OPINION is itself a soundness judgment.** *Human review is an event in the world, not a property encoded in git.* |

❌ **"Loop until both models approve, and let that be the attestation" — 0% achievable, and the falsifier reframe does NOT resurrect it.** Two models approved the rename-blind detector; their agreement was worth **nothing** against a bug **three commands** expose. **You cannot remove the human. You can only make the human's fifteen minutes count.**

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

---

## 12. Round 3 (2026-07-13) — the consult KILLED THE LOOP-DRIVER'S OWN DESIGN, and G-CONSULT-8 needed sharpening, not refuting

**Provenance:** an `/opsx:explore` fan-out on a *real* open question (how to stop `AGENTS.md` regrowing),
run as a **three-arm** consult with **disjoint mandates** and a **non-participant re-measurer**. Unlike rounds
1–2 this was **not an experiment about consulting** — it was a consult doing real work, and the findings are
a by-product. That makes it the cleanest evidence in this doc (**G-TARPIT-4**: build it and use it).
Captured findings → [`agents-md-structural-best-practices.md`](agents-md-structural-best-practices.md) §A.

### 12a. The arms, and why they were disjoint

| arm | mandate | why |
| --- | --- | --- |
| **fable-5** (in-repo) | **measure**: per-item disposition audit of every rule/bullet — bytes, duplication target, reachability, staleness. *"Measure. Table. Number."* | its edge is in-repo derivation with ground truth on disk |
| **`gpt-5.6-sol`** (external) | **attack**: falsify the loop-driver's stated thesis; construct ACCIDENT-class bypasses of its proposed guard | no loyalty to repo doctrine |
| **Claude Code docs agent** | **source**: what does the loading model *actually* do (eager vs. lazy)? | the decisive constraint was **undocumented in-repo** |
| **Opus (non-participant)** | **re-derive every load-bearing number from ground truth** (G-CONSULT-2) | the only thing that caught the shared false frame in round 2 |

⚠️ **The contamination hazard was maximal and was faced explicitly:** the artifact under review
(`AGENTS.md`) is **auto-injected into both models' context** (G-CONSULT-11), and it *contains a refutations
list that already states a hypothesis close to the loop-driver's*. Counter-measures: state the thesis
**explicitly as the target to attack** (*you cannot crib a hypothesis you are ordered to kill*), demand
**DERIVED vs REFLECTED** labels per claim, and give each arm a mandate whose answer is **on disk**, not in
doctrine.

### 12b. ❗ FIRM — the second model killed a design the loop-driver had already committed to in writing

The loop-driver proposed a **per-unit word cap** on refutation entries and argued it was *compression-proof*
(*"you cannot cram 1,400 words of mechanism into 60 words — you are forced to move it to the research doc"*).
`gpt-5.6-sol` killed it in one line:

> *"Split one 1,400-word entry into **twenty-four ≤60-word bullets**. It passes per-bullet lint, preserves
> nearly all the cost, and destroys atomic scanability."*
> *"These are not adversarial evasions; they are **predictable responses to a locally failing lint rule**."*

The cap bounded the **unit** and left the **tier** unbounded. Because **bullet-splitting is what an HONEST
session does** when told "keep bullets short," this is **ACCIDENT-class ⇒ fatal** under the repo's own
standard (G-GATE-2) — not an R3 residual to be waved through. It also named three more accident-class
failures the loop-driver had not seen, including the deepest one: at a ceiling, *"sacrifice older
load-bearing rules to admit the newest incident — **the guard guarantees size, not retention value**."*

**This is the first time in this repo's five cross-model docs that a consult killed a design the loop-driver
was already writing down.** Prior wins were *finding a defect in existing artifacts*; this one **stopped a
bad mechanism from reaching a proposal**.

### 12c. ✅ G-CONSULT-8 is SHARPENED, not refuted — the discriminator is the ANSWER KEY, not code-vs-doctrine

**The loop-driver predicted this arm would add little**, citing G-CONSULT-8 (*"point the second family at the
CODE, not the DOCTRINE"* — and `AGENTS.md` restructuring is **pure doctrine**). It produced the single most
important finding of the session. **But that does not refute G-CONSULT-8 — it locates it more precisely:**

- The arm was **not reviewing doctrine.** It was attacking a **design invented twenty minutes earlier**, which
  exists in **no document either model had read**.
- G-CONSULT-8's real mechanism was always *"agreement concentrates where there is a **shared answer key**."*
  **Code** is merely the most common place where no answer key exists. **A fresh design is another.**

⇒ **G-CONSULT-13 (below).** The operational rule changes: *don't ask "is this code or doctrine?" — ask
**"does the repo already contain the answer?"*** A novel design is the ideal consult target **even on a
doctrine topic**, and a settled doctrine question is a waste **even about code**.

### 12d. ✅ The non-participant adjudicated the two models — and found the winner's own claim UNDERSTATED

The two arms **disagreed on the fix** (fable: compress 14 long bullets — a **one-time diet**; gpt: an
**atomicity invariant** — a standing rule). Third-party re-measurement settled it, and **strengthened gpt's
case beyond what gpt itself claimed**:

- gpt claimed the top two entries were *"demonstrably non-atomic"* (**20** numbered subclaims).
- Re-derived: **only 2 of the 25 entries are non-atomic at all**, and those 2 carry **23 of the tier's 23**
  inline numbered sub-findings — while holding **54.5%** of the tier. **The other 23 entries are already in
  the correct one-liner form.**

⇒ The atomicity rule catches **100% of the observed bloat and touches nothing that works**; the length-based
approach would have forced edits to **14 healthy bullets** and left the actual mechanism intact. **Neither
model computed this.** Consistent with **G-CONSULT-2**: the third party is not a formality.

### 12e. ⚙️ Codex operational forensics — the run cost three dead jobs, and the failure mode was invisible

✅ **FIRM — the ZOMBIE failure mode.** `codex task` jobs die **silently**: the underlying codex thread
terminates, **the companion never observes it**, and the job sits in `status: running` **indefinitely** —
measured at **1h49m** and **1h59m** with the last real log line ~1h40m earlier. Cancelling prints the tell:
`Codex turn interrupt failed: thread not found: <thread-id>`.

| | `Turn completed` | `thread not found` on cancel |
| --- | --- | --- |
| jobs that **died** | **0** | **yes** |
| jobs that **completed** | **1** | **no** |

- ❗ **`status: running` is NOT a liveness signal. Only LOG-FILE GROWTH is.** (`wc -c` the job's `logFile`;
  a live job writes every few seconds. A stall of ≥5 min with `status: running` = a zombie.) Discriminator for
  a genuine completion: `grep -c 'Turn completed'` → **1**.
- **Measured rate: 4 zombies in 10 `task` runs (~40%).** This is not an edge case; **budget for it.**

### ❗ 12e-bis. RETRACTION — the CAUSE is NOT established, and this doc asserted one that was FALSE

⚠️ **An earlier version of this section (committed in `fb6121e`) claimed: *"all 3 deaths overlapped another
running job; all 3 successes ran alone ⇒ the single-flight broker collision."* That claim is REFUTED, by the
very next observation.** A 4th job zombied while running **completely alone**, with the queue **verified empty
at launch** (`status --json` → `running: 0`). The full population:

| packet | concurrent? | outcome |
| --- | --- | --- |
| 2,421 B | alone | ✅ completed (~4 min) |
| **5,505 B** | concurrent | ❌ zombie |
| **6,553 B** | — | ✅ **completed** |
| 7,266 B | concurrent | ❌ zombie |
| **15,469 B** | **ALONE (queue verified 0)** | ❌ **ZOMBIE** |

⇒ ❌ **Concurrency is REFUTED as the cause** (a job died alone). ⇒ ❌ **Packet size is REFUTED as the cause**
(a **6,553 B** packet completed while a **5,505 B** one died). ❓ **The cause is UNKNOWN.** Both theories were
n=3 generalizations that the 4th data point killed.

❗ **This is a self-inflicted instance of G-CONSULT-2 — *"check the POPULATION, not the sample."*** The doc
had that guideline written down, and the loop-driver **still shipped a confident causal claim from n=3**, in
the same commit that restated the guideline. **Serializing codex calls remains good practice (G-CONSULT-7 is
independently motivated), but it is NOT a fix for the zombies, and this doc must not be cited as saying it is.**

### 12e-ter. Operational facts that DID hold

- The companion's `task` runs **inline/blocking**, not detached — but **killing the invoking `node` process
  does NOT kill the job** (the companion owns it; it kept running after a harness Bash timeout at 2 min).
  Driving it under the harness's `run_in_background` returns **exit 0 immediately**, so *"finished"* and
  *"still running"* look identical. **Never read exit 0 as completion.**
- `result <id>` resolves **only finished** jobs — for a running one it errors *"No job found"*, which reads
  like a crash and is not.
- ⚠️ **`codex task --help` RUNS A TASK.** There is no help flag on the subcommand; the string becomes the
  prompt. It burned a 12 s job and a runtime slot.
- **Cost of the lesson:** ~3h of wall-clock across four zombie jobs.

### 12f. Fates table (round 3)

| Claim | Fate | Killed / confirmed by |
| --- | --- | --- |
| "A per-unit word cap is compression-proof" (loop-driver) | ❌ **REFUTED, ACCIDENT-class** | `gpt-5.6-sol`: split into 24 short bullets |
| "This is doctrine ⇒ the second model will add little" (loop-driver, citing G-CONSULT-8) | ❌ **REFUTED as stated** → ✅ **sharpened** into G-CONSULT-13 | the arm attacked a **fresh design**, not doctrine — no answer key existed |
| "The codex jobs hung because the packet was too big / `xhigh`" (loop-driver) | ❌ **REFUTED** | a **6,553 B** packet completed while a **5,505 B** one died |
| "The codex zombies are caused by the single-flight collision — every death overlapped another job" (loop-driver, **shipped in `fb6121e`**) | ❌ **REFUTED — and it was MY OWN n=3 overgeneralization** | the **next** job zombied while running **ALONE**, queue verified empty. ⇒ **cause UNKNOWN**; see §12e-bis. A self-inflicted violation of this doc's own **G-CONSULT-2** (*check the population, not the sample*) |
| "`status: running` means the job is alive" | ❌ **REFUTED** | 4 zombies held `running` for up to 1h59m with a dead thread (**~40% of all `task` runs**) |
| "The two models will agree (both read the same auto-injected file)" | ✅ **agreed on the DIAGNOSIS, disagreed on the FIX** — and the fix is where the value was | third-party re-measurement adjudicated |
| gpt's own claim: "the top two entries are non-atomic" | ✅ **CONFIRMED and UNDERSTATED** | **2 of 25** non-atomic, holding **54.5%** and **23/23** subclaims |

### 12g. Reusable guidelines (extend §9)

- **G-CONSULT-13 — ❗ Point the second model where THE REPO HAS NO ANSWER, not merely at "code."** This
  supersedes the operational reading of **G-CONSULT-8** (*"code, not doctrine"*), whose **mechanism** was always
  *"agreement concentrates where there is a shared answer key."* Code is only the **most common** place with no
  answer key. **A design you invented ten minutes ago is another** — and it is an **ideal** consult target even
  on a pure-doctrine topic, because neither model can retrieve the answer, so both must reason. Conversely a
  settled doctrine question is a waste **even when it is about code**. ⇒ **The test before spending a consult
  is not *"is this code?"* but *"could either model retrieve this answer from something it has read?"*** If yes,
  do not pay — you will be handed your own file back. **Corollary: the highest-value consult target is the
  design the loop-driver has NOT yet written down** — that is also the last moment a bad mechanism is cheap
  to kill (12b: it was killed **before** it reached a proposal).
- **G-CONSULT-14 — Verify a background model's LIVENESS by output growth, never by its status field.** Four
  `codex task` jobs (**~40% of all runs**) reported `status: running` for **up to 1h59m** with a **dead**
  underlying thread (`thread not found` on cancel; `Turn completed` = 0). A status field reports *what the
  supervisor believes*; a growing log reports *what is happening*. **Poll `wc -c` on the job's `logFile`; treat
  ≥5 min of zero growth as death and reap it.** ⚠️ **The CAUSE of the zombies is UNKNOWN — neither concurrency
  nor packet size survives the data (§12e-bis). Do not ship a fix for a cause you have not established;
  ship the DETECTOR.** ❗ *This guideline exists because the loop-driver shipped a confident causal claim from
  **n=3** — in the same commit that restated **G-CONSULT-2** (check the population, not the sample) — and the
  **next** observation refuted it. **A guideline you have written down but do not APPLY TO YOURSELF is not yet
  a guideline.***
- **G-CONSULT-15 — State your thesis to the adversary EXPLICITLY, as the target.** The contamination hazard was
  maximal here (the artifact under review is **auto-injected**, and it already contains a hypothesis close to
  the loop-driver's). Naming the thesis and ordering the model to **falsify it** converts the leak into a
  **constraint**: *you cannot crib a hypothesis you have been ordered to kill*. Pair with **DERIVED vs
  REFLECTED** labels per claim — *"REFLECTED claims are worthless here"* — which makes doc-regurgitation
  (**G-CONSULT-3**) visible instead of invisible.

### 12h. Re-verify by effect

- **The kill:** re-run gpt's own falsifier, offered unprompted and reproducing exactly —
  ```sh
  awk '/^\*\*Learned refutations/{p=1;next} p&&/^## /{exit} p&&/^- /{print}' AGENTS.md |
  perl -ne '@w=/\S+/g; print scalar(@w),"\n"' | sort -nr |
  awk 'NR<=2{t+=$1}{a+=$1;n++}END{printf "entries=%d top2=%.1f%% mean=%.1f\n",n,100*t/a,a/n}'
  # 2026-07-13: entries=25 top2=54.5% mean=177.7
  ```
- **The atomicity census** (the number neither model computed):
  ```sh
  awk '/^\*\*Learned refutations/{p=1;next} p&&/^## /{exit} p&&/^- /{print}' AGENTS.md |
  awk '{n=gsub(/\*\*\([0-9]+[a-z]?\)/,""); if(n>0){c++; tot+=n}} END{printf "%d non-atomic, %d subclaims\n",c,tot}'
  # 2026-07-13: 2 non-atomic, 23 subclaims
  ```
- **The zombie discriminator:** `grep -c 'Turn completed' <job>.log` → **1** = a real completion; **0** plus
  `thread not found` on cancel = a zombie that reported `running` the whole time.

### 12i. Evidence artifacts

- Codex job logs (all 22): `~/.claude/plugins/data/codex-openai-codex/state/xtty-*/jobs/*.log`. The three
  zombies: `task-mrj88vi5-csv0lh`, `task-mrj8lwrk-67hwez`, `task-mrjbowxo-ukliuh`. The successful lean
  relaunch: `task-mrjcnovf-eufx0j` (~4 min, run alone).
- The decision packets (out-of-repo by design, §2): the 5 KB packet that ran into three zombie jobs, and the
  ~600-word lean packet that completed.
- The captured findings: [`agents-md-structural-best-practices.md`](agents-md-structural-best-practices.md) §A
  (addendum 2026-07-13).
