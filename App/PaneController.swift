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
final class PaneController: NSObject, LocalProcessTerminalViewDelegate {
    let view: XttyTerminalView
    /// The model handle registered in the `SessionRegistry` (identity + session).
    let pane: Pane

    private let session: TerminalSession
    private let config: XttyConfig
    private let registry: SessionRegistry
    weak var delegate: PaneControllerDelegate?
    private var processEnded = false

    #if DEBUG
    private var gridDumpTimer: Timer?
    private static let gridDumpPath = "/tmp/xtty-grid-dump.txt"
    private static let stateDumpPath = "/tmp/xtty-state-dump.json"
    #endif

    init(config: XttyConfig, registry: SessionRegistry, frame: NSRect) {
        // Build everything via locals first — `self` is unavailable before super.init.
        let view = XttyTerminalView(frame: frame)
        let launch = ShellResolver.resolve()
        let session = TerminalSession(terminal: view.getTerminal(), launchConfig: launch)
        let pane = registry.makePane(for: session)

        self.view = view
        self.session = session
        self.pane = pane
        self.config = config
        self.registry = registry
        super.init()

        view.processDelegate = self
        view.configuredFontSize = CGFloat(config.fontSize)

        // Apply config (font / theme palette / bounded scrollback / option-as-meta)
        // before the shell starts so the initial PTY size + appearance reflect it.
        TerminalConfigurator.apply(config, to: view)

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
            execName: launch.execName
        )
    }

    /// Terminate the child (unless already exited) and unregister from the model.
    /// Safe to call multiple times.
    func terminate() {
        #if DEBUG
        gridDumpTimer?.invalidate()
        gridDumpTimer = nil
        #endif
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

    #if DEBUG
    /// Poll this pane's headless engine grid + state onto temp files the XCUITest
    /// harness reads. Gated by `-UITestGridDump` (started by the window controller
    /// for the focused pane). The view is custom-drawn, so this engine grid — not
    /// the accessibility tree — is the deterministic content source for UI tests.
    func startGridDumpForUITests() {
        gridDumpTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let engine = self.view.getTerminal()

                // `skipNullCellsFollowingWide` + a `characterProvider` keep wide CJK
                // (NUL spacer 2nd column) and non-BMP/grapheme emoji (map-indexed
                // codes) intact; without them CJK is NUL-separated and emoji vanish.
                var lines: [String] = []
                lines.reserveCapacity(engine.rows)
                for row in 0..<engine.rows {
                    lines.append(engine.getLine(row: row)?.translateToString(
                        trimRight: true,
                        skipNullCellsFollowingWide: true,
                        characterProvider: { engine.getCharacter(for: $0) }
                    ) ?? "")
                }
                try? lines.joined(separator: "\n").write(
                    toFile: PaneController.gridDumpPath, atomically: true, encoding: .utf8)

                // State the grid text can't carry (font / theme / option-as-meta) plus
                // scrollback depth via the public proxy `getTopVisibleRow() + rows`.
                let depth = engine.getTopVisibleRow()
                let state: [String: Any] = [
                    "fontFamily": self.view.font.familyName ?? self.view.font.fontName,
                    "fontSize": Double(self.view.font.pointSize),
                    "theme": self.config.themeName,
                    "scrollbackCap": self.config.scrollback,
                    "optionAsMeta": self.view.optionAsMetaKey,
                    "rows": engine.rows,
                    "isAlt": engine.isCurrentBufferAlternate,
                    "scrollbackDepth": depth,
                    "bufferLines": depth + engine.rows,
                ]
                if let data = try? JSONSerialization.data(withJSONObject: state, options: [.sortedKeys]) {
                    try? data.write(to: URL(fileURLWithPath: PaneController.stateDumpPath))
                }
            }
        }
    }
    #endif
}
