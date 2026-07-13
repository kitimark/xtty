# The Cross-Review Archive Gate — Defects Found by *Using* It

**Provenance:** 2026-07-12, produced by **using** the archive gate shipped one day earlier (`add-cross-model-design-review`, archived 2026-07-12) on the next real change — not by reviewing its spec. Every claim below was **measured by effect** against the **real committed scripts** (`scripts/cross-review-scope.sh`, `scripts/cross-review-digest.sh`) in **throwaway `mktemp -d` repos**; the live repository was never mutated. Time-sensitive: file counts are **HEAD-dependent by construction** (that is finding **F6**) and are stamped at `HEAD = f1f9edc`.

**Headline:** *Four measured defects in the shipped gate — a **re-attestation deadlock**, a scope classifier that **answers a prospective question with a confident false negative**, a **verified bypass** (uncommitted implementation ⇒ the entire precondition is **skipped**), and **HEAD-dependent range pollution**. ⚠️ **This doc deliberately prescribes NO fix for check (4).** Its prescription flipped **three times** under review — the last flip proving that deleting the counter also deletes the gate's **principal accident tripwire** (silent re-attestation), and that the counter's value and its liveness cost are **the same property**. That oscillation is itself the finding (**G-TARPIT-1/3**). Take the measurements into an explore; do not propose a check-(4) change from this document. This is **G-TARPIT-4 in action** — none of it was visible from the spec; all of it appeared on first use.*

**Companion docs.** [`cross-model-review-tar-pit-forensics.md`](cross-model-review-tar-pit-forensics.md) (why *hardening* this gate does not terminate — **G-TARPIT-1..5**) and [`cross-model-design-review-axes.md`](cross-model-design-review-axes.md) (why two model families are complementary). **This doc is the third:** what the shipped gate actually does when you run it. Note the direct line: **§11 of the tar-pit doc *added* check (4)'s strong form** (commit `3319785`, a two-model co-draft, net-neutral) to close the post-attestation-rewrite gap. **F2 below shows that hardening did not close it** — and it bricked the honest path. **§11's hardening was itself a tar-pit relapse.**

## Sources

- Co-research Workflow **`wf_9af3679c-537`** — Fable-5 ‖ `gpt-5.6-sol` ‖ Opus adjudicator, 3 bounded rounds, **converged**, ~886k tokens.
- Adversarial verification Workflow **`wf_cfbf0992-20b`** — 9 agents, ~676k tokens.
- The tri-pass cross-review of `fix-cross-review-gate-task-emission` (**4 bounded rounds**): committed ledger at `openspec/changes/archive/2026-07-13-fix-cross-review-gate-task-emission/cross-review-ledger.md` (findings **F1–F12, G1–G11, H1–H8, R4-1…R4-13**). ⚠️ **That change was ABANDONED** (2026-07-13, archived `--skip-specs`, 1/20 tasks) — see **§9**; its round-4 findings are the source of **F4 (revised)**, **F8**, and **G-GATE-3 (revised) / 6 / 7**.
- Abandonment audit Workflow **`wf_d714bb3c-772`** — 32 agents, every stranded finding adversarially verified before capture.
- Commits `3815113` → `eadd8d0` → `f1f9edc` → `dca6b11` → `ad91b12` / `69efa68` (round 4).
- The shipped gate: `openspec/specs/cross-model-review/spec.md`; AGENTS.md → *Cross-model design review + the human-attestation archive gate*; `scripts/cross-review-{scope,digest}.sh`; `scripts/test-cross-review-scripts.sh`.

---

## 1. The gate, as shipped (mechanism)

Archiving an **in-scope** change is refused unless four checks hold — **as prose.**

> ### ⚠️⚠️ **THERE IS NO EXECUTABLE ARCHIVE GATE.** (F7 — verified)
> **Not one** of the four checks has a committed **archive-time** implementation. `exempt_by_act()` exists **only inside a test harness**; the digest tool *prints* a digest but nothing committed **extracts the attested value, compares them, or refuses archive**; and the archive skill (`.claude/skills/openspec-archive-change/SKILL.md`, `/opsx:archive`) contains **zero** references to cross-review, attestation, step-0, the classifier, or the digest — it gates only on *incomplete tasks*, then asks the user to confirm and proceeds.
> **"Fail-closed" describes an instruction-following convention, not an enforced property.** The whole gate is AGENTS.md prose a model is trusted to re-type. **Read every drill below with that in mind:** they measure the *scripts*, not a gate.

| # | Check | Encoding |
| --- | --- | --- |
| 1 | attestation line exists, exactly once, well-formed | `grep -c '<!-- cross-review-attestation:' = 1` (**shape is not validated** — `<!-- cross-review-attestation: LOL -->` passes) |
| 2 | reviewed-state digest **recomputes** and string-equals the attested value | `scripts/cross-review-digest.sh <change>` |
| 3 | tree/index clean | the digest tool's own refusal |
| 4a | **counter:** line added exactly once, never deleted/modified | `now==1 && adds==1 && dels==0` over `git log -p -- tasks.md` |
| 4b | **confinement:** the attestation-**introducing** commit's `tasks.md` hunk is confined to the attestation line + checkbox **ticks** | **prose only — no executable** |
| 4c | **later-commits:** every commit *after* the attestation touches only bookkeeping surfaces — **no reviewed artifact, no gate implementation** | **prose only — no executable.** ⚠️ **NOT "redundant with check (2)"** — an earlier draft said so and it is **refuted** (F3): after a re-attestation refreshes the digest, check (2) is **green** while 4c is **red**. 4c is the *only* remaining prohibition on post-attestation drift, and **it independently blocks the honest recovery.** |

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

