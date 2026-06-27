# GPU Rendering & Metal (cell grid + glyph atlas)

> **Provenance:** Generated 2026-06-27 from a 39-agent research workflow (10-terminal survey + adversarial fact-check + 8 architecture deep-dives + synthesis), 281 web lookups. Claims marked surprising/marketing-flavored were independently fact-checked (see [fact-checks](../03-analysis/fact-checks.md)).

> _Topic scope:_ GPU-accelerated rendering on macOS for terminal emulators: Metal, the glyph atlas/texture cache, cell-grid rendering, damage tracking, and how Alacritty, Kitty, and Ghostty draw the screen

## Summary

A GPU-accelerated terminal treats the screen as a fixed grid of character cells, not free-form text. Each unique glyph (a styled character bitmap) is rasterized once by the OS font engine and stored in a "glyph atlas" — one big GPU texture full of small glyph images. To draw a frame, the terminal builds a compact per-cell data array (which atlas glyph, where on the grid, what colors) and hands it to the GPU, which uses "instanced" drawing to paint thousands of cells in just a handful of draw calls. On macOS the native path is Metal (via CAMetalLayer/IOSurface and CoreText for fonts); the same ideas map onto OpenGL elsewhere. The three leading terminals differ mainly in how aggressively they avoid redundant work: Alacritty redraws the whole screen every frame because it's cheap, while Kitty and Ghostty track which cells/lines are "dirty" to skip unchanged work.

## Key points

- The mental model: a terminal screen is a grid of fixed-size cells (cols x rows). Rendering reduces to 'for each cell, stamp the right glyph image at the right grid position in the right colors.' This regular structure is exactly what GPUs are good at, which is why GPU terminals are fast.
- Glyph atlas / texture cache: rasterizing a glyph (turning a font outline into antialiased pixels) is expensive, so you do it once per unique (codepoint + style + size) and cache the resulting bitmap in a large GPU texture called the atlas. Each cell then just stores the atlas (x,y,w,h) coordinates to sample. Alacritty's original design rasterizes each glyph once into an atlas and renders a full screen in only TWO draw calls at ~500 FPS.
- Multiple atlas formats are needed: a single-channel GRAYSCALE atlas for normal antialiased text (saves memory), and a 4-channel RGBA/BGRA atlas for color emoji and images. Ghostty also keeps a 3-byte BGR atlas for subpixel antialiasing. The cell data records which atlas (grayscale vs color) a glyph lives in.
- Instanced rendering is the core GPU trick: instead of one draw call per character, you upload one small 'instance' struct per visible cell (Ghostty's CellText is 32 bytes: atlas pos/size, glyph bearings, grid col/row, RGBA color, atlas-type/flags) and issue a single instanced draw. A vertex shader expands each instance into a quad; a fragment shader samples the atlas and applies fg/bg color.
- Multi-pass back-to-front drawing: terminals draw in ordered passes, each with its own shader pipeline. Ghostty uses background pass (cell bg colors) -> text pass (glyphs from atlas) -> cursor pass. Each pass gets a Uniforms struct with the projection matrix, screen size, cell size, and grid dimensions.
- CPU/GPU data split (Kitty): each cell is stored twice. CPUCell holds the logical 'what' (character, width, attributes); GPUCell holds the rendering artifacts ('sprite_idx' atlas coordinates and final fg/bg/decoration colors) and is laid out so its fields bind directly as OpenGL vertex attributes — no per-frame transformation needed.
- Damage / dirty tracking is the main divergence. Alacritty: no per-cell damage internally — 'the entire screen is redrawn each frame because it's so cheap.' Kitty: per-line 'has_dirty_text' bit (linebuf_mark_line_dirty/clean); only dirty lines get reshaped and re-uploaded to the GPU. Ghostty: dirty-region tracking inside a RenderState snapshot to avoid full-screen rebuilds.
- macOS Metal specifics: pick an MTLDevice, create an MTLCommandQueue, host the view in a CAMetalLayer/IOSurfaceLayer, and set contentsScale to the window's backing scale factor (Retina) or text is blurry. Ghostty uses 3 swap-chain buffers, .bgra8unorm_srgb pixel format, and ahead-of-time-compiled .metallib shaders (vs OpenGL's runtime-compiled GLSL). Note Metal's +Y axis points DOWN.
- Buffer storage modes matter on Apple Silicon vs Intel: unified-memory GPUs can use 'shared' storage (CPU and GPU see the same memory), while discrete GPUs need 'managed' storage with explicit didModifyRange: sync calls after the CPU writes cell/instance data. Ghostty chooses default_storage_mode by GPU architecture.
- Threading & frame pacing: Ghostty runs a dedicated renderer thread separate from terminal emulation, sharing a mutex-guarded RenderState snapshot so the renderer never touches live terminal state mid-mutation. It uses libxev for timing and can drive up to 120 FPS while staying vsync-aligned. V-Sync also throttles the parser usefully — Alacritty notes it gives the parser ~14.7ms of a 16.7ms frame to ingest data.
- Font rasterization is OS-specific: on macOS the native engine is CoreText (Ghostty uses CoreText for discovery + rasterization); FreeType is the cross-platform alternative. Box-drawing/Powerline/Nerd-Font glyphs are often drawn by the terminal itself as 'sprites' (Ghostty renders them via a Canvas/z2d into the atlas) instead of relying on the font, so they tile seamlessly.
- Atlas growth & resync: atlases are packed with a bin-packing algorithm (Ghostty uses a square bin-packer from 'A Thousand Ways to Pack the Bin'). When new glyphs are added the atlas may need to grow; the system bumps 'modified'/'resized' counters so the renderer knows to re-upload the texture to the GPU in a batch rather than per glyph.

