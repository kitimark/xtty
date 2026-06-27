# Performance — Latency vs Throughput

> **Provenance:** Generated 2026-06-27 from a 39-agent research workflow (10-terminal survey + adversarial fact-check + 8 architecture deep-dives + synthesis), 281 web lookups. Claims marked surprising/marketing-flavored were independently fact-checked (see [fact-checks](../03-analysis/fact-checks.md)).

> _Topic scope:_ Terminal performance: input latency vs throughput, vtebench benchmarking, frame pacing, and why "fastest terminal" claims are nuanced (macOS focus)

## Summary

A terminal's "speed" is really two different, weakly-correlated things. Throughput is how fast it can read raw bytes from the PTY and parse/render them (think `cat hugefile` or a flood of escape codes); latency is how long after a keypress the character actually appears on screen. The popular benchmark vtebench only measures throughput, and its own README warns it says nothing about latency or frame rate, yet "fastest terminal" claims are usually built on throughput numbers. For everyday interactive use latency is what you feel, and it's dominated by frame pacing: the terminal must wait for the next monitor refresh to show your keystroke, so vsync/refresh-rate behavior and how the app schedules frames matter more than raw parsing speed. Building a fast terminal means optimizing both axes separately and accepting that they trade off.

## Key points

- Two distinct metrics: THROUGHPUT (bytes/sec read from the PTY + parsed + rendered, e.g. dumping a big file or vtebench payloads) vs INPUT LATENCY (keypress-to-photon, the time before your typed character shows up). They are only weakly correlated; high throughput does NOT imply low latency.
- vtebench (from the Alacritty project) measures ONLY PTY read/parse throughput. Its README explicitly says: 'This benchmark is not sufficient to get a general understanding of the performance of a terminal emulator. It lacks support for critical factors like frame rate or latency.' It feeds a benchmark program's stdout as payload and times how fast the terminal sinks it.
- Dan Luu's measurements (hardware/screen-capture keypress-to-display, macOS) found throughput and latency essentially uncorrelated: e.g. Alacritty ~39 MB/s throughput but ~31ms median latency, st ~14 MB/s at ~25ms, while emacs-eshell at a tiny 0.05 MB/s had only ~5ms latency. terminal.app measured among the lowest median latency (~6ms) despite unremarkable throughput.
- Why 'fastest terminal' claims are nuanced: most terminals can already sink stdout orders of magnitude faster than a human reads, so extra throughput barely changes day-to-day experience; meanwhile responsiveness to ^C, scroll, and typing under load is what users actually feel, and those aren't what throughput benchmarks measure.
- Tail latency matters more than the median. Under load (e.g. compiling) medians stay stable but the 99th/99.9th percentile blows up. At ~120 wpm you hit the 99.9th-percentile latency roughly every ~100 seconds, so occasional hitches are felt even if the average looks fine.
- Frame pacing is the dominant latency lever for interactive typing. A keystroke can only become visible at the next display refresh, so latency is bounded by the refresh interval (~16.7ms at 60Hz, ~6.9ms at 144Hz) plus how the terminal schedules its frame. A fixed-rate repaint timer is a classic latency bug.
- Real example of fixing frame pacing: GNOME's VTE used to repaint on a fixed 40Hz timer (adding artificial latency); GNOME 46 switched to drawing every frame synchronized with the monitor, bringing VTE-based terminals (GNOME Terminal, Console) nearly to Alacritty's latency. Measurement showed latencies spread uniformly across one refresh interval, the signature of proper vsync alignment.
- Architecture creates the tradeoff: single-threaded terminals (parse + render on one thread, like VTE) let long repaints slow down PTY draining, so optimizing latency (drawing more often) can hurt throughput; Alacritty uses a separate render thread so parsing isn't blocked by drawing. Batching/coalescing PTY reads boosts throughput but can add latency; flushing eagerly cuts latency but wastes work.
- Measurement methodology determines credibility. Software tools like Typometer inject synthetic keystrokes and screen-grab in software, capturing only the software stack. Hardware methods (light sensor + microcontroller, e.g. a Teensy reading ~35,500 samples/sec) capture true end-to-end including keyboard, USB, compositor, GPU, and monitor, which add 20ms+ that software methods miss.
- Practical perception thresholds: under ~10ms feels instant, and above ~20ms added latency starts to be noticeable; total end-to-end keypress-to-photon is often 20-40ms+ once hardware is included.

## How real terminals do it

