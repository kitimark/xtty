# Fact-Checks

> **Provenance:** Generated 2026-06-27 from a 39-agent research workflow (10-terminal survey + adversarial fact-check + 8 architecture deep-dives + synthesis), 281 web lookups. Claims marked surprising/marketing-flavored were independently fact-checked (see [fact-checks](../03-analysis/fact-checks.md)).

Each surprising/marketing-flavored claim surfaced during the survey was independently re-searched with a skeptic's prompt (try to refute).

**Totals:** 16 confirmed, 4 refuted, 0 uncertain.

---

**✅ CONFIRMED — iTerm2**

- *Claim:* The widely cited ~12ms key-to-screen input latency 'slowest among modern terminals' figure for iTerm2 comes from secondary review/comparison articles, not an official benchmark, and exact numbers vary by config/hardware.
- *Finding:* Verification supports the claim. The specific "~12ms input latency, slowest of the group" figure appears in 2026 secondary review/comparison sites (e.g., DevToolReviews, Vibehackers), which present it in a comparison table with no citation, methodology link, or official benchmark — DevToolReviews only says it "spent six weeks" daily-driving terminals with undefined "standardized tests." No official iTerm2 benchmark publishes a 12ms key-to-screen figure. The most-cited primary benchmark (Dan Luu, danluu.com/term-latency) measures iTerm2 at roughly 44ms idle median (60ms at 99.9th pct) and ~45ms under load — an order of magnitude higher than 12ms and using a different method (java.awt.Robot keypress + screen capture) — and does NOT call iTerm2 the slowest (Hyper is slower there). Other community tests (e.g., camera-based "Is It Snappy?" on Linux/Wayland by various authors) give yet different rankings and explicitly caution that results are specific to one hardware/OS/compositor combo. So the numbers do vary substantially by config/hardware/methodology, and the "12ms slowest" claim originates in secondary reviews rather than a primary/official source. Caveat: these are slightly different metrics (idle vs under-load vs camera-based total latency), so the figures are not directly comparable, but that variance itself is exactly the point the claim makes.
- *Sources:* https://danluu.com/term-latency/; https://www.devtoolreviews.com/reviews/best-terminal-emulators-2026; https://www.devtoolreviews.com/reviews/ghostty-vs-warp-vs-iterm2-2026; https://vibehackers.io/blog/best-terminal-for-mac; https://scopir.com/posts/best-terminal-emulators-developers-2026/; https://www.lkhrs.com/blog/2022/07/terminal-latency/


**✅ CONFIRMED — iTerm2**

- *Claim:* Version specifics are contested: Wikipedia lists 3.5.11 (Jan 2, 2025) as latest stable, while a search snippet claimed 3.6.x builds in 2025; the 3.6 line should be verified on the downloads page.
- *Finding:* Both facts are accurate, and verifying directly on the official downloads page resolves the contradiction: 3.5.11 was indeed released Jan 2, 2025 (a security fix), and the 3.6 line is genuine - iTerm2 3.6.0 shipped Sept 15, 2025, with the 3.6.x series continuing through 2026. So 3.5.11 was NOT the latest stable for long; it was superseded by the 3.6 branch. As of the official downloads page, the current latest stable is 3.6.11 (June 2, 2026). The 'contested' framing is really just stale Wikipedia data lagging behind reality, not a genuine factual conflict - the 3.6 line is confirmed real.
- *Sources:* https://iterm2.com/downloads.html; https://iterm2.com/appcasts/full_changes.txt


---

**❌ REFUTED — Apple Terminal.app (macOS built-in)**

