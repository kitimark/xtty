# SwiftUI main-menu clobber — source-level forensics: the machinery, live attribution, and fix-candidate verdicts

> **Provenance:** 2026-07-05. Produced by a 6-agent forensics workflow — five parallel investigators (SDK + framework-binary forensics; live lldb attribution on the real xtty Debug build; Ghostty/CodeEdit prior-art clones; web + OpenSwiftUI sweep; xtty migration-surface map) plus an **adversarial verifier** that re-read the raw artifacts and resolved two inter-investigator contradictions. Host: macOS 26.2 (25C56), Xcode 26.6, Apple Silicon. This doc **names the machinery** behind the clobber that [`local-macos-vm-ci-reproduction.md`](local-macos-vm-ci-reproduction.md) §8/§9 proved black-box (in-place item mutation, per-launch race) and settles the `fix-main-menu-clobber` design that [`github-actions-ci-cd.md`](github-actions-ci-cd.md) §15e sketched. Evidence bundle: `~/Downloads/xtty-vm-poc/artifacts/menu-clobber-source-forensics/` (41 files; see §9).

**Question:** which code inside SwiftUI clobbers `NSApp.mainMenu`, what triggers it and when, and which fix candidates survive contact with the actual mechanism?

**Headline:**
- ✅ **Mechanism named and confirmed** (4 independent evidence classes): `SwiftUI.AppDelegate.makeMainMenu(updateImmediately:)` → `AppKitMainMenuItem.updateMainMenu(to:…)` — an identifier-keyed reconciler that **mutates the installed `NSMenu`'s items in place**; `-[NSApplication setMainMenu:]` fires only on first install.
- ✅ **Reproduced deterministically on bare metal** (no VM needed) by synthetically re-firing the trigger — identical signature to the CI/VM clobber, including the Help menu xtty never builds.
- ✅ **`NSApplicationMain` is the correct fix by construction**: every mutating frame lives on `SwiftUI.AppDelegate`, which exists only when SwiftUI's `App` bootstrap runs. Ghostty is 3 years of shipping precedent for exactly this migration.
- ❌ **`.commandsRemoved()` refuted live** (probe5): the reconciler still strips all custom items.
- ❌ **Rebuild-menu-on-notification refuted live** (probe6): the next pass clobbers the fresh menu in place again — whack-a-mole by mechanism; and the trigger isn't `didBecomeActive` anyway.
- ❓ The **natural** second-pass trigger on slow VMs is `scenesDidChange(phaseChanged:)` **by elimination** (only two static call sites exist) — never observed live on bare metal; all bare-metal reproductions used the synthetic trigger. Immaterial to the fix (both call sites die with `SwiftUI.AppDelegate`).

---

## 1. The machinery (what CI and the VM rigs could never show)

Under `@main struct XttyApp: App`, the **real** `NSApp.delegate` is SwiftUI's private `SwiftUI.AppDelegate` — xtty's `AppDelegate` via `@NSApplicationDelegateAdaptor` is only a *forwarding target* (proven by lldb frames: the adaptor's `applicationDidFinishLaunching` is called *by* `SwiftUI.AppDelegate.applicationDidFinishLaunching`, frame #4 in the backtraces; OpenSwiftUI's audited reimplementation shows the same architecture, down to a `forwardingTarget` for unhandled selectors).

```
SwiftUI.AppDelegate  (the REAL NSApp.delegate; ours is only forwarded-to)
  ├─ call site 1: applicationWillFinishLaunching(_:)      — synchronous, at launch
  └─ call site 2: scenesDidChange(phaseChanged:)          — deferred, scene-phase-driven
        │            (the ONLY two `bl` sites to makeMainMenu in the whole binary)
        ▼
  makeMainMenu(updateImmediately:)
        ▼
  static AppKitMainMenuItem.updateMainMenu(to:windowsController:environment:
                    focusedValues:focusStore:updateImmediately:testAppGraph:)
        │   items resolved by SwiftUI._ResolvedCommands.mainMenuItems(env:)
        ▼
  menu = NSApp.mainMenu ?? NSMenu()          ← adopts OUR installed menu object
  setMainMenu: ONLY if target ≠ current      ← cmp/b.eq at +1960 skips it → pointer never swaps
  CollectionChanges diff keyed on MainMenuItem.Identifier:
     · NSMenu.findMainMenuItem(id:) recognizes ONLY SwiftUI's AppKitMainMenuItem class
       → plain NSMenuItems (all of xtty's) NEVER match
     → every custom item removed   (-[NSMenu removeItemAtIndex:], partly via PruneTrivialFileMenu)
     → SwiftUI defaults inserted   (-[NSMenu insertItem:atIndex:]; submenus via setItemArray:)
```

