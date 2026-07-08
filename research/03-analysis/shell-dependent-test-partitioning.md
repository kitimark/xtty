# Shell-dependent test partitioning — the vacuous-pass finding and the two-change strategy

> **Provenance:** 2026-07-07. Produced by an `/opsx:explore` session that started from a single
> question — "how do we fix `XttyUITests.testMultiLinePasteIsNotAutoExecuted`?" (the sole standing
> `build-and-test` red, `bash32-no-bracketed-paste`, confirmed IN-ENVELOPE on run `28841237111`) — and
> widened into a test-architecture finding. Grounded in direct repo greps (file:line cited inline) and
> synthesises the existing VM/CI forensics rather than re-measuring them. **Status (updated 2026-07-08):**
> the first change, **`add-zsh-test-image`, is built + measured** — the `xtty-test-zsh:26.5` golden exists and
> the divergence below is now confirmed by effect on real rigs (zsh headless envelope `40/1/1` at that time,
> semantic family asserting-for-real with 0 capture-inactive; the paste `:82` residual in that envelope was a
> **prompt-width soft-wrap**, since **fixed** by `harden-paste-wrap-assertion` → `41/0/1`, so only the bash
> `:87` execution arm is now shell-dependent); the second, `split-shell-dependent-testplan`, remains
> proposed (the honest-`XCTSkip` follow-up for the bash execution arm). This doc is the *why*; the actionable *what* lives in the changes.
>
> **Confidence tags:** ✅ grep-proven in this repo · ✅ᶠ measured in a cited forensics doc · ❓ run-to-verify
> (depends on a rig not yet built).

## The headline

xtty's XCUITest suite is **already partitioned by shell**, but only implicitly — and on the bash rig the
partition manifests as **vacuous passes that assert nothing**, which reads as coverage but is false
confidence. The one honest exception (`testMultiLinePasteIsNotAutoExecuted`) is the test that *hard-fails*,
not the one that's broken. The fix is to make the partition **explicit and honest**, and to add a rig where
the shell-dependent half actually runs.

## Mechanism — why the suite splits along a shell line

Two independent shell capabilities decide the outcome of ~half the suite, and **neither is xtty's own code
failing**:

1. **OSC 133/7 semantic capture is zsh-only.** xtty injects shell integration by redirecting `ZDOTDIR` to a
   bundled dir — a **zsh-only** mechanism (`ShellResolver.launchConfig`, gated `base == "zsh"`;
   `shell-integration` spec). Under bash there is no injection, so no OSC 133/7, so semantic capture never
   goes live. ✅

2. **Bracketed paste is a shell/readline capability, and macOS bash 3.2.57 lacks it.** SwiftTerm's paste path
   wraps the clipboard in `\e[200~…\e[201~` **iff** `terminal.bracketedPasteMode` is true
   (`external/SwiftTerm/.../Mac/MacTerminalView.swift:1180`), and that flag is set only when the shell emits
   `\e[?2004h`. bash 3.2's readline predates `enable-bracketed-paste` (readline 7.0 / bash 4.4+), so it never
   enables it → xtty legitimately pastes raw bytes → the embedded `\n` executes. ✅ᶠ
   (`github-actions-ci-cd.md` §19b; `packer/README.md` → Acceptance / Expected-difference matrix).

Both rigs that matter — the GitHub Actions runner and the Tart VM — run Apple's bash 3.2.57 **on purpose**
(`packer/xtty-test.pkr.hcl:132` `chsh -s /bin/bash`), for CI-parity *and* to dodge the zsh-only Local Network
privacy modal (`local-network-privacy-forensics.md`). So the VM fails the paste test identically to CI — as
expected, not as a surprise.

## The finding — graceful degradation → vacuous pass → false confidence

The semantic-capture family doesn't fail on bash; it **early-returns**. Every one of these files carries the
same guard (grep-proven — `waitForSemanticCaptureActive()` + a `"…capture inactive (host zsh config?)"`
screenshot + `return` **before any assertion**):