- *Claim:* Apple's claim that macOS 26 Tahoe brings Terminal's "first redesign in decades" / first significant visual refresh since launch (~20+ years) - widely repeated in 2025 press but marketing-flavored.
- *Finding:* The "first redesign in decades" framing was NOT an Apple claim; it is press/headline characterization (Macworld's headline by Roman Loyola, TweakTown's "first makeover in 24 years," MacRumors' "first notable design update since the command-line tool debuted"). Apple's own wording at the WWDC25 Platforms State of the Union "lightning round" was merely feature-level and understated: "Terminal gets 24-bit color, new themes and Powerline fonts" (plus themes inspired by Liquid Glass). Apple did not assert a "first in decades / since launch" superlative as marketing. So the claim misattributes a media framing to Apple. The underlying substance is, however, factually reasonable: Terminal.app debuted in Mac OS X 10.0 (2001) and had seen no comparable visual overhaul in ~24 years, so describing the macOS 26 update as its first significant visual refresh in roughly two decades is accurate as a press observation. Net: "widely repeated in 2025 press" = true; "marketing-flavored" = it is press-flavored, not an Apple marketing line; "Apple's claim" = false.
- *Sources:* https://www.macrumors.com/2025/06/16/apples-terminal-app-macos-tahoe/; https://www.macworld.com/article/2809620/macos-26-includes-a-new-look-for-the-terminal-app.html; https://www.tweaktown.com/news/105878/power-users-take-note-macos-tahoe-is-giving-the-terminal-app-its-first-makeover-in-24-years/index.html; https://developer.apple.com/videos/play/wwdc2025/102/; https://en.wikipedia.org/wiki/MacOS_Tahoe


**✅ CONFIRMED — Apple Terminal.app (macOS built-in)**

- *Claim:* Apple Terminal.app gained true 24-bit color only in macOS 26 (2025), having effectively been limited to 256 colors before.
- *Finding:* Accurate. Apple announced at WWDC 2025 (Platforms State of the Union) that the redesigned Terminal in macOS 26 Tahoe (released September 15, 2025) adds 24-bit color and Powerline font support. Before this, the built-in Terminal.app was the notable holdout among major terminal emulators, supporting only ANSI 256 colors (no true color), unlike iTerm2, Alacritty, and VS Code's terminal which had long supported 24-bit color. Minor nuance: Apple's marketing/release notes frame it as Terminal gaining 24-bit color; community sources consistently confirm the prior 256-color ceiling.
- *Sources:* https://www.macrumors.com/2025/06/16/apples-terminal-app-macos-tahoe/; https://x.com/ambermac/status/1937128132428923278; https://en.wikipedia.org/wiki/MacOS_Tahoe; https://medium.com/@skeough117/the-mac-default-terminal-lacks-true-color-capabilities-7ee42eb27aa1; https://gist.github.com/CMCDragonkai/146100155ecd79c7dac19a9e23e6a362; https://news.ycombinator.com/item?id=45281616


---

**✅ CONFIRMED — Ghostty**

- *Claim:* Reviewers call Ghostty the "fastest terminal emulator tested" (~0.7s to cat 100,000 lines, ~2ms key-to-screen latency), while Ghostty's own docs are more modest — claiming only to be "in the same class as the fastest" terminals (roughly on par with Alacritty) — and the benchmark numbers are method-dependent and contested.
- *Finding:* The claim is substantially accurate, with two minor nuances. (1) Review numbers vary by source rather than being a single fixed figure: e.g. DevToolReviews reports ~0.6s for cat 100k lines and ~1.8ms latency; other 2026 reviews cite ~0.7s and ~1.2-2ms. So "~0.7s" and "~2ms" are fair round-figures but not canonical. (2) Ghostty's official About page (ghostty.org/docs/about) does indeed use the modest framing — verbatim: "Ghostty aims to be in the same class as the fastest terminal emulators" and "In some benchmarks it is faster, in others it is slower, but in every case it should be impossible to say that Ghostty is slow" — but that specific page does NOT name Alacritty. The "within a few percentage points of Alacritty / ~100x faster than Terminal.app and iTerm" comparison comes from Ghostty's broader docs/FAQ and community material, not the About page itself. The "contested/method-dependent" point is well supported: Ghostty maintainer Mitchell Hashimoto acknowledges (discussion #4837) that input latency was "never once reliably measured or optimized" and that Ghostty does worse on pathological synthetic benchmarks; Hacker News critics note input-latency benchmarks are unreliable without a camera and that cat/IO-throughput tests don't reflect real-world use, with results often within ~15% across Alacritty/Ghostty/Kitty.
- *Sources:* https://ghostty.org/docs/about; https://www.devtoolreviews.com/reviews/ghostty-terminal-review-2026; https://github.com/ghostty-org/ghostty/discussions/4837; https://news.ycombinator.com/item?id=42526221; https://scopir.com/posts/best-terminal-emulators-developers-2026/; https://vibehackers.io/blog/best-terminal-for-mac


**❌ REFUTED — Ghostty**

- *Claim:* Ghostty is the 'only' macOS terminal using Apple's Metal natively, while Kitty/Alacritty use OpenGL via Apple's deprecated compatibility layer.
- *Finding:* The "only" is false. Two halves of the claim must be separated:

1) RENDERER FACTS ON KITTY/ALACRITTY (accurate): Alacritty bills itself as "A cross-platform, OpenGL terminal emulator" and Kitty renders with OpenGL; macOS deprecated OpenGL in 10.14 (2018), so on macOS both run through Apple's deprecated OpenGL compatibility path. This part checks out.

2) GHOSTTY AS "ONLY" METAL TERMINAL (false): Ghostty does use Metal natively on macOS (confirmed by ghostty.org docs), but it is NOT the only one. Warp is built in Rust and "renders directly on the GPU using Metal," using wgpu which targets Metal on macOS — Warp's team explicitly states "Metal was chosen over OpenGL as the GPU API since Warp was going to target macOS as its first platform" (warp.dev/blog/how-warp-works). WezTerm also reaches Metal on macOS via its WebGpu front_end (wgpu backend), per WezTerm's own docs. So at minimum Warp (natively Metal) and WezTerm (Metal via wgpu/WebGPU) also use Metal on macOS. A precise statement: "Among the popular GPU terminals, Ghostty and Warp use Metal natively on macOS (WezTerm can too via its WebGPU backend), whereas Kitty and Alacritty use OpenGL through Apple's deprecated compatibility layer." Reviews repeating the "only" wording are overstated, likely because they only compared Ghostty against Kitty/Alacritty and omitted Warp/WezTerm.
- *Sources:* https://www.warp.dev/blog/how-warp-works; https://ghostty.org/docs/features; https://github.com/alacritty/alacritty; https://wezterm.org/config/lua/config/front_end.html; https://developer.apple.com/documentation/Metal/migrating-opengl-code-to-metal; https://sw.kovidgoyal.net/kitty/