**❗❗ AND THE HORNS ARE WORSE THAN THAT — deleting 4a does NOT restore liveness.** An external review (Codex, which *cannot run a drill* and found this **by reading the spec**) caught that **every drill in this doc measured only the *executable* subset** — checks (1)(2)(3)(4a). **The specified gate's clause 4c also blocks the honest recovery, independently.** Verified:

```
D4 (the honest recovery the spec MANDATES: drift → human re-reviews → re-attests)
   check(2)  PASS        ← the digest was refreshed
   check(4a) adds=2 dels=1  FAIL
   check(4c) VIOLATED   ← a later commit touched a reviewed artifact — INDEPENDENT of 4a
```

So *"delete 4a ⇒ liveness restored"* — the premise under every prescription this doc ever carried — **is false.** Any liveness fix must address **4a and 4c together**. And it refutes this doc's own earlier claim that 4c is *"largely redundant with check (2)"*: here check (2) is **green** and 4c is **red**.

**❗ The horns are the SAME PROPERTY.** A model silently re-attesting and a human deliberately re-attesting after a genuine re-review are **mechanically identical acts**. 4a's value *is* its cost: it forces every re-attestation to be a deliberate, effortful, history-rewriting act that a careless model will not casually perform. **You cannot delete the cost without deleting the value.** Any "fix" that admits the honest recovery admits the silent one **by construction** — the same unsolvable distinction as F2.

#### What the review established (facts, not prescriptions)

- **Check (4) has THREE clauses** (§1) — the two-clause decomposition was wrong.
- **All three are adversarially null.** 4b is defeated by two plain forward commits exactly as 4a is (Passes A + C, independently — a two-pass consensus). *"Sole adversarial guard"* was **false**.
- **4b is NOT separable from 4a as written.** Its subject is *"the attestation-**introducing** commit"* — uniquely defined **only because 4a guarantees `adds==1`**. Delete 4a (which legalises a second add — the whole point) and the anchor becomes ambiguous: anchored to the **first** add, an actor re-attests in a later commit and 4b passes against the *original* clean commit. **Any 4a-deletion MUST re-anchor 4b.** The instruction an earlier draft carried — *"targets 4a and MUST NOT touch 4b"* — was **actively harmful**; it is retracted.
- **`base=` and `head=` are decorative.** `cross-review-digest.sh` reads **neither** (0 references) — it re-derives `B` positionally and hashes at **live HEAD**.

#### An unevaluated candidate worth exploring (Pass C's — NOT endorsed here)

**Head-pinning.** Make the already-recorded `head=` field **load-bearing**: compute the digest **at the attested head**, and require that sha to be the parent of the attestation commit and an ancestor of HEAD with bookkeeping-only deltas. It is metadata-free (git ground truth + a *human-authored* field — no ownership trailer). It would **subsume 4b's catch** (smuggled content is not in `head=`'s tree, so check (2) fails without any confinement clause) and **kill F6's HEAD-dependence**.

⚠️ **But it does not resolve the tension above** — a re-attestation still rewrites the line, so the silent-re-attestation horn survives. It is a **promising partial**, unrun, and it belongs in an **explore**, not in this doc.

#### Two results from the fully-informed external review (Codex, read-only — it could not drill)

**(a) The tension is FORMALLY irreducible for a git-only gate — and the only exit is an external authority.**
*"Let the gate observe repository history, trees, metadata, and deterministic script output. D3 and D4 can produce the same observation: identical content commit, attestation commit, parent relationship, digest, author fields, timestamps, reachable history. **Human review is an event in the world, not a property encoded by Git.** Any predicate over that observation must return the same answer for both."*

The **only** distinguishing fact would be an **externally authenticated human act** — a signature over `(change, base, reviewed-head, digest)` from a key **the model cannot use**, verified at a boundary **the model cannot modify**. But: a plain `git commit -S` is insufficient (an unlocked key or an unattended agent defeats it); a signature proves *key use*, not *reading*; and verification **inside** the model-controlled loop is not an independent boundary. The repo's own **optional-not-default signing form** is precisely this idea, already documented **and declined**.

> ❗ **The current design tries to retain BOTH liveness AND silent-re-attestation prevention WITHOUT an external authority. That combination is impossible.** Whatever the explore decides, it must *pick*: accept the deadlock, accept silent re-attestation as R3, or move attestation authority outside the model-controlled repo.

**(b) A taxonomy contradiction this doc must not paper over.** D3 — a model computing and filling the attested value — is **expressly forbidden** by the spec (the human-only clause), and **D10 already accepts a repo-controlling model performing a forbidden act as the R3 residual**. Yet this doc reclassified the *same act* as *"the principal ordinary **accident**."* **Intent — malicious vs. well-meaning — is no more git-observable than review is.** The two taxonomies cannot both govern. **The explore must decide which one does**; the answer changes whether the counter is protecting anything the design has not already conceded.

