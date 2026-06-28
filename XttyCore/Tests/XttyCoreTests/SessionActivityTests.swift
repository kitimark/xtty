import XCTest
import SwiftTerm
@testable import XttyCore

// Unit tests for the view-free session activity derivation (the P5 sidebar's
// state vocabulary) and its wiring through TerminalSession. No app, no views.
final class SessionActivityTests: XCTestCase {

    // MARK: Pure derivation precedence (design D1): fullScreen → running → failed → succeeded → idle

    func testAlternateScreenWins() {
        XCTAssertEqual(
            SessionActivity.derive(isAlternateScreen: true, isRunning: true, lastFinished: .failed),
            .fullScreen, "the alternate screen overrides everything")
    }

    func testRunningBeatsLastFinished() {
        XCTAssertEqual(
            SessionActivity.derive(isAlternateScreen: false, isRunning: true, lastFinished: .succeeded),
            .running)
    }

    func testFailedAndSucceeded() {
        XCTAssertEqual(
            SessionActivity.derive(isAlternateScreen: false, isRunning: false, lastFinished: .failed),
            .failed)
        XCTAssertEqual(
            SessionActivity.derive(isAlternateScreen: false, isRunning: false, lastFinished: .succeeded),
            .succeeded)
    }

    func testIdleWhenNothingOrOpaque() {
        XCTAssertEqual(
            SessionActivity.derive(isAlternateScreen: false, isRunning: false, lastFinished: nil),
            .idle, "a fresh session is idle")
        XCTAssertEqual(
            SessionActivity.derive(isAlternateScreen: false, isRunning: false, lastFinished: .opaque),
            .idle, "a finished full-screen excursion reads as idle, not succeeded/failed")
    }

    // MARK: Wired through a real (headless) session

    private final class NoopTerminalDelegate: TerminalDelegate {
        func send(source: Terminal, data: ArraySlice<UInt8>) {}
    }

    @MainActor
    func testSessionActivityFollowsTheBlockStream() {
        let session = TerminalSession(
            terminal: Terminal(delegate: NoopTerminalDelegate()),
            launchConfig: ShellResolver.launchConfig(forShell: "/bin/zsh", environment: [:])
        )
        XCTAssertEqual(session.activity, .idle)
        XCTAssertNil(session.runningCommand)

        session.handleSemanticMark(SemanticMark(action: .commandStart, command: "make"))
        XCTAssertEqual(session.activity, .running)
        XCTAssertEqual(session.runningCommand, "make")

        session.handleSemanticMark(SemanticMark(action: .commandEnd(exitCode: 2)))
        XCTAssertEqual(session.activity, .failed)
        XCTAssertNil(session.runningCommand)

        session.handleSemanticMark(SemanticMark(action: .commandStart, command: "ls"))
        session.handleSemanticMark(SemanticMark(action: .commandEnd(exitCode: 0)))
        XCTAssertEqual(session.activity, .succeeded)

        session.setAlternateScreen(true)
        XCTAssertEqual(session.activity, .fullScreen)
    }
}
