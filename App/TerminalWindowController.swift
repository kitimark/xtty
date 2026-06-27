import AppKit
import CoreGraphics
import SwiftTerm
import XttyCore

/// Owns xtty's terminal window.
///
/// **Why AppKit, not SwiftUI:** SwiftTerm's `LocalProcessTerminalView` draws its
/// grid into a hand-managed, layer-backed `CALayer` (CoreText `draw(_:)`). On
/// macOS 26, SwiftUI's `NSViewRepresentable` host (`AppKitPlatformViewHost`) does
/// not composite that subtree — the shell runs but the canvas stays black. We
/// verified this empirically: the *same* view renders correctly when hosted in a
/// plain `NSWindow` (as contentView **and** as a nested subview), and stays black
/// under SwiftUI for **both** the CoreGraphics and the Metal render paths (even a
/// `CAMetalLayer` isn't composited). So the terminal is hosted directly in AppKit.
///
/// The engine seam is unchanged: the shell is resolved via `XttyCore.ShellResolver`
/// and the engine handle is routed through `XttyCore.TerminalSession`. This
/// controller only owns the view + window lifecycle.
///
/// Lifecycle discipline (P1):
/// - The shell is spawned **exactly once**, in `init`.
/// - The window opens on the built-in MacBook Pro display (the user's workspace),
///   not an external monitor.
/// - On teardown the child is terminated to avoid orphan shells.
/// - When the shell exits, the exit code is recorded on the session and the
///   window closes (exit policy A).
@MainActor
final class TerminalWindowController: NSObject, LocalProcessTerminalViewDelegate {
    let window: NSWindow
    private let terminal: LocalProcessTerminalView
    private var session: TerminalSession?
    private var processEnded = false
    private var keyObserver: NSObjectProtocol?

    #if DEBUG
    /// DEBUG-only: drives the XCUITest grid-dump assertion channel (see change
    /// `add-verification-harness`). Polls the headless engine grid to a temp file
    /// the UI-test runner reads. Only started under the `-UITestGridDump` arg.
    private var gridDumpTimer: Timer?
    private static let gridDumpPath = "/tmp/xtty-grid-dump.txt"
    #endif

