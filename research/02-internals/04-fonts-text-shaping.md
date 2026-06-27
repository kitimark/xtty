# Fonts & Text Shaping

> **Provenance:** Generated 2026-06-27 from a 39-agent research workflow (10-terminal survey + adversarial fact-check + 8 architecture deep-dives + synthesis), 281 web lookups. Claims marked surprising/marketing-flavored were independently fact-checked (see [fact-checks](../03-analysis/fact-checks.md)).

> _Topic scope:_ Font rendering and text shaping in terminal emulators (macOS focus): CoreText, HarfBuzz, programming ligatures, monospace metrics, antialiasing, emoji and fallback fonts

## Summary

A terminal draws text on a fixed grid of equal-width cells, but turning the characters in those cells into pixels still needs the same machinery as any rich-text app: a shaping engine to map Unicode codepoints to positioned glyphs, a rasterizer to turn glyph outlines into anti-aliased pixels, and a fallback mechanism for characters the main font lacks (emoji, CJK, symbols/Nerd Font icons). On macOS the native stack is CoreText (shaping + font discovery/cascade) plus CoreGraphics (rasterization); HarfBuzz is the cross-platform alternative many terminals use so behavior matches Linux/Windows. The terminal-specific twist is that the rigid grid fights against proportional shaping: terminals must decide where ligatures and contextual substitutions are allowed, keep every glyph aligned to cell boundaries, and handle wide (2-cell) characters and emoji without bleeding into neighbors. macOS adds a wrinkle by dropping subpixel antialiasing (Mojave/Big Sur), so everyone now does grayscale AA and must get gamma blending right to avoid thin/blurry text.

## Key points