## How real terminals do it

- Alacritty (OpenGL, cross-platform incl. macOS): rasterizes each glyph once into a texture atlas, uploads all glyph instance data once per frame, and renders the entire screen in just two draw calls — fast enough (~500 FPS on a full screen) that it deliberately redraws everything every frame instead of tracking damage. Uses OpenGL 3.3+; on macOS it goes through Apple's (deprecated) OpenGL.
- Kitty (OpenGL, written in C + Python): splits each cell into CPUCell (character + attributes) and GPUCell (sprite_idx atlas coordinates + final colors, laid out as GL vertex attributes). A glyph 'sprite' atlas holds rendered glyphs; a per-line has_dirty_text flag drives selective reshaping and re-upload so only changed lines are reprocessed. Performance-critical paths are C, app logic is Python.
- Ghostty (true Metal on macOS/iOS, OpenGL 4.3+ on Linux): GenericRenderer(GraphicsAPI) abstracts Metal vs OpenGL. A dedicated renderer thread reads a mutex-guarded RenderState snapshot (a MultiArrayList of viewport rows + dirty regions). Builds 32-byte CellText instances, draws background -> text -> cursor passes with instancing, presents via an IOSurfaceLayer with contentsScale set for Retina. Uses CoreText for fonts and separate grayscale/BGR/BGRA atlases.
- Ghostty's built-in sprite face: box-drawing characters, cursors, and underlines/decorations are drawn programmatically with a Canvas (z2d library) and packed into the grayscale atlas, bypassing the font entirely so lines connect perfectly across cells.
- Common pattern across all three: one big GPU glyph atlas + per-cell instance data + a vertex/fragment shader pair that expands cells into quads and samples the atlas — the differences are mainly damage tracking (none / per-line / per-region) and graphics API (OpenGL vs Metal).

## Pitfalls / hard parts

