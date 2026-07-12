# The Cross-Review Archive Gate — Defects Found by *Using* It

**Provenance:** 2026-07-12, produced by **using** the archive gate shipped one day earlier (`add-cross-model-design-review`, archived 2026-07-12) on the next real change — not by reviewing its spec. Every claim below was **measured by effect** against the **real committed scripts** (`scripts/cross-review-scope.sh`, `scripts/cross-review-digest.sh`) in **throwaway `mktemp -d` repos**; the live repository was never mutated. Time-sensitive: file counts are **HEAD-dependent by construction** (that is finding **F6**) and are stamped at `HEAD = f1f9edc`.

**Headline:** *Four measured defects in the shipped gate — a **re-attestation deadlock**, a scope classifier that **answers a prospective question with a confident false negative**, a **verified bypass** (uncommitted implementation ⇒ the entire precondition is **skipped**), and **HEAD-dependent range pollution**. ⚠️ **This doc deliberately prescribes NO fix for check (4).** Its prescription flipped **three times** under review — the last flip proving that deleting the counter also deletes the gate's **principal accident tripwire** (silent re-attestation), and that the counter's value and its liveness cost are **the same property**. That oscillation is itself the finding (**G-TARPIT-1/3**). Take the measurements into an explore; do not propose a check-(4) change from this document. This is **G-TARPIT-4 in action** — none of it was visible from the spec; all of it appeared on first use.*

**Companion docs.** [`cross-model-review-tar-pit-forensics.md`](cross-model-review-tar-pit-forensics.md) (why *hardening* this gate does not terminate — **G-TARPIT-1..5**) and [`cross-model-design-review-axes.md`](cross-model-design-review-axes.md) (why two model families are complementary). **This doc is the third:** what the shipped gate actually does when you run it. Note the direct line: **§11 of the tar-pit doc *added* check (4)'s strong form** (commit `3319785`, a two-model co-draft, net-neutral) to close the post-attestation-rewrite gap. **F2 below shows that hardening did not close it** — and it bricked the honest path. **§11's hardening was itself a tar-pit relapse.**

## Sources

- Co-research Workflow **`wf_9af3679c-537`** — Fable-5 ‖ `gpt-5.6-sol` ‖ Opus adjudicator, 3 bounded rounds, **converged**, ~886k tokens.
- Adversarial verification Workflow **`wf_cfbf0992-20b`** — 9 agents, ~676k tokens.
- The live tri-pass cross-review of `fix-cross-review-gate-task-emission` (2 bounded rounds): committed ledger at `openspec/changes/fix-cross-review-gate-task-emission/cross-review-ledger.md` (findings **F1–F12, G1–G11**).
- Commits `3815113` → `eadd8d0` → `f1f9edc`.
- The shipped gate: `openspec/specs/cross-model-review/spec.md`; AGENTS.md → *Cross-model design review + the human-attestation archive gate*; `scripts/cross-review-{scope,digest}.sh`; `scripts/test-cross-review-scripts.sh`.

---

## 1. The gate, as shipped (mechanism)

Archiving an **in-scope** change is refused unless four checks hold. Their **only** committed executable is `exempt_by_act()` in `scripts/test-cross-review-scripts.sh` (a *test harness*); the rest is prose in AGENTS.md that a human/model re-types at archive time.

| # | Check | Encoding |
| --- | --- | --- |
| 1 | attestation line exists, exactly once, well-formed | `grep -c '<!-- cross-review-attestation:' = 1` (**shape is not validated** — `<!-- cross-review-attestation: LOL -->` passes) |
| 2 | reviewed-state digest **recomputes** and string-equals the attested value | `scripts/cross-review-digest.sh <change>` |
| 3 | tree/index clean | the digest tool's own refusal |
| 4a | **counter:** line added exactly once, never deleted/modified | `now==1 && adds==1 && dels==0` over `git log -p -- tasks.md` |
| 4b | **confinement:** the attestation-**introducing** commit's `tasks.md` hunk is confined to the attestation line + checkbox **ticks** | **prose only — no executable** |
| 4c | **later-commits:** every commit *after* the attestation touches only bookkeeping surfaces — **no reviewed artifact, no gate implementation** | **prose only — no executable**; largely **redundant with check (2)** |

