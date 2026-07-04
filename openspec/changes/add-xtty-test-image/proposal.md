# Proposal: add-xtty-test-image

## Why

The menu-clobber class of per-launch races reproduces in a resource-constrained local macOS VM but **not** on bare metal (`research/03-analysis/local-macos-vm-ci-reproduction.md` §8/§9: two rigs reproduced CI run `28472076179` exactly, and two runs of the identical VM + binary diverged, proving the race live) — so a local CI-parity VM rig is now a proven, load-bearing verification tool for xtty, not a curiosity. But the only rig that "just works" today is the prebuilt 87 GB `macos-tahoe-xcode` image, ~45–50 GB of which (iOS/watchOS/tvOS simulators, Android SDK, Flutter, multiple Xcodes) xtty never touches, and it is a one-off download, not reproducible from pinned inputs. §10/§11 established that a **~40 GB minimal image** — macOS base + Xcode with the macOS SDK only, no simulators, no Metal toolchain — is buildable the battle-tested cirruslabs way, and the owner decided (§11g, 2026-07-04) to make it a real repo artifact.

## What Changes

- **A reproducible, version-controlled image-build definition** for a minimal local macOS test-VM image capable of building xtty and running the **full** test suite including the XCUITests. Built from pinned inputs: a pinned OS base-image tag (inheriting the XCUITest session infrastructure — auto-login, automation mode, TCC grants — from the base layer) plus a pinned Xcode version (26.5 — CI parity with the `macos-26` hosted runner and the proven Tart rig; the lume rig reproduced the same results on Xcode 26.6, which strengthens version-insensitivity rather than parity).
- **Zero Apple credentials at image-build time**: Xcode is installed from a **pre-downloaded official Apple installer archive** (a one-time, human-gated, Apple-ID-authenticated download); the build itself never talks to Apple's auth. No simulator platforms are downloaded (the entire ~45 GB saving), and no Metal toolchain component is fetched (the deterministic Apple-catalog-rotation trap, §10c/§11d).
- **The guest is xtty-build-capable but generic**: the project generator (XcodeGen) is installed in-guest; **no xtty source is baked into the image** — the repo arrives at test time in a disposable clone of the golden image.
- **A documented runtime workflow**: clone the golden image per run, deploy the source, build + run the full suite in-guest, delete the clone; never build in the golden image.
- **A build-entry-point target** wrapping the image build, plus a maintenance/prerequisites doc and an AGENTS.md Building note.
- **Out of scope / deferred**: pushing the image to a registry (ghcr) — deferred until a second consumer exists (§10d); local image + copy-on-write clones only. Any CI-workflow change. Any product or test code change.
- **Hard dependency**: **`retire-metal-renderer` must be applied first** — the zero-Metal xtty build is what lets the image omit the Metal toolchain entirely. This change does not build without it. **Archive ordering (pre-registered):** its `build-workflow` delta — which MODIFIES the Prerequisite-check requirement to drop the Metal toolchain — must be **archived before or together with** this change's archive; archiving this change first would merge a `build-workflow` spec that simultaneously requires the Metal toolchain (doctor prerequisite) and asserts the image needs none.
- **Independent of `fix-main-menu-clobber`** (§11g decision 3): an in-guest full-suite run **before** the menu fix lands is *expected* to reproduce the race results — the known failing-test **set**, with counts net of `retire-metal-renderer`'s test deletion (33/7/1-ish of 41, possibly 35/5/1 — see design D9); image acceptance is **parity with the proven big-image rig**, not an all-green suite.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `build-workflow`: one ADDED requirement — the project provides a reproducible way to build a minimal local macOS VM test image (full suite incl. UI tests runnable in-guest; no simulators, no Metal toolchain; pinned inputs + a one-time human-provided Apple installer archive; no Apple credentials at build time).

No `verification-harness` delta: the image adds no new app-observable behavior — it runs the *existing* suite in a new environment (the `add-ci-pipeline` precedent: CI/tooling changes that only invoke existing tests carry no harness delta).

## Impact

- **New files**: an image-build template + a short README under a new top-level tooling directory (concrete layout in `design.md`).
- **`Makefile`**: one new target wrapping the image build (consistent with the make-wraps-everything idiom).
- **Docs**: AGENTS.md Building section gains the image workflow; prerequisites called out as human-gated one-time steps (image-builder tooling install; the Apple-ID-authenticated Xcode archive download; ~45+ GB free disk during the build).
- **No product code, no test code, no CI workflow, no app runtime behavior** is touched.
- **Dependencies**: hard on `retire-metal-renderer` (applied first, and its `build-workflow` delta archived before or together with this change's archive — see What Changes); none on `fix-main-menu-clobber` or `harden-churn-shell-readiness`.
