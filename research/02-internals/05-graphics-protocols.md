# Graphics Protocols — Sixel / iTerm2 / kitty

> **Provenance:** Generated 2026-06-27 from a 39-agent research workflow (10-terminal survey + adversarial fact-check + 8 architecture deep-dives + synthesis), 281 web lookups. Claims marked surprising/marketing-flavored were independently fact-checked (see [fact-checks](../03-analysis/fact-checks.md)).

> _Topic scope:_ Advanced terminal graphics protocols: Sixel, the Kitty graphics protocol, and the iTerm2 inline images protocol — and how images are displayed inside a text grid (macOS focus)

## Summary

Terminals are fundamentally character-cell grids, so "graphics" means smuggling raster pixel data through the same byte stream that carries text, using escape sequences the terminal intercepts instead of printing. Three living protocols dominate: Sixel (an old DEC bitmap format revived, uses a DCS escape and a limited color-register palette), the iTerm2 inline images protocol (an OSC 1337 sequence carrying a whole base64-encoded image file), and the Kitty graphics protocol (a richer APC-based system with image IDs, reusable placements, z-ordering, shared-memory transfer, animation, and Unicode placeholders for multiplexers). The terminal decodes the pixels, maps the requested size onto a rectangle of character cells, blends/draws them over its grid, and advances (or doesn't) the text cursor. On macOS the native Terminal.app supports none of these; iTerm2, kitty, Ghostty, and WezTerm do, with WezTerm being the only one that speaks all three.

## Key points

- The core trick: a terminal is a grid of character cells, and images are injected through in-band escape sequences. Sixel uses a DCS string (ESC P ... q ... ESC \), iTerm2 uses an OSC (ESC ] 1337 ; File=... ^G or ST), and Kitty uses an APC (ESC _ G <control>;<base64 payload> ESC \). Binary pixel data is base64-encoded so it survives a text channel.
- Sixel encodes bitmaps in 6-pixel-tall horizontal bands: each vertical column of 6 pixels becomes a 6-bit number turned into a printable ASCII char (value + 63). Color is indexed through 'color registers' (# selects a register; registers are defined with RGB or HLS in 0-63 per-channel DEC format). Practical palettes are commonly capped (often ~256, sometimes as low as 16), there is no alpha channel, and dithering must be done by the sender. It is descended from DEC dot-matrix printers and VT2xx/VT3xx terminals.
- iTerm2's protocol is the simplest to implement on the producer side: it sends one whole image FILE (PNG, GIF, JPEG, PDF, anything macOS can decode) as base64 after OSC 1337;File=, with optional args name (base64), size, width, height (in cells, Npx, N%, or auto), preserveAspectRatio, and inline=1. inline=0 just downloads the file to ~/Downloads. iTerm2 3.5+ adds a chunked MultipartFile/FilePart/FileEnd variant so large images survive tmux's per-sequence size limit (~1 MiB).
- Kitty's protocol is the most capable. Control data is comma-separated key=value pairs; payload is base64. Formats: f=24 (RGB), f=32 (RGBA, default), f=100 (PNG). Optional zlib compression with o=z. The action key a controls behavior: a=t transmit, a=T transmit+display, a=p display existing, a=d delete, a=f/a=a for animation frames/control, a=q query support.
- Kitty separates an IMAGE (transmitted once, given i=<id> or auto via I=<number>) from a PLACEMENT (an on-screen instance, p=<placement id>). One image can be drawn many times at different spots and even cropped to a sub-rectangle (x,y,s,v) without re-sending pixels — a big efficiency win over iTerm2/Sixel which re-transmit every time.
- Transmission media (Kitty 't' key) matters for performance: t=d direct in the escape payload (works remotely, must be chunked into <=4096-byte multiples of 4 using m=1/m=0), t=f regular file path, t=t temp file (deleted after read), t=s POSIX shared memory. File and shm paths let a local program hand over megabytes without stuffing them through the PTY byte stream.
- Positioning in the text grid: placement starts at the cursor's cell; c=<cols> and r=<rows> set how many character cells the image rectangle spans (giving just one auto-scales the other to preserve aspect ratio), and X/Y give sub-cell pixel offsets. z=<n> sets the z-index relative to text (positive = above text, negative = below; very negative draws beneath even non-default cell backgrounds). By default the cursor advances right by c and down by r; C=1 suppresses cursor movement so layout stays put.
- Multiplexer survival (tmux/screen): Kitty defines Unicode placeholders — a virtual placement (a=p,U=1) plus the placeholder char U+10EEEE whose foreground color encodes the image ID and whose combining diacritics encode row/column indices. The image then follows the cell as the TUI moves it. Alternatively, Kitty and Sixel/iTerm2 sequences can be wrapped in tmux DCS passthrough (requires 'set -g allow-passthrough on'); Sixel runs natively on tmux >= 3.4.
- Sizing requires the program to know cell geometry. Programs query window pixel size with CSI 14 t (terminal replies ESC[4;<height>;<width>t) and cell size with CSI 16 t. Kitty can also report these. Without this, a producer can't translate desired pixel dimensions into a count of cells. Many tools also fall back to terminfo/env detection ($TERM, $KITTY_WINDOW_ID, $TERM_PROGRAM) to pick a protocol.
- Drawing mechanics in the emulator: the terminal decodes pixels into a texture, computes the target rectangle in pixels (cells * cell_size + offsets), and composites it over the glyph grid — Kitty supports alpha blending and z-order so text and images interleave; Sixel just paints opaque pixels. Images are expected to scroll with the text and be clipped/erased correctly when the region is overwritten or cleared.
- Reference tools to study: kitty's 'icat' kitten and 'kitten icat' (Kitty protocol), 'imgcat' (iTerm2 protocol, ships with iTerm2; WezTerm has 'wezterm imgcat'), 'img2sixel'/libsixel and 'lsix' (Sixel), chafa (auto-detects and targets all three plus Unicode-block fallback), and timg/viu as cross-protocol viewers.

## How real terminals do it

- kitty (macOS/Linux, by Kovid Goyal): originated the Kitty graphics protocol; uses image IDs + placements, shared-memory and temp-file transfer, z-index, animation, and Unicode placeholders. Its 'icat'/'kitten icat' is the canonical demo client. kitty deliberately does NOT implement Sixel.
- Ghostty (macOS/Linux, by Mitchell Hashimoto): implements the Kitty graphics protocol (the modern de-facto standard) and is GPU-accelerated; very fast text throughput on macOS.
- WezTerm (macOS/Linux/Windows): the only terminal that supports all three — Kitty graphics, Sixel, and iTerm2 inline images — and ships 'wezterm imgcat'. Good reference for how one renderer multiplexes protocols.
- iTerm2 (macOS): defines the OSC 1337 File= inline-images protocol, ships 'imgcat', added Sixel support in v3, and added the chunked MultipartFile variant (3.5+) for tmux. Leverages macOS image decoders so it accepts PDF/PICT/PNG/GIF/etc.
- Apple Terminal.app (macOS): supports NONE of the modern graphics protocols — the key macOS gotcha. A program must detect this and fall back to Unicode half-block / braille rendering (as chafa does).
- Konsole (KDE): has partial Kitty graphics protocol support, illustrating that partial/incremental implementations are common.
- Sixel-native terminals/tools: xterm (with sixel enabled), mlterm, mintty, RLogin; libsixel/img2sixel and hackerb9's 'lsix' (image thumbnails like ls) are the classic Sixel producers.
- tmux: passes graphics through via DCS passthrough when 'allow-passthrough on' is set, and supports Sixel natively since 3.4 — the place most real-world graphics bugs surface.

## Pitfalls / hard parts

- Coordinate/units impedance mismatch: producers think in pixels, terminals lay out in cells. You must query cell and window pixel size (CSI 14t / CSI 16t) and round pixel requests to whole cells, or images come out the wrong size or misaligned. Cell size also changes on font/zoom changes and window DPI changes (Retina/non-Retina on macOS), so cached geometry goes stale.
- macOS Retina/HiDPI scaling: a 'pixel' in the protocol may be a logical point, not a physical device pixel. Getting backing-scale-factor handling wrong yields blurry or half-size images. iTerm2/kitty handle this; a new implementation must decide its pixel convention explicitly.
- Multiplexers (tmux/screen) are the hardest part. They don't understand graphics sequences and will either strip them or, with passthrough, pass raw bytes that may land in the wrong pane, not get clipped on scroll, or leave ghost images. Kitty's Unicode-placeholder scheme exists precisely because naive passthrough breaks on pane movement and scrollback. tmux also imposes a per-escape-sequence size cap (~1 MiB), forcing chunking.
- Cursor and scroll semantics: after drawing, where is the cursor? Sixel repositions the text cursor to the graphics active position on exit, which can clobber subsequent text. Kitty advances by c/r unless C=1. Getting scroll-with-text, region clears, and overwrite/erase of image-covered cells right is subtle and a common source of artifacts.
- Sixel's palette and color limits: indexed color registers (often capped at 256 or fewer), 6-bit-per-channel DEC color format, no alpha channel, and no built-in dithering mean the sender must quantize and dither, and banding/posterization is easy to produce. The deprecated aspect-ratio parameters add further compatibility traps.
- Transferring large images through the PTY is slow and can block; that's why Kitty offers file/temp-file/shared-memory media — but those only work when client and terminal share a filesystem (i.e., not over SSH), so you need a remote vs local code path. Direct base64 transfer must be chunked correctly (4096-byte multiples of 4 for Kitty).
- Protocol detection and graceful fallback: there's no clean universal capability query. You must sniff $TERM/$TERM_PROGRAM/env vars or send an a=q query and time out, then degrade to Sixel, then to Unicode blocks. Guessing wrong dumps raw escape garbage onto the user's screen.
- Memory and lifetime management in the emulator: with Kitty, images and placements persist and must be tracked, deleted (lowercase d keeps data, uppercase frees it), garbage-collected, and bounded — otherwise a long-running TUI leaks GPU/CPU memory. Scrollback containing images multiplies this.
- Z-order and alpha compositing: blending images correctly with text, default vs non-default cell backgrounds, and overlapping placements (lower image ID as tiebreaker) is real renderer work; Sixel sidesteps it by being opaque, but then can't integrate with text the way Kitty does.
- Security/DoS: decoding attacker-controlled image bytes (e.g., a malicious PNG catted to the terminal) runs an image decoder on untrusted input; huge dimensions or animation frame counts can exhaust memory. Terminals must bound sizes and harden their decoders.

## macOS specifics

Apple's built-in Terminal.app supports none of these graphics protocols, so any tool targeting "the Mac terminal" must detect that and fall back to Unicode half-block/braille rendering. The graphics-capable macOS terminals are iTerm2 (its own OSC 1337 protocol plus Sixel), kitty and Ghostty (Kitty graphics protocol), and WezTerm (all three). iTerm2's protocol is convenient on macOS because it hands the base64 file straight to the OS image decoders, accepting PDF/PICT/PNG/GIF/etc. The biggest macOS-specific implementation hazard is Retina/HiDPI backing-scale handling: you must be deliberate about whether protocol "pixels" are logical points or physical device pixels, and re-query cell/window pixel size (CSI 14t/16t) when the window moves between displays of different scale or the font size changes, or images render blurry or wrongly sized.

## Sources

- https://sw.kovidgoyal.net/kitty/graphics-protocol/
- https://github.com/kovidgoyal/kitty/blob/master/docs/graphics-protocol.rst
- https://sw.kovidgoyal.net/kitty/kittens/icat/
- https://iterm2.com/documentation-images.html
- https://en.wikipedia.org/wiki/Sixel
- https://saitoha.github.io/libsixel/
- https://vt100.net/shuford/terminal/all_about_sixels.txt
- https://wezterm.org/imgcat.html
- https://wezterm.org/features.html
- https://rioterm.com/docs/features/kitty-graphics-protocol
- https://rioterm.com/docs/features/sixel-protocol
- https://rioterm.com/docs/features/iterm2-image-protocol
- https://akmatori.com/blog/terminal-graphics-protocols
- https://github.com/kovidgoyal/kitty/discussions/5287
- https://github.com/hackerb9/lsix
- https://mintlify.wiki/tmux/tmux/advanced/sixel-images
- https://tmuxai.dev/terminal-compatibility/
- https://medium.com/@dynamicy/choosing-a-terminal-on-macos-2025-iterm2-vs-ghostty-vs-wezterm-vs-kitty-vs-alacritty-d6a5e42fd8b3
