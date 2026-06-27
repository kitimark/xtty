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