This explains **every** prior black-box observation exactly:

| Observation (VM/CI, §8d) | Mechanism |
| --- | --- |
| `mainMenuPtr == builtMenuPtr` through a 100 % clobber | `menu = NSApp.mainMenu ?? NSMenu()` + the `b.eq` skip: re-runs never call `setMainMenu:` |
| Items become `[xtty, Edit, View, Window, Help]` — a **Help** menu xtty never creates | SwiftUI's default resolved-commands set, inserted as `AppKitMainMenuItem` instances |
| No **File** menu in the clobbered bar | `PruneTrivialFileMenu.apply(to:appGraph:)` → `removeItemAtIndex:1` |
| Identity-based canary read healthy through the clobber | The reconciler mutates *content*, never *identity* — identity sensors are structurally blind |

Supporting private types (for future symbol hunts): `MainMenuItem` (+`.Identifier`/`.Content`), `AppKitMainMenuItem: NSMenuItem` (ivars `id`/`dynamicSubmenu`/`menuHost`/`menuContentsAreInvalid`), `MainMenuItemHost` (a per-item ViewGraph host), `SwiftUIMenu: NSMenu`, `SwiftUIMenuItem: NSMenuItem`, `MainMenuNavigationBridge`, `AppKitMainMenuEffects`, `PruneTrivialFileMenu`. There is **no separate SwiftUI–AppKit glue framework**: SwiftUI.framework weak-links AppKit and contains the whole bridge. AppKit itself never synthesizes an app menu — at `finishLaunching` it only *adds text-input items to an existing one* (`-[NSApplication(NSMenuUpdating) _customizeMainMenu]`).

## 2. The launch timeline and the race, precisely

✅ **Pass 1 cannot clobber.** SwiftUI's initial install is a **synchronous** `NSApplicationWillFinishLaunchingNotification` observer callout inside `-[NSApplication finishLaunching]` — it strictly precedes xtty's `applicationDidFinishLaunching` assignment (`App/XttyApp.swift:58` visible in-stack). At that point `mainMenu` is nil, so SwiftUI allocs a fresh `NSMenu`, `setMainMenu:`s it, populates it (this is the *only* `setMainMenu:` call), and prunes File.

✅ **On fast bare metal, exactly one pass fires per launch.** Measured: no re-fire across ~20 s idle and 3× Finder/xtty activation churn (run4/run6 hit counts). So locally "xtty wins the race" because **no SwiftUI pass ever runs after `XttyApp.swift:58`** — not because xtty out-races anything.

❓ **The VM/CI clobber is therefore a second, deferred pass.** By elimination it is `scenesDidChange(phaseChanged:)` — the binary has exactly two call sites into `makeMainMenu`, and the first provably can't clobber. Disassembly ties `scenesDidChange` to `SwiftUI.AppKitWindowController.scenePhase.didSet` (plausibly fired by XCUITest activating the freshly launched app on a slow 3-vCPU guest, landing *after* xtty's assignment). **Not observed live**: a window-less unbundled probe's activation did not fire it (probe3), so the exact runtime condition remains open. This is the one honest gap — and it is immaterial to the fix, because `NSApplicationMain` removes the owner of *both* call sites.

❌ **Community timing claims corrected for our shape:** widely-cited posts (Steipete 2021, curmi) say the menu installs "async, after `applicationDidFinishLaunching` — skip a runloop". Measured false for xtty's Settings-only scene on macOS 26.2: the install is synchronous in `willFinishLaunching`. Those accounts are WindowGroup apps on older SwiftUI; at best they corroborate the *existence of later update passes* (the part that matters).

## 3. Fix-candidate fates table