```
$ grep -rln 'waitForSemanticCaptureActive\|capture inactive' AppUITests/*.swift
XttyBlockSidebarUITests.swift      (6 test methods)
XttyGitReviewUITests.swift         (4)
XttySpatialBlocksUITests.swift     (3)
XttySemanticCaptureUITests.swift   (3)
XttyFileLinkOpenUITests.swift      (2)
XttySessionSidebarUITests.swift    (1)
```

That is **19 methods** that, on the bash rig, take the degrade arm and **pass while asserting nothing**. The
packer README even documents this as intended ("take their graceful-degradation arms under bash"). The lone
shell-dependent test *without* a degrade arm is `testMultiLinePasteIsNotAutoExecuted` (`XttyUITests.swift:62`),
which asserts unconditionally and therefore **hard-fails** on bash 3.2. So the current bash-rig picture is:

```
   shell-dependent (~20)          on the bash rig (CI + current VM)
   ├─ 19 semantic-family    →  early-return  →  "PASS"   ← asserts nothing (vacuous)
   └─  1 paste test         →  asserts       →  FAIL     ← the only honest one
   shell-agnostic  (~22)    →  asserts       →  PASS     ← real coverage
                                                            (42 methods total)
```

The paste red isn't the problem to make disappear — it's the **only** shell-dependent test telling the truth.
The real defect is the 19 vacuous passes. (The i18n half of `testTruecolorEmojiAndWideChars` is a partial case
— its emoji/CJK content also rides Cmd+V paste, so it too is bracketed-paste-sensitive.)

### The concrete partition (42 methods)

| Set | Members | Count | Bash-rig behavior today |
| --- | --- | --- | --- |
| **Shell-dependent** | semantic-capture · session/block sidebar · git-review · spatial-blocks · file-link-open · `testMultiLinePasteIsNotAutoExecuted` (+ i18n-paste half of truecolor) | **~20** | 19 vacuous-pass · 1 hard-fail |
| **Intersection (shell-agnostic)** | multiplexing · quick-terminal · config · profile · lifecycle-census · find-bar · focus-on-activate · resize · GridDumpReader | **~22** | real pass ✅ |

The line is exactly the OSC-injection / bracketed-paste boundary; membership falls out mechanically.

## Reproducible probes

