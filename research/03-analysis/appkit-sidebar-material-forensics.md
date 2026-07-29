# AppKit sidebar-material forensics — what `.listStyle(.sidebar)` actually paints in xtty

> **Provenance:** 2026-07-29. Screen-measurement session against the installed Release build (xtty 0.0.1 (500), `make install`, matching HEAD at measurement time), run to settle task 5.1 of `add-design-exploration-workflow` — the sidebar-material question that decides how mockup panels are painted. Measured on the built-in Retina display (3024×1964 @2x) with solid programmatic backdrops; an earlier same-day pass measured the black/white bracket on the primary external display. All patch samples are 200×200-px means with per-channel σ ≈ 0 unless noted.

**Sources:** `App/TerminalWindowController.swift:206-241` (panel hosting), `App/SessionSidebar.swift:113` and `App/GitReviewView.swift:130` (the two `.listStyle(.sidebar)` sites), `App/GitReviewView.swift:76-80` (the empty states), the capture set + fitting scripts under the measurement job dir (transient — reproduce from the probes below), `design/xtty-design-system/tokens.css` (the token file the finding corrects).

## Headline

✅ **`.listStyle(.sidebar)` engages a live behind-window vibrancy material even in a bare `NSHostingView`.** Both panels — the session sidebar and the git panel's file list — are hosted as plain `NSHostingView` children of an ordinary `NSView` with Auto Layout (`TerminalWindowController.swift:206-241`); no `NSSplitViewItem`, no sidebar behavior, no authored `NSVisualEffectView` anywhere in xtty. The material shows up anyway: the panel's rendered color tracks whatever sits on the desktop behind the window. The intuition "vibrancy requires `NSSplitViewItem` sidebar treatment" is refuted by measurement.

✅ **Both `.listStyle(.sidebar)` sites render identically** — every backdrop/activation combination measured the session sidebar and the git-panel List at exactly the same value.

✅ **Three distinct panel appearances exist, two of them opaque:**

| Surface | Behavior | Measured |
| --- | --- | --- |
| Sidebar/git List, **window active** | translucent, backdrop-dependent | ≈ base `#24252b` + ~18% of a saturation-boosted backdrop (table below) |
| Sidebar/git List, **window inactive** | **opaque**, backdrop-invariant | `#282a35` (40,42,53) on all four backdrops |
| Git panel **empty states** ("No changes", "Not a git repository") and the **titlebar** | **opaque**, backdrop- and activation-invariant | `#1f212c` (31,33,44) |

The empty states are not the List at all (`GitReviewView.swift:76-80` is a plain VStack), so what shows there is the window's own composited ground — which on macOS 26 darkAqua measures `#1f212c`, **not** the `#1e1e1e` the `windowBackgroundColor` catalog entry resolves to. The terminal pane is the opacity control: `(29.4, 31.0, 32.8) ± 0.5` (i.e. `#1d1f21` plus capture dither) in every single capture.

## The measurement matrix

Window active, both panels (values as captured; backdrop sampled in the same frame):

| Backdrop (captured) | Panel RGB | Naive-mix prediction | Residual |
| --- | --- | --- | --- |
| (0,0,0) | (36,37,43) | — fit anchor | — |
| (128,128,128) | (57,58,64) | (58.6, 59.6, 65.1) | (−1.6, −1.6, −1.1) |
| (255,255,255) | (81,82,87) | — fit anchor | — |
| (234,51,247) ← sRGB magenta after display compositing | (81,37,87) | (77.3, 46.0, 85.6) | **(+3.7, −9.0, +1.4)** |

"Naive mix" is the per-channel sRGB affine `panel = base + α·backdrop` fitted on the black/white bracket: base = (36,37,43), α ≈ (0.176, 0.176, 0.173).

Cross-display check: the earlier primary-display bracket read black → (37,37,43), white → (82,82,88), i.e. within 1/255 per channel of the built-in numbers. The material is not display-dependent.

## Mechanism (as far as the data supports)