| Candidate | Fate | The experiment/evidence that settled it |
| --- | --- | --- |
| **(a) `NSApplicationMain`** — drop the SwiftUI App lifecycle | ✅ **RECOMMENDED** — eliminates the mutator by construction | Both `makeMainMenu` call sites are methods of `SwiftUI.AppDelegate`, installed only by `SwiftUI.runApp` under `App.main`; merely *linking* SwiftUI (NSHostingView) does **not** instantiate it (probe check). Ghostty shipped exactly this migration in 2023 and has run it since (§5). Final proof = post-migration VM runs (§7). |
| Stage-A: re-assert the same built instance | ❌ (was already refuted §8d; now *explained*) | The `b.eq` skip means SwiftUI never swaps the pointer on a later pass — it rewrites items inside the installed object; asserting an identical pointer is a no-op by instruction-level construction. |
| **(b) `.commandsRemoved()`** on the Settings scene | ❌ **REFUTED live** | probe5 (source verified: exactly `Settings { EmptyView() }.commandsRemoved()`): the reconciler still runs and still strips ALL custom items in place, leaving a lone synthesized View menu. Matches the documented semantics — it removes commands *defined by that scene*, not the synthesis machinery. |
| **(c) Rebuild-and-reinstall on a notification** (`didBecomeActive`, KVO) | ❌ **REFUTED live** as durable | probe6: a FRESH menu fully restores — then the next synthesis pass mutates the *new* object in place (whack-a-mole). run6: activation does **not** fire the SwiftUI pass, so `didBecomeActive` re-asserts at the wrong moments. Ghostty's deleted `CursedMenuManager` ("truly cursed… quite brittle") is the field record of this arms race. |
| **(d) SwiftUI `Commands` ownership** (keep lifecycle, SwiftUI owns the menu) | ⚠️ viable **second choice** only | The only *supported* single-owner model in-lifecycle (SDK sweep found **no** synthesis-suppression API). CodeEdit ships it — at the cost of swizzling `NSMenuItem.keyEquivalentModifierMask` to clean up SwiftUI's synthesized junk, plus restructuring all menu logic (xtty: configurable keybindings, dynamic profile submenu, DEBUG menu) into Commands. |
| Community claim: "menu installs async after ADFL" | ❌ for our shape | Measured synchronous `willFinishLaunching` install (§2). |
| Premise check: "Christian Tietze documented this clobber" | ❌ | His blog has no such post (full index checked). His actual relevance: Ghostty's migration commit cites his 2019 NSWindow-tabbing post as the design basis for the AppKit *destination*. |

## 4. Reproducible probes (P1–P8) — what each proves, and cannot prove

All artifacts referenced below live in the evidence bundle (§9). OS-build-specific: symbol names/offsets verified on macOS 26.2 (25C56); re-run P2 after an OS update before trusting offsets.

- **P1 — extract the real SwiftUI binary from the dyld shared cache.** Frameworks don't exist as on-disk Mach-Os on modern macOS. Working extractor: `/usr/lib/dsc_extractor.bundle`'s `dyld_shared_cache_extract_dylibs_progress` driven by a ~20-line C shim (`extract.c` in the bundle), against `/System/Volumes/Preboot/Cryptexes/OS/System/Library/dyld/dyld_shared_cache_arm64e`. Proves: nothing by itself; enables P2/P4. The extracted dylibs (121 MB) were **not** copied to the bundle — re-extract with `extract.c`.
- **P2 — symbol hunt.** `nm` the extracted binary + `swift demangle`; grep `MainMenu|makeMainMenu|updateMainMenu`. **Local (non-exported) Swift symbols ARE present** in dsc-extracted binaries — this is what named `makeMainMenu`'s private discriminator (`…33_CD9513E1DBF2FF41775224EE6D5A7974LL…`). Output: `swiftui-mainmenu-syms{,-raw}.txt`, `{swiftui,swiftuicore,appkit}-exports.txt`. Proves the machinery's *names*; cannot prove behavior.
- **P3 — runtime ObjC enumeration** (`objc-menu-enum.m`): `dlopen` SwiftUI + `objc_copyClassNamesForImage` + method dumps → `objc-menu-classes.txt` (the `AppKitMainMenuItem` ivars/delegate methods). Used **because the static instrument is dead** (see Dead instruments).
- **P4 — disassembly anchor.** `llvm-objdump` the extracted binary; decode `updateMainMenu` (`updateMainMenu-body.txt`, full text in `disasm-updateMainMenu.txt.gz`): the `mainMenu ?? NSMenu()` read at +1860–1876, the `cmp/b.eq` `setMainMenu:` skip at +1960–1988, the `CollectionChanges` diff at +3052, and the only two `bl makeMainMenu` sites. Proves the in-place/no-pointer-swap logic *statically*; offsets are OS-build-specific.
- **P5 — live lldb attribution on the real xtty Debug build.** Breakpoints by **mangled Swift name** (resolve fine on a live process even when static `image lookup` fails) + ObjC mutator selectors, auto-continue + `bt`. `run5.log` is the money capture: `NSApp.mainMenu` pointer `0xb7e305f00` identical before/after while its 6 plain items became 5 `SwiftUI.AppKitMainMenuItem` (xtty/Edit/View/Window/Help) — byte-for-byte the CI clobber signature. Command files `menu-bp*.lldb`. Proves attribution + same-object mutation *dynamically, on the shipping app*.
- **P6 — deterministic bare-metal reproduction (synthetic trigger).** With the custom menu installed, re-post `NSApplication.willFinishLaunchingNotification` → AppKit's delegate-notification wiring re-invokes `SwiftUI.AppDelegate.applicationWillFinishLaunching` → the full clobber, same pointer (probe4/probe6 runs; reconfirmed ×3). Proves the code path end-to-end without a VM. **Cannot prove** the *natural* trigger identity (§2 ❓) — the trigger is synthetic by design.
- **P7 — fix-candidate probe apps** (`probe.swift`…`probe6.swift`): minimal Settings-scene SwiftUI-lifecycle apps; probe5 = the `.commandsRemoved()` arm (❌), probe6 = the rebuild-and-reinstall arm (❌ whack-a-mole). Each ~2 KB source, compiles with `swiftc`.
- **P8 — trigger-absence observation** (run4/run6): 20 s idle + 3× activation churn on bare metal → zero re-fires. Proves "one pass per launch" locally; cannot prove VM scheduling.