⚠️ **Check (4) has THREE clauses as specified, not two.** An earlier draft of this doc decomposed it as 4a/4b and **omitted 4c** — corrected here. Any surgical edit to check (4) must say what happens to **all three**. Note the provenance, which is decisive for the fix: **commit `3319785` (tar-pit §11) added *only* 4a.** 4b and 4c **pre-existed** it. So *"delete 4a, keep 4b/4c"* is exactly *"revert what §11 added; keep what was already there."*

The digest hashes **HEAD content of every path in `git diff --name-only B..HEAD`** (B = parent of the `proposal.md`-introducing commit), *excluding* the advisory ledger and, inside `tasks.md`, the attestation line + checkbox **state** (so a tick does not move the digest, but task **text** does).

Design **D10** already disclaims adversarial force for **all four** checks: they are *"accident tripwires and human-legibility aids"*, with adversarial resistance resting on the human + the accepted **R3** residual (a repo-controlling model performing a forbidden act).

---

## 2. Findings

### F1 — The re-attestation deadlock ✅

Once post-attestation drift invalidates check (2), **every forward-history re-attestation fails check (4a)**:

| Recovery attempt | result |
| --- | --- |
| modify the digest in place | `adds=2 dels=1` ❌ |
| delete + re-add the line | `adds=2 dels=1` ❌ |
| append a second line | `now=2 adds=2` ❌ |
| `git revert` | `dels=1` **forever** ❌ |
| **`git reset`/amend the attestation commit away, re-land, re-attest** | **all checks PASS** ✅ |

`git log -p` walks **reachable** history only, so the dropped attestation commit vanishes from the count. **The only escape is a history rewrite.** Meanwhile the spec's own fail-closed scenario mandates *"a fresh review and attestation"* — the exact act check (4a) forbids. **The spec mandates a recovery its own check makes impossible.**

This was **known**: the archived change's ledger carries it as finding **rB1** (HIGH, raised by `gpt-5.6-sol`), dismissed as an accepted residual whose recovery is *"rewriting the LOCAL pre-archive attestation commit."* What the dismissal never weighed: **that recovery gesture is byte-for-byte the attack in F2.**

### F2 — Check (4a) is adversarially **null**, *as specified* ✅

Three attacks pass **all four checks** on content the human never reviewed:

- **reset-laundering** — edit a reviewed file → `git reset` the human's attestation commit away → re-attest to the new digest. `now=1 adds=1 dels=0`, tree clean, digest recomputes.
- **amend-forge** — one commit carrying the reviewed-file edit *and* the attestation; `--amend` fills in the post-edit digest.
- **split-commit forward forge (decisive)** — edit the reviewed file in commit **A**, write the attestation in commit **B**. **Two plain forward commits. Zero history rewriting.** Passes the counter **and** the confinement clause. Measured:

  ```
  check1 now=1 · check2 recompute==attested · check3 clean · check4a adds=1 dels=0 · check4b SATISFIED
  git show HEAD:src/reviewed.txt  →  "SPLIT-FORGE content the human NEVER saw"
  ```

So check (4a) catches only the **naive in-place rewrite** — a variant no actor, honest or hostile, needs to use. **It is null even as *specified*, not merely as implemented.**

**Precision that matters** ❗ An honest recovery and the attack do **not** produce "the same git state" — they differ (`adds=2/dels=1` vs `adds=1/dels=0`). The correct claim is that they are **mechanically indistinguishable *to the gate***: git can record *what changed*, never *whether a human read it*. That distinction is **unsolvable by design** — attempting to mechanize it is the refuted tar pit.

### F3 — ⚠️ **The fix is NOT settled. This doc deliberately prescribes NONE.** ✅ (the tension is the finding)