- **The active material is not a plain per-channel mix — it saturates the backdrop first.** The magenta residual (+R, −G, +B) pushes the result *away* from grey, which no per-channel model can produce. Modeling `panel = base + α·saturate_S(backdrop)` (Rec.709 luma, channels clamped to [0,255]) reproduces the magenta measurement **exactly** at S ≈ 2: the captured backdrop (234,51,247) saturates to (255,0,255), predicting (81.0, 37.0, 87.0) — the measured value to the digit. Because all three channels clamp/floor, the data only *bounds* S: the G-channel floor requires S ≥ ~1.96 and anything above fits equally. An achromatic backdrop is untouched by saturation, which is consistent with mid-grey sitting near the naive line (−1.6).
- **Gamma-correct (linear-light) per-channel mixing is refuted as the explanation**: fitted on the same bracket it *mispredicts mid-grey by +7…8 per channel* and still leaves a chroma-directional residual on magenta. The naive sRGB affine plus a saturation boost is the parsimonious description.
- **This retroactively explains the blue-wallpaper anomaly** from the primary-display pass (sidebar blue channel 87 measured vs ~70 naive-predicted): the boost, not a wallpaper-sampling artifact — a *solid* chromatic backdrop reproduces the deviation, so blur/point-sampling mismatch over a gradient wallpaper is eliminated as the cause.
- **Inactive windows drop the translucency entirely** — `#282a35` on all four backdrops is opaque within quantization (any α ≥ 1/255 would move it across a 0→255 backdrop swing).
- What supplies the material was not dug out of AppKit internals; the claim is strictly behavioral: SwiftUI's sidebar-styled `List` brings its own material, and bare `NSHostingView` hosting does not disable it.

## Consequence — the mockup convention (openspec `add-design-exploration-workflow`, D13)

Mockup panels paint **fixed measured approximations**, annotated as approximations of a live surface:

- `--xtty-panel-bg: #393a40` — the material measured over neutral mid-grey, window active (a representative desktop; one step lighter than the terminal `#1d1f21`).
- `--xtty-panel-bg-inactive: #282a35` — exact, not an approximation (the inactive appearance is a constant).
- `--surface: #1f212c` — corrected from `#1e1e1e`; the window ground actually composited on screen (titlebar, git-panel empty states).

**Not** a CSS `backdrop-filter`, even though `saturate()` exists in CSS: the material's input is the desktop *behind the app window*, which a self-contained mockup neither has nor controls — a backdrop-filter would mix the mockup page's own background and produce a confidently wrong, gallery-theme-dependent tint. The two opaque states would need flat values regardless.

## Probes (reproduce-by-effect)

