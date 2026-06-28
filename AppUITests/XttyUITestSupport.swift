import XCTest

// Shared helpers for xtty's macOS XCUITest suite.
//
// Two assertion channels (see OpenSpec change add-verification-harness):
//  - Screenshots via XCTAttachment for human/vision review (always available).
//  - A DEBUG grid-dump file the app writes to /tmp/xtty-grid-dump.txt when
//    launched with "-UITestGridDump", for deterministic substring assertions.
//
// SwiftTerm's LocalProcessTerminalView is custom-drawn, so XCUIElement.value on
// the terminal is NOT a reliable source of cell text; we never rely on it.

enum XttyUI {
    /// Accessibility identifier set on the terminal view in TerminalWindowController.
    static let terminalIdentifier = "xtty.terminal"
    /// Accessibility identifier set on the NSWindow.
    static let windowIdentifier = "xtty.window"
    /// Path the DEBUG grid-dump hook writes to (app is non-sandboxed, so /tmp is
    /// readable by the separate UI-test runner process).
    static let gridDumpPath = "/tmp/xtty-grid-dump.txt"
    /// Path the DEBUG state-dump hook writes to: config knobs + scrollback depth
    /// that the grid text can't carry (see TerminalWindowController.startGridDump…).
    static let stateDumpPath = "/tmp/xtty-state-dump.json"
}

extension XCUIApplication {
    /// The custom-drawn terminal element, located by accessibility identifier.
    var terminal: XCUIElement {
        let byTextView = textViews[XttyUI.terminalIdentifier]
        if byTextView.exists { return byTextView }
        return descendants(matching: .any)[XttyUI.terminalIdentifier]
    }

    /// The single application window.
    var mainWindow: XCUIElement {
        let byId = windows[XttyUI.windowIdentifier]
        return byId.exists ? byId : windows.firstMatch
    }
}

extension XCTestCase {
    /// Launch xtty with a temp config file (injected via `XDG_CONFIG_HOME`) and the
    /// grid + state dump hooks enabled, so a test can assert that a *specific*
    /// config was read and applied. `scrollbackOverride` adds `-UITestScrollback`
    /// to shrink the cap for a fast, exact bounded-scrollback flood. The temp dir
    /// is removed via a teardown block.
    func launchConfigured(config configText: String, scrollbackOverride: Int? = nil,
                          extraEnv: [String: String] = [:]) -> XCUIApplication {
        let fm = FileManager.default
        // XDG_CONFIG_HOME points at <base>; the loader reads <base>/xtty/config.
        let base = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("xtty-uitest-xdg-\(UUID().uuidString)")
        let dir = (base as NSString).appendingPathComponent("xtty")
        try? fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try? configText.write(toFile: (dir as NSString).appendingPathComponent("config"),
                              atomically: true, encoding: .utf8)

        GridDumpReader.reset()
        StateDumpReader.reset()
        let app = XCUIApplication()
        var args = ["-UITestGridDump"]
        if let n = scrollbackOverride { args += ["-UITestScrollback", String(n)] }
        app.launchArguments = args
        app.launchEnvironment["XDG_CONFIG_HOME"] = base
        for (k, v) in extraEnv { app.launchEnvironment[k] = v }
        app.launch()
        // Terminate at teardown so a still-running instance can't overwrite the
        // shared /tmp dump for the next test (state like pane count is sticky).
        addTeardownBlock {
            app.terminate()
            try? fm.removeItem(atPath: base)
        }
        return app
    }

    /// Attach a full-screen screenshot for human/vision review.
    func attachScreenshot(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Attach the current DEBUG grid dump as plain text (best-effort).
    func attachGridDump(_ name: String) {
        guard let text = GridDumpReader.read() else { return }
        let attachment = XCTAttachment(string: text)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

/// Reads the DEBUG grid-dump file the app writes when launched with
/// "-UITestGridDump". All methods are no-ops / nil if the hook is absent, so the
/// suite still runs (screenshot-only) against a Release build.
enum GridDumpReader {
    static func read() -> String? {
        try? String(contentsOfFile: XttyUI.gridDumpPath, encoding: .utf8)
    }

    static func reset() {
        try? FileManager.default.removeItem(atPath: XttyUI.gridDumpPath)
    }

    /// Whether a grid dump exists at all (i.e. the DEBUG hook is active).
    static var isAvailable: Bool { read() != nil }

    /// Poll until the grid is non-empty (shell prompt has been drawn) or timeout.
    @discardableResult
    static func waitForNonEmpty(timeout: TimeInterval) -> Bool {
        poll(timeout: timeout) { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    /// Poll until the grid contains `needle` or timeout.
    @discardableResult
    static func waitForContains(_ needle: String, timeout: TimeInterval) -> Bool {
        poll(timeout: timeout) { $0.contains(needle) }
    }

    private static func poll(timeout: TimeInterval, _ predicate: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let text = read(), predicate(text) { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return false
    }
}

/// Reads the DEBUG state-dump JSON the app writes alongside the grid dump (font,
/// theme, option-as-meta, scrollback depth). Like `GridDumpReader`, all methods
/// degrade to nil/no-op when the hook is absent (Release build).
enum StateDumpReader {
    static func read() -> [String: Any]? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: XttyUI.stateDumpPath)),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return obj
    }

    static func reset() {
        try? FileManager.default.removeItem(atPath: XttyUI.stateDumpPath)
    }

    static var isAvailable: Bool { read() != nil }

    /// Poll until the state dump parses (hook active + first tick written) or timeout.
    static func waitForState(timeout: TimeInterval) -> [String: Any]? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let state = read() { return state }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return nil
    }

    /// Poll until the state dump satisfies `predicate` (returning the matching
    /// snapshot) or timeout. Useful for waiting on scrollback depth to settle.
    static func waitForState(timeout: TimeInterval, where predicate: ([String: Any]) -> Bool) -> [String: Any]? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let state = read(), predicate(state) { return state }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return nil
    }

    /// Attach the current state dump as JSON text for human review (best-effort).
    static func attach(_ testCase: XCTestCase, name: String) {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: XttyUI.stateDumpPath)),
              let text = String(data: data, encoding: .utf8) else { return }
        let attachment = XCTAttachment(string: text)
        attachment.name = name
        attachment.lifetime = .keepAlways
        testCase.add(attachment)
    }
}