    init(contentSize: NSSize = NSSize(width: 900, height: 560)) {
        terminal = LocalProcessTerminalView(frame: NSRect(origin: .zero, size: contentSize))
        window = NSWindow(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        super.init()

        window.title = "xtty"
        window.contentView = terminal
        window.tabbingMode = .disallowed
        terminal.processDelegate = self

        // Accessibility wiring for the XCUITest harness. SwiftTerm's view is
        // custom-drawn, so AppKit exposes no per-cell text — these identifiers
        // only let UI tests *locate* the view/window and route synthetic input;
        // terminal content is asserted via the DEBUG grid-dump hook below, never
        // the accessibility tree. See change `add-verification-harness`.
        terminal.setAccessibilityElement(true)
        terminal.setAccessibilityRole(.textArea)
        terminal.setAccessibilityLabel("Terminal")
        terminal.setAccessibilityIdentifier("xtty.terminal")
        window.setAccessibilityIdentifier("xtty.window")
        window.identifier = NSUserInterfaceItemIdentifier("xtty.window")

        // Open on the built-in display (user's workspace), not an external monitor.
        positionOnBuiltInDisplay()

        // Resolve the shell + login launch config through the seam.
        let config = ShellResolver.resolve()

        // Route the engine handle through XttyCore (observe-only). The view + PTY
        // drive the engine; the session just holds the handle + exit status.
        session = TerminalSession(terminal: terminal.getTerminal(), launchConfig: config)

        // SwiftTerm's environment is an array of "KEY=VALUE"; a non-nil array
        // replaces the child environment wholesale (so ShellResolver seeds the
        // identity vars it needs — see ShellResolver).
        let environment = config.environment.map { "\($0.key)=\($0.value)" }
        terminal.startProcess(
            executable: config.executable,
            args: config.args,
            environment: environment,
            execName: config.execName
        )

        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(terminal)

        // Keep the terminal first responder whenever its window becomes key, so
        // typing works immediately on focus without an extra click.
        keyObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.window.makeFirstResponder(self.terminal)
            }
        }
    }

    /// Center the window on the built-in MacBook Pro display (falls back to the
    /// main screen, then to AppKit's default centering).
    private func positionOnBuiltInDisplay() {
        #if DEBUG
        for s in NSScreen.screens {
            let key = NSDeviceDescriptionKey("NSScreenNumber")
            let id = (s.deviceDescription[key] as? NSNumber).map { CGDirectDisplayID($0.uint32Value) } ?? 0
            NSLog("[xtty] screen '\(s.localizedName)' id=\(id) builtin=\(CGDisplayIsBuiltin(id) != 0) frame=\(NSStringFromRect(s.frame)) main=\(s == NSScreen.main)")
        }
        #endif
        let builtIn = TerminalWindowController.builtInScreen()
        guard let screen = builtIn ?? NSScreen.main else {
            window.center()
            return
        }
        let visible = screen.visibleFrame
        let size = window.frame.size
        let origin = NSPoint(x: visible.midX - size.width / 2,
                             y: visible.midY - size.height / 2)
        window.setFrame(NSRect(origin: origin, size: size), display: true)
        #if DEBUG
        NSLog("[xtty] placed window on '\(screen.localizedName)' (builtInDetected=\(builtIn != nil)) frame=\(NSStringFromRect(window.frame))")
        #endif
    }

    /// The `NSScreen` backed by the built-in display, identified via
    /// `CGDisplayIsBuiltin`. Returns nil if there is no built-in display.
    static func builtInScreen() -> NSScreen? {
        for screen in NSScreen.screens {
            let key = NSDeviceDescriptionKey("NSScreenNumber")
            guard let number = screen.deviceDescription[key] as? NSNumber else { continue }
            let displayID = CGDirectDisplayID(number.uint32Value)
            if CGDisplayIsBuiltin(displayID) != 0 {
                return screen
            }
        }
        return nil
    }

    /// Terminate the child process (SIGTERM) unless it already exited, and remove
    /// observers. Safe to call multiple times.
    func terminate() {
        #if DEBUG
        gridDumpTimer?.invalidate()
        gridDumpTimer = nil
        #endif
        if let keyObserver {
            NotificationCenter.default.removeObserver(keyObserver)
            self.keyObserver = nil
        }
        if !processEnded {
            processEnded = true
            terminal.terminate()
        }
    }

    #if DEBUG
    /// Start polling the headless engine grid onto a temp file for the XCUITest
    /// harness. Gated by the `-UITestGridDump` launch arg (see `XttyApp`). The view
    /// is custom-drawn, so this engine grid — not the accessibility tree — is the
    /// deterministic content source for UI tests.
    func startGridDumpForUITests() {
        gridDumpTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let engine = self.terminal.getTerminal()
                var lines: [String] = []
                lines.reserveCapacity(engine.rows)
                for row in 0..<engine.rows {
                    lines.append(engine.getLine(row: row)?.translateToString(trimRight: true) ?? "")
                }
                try? lines.joined(separator: "\n").write(
                    toFile: TerminalWindowController.gridDumpPath,
                    atomically: true, encoding: .utf8)
            }
        }
    }
    #endif

    // MARK: LocalProcessTerminalViewDelegate
    //
    // The protocol is not actor-isolated, but SwiftTerm invokes these on the main
    // thread. Declaring them `nonisolated` satisfies the conformance from this
    // `@MainActor` class; `assumeIsolated` lets us touch main-actor state safely.

    // Exit policy A: record the exit code on the session, then close the window.
    nonisolated func processTerminated(source: TerminalView, exitCode: Int32?) {
        MainActor.assumeIsolated {
            processEnded = true
            session?.recordExit(code: exitCode)
            window.close()
        }
    }

    // SwiftTerm handles PTY resize internally; nothing to do at P1.
    nonisolated func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

    nonisolated func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        MainActor.assumeIsolated {
            window.title = title.isEmpty ? "xtty" : title
        }
    }

    // OSC 7 cwd capture is P4; ignore here.
    nonisolated func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
}