**Read this before acting on anything above.** Earlier drafts of this section prescribed a fix. **The prescription flipped three times under review**, and the third flip found an unpriced cost in the second. That oscillation *is* the finding — it is the tar pit recurring (**G-TARPIT-1/3**), and the honest response is to **record the measurements and stop prescribing.**

| round | prescription | killed by |
| --- | --- | --- |
| adversarial verification fan-out | *"keep check (4) — the friction is the feature"* | co-research: it is adversarially null **and** liveness-fatal |
| co-research (3 rounds, **converged**) | *"delete check (4) entirely"* | cross-review: it has **three** clauses, and the decomposition was wrong |
| cross-review round 1 (**my** correction) | *"delete 4a, **keep 4b** — the sole adversarial guard"* | **Passes A + C, independently**: 4b is defeated by two plain forward commits, exactly like 4a. My "sole guard" claim was **false** |
| cross-review round 2 (Pass C) | *"…and deleting 4a is not free either"* | **measured** — see the tension below |

#### The genuine, unresolved tension (measured, both horns)

**Horn 1 — 4a is the gate's PRINCIPAL accident tripwire.** Delete it and a model can **silently re-attest** in one plain forward commit. Measured:

```
human attests → reviewed file drifts → model re-runs the digest tool and refreshes the attested value
check(2) PASS  ← green again, on content the human NEVER re-read
check(4a) adds=2 dels=1 FAIL   ← the ONLY check that catches it
HEAD content: "DRIFTED content the human never re-read"
```

Without `dels==0`, **check (2) degrades to "the value equals itself."** And this is not an exotic adversary — it is the **most plausible accident in this repo: a well-meaning, over-helpful model "repairing" a stale attestation**, so the human never re-reads the changed state. That is *exactly* the failure the gate exists to prevent.

**Horn 2 — 4a is liveness-fatal.** It refuses **100%** of honest forward recoveries (F1).

**❗ The horns are the SAME PROPERTY.** A model silently re-attesting and a human deliberately re-attesting after a genuine re-review are **mechanically identical acts**. 4a's value *is* its cost: it forces every re-attestation to be a deliberate, effortful, history-rewriting act that a careless model will not casually perform. **You cannot delete the cost without deleting the value.** Any "fix" that admits the honest recovery admits the silent one **by construction** — the same unsolvable distinction as F2.

#### What the review established (facts, not prescriptions)

- **Check (4) has THREE clauses** (§1) — the two-clause decomposition was wrong.
- **All three are adversarially null.** 4b is defeated by two plain forward commits exactly as 4a is (Passes A + C, independently — a two-pass consensus). *"Sole adversarial guard"* was **false**.
- **4b is NOT separable from 4a as written.** Its subject is *"the attestation-**introducing** commit"* — uniquely defined **only because 4a guarantees `adds==1`**. Delete 4a (which legalises a second add — the whole point) and the anchor becomes ambiguous: anchored to the **first** add, an actor re-attests in a later commit and 4b passes against the *original* clean commit. **Any 4a-deletion MUST re-anchor 4b.** The instruction an earlier draft carried — *"targets 4a and MUST NOT touch 4b"* — was **actively harmful**; it is retracted.
- **`base=` and `head=` are decorative.** `cross-review-digest.sh` reads **neither** (0 references) — it re-derives `B` positionally and hashes at **live HEAD**.

#### An unevaluated candidate worth exploring (Pass C's — NOT endorsed here)

**Head-pinning.** Make the already-recorded `head=` field **load-bearing**: compute the digest **at the attested head**, and require that sha to be the parent of the attestation commit and an ancestor of HEAD with bookkeeping-only deltas. It is metadata-free (git ground truth + a *human-authored* field — no ownership trailer). It would **subsume 4b's catch** (smuggled content is not in `head=`'s tree, so check (2) fails without any confinement clause) and **kill F6's HEAD-dependence**.

⚠️ **But it does not resolve the tension above** — a re-attestation still rewrites the line, so the silent-re-attestation horn survives. It is a **promising partial**, unrun, and it belongs in an **explore**, not in this doc.

#### The instruction this doc actually gives

