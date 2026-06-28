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

    /// A safe fallback profile (base appearance + plain login shell), used only
    /// when a focused pane can't be found for split inheritance.
    static let baseProfile = XttyProfile(name: nil, config: .default, launch: .none)

    init(profile: XttyProfile, registry: SessionRegistry, frame: NSRect) {
        // Build everything via locals first — `self` is unavailable before super.init.
        let view = XttyTerminalView(frame: frame)
        // Resolve the launch from the profile's overrides: a `command` runs through
        // the user's login+interactive shell (so PATH/dotfiles apply), else a plain
        // login shell; `cwd`/`env` are applied here too (design D4/D5/D6).
        let launch = ShellResolver.resolve(override: profile.launch) {
            NSLog("[xtty] profile '%@': %@", profile.name ?? "base", $0)
        }
        let session = TerminalSession(terminal: view.getTerminal(), launchConfig: launch)
        let pane = registry.makePane(for: session, profileName: profile.name)

        self.view = view
        self.session = session
        self.pane = pane
        self.profile = profile
        self.registry = registry
        super.init()

        view.processDelegate = self
        view.commands = self
        view.configuredFontSize = CGFloat(profile.config.fontSize)

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

    nonisolated func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

    nonisolated func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        MainActor.assumeIsolated { delegate?.paneDidUpdateTitle(self, title: title) }
    }

    // OSC 7 cwd capture is P4; ignore here.
    nonisolated func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

    /// This pane's headless engine (read by the window controller's DEBUG dump).
    var engine: Terminal { view.getTerminal() }

    // MARK: XttyTerminalViewCommands (forward the focused view's intent to the owner)

    func splitPane(axis: SplitAxis) { delegate?.paneRequestsSplit(self, axis: axis) }
    func closePane() { delegate?.paneRequestsClose(self) }
    func moveFocus(_ direction: FocusDirection) { delegate?.paneRequestsFocusMove(self, direction: direction) }
    func newTab() { delegate?.paneRequestsNewTab(self) }
    func newWindow() { delegate?.paneRequestsNewWindow(self) }
}