#### Head-pinning — evaluated and substantially KILLED

The candidate's central mechanism claim was **backwards**. It was said that smuggled content *"is not in `head=`'s tree, so check (2) fails"*. **Its absence from `head=`'s tree is exactly why check (2) PASSES.** Head-pinning therefore does **not** subsume 4b on its own — it needs an *additional*, executable, **per-commit** `head..HEAD` bookkeeping-only check (and per-commit, not a net `git diff`: an edit followed by a revert has an empty net diff but violates the clause). It does **not** stop the split-commit forge (the forge simply names the malicious commit as `head=`). It does **not** resolve D3/D4, fix scope pollution, or fix D5. It **does** stabilise the digest against unrelated later commits — a real but **narrow, orthogonal** benefit. *Recorded as a partial; not a solution.*

#### The instruction this doc actually gives

**Do not propose a check-(4) change from this document.** Take the *measurements* (F1, F2, F4, F5, F6 — all solid) into an `/opsx:explore`, and design the fix there against **both horns**, with the three-clause decomposition and the re-anchoring requirement in hand. **A research capture records what is; it must not pre-decide a fix that three review rounds could not settle.**

**Probe subtlety — this is why the 4b error was easy to make** ❗ Testing confinement requires **normalizing checkbox state before diffing**. A *tick* (`[ ]`→`[x]`) and a *new task line* are both `+`/`-` checkbox lines in a raw hunk. My first probe filtered *all* checkbox lines and reported a **false negative**. The correct probe compares the **set of task texts** with the box normalized:

```bash
tasktexts(){ git show "$1:.../tasks.md" | sed -e "/$SENTINEL/d" -e 's/^\(- \)\[[ xX]\]/\1[ ]/'; }
diff <(tasktexts "$IC^") <(tasktexts "$IC")   # empty ⇒ confined
```

### F7 — ⚠️ **There is no executable archive gate at all** ✅ *(found by the read-only reviewer; the biggest finding here)*

Verified:

| claim | evidence |
| --- | --- |
| The archive skill never invokes the gate | `.claude/skills/openspec-archive-change/SKILL.md` and `/opsx:archive` → **0** hits for cross-review / attestation / step-0 / classifier / digest. They count **incomplete tasks**, ask the user to confirm, and proceed. |
| Check (4a) has no archive-time executable | `exempt_by_act()` exists **only** in `scripts/test-cross-review-scripts.sh` — a *test harness*. |
| Check (2) has no archive-time executable | `cross-review-digest.sh` **prints** a digest. **Nothing committed extracts the attested value, compares them, or refuses archive.** |
| Checks (1)/(4b)/(4c) | prose only. |

**So the four-check precondition is AGENTS.md prose that a model is trusted to re-type at archive time.** *"Fail-closed"* is an **instruction-following convention, not an enforced property** — which means **D5's bypass is not the only way past the gate; simply not running step-0 is another**, and nothing detects it.

This is *partly* acknowledged by the design (R3: *"a session that ignores `⟶ archive-ritual` is already outside the workflow's contract"*). What was **not** acknowledged — and what this doc got wrong — is the **magnitude**: an earlier §1 table implied checks 1/2/3/4a *were* executable and only 4b/4c were prose. **None of them are.**

❗ **Read every drill in this document with that scoping.** They measure the **scripts** and a **hand-reconstructed** version of the prose clauses. They do **not** measure a committed gate, because there isn't one.

### F4 — The scope classifier scopes the **RANGE**, not the change: its verdict is **non-attributive** and it **LATCHES** ✅

> ⚠️ **REVISED 2026-07-13 — an earlier version of this section was REFUTED by measurement.** It framed the
> classifier as merely **retrospective** and asserted *"the normal post-propose state **is** `exit 0`"*, with a
> lifecycle table showing `propose committed → exit 0`. **Both are false.** The refutation came from the
> `fix-cross-review-gate-task-emission` round-4 cross-review — the very change whose measurement the old text
> cited. That change was **abandoned**; its findings are preserved here. The retired claim is kept below as a
> ❌ so it cannot be re-cited.

`scripts/cross-review-scope.sh:54` is `paths="$(git diff --name-only "$B"..HEAD)"` where `B = parent(<proposal.md commit>)`. **That range is repo-wide** — it holds *every* commit that landed after the change was proposed, by anyone, for any reason. So the classifier answers *"is **some** path in this range out-of-allowlist?"* — **not** *"is **this change** in scope?"*

**Three properties, all measured:**

- **Non-attributive.** An `exit 10` verdict says only that *some* path in the range is out-of-allowlist. It **cannot say whose**. It is therefore **never** evidence that *this change's* implementation landed.
- **Retrospective.** It reads **committed** paths only, so it can never answer a *propose-time* question about paths that do not yet exist. `exit 0` / `exit 2` mean *"not yet knowable to be in scope"* — **never** *"out of scope"*; treating `exit 0` as "out of scope" is **fail-open**.
- **⚠️ Monotone under intervening archives — the one that bites.** `openspec archive` **always** writes `openspec/specs/**`, which is **NOT** in the allowlist (`cross-review-scope.sh:44-51` allows only `openspec/changes/*`, `research/*`, the four root docs, `packer/README.md`). So **any change left open across any other change's archive latches to `exit 10` permanently and can never return.** With concurrent changes — this repo's normal state — that is the **common case, not the exception.**