- Pipeline stages: (1) the grid model holds codepoints per cell; (2) shaping turns runs of codepoints into glyph IDs + positions; (3) rasterization turns glyph outlines into an anti-aliased coverage bitmap, usually cached in a glyph atlas texture; (4) the GPU composites textured quads per cell. Shaping and rasterization are distinct steps with different libraries.
- CoreText is Apple's shaping/layout engine. Key objects: CTFontRef (a font at a specific size/config), CTFontDescriptorRef (font matching attributes), CTLineRef/CTRunRef (shaped runs). It does glyph substitution, applies OpenType features, and exposes metrics. CoreGraphics (CGContext, CGFontRef) does the actual outline rasterization. A CTFontRef maps cleanly onto a HarfBuzz hb_font_t, and CGFontRef onto an hb_face_t, which is why hb-coretext exists as a HarfBuzz backend.
- HarfBuzz is the cross-platform shaping engine: it converts a buffer of Unicode codepoints (plus script/language/direction) into glyph IDs with x/y advances and offsets, applying GSUB/GPOS OpenType tables. It has pluggable backends (hb-ft for FreeType, hb-coretext for macOS, hb-directwrite/uniscribe/gdi for Windows). Positions come back in 26.6 fixed-point and must be converted to pixels.
- Terminals shape in 'runs', not per-cell: consecutive cells sharing the same font, style (bold/italic), color/selection state, and direction are batched into one shaped run so contextual features and ligatures can work. A run is broken on any style/font/selection change. This is the core data-structure change needed to support ligatures (e.g. Alacritty's TextRun vs RenderableCell).
- Programming ligatures (==, !=, ->, =>, <=, >=, etc.) are OpenType contextual-alternate substitutions, controlled by the calt/clig/liga/dlig features. They are OFF semantically by default in many terminals' shaping config and must be deliberately enabled; the shaper replaces a multi-char sequence with one wide glyph spanning the original number of cells.
- macOS rendering uses grayscale antialiasing only. Subpixel/LCD antialiasing (ClearType-style RGB fringing) was removed in Mojave (10.14) and the Font Smoothing UI removed in Big Sur (11). Grayscale AA needs no knowledge of pixel RGB geometry but does require correct gamma/sRGB-linear blending; getting blending wrong makes text look too thin or too heavy. macOS also historically did 'font dilation' (fattening outlines, the AppleFontSmoothing/CGFontRenderingFontSmoothingDisabled defaults) and largely ignores font hinting when AA is on.
- Monospace metrics: terminals derive cell width from the font's advance width (typically the width of a representative glyph like 'M' or '0' / 'x_advance'), and cell height from ascent + descent + line gap (leading). Every glyph is positioned by snapping to the cell's pen origin baseline; advances reported by the shaper are usually discarded for the X axis because the grid dictates spacing, but x_offset/y_offset are kept for fine positioning (e.g. combining marks).
- Wide characters and emoji occupy 2 cells (East Asian Width 'wide'/'fullwidth', most emoji). Width is determined by Unicode width rules (wcwidth-style tables, plus emoji-sequences data and the FE0F/VS16 variation selector promoting an emoji to width 2). The renderer must scale/center the (often color, sbix/COLR/CBDT) emoji glyph into its 2-cell box without bleeding into neighbors.
- Font fallback: when the primary monospace font lacks a glyph, the terminal walks a cascade list. On macOS CoreText auto-discovers fallbacks (CTFontCreateForString / the system cascade); cross-platform terminals build their own fallback chain (fontconfig on Linux) plus user-configured maps (kitty's symbol_map, WezTerm font fallback lists) to force specific fonts for ranges like Nerd Font icons. Fallback glyphs often have different metrics, so they must be scaled/positioned to fit the cell, a common source of misalignment bugs.
- Glyph caching: rasterized glyphs (or shaped runs) are cached in a GPU atlas keyed by glyph id + font + size + subpixel/AA settings; some terminals (Ghostty) use position-independent hashing so an identical run at a different column reuses the cache, and reuse HarfBuzz buffers across frames to avoid allocations.

## How real terminals do it

- Ghostty: compile-time selectable shaper backends - CoreText on macOS (with forced LTR embedding to avoid bidi), HarfBuzz for FreeType builds, plus a noop shaper and a web-canvas shaper for WASM. It groups cells into runs, breaks runs on style/font/selection/cursor changes and on known 'bad ligatures' like fl/fi/st, disables calt/liga/dlig by default, converts HarfBuzz 26.6 positions to integers, stores x_offset/y_offset per cell, and uses position-independent run hashing for cache hits.
- Alacritty: intentionally does NOT support programming ligatures, by design (lean/fast philosophy). A long-standing community PR (#2677) demonstrated adding HarfBuzz ligature support by switching the render unit from per-cell RenderableCell to a TextRun that bundles cells sharing render properties - illustrating exactly the architecture change ligatures require.
- WezTerm: uses HarfBuzz for shaping and exposes harfbuzz_features (CSS-like, e.g. calt=0 clig=0 liga=0 to disable ligatures, or stylistic sets like Fira Code's 'zero'); features can be set per-font in the fallback stack. It has full ligature support.
- kitty: GPU-accelerated, uses HarfBuzz for shaping; lets users prepend/append fallback fonts and force ranges via symbol_map (popular for Nerd Font icons); has a --debug-font-fallback flag; implements correct sRGB linear-gamma blending to mimic macOS-quality grayscale rendering; computes emoji width from Unicode emoji-sequences (width 2 unless FE0F handling dictates otherwise) and has a text-sizing protocol for multi-cell text.
- HarfBuzz itself documents the CoreText integration: hb_coretext_font_create / mapping CTFontRef<->hb_font_t and CGFontRef<->hb_face_t, so a macOS terminal can use CoreText for font objects but HarfBuzz for shaping (or vice versa).
- macOS Terminal.app and menu text historically retained more smoothing than third-party apps, but post-Big Sur everything is grayscale AA; users tweak legibility via the AppleFontSmoothing / CGFontRenderingFontSmoothingDisabled defaults keys.

## Pitfalls / hard parts

- Reconciling proportional shaping with a fixed grid: HarfBuzz/CoreText return real advances and offsets, but the terminal must snap glyphs to cell boundaries and usually ignore the X advance. Naively trusting shaper advances breaks alignment; ignoring offsets breaks combining marks and some scripts.
- Deciding where ligatures are legal: a ligature must span exactly the right number of cells, must break across style/color/selection boundaries, must not fire across the cursor (or text under the cursor becomes unreadable), and must avoid 'accidental' typographic ligatures (fi, fl, st) that corrupt code. This is why terminals disable liga/calt by default and re-enable selectively.
- Cursor and selection interaction with ligatures: when the cursor sits inside a multi-cell ligature, or a selection bisects it, you must split the run and re-shape, otherwise the glyph and the cursor/selection highlight disagree.
- Character width correctness: wcwidth/East Asian Width tables drift across Unicode versions and differ between the terminal and the programs running inside it (vim, tmux). A mismatch causes the whole line to shift. Emoji width is especially nasty: VS16 (FE0F) and ZWJ sequences (family/skin-tone emoji) determine width and grapheme clustering, and many emoji are 2 cells.
- Color emoji and color fonts: emoji come as bitmap (sbix/CBDT) or vector-color (COLR/CPAL, SVG) glyphs with their own metrics; you must scale and center them into a 2-cell box without overflow, and your GPU atlas/pipeline must handle RGBA color glyphs alongside grayscale coverage glyphs.
- Fallback-font metric mismatch: fallback fonts (emoji, CJK, Nerd Fonts) have different ascent/descent/advance, so glyphs land too high/low or wrong size; you must rescale/reposition to the primary font's cell, and pick a deterministic fallback order (CoreText's auto cascade can differ from a hand-built one).
- Gamma/sRGB blending for grayscale AA: blending glyph coverage in non-linear sRGB makes light-on-dark text look too thin and dark-on-light too heavy. Correct results require blending in linear space (kitty's sRGB-linear blending), and matching macOS's look additionally means replicating its outline dilation.
- Performance: shaping and rasterizing every frame is too slow; you need a glyph atlas plus a shaped-run cache that is position-independent and invalidated correctly on font/size/DPI/AA-setting changes. Buffer reuse across frames matters for allocation pressure.
- HiDPI / Retina and fractional scaling: cell metrics must be computed in physical pixels and snapped consistently, or text shimmers/misaligns when moved between displays of different scale factors.
- macOS specifics leaking through: CoreText forces LTR-handling decisions, hinting is effectively ignored when AA is on, and the lack of subpixel AA means you cannot rely on RGB-geometry tricks for sharpness - you must lean on correct gamma and possibly higher-DPI assumptions.

## macOS specifics

Native stack is CoreText (font matching via CTFontDescriptor, shaping/layout via CTLine/CTRun, metrics) plus CoreGraphics (CGContext/CGFontRef outline rasterization). CoreText auto-discovers fallback fonts via the system cascade (CTFontCreateForString), which is convenient but less controllable than a hand-built chain. macOS does grayscale antialiasing only: subpixel/LCD AA was removed in Mojave (10.14) and the Font Smoothing preference removed in Big Sur (11); leftover behavior is tunable through defaults keys (AppleFontSmoothing, CGFontRenderingFontSmoothingDisabled). The rasterizer ignores font hinting when AA is on and historically applies 'font dilation' to fatten glyphs, so matching the native look requires correct linear/sRGB gamma blending and possibly outline dilation. A CTFontRef maps onto a HarfBuzz hb_font_t and CGFontRef onto hb_face_t, so terminals can mix CoreText font objects with HarfBuzz shaping (hb-coretext). Most cross-platform terminals (kitty, WezTerm, Ghostty's HB build) prefer HarfBuzz so shaping matches other OSes, using CoreText mainly for font discovery and rasterization; Ghostty also ships a dedicated CoreText shaper backend (with forced LTR embedding).

## Sources

- https://harfbuzz.github.io/integration-coretext.html
- https://harfbuzz.github.io/why-do-i-need-a-shaping-engine.html
- https://harfbuzz.github.io/
- https://github.com/harfbuzz/harfbuzz
- https://deepwiki.com/ghostty-org/ghostty/5.5.2-text-shaping
- https://wezterm.org/config/font-shaping.html
- https://github.com/alacritty/alacritty/pull/2677
- https://brev.al/blog/articles/coding-ligatures-alacritty-nerd-fonts
- https://blog.codeminer42.com/modern-terminals-alacritty-kitty-and-ghostty/
- https://skip.house/blog/macos-font-rendering
- https://mjtsai.com/blog/2018/07/13/macos-10-14-mojave-removes-subpixel-anti-aliasing/
- https://www.howtogeek.com/358596/how-to-fix-blurry-fonts-on-macos-mojave-with-subpixel-antialiasing/
- https://sw.kovidgoyal.net/kitty/text-sizing-protocol/
- https://github.com/kovidgoyal/kitty/issues/2396
- https://github.com/kovidgoyal/kitty/issues/3312
- https://erwin.co/kitty-and-nerd-fonts/