- Alacritty: built the vtebench tool and optimizes hard for PTY throughput (~39 MB/s in Luu's tests), using a dedicated rendering thread so parsing isn't blocked by drawing; it's the common latency baseline others compare against, though its median latency (~31ms in those tests) is not class-leading.
- Apple Terminal.app: among the lowest median keypress-to-display latency on macOS in Dan Luu's measurements (~6ms median) despite modest throughput, but exhibited visible stuttering under load, illustrating that a good median can hide bad frame consistency.
- GNOME VTE terminals (GNOME Terminal, GNOME Console, Tilix): moved from a fixed 40Hz repaint timer to per-frame monitor-synced rendering in GNOME 46, dramatically cutting input latency to near-Alacritty levels; remaining gap is extra VTE work (accessibility, scrollbar math). Single-threaded parse+render means repaint time affects throughput.
- st (suckless): low throughput (~14 MB/s) yet competitive latency (~25ms), a concrete counterexample to 'high throughput = low latency.'
- Hyper / web-based (Electron) terminals: consistently among the worst latency due to the browser rendering stack, a cautionary tale about layering.
- xterm / Zutty: xterm often posts excellent latency in benchmarks; Zutty was written explicitly to be a low-latency GPU terminal and published comparative typing-latency measurements.
- macOS Metal-based terminals (e.g. Kitty, Ghostty, WezTerm use GPU rendering): correct frame pacing on macOS hinges on CAMetalLayer/CVDisplayLink scheduling. With maximumDrawableCount=3, CPU-to-display latency can be ~50ms (3 frames queued) vs ~16ms when scheduled tightly; Apple's guidance is to drive presentation off a display link and present at the link's output time, and to handle ProMotion's variable refresh.

## Pitfalls / hard parts

- Conflating throughput with speed: shipping a 'fastest terminal' claim backed only by vtebench/`cat bigfile` numbers, when those barely affect interactive feel and ignore the latency users actually experience.
- Fixed-rate repaint timers: a simple 'redraw every N ms' loop adds up to one timer interval of latency on every keystroke (the VTE 40Hz mistake). You want to render in response to input, aligned to the next refresh, not on an independent clock.
- Ignoring tail latency: optimizing the median while p99/p99.9 spikes under load. Real workloads (compiles, log floods) are exactly when responsiveness matters and is hardest to hold.
- The throughput-vs-latency architectural conflict: coalescing PTY reads and skipping frames boosts throughput but raises latency; drawing every frame lowers latency but, in single-threaded designs, can starve PTY draining and tank throughput. You often need a separate render thread to have both.
- Measuring in software only: Typometer-style synthetic keystroke + screen capture misses 20ms+ of real hardware latency (keyboard scan, USB poll, compositor, GPU queue, monitor pixel response). Credible numbers need a hardware light-sensor rig.
- macOS Metal drawable queue depth: leaving CAMetalLayer/MTKView at default triple buffering queues multiple frames and silently adds 30-50ms; you must present off CVDisplayLink at the correct output time to get down to ~16ms.
- Compositor and refresh-rate variability: window manager/compositor choices and ProMotion's variable refresh rate change measured latency a lot, so results aren't portable across setups and benchmarks must state the full environment.
- Vsync trade-off: presenting unsynced can lower latency but causes tearing; syncing avoids tearing but bounds you to the refresh interval, so the 'right' answer depends on display capabilities (and high-Hz/VRR displays shrink the penalty).
- Benchmark payload realism: vtebench-style escape-code floods don't resemble real app output (vim, tmux, ls --color), so over-tuning to them optimizes the wrong distribution.

## macOS specifics

On macOS, interactive latency is governed by Core Animation and the display pipeline more than by parsing speed. GPU terminals render into a CAMetalLayer/MTKView; the default triple-buffered drawable queue (maximumDrawableCount=3) can leave multiple frames queued and add 30-50ms, whereas scheduling presentation off a CVDisplayLink and calling presentDrawable:atTime: with the link's output time can bring CPU-to-display latency to ~16ms or less. ProMotion (variable 60-120Hz) and multi-monitor setups complicate frame pacing and can cause presentDrawable to fall behind the display link, producing stutter. In Dan Luu's macOS measurements, Apple's Terminal.app had a notably low median latency (~6ms software-measured) but visible stuttering under load, while GPU terminals like Alacritty/iTerm2 showed higher medians; total end-to-end latency including keyboard, USB, GPU, and monitor typically exceeds 20ms regardless.

## Sources

- https://danluu.com/term-latency/
- https://github.com/alacritty/vtebench
- https://github.com/alacritty/vtebench/blob/master/README.md
- https://bxt.rs/blog/just-how-much-faster-are-the-gnome-46-terminals/
- https://tomscii.sig7.se/2021/01/Typing-latency-of-Zutty
- https://beuke.org/terminal-latency/
- https://anarc.at/blog/2018-05-04-terminal-emulators-2/
- https://lwn.net/Articles/751763/
- https://news.ycombinator.com/item?id=42526221
- https://developer.apple.com/documentation/metal/achieving-smooth-frame-rates-with-a-metal-display-link
- https://developer.apple.com/forums/thread/711033
- https://danluu.com/input-lag/
- https://danluu.com/keyboard-latency/