---

**✅ CONFIRMED — kitty**

- *Claim:* kitty's own performance docs claim it is 'twice as fast as the next best' terminal in throughput (134.55 MB/s vs gnome-terminal 61.83 MB/s) - this is a self-reported benchmark with acknowledged methodological caveats (rendering suppressed, uneven feature support), so treat as vendor-favorable rather than neutral.
- *Finding:* All elements of the claim are directly supported by kitty's official performance documentation (sw.kovidgoyal.net/kitty/performance), which is self-published by kitty's author Kovid Goyal. The docs state verbatim "kitty is twice as fast as the next best" and list kitty 0.33 at 134.55 MB/s average throughput versus gnome-terminal 3.50.1 at 61.83 MB/s. The methodological caveats are explicitly acknowledged: (1) the benchmark kitten by default suppresses actual rendering "to better focus on parser speed"; (2) gnome-terminal, konsole and xterm do not support the Synchronized update escape code used to suppress rendering, and "if and when they gain support for it their numbers are likely to improve by 20-50%"; (3) uneven feature support is noted (e.g., Alacritty "isn't remotely comparable to any of the other terminals feature wise without tmux"). Measurements used the same font, font size, window size, default settings, and same computer. One minor nuance: this is a true/throughput-only benchmark of parser speed, not a holistic real-world performance measure, and the figures are version-specific (kitty 0.33), so they may shift with releases. Treating the benchmark as vendor-favorable rather than neutral is appropriate given it is published by the project itself.
- *Sources:* https://sw.kovidgoyal.net/kitty/performance/; https://github.com/kovidgoyal/kitty/blob/master/docs/performance.rst