**Measured 2026-07-13, all three then-open changes:**

| change | reviewed range | own paths | foreign | own paths out-of-allowlist? | verdict |
| --- | --- | --- | --- | --- | --- |
| `fix-cross-review-gate-task-emission` | 21 | 7 | 14 (67%) | **none** | `exit 10` — **100% foreign-driven**, at **1/20 tasks, zero implementation landed** |
| `add-git-diff-wrap-toggle` | 42 | 7 | 35 (83%) | **none** | `exit 10` — **100% foreign-driven**, at **0/20 tasks** |
| `add-ci-pipeline` | 324 | 5 | 319 (98.5%) | yes (`.github/workflows/**`) | `exit 10` |

**Fates table — what this kills:**

| Retired claim | ❌ Killed by |
| --- | --- |
| *"the normal post-propose state **is** `exit 0`"* | Measured: **all three** open changes read `exit 10`; two with **zero** own out-of-allowlist paths. After any intervening archive the steady state is `exit 10`. |
| *"`propose committed → exit 0`"* (the lifecycle table) | `fix-cross-review-gate-task-emission` read `exit 10` at **1/20 tasks** — the flip came from **unrelated work**, not from the change. |
| *"`exit 10` ⇒ the change's implementation landed"* (the proxy) | Non-attributivity: `exit 10` cannot say *whose* path triggered it. Any check using it as a "did implementation land?" proxy is a **false-positive test**. |

**Consequence for any future gate design:** the direction is still safe (**over**-inclusion never opens a bypass), but the **precision is a function of repo activity, not of the change**. Do **not** hang a BLOCKER, an eligibility test, or a lifecycle assertion on this verdict without first **narrowing the range to the change's own paths** — that narrowing is the prerequisite fix, not an optimization.

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

**Severity:** pollution is **fail-closed** — over-inclusion costs one unnecessary review, it can **never** produce a bypass. So it is **noise, not a hole** — but it is the mechanism that makes F1 *terminal* rather than merely annoying. ❗ **F4 (revised) upgrades this:** pollution is not merely *possible*, it is **structural and monotone** — `openspec archive` writes the non-allowlisted `openspec/specs/**`, so **every** long-lived change latches to `exit 10`. The numbers in the table above are already stale by design; the *mechanism* is the durable finding.

### F8 — The gate task reaches no author, and its "escape hatch" does not exist ✅

*(Findings preserved from the **abandoned** `fix-cross-review-gate-task-emission` — see §9. All re-measured 2026-07-13.)*

**(a) The emission + enforcement defects — the gate is not wired to the propose loop.**

| Defect | Evidence |
| --- | --- |
| **Nothing emits the gate task.** `/opsx:propose` reads `openspec/config.yaml`, **not** `AGENTS.md`. That file carries a `rules.tasks` entry for all **four** existing point-of-tick markers and **zero** for the human-attestation cross-review task. | `grep -ci 'cross-review\|attestation' openspec/config.yaml` ⇒ **0** |
| **Nothing blocks on its absence.** The critic's gate-task check is `heuristic → REVIEW`, explicitly *"never a BLOCKER"*, and REVIEW findings never block a coherent verdict. | `.claude/agents/xtty-openspec-critic.md:42`, `:80` |

This is the repo's own **G13** reproduced exactly: *a rule that lives only in AGENTS.md does not reach the loop.* **Both defects remain UNFIXED** — the change that would have fixed them was abandoned (§9).

**⚠️ But the *severity* framing must stay honest — an earlier draft's evidence was ANACHRONISTIC.** The claim *"the gate is inert; both open changes violate the spec"* does **not** show the propose loop failing, because **both changes predate the obligation**:

```
add-cross-model-design-review  ARCHIVED 2026-07-12   ← the obligation ships here
add-ci-pipeline               proposed 2026-06-30    ← 12 days BEFORE
add-git-diff-wrap-toggle      proposed 2026-07-11    ←  1 day BEFORE
brief-cross-review-pass-b     proposed 2026-07-12    ← the ONLY post-gate change — and it DID carry the task
```

And the one post-gate data point is **also** confounded (a gate-saturated authoring session; git cannot distinguish *loop-emitted* from *hand-added in the same commit*). **Net: n=1 either way, no clean evidence in either direction.** The case for moving the obligation onto `config.yaml` is **structural (G13)**, not empirical — state it that way.

