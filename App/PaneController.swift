import AppKit
import CoreGraphics
import SwiftTerm
import XttyCore

/// What a `PaneController` reports back to its owner (the window/tab controller).
@MainActor
protocol PaneControllerDelegate: AnyObject {
    /// The pane's shell process exited (exit policy + tree collapse live in the owner).
    func paneDidTerminate(_ pane: PaneController, exitCode: Int32?)
    /// The pane's terminal title changed (drives the window/tab title when focused).
    func paneDidUpdateTitle(_ pane: PaneController, title: String)
    /// The pane requests a split alongside itself along `axis`.
    func paneRequestsSplit(_ pane: PaneController, axis: SplitAxis)
    /// The pane requests to be closed (the owner collapses + escalates).
    func paneRequestsClose(_ pane: PaneController)
    /// The pane requests focus move to a neighbor.
    func paneRequestsFocusMove(_ pane: PaneController, direction: FocusDirection)
    /// The pane requests a new tab / new window.
    func paneRequestsNewTab(_ pane: PaneController)
    func paneRequestsNewWindow(_ pane: PaneController)
    /// A foreground command finished in the pane (OSC 133 `D`) — drives the
    /// git-review panel's command-finish refresh (P6a).
    func paneDidFinishCommand(_ pane: PaneController)
}

/// Owns one terminal pane: a single `XttyTerminalView` (its own PTY + shell +
/// engine) wrapped as an `XttyCore.Pane` / `TerminalSession`, acting as the
/// view's `LocalProcessTerminalViewDelegate`.
///
/// This is the per-view unit the P3 decomposition extracts from the old
/// monolithic window controller: a window/tab now owns a *tree* of these (see
/// `TerminalWindowController`). The DEBUG harness dump lives here too, so each
/// pane can report its own engine grid + state.
@MainActor
final class PaneController: NSObject, LocalProcessTerminalViewDelegate, XttyTerminalViewCommands {
    let view: XttyTerminalView
    /// The model handle registered in the `SessionRegistry` (identity + session).
    let pane: Pane
    /// The profile this pane launched with, retained so a split can inherit it
    /// (the new pane relaunches with the same appearance + launch overrides).
    let profile: XttyProfile

    private let session: TerminalSession
    private let registry: SessionRegistry
    weak var delegate: PaneControllerDelegate?
    private var processEnded = false

    /// Intercepts `requestOpenLink` so clicked file/URL links route through xtty
    /// (file:line → editor, scheme guard) instead of SwiftTerm's default opener.
    /// Retained here because the view holds `terminalDelegate` weakly (design D1).
    private var linkDelegate: LinkRoutingTerminalDelegate?

    /// The last resolved link-open action, surfaced in the DEBUG state dump.
    private(set) var lastLinkOpen: LinkOpenResolution?

    /// The last jump-to-prompt target display row (P4b-2), or `nil` when the last
    /// jump was a no-op (no anchored target / provider unavailable). DEBUG dump.
    private(set) var lastJumpTargetRow: Int?

    /// The last copy-command-output text (P4b-2), or `nil` when the last copy was a
    /// no-op. DEBUG dump (so the harness asserts without reading the real clipboard).
    private(set) var lastCopiedOutput: String?

    /// A safe fallback profile (base appearance + plain login shell), used only
    /// when a focused pane can't be found for split inheritance.
    static let baseProfile = XttyProfile(name: nil, config: .default, launch: .none)

    /// Lowercased names that denote the local machine, so an OSC 7 cwd reported by
    /// the local host is treated as a local path and a foreign host (e.g. over ssh)
    /// is flagged remote. Computed once.
    static let localHostNames: Set<String> = {
        var names: Set<String> = ["", "localhost"]
        let host = ProcessInfo.processInfo.hostName.lowercased()  // e.g. marks-mbp.local
        names.insert(host)
        if let short = host.split(separator: ".").first { names.insert(String(short)) }
        return names
    }()

    #if DEBUG
    /// DEBUG-only live-instance count for the P7c lifecycle census (absent in
    /// release). `nonisolated(unsafe)` so the nonisolated `deinit` can decrement
    /// it; created/destroyed on the main thread, the same vouch `GlobalHotKey`
    /// documents for its Carbon refs.
    nonisolated(unsafe) static var liveCount = 0
    #endif

