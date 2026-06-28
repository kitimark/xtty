# SwiftTerm fork vs patch-in-repo — how to add the P4b-2 accessors without a fork repo

> **Provenance:** Drafted 2026-06-28 during the `add-spatial-blocks` (P4b-2) proposal work, after the user asked whether a Playwright-style in-repo **patch** could replace maintaining a separate SwiftTerm **fork** repo. Grounded in: a shallow sparse clone of `microsoft/playwright` (`browser_patches/`, read in `/tmp`), the SwiftTerm `v1.13.0` checkout's `Package.swift`, and xtty's `XttyCore/Package.swift` + `project.yml`. No code written. Settles the *mechanism* for injecting the 2 engine accessors that P4b-2's [spatial-blocks decisions](p4b-2-spatial-blocks-decisions.md) require.

> _Topic scope:_ P4b-2 needs two read-only accessors compiled **inside** SwiftTerm's module (`getScrollInvariantCursorLocation()` + `scrollbackBase`, reading `internal` `buffer.yBase`/`linesTop`). The original plan (design D1) was a revision-pinned GitHub fork. This doc evaluates a Playwright-style patch-in-repo alternative and the "defer via a shim" sequencing, so we can make progress without creating a fork repo now.

---

## Headline

A literal Playwright-style **patch-at-build does not map onto SwiftPM** (SPM owns the dependency checkout; there is no patch hook in a vanilla `xcodebuild`/`swift build`). But the *spirit* — pin upstream, keep the change in-repo, no fork repo — **does** map, via a **local-path SPM dependency** (git submodule or vendored copy). And because our change is **add-only (one new file, zero edits to existing SwiftTerm files)**, the "patch" degenerates from a fragile diff to "drop in one source file." Separately, the **best-effort/optional-anchor design lets us defer the whole mechanism**: build the feature now against an **injectable accessor seam**, fake-test the happy path, and light it up later as a ~2-line production swap.

---

## What Playwright actually does (the model the user referenced)

```
browser_patches/firefox/
├── UPSTREAM_CONFIG.sh     REMOTE_URL + BASE_REVISION   ← pins upstream to ONE commit
└── patches/bootstrap.diff one big `git diff` (108 KB) of all Playwright's changes
```