**✅ CONFIRMED — kitty**

- *Claim:* Claim that kitty has 'best-in-class' keyboard-to-screen latency - true in some third-party Linux Typometer tests, but on macOS it reportedly only ties Apple Terminal.app, and 2025-2026 reviews show Ghostty/Alacritty as roughly equal, so 'best' is contested/context-dependent.
- *Finding:* The claim is accurate and, if anything, understates how contested "best-in-class" is. Key nuances: (1) The "best-in-class" / "far and away the best" framing originates primarily from kitty's OWN documentation (sw.kovidgoyal.net/kitty/performance), which cites unspecified third-party Typometer measurements rather than being an independent consensus. (2) The macOS "tie" is also self-reported by kitty's docs: "kitty and Apple's Terminal.app share the crown for best latency" (measured at default input_delay of 3ms). (3) 2025-2026 reviews consistently place kitty, Alacritty, Ghostty and foot in a single "fastest" cohort with only ~5-15% differences that are imperceptible in real use; some give Ghostty a slight edge (~2ms key-to-screen). (4) Critically, at least one independent third-party Linux benchmark (beuke.org) directly contradicts "best-in-class": it measured Alacritty at ~6.9ms, xterm ~5.3ms, st ~5.2ms, versus kitty ~23.8ms in default config and ~10.7ms even when tuned -- i.e., kitty ranked behind several competitors. So "best" is genuinely context-dependent (default vs tuned config, OS, measurement method) and partly a vendor self-claim.
- *Sources:* https://sw.kovidgoyal.net/kitty/performance/; https://beuke.org/terminal-latency/; https://github.com/ghostty-org/ghostty/discussions/4837; https://blog.codeminer42.com/modern-terminals-alacritty-kitty-and-ghostty/; https://www.lkhrs.com/blog/2022/07/terminal-latency/; https://news.ycombinator.com/item?id=39967335


---

**✅ CONFIRMED — Alacritty**

- *Claim:* Reviews claim Alacritty is 'the fastest and lightest terminal' with the lowest input latency on macOS — this is benchmark-dependent and contested; the project's own FAQ only claims better vtebench throughput, not universally lowest latency.
- *Finding:* The claim is accurate. The Alacritty project's own README/FAQ deliberately avoids declaring itself universally fastest or lowest-latency. It states only: "Alacritty uses vtebench to quantify terminal emulator throughput and manages to consistently score better than the competition using it," while explicitly cautioning that "Benchmarking terminal emulators is complicated" and that latency, framerate, and frame consistency are harder to quantify and not captured by vtebench (which measures only PTY read throughput). The vtebench README itself notes it "is not sufficient to get a general understanding of the performance of a terminal emulator" and "lacks support for ... frame rate or latency." Independent measurements contradict any "lowest input latency on macOS" claim: Dan Luu's terminal-latency study found Alacritty around ~31ms median idle latency versus ~6ms for Terminal.app and ~5ms for emacs-eshell, placing Alacritty among the noticeably-laggy group (with st, hyper, iterm2), not the fastest. Other reviews rank kitty, Terminal.app, and WezTerm ahead of Alacritty on input latency, with Ghostty and Kitty considered effectively as fast in real-world use. So input-latency leadership is both benchmark-dependent and contested, exactly as the claim states; Alacritty's strongest defensible claim is throughput (vtebench) plus low memory footprint, not lowest latency.
- *Sources:* https://github.com/alacritty/alacritty; https://github.com/alacritty/vtebench/blob/master/README.md; https://danluu.com/term-latency/; https://www.lkhrs.com/blog/terminal-latency/


**❌ REFUTED — Alacritty**

