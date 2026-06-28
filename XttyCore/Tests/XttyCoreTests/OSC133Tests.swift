import XCTest
@testable import XttyCore

// The handler receives the payload AFTER "133;", so tests pass e.g. "D;1".
final class OSC133Tests: XCTestCase {
    func testRecognizesBareActions() {
        XCTAssertEqual(OSC133.parse("A")?.action, .promptStart)
        XCTAssertEqual(OSC133.parse("B")?.action, .promptEnd)
        XCTAssertEqual(OSC133.parse("C")?.action, .commandStart)
        XCTAssertEqual(OSC133.parse("P")?.action, .promptStart, "P is a prompt start")
    }

    func testExitCodeIsBarePositionalInteger() {
        XCTAssertEqual(OSC133.parse("D;0")?.action, .commandEnd(exitCode: 0))
        XCTAssertEqual(OSC133.parse("D;1")?.action, .commandEnd(exitCode: 1))
        XCTAssertEqual(OSC133.parse("D;130")?.action, .commandEnd(exitCode: 130))
    }

    func testBareDHasNoExitCode() {
        XCTAssertEqual(OSC133.parse("D")?.action, .commandEnd(exitCode: nil))
    }

    func testExitCodePrecedesOtherOptions() {
        // 133;D;12;aid=foo — aid comes AFTER the bare code.
        XCTAssertEqual(OSC133.parse("D;12;aid=foo")?.action, .commandEnd(exitCode: 12))
    }

    func testNegativeExitCode() {
        XCTAssertEqual(OSC133.parse("D;-1")?.action, .commandEnd(exitCode: -1))
    }

    func testCmdlineUrlIsPercentDecoded() {
        let mark = OSC133.parse("C;cmdline_url=git%20status")
        XCTAssertEqual(mark?.action, .commandStart)
        XCTAssertEqual(mark?.command, "git status")
    }

    func testCmdlineIsShellDequoted() {
        let mark = OSC133.parse(#"C;cmdline=echo\ hi"#)
        XCTAssertEqual(mark?.command, "echo hi")
    }

    func testUndecodableCmdlineFallsBackToRaw() {
        // A value with no escapes round-trips as itself (raw fallback).
        let mark = OSC133.parse("C;cmdline_url=plain")
        XCTAssertEqual(mark?.command, "plain")
    }

    func testContinuationPromptFlag() {
        XCTAssertEqual(OSC133.parse("A;k=s")?.isContinuation, true)
        XCTAssertEqual(OSC133.parse("A;k=i")?.isContinuation, false)
        XCTAssertEqual(OSC133.parse("A")?.isContinuation, false)
    }

    func testUnknownActionIsIgnored() {
        XCTAssertNil(OSC133.parse("k;foo=bar"), "kitty's 133;k is not a semantic boundary")
        XCTAssertNil(OSC133.parse("Z"))
        XCTAssertNil(OSC133.parse(""))
    }

    func testValueMaySplitOnlyOnFirstEquals() {
        // cmdline_url=a=b should keep "a=b" as the value (split on first '=').
        let mark = OSC133.parse("C;cmdline_url=a=b")
        XCTAssertEqual(mark?.command, "a=b")
    }
}