Lifecycle (Playwright's own CI): **clone upstream @ `BASE_REVISION` → `git apply bootstrap.diff` → compile from source → ship the prebuilt binary.** `roll_from_upstream.sh` rsyncs the patch set from an internal mirror; an export step regenerates the `.diff` from a modified checkout.

✅ **Why it works for them:** Playwright *owns the entire build pipeline* — it does the clone, the patch, and the compile itself, then distributes binaries. The patch has a place to live because Playwright controls the clone→patch→compile sequence.

---

## Why it doesn't drop straight onto SwiftTerm + SwiftPM

❌ **SwiftPM owns the checkout, not us.** With `.package(url:…)`, SPM clones SwiftTerm into `.build/checkouts` / DerivedData and there is **no hook** (in `Package.swift` or a vanilla `xcodebuild`/`swift build`) to run "after resolve, `git apply`." Patching the SPM checkout in place is wiped on every clean/re-resolve. So the literal patch-at-build step has nowhere to live.

✅ **But the spirit maps,** because the real requirement is narrow: our file only needs to be **compiled inside SwiftTerm's module** (to reach `internal` `yBase`/`linesTop`). SPM's **local-path dependency** gives exactly that. Two enabling facts were verified:

- ✅ SwiftTerm's `SwiftTerm` target **globs** its sources (`path: "Sources/SwiftTerm"` + an `exclude:` list, **not** an allow-list) — so a dropped-in `XttyAccessors.swift` in `Sources/SwiftTerm/` compiles as part of the module. *(SwiftTerm `Package.swift:27-31, 72-92)*
- ✅ Only `XttyCore/Package.swift` names SwiftTerm; `project.yml` has **no** SwiftTerm entry (the App gets it transitively through the local `XttyCore` package). So switching to a local path touches **one line** in `XttyCore/Package.swift`. *(XttyCore/Package.swift:23; project.yml `packages:` has only `XttyCore`)*
- ✅ Our change is **add-only** (design D1 modifies no existing file) → the "patch" is a single standalone source file, **never a diff that can fail to apply** on an upstream bump.

---

## The options (all four avoid creating a fork repo except D)

| Option | How | Cost to build/consume | Avoids fork repo? |
|---|---|---|---|
| **A. Defer via an injectable shim** | Build tasks 2–8 against an injectable accessor seam (closure/protocol). Production returns `nil` → feature **no-ops gracefully** (the spec's degradation path). Tests inject a **fake** returning synthetic rows → **happy path tested now**. Pick B/C/D later as a ~2-line swap. | trivial now; a short integration + real-zsh pass at light-up | ✅ (decide later) |
| **B. Submodule + drop-in file** *(Playwright analog)* | `external/SwiftTerm` submodule pinned to v1.13.0 (pristine) + `XttyAccessors.swift` in xtty + a prepare step copies it into `Sources/SwiftTerm/`; `XttyCore/Package.swift` → `.package(path: "../external/SwiftTerm")` | needs `submodule update --init` + prepare step before build; regen xcodeproj after — **non-hermetic** | ✅ |
| **C. Vendor in-tree** | Commit SwiftTerm v1.13.0 source into `vendor/SwiftTerm/` + add the file + local path dep | hermetic, `swift build` just works | ✅ but ~100+ files committed; manual re-vendor on upgrade |
| **D. Fork** *(original D1)* | revision-pinned `kitimark/SwiftTerm` | lowest — `swift package resolve` just works, Xcode-native | ❌ (the thing being avoided) |

**B is the faithful SwiftPM translation of Playwright's link:** upstream stays a clean pinned ref, the modification lives in *our* repo as a reviewable artifact, a script reconstitutes the patched build. Honest tradeoff vs a fork: the build is **non-hermetic** — every clone/CI needs submodule-init + the prepare step, and the gitignored xcodeproj must be regenerated once the submodule is present.

---

## The "defer via shim" confidence analysis (the load-bearing nuance)

The seam funnels the entire fork dependency through **two reads of plain `Int`s**, and everything downstream is fork-agnostic:

```
SwiftTerm engine ─(only fork-touching layer: PaneController)─> Int rows ─> XttyCore (pure; no SwiftTerm change)
  getScrollInvariantCursorLocation().row                        capture     anchors / invalidation / reverse-map / prev-next
  scrollbackBase                                                            all operate on Int
```

- ✅ XttyCore never calls the fork API — it receives captured `Int` rows, returns `Int` targets. `scrollTo`/`getText`/`getScrollInvariantLine` are already public. The only references to the missing symbols are a tiny bridge in `PaneController` (OSC-133 capture ~`:117-126` + the `liveTop`/`scrollbackBase` read). `liveTop` is derivable as `accessor#1.row − getCursorLocation().y` (public), so it rides on the one accessor.
- ✅ **The literal swap is ~2 function bodies in one file** (`nil` → the real read). High confidence (~95%) — the Int-only coupling leaves nowhere for hidden coupling to hide on the xtty side.

Two honest caveats that "one-line swap" otherwise hides:

- ⚠️ **The mechanism work is deferred, not eliminated.** The real bodies only *compile* once the symbols exist (fork/submodule/vendor in place). That step is the same effort whichever option is picked; the shim postpones it, it doesn't shrink it.
- ❌ **A pure-`nil` shim never exercises the happy path.** With `nil`, anchors are always absent → jump/copy always no-op → every green test is a *degradation* test. An off-by-one in the reverse-map or a wrong `Position` range would surface only at light-up.

**Mitigation that makes A genuinely safe — an injectable seam, not bare `nil`:**

- ✅ Make the accessor a **closure/protocol** dependency. **Production** returns `nil` today (graceful no-op), the real read post-fork. **Tests** inject a **fake** returning synthetic rows → exercise the **full happy path** (capture → invalidate → reverse-map → prev/next → jump/copy range) **today, without the fork**. The only thing the fork then changes is whether the real SwiftTerm accessor returns the number we expect — already verified by reading `Buffer.swift`/`Terminal.swift`.

**Calibrated confidence:**

| Claim | Confidence |
|---|---|
| xtty-side swap is ~2 lines, one file | ~95% |
| "Whole feature done, no rework at light-up" — **pure-`nil` shim** | ~70% (unexercised happy path) |
| same — **injectable seam + fake-engine tests** | ~90% |
| Either way, budget a short integration + real-zsh validation pass at light-up | n/a (this is the honestly-remaining work, not zero) |

---

## Outcome (2026-06-28): Option B shipped

`add-spatial-blocks` Phase 2 lit this up with **Option B (submodule + drop-in)**: `external/SwiftTerm` pinned to `v1.13.0` (`8e7a1e1`), `patches/swiftterm/XttyAccessors.swift` dropped in by `scripts/bootstrap-swiftterm.sh`, and `XttyCore/Package.swift` switched to `.package(path: "../external/SwiftTerm")`. The `.gitmodules` carries `ignore = untracked` so the drop-in file doesn't dirty the parent tree; AGENTS **Building** documents the one-time bootstrap. The Phase-1 injectable seam meant light-up was a 2-line swap in `PaneController` (`engineScrollRow`/`engineScrollbackBase`); the real-injected-zsh happy-path e2e (jump + copy + scroll-invariance) went green on the first run. The upstream PR (the same accessor file) is **prepared but not yet filed** — filing needs a GitHub fork of SwiftTerm (the user's call). No fork repo was created.

## Recommendation

**A now (with the injectable seam, not bare `nil`); B when lighting it up** — if avoiding the fork repo remains the goal. The injectable seam de-risks the deferral to a ~2-line production swap + a bounded validation pass, lets ~80–90% of the feature land and be *really* tested today, and keeps the mechanism choice (B/C/D) reversible. The injectable seam is worth adding **regardless** of which mechanism is eventually chosen — it isolates the one place SwiftTerm internals leak in.

This supersedes design D1's "fork now" assumption for `add-spatial-blocks` (D1 + the Migration plan should be updated to the chosen path).

---

## Sources
- **Playwright** (shallow sparse clone, 2026-06-28) — `browser_patches/firefox/UPSTREAM_CONFIG.sh`, `browser_patches/firefox/patches/bootstrap.diff`, `browser_patches/roll_from_upstream.sh`.
- **SwiftTerm** `v1.13.0` (`8e7a1e1`) — `Package.swift` (target source globbing + `exclude:`).
- **xtty** — `XttyCore/Package.swift:23` (the SwiftTerm pin), `project.yml` (`packages:`), and the P4b-2 design (`openspec/changes/add-spatial-blocks/design.md`, D1 + Migration).
- **Prior decisions** — [P4b-2 spatial-blocks decisions](p4b-2-spatial-blocks-decisions.md) (the 2-accessor fork anatomy this injects), [P4 semantic-capture decisions](p4-semantic-capture-decisions.md).