**Do not propose a check-(4) change from this document.** Take the *measurements* (F1, F2, F4, F5, F6 — all solid) into an `/opsx:explore`, and design the fix there against **both horns**, with the three-clause decomposition and the re-anchoring requirement in hand. **A research capture records what is; it must not pre-decide a fix that three review rounds could not settle.**

**Probe subtlety — this is why the 4b error was easy to make** ❗ Testing confinement requires **normalizing checkbox state before diffing**. A *tick* (`[ ]`→`[x]`) and a *new task line* are both `+`/`-` checkbox lines in a raw hunk. My first probe filtered *all* checkbox lines and reported a **false negative**. The correct probe compares the **set of task texts** with the box normalized:

```bash
tasktexts(){ git show "$1:.../tasks.md" | sed -e "/$SENTINEL/d" -e 's/^\(- \)\[[ xX]\]/\1[ ]/'; }
diff <(tasktexts "$IC^") <(tasktexts "$IC")   # empty ⇒ confined
```

### F4 — The scope classifier is **retrospective**: a not-in-scope verdict is a **false negative**, not an abstention ✅

`scripts/cross-review-scope.sh:54` is `paths="$(git diff --name-only "$B"..HEAD)"` — **paths already committed**. It never sees paths a change *declares it will touch*. So the verdict is a function of *(repo HEAD, what is committed so far)* and **moves across a change's lifecycle**:

```
uncommitted           → exit 2    (no proposal.md commit to anchor B)
propose committed     → exit 0    ← "out of scope": only the change's own artifacts have landed,
                                    and openspec/changes/** is allowlisted
implementation landed → exit 10   ← "in scope": product/tooling paths now in range
```

**Only `exit 10` is positively informative.** `exit 0` and `exit 2` mean *"not yet knowable to be in scope"* — **never** *"out of scope"*. Treating `exit 0` as "out of scope" is **fail-open**, and the normal post-propose state *is* `exit 0`. Measured live on `fix-cross-review-gate-task-emission` itself (`exit 0`, 8 paths, all allowlisted).

**`exit 2` conflates four distinct `die` causes** — missing change dir, uncommitted `proposal.md`, **range-omission** (dir touched before `proposal.md`), root commit. **Only one** means "uncommitted". Treating all four as "uncommitted ⇒ non-blocking" lets a **committed malformed range** pass review and fail late at archive.

### F5 — ⚠️ A **verified bypass**: the scope call is blind to *uncommitted* implementation ✅

Clean-room measured:

```
$ git status --porcelain
?? App/Product.swift            ← real product code, UNCOMMITTED
$ scripts/cross-review-scope.sh demo
SCOPE: out — every changed path is inside the docs/tracker allowlist    → exit 0
```

AGENTS.md step-0 applies the precondition **only** *"for a change the mechanical classifier deems in scope."* So an honest checkbox-walking session that reaches `⟶ archive-ritual` with **implemented-but-uncommitted** work gets `exit 0` ⇒ **the entire four-check precondition is skipped** ⇒ `openspec archive` proceeds ⇒ the code is committed afterwards. **The gate never fires.**

**The counterintuitive crux** ❗ One naturally assumes `cross-review-digest.sh`'s **dirty-tree refusal** backstops this. **It does not.** That refusal *is* **check (3)** — it lives **inside** the precondition that was skipped. **An inner check cannot backstop an outer skip.**

**Pre-existing** — shipped with `add-cross-model-design-review`. **Fix direction:** give `cross-review-scope.sh` the same dirty-tree refusal the digest tool already has (exit 2), so an unclean tree **fails closed** rather than silently reading "out".

### F6 — Range pollution: no metadata-free fix, and worse than "digest churn" ✅

The positional base makes a **parked** change's range swallow other changes' commits. Measured at `HEAD = f1f9edc` (**and these numbers move with every commit — that is the finding**):

| change | scope | paths | own | foreign |
| --- | --- | --- | --- | --- |
| `add-git-diff-wrap-toggle` | **exit 10** | 34 | 7 | **27** |
| `add-ci-pipeline` | **exit 10** | 316 | 5 | **311 (98.4%)** |

