# Tasks — bound-the-agents-md-guide

> **The prototype is already built and measured.** `research/artifacts/guide-gate/` carries the hook, the installer, **45 isolated fixtures (45/45 green)**, and an **18-mutant matrix** proving every fix load-bearing. This change **lands** it: tracked sources, a `make` entry point, CI, and the spec. Port it — do not redesign it. Every rule in it was settled by measurement, and the plausible-sounding alternatives are refuted in `design.md`.

## 1. Land the gate's sources

- [ ] 1.1 Add the tracked hook source `.githooks/pre-push`, ported from `research/artifacts/guide-gate/pre-push`. Keep the ownership **sentinel** line (the installer's ours-vs-foreign discriminator) and the `XTTY_GUIDE_CEILING` / `XTTY_GUIDE_FLOOR` env overrides (the fixtures depend on them).
- [ ] 1.2 Add `scripts/install-hooks.sh`, ported from `research/artifacts/guide-gate/install-hooks.sh`: install into `$(git rev-parse --git-common-dir)/hooks` (**never** `--git-path hooks` — it follows a *global* `core.hooksPath` and would arm the gate for every repository the user pushes); stamp the repo with `git config xtty.guide-gate true`; refuse to write into a hooks dir we do not own; never clobber a foreign `pre-push`; **always exit 0**.
- [ ] 1.3 Set the initial ceiling to **65,666 B** in the hook, and record in a comment that it is a **ratchet** set from the *achieved* 64,079 B — it may only ever be lowered, and only after a measured reduction has landed (design D6).

## 2. Wire it into the build

- [ ] 2.1 Add a **phony** `hooks` target to the `Makefile` that runs `scripts/install-hooks.sh` and cannot fail.
- [ ] 2.2 Make `hooks` an **unconditional, order-only** prerequisite of `build`, `test`, `test-core`, `run`, `install`, and `setup` (`target: | hooks`). Order-only so it never marks the build out of date; phony so it re-copies every run and the installed copy can never go stale. **This is the task that arms already-bootstrapped clones — a hook wired only to `setup` leaves the maintainer's own machine, which produces essentially every push, permanently unarmed.**
- [ ] 2.3 Add the `hooks` target to `make`'s self-documenting target list.

## 3. Land the fixture suite (the gate's regression net)

- [ ] 3.1 Add the fixture suite at `scripts/test-guide-gate.sh`, ported from `research/artifacts/guide-gate/suite.sh` — **45 arms, each in an isolated scratch repo (fresh repo + remote per arm)**. The arms were previously coupled through shared remote state and one real red cascaded into spurious ones.
- [ ] 3.2 Keep **setup failure FATAL**: an earlier version of this suite reported **21 "passes"** in a sandbox where `mktemp` was failing. A green suite that never ran is a lie.
- [ ] 3.3 Add the mutation matrix at `scripts/test-guide-gate-mutants.sh`, ported from `research/artifacts/guide-gate/mutants.sh` — it reverts each fix and asserts the arm guarding it goes **red**. **Four of this suite's own arms were once green and proved nothing**; the matrix is what exposed them. A fixture that never fails is decoration.
- [ ] 3.4 Add a `make test-guide-gate` target running both.

## 4. Continuous integration

- [ ] 4.1 Add a CI step that runs `make hooks` and asserts the installed hook is **byte-identical** to `.githooks/pre-push`.
- [ ] 4.2 Add a CI step running the fixture suite + mutation matrix.
- [ ] 4.3 In `research/03-analysis/github-actions-ci-cd.md`, describe the check honestly as an **installer regression test over CI's own clone** — it is **not** a detector of unarmed developer clones, and the earlier claim that it was is corrected in `design.md`.

## 5. Documentation

- [ ] 5.1 In `AGENTS.md` → *Building*, document `make hooks` and the guide ceiling (bounded — a table row and a pointer, not a narrative; this change is about not doing that).
- [ ] 5.2 In `AGENTS.md` → *How to work here*, state the **park-don't-lose** refusal protocol: on refusal, the finding goes to its named lazily-loaded surface and the guide keeps a bounded pointer. Never relocate refused content to another **eagerly-loaded** surface — the meter covers those too.
- [ ] 5.3 Add a **Learned refutation** one-liner: the leanness rule was **overridden, not unheard** (it existed at three surfaces); the disease is **admission, not reach**; a guard scoped to one surface **displaces** growth rather than stopping it.

## 6. Verify

- [ ] 6.1 Run the fixture suite and the mutation matrix: **45/45 green**, and every mutant red at exactly its own arm.
- [ ] 6.2 **Verify the gate by effect on the real repository, in a throwaway clone** (never on `main`): arm it, attempt a push that grows `AGENTS.md` past 65,666 B ⇒ **REFUSED**; attempt an unrelated push ⇒ **ALLOWED**; attempt a push that deletes the guide ⇒ **REFUSED**. A syntax check or a read-back is **not** acceptable evidence.
- [ ] 6.3 Confirm the meter reads the real repository correctly: `resolve_guide HEAD` → **64,079 B** through `main`'s actual symlink. *(The pre-fix meter read **9 bytes** — `git show` on a symlink returns the link target.)*
- [ ] 6.4 Confirm an already-bootstrapped clone is armed by a routine `make build` alone (no `setup`, no re-bootstrap): `git config --get xtty.guide-gate` → `true`, and the installed hook is byte-identical to the source.
- [ ] 6.5 Run the standard test suite to confirm no regression ⟶ **xtty-test-validator (Tier-1 `make test` + `make test-core`)**
- [ ] 6.6 `openspec validate --all --type spec`

## 7. Completion

- [ ] 7.1 Pre-archive coherence review ⟶ **xtty-openspec-critic (bound-the-agents-md-guide)**
- [ ] 7.2 **HUMAN-ONLY — THE MODEL MUST STOP HERE.** This change is **in scope** for the cross-model gate (it touches `.githooks/`, `scripts/`, `Makefile`, `.github/` — all outside the docs allowlist). The **human** runs `/xtty:cross-review bound-the-agents-md-guide`, **reads the complete ledger**, runs `scripts/cross-review-digest.sh bound-the-agents-md-guide` themselves, and ticks this task **recording the reviewed-state digest on a delimited attestation line** in this file:
      `<!-- cross-review-attestation: base=<B> head=<HEAD> digest=<sha256> reviewed=<date> -->`
      **The model may not tick this task and may not derive, compute, or fill in the attested value.** A model-authored attestation certifies the opposite of what it claims.
- [ ] 7.3 Archive + reconcile the trackers ⟶ **archive-ritual** *(step 0 — the fail-closed precondition — runs FIRST, before `openspec archive`)*