**(b) ❗ There is NO procedure for removing an over-emitted human-only task.** A fail-closed emission rule ("when in doubt, emit") is normally justified as cheap *because reversible* — *"over-emission costs one strikeable task."* **That justification is false here.** Grepping AGENTS.md, both established specs, and the scripts, **every** hit for *strike / remove the task / delete the task* is **the assertion itself**: no actor, no authority, no recorded form. The model may not **tick** the task; nothing sanctions it **deleting** the task either — and **no rule distinguishes *"strike an over-emitted task"* from *"delete an inconvenient gate task"***, which is the precise act the gate exists to prevent. Worse, under F4's latch a long-lived change reads `exit 10`, so any BLOCKER-grade enforcement would **re-raise the task the moment it is removed**. **Any future design that emits fail-closed MUST define the strike as a first-class human-only act, or drop the cheapness claim.**

**(c) `add-ci-pipeline`'s obligation is *expensive*, not *impossible* — a refuted premise worth recording.** The abandoned change excluded it on the grounds that its attestation would be **unsatisfiable** (its remaining commits would restage the HEAD-dependent digest, and F1 forbids re-recording). **Refuted by the external reviewer, confirmed on disk:** its remaining work is **5.4** (a test PR) and **5.5** (*a GitHub repo **setting** — not even a commit*), and both sit **before** its tail. So *owner-steps → commit → **then** attest → **then** archive* is an ordinary available ordering with **zero** intervening commits. The 324-path / 98.5%-foreign range is a **cost**, not an impossibility. ❗ It **does** genuinely lack a `⟶ xtty-openspec-critic` task (confirmed — its tail has only `⟶ archive-ritual`), so *"place the attestation task after the critic task"* has **no anchor** until one is added.

---

## 3. Retired theories (fates table — each ❌ next to the experiment that killed it)

