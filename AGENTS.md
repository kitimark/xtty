# AGENTS.md — xtty

Guidance for AI agents (and humans) working in this repository. This is the canonical project guide; `CLAUDE.md` imports it.

## What this project is

**xtty** is a **native macOS terminal emulator**. It is greenfield and in the **build** phase: the app already launches a live terminal (the user's login shell in a SwiftTerm engine hosted in AppKit). The direction, requirements, and design are documented in `research/`; implementation proceeds milestone-by-milestone via the OpenSpec workflow.

## Current status

**Snapshot (2026-07-06):** P0–P7 are all implemented and archived — xtty is a daily-drivable native terminal: tabs/splits/windows, quake terminal, profiles, OSC 7+133 semantic capture on auto-injected zsh, session + block sidebars, file-link open, spatial block navigation, git review panel (flat/tree), and the perf harness that settled the renderer question (**keep CoreGraphics**). Test posture: **232 `XttyCore` unit + 41 XCUITests** (post-`retire-metal-renderer`); local `make test` green — the churn confirm-close race is **fixed** by `harden-churn-shell-readiness` (computed-marker shell-readiness gate; churn now 5/5 local + green on both VM rigs, full-sweep-validated 2026-07-06); VM-rig acceptance envelope **39/1/1 of 41** (sole benign residual: multi-line paste on the rig's bash-3.2), authoritative home `packer/README.md` → Acceptance. CI: `test-core` is the green required gate (Metal-guard-free); `build-and-test` non-blocking — the menu-clobber product bug is fixed and CI-confirmed; 2 residual rig fragilities deferred to a harness-truthing follow-up.

**Open changes** (must match `openspec list`):

| Change | State | What it is | Detail |
| --- | --- | --- | --- |
| `add-ci-pipeline` | implemented — owner steps left | CI is live; remaining: repo public, pr-lint PR, branch protection, archive | `research/03-analysis/github-actions-ci-cd.md` |
| `add-openspec-critic-agent` | implemented — dogfood-proven, pending archive | committed `xtty-openspec-critic` agent + `/xtty:review` launcher: change-set-aware OpenSpec coherence + disk-drift review | `research/03-analysis/dev-workflow-agent-orchestration.md` |
| `add-vm-prompt-width-parity` | implemented — pending archive (pair #1) | long-`\h` (59-char) Tart image reproduces the runner's prompt width; image rebuilt + VM re-baselined **`38/2/1` interim** (find-bar reds in-guest as the transient repro; D2 verified by effect; paste stayed `:87`, not `:84`); on-archive snapshot/HISTORY left (task 5.2) | `research/03-analysis/ci-runner-prompt-width-forensics.md` |
| `harden-findbar-wrap-assertion` | implemented — pending archive (pair #2) | test-only: wrap-tolerant matcher at `XttyUITests.swift:198` + `testSoftWrapGuardIsWrapTolerant`; §19b `findbar-marker-wrap` residual→**fixed**. Red→green **proven in-guest** on the wide-prompt image (validator full sweep: VM `40/1/1` of 42, find-bar green, D2-confirmed); local Tier-1 blocked by this Mac's Automation-Mode auth. On-archive: task 5.2 | `research/03-analysis/ci-runner-prompt-width-forensics.md` |

**Shipped and archived** (full narratives: [HISTORY.md](HISTORY.md); what is true: `openspec/specs/`; mechanisms: `research/`):

| Group | Changes | Detail |
| --- | --- | --- |
| Foundation (P0–P2) | app skeleton; SwiftTerm integration (AppKit-hosted); verification harness; daily-driver baseline (config loader, bounded scrollback, find, font sizing) | [HISTORY.md](HISTORY.md) |
| Multiplexing + UX (P3) | tabs/splits/windows + configurable keybindings; quake terminal; profiles | `research/03-analysis/p3b-shell-ux-decisions.md` |
| Semantics (P4) | OSC 7/133 capture + zsh auto-inject + alt-screen gating; file-link open (D7 scheme guard); spatial blocks (jump-to-prompt, copy-output; the 2-accessor SwiftTerm patch); block sidebar | `p4-semantic-capture-decisions.md`, `p4b-2-spatial-blocks-decisions.md` |
| Sidebar + git (P5–P6) | session activity sidebar; git-review panel + intra-line diff polish + flat↔tree toggle | `p5-sidebar-and-p4b-sequencing.md`, `p6-file-diff-decisions.md` |
| Performance (P7) | latency/memory harness; trustworthy `SCStream` latency probe → **keep CoreGraphics, skip Phase 8**; lifecycle census (leak guard) | `p7-measurement-methodology.md`, `p7c-leak-retain-audit.md` |
| Tooling | local signing identity; CI pipeline; bash-banner silence; wrap-tolerant focus matcher; **menu-clobber fix (`NSApplicationMain`)**; `xtty-test-validator` agent (v4); capture-research tooling + depth bar; **AGENTS.md rules/history split (`slim-agents-context`** — −21.5k startup tokens, probe-verified 36/36 vs fat 34/36**)**; **Metal-renderer retirement (`retire-metal-renderer`** — zero-Metal build, CI guard-free, graphics-VM-validated 39/1/1 of 41; resurrection = P7b methodology**)**; **churn shell-readiness hardening (`harden-churn-shell-readiness`** — computed-marker readiness gate + fail-fast asserted steps + `.common`-mode modal-live dumps; churn F/F/P → 5/5 local + green across both VM rigs**)**; **validator-delegation trigger (`harden-validator-delegation-trigger`** — iterate/validate boundary + per-task `⟶ xtty-test-validator` marker + `config.yaml` `rules.tasks` seed; §6 by-effect proof held: autonomous-spawn on the post-compact `harden-churn` apply**)**; **minimal local VM test image (`add-xtty-test-image`** — ~35 GB Packer/Tart image from pinned inputs, simulator+Metal-toolchain-free, no Apple creds at build; native in-guest build+test proven 2026-07-06; home `packer/README.md`**)**; **test-image bash login shell (`test-image-bash-shell`** — guest shell → `/bin/bash` for exact hosted-runner parity; kills the Local-Network privacy modal (zsh-only OSC 7 reverse-DNS root cause)**)**; **CI-failure investigator (`add-ci-investigator-agent`** — committed `xtty-ci-investigator` Sonnet agent + `/xtty:investigate-ci` launcher; reads a red run and classifies each failure against the new CI expected-difference matrix (`github-actions-ci-cd.md` §19); watch-vs-investigate delegation boundary + `⟶ xtty-ci-investigator` marker; by-effect proof held — autonomous IN-ENVELOPE on run `28801860582`**)**; **OpenSpec coherence critic (`add-openspec-critic-agent`** — committed `xtty-openspec-critic` **Opus** agent + `/xtty:review` launcher; change-set-aware review (single-change rules + disk-drift + cross-change collisions/red→green pairs) deferring to AGENTS.md's rulebook + live repo; validate-vs-review boundary + `⟶ xtty-openspec-critic` marker; by-effect dogfood held — COHERENT on the 4-change set, caught the `7/10`→`19/34` drift it predicted + the red→green pair**)** | `dev-workflow-agent-orchestration.md`, `agents-md-context-budget.md`, `github-actions-ci-cd.md`, `swiftui-mainmenu-clobber-forensics.md`, `claude-code-subagent-execution-forensics.md`, `confirm-close-shell-readiness.md`, `packer/README.md`, `local-network-privacy-forensics.md` |

**Established specs** (must match `ls openspec/specs/`): `app-shell`, `build-workflow`, `terminal-configuration`, `terminal-keybindings`, `terminal-links`, `terminal-multiplexing`, `quick-terminal`, `terminal-session`, `terminal-semantics`, `shell-integration`, `session-sidebar`, `git-review`, `terminal-spatial-blocks`, `lifecycle-census`, `verification-harness`, `performance-harness`, `research-capture`, `test-validation`, `ci-investigation`.

**Learned refutations — do not re-propose.** Each was settled by measurement; details in [HISTORY.md](HISTORY.md) and the linked research docs:

- **Test retry flags / retry tolerance are banned** — retries mask the per-launch race class (a retried VM run green-lit two genuinely broken tests).
- **`run_in_background` strands subagents** — its "re-invokes you" promise is false for them; a subagent that ends its turn mid-work is never resumed. Foreground bounded waits only.
- **Re-asserting `NSApp.mainMenu` is a no-op** — SwiftUI's reconciler mutates the same `NSMenu` instance in place; the shipped fix dropped the SwiftUI lifecycle (`NSApplicationMain`).
- **`hasForegroundJob`-based readiness waits are refuted** — fg==shellPid from ~3 ms; 15–57 ms child bursts invisible to the 150 ms dump sampler; use the computed-marker execution roundtrip.
- **SwiftUI `NSViewRepresentable` hosting renders SwiftTerm black** on macOS 26 — host the terminal view in an AppKit `NSWindow`.
- **The Metal renderer was rejected by measurement** (worse p99 tail, more memory, no median win); resurrecting it requires re-running the archived P7b methodology, not an opinion.
- **The Scope-B project file-tree browser is rejected** as off-mission IDE-creep (P6b addendum in `p6-file-diff-decisions.md`).
- **`launchEnvironment`/CI env vars are stripped by the curated child-env seed wall** — environment fixes must land at the product seam (`ShellResolver`) or they silently no-op.
- **Agent-definition edits reach spawns with unpredictable lag** — verify delivery per run (the `Definition:` stamp); a spawn 63 s post-edit was served the stale copy.
- **Guest bash 3.2 has no bracketed paste** — the VM rig's multi-line-paste red is a benign rig residual, not a product bug.
- **The hosted-runner find-bar wrap is not reproducible from the image build** — stock macOS `PS1='\h:\W \u\$ '` is byte-identical on runner + VM (`runner-images` sets no `PS1`); the runner's ~61-char `\h` is GitHub-network-injected at *runtime* (the image sets only `Mac-<epoch>.local`), so the sole reproduction lever is hostname *length*, which we control — and the short-`\h` Tart VM is blind to prompt-width flakes by construction (`ci-runner-prompt-width-forensics.md`).
- **`xcrun -f metal` inside a VM is a false positive** — it PATH-resolves while the toolchain is unfetchable in-guest.
- **Don't pre-build a speculative dev-workflow agent roster** — add an `xtty-*` agent only after its friction recurs across several changes and is provably under-done (both existing agents were reactive; a proposed roster-of-4 was refuted by the dev-workflow forensics → build one **change-set-aware** `openspec-critic` first, adopt fork-per-change authoring as a habit). Delegate only above the ~12k-token subagent-inheritance floor; compute cross-artifact state on demand, never cache counts (`dev-workflow-agent-orchestration.md`).

## Repository structure

```
xtty/
├── AGENTS.md        # this file — canonical project guide
├── CLAUDE.md        # imports AGENTS.md (Claude Code entry point)
├── research/        # exploratory background (read before proposing direction)
│   ├── 00-overview/ #   landscape synthesis + comparison matrix
│   ├── 01-terminals/#   per-terminal deep-dives (iTerm2, Ghostty, Warp, …)
│   ├── 02-internals/#   how terminals work (PTY, VT parsing, GPU/Metal, fonts, …)
│   ├── 03-analysis/ #   fact-checks, opportunities, requirements, agents-and-xtty
│   └── 04-design/   #   the build plan: stack sketch + phased milestones
└── openspec/        # spec-driven implementation workflow
    ├── config.yaml  #   project context shown to AI when creating artifacts
    ├── specs/       #   established specs (source of truth) — grows as changes land
    └── changes/     #   in-flight change proposals (+ archive/ for completed)
```

Start here: `research/README.md` (index), `research/03-analysis/xtty-requirements.md` (what we're building), `research/04-design/01-stack-sketch.md` + `02-milestones.md` (how).

## Tech stack (primary: "All-Swift")

- **UI/chrome:** Swift + SwiftUI/AppKit
- **Renderer:** *researched Phase-8 path, skipped by the closed P7b gate — xtty ships SwiftTerm's CoreGraphics renderer.* The sketch: custom Metal view (`MTKView`/`CAMetalLayer`), CoreText glyph atlas, dedicated render thread, **latency-first** (frame pacing > throughput)
- **VT engine:** reuse **SwiftTerm**'s headless `Terminal` core (parser + grid)
- **PTY:** Darwin `posix_openpt`/`forkpty` + kqueue read/write loop
- **Shell integration:** OSC 7 (cwd) + OSC 133 (command boundaries) capture

Researched alternatives if we hit limits (Rust core + Swift, Zig/libghostty + Swift, Swift + libghostty-vt) are in `research/04-design/01-stack-sketch.md` with switch triggers.

## Building

The Xcode project is generated from a committed `project.yml` via **XcodeGen**; the resulting `xtty.xcodeproj` is **gitignored** (never commit it).

**Quick start — use the `Makefile`.** It is the single entry point; run `make` (no target) to list everything. It only wraps the commands documented below.

| Command | What it does |
| --- | --- |
| `make doctor` | check the prerequisites you must install yourself (XcodeGen, full Xcode) and print how to get each |
| `make setup` | first-time, post-clone: `doctor` → bootstrap SwiftTerm → generate the project |
| `make build` / `make run` | build (then launch) the app — **auto-bootstraps SwiftTerm and regenerates the project only when their tracked inputs changed** |
| `make test-core` | the fast `XttyCore` unit loop (no app build) |
| `make test` | the app XCUITests (the benchmark e2e is opt-in — set `XTTY_RUN_BENCH_E2E=1` — so routine runs never prompt for Screen Recording) |
| `make bench` | the P7a performance harness — latency + per-scenario memory → a JSON report under `build/bench/` (latency is **coarse/experimental**; memory is the trustworthy result — see `research/03-analysis/p7-measurement-methodology.md`) |
| `make image` | build the minimal **~40 GB local test-VM image** (Packer + Tart, from pinned inputs) — prereqs are human-gated and only advised (packer install + a one-time Apple-ID Xcode-`.xip` download); see `packer/README.md` |
| `make bootstrap` / `make generate` | force a re-run after editing the SwiftTerm pin/patch or `project.yml` |
| `make clean` / `make reset` | remove build outputs / nuke + rebuild the SwiftTerm checkout |

The targets are thin wrappers — reach for the underlying commands below directly if you're not using `make`, or to understand what a target does:

- **Prerequisite:** XcodeGen — `brew install xcodegen` (developed against **v2.45.4**). Building/testing the app target needs **full Xcode** (the Command Line Tools alone lack `xcodebuild`, `XCTest`, and swift-testing). Verified against **Xcode 26.6**.
- **SwiftTerm checkout (one-time, P4b-2):** SwiftTerm is consumed as a **gitignored upstream clone** at `external/SwiftTerm`, pinned via `patches/swiftterm/UPSTREAM_CONFIG.sh` (currently `v1.13.0`) with a tracked **patch** applied (the P4b-2 accessors add + a `Package.swift` hunk stripping the Metal shader resource, so builds need **no Metal toolchain** — `retire-metal-renderer`) — the no-fork "patch in repo" mechanism, Playwright-style (see `research/03-analysis/swiftterm-fork-vs-patch-strategy.md`). After cloning xtty, run **`scripts/bootstrap-swiftterm.sh`** — it clones `external/SwiftTerm`, restores the pinned ref pristine (checkout + reset + clean, enforced every run), and `git apply`s `patches/swiftterm/xtty-accessors.diff`. Re-run it after editing the pin or the patch. The build fails to resolve `../external/SwiftTerm` until this runs. Nothing under `external/SwiftTerm` is tracked (it's `.gitignore`d build infra); only the pin + the `.diff` + the script are version-controlled. Retire the whole mechanism once the accessors land in an upstream SwiftTerm release.
- **Local VM test image (optional):** `make image` builds the minimal **~40 GB** Tart image `xtty-test:26.5` from pinned inputs (no simulators, no Metal toolchain, no xtty source baked in; prereqs human-gated — packer + a one-time Apple-ID Xcode `.xip` download). Purpose: CI-parity XCUITest runs — the per-launch race class reproduces at 3 vCPU in a VM, not on bare metal. Runtime workflow, acceptance envelope, and expected-difference matrix: **`packer/README.md`**. Depends on `retire-metal-renderer`.
- **Generate the project:** `xcodegen generate` (re-run after editing `project.yml` or adding/removing source files).
- **Build & run:** open `xtty.xcodeproj` in Xcode, or `xcodebuild -project xtty.xcodeproj -scheme xtty build`.
- **Core package:** `XttyCore` is a local SPM package (the engine-facing seam). It builds/tests standalone from `XttyCore/` via `swift build` / `swift test` (tests need Xcode's toolchain for XCTest).

Signing posture (P0): **App Sandbox OFF** (`App/xtty.entitlements`), **Sign to Run Locally** (ad-hoc identity), Hardened Runtime/notarization deferred.

- **Optional stable local signing (dev convenience):** ad-hoc signing changes the app's code identity every rebuild, so TCC grants (notably Screen Recording for `make bench`) re-prompt per build. Create the self-signed cert once with `scripts/create-signing-cert.sh` (→ `xtty-dev`) and build with `XTTY_SIGN_IDENTITY=xtty-dev make build|test|bench`; unset, builds stay ad-hoc/portable. Full distribution (Developer ID + Hardened Runtime + notarization) is researched **green but gated on the ~$99/yr Apple Developer Program decision** — `research/03-analysis/distribution-signing-research.md`.

### Continuous integration (GitHub Actions)

CI runs on every push and pull request via `.github/workflows/` — **$0 and secret-free** (the ad-hoc default needs no Apple credentials; standard `macos-26` runners are free + unlimited on public repos). Two jobs in `ci.yml`:

- **`test-core`** (the **required gate**) — reconstitutes SwiftTerm and runs the fast view-free `XttyCore` unit tests (`swift test`, no app build). Deterministic; this is the check to require in branch protection.
- **`build-and-test`** (**non-blocking**) — `xcodegen generate` + `xcodebuild test` (the app XCUITests), retry-tolerant, uploads the `.xcresult` on failure. Kept out of required checks while hosted-runner XCUITest reliability is being proven.

Both jobs cache the reconstituted `external/SwiftTerm` (keyed on the pin + patch); no Metal-toolchain guard is needed — the build is Metal-free (`retire-metal-renderer`). `pr-lint.yml` enforces Conventional Commit **PR titles** (pull requests only). The workflows call `scripts/bootstrap-swiftterm.sh` directly (not `make`). Release/notarization are **not** in CI (deferred). Current CI truth: `test-core` is green and gate-worthy; `build-and-test` is non-blocking with the menu-clobber fix confirmed on CI and 2 residual rig fragilities (find-bar marker-wrap on the runner's ~72-char prompt; multi-line paste on bash-3.2) deferred to a harness-truthing successor. The full CI investigation record — runner forensics, the SwiftUI menu-clobber root cause and fix, the shell/banner fixes, per-run counts (§9–§18) — lives in `research/03-analysis/github-actions-ci-cd.md`, with the chronological digest in [HISTORY.md](HISTORY.md).

## Product values (hard requirements)

- **Lean memory** — nowhere near Warp; bound scrollback, manage the glyph atlas, avoid retain cycles.
- **No account / no login, free and open, no paywalled features.**
- **Native macOS feel**; keep the user's existing zsh/tmux/dotfiles working.
- **Great host for agent CLIs** (Claude Code, etc.) — agents pluggable/local, not vendor-locked.

Signature features: at-a-glance per-session progress sidebar (from OSC 133); a *lightweight* in-terminal file/diff view (not a full IDE). Full list: `research/03-analysis/xtty-requirements.md`.

## How to work here

- **Implementation follows the phased plan** in `research/04-design/02-milestones.md` (P0 skeleton → P5 daily-driver → **P7 OSC capture (keystone)** → P8 sidebar → P10 polish). P8/P9 depend on P7.
- **Use OpenSpec for non-trivial changes** (see the OpenSpec workflow section below). The project `context` in `openspec/config.yaml` is shown to the AI on every artifact.
- **Research is background, not spec.** `research/` records *why*; `openspec/specs/` will record *what is true*. When they conflict once code exists, specs win.
- **Write up research in `research/` when it's done.** Whenever an investigation or spike produces durable findings — a tooling landscape, a comparison, an internals discovery, a dead end worth remembering — capture it as a `research/` doc *as soon as it settles* (even mid-build), in the right subfolder (`03-analysis/` for analysis, `02-internals/` for internals, `04-design/` for build-plan shifts). Follow the research-doc conventions (Provenance + Sources + ✅/❌/❓) and add it to `research/README.md`. **Capture depth — settle the *mechanism*, not just the conclusion (scaled to the finding).** Any capture with **measured claims or retired theories** carries: (1) the **mechanism/internals** (how the system actually works, with the evidence); (2) **reproducible probes** — the exact commands, what each proves *and cannot prove*, including instruments that did **not** work; (3) the **investigation record** — each retired theory as a ❌ *next to the experiment that killed it* (a fates table), so stale claims can't be cited and theories don't respawn; (4) **re-verify by effect** — how a future reader re-checks the headline claim (never a syntax/read-back check); (5) when the finding generalizes, a distilled **reusable guideline** (numbered); (6) pointers to the **evidence artifacts**. Lightweight captures (a landscape/comparison with no measurements) skip these. Exemplar: `research/03-analysis/local-network-privacy-forensics.md`. Keep the *why/landscape* in `research/`; the actionable *decision* belongs in the OpenSpec change.
- **Keep progress current when implementation lands — and keep it lean.** When a change (or a milestone's tasks) is done, update the trackers in the same session: tick the `tasks.md` checkboxes; update the change's **row in the Current-status table** (bounded: state + one-liner + detail pointer — **never a narrative paragraph**); refresh the **snapshot paragraph** if counts/envelope/milestone position moved; **append the full narrative to [HISTORY.md](HISTORY.md)** under a dated heading in the matching section; and advance the milestone state in `research/04-design/02-milestones.md`. If the change settled a refutation worth never re-litigating, add a one-liner (with its conclusion) to the **Learned refutations** list. **Then verify against disk** — `openspec list` (active changes must match the open-changes table), `ls openspec/changes/archive/` (archived changes must be marked archived, not "pending archive"), `ls openspec/specs/` (established specs must match the list above) — and fix any tracker that disagrees with reality. Don't leave finished work looking pending or stale. The **`/xtty:capture-research`** command + **`xtty-capture-research`** skill walk this whole capture-and-reconcile checklist (place + index the research doc → reconcile the trackers → verify-against-disk).
- **Test-suite validation is delegated to the `xtty-test-validator` agent, not run inline.** Multi-environment validation (fast core unit tests, local bare-metal XCUITests, headless Tart VM, graphics Tart VM) floods the main session with build/VM/polling noise if run directly — so it's a committed **agent** (`.claude/agents/xtty-test-validator.md`), not inline commands. **Two spawn scenarios:** (a) a **direct user request** — via the `/xtty:validate` launcher (`.claude/commands/xtty/validate.md`) or plain natural language; (b) **OpenSpec verify-task delegation** — a verify task (in `/opsx:apply`, or any change's `tasks.md`) that executes the test suite is delegated to `xtty-test-validator`, and the apply loop consumes only its report, ticking the task with the report's verbatim counts/classification rather than running the suite inline. **The delegation boundary (two verbs — this is the trigger that historically drifted):** *iterate* — running tests for your own feedback while coding — stays **inline** for the cheap tiers: `make test-core`, one-off `-UITestGridDump` launches, greps, `make doctor`, `openspec validate`, `gh run watch` (`make bench` too, on its own). *Validate/accept* — establishing the change's acceptance posture — is **delegated** whenever a verify task runs the **Tier-1 XCUITest suite (`make test`), any VM tier, or a full acceptance matrix** (bench rides *with* a full-matrix task's delegation). **Carry the trigger into the task, not just this rule:** a delegate-set verify task in any `tasks.md` MUST be authored with the marker **`⟶ xtty-test-validator (<tier/scope>)`** right in the task line — because `/opsx:apply` does *not* re-read this file against its own loud prompt, so the marker at the point-of-tick is the only signal that reaches the apply loop (measured: the `retire-metal-renderer` apply ran the Tier-1 suite and full matrix inline, 0 autonomous delegations). **Pre-tick self-check:** before ticking a verify task that ran a suite, confirm its counts came from a validator report — or that the inline run was a cheap/iterate case within the boundary above. This file (AGENTS.md) is the single source of the boundary; `openspec/config.yaml`'s `rules.tasks` and the per-task markers only point here. **Deference chain, both directions:** the agent defers to this file (AGENTS.md) for the rules above and to `packer/README.md` for the numbers and VM mechanics (the living acceptance envelope + the expected-difference matrix + the Runtime workflow commands) — it never hardcodes them. The reverse duty: any change that alters test counts or expected residuals (e.g. a test added/removed, an environment fix) MUST update `packer/README.md`'s Acceptance/matrix section in the same session, or the agent's "runtime read" just relocates the staleness. **Editing the agent file itself is different: definition edits reach spawns with an unpredictable lag, so delivery must be verified, never assumed** (measured 2026-07-06: a spawn 63 s after an edit was served the stale pre-edit copy — probe-quoted verbatim — while a spawn ~40 min after the next edit got the fresh one; a fresh session always serves current). Every report therefore opens with a `Definition: <version>` stamp the caller checks (see the launcher), and the launcher documents the **babysitter protocol** — if a sweep strands (the agent parks mid-run), the caller reconstructs from the run's `ledger.log`/`REVIEW.md` and resumes the same agent via SendMessage, recording the resume in REVIEW.md.
- **CI-failure investigation is delegated to the `xtty-ci-investigator` agent, not run inline.** Diagnosing a red GitHub Actions run floods the session with failing-job logs, the `.xcresult` download, `xcrun` parsing, and dozens of exported attachments — so it's a committed **agent** (`.claude/agents/xtty-ci-investigator.md`) that returns only a fixed verdict, mirroring `xtty-test-validator` from the opposite direction (it **reads** an already-produced CI run rather than running the suite). **Two spawn scenarios:** (a) a **direct user request** — via the `/xtty:investigate-ci` launcher (`.claude/commands/xtty/investigate-ci.md`) or plain natural language; (b) **apply-loop delegation** — a task that *investigates a failed CI run* is delegated to `xtty-ci-investigator`, and the apply loop consumes only its report, ticking the task with the report's verbatim verdict/classification. **The delegation boundary (watch vs investigate):** *watching* CI — following a run or reading its status (`gh run watch`, `gh run view`) — stays **inline**; *investigating a red run* — pulling logs/`.xcresult`/attachments to classify the failures — is **delegated**. **Carry the trigger into the task:** a delegate-set task in any `tasks.md` MUST be authored with the marker **`⟶ xtty-ci-investigator (<run>)`** in the task line (same point-of-tick reasoning as the validator — `/opsx:apply` reads the marker, not this rule). **Deference chain, both directions:** the agent defers to this file (AGENTS.md) for the rules above and to `research/03-analysis/github-actions-ci-cd.md` **§19 (the CI expected-difference matrix)** for the known-benign buckets + the required-gate/non-blocking job map — it never hardcodes them. The reverse duty: any change that adds/removes a test, fixes a known-benign residual, or changes a job's gate status MUST update §19 in the same session, or the agent's "runtime read" just relocates the staleness. The agent is **observe-and-classify only** (never edits code or re-runs/cancels CI) and, being short and read-only (`gh`/`xcrun`, no VM), needs **no babysitter/strand-recovery** — only the same `Definition: <version>` stamp + delivery check.
- **OpenSpec-change coherence review is delegated to the `xtty-openspec-critic` agent, not run inline.** A full coherence review floods the session with rule-by-rule grepping, `openspec/specs` diffing for MODIFIED blocks, disk-drift derivation, and cross-change comparison — so it's a committed **agent** (`.claude/agents/xtty-openspec-critic.md`) that returns only a fixed findings verdict, the third `xtty-*` family member. **Two spawn scenarios:** (a) a **direct user request** — via the `/xtty:review` launcher (`.claude/commands/xtty/review.md`) or plain natural language; (b) **apply/propose-loop delegation** — a task that *reviews a change for coherence* is delegated to `xtty-openspec-critic`, and the loop consumes only its report, ticking the task with the report's verbatim findings/verdict. **The delegation boundary (validate vs review):** running **`openspec validate`** — the cheap mechanical pass/fail gate — stays **inline**; a **full coherence review** (the "Keeping a change coherent" rules + disk-drift + the cross-change pass) is **delegated**. **Carry the trigger into the task:** a delegate-set task in any `tasks.md` MUST be authored with the marker **`⟶ xtty-openspec-critic (<change|all>)`** in the task line (same point-of-tick reasoning — the loop reads the marker, not this rule). Recommended trigger points: **post-propose** (is the new change coherent?) and **pre-archive** (still coherent after implementation?). **Deference chain, both directions:** the agent defers to this file (AGENTS.md) — the **"Keeping a change coherent"** subsection + the **spec-delta format** rules — as the single source of truth for the coherence *rules*, and to the **live repository state** (`openspec list`, `ls openspec/specs/`, the change dirs, the trackers) as the ground truth for *drift* — it never hardcodes the rule set, and a rule it can't mechanically check it flags for human review rather than dropping. The reverse duty: a change to the coherence rulebook here SHOULD prompt updating the agent's operationalization (else the un-checkable rule surfaces as a REVIEW flag). The agent is **observe-and-report only** (never edits any artifact/spec/tracker/code) and, being short and read-only (`openspec`/`git`/`grep`, no VM), needs **no babysitter/strand-recovery** — only the same `Definition: <version>` stamp + delivery check. It is the first `xtty-*` agent with a **change-set-aware** pass (shared requirements, archive-ordering, red→green pairs — computed on demand, never cached).

## OpenSpec workflow

We do **spec-driven development**: formalize *what* changes as reviewable artifacts, approve, then implement. Don't write feature code straight from a chat prompt — capture it as a change first.

**The loop** (one change per milestone from `research/04-design/02-milestones.md`):

```
explore ──▶ propose ──▶ apply ──▶ archive
(think)    (artifacts) (implement) (merge into specs/)
```

**Slash commands** (preferred entry points):
- `/opsx:explore <topic>` — thinking/investigation mode. **Never implements**; may read code/clone OSS to `/tmp` for understanding and may create OpenSpec artifacts. Use it before committing to an approach.
- `/opsx:propose <name>` — create a change and generate all artifacts (`proposal.md` → `design.md` + `specs/` → `tasks.md`).
- `/opsx:apply` — implement a proposed change by walking its `tasks.md` checkboxes. This is where real code gets written.

**Underlying CLI** (`openspec`, v1.4.x):
- `openspec list` — active changes · `openspec list --specs` — established specs
- `openspec new change "<name>"` — scaffold a change
- `openspec status --change "<name>" [--json]` — artifact build order & paths
- `openspec instructions <artifact> --change "<name>" --json` — template + rules for an artifact (follow these; do NOT copy the `context`/`rules` blocks into the file)
- `openspec validate "<name>"` — validate before committing
- `openspec archive "<name>"` — on completion, merge spec deltas into `openspec/specs/`

**Artifact order & dependencies:** `proposal` → (`design` + `specs`) → `tasks`. `tasks` is the apply gate.

**Spec delta format** (in `changes/<name>/specs/<capability>/spec.md`):
- Use `## ADDED Requirements` / `## MODIFIED Requirements` / `## REMOVED Requirements`.
- `### Requirement: <name>` with **SHALL/MUST** (avoid should/may); every requirement needs ≥1 scenario.
- `#### Scenario: <name>` with **WHEN/THEN** — scenarios MUST use exactly **4 hashtags** (3 fails silently).

**Keeping a change coherent — what to update when a requirement changes.** The four artifacts are a dependency chain (`proposal → design + specs → tasks`), so a requirement edit rarely lives alone. When you add/modify/remove a requirement in `changes/<name>/specs/`, walk this list, then run `openspec validate "<name>"` (it catches missing deltas/scenarios):
- **`proposal.md` → Capabilities** is the contract with `specs/`: every capability a spec delta touches MUST appear under **New** or **Modified Capabilities** (and vice-versa — no orphan spec dir, no listed-but-absent capability). Refresh **What Changes** / **Impact** if scope moved.
- **`specs/<capability>/spec.md`** — keep requirements **mechanism-neutral (the *what*)**; the *how* (fork vs seam, file/type names, concrete APIs) belongs in `design.md`, never inside a requirement. A **MODIFIED** requirement MUST paste the **entire** existing block from `openspec/specs/<capability>/spec.md` and edit it (partial content silently loses detail at archive). A behavioral change usually spans **multiple capabilities** — e.g. a new keybind action also touches `terminal-keybindings`; a new config key touches `terminal-configuration`.
- **`verification-harness` (almost always, in this repo)** — the custom-drawn view exposes nothing to accessibility, so any **new observable behavior** needs *both* a `verification-harness` spec delta (a new DEBUG state-dump field/observation + an e2e scenario) **and** a harness task. 19 of the 34 archived changes carried a harness delta for exactly this reason — if the harness can't see it, it isn't done.
- **`design.md`** — re-check that decisions and requirements still justify each other *both ways*: a changed decision can leave a requirement over-/under-specified (neutralize it — e.g. drop a hard-coded mechanism), and a new requirement may need a decision plus a Risks / Migration / Open-Questions update.
- **`tasks.md`** — every requirement needs build **and** verify tasks; add or re-order them when requirements change (and split deferred work into its own task group rather than blurring scope). Any verify task that runs the **Tier-1 XCUITest suite (`make test`), a VM tier, or a full acceptance matrix** MUST carry the delegation marker `⟶ xtty-test-validator (<tier/scope>)` (see the test-validation rule in *How to work here* for the inline-vs-delegate boundary); cheap checks stay unmarked.
- **`research/`** — the *why* stays in `research/` (update the relevant doc **and** its `research/README.md` line when a decision/finding shifts); the actionable *decision* stays in the change. Trackers (AGENTS **Current status**, the milestone state) are updated on completion per **Keep progress current**.

**Lifecycle rule:** `openspec/specs/` is the source of truth and only grows via `openspec archive` after a change is implemented. In-flight work lives in `openspec/changes/<name>/`. Commit proposal artifacts as `docs(openspec): …`; commit the implementation under the relevant `feat`/`chore` scope.

**After archiving, finish the merge by hand:** `openspec archive` merges spec deltas mechanically, so check the result before committing — (1) fill in the `## Purpose` of any **newly-created** spec (archive stubs it with `TBD - … Update Purpose after archive.`); (2) make the merged requirement text reflect *what actually shipped*, not what the proposal guessed (specs record what is true — e.g. correct the delta if the implementation diverged); (3) `openspec validate --all --type spec` and skim the diff for collapsed blank lines. Then commit as `docs(openspec): archive …`.

## Conventions

- **Commits: [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/)** — `type(scope): description`. Types used so far: `docs` (research/design/openspec content), `feat`/`test` (implementation), `chore` (tooling). Scopes: `research`, `design`, `openspec`, `app`. End commit messages with the `Co-Authored-By` trailer when authored with an AI.
- **Research docs** carry a **Provenance** note (date + how produced) and a **Sources** list; fact-checked claims use ✅/❌/❓. Snapshots are dated and time-sensitive — re-verify versions/latency/pricing before quoting.
- **Engineering bias:** macOS-first; **reuse battle-tested components over hand-rolling** (especially the VT parser — use the Williams state machine via a library); favor **latency and low memory** in every tradeoff.
- **Don't track local tooling:** `.claude/` is gitignored — **except** the committed project tooling `.claude/commands/xtty/` + `.claude/skills/xtty-*/` + `.claude/agents/xtty-*` (the `/xtty:capture-research` command + the `xtty-capture-research` skill + the `xtty-test-validator` agent + its `/xtty:validate` launcher command + the `xtty-ci-investigator` agent + its `/xtty:investigate-ci` launcher command + the `xtty-openspec-critic` agent + its `/xtty:review` launcher command), which are version-controlled. Machine-local Claude files (`settings.local.json`, locks) and the openspec-generated `opsx`/`openspec-*` tooling stay ignored.

## Key references

- Development history / per-change narratives: [HISTORY.md](HISTORY.md)
- Requirements: `research/03-analysis/xtty-requirements.md`
- Stack & alternatives: `research/04-design/01-stack-sketch.md`
- Build plan: `research/04-design/02-milestones.md`
- Agent strategy: `research/03-analysis/agents-and-xtty.md`
- Internals deep-dives: `research/02-internals/`
