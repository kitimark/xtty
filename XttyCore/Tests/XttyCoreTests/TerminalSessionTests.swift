import XCTest
import SwiftTerm
@testable import XttyCore

// Unit tests for TerminalSession. Construct it around a *headless* SwiftTerm
// `Terminal` (no terminal view, no PTY, no app launch) and verify it holds the
// engine handle and records an exit code.

/// Minimal `TerminalDelegate`. Every method except `send` has a default
/// implementation in SwiftTerm, so we only implement that one to satisfy the
/// protocol. The engine never sends anything in these tests.
private final class NoopTerminalDelegate: TerminalDelegate {
    func send(source: Terminal, data: ArraySlice<UInt8>) {}
}

final class TerminalSessionTests: XCTestCase {
    func testHoldsEngineHandleAndRecordsExit() {
        let delegate = NoopTerminalDelegate()
        let engine = Terminal(delegate: delegate)
        let config = ShellResolver.launchConfig(forShell: "/bin/zsh", environment: [:])

        let session = TerminalSession(terminal: engine, launchConfig: config)

        // Holds the engine handle and the launch config.
        XCTAssertTrue(session.terminal === engine)
        XCTAssertEqual(session.launchConfig, config)

        // Exit code is nil while running, then reflects the recorded value.
        XCTAssertNil(session.exitCode)
        session.recordExit(code: 0)
        XCTAssertEqual(session.exitCode, 0)
    }
}
