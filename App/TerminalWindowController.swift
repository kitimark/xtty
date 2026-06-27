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
    /// The configured base font size (Cmd 0 returns here). Set at launch from the
    /// terminal's font; later sourced from config.
    private var configuredFontSize: CGFloat
    /// The resolved launch configuration, retained so the DEBUG state dump can
    /// report what was applied: the engine has no theme-name concept and the
    /// scrollback cap isn't publicly readable back off the engine.
    private let config: XttyConfig

    #if DEBUG
    /// DEBUG-only: drives the XCUITest grid-dump assertion channel (see change
    /// `add-verification-harness`). Polls the headless engine grid to a temp file
    /// the UI-test runner reads. Only started under the `-UITestGridDump` arg.
    private var gridDumpTimer: Timer?
    private static let gridDumpPath = "/tmp/xtty-grid-dump.txt"
    /// Sibling of the grid dump holding config/engine state that the grid text
    /// can't carry (font, theme, option-as-meta, scrollback depth) so UI tests
    /// can assert config-applied + bounded-scrollback deterministically.
    private static let stateDumpPath = "/tmp/xtty-state-dump.json"
    #endif

    init(contentSize: NSSize = NSSize(width: 900, height: 560)) {
        // Load the user config (~/.config/xtty/config) through the XttyCore seam;
        // a missing file yields defaults. Applied to the view below.
        let loadedConfig = XttyConfigLoader.load(warn: { NSLog("[xtty] config: %@", $0) })
        #if DEBUG
        let appConfig = TerminalWindowController.applyUITestOverrides(to: loadedConfig)
        #else
        let appConfig = loadedConfig
        #endif
        terminal = LocalProcessTerminalView(frame: NSRect(origin: .zero, size: contentSize))
        config = appConfig
        configuredFontSize = CGFloat(appConfig.fontSize)
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

        // Apply the user config (font, theme palette, bounded scrollback,
        // option-as-meta) before the shell starts so the initial PTY size and
        // appearance reflect it. Font/theme knowledge lives here in the app layer;
        // XttyCore only carries the toolkit-independent values.
        TerminalConfigurator.apply(appConfig, to: terminal)

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

    // MARK: Font size (ephemeral, not persisted to config)
    //
    // The configured base size is the launch font size; Cmd +/− adjust the live
    // session and Cmd 0 returns to the configured base. Live changes are NOT
    // written back to the config file (P2 policy).

    /// Smallest/largest live font sizes, to keep the grid legible and bounded.
    private static let fontSizeRange: ClosedRange<CGFloat> = 6...72

    /// Adjust the live font size by `delta` points, clamped to `fontSizeRange`.
    func adjustFontSize(by delta: CGFloat) {
        let current = terminal.font
        let newSize = min(max(current.pointSize + delta, Self.fontSizeRange.lowerBound),
                          Self.fontSizeRange.upperBound)
        guard newSize != current.pointSize else { return }
        if let resized = NSFont(descriptor: current.fontDescriptor, size: newSize) {
            terminal.font = resized
        }
    }

    /// Reset the live font size to the configured base size (family unchanged).
    func resetFontSize() {
        let current = terminal.font
        guard current.pointSize != configuredFontSize else { return }
        if let reset = NSFont(descriptor: current.fontDescriptor, size: configuredFontSize) {
            terminal.font = reset
        }
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
    /// XCUITest determinism: `-UITestScrollback <n>` shrinks the scrollback cap so
    /// the bounded-scrollback flood test runs fast with an exact saturation point.
    /// No-op (returns the config unchanged) when the arg is absent/invalid.
    private static func applyUITestOverrides(to config: XttyConfig) -> XttyConfig {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-UITestScrollback"),
              i + 1 < args.count, let n = Int(args[i + 1]), n >= 0 else {
            return config
        }
        var overridden = config
        overridden.scrollback = n
        return overridden
    }

    /// Start polling the headless engine grid onto a temp file for the XCUITest
    /// harness. Gated by the `-UITestGridDump` launch arg (see `XttyApp`). The view
    /// is custom-drawn, so this engine grid — not the accessibility tree — is the
    /// deterministic content source for UI tests.
    func startGridDumpForUITests() {
        gridDumpTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let engine = self.terminal.getTerminal()

                // Grid text. `skipNullCellsFollowingWide` + a `characterProvider`
                // are required so wide CJK (whose 2nd column is a NUL spacer cell)
                // and non-BMP/grapheme emoji (stored as map-indexed codes the plain
                // path can't resolve) reproduce intact in the dump. Without them CJK
                // comes out NUL-separated and most emoji collapse to spaces.
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
                    toFile: TerminalWindowController.gridDumpPath,
                    atomically: true, encoding: .utf8)

                // State dump: config knobs invisible in the grid text (font / theme
                // / option-as-meta) plus scrollback depth. `bufferLines` uses the
                // public proxy `getTopVisibleRow() + rows` because the true buffer
                // line count is internal to SwiftTerm; once a flood overflows the
                // cap the depth saturates at exactly the scrollback cap (valid only
                // on the normal buffer with the view pinned to bottom — hence `isAlt`
                // and `scrollbackDepth` are emitted so the test can check both).
                let depth = engine.getTopVisibleRow()
                let state: [String: Any] = [
                    "fontFamily": self.terminal.font.familyName ?? self.terminal.font.fontName,
                    "fontSize": Double(self.terminal.font.pointSize),
                    "theme": self.config.themeName,
                    "scrollbackCap": self.config.scrollback,
                    "optionAsMeta": self.terminal.optionAsMetaKey,
                    "rows": engine.rows,
                    "isAlt": engine.isCurrentBufferAlternate,
                    "scrollbackDepth": depth,
                    "bufferLines": depth + engine.rows,
                ]
                if let data = try? JSONSerialization.data(withJSONObject: state, options: [.sortedKeys]) {
                    try? data.write(to: URL(fileURLWithPath: TerminalWindowController.stateDumpPath))
                }
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