- *Claim:* Alacritty has the most GitHub stars of any terminal emulator.
- *Finding:* As of 2026-06-27 (live GitHub API counts), Alacritty has ~64,686 stars. This is NOT the most of any terminal emulator: Microsoft's Windows Terminal (microsoft/terminal) has ~103,727 stars, well ahead of Alacritty. The claim is therefore false in absolute terms. A narrower, defensible statement: among lightweight cross-platform GPU-accelerated terminal emulators, Alacritty currently still leads Ghostty (~57,179 stars), but Ghostty has been growing rapidly and the gap (~7.5k) has narrowed substantially, so the lead is time-sensitive. Other emulators: kitty ~33,630, iTerm2 ~17,751.
- *Sources:* https://api.github.com/repos/alacritty/alacritty; https://api.github.com/repos/microsoft/terminal; https://api.github.com/repos/ghostty-org/ghostty; https://api.github.com/repos/kovidgoyal/kitty; https://github.com/ghostty-org/ghostty; https://bundl.run/compare/ghostty-vs-alacritty


---

**✅ CONFIRMED — WezTerm**

- *Claim:* WezTerm's first public release date is inconsistent across sources (one claimed Sept 4, 2022, while GitHub release tags exist from 2019) — verify the actual earliest release.
- *Finding:* The verifiable core of the claim holds: WezTerm GitHub tags do exist from 2019, so any "Sept 4, 2022" first-release date is wrong. Querying the repo directly (git ls-remote --tags github.com/wezterm/wezterm), the earliest dated tags are from March 24, 2019: 20190324-160658, 20190324-175217, 20190324-182322, followed by more tags throughout 2019 (e.g. 20190507, 20190520, 20190602, 20190622, 20190623, 20190626, 20191124, 20191218, 20191229). WezTerm uses a date-stamped versioning scheme (YYYYMMDD-HHMMSS-githash), so the tag name itself encodes the release date. Note: the official wezterm.org changelog only documents releases back to 20191124-233250 (Nov 24, 2019), but actual tags/builds go back to March 24, 2019. The repo's own git history (initial commits) predates that. A "September 4, 2022" date does not correspond to any first release and is refuted as the earliest. Earliest tagged release: 20190324-160658 (March 24, 2019).
- *Sources:* https://github.com/wezterm/wezterm/tags; https://github.com/wezterm/wezterm/releases; https://wezterm.org/changelog.html; https://wezterm.org/config/lua/wezterm/version.html


**❌ REFUTED — WezTerm**