- Atlas exhaustion and resizing: the atlas is a fixed-size texture; as new glyphs (CJK, emoji, many fonts/styles) appear you must bin-pack them and eventually grow or evict, then re-upload the texture to the GPU without stalling the frame. Getting eviction wrong causes flickering or re-rasterization stalls.
- Retina / fractional scaling: forgetting contentsScale (or mishandling backingScaleFactor changes when a window moves between displays) gives blurry text. Cell size, padding, and atlas glyph sizes must all be computed in physical pixels, not points.
- Subpixel vs grayscale antialiasing: subpixel AA needs a 3-channel atlas and order-dependent blending against the actual background, which fights with translucency/blur and with a separate background pass — many terminals drop subpixel AA on macOS for this reason.
- Color emoji and images need a separate RGBA atlas and different blending/compositing than grayscale text; mixing them into one instanced draw requires the shader to know which atlas/format each cell uses (hence an atlas-type flag per cell).
- Damage tracking is deceptively hard to get correct: scroll regions, cursor movement, wide (double-width) characters, combining marks/grapheme clusters, and reflow on resize all invalidate cells in non-obvious ways. A subtly wrong dirty bit leaves stale pixels on screen. Alacritty sidesteps this by always redrawing.
- Text shaping vs the cell grid: ligatures, combining characters, and variable-width/emoji break the 'one glyph per cell' assumption. You must shape runs (HarfBuzz/CoreText) yet still map results back onto fixed cells, deciding how wide glyphs span cells and how to cache shaped runs.
- GPU buffer synchronization: with managed/discrete memory you must call didModifyRange: (or equivalent) after writing instance/cell buffers, and with triple buffering you must not overwrite a buffer the GPU is still reading — needs per-frame buffer rotation/fencing or you get tearing/corruption.
- Threading the renderer: sharing terminal state with a render thread requires a snapshot or lock so you never read half-mutated grid state; doing this without excessive copying or lock contention (Ghostty's RenderState snapshot approach) is genuinely tricky.
- Frame pacing / vsync: you want to coalesce bursts of PTY output into one frame (not render per byte) and stay vsync-aligned for smooth scrolling, while still being responsive to input — balancing latency vs throughput is a real design tension.
- Cross-platform graphics abstraction: Metal and OpenGL differ in Y-axis direction, shader language/compilation, sRGB handling, and swap-chain buffer counts, so a clean abstraction (like Ghostty's GenericRenderer) is needed or the backends drift.

## macOS specifics

On macOS the native GPU path is Metal, exposed by hosting the terminal view in a CAMetalLayer (Ghostty uses an IOSurfaceLayer). You must set the layer's contentsScale to the window's backingScaleFactor or Retina text renders blurry. Typical setup: pick an MTLDevice, create an MTLCommandQueue, use a triple-buffered swap chain and a .bgra8unorm_srgb pixel format, and precompile shaders to a .metallib (Metal shaders are AOT-compiled MSL, unlike OpenGL's runtime GLSL). Watch two Metal gotchas: the +Y axis points down (opposite of OpenGL), and buffer storage mode depends on hardware — Apple Silicon's unified memory allows 'shared' buffers (no copy), while Intel/discrete GPUs need 'managed' buffers with explicit didModifyRange: after CPU writes. Fonts come from CoreText (discovery + rasterization), and color emoji require an RGBA atlas. Apple deprecated OpenGL, so Alacritty/Kitty's GL backends still work today but Metal is the future-proof native choice — which is why Ghostty built a true Metal renderer.

## Sources

- https://jwilm.io/blog/announcing-alacritty/
- https://github.com/alacritty/alacritty
- https://deepwiki.com/alacritty/alacritty
- https://deepwiki.com/ghostty-org/ghostty/5-rendering-system
- https://deepwiki.com/ghostty-org/ghostty/5.3-rendering-pipeline-and-shaders
- https://deepwiki.com/ghostty-org/ghostty/5.5.3-glyph-rendering-and-atlases
- https://deepwiki.com/ghostty-org/ghostty/5.5-font-system
- https://github.com/ghostty-org/ghostty
- https://deepwiki.com/kovidgoyal/kitty/2.5-terminal-buffer-data-structures
- https://deepwiki.com/kovidgoyal/kitty/2.3-screen-and-terminal-display
- https://sw.kovidgoyal.net/kitty/
- https://tomscii.sig7.se/2020/11/How-Zutty-works