    init(profile: XttyProfile, registry: SessionRegistry, frame: NSRect, startDirectory: String? = nil) {
        // Build everything via locals first — `self` is unavailable before super.init.
        let view = XttyTerminalView(frame: frame)
        // Resolve the launch from the profile's overrides: a `command` runs through
        // the user's login+interactive shell (so PATH/dotfiles apply), else a plain
        // login shell; `cwd`/`env` are applied here too (design D4/D5/D6).
        var launch = ShellResolver.resolve(
            override: profile.launch,
            integrationDir: ShellIntegration.zshDirectory
        ) {
            NSLog("[xtty] profile '%@': %@", profile.name ?? "base", $0)
        }
        // A split passes the focused pane's live cwd, overriding the profile's
        // static start directory so the new pane opens where the user is working.
        if let startDirectory { launch = launch.withWorkingDirectory(startDirectory) }
        let session = TerminalSession(terminal: view.getTerminal(), launchConfig: launch)
        let pane = registry.makePane(for: session, profileName: profile.name)

        self.view = view
        self.session = session
        self.pane = pane
        self.profile = profile
        self.registry = registry
        super.init()

        #if DEBUG
        // Lifecycle census (P7c): count this controller and its (view-free)
        // session here, from the main actor, so XttyCore stays isolation-free (D2).
        Self.liveCount += 1
        TerminalSession.recordInit()
        #endif

        view.processDelegate = self
        view.commands = self
        view.configuredFontSize = CGFloat(profile.config.fontSize)

        // Route clicked links through xtty: replace the view's `terminalDelegate`
        // (the view itself) with a proxy that forwards everything back except
        // `requestOpenLink`, which we handle (file:line → editor + scheme guard).
        let linkDelegate = LinkRoutingTerminalDelegate(forwardingTo: view) { [weak self] link, _ in
            MainActor.assumeIsolated { self?.openLink(link) }
        }
        // Sample liveTop on scroll (P4b-2): catches a clear/reset between OSC marks
        // for anchor invalidation. No-op in Phase 1 (the seam returns nil).
        linkDelegate.onScrolled = { [weak self] _ in
            MainActor.assumeIsolated { self?.sampleLiveTop() }
        }
        view.terminalDelegate = linkDelegate
        self.linkDelegate = linkDelegate

        // Semantic capture (P4a). Alternate-screen transitions gate block-building;
        // the OSC 133 handler feeds the per-session block tracker. Both fire on the
        // engine's main feed path (assumeIsolated is safe — see design D1).
        view.onBufferActivated = { [weak self] isAlternate in
            guard let self else { return }
            self.session.setAlternateScreen(isAlternate)
            // Alt-screen flips the session activity (→ fullScreen / back); refresh
            // the sidebar (event-driven, on the main feed thread — see design D5).
            self.registry.noteActivityChange()
        }
        view.getTerminal().registerOscHandler(code: 133) { [weak self] data in
            guard let mark = OSC133.parse(String(decoding: data, as: UTF8.self)) else { return }
            MainActor.assumeIsolated {
                guard let self else { return }
                // Reset detection before capture, so the new anchor (P4b-2) is
                // stamped with the post-bump epoch. Then capture the trim-invariant
                // cursor row through the seam (nil in Phase 1 → no anchor).
                self.session.blocks.noteLiveTop(self.engineLiveTop())
                self.session.handleSemanticMark(mark, row: self.engineScrollRow())
                // A command boundary (running ↔ finished) changes the activity;
                // signal the observable registry so the sidebar re-renders.
                self.registry.noteActivityChange()
                // A finished command may have changed files — refresh git review
                // (debounced + gated downstream, so this stays cheap).
                if case .commandEnd = mark.action { self.delegate?.paneDidFinishCommand(self) }
            }
        }

        // Apply config (font / theme palette / bounded scrollback / option-as-meta)
        // before the shell starts so the initial PTY size + appearance reflect it.
        TerminalConfigurator.apply(profile.config, to: view)

        // Accessibility: locate-only. The custom-drawn view exposes no per-cell
        // text, so UI tests assert content via the DEBUG dump, not the AX tree.
        view.setAccessibilityElement(true)
        view.setAccessibilityRole(.textArea)
        view.setAccessibilityLabel("Terminal")
        view.setAccessibilityIdentifier("xtty.terminal")

        // A non-nil array replaces the child environment wholesale (ShellResolver
        // seeds the identity vars; the login shell builds PATH from dotfiles).
        let environment = launch.environment.map { "\($0.key)=\($0.value)" }
        view.startProcess(
            executable: launch.executable,
            args: launch.args,
            environment: environment,
            execName: launch.execName,
            currentDirectory: launch.cwd
        )
    }