- *Claim:* WezTerm's last stable release was February 2024, and the project is effectively in spare-time/nightly-only maintenance limbo and possibly abandoned (as of 2026).
- *Finding:* The claim is mixed: one part is true, but the central "possibly abandoned / limbo" framing is false. TRUE part: the last tagged STABLE release is indeed 20240203-110809-5046fc22, dated February 3, 2024, and it is still marked "Latest" stable as of June 2026 — so there has been no new versioned stable release in ~2.4 years. However, "possibly abandoned / maintenance limbo" is REFUTED by primary evidence: the project is actively developed. The GitHub main branch shows frequent commits merged from many contributors, including commits dated June 27, 2026 (the day of this check) and a steady stream through June 2026. A continuously-built "nightly" prerelease is published and was last updated June 27, 2026, with fresh artifacts across macOS, Fedora, CentOS, Alpine, and Android. The maintainer (wez) explicitly documents that the bleeding-edge/nightly build is rebuilt continuously and is "usually the best available version" because he daily-drives it. Accurate framing: WezTerm follows a rolling/nightly release model with an infrequent stable-tag cadence (the stable tag has been stale since Feb 2024), but the codebase is under active, ongoing development — not abandoned. Community issues (e.g., #7299, #7451) ask about the long gap between tagged releases, but that reflects release-tagging cadence, not project inactivity.
- *Sources:* https://wezterm.org/changelog.html; https://github.com/wezterm/wezterm/releases; https://api.github.com/repos/wezterm/wezterm/releases/tags/nightly; https://api.github.com/repos/wezterm/wezterm/commits?per_page=5; https://github.com/wezterm/wezterm/issues/7299; https://github.com/wezterm/wezterm/issues/7451


---

**✅ CONFIRMED — Warp**

- *Claim:* Warp scored 75.6% on SWE-bench Verified in November 2025, claimed top-5 among AI dev tools — a self-reported, version-sensitive benchmark to verify independently
- *Finding:* The 75.6% figure is accurate and appears in Warp's own "2025 in Review" post tied to the Agents 3.0 release in November 2025 ("75.6% on SWE-bench Verified", alongside 61.2% on Terminal-Bench). The framing is correct: it is self-reported by Warp and version-sensitive. One nuance: Warp reported several different scores over 2025 — 71% (June 23, 2025, explicitly described as "top 5 on the leaderboard"), 75.8% (September 1, 2025, described as roughly #3), and 75.6% (November 2025, Agents 3.0). So the 75.6% is slightly LOWER than the earlier 75.8% September figure, underscoring the version-sensitivity. The "top-5" characterization is supported by Warp's own leaderboard claims. All scores are self-reported on Warp's blog rather than from an independent third-party evaluation of Warp's agent, so the call to verify independently is well-founded.
- *Sources:* https://www.warp.dev/blog/2025-in-review; https://www.warp.dev/blog/swe-bench-verified-update; https://www.warp.dev/blog/swe-bench-verified; https://www.swebench.com/verified.html


**✅ CONFIRMED — Warp**

- *Claim:* 'Fully native' Metal-rendered Mac app, yet uses ~300-500 MB RAM (Electron-like) — the 'lightweight native' framing is contestable
- *Finding:* Both factual halves check out, but two nuances matter. (1) The "fully native / Metal / no Electron" part is literally Warp's own marketing: their launch post is titled "Warp is a fully native, GPU-accelerated, Rust-based terminal. No Electron," and their engineering blog confirms a custom Rust UI framework rendering via Metal on macOS (Vulkan/DirectX elsewhere). This architecture is genuinely NOT Electron/Chromium — so "Electron-like" applies only to the RAM footprint, not the technical design. (2) The 300-500 MB figure is real and documented in numerous official GitHub issues, but it is the higher/regressed end rather than a universal baseline. Reported idle usage starts around ~100 MB on a fresh launch and ~200 MB after a day with a few tabs; a v0.2025.10.29 regression pushed idle usage from ~100 MB to 500 MB+, and worse memory-leak bugs (3.6 GB, even 113 GB) have been filed. Warp maintainers themselves discuss a target budget of "RSS under 500 MB with 4 panes idle," implicitly acknowledging that 300-500 MB is heavier than ideal for a terminal. So the critique that the "lightweight native" framing is contestable is fair: Warp is authentically native but its memory footprint is in Electron-app territory.
- *Sources:* https://news.ycombinator.com/item?id=30922442; https://www.warp.dev/blog/how-warp-works; https://github.com/warpdotdev/Warp/issues/7938; https://github.com/warpdotdev/Warp/issues/2611; https://github.com/warpdotdev/warp/issues/9595; https://github.com/warpdotdev/warp/issues/7520; https://github.com/warpdotdev/Warp/issues/7892


---

**✅ CONFIRMED — Rio Terminal**

- *Claim:* First-party performance framing that Rio 'is fast' / high-performance — no independent benchmark found showing it beats Alacritty/Kitty/WezTerm; treat speed claims as marketing.
- *Finding:* The claim holds on all three parts. (1) The "fast/high-performance" framing is first-party and unquantified: rioterm.com states "The Rio has fast performance, leveraging the latest technologies including Rust and advanced rendering architectures" and markets it as a "hardware-accelerated GPU terminal emulator," with no benchmark data, comparative numbers, or methodology on either the homepage or the GitHub README. (2) No independent benchmark was found showing Rio beats Alacritty, Kitty, or WezTerm. The most cited independent latency/throughput benchmarks (beuke.org, lkhrs.com, danluu.com) test Alacritty/Kitty/WezTerm/foot/etc. but do NOT include Rio at all. (3) Where Rio is mentioned in comparisons, the assessment is that it does not lead: a Terminal Trove comparison summary states Rio (Rust on a WebGPU backend) does not beat Alacritty or Kitty in performance comparisons. Nuance worth noting: absence of an independent benchmark beating the others is not proof Rio is slow — it simply means the vendor's speed claim is unsubstantiated by neutral testing, so treating it as marketing is appropriate. The architectural basis (Rust + WGPU/WebGPU GPU rendering) is real, but architecture is not a measured performance result.
- *Sources:* https://rioterm.com/; https://github.com/raphamorim/rio; https://beuke.org/terminal-latency/; https://www.lkhrs.com/blog/2022/07/terminal-latency/; https://danluu.com/term-latency/; https://terminaltrove.com/compare/terminals/; https://terminaltrove.com/terminals/rio-terminal/; https://github.com/alacritty/vtebench


**✅ CONFIRMED — Rio Terminal**

- *Claim:* The 'consistent 60+ FPS' and 'lower overhead, better integration' from the March 2026 native-Metal blog post — first-party and version-sensitive (tied to recent 0.3.x/0.4.x releases).
- *Finding:* The phrasing is accurate but one detail should be tightened. The quotes come from Rio's own (first-party) blog post "What's coming next?" dated 2026-03-11 at rioterm.com, which states verbatim: "Metal support: Rio now runs natively on Metal, Apple's GPU API. This means lower overhead and better integration on macOS." and "Consistent 60+ FPS: Even when hammering the terminal with empty line breaks, Rio now maintains at least a consistent 60fps." The blog post itself does NOT cite a version number (it refers only to "the next version of Rio"). The native Metal backend (renderer.backend = metal) was actually introduced in the 0.4.0 release as part of a major renderer rewrite, with refinements in later 0.4.x releases (e.g., 0.4.2 transparency). So it is genuinely version-sensitive, but specifically a 0.4.x feature; attributing it to 0.3.x is inaccurate. With that one caveat, the claim is supported.
- *Sources:* https://rioterm.com/blog/2026/03/11/whats-coming-next; https://rioterm.com/changelog; https://github.com/raphamorim/rio/releases


---

**✅ CONFIRMED — Wave Terminal**

- *Claim:* Wave Terminal markets SSH sessions as "durable" that "survive connection interruptions, network changes, and Wave restarts."
- *Finding:* The marketing claim is accurate as a description of what Wave Terminal officially states. Wave's own documentation (Durable Sessions, introduced in v0.14) uses essentially this exact language: durable sessions "allow your remote terminal sessions to survive connection interruptions, network changes, and Wave restarts," maintaining shell state, running programs, and full scrollback. The mechanism is a lightweight Go-based "job manager" launched on the remote host that keeps the shell running independently and communicates over Unix domain sockets through the existing SSH connection (no extra open ports) — conceptually similar to built-in tmux/screen. So this is a verified vendor claim, not marketing puffery beyond what is documented. Important caveats the bare claim omits: (1) durable sessions are DISABLED BY DEFAULT and must be opted into via config (global/per-connection/per-block); (2) they apply ONLY to remote SSH connections — local terminals and WSL use standard, non-durable sessions; (3) switching between standard and durable mode RESTARTS the shell and terminates running processes; (4) sessions still end when you close the block, switch connections, or delete the workspace/tab; (5) durability is not absolute — sessions can be "Lost" if the remote server reboots or the job manager process is killed, and reconnection requires a working SSH connection plus a resync of buffered output. The author's instinct that it is "worth testing how robust reconnection actually is in practice" is reasonable: the documented behavior is plausible and matches the architecture, but the guarantees are bounded (e.g., a server reboot loses the session), and this is a relatively new feature, so empirical reliability across flaky networks/sleep/updates is the appropriate thing to validate.
- *Sources:* https://docs.waveterm.dev/durable-sessions; https://docs.waveterm.dev/connections; https://docs.waveterm.dev/releasenotes; https://github.com/wavetermdev/waveterm


**✅ CONFIRMED — Wave Terminal**

- *Claim:* Wave Terminal release notes claim that Wave AI (v0.12, Nov/Dec 2025) was 'powered by GPT-5' and later 'GPT-5.1 with thinking modes' - version/date-sensitive and tied to OpenAI model availability.
- *Finding:* Substantially accurate, with a minor date refinement. Wave Terminal's official release notes (docs.waveterm.dev/releasenotes) state for v0.12.0: "Wave Terminal v0.12.0 introduces a completely redesigned AI experience powered by OpenAI GPT-5." That release was dated October 16, 2025 (the v0.12 series, not strictly Nov/Dec). The GPT-5.1 + thinking modes part lands in v0.12.3 (dated November 17, 2025), which notes upgrading to OpenAI's GPT-5.1 model and adds a "Thinking Mode Toggle" with Quick/Balanced/Deep modes. So the GPT-5.1/thinking-modes change is the Nov 2025 update, while the initial GPT-5 launch was October 2025. The claim is therefore confirmed in substance; the only nuance is that v0.12.0's GPT-5 launch was October 2025 rather than Nov/Dec, with GPT-5.1 arriving mid-November 2025. The claim is indeed version/date-sensitive and tied to OpenAI model availability (earlier v0.11.x notes reference GPT-5 support in Aug 2025 and a gpt-5-mini cloud proxy).
- *Sources:* https://docs.waveterm.dev/releasenotes; https://github.com/wavetermdev/waveterm/releases/tag/v0.12.0; https://github.com/wavetermdev/waveterm/releases


---

**✅ CONFIRMED — Hyper**

- *Claim:* Hyper bills itself as a terminal 'built on open web standards' aiming to be 'the simplest, most powerful and well-tested interface' — a marketing claim contested by reviewers who cite its Electron performance penalties.
- *Finding:* Both phrases are accurate quotes from Hyper's official site. Its Project Goals section states the experience is "built on open web standards" and aspires to "what could be the simplest, most powerful and well-tested interface for productivity." Minor nuance: these are framed as aspirational "project goals" rather than a literal product tagline/slogan, but "bills itself" is a fair characterization. Reviewers do contest performance: Slant and others note Hyper's Electron foundation causes higher input latency, slower rendering of large output, and high memory/resource usage that degrades further with plugins.
- *Sources:* https://hyper.is/; https://github.com/vercel/hyper; https://www.slant.co/options/18898/~hyper-review; https://dev.to/_d7eb1c1703182e3ce1782/best-terminal-emulators-compared-iterm2-warp-alacritty-windows-terminal-and-more-3f6; https://news.ycombinator.com/item?id=16900941


**✅ CONFIRMED — Hyper**

- *Claim:* The latest stable release of Hyper is v3.4.1 dated January 8, 2023, implying the project has been largely dormant for ~3+ years.
- *Finding:* Accurate as stated, with one clarification. Per the GitHub API, v3.4.1 (prerelease=false) was published 2023-01-08T00:56:10Z, so January 8, 2023 is correct and it is the most recent STABLE release. There is no newer stable release. The only newer tags are pre-release/canary builds toward v4 (v4.0.0-canary.1 through canary.5), the last being v4.0.0-canary.5 on 2023-07-13. So even counting prereleases, the last published release was mid-2023, ~3 years before the current date (2026-06-27). The dormancy characterization is well supported (community has even opened an 'Is Hyper dead?' issue).</correction>
<parameter name="sources">["https://api.github.com/repos/vercel/hyper/releases", "https://github.com/vercel/hyper/releases", "https://github.com/vercel/hyper/issues/8101"]