| Theory | Refuted by | Fate |
| --- | --- | --- |
| "check (4) is **sound** — the adversarial defense against re-forge" | reset-laundering, amend-forge, **and** the split-commit forward forge — all pass four-of-four | ❌ |
| "first-forge only defeats a *negligent* human; re-forge defeats a *diligent* one — the asymmetry justifies check (4)" | **both** forges are the model performing the human-only act = **R3**, one already-accepted residual. (**R5** is the *human* rubber-stamping — a **different actor**.) No trust-class asymmetry exists | ❌ |
| "**RELAX** check (4)" (keep `now==1` + operative-line confinement + re-anchored later-commit classification) | **Fable-5's own drill**, which it built and then used to **withdraw its own proposal**: `{3-check ALLOW}` ⊇ `{relaxed PASS}` ⇒ **zero verdict change**, while *adding* `git log -S` operative-line discovery, diff normalization, and commit classification. A **strictly dominated no-op** that had self-labelled `fix_is_subtractive: true` — falsely | ❌ |
| "**DELETE check (4) entirely**" (the co-research's *converged* conclusion) | **first** narrowed by the amend-bundle experiment (*"only confinement catches it"*) — **but that narrowing was itself REFUTED** (F3): confinement is null too. What actually stands against a bare deletion is **H4**: deleting the counter deletes the gate's **principal accident tripwire** (silent re-attestation) | ⚠️ **UNSETTLED — not refuted, not adopted.** The doc **prescribes nothing**; the fix goes to an explore |
| "delete 4a, **preserve 4b** — the sole adversarial guard" (**this doc's own round-1 correction**) | two plain forward commits defeat confinement exactly as they defeat the counter — reached **independently by two passes**. An asymmetric standard (adversarial for one clause, bundle-only for the other) manufactured a guard that does not exist | ❌ **retracted** |
| "a model *agreeing* with a claim is evidence for it" | **Codex endorsed** the *"preserve the confinement clause"* claim in the same round two other passes **refuted** it | ❌ (a near-miss the tri-pass almost ratified) |
| "branch protection makes the deadlock **terminal**" | live: `gh api .../branches/main/protection` → **404 "Branch not protected"**; `rulesets` → `[]`; `add-ci-pipeline` task 5.5 is `(Optional)` and **unticked**; solo owner holds `admin:true` | ❌ |
| "check (4) catches **zero** accidents" (Fable-5, round 1 — **retracted by Fable-5 itself**) | `gpt-5.6-sol` was **right** to insist otherwise: a metadata-only edit to `base=`/`head=`/`reviewed=` is invisible to check (2) (the digest excludes the **whole** attestation line) and refused **only** by check (4). Low value — but not zero. *(gpt's proposed check-(1) template regex does **not** recover it — measured.)* | ❌ |
| "the honest recovery and the attack produce the **same git state**" (my own phrasing) | they differ: `adds=2/dels=1` vs `adds=1/dels=0` | ❌ → **"mechanically indistinguishable *to the gate*"** |
| **"the normal post-propose state *is* `exit 0`"** *(this doc's own F4, before the 2026-07-13 revision)* | Measured: **all three** then-open changes read **`exit 10`**, two of them with **zero** own out-of-allowlist paths. `openspec archive` always writes the **non-allowlisted** `openspec/specs/**`, so any change open across any archive **latches to `exit 10` permanently** | ❌ **refuted** → F4 rewritten: the classifier is **non-attributive** and **monotone**, not merely retrospective |
| **"`propose committed → exit 0`"** *(the F4 lifecycle table)* | `fix-cross-review-gate-task-emission` read **`exit 10` at 1/20 tasks, zero implementation landed** — flipped by **unrelated** work landing in its range | ❌ **refuted** |
| **"`exit 10` ⇒ this change's implementation landed"** *(used as a validity proxy in the abandoned change's task 6.1)* | Non-attributivity: `exit 10` cannot say **whose** path triggered it. Any check using it as a "did implementation land?" test is a **false-positive test** | ❌ **refuted** — use an **attributive** test (assert the change's own implementation paths are in the range) |
| **"over-emission costs one *strikeable* task"** *(the standard justification for a fail-closed emission rule)* | **No striking procedure exists anywhere** — every grep hit is the assertion itself. And under F4's latch, BLOCKER-grade enforcement **re-raises the task the moment it is removed** | ❌ **refuted** — fail-closed emission is **not** cheaply reversible (F8b) |
| **"`add-ci-pipeline`'s attestation is *unsatisfiable*"** *(the abandoned change's D7)* | Its remaining work is a test PR + a GitHub **repo setting** (not a commit), both **before** its tail ⇒ *owner-steps → attest → archive* is an ordinary ordering with zero intervening commits | ❌ **refuted** — **expensive** (324 paths, 98.5% foreign), not impossible (F8c) |
| **"both open changes violate the gate ⇒ the propose loop is broken"** | **Anachronistic**: both **predate** the obligation (by 12 and 1 days); the **only** post-gate change **did** carry the task — and *that* data point is confounded too | ❌ **refuted** → the case for `config.yaml` is **structural (G13)**, not empirical (F8a) |

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
| **Lifecycle sweep** — run the classifier at propose-commit, then after implementation lands | that `exit 0` is a **false negative**, never an abstention (F4) | ⚠️ **that `exit 0` is the propose-time state at all.** In a repo with *concurrent* changes it is **not** — an intervening archive flips the verdict to `exit 10` **with no implementation landed**. This probe is only clean on an otherwise-idle repo; **run the attribution probe instead** |
| **Attribution probe** — `scripts/cross-review-scope.sh <change>`, then `git log B..HEAD -- <each out-of-allowlist path>` | **who actually drove the `exit 10`** — the change under review, or foreign work (F4). This is the probe that exposes the latch | that the verdict is *wrong* — it is fail-closed and correct **as a range statement**; what it cannot do is attribute |

**Dead instrument (record it so it is not retried).** `gpt-5.6-sol`'s sandbox **blocked `mktemp`** (`Operation not permitted`), so it **never ran a drill** in the co-research. It corroborated by **reading primary source** — and was repeatedly the *more careful reader* (it caught the metadata-corruption tripwire against Fable-5's "zero accidents" overclaim, and caught Fable grepping for an implementation string instead of reading normative prose). **So the empirical leg is single-runner (Fable-5 + Opus).** ❗ **Do not oversell "cross-model empirical consensus"** — the *analytic* consensus is genuine; the *empirical* one is not.

**Harness gap that let this ship.** `scripts/test-cross-review-scripts.sh` **Scenario H** drills only the **malicious** arm (rewrite/delete are detected). It has **no honest-recovery arm** — which is precisely why F1 shipped unnoticed. The fix must add it.

---

## 5. Re-verify by effect

Never re-read the spec to "confirm" any of this. Re-run:

1. **F1/F2/F3** — build a throwaway repo, attest, then run the four probes above. Expect: every forward recovery **red**; the split-commit forge **green on all four checks**; the amend-bundle **green except confinement**.
2. **F4 (rewritten — the old step here was itself refuted).** ❌ *Do **not** re-verify by "run it on an unimplemented change ⇒ expect `exit 0`" — that only holds on an otherwise-idle repo.* ✅ Instead run the **attribution probe**: `scripts/cross-review-scope.sh <any long-lived open change>` ⇒ almost certainly **exit 10**; then, for **each** out-of-allowlist path it names, `git log B..HEAD --oneline -- <path>` and check **whose** change introduced it. Expect: the drivers are **foreign**. Then confirm the mechanism directly — `openspec archive` writes `openspec/specs/**`, and `openspec/specs/*` is **absent** from `cross-review-scope.sh`'s `allowlisted()` case statement. That is the **latch**.
3. **F5** — leave real product code **uncommitted**, run the classifier ⇒ **exit 0**. That is the bypass.
4. **F6** — `git diff --name-only "$B"..HEAD | wc -l` for any parked change, then make **one unrelated commit** and re-run. The number **moves**. That is the HEAD-dependence.

**Fix verification — deliberately NOT specified here.** An earlier draft said the fix would be verified by *"the counter's deletion going green and confinement's survival staying red"* — **that presumed the very prescription this doc retracts** (F3), and it is wrong anyway (deleting the counter does not restore liveness — 4c blocks it too). **Whatever fix an explore lands must state its own by-effect verification**, and it must exercise the **specified** gate (all three clauses of check (4)), not merely the executable fragment these drills reached.

---

## 6. Reusable guidelines

- **G-GATE-1 — A mechanical check the recovering party can launder by `git reset` guarantees nothing against an adversary; and if it *also* forbids the honest recovery, it is a liveness cost you must price explicitly.** ⚠️ **But do not read this as "delete such a check"** — an earlier draft did, and that was wrong twice over: the counter turned out to be the gate's *principal accident tripwire* (a null-against-adversaries check can still be the only thing catching a *careless* actor), and deleting it would not even restore liveness (clause 4c blocks the honest recovery independently). **Price every clause against both an adversary AND an accident, and against liveness — then decide. This doc decides nothing** (F3).
- **G-GATE-2 — Don't judge a check by a standard it never claimed.** D10 already scopes all four checks to **accident tripwires**, not adversarial guarantees. The honest question is never *"can it be forged?"* (yes — that is R3, accepted) but *"does it catch the **ordinary, non-adversarial** failure it is aimed at, without false-positiving the honest path?"* **My own error, recorded:** I judged check (4) adversarially, found it wanting, and proposed removal — then had to be corrected twice (once by the review, once by my own probe) before landing on the right question.
- **G-GATE-3 — ⚠️ REVISED. A range-scoped classifier answers a question about the RANGE, not about the change — so it can be asked *neither* a prospective question *nor* an attributive one.** The original form of this guideline said only *"a retrospective classifier cannot be asked a prospective question"* — true, but it **understated the defect** and was refuted as a *sufficient* account (F4). Three properties, and the third is the one that bites:
  - **Retrospective** — scoping from *committed* paths, it returns a **confident false negative** before implementation lands, not an abstention. Treat a negative as *"not yet knowable"*, **never** *"no"*.
  - **Non-attributive** — a *positive* verdict says only that **some** path in the range is out-of-allowlist, **never whose**. So *"only the positive verdict is informative"* (the original corollary) is **too generous**: the positive verdict is informative **about the range**, and about the change **only** if the range happens to be clean.
  - **Monotone / latching** — if the range mechanically accretes an out-of-allowlist path over time (here: **every** `openspec archive` writes the non-allowlisted `openspec/specs/**`), then **every long-lived change eventually reads positive, permanently**, and the verdict decays to a constant that carries **no information about any change at all.**
  **Corollary (the load-bearing one):** *never* use such a verdict as a **proxy** for a property of the change — "did its implementation land?", "is it in scope?", "may this check fire?" — and **never hang BLOCKER force on it** until the range is **narrowed to the change's own paths**. Narrowing is a **prerequisite**, not an optimization. Test for the disease by **attribution**, not by the verdict: `git log B..HEAD -- <each out-of-allowlist path>` and ask *whose* it is.
- **G-GATE-6 — A fail-closed emission rule is only cheap if the *strike* is a first-class, defined act. Define it, or drop the cheapness claim.** *"When in doubt, emit; over-emission costs one strikeable task"* is the standard justification — and it is **false unless someone specified striking**. Here nothing did: no actor, no authority, no recorded form, and **no rule distinguishing *"strike an over-emitted task"* from *"delete an inconvenient gate task"*** — the precise act the gate exists to prevent. Worse, pairing fail-closed emission with BLOCKER-grade enforcement makes the over-emission **irreversible** (the BLOCKER re-raises the task the moment it is removed), so the two halves **contradict each other**: emission is justified as cheap *because reversible*; enforcement makes it *un*-reversible (F8b).
- **G-GATE-7 — Don't infer "the tool is broken" from artifacts that predate the tool.** An obligation shipped on date *D* cannot be evidenced-as-failing by changes proposed **before** *D* — they are a **retroactively-applied rule**, not a broken loop. Check the dates **before** claiming severity: here the two "violating" changes predated the gate by 12 days and 1 day, and the **only** post-gate change **did** carry the task (though *that* is confounded too — git cannot distinguish loop-emitted from hand-added in one commit). **n=1 either way ⇒ argue structurally, not empirically** (F8a). Corollary for **migrations**: a retroactive obligation on pre-existing work needs an explicit **grandfathering** decision — *"compare the change's proposal commit against the rule's ship commit"* is mechanical and dateable — or you hand someone an obligation they had no chance to meet.
- **G-GATE-4 — A precondition gated on a classifier blind to uncommitted work is bypassable by simply not committing — and an *inner* dirty-tree check cannot backstop an *outer* scope skip.** Put the cleanliness refusal in the **classifier**, at the outermost gate, not only in the tool that runs after the gate has already decided to apply.
- **G-GATE-5 — Test every clause of a check against the *same* adversary/accident model. An asymmetric standard makes a null clause look load-bearing.** This doc's own error: it judged the counter by an **adversarial** standard (null ⇒ delete) and the confinement clause by a **bundle-only** standard (catches the one attack I constructed ⇒ *"load-bearing"*) — then a one-step generalization of its *own* F2 attack defeated confinement too. Corollaries, each paid for: **(a)** enumerate *all* clauses first (check (4) had **three**; I found two). **(b)** Check whether a clause's *subject* depends on another clause (4b's *"introducing commit"* is well-defined **only** while 4a holds — they are **not** separable). **(c)** Ask what each clause catches **non-adversarially** *before* deleting it (the counter turned out to be the gate's **principal accident tripwire**). **(d)** When your prescription flips on each round, **stop prescribing** — that is the tar pit (**G-TARPIT-3**), and a forensics doc's job is to record what *is*, not to pre-decide a contested fix.

---

## 7. Evidence artifacts

- The committed ledger — **4 rounds**, findings **F1–F12, G1–G11, H1–H8, R4-1…R4-13**, every dismissal with its rationale: `openspec/changes/archive/2026-07-13-fix-cross-review-gate-task-emission/cross-review-ledger.md` *(the change was **abandoned** — §9 — so the ledger now lives in the archive; it is the fullest record of how these defects were found).*
- Workflows: **`wf_9af3679c-537`** (co-research: `converged:true`, 3 rounds) · **`wf_cfbf0992-20b`** (adversarial verification, 9 agents) · **`wf_d714bb3c-772`** (the abandonment audit: 32 agents, every stranded finding adversarially verified).
- Commits: `3815113` (propose) → `eadd8d0` (round 1) → `f1f9edc` (round 2) → `dca6b11` (round 3) → `ad91b12` / `69efa68` (round 4: the latch) → the abandonment.
- The gate itself: `scripts/cross-review-{scope,digest}.sh`, `scripts/test-cross-review-scripts.sh`, `openspec/specs/cross-model-review/spec.md`.

## 8. Open — **not** decided here

**Sequencing is escalated to the human and is NOT settled.** Both soundness passes, on **different model families**, argued across four rounds (`gpt-5.6-sol` returned **four consecutive no-ships**) that the **check-(4a) deletion** and the **range-pollution / dirty-tree** fixes should land **before** any change that makes gate-task enforcement *routine* — while F5's bypass is open and F1's attestation model is unrecoverable. ❗ **Round 4 settled the empirical half of that argument** (F4): range pollution is **not hypothetical and not an edge case** — it is **structural**, and it had already **latched** the very change under review. **That is now a reason to fix the range FIRST**, and it is the strongest single input to whatever replaces the abandoned change.

❗ **Codex's proposed remedy for F1 — "append-only, explicitly superseding attestation generations" — is DISMISSED**: it is the **refuted "recoverable attestation epoch"** (G-TARPIT-1/2). Its **sequencing** argument stands; its **remedy** does not. Neither the check-(4a) change nor the range-pollution change has been proposed yet.

---

## 9. ⚠️ The emission fix was ABANDONED (2026-07-13) — what that leaves, and why it is recorded here

`fix-cross-review-gate-task-emission` — the change that would have wired the gate task into `openspec/config.yaml` and given the critic a blocking check — was **abandoned as won't-do at 1/20 tasks** and archived **without merging its spec deltas** (`openspec archive --skip-specs`). Its four rounds of cross-model review are the source of **F4 (revised)**, **F8**, **G-GATE-3 (revised)**, **G-GATE-6**, and **G-GATE-7** above.

**Why it was abandoned** — three design-shape questions its own review could not settle, on top of a standing four-no-ship sequencing escalation:

| | The question it could not answer |
| --- | --- |
| **Q1** | **Sequencing** — should it land *after* the range-pollution fix? Round 4 turned this from an argument into a **measurement**: the pollution had already latched the change itself (F4). |
| **Q2** | **Should the `exit 10` arm carry BLOCKER force at all?** Under the latch, the verdict is a near-constant carrying no information about any change — so a BLOCKER hung on it would be **red by default on nearly every change**, and since nothing executable consumes a critic BLOCKER (**F7**), its only force is the reader's attention. |
| **Q3** | **Migrate, grandfather, or exclude** the two pre-gate changes? Its exclusion premise was **refuted** (F8c) and both changes **predate the obligation** (F8a/G-GATE-7). |

**The honest read: Q2 dissolves if the range is narrowed first.** The change tried to build enforcement **on top of** a classifier whose verdict cannot attribute — and every one of its hardest problems traces back to that. **The prerequisite is F4's narrowing, not this change.**

**What remains BROKEN, and is now nobody's task:**

1. **Emission and enforcement are still unfixed** — `openspec/config.yaml` has **0** cross-review rules; the critic's gate-task check is still **REVIEW-only, never a BLOCKER** (F8a). Nothing prompts a human to run the review; they discover the requirement only when archive refuses.
2. **Neither open change carries the gate task the shipped spec requires** (`add-ci-pipeline`, `add-git-diff-wrap-toggle` — both `exit 10`, both **0** attestation tasks). Per **G-GATE-7** the right disposition is probably **grandfathering**, but **no decision has been made.**
3. **`add-ci-pipeline` has no `⟶ xtty-openspec-critic` task at all**, so the *"place the attestation task after the critic task"* rule has **no anchor** for it (F8c).

**What was FIXED while abandoning** (so the abandonment is not a pure loss): the **false mechanism claim** — *"a classifier over **the change's changed paths**"* — was corrected in **`openspec/specs/cross-model-review/spec.md`** and **`AGENTS.md`**, and the refuted lifecycle claim was corrected **in this document** (F4). Those three surfaces had all been asserting a mechanism the tool does not implement.

**Guidance for whatever replaces it:** start from **F4's range narrowing** (`scripts/cross-review-scope.sh`), settle **grandfathering** (G-GATE-7) and the **strike** (G-GATE-6) *before* proposing enforcement, and take the check-(4) tension to an `/opsx:explore` (F3) — **do not inherit a prescription from any model-authored artifact, including this one.**