    deinit {
        #if DEBUG
        // Lifecycle census (P7c): mirror init — decrement on actual deallocation
        // (not on `terminate()`, which is logical teardown, not dealloc).
        Self.liveCount -= 1
        TerminalSession.recordDeinit()
        #endif
    }

    /// Terminate the child (unless already exited) and unregister from the model.
    /// Safe to call multiple times.
    func terminate() {
        if !processEnded {
            processEnded = true
            view.terminate()
        }
        registry.unregister(pane.id)
    }

    // MARK: LocalProcessTerminalViewDelegate
    //
    // SwiftTerm invokes these on the main thread; `nonisolated` satisfies the
    // (non-isolated) protocol from this `@MainActor` class, and `assumeIsolated`
    // lets us touch main-actor state safely.

    nonisolated func processTerminated(source: TerminalView, exitCode: Int32?) {
        MainActor.assumeIsolated {
            processEnded = true
            session.recordExit(code: exitCode)
            delegate?.paneDidTerminate(self, exitCode: exitCode)
        }
    }

    nonisolated func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {
        // Resize/reflow shifts buffer line indices without dropping linesTop, so
        // every stored anchor would silently mis-resolve — invalidate them all
        // (P4b-2, design D3). Fires after the reflow, before any later keypress.
        MainActor.assumeIsolated { session.blocks.bumpEpoch() }
    }