Consequences:

1. **The digest is a function of repo HEAD** — *any* commit anywhere restages it. Combined with F1, a stale attestation is **unrecoverable forward**.
2. **It corrupts the scope classifier too**, not just the digest: `add-git-diff-wrap-toggle` classifies **in scope on 8 paths that are ALL FOREIGN**, while **its own 7 are 100% allowlisted**.
3. **The paid external reviewer reads ~80% foreign diff** for a parked change.
4. **A foreign, *archived* change's `cross-review-ledger.md` is currently hashed INTO the digest** — the exclusion is `LEDGER="$CHANGE_DIR/cross-review-ledger.md"` (line 46), which does **not** match `openspec/changes/archive/<date>-<name>/cross-review-ledger.md`.

**No metadata-free narrowing of the reviewed FILE SET exists** ❗ *(narrowed claim — an earlier draft said "no metadata-free **fix**", which over-claimed: consequence **1** may be fixable by **head-pinning** (F3) and consequence **4**, the archived-ledger glob, is a **one-line fix** this doc names and then wrongly filed under "no fix".)* Co-commit attribution, tested retroactively on the repo's own archived change, **misses 8/20 paths including both gate scripts** (xtty commits code separately from the `tasks.md` tick). Narrowing further would re-import the **`OpenSpec-Change:` ownership trailer this repo explicitly refuted and deleted**.

**Severity:** pollution is **fail-closed** — over-inclusion costs one unnecessary review, it can **never** produce a bypass. So it is **noise, not a hole** — but it is the mechanism that makes F1 *terminal* rather than merely annoying.

---

## 3. Retired theories (fates table — each ❌ next to the experiment that killed it)