1. **Backdrop rig** — a ~40-line Swift CLI creating a borderless, `ignoresMouseEvents`, `.normal`-level `NSWindow` filling one screen with a solid `NSColor(srgbRed:…)`; `swiftc backdrop.swift -o backdrop && ./backdrop R G B <screenIndex> &`, kill to remove. Two gotchas that cost time: the `NSWindow(contentRect:…screen:)` initializer interprets `contentRect` **relative to that screen's origin** — passing a global frame puts the window invisibly off-space (use the screenless initializer + `setFrame`); and a sandboxed harness shell cannot connect to the WindowServer at all — the tool must run unsandboxed.
2. **Capture + sample** — `screencapture -x -D <display> out.png`, then PIL/numpy patch means over: the panel below its rows, the terminal, the titlebar, and **the backdrop itself in the same frame**. The backdrop must be sampled, never assumed: an sRGB (255,0,255) window composites onto the wide-gamut built-in display and *captures* as (234,51,247) — nominal values are not measurement inputs. Neutral greys capture unskewed (128 → exactly 128).
3. **States** — window active vs inactive (deactivate by clicking the desktop *through* the mouse-transparent backdrop — see failed instrument #3), git panel empty vs populated (an untracked scratch file + the panel's refresh button toggles it; deleted afterwards).
4. **Model fits** — fit base+α per channel on the black/white bracket; check mid-grey directly (never derive it); check one strongly chromatic backdrop against the fit; if the residual is chroma-directional, test saturate-then-mix.

**Instruments that did NOT work:**

- **Preview/Quick Look as fullscreen backdrops** — macOS fullscreen mode moves them to their own Space (reproducibly landing the backdrop on a different Space than the measured window on a second display). The borderless-window tool replaces them; it never enters fullscreen mode.
- **`NSWindow(contentRect:…screen:)` with a global frame** — window created, `orderFrontRegardless()` succeeds, nothing visible (see probe 1).
- **`osascript 'tell application "Finder" …'` to deactivate the window** — hung a full 2-minute timeout on a TCC automation prompt mid-run ("iTerm wants access to control Finder"; dismissed with Don't Allow, no grant made). Deactivation that needs no Automation grant: click the desktop through the `ignoresMouseEvents` backdrop.
- **`hasForegroundJob`-style single-pixel sampling** — not attempted; patch means with σ reported caught two contaminated samples (a TCC dialog overlapping the terminal patch; a panel row inside the patch) that a single pixel would have silently mismeasured.

## Theory fates

| Theory | Fate | Killed by |
| --- | --- | --- |
| Vibrancy requires an `NSSplitViewItem` with sidebar behavior; bare `NSHostingView`s render flat | ❌ | 4-backdrop matrix: the panel tracks the backdrop in a plain-`NSView` host |
| `--elev-flat`'s "M-by-absence" grep (0 hits for vibrancy/`NSVisualEffectView`) proves no material on screen | ❌ | same — the grep is true of *authored* effects only; AppKit supplies one |
| The blue-wallpaper over-prediction was a wallpaper-sampling/blur artifact | ❌ | solid magenta reproduces the chroma boost exactly (no gradient to mis-sample) |
| The material is a per-channel sRGB mix (naive affine) | ❌ | magenta G residual −9.0; no per-channel model moves a result away from grey |
| The deviation is just gamma-correct (linear-light) compositing | ❌ | linear-light fit mispredicts mid-grey by +7…8 and still leaves the chroma residual |
| The git panel renders like the session sidebar in every state | ❌ | its empty states are not the List — opaque `#1f212c`, the window ground (== titlebar) |
| The panels keep their translucency when the window is inactive | ❌ | `#282a35` on all four backdrops — opaque |
| The rendered window ground is `windowBackgroundColor`'s catalog `#1e1e1e` | ❌ | titlebar + empty states measure `#1f212c`, invariant across backdrops and activation |
| Exact saturation factor S = 2.0 | ❓ | unprovable from this data — all channels clamp; only S ≥ ~1.96 is established |

**Deliberately unmeasured:** light mode (mockups are dark-theme-first; measure before authoring `appearance-light.baseline.html`), the SwiftTerm find-bar popover material (vendor-owned, drawn as-is), and sub-pixel blur behavior at panel edges (irrelevant to a flat-fill convention).

## Re-verify by effect

Rebuild the rig (probes 1–2) against any installed build: over a solid mid-grey backdrop with the window active, the session sidebar and a populated git-panel List must both measure within a few units of (57,58,64) and move when the backdrop changes; deactivate the window and both must snap to (40,42,53) and stop moving. If they don't, the mockup tokens (`--xtty-panel-bg`, `--xtty-panel-bg-inactive`, `--surface`) are stale — re-measure, don't re-derive.

## Guideline

**G-MAT-1.** To characterize an OS-supplied material, put a *solid programmatic backdrop* behind the real window and sample backdrop and surface **in the same capture** — a wallpaper point-sample is not the material's input (the material blurs and *saturates* a region, cross-channel), and a nominal PNG value is not what the display composites (wide-gamut color management skews saturated colors at capture). Fit neutral brackets first, then test at least one strongly chromatic backdrop: only a chromatic probe can expose cross-channel behavior that any per-channel model — naive or gamma-correct — will silently miss.