    nonisolated func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        MainActor.assumeIsolated { delegate?.paneDidUpdateTitle(self, title: title) }
    }

    // OSC 7 cwd capture: SwiftTerm's built-in handler stores the raw URL and fires
    // this delegate (trust-gated; we deliberately do not register a custom OSC 7
    // handler). Decode it and record the per-session live cwd.
    nonisolated func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
        MainActor.assumeIsolated {
            guard let directory,
                  let wd = OSC7.decode(directory, localHostNames: PaneController.localHostNames)
            else { return }
            session.updateWorkingDirectory(wd)
        }
    }

    /// This pane's headless engine (read by the window controller's DEBUG dump).
    var engine: Terminal { view.getTerminal() }

    // MARK: File/URL link opening (P4b-1)

    /// Resolve a clicked link against this session's live local cwd + the profile's
    /// `link-opener` template (all view-free in `XttyCore.LinkRouter`). Pure.
    func resolveLink(_ link: String) -> LinkOpenResolution {
        LinkRouter.resolve(
            link: link,
            localCwd: session.liveLocalDirectory,
            opener: profile.config.linkOpener,
            environment: ProcessInfo.processInfo.environment
        )
    }

    /// Route a clicked link: resolve, record (for the DEBUG dump), then perform
    /// the side effect (editor / system opener), or log a blocked/unresolved one.
    func openLink(_ link: String) {
        let resolution = resolveLink(link)
        lastLinkOpen = resolution
        FileOpener.perform(resolution)
    }

    #if DEBUG
    /// XCUITest hook: resolve a synthetic link through the real pipeline + the live
    /// cwd and record it for the state dump, WITHOUT launching an editor.
    func routeTestLink(_ link: String) {
        lastLinkOpen = resolveLink(link)
    }
    #endif

    // MARK: Spatial blocks (P4b-2) — scroll-coordinate seam + jump + copy

    // The trim-invariant absolute cursor row + scrollback base come from the
    // SwiftTerm engine accessors added via the pinned submodule + drop-in
    // (scripts/bootstrap-swiftterm.sh; see the fork-vs-patch research doc). These
    // were the Phase-1 nil seam; lit up in Phase 2 to read the real accessors.
    private func engineScrollRow() -> Int? { engine.getScrollInvariantCursorLocation().row }
    private func engineScrollbackBase() -> Int? { engine.scrollbackBase }

    /// liveTop = yBase + linesTop = (scroll-invariant cursor row) − (yBase-relative
    /// cursor y, public). `nil` when the provider is unavailable (Phase 1).
    private func engineLiveTop() -> Int? {
        engineScrollRow().map { $0 - engine.getCursorLocation().y }
    }

    /// Sample liveTop for reset detection (called from the scroll hook).
    private func sampleLiveTop() {
        session.blocks.noteLiveTop(engineLiveTop())
    }

    /// The absolute prompt rows of anchored, still-valid blocks (jump targets).
    private var validPromptRows: [Int] {
        let tracker = session.blocks
        return tracker.blocks.compactMap { block in
            guard let anchor = block.anchor, tracker.anchorIsValid(anchor) else { return nil }
            return anchor.promptRow
        }
    }

    /// Scroll the viewport to the previous/next command prompt (P4b-2). Viewport
    /// only — never moves the cursor or a selection. No-op (recorded) when the
    /// coordinate provider is unavailable or there is no anchored target.
    func jumpToPrompt(_ direction: BlockNavigation.JumpDirection) {
        lastJumpTargetRow = nil
        guard let base = engineScrollbackBase() else { return }  // provider unavailable
        let currentTop = engine.getTopVisibleRow() + base
        guard let targetAbs = BlockNavigation.jumpTargetRow(
            promptRows: validPromptRows, currentTopAbsolute: currentTop, direction: direction
        ) else { return }  // no prompt in that direction
        let row: Int
        switch BlockNavigation.displayRow(forAbsolute: targetAbs, scrollbackBase: base) {
        case .row(let r): row = r
        case .trimmedOut: row = 0  // clamp to top
        }
        view.scrollTo(row: row)
        lastJumpTargetRow = row
    }

    /// Copy the focused/last command's output (or the running command's output so
    /// far) to the clipboard, excluding the trailing prompt (P4b-2). Engine-only
    /// (`getText` → pasteboard, no on-screen selection). No-op (recorded) on an
    /// invalid/trimmed anchor or an unavailable provider.
    func copyCommandOutput() {
        lastCopiedOutput = nil
        let tracker = session.blocks
        guard let block = tracker.runningBlock ?? tracker.blocks.last,
              let anchor = block.anchor, tracker.anchorIsValid(anchor),
              let base = engineScrollbackBase(),
              let range = BlockNavigation.outputRowRange(anchor: anchor, liveEnd: engineScrollRow()),
              case let .row(startRow) = BlockNavigation.displayRow(forAbsolute: range.start, scrollbackBase: base),
              case let .row(endRow) = BlockNavigation.displayRow(forAbsolute: range.end, scrollbackBase: base)
        else { return }
        let lastCol = max(engine.cols - 1, 0)
        let text = engine.getText(start: Position(col: 0, row: startRow), end: Position(col: lastCol, row: endRow))
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        lastCopiedOutput = text
        showToast("Copied output")
    }

    /// A transient, non-modal confirmation overlaid on the pane (never blocks
    /// input). Used to confirm what copy-command-output grabbed (the fork-free
    /// substitute for a visual selection — design D7).
    private func showToast(_ message: String) {
        SpatialToast.show(message, over: view)
    }

    #if DEBUG
    /// XCUITest hooks: drive jump/copy through the real pipeline so the harness can
    /// assert the resolved target / copied text from the state dump.
    func jumpToPromptForTest(previous: Bool) { jumpToPrompt(previous ? .previous : .next) }
    func copyCommandOutputForTest() { copyCommandOutput() }
    #endif

    // MARK: XttyTerminalViewCommands (forward the focused view's intent to the owner)

    func splitPane(axis: SplitAxis) { delegate?.paneRequestsSplit(self, axis: axis) }
    func closePane() { delegate?.paneRequestsClose(self) }
    func moveFocus(_ direction: FocusDirection) { delegate?.paneRequestsFocusMove(self, direction: direction) }
    func newTab() { delegate?.paneRequestsNewTab(self) }
    func newWindow() { delegate?.paneRequestsNewWindow(self) }
}