**Dead instruments** (record them so nobody re-burns time):
- ❌ `dyld_info -objc` on shared-cache dylibs — prints "cannot print live objc info"; use P3 instead.
- ❌ lldb `image lookup` against the cache image — unreliable for these symbols; breakpoint-by-mangled-name on a live process works.
- ❌ Pointer-identity menu canary (`menuIsBuiltInstance`/`menuClobberCount`) — read healthy through a 100 % clobber (§8d); content (titles) is the only valid sensor.
- ❌ Activating a window-less unbundled probe to fire `scenesDidChange` naturally (probe3) — didn't fire; the natural second pass stays unreproduced on bare metal.

## 5. Prior art and the ecosystem record

- **Ghostty fought this exact bug and chose the same fix (2023).** Pre-migration `GhosttyApp.swift` contains `CursedMenuManager` — KVO on **both** the `NSApp.mainMenu` pointer **and** the File submenu's `items` (independent 2023 corroboration of in-place item mutation). The migration commit `850bf3e9` (2023-06-30) added a top-level-code `main.swift` calling `NSApplicationMain`, `MainMenu.xib` (`NSMainNibFile`), and **deleted** the cursed manager; the stated trigger was SwiftUI lifecycle blocking custom `NSWindow` classes, with the menu escape called out as a benefit (devlog 002). Architecture persists to HEAD (2026-07-04). Crucially for xtty: Ghostty's **primary terminal window content is a SwiftUI view in an `NSHostingView`** — the AppKit-lifecycle + SwiftUI-views hybrid is proven at scale. Saved: `ghostty-pre-migration-GhosttyApp.swift`, `ghostty-migration-commit-850bf3e94.patch`, `ghostty-prior-art-evidence.md`.
- **CodeEdit** ships candidate (d) — SwiftUI lifecycle + Commands ownership — and pays for it with ObjC swizzling (`CommandsFixes.swift`: `NSMenuItem.keyEquivalentModifierMask` setter swizzle to neutralize SwiftUI's synthesized items).
- **OpenSwiftUI** (the closest readable "source", audited against real SwiftUI 6.5.4) corroborates the architecture: SwiftUI's own delegate owns the app + menus; the adaptor delegate is a forwarding target; menu updates are graph-update-driven (`commandsListVersion: DisplayList.Version`); init enables the private `NSMenu._setAlwaysCallDelegateBeforeSidebandUpdaters(true)` SPI. Cross-check: OpenSwiftUI's file-ID for the AppKit delegate matches the `CD9513E1…` discriminator in the real binary's `makeMainMenu` symbol.
- **`swiftlang/swift` contains none of this** (honesty check, gh code search: `mainMenu`/`NSApplicationDelegateAdaptor` zero hits outside test fixtures). The implementation lives in the closed-source SwiftUI/AppKit binaries — which is why P1–P5 read binaries, runtimes, and reimplementations instead.
- **No public API disables main-menu synthesis** under the SwiftUI lifecycle (full SDK 26.x swiftinterface sweep): `commands` (macOS 11+), `commandsRemoved`/`commandsReplaced` (macOS 13+) exist but are command-set-scoped; Apple Forums thread 740591 documents the removal gaps.

## 6. Consequences for `fix-main-menu-clobber`

The migration surface is **one construct** (verified file-by-file):

1. Delete `App/XttyApp.swift:15-24` (the `@main` `XttyApp` struct; nothing references the Settings scene — no SettingsLink/openSettings/Cmd+, anywhere) and its now-unused `import SwiftUI` (line 1). `AppDelegate` stays byte-identical.
2. New `App/main.swift`: `let delegate = AppDelegate(); NSApplication.shared.delegate = delegate; _ = NSApplicationMain(CommandLine.argc, CommandLine.argv)`. The top-level `let` provides the strong retention `@NSApplicationDelegateAdaptor` used to supply (`NSApplication.delegate` is weak). Swift 6 note: top-level code is MainActor-isolated (SE-0343), so constructing the `@MainActor` delegate compiles; a `@main` type instead would need `@MainActor static func main()`.
3. `xcodegen generate` — `project.yml` already sets `INFOPLIST_KEY_NSPrincipalClass: NSApplication` and the `App/` source glob picks up `main.swift`; no functional project change (one stale comment at project.yml:55-56).
4. Recommended rider: implement `applicationSupportsSecureRestorableState → true` (we lose SwiftUI's delegate-proxy defaults; without it, pure-AppKit runs log the secure-restorable-state warning — cosmetic).

Everything else — `MainMenu.swift`, all `NSHostingView` embeddings (sidebar `TerminalWindowController.swift:213`, git review `:218` — plain `@State`/`TimelineView`/`@Observable`, no App/Scene dependency), quick-terminal Carbon hotkey, DEBUG dump timer, benchmark mode, every launch-arg/env-trigger in the harness — is lifecycle-agnostic and untouched.

**Validation protocol (pre-registered):** bare-metal green proves nothing (§2 — the second pass never fires locally). Acceptance = `make build` on the spike (settles the Swift-6 question immediately), then the **full XCUITest suite at least twice** in the Tart rig `xtty-verify2` (3 vCPU, the environment that loses the race ~100 %), expecting the 7 menu-dispatch failures to flip green in **both** runs; menu canary compares **titles** (§4 dead instruments). The §15e/§15f harness-truthing items and second-order matrix in [`github-actions-ci-cd.md`](github-actions-ci-cd.md) stand unchanged, with one amendment: **the "second choice if `NSApplicationMain` regresses" is now the Commands API (d), not rebuild-on-notification (c)** — (c) is refuted (§3).

## 7. Re-verify by effect

- **Headline claim (the machinery + fix):** on a post-migration build, `lldb -o 'run' -o 'expr -l objc -- (Class)[[NSApp delegate] class]'` must print xtty's `AppDelegate`, **not** `SwiftUI.AppDelegate`; a breakpoint on the `makeMainMenu` mangled name must fail to resolve any live code path (the class never instantiates). Then the effect that matters: the P6 synthetic trigger against the fixed build must leave the menu intact, and the VM protocol in §6 must go green twice.
  - ✅ **Done 2026-07-05 (`fix-main-menu-clobber` applied):** the delegate-class check printed **`xtty.AppDelegate`**; the VM protocol measured **40/1/1 three times** (headless ×2 + graphics) on the ~100%-clobber rig, all 7 menu-dispatch tests flipped, the menu canary present every launch. The one residual is a bash-3.2 bracketed-paste rig artifact, not the fix. Full result: [`github-actions-ci-cd.md`](github-actions-ci-cd.md) §18 + `~/Downloads/xtty-vm-poc/artifacts/fix-main-menu-clobber-verify/`.
- **Mechanism claims on a future macOS:** re-run P2 (symbol hunt) first — Apple renames private symbols; if `makeMainMenu`/`updateMainMenu` vanish, re-anchor via P3 (runtime class enumeration) before trusting any offset in §1.
- **Fates-table claims:** each ❌ row names its probe; re-run the probe (P7 sources compile standalone with `swiftc`).

## 8. Reusable guideline — closed-source-framework forensics (F1–F7)

Complements the privacy-subsystem guideline G1–G10 in [`local-network-privacy-forensics.md`](local-network-privacy-forensics.md); use this set when the suspect is Apple framework *behavior* rather than a policy daemon.

- **F1.** For closed-source Apple behavior, **the framework binary is the source**: dsc-extract it (`dsc_extractor.bundle`) and read it with `nm`/`llvm-objdump` — local Swift symbol names survive in the extracted Mach-O.
- **F2.** Know the dead static instruments: `dyld_info -objc` can't read shared-cache ObjC metadata; use **runtime enumeration** (`dlopen` + `objc_copyClassNamesForImage`) instead.
- **F3.** **Attribute by live breakpoint backtrace on mangled names** — lldb resolves private Swift symbols on a live process even when static lookup fails; auto-continue + `bt` turns a race into a log.
- **F4.** When behavior is machine-speed-dependent, **find the trigger's call sites statically, then re-fire the trigger synthetically** to get a deterministic reproduction on fast hardware — and mark synthetic-vs-natural honestly in the capture (our one ❓).
- **F5.** Reconciler-style frameworks **mutate content in place** — identity/pointer sensors lie; assert on *content* (titles, counts).
- **F6.** Weigh community timing claims against a measured trace for **your app shape on your OS** — WindowGroup-app folklore did not survive contact with a Settings-only scene on macOS 26.
- **F7.** Check prior art's **git history, not just HEAD** — Ghostty's `CursedMenuManager` fight lives only in a deleted file; HEAD shows a clean architecture and no trace of the war.

## Sources

- Binaries: `/System/Library/Frameworks/{SwiftUI,SwiftUICore,AppKit}.framework` via the dyld shared cache (`/System/Volumes/Preboot/Cryptexes/OS/System/Library/dyld/dyld_shared_cache_arm64e`, macOS 26.2/25C56), extracted with `/usr/lib/dsc_extractor.bundle`.
- SDK: `MacOSX.sdk/System/Library/Frameworks/SwiftUI.framework/Modules/SwiftUI.swiftmodule/arm64e-apple-macos.swiftinterface` (Xcode 26.6).
- Live runs: lldb batch against `build/Build/Products/Debug/xtty.app` (2026-07-05 Debug build) and the probe apps (`probe*.swift`).
- Ghostty: <https://github.com/ghostty-org/ghostty> (HEAD `8642142a`, 2026-07-04; migration commit `850bf3e9456c37b6ab61e2a1832908a5a736d977`); devlog <https://mitchellh.com/writing/ghostty-devlog-002>.
- CodeEdit: <https://github.com/CodeEditApp/CodeEdit> (`CodeEditApp.swift`, `Features/WindowCommands/Utils/CommandsFixes.swift`).
- OpenSwiftUI: <https://github.com/OpenSwiftUIProject/OpenSwiftUI> @ `a1ab0ace` (`AppKitApp.swift`, `AppKitAppDelegate.swift`, `Commands.swift`, `MainMenuItem.swift`).
- Apple docs/forums: `commandsRemoved()` documentation; "Building and customizing the menu bar with SwiftUI"; forums threads 740591, 667362.
- Community timing posts (corrected by measurement, §2): <https://steipete.me/posts/2021/top-level-menu-visibility-in-swiftui>, <https://curmi.com/swiftui-and-menu-bars/>.
- Honesty check: <https://github.com/swiftlang/swift> gh code search (zero relevant hits).

## 9. Evidence artifacts

`~/Downloads/xtty-vm-poc/artifacts/menu-clobber-source-forensics/` (41 files, ~49 MB):

- **Symbols/metadata:** `swiftui-mainmenu-syms{,-raw}.txt`, `{swiftui,swiftuicore,appkit}-exports.txt`, `objc-menu-classes.txt` (+ `objc-menu-enum.m` source), `lldb-swiftui-symtab.txt`.
- **Disassembly:** `updateMainMenu-body.txt` (annotated decode), `disasm-updateMainMenu.txt.gz` (full text, 43 MB).
- **lldb attribution:** `menu-bp*.lldb` command files; `run1..run6.log` — `run5.log` = the same-pointer clobber on the real xtty build; `run4/run6` = the no-re-fire observations; `lldb-probe.cmds` + `lldb-probe-run.txt` = the probe-app trace.
- **Probe apps:** `probe.swift` … `probe6.swift` + `probe*-run.txt` + `probe-baseline.txt` (probe5 = `.commandsRemoved()` ❌; probe6 = rebuild whack-a-mole ❌; probe4 = the first deterministic same-object clobber).
- **Prior art:** `ghostty-pre-migration-GhosttyApp.swift` (CursedMenuManager), `ghostty-migration-commit-850bf3e94.patch`, `ghostty-prior-art-evidence.md`, `hws-managing-menus.html`.
- **Tooling:** `extract.c` (the dsc-extraction shim — the 121 MB extracted dylibs are not stored; re-extract with it).