| Theory | Refuted by | Fate |
| --- | --- | --- |
| "check (4) is **sound** — the adversarial defense against re-forge" | reset-laundering, amend-forge, **and** the split-commit forward forge — all pass four-of-four | ❌ |
| "first-forge only defeats a *negligent* human; re-forge defeats a *diligent* one — the asymmetry justifies check (4)" | **both** forges are the model performing the human-only act = **R3**, one already-accepted residual. (**R5** is the *human* rubber-stamping — a **different actor**.) No trust-class asymmetry exists | ❌ |
| "**RELAX** check (4)" (keep `now==1` + operative-line confinement + re-anchored later-commit classification) | **Fable-5's own drill**, which it built and then used to **withdraw its own proposal**: `{3-check ALLOW}` ⊇ `{relaxed PASS}` ⇒ **zero verdict change**, while *adding* `git log -S` operative-line discovery, diff normalization, and commit classification. A **strictly dominated no-op** that had self-labelled `fix_is_subtractive: true` — falsely | ❌ |
| "**DELETE check (4) entirely**" (the co-research's *converged* conclusion) | the **G4 amend-bundle** experiment: only the confinement clause catches it | ❌ → **narrowed** to *"delete 4a, preserve 4b"* (**F3**) |
| "branch protection makes the deadlock **terminal**" | live: `gh api .../branches/main/protection` → **404 "Branch not protected"**; `rulesets` → `[]`; `add-ci-pipeline` task 5.5 is `(Optional)` and **unticked**; solo owner holds `admin:true` | ❌ |
| "check (4) catches **zero** accidents" (Fable-5, round 1 — **retracted by Fable-5 itself**) | `gpt-5.6-sol` was **right** to insist otherwise: a metadata-only edit to `base=`/`head=`/`reviewed=` is invisible to check (2) (the digest excludes the **whole** attestation line) and refused **only** by check (4). Low value — but not zero. *(gpt's proposed check-(1) template regex does **not** recover it — measured.)* | ❌ |
| "the honest recovery and the attack produce the **same git state**" (my own phrasing) | they differ: `adds=2/dels=1` vs `adds=1/dels=0` | ❌ → **"mechanically indistinguishable *to the gate*"** |

---

## 4. Reproducible probes — what each proves *and cannot prove*

All run in `mktemp -d` throwaway repos against the **real** committed scripts. **The live repo is never mutated** — verify with `git rev-parse HEAD` before and after.

| Probe | Proves | Cannot prove |
| --- | --- | --- |
| **Deadlock drill** — attest → drift → try all 4 recovery forms | check (4a) refuses **100%** of forward-history recoveries (F1) | that no *out-of-band* recovery exists (a history rewrite works — that is the point) |
| **Reset-laundering** — edit → `git reset` attestation away → re-attest | check (4a) buys **nothing** against a rewriting adversary (F2) | anything about a *forward-only* adversary — see next row |
| **Split-commit forward forge** — edit in commit A, attest in commit B | check (4a) is null **without any history rewrite** — the decisive arm (F2) | that the *human* could not have caught it by reading the ledger (they could — that is the real defense) |
| **Amend-bundle** — commit task text → digest → `--amend` the attestation in | **only** the confinement clause (4b) catches it ⇒ 4b is load-bearing and separable (F3) | ⚠️ **nothing, if you diff raw hunks** — you MUST normalize checkbox state first, or a *tick* is indistinguishable from a *new task line*. **My first probe was broken exactly this way and returned a false negative.** |
| **Uncommitted-implementation bypass** — real code present, uncommitted → run the classifier | `exit 0` ⇒ the whole precondition is skipped (F5) | that the digest's dirty-tree refusal helps — **it cannot**: it *is* check (3), inside the skipped precondition |
| **Lifecycle sweep** — run the classifier at propose-commit, then after implementation lands | the verdict moves `exit 0 → exit 10`; `exit 0` is a **false negative** (F4) | scope for *uncommitted* work — that is F5 |

**Dead instrument (record it so it is not retried).** `gpt-5.6-sol`'s sandbox **blocked `mktemp`** (`Operation not permitted`), so it **never ran a drill** in the co-research. It corroborated by **reading primary source** — and was repeatedly the *more careful reader* (it caught the metadata-corruption tripwire against Fable-5's "zero accidents" overclaim, and caught Fable grepping for an implementation string instead of reading normative prose). **So the empirical leg is single-runner (Fable-5 + Opus).** ❗ **Do not oversell "cross-model empirical consensus"** — the *analytic* consensus is genuine; the *empirical* one is not.

**Harness gap that let this ship.** `scripts/test-cross-review-scripts.sh` **Scenario H** drills only the **malicious** arm (rewrite/delete are detected). It has **no honest-recovery arm** — which is precisely why F1 shipped unnoticed. The fix must add it.

---

## 5. Re-verify by effect

Never re-read the spec to "confirm" any of this. Re-run:

1. **F1/F2/F3** — build a throwaway repo, attest, then run the four probes above. Expect: every forward recovery **red**; the split-commit forge **green on all four checks**; the amend-bundle **green except confinement**.
2. **F4** — `scripts/cross-review-scope.sh <a change whose implementation has not landed>` ⇒ **exit 0**. Then land its implementation and re-run ⇒ **exit 10**. The verdict *moved*; the change did not.
3. **F5** — leave real product code **uncommitted**, run the classifier ⇒ **exit 0**. That is the bypass.
4. **F6** — `git diff --name-only "$B"..HEAD | wc -l` for any parked change, then make **one unrelated commit** and re-run. The number **moves**. That is the HEAD-dependence.

**Fix verification (when the fixes land):** the counter's deletion is verified by the honest-recovery arm going **green** in `test-cross-review-scripts.sh`; confinement's survival by the amend-bundle arm staying **red**. Both arms must exist — one without the other proves nothing.

---

## 6. Reusable guidelines

- **G-GATE-1 — A mechanical check the recovering party can launder by `git reset` guarantees nothing; if it *also* forbids the recovery, it is pure liveness cost.** Check (4a) refuses 100% of honest forward recoveries while three separate attacks walk past it. Delete such a check; do not "relax" it (a relaxation that admits the honest path admits the attack **by construction** — they are indistinguishable to the mechanism).
- **G-GATE-2 — Don't judge a check by a standard it never claimed.** D10 already scopes all four checks to **accident tripwires**, not adversarial guarantees. The honest question is never *"can it be forged?"* (yes — that is R3, accepted) but *"does it catch the **ordinary, non-adversarial** failure it is aimed at, without false-positiving the honest path?"* **My own error, recorded:** I judged check (4) adversarially, found it wanting, and proposed removal — then had to be corrected twice (once by the review, once by my own probe) before landing on the right question.
- **G-GATE-3 — A retrospective classifier cannot be asked a prospective question.** One that scopes from *committed* paths returns, before implementation lands, a **confident false negative** — not an abstention. **Only its positive verdict is informative**; treat every other outcome as *"not yet knowable"*, never as *"no"*. Corollary: a check whose severity derives from such a classifier may take **blocker force only from the positive verdict**.
- **G-GATE-4 — A precondition gated on a classifier blind to uncommitted work is bypassable by simply not committing — and an *inner* dirty-tree check cannot backstop an *outer* scope skip.** Put the cleanliness refusal in the **classifier**, at the outermost gate, not only in the tool that runs after the gate has already decided to apply.
- **G-GATE-5 — Test every clause of a check against the *same* adversary/accident model. An asymmetric standard makes a null clause look load-bearing.** This doc's own error: it judged the counter by an **adversarial** standard (null ⇒ delete) and the confinement clause by a **bundle-only** standard (catches the one attack I constructed ⇒ *"load-bearing"*) — then a one-step generalization of its *own* F2 attack defeated confinement too. Corollaries, each paid for: **(a)** enumerate *all* clauses first (check (4) had **three**; I found two). **(b)** Check whether a clause's *subject* depends on another clause (4b's *"introducing commit"* is well-defined **only** while 4a holds — they are **not** separable). **(c)** Ask what each clause catches **non-adversarially** *before* deleting it (the counter turned out to be the gate's **principal accident tripwire**). **(d)** When your prescription flips on each round, **stop prescribing** — that is the tar pit (**G-TARPIT-3**), and a forensics doc's job is to record what *is*, not to pre-decide a contested fix.

---

## 7. Evidence artifacts

- The committed ledger (findings **F1–F12, G1–G11**, every dismissal with its rationale): `openspec/changes/fix-cross-review-gate-task-emission/cross-review-ledger.md`.
- Workflows: **`wf_9af3679c-537`** (co-research: `converged:true`, 3 rounds) · **`wf_cfbf0992-20b`** (adversarial verification, 9 agents).
- Commits: `3815113` (propose) → `eadd8d0` (round 1: the fail-open exit-arm fix) → `f1f9edc` (round 2: bound closed, sequencing escalated).
- The gate itself: `scripts/cross-review-{scope,digest}.sh`, `scripts/test-cross-review-scripts.sh`, `openspec/specs/cross-model-review/spec.md`.

## 8. Open — **not** decided here

**Sequencing is escalated to the human and is NOT settled.** Both soundness passes, on **different model families** (Pass C round 1; `gpt-5.6-sol` round 2, an explicit *"no-ship"*), independently argue the **check-(4a) deletion** and the **range-pollution / dirty-tree** fixes should land **before** `fix-cross-review-gate-task-emission` — which makes gate-task enforcement *routine* while F5's bypass is open and F1's attestation model is unrecoverable. The counter-argument: the deadlock is only *reachable* once a change acquires an attestation, and today nothing prompts one. **Constraining fact:** the gate **already** applies to both open changes (`exit 10`) either way, so `fix-cross-review-gate-task-emission` does not *create* the exposure — it makes it *routine*.

❗ **Codex's proposed remedy for F1 — "append-only, explicitly superseding attestation generations" — is DISMISSED**: it is the **refuted "recoverable attestation epoch"** (G-TARPIT-1/2). Its **sequencing** argument stands; its **remedy** does not. Neither the check-(4a) change nor the range-pollution change has been proposed yet.