- **P1 — prove the vacuous passes (static).** `grep -n 'waitForSemanticCaptureActive' AppUITests/*.swift` →
  each hit is followed by a screenshot + bare `return`. *Proves:* the assertions are gated behind capture
  being live. *Cannot prove:* whether capture is live on any given rig (that's P2).
- **P2 — prove it by effect (runtime).** On the bash rig, inspect the `.xcresult` attachments: the presence of
  `"semantic-capture-inactive (host zsh config?)"` screenshots on the family = they took the degrade arm; the
  paste test's `paste-grid` shows `-bash: alpha####: command not found` (executed, not staged). *Proves:* the
  divergence is real, not theoretical. This is the **re-verify-by-effect** check — never read the test source
  and assume.
- **P3 — the suite needs no test-plan to run.** `packer/README.md` Runtime workflow invokes
  `xcodebuild test-without-building -xctestrun *.xctestrun` — the whole 42-method suite runs with no plan
  selection. *Proves:* a zsh rig can run the **current, unmodified** suite and simply observe a different
  result — so the zsh-image change stands alone, ahead of any test-code split.

## Options considered — fates

| Option | Verdict | Why |
| --- | --- | --- |
| Pre-grant / suppress the Local Network modal so the rig can just use zsh | ❌ | Not pre-grantable — `tccutil` doesn't cover LN, no MDM payload, NE-plist edits are daemon-reconciled, the arbiter is "irreducible" (`local-network-privacy-forensics.md` §2a, G9). |
| Swap the rig to Homebrew **bash 5.1+** (has bracketed paste) | ❌ | Fixes *one* test, not the family (bash still gets no OSC injection → semantic tests stay vacuous), and breaks hosted-runner parity (runner is bash 3.2). Image bloat + network dep. |
| `XCTSkip` the shell-dependent tests everywhere | ❌ alone | Honest, but throws away the coverage entirely — nothing ever exercises the real arm. Only acceptable **paired** with a rig that does run them. |
| Assert the degraded behavior (first line executes) on bash | ❌ | Inverts the test's intent — asserts the *shell*, not xtty. Zero product value. |
| Force `terminal.bracketedPasteMode` on and assert xtty emits the brackets, shell-free | ⚠️ candidate | Tests xtty's *half* deterministically (good), but the wrapping is SwiftTerm's, so it partly re-tests upstream; kept as a possible add in the split change, not the core fix. |
| **Two explicit sets + honest skip + a zsh rig that runs the dependent set** | ✅ decided | Makes the partition real, converts vacuous-pass/red → honest skip on incapable shells, and gives the dependent set *real* coverage where a capable shell exists. |

## The decided strategy — two changes, measurement-first ordering

Scoped in this session (owner-confirmed). Ordering was **deliberately reversed** from the first sketch so the
hypothesis is proven on real rigs *before* the suite is restructured — this repo settles by measurement, and a
zsh rig is the instrument.

1. **`add-zsh-test-image` — FIRST (observe-only, no test-code changes) — ✅ BUILT + MEASURED (2026-07-08).**
   Parameterised the packer template (`shell = bash | zsh`): kept `xtty-test:26.5` (bash, unchanged) + built
   `xtty-test-zsh:26.5`. **The LaunchDaemon `/etc/hosts` fix-class (b) was refuted on this image** — it did
   not neutralise the gate (the routable-IPv4 reverse PTR escapes the files module; 40 gate events measured,
   task 4.1 / `local-network-privacy-forensics.md` §8), so no rig-level machinery ships and the divergence is
   measured **headless** (the modal is graphics-only); the durable fix is the product change
   `fix-osc7-hostname-reverse-dns` (the `gethostname` swap, landed 2026-07-08). Ran the *existing* suite on
   both rigs and recorded the **divergence** as the acceptance criterion (not all-green): **measured — bash
   `40/1/1` (family vacuous, 16–17 "capture inactive" attachments; paste executes `:87`) ↔ zsh `40/1/1`
   (family asserting-for-real, 0 "capture inactive"; paste stages correctly but the first line soft-wrapped
   behind the 70-col wide zsh prompt so the strict matcher missed it at `:82`).** The
   critical evidence held: the zsh rig takes the **real arm** (0 capture-inactive attachments), so its green is
   genuine coverage, not another vacuous pass. Measured surprise: the paste test reds on *both* shells — but for
   **different reasons that fix differently**: bash execution `:87` (a shell-capability miss, skipped by change 2)
   ↔ zsh `:82` a **prompt-width soft-wrap**. The zsh `:82` is **not** a change-2 skip candidate but a matcher
   bug, **fixed** by `harden-paste-wrap-assertion` (wrap-tolerant matcher, zsh rig `40/1/1` → `41/0/1`); change 2
   skips only the bash `:87` arm.
2. **`split-shell-dependent-testplan` — SECOND (informed by the measured divergence).** Two `.xctestplan`s
   (`Intersection` + `ShellInteractive`) wired via the XcodeGen scheme; convert the family's silent `return`
   and the paste test's hard assertion into **honest `XCTSkip`/`XCTSkipUnless`** keyed on the true capability
   predicate (semantic-capture-active for the family; the terminal's reported `bracketedPasteMode` for paste,
   sampled **after** the computed-marker shell-readiness gate of `harden-churn-shell-readiness`, never before
   the first prompt). Exposing `bracketedPasteMode` in the DEBUG state dump is a **new harness observation** →
   carries a `verification-harness` spec delta + task (AGENTS.md harness-coupling rule).

Both changes have a **reverse duty** to update `packer/README.md` Acceptance/matrix + `github-actions-ci-cd.md`
§19b in the same session (bash rig: paste red → skip; new zsh-rig envelope), or the validator/investigator
"runtime read" just relocates the staleness. The zsh rig is a **supplement**, not a replacement — the bash rig
keeps proving CI-parity; a future GitHub-Actions zsh job is out of scope for now but is the eventual target.

✅ **Front-loaded risk — materialised, then resolved (why zsh-first was the smart order):** the LN arbiter
*was* irreducible at the rig level; the `/etc/hosts` daemon could **not** tame the modal (change 1 task 4.1),
and we learned it before change 2 depended on the rig. The fallback became the fix: the product change
`fix-osc7-hostname-reverse-dns` (`gethostname` vs `ProcessInfo.hostName`) landed 2026-07-08 and removes the
trigger entirely (0 gate events, headless *and* graphics). Measuring zsh-first paid off exactly as intended.

## Re-verify by effect

- **The vacuous-pass claim:** run the current suite on the bash rig; in the `.xcresult`, confirm the 19
  family methods carry `"…capture inactive…"` attachments (degrade arm) and the paste grid shows
  `command not found` (executed). If a family test asserted its real payload on bash, this doc is wrong.
- **The divergence — ✅ CONFIRMED 2026-07-08 (`xtty-test-zsh:26.5` headless ×2 + a graphics pre-check):** the
  same binary + same suite yielded a *different* result on the zsh rig — the semantic family attachments showed
  the live-capture arm (**0** "capture inactive" vs bash's 16–17), proving same-binary divergence across shells
  by effect. (`add-zsh-test-image` first saw the paste test red on zsh at `:82`, not the bash execution arm
  `:87`. That `:82` red was **not** a grid-capture miss and **not** a change-2 skip candidate but the
  **prompt-width soft-wrap** class: the pasted first line *did* stage — the wide 70-col zsh prompt just wrapped
  it past the 78-col boundary so the strict matcher couldn't span the `\n`. `harden-paste-wrap-assertion`
  **fixed** it with the wrap-tolerant matcher (`40/1/1` → `41/0/1`, red→green on both VM arms) — a matcher fix,
  not a skip. So the paste *does* stage both lines on zsh; the earlier "does not stage both lines" reading was a
  strict-matcher artifact — measured, not inferred.)

## Reusable guideline

> **Graceful degradation that returns before asserting is a vacuous pass, and a vacuous pass is
> indistinguishable from coverage until you read the attachments.** When a test's real arm depends on an
> environment capability (a shell feature, a GPU, a network), either (a) `XCTSkip` on the capability predicate
> so the miss is *recorded as a skip*, or (b) run it on a rig that *has* the capability — never let it
> silently no-op into green. And prove the capable rig takes the real arm *by effect* (an artifact only the
> real path produces), because a degrade arm and a real arm both show up as "passed."

## Sources

- Repo greps (2026-07-07): `AppUITests/*.swift` (degrade-arm pattern, method counts, `XttyUITests.swift:62`
  paste test), `external/SwiftTerm/.../Mac/MacTerminalView.swift:1180` (paste bracketing gate),
  `XttyCore/Sources/XttyCore/ShellResolver.swift` (zsh-only injection), `packer/xtty-test.pkr.hcl:132`
  (`chsh -s /bin/bash`), `packer/README.md` (Runtime workflow, Acceptance `40/1/1` of 42, Expected-difference
  matrix), `project.yml` (scheme test target, no test-plan today).
- `research/03-analysis/github-actions-ci-cd.md` §19b — the `bash32-no-bracketed-paste` bucket + CI matrix.
- `research/03-analysis/local-network-privacy-forensics.md` — why the rig is bash; the LN gate machinery, the
  non-pre-grantable arbiter (§2a/G9), and the `/etc/hosts` fix-class (b) (P7, 0 gate events).
- `research/03-analysis/ci-runner-prompt-width-forensics.md` — companion "why this test reds only here"
  environment-difference doc; the paste `:87`-not-`:84` measured correction.
- Investigation of run `28841237111` (this session, via `xtty-ci-investigator`) — the paste red confirmed
  IN-ENVELOPE, find-bar wrap fix confirmed green.
