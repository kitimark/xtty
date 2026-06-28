import XCTest
@testable import XttyCore

final class BlockTrackerTests: XCTestCase {
    /// A monotonic injected clock so timestamps are deterministic.
    private func clock() -> () -> Date {
        var t = 0.0
        return { t += 1; return Date(timeIntervalSinceReferenceDate: t) }
    }

    private func tracker() -> BlockTracker { BlockTracker(now: clock()) }

    // Convenience: feed marks by action.
    private func mark(_ a: SemanticAction, command: String? = nil, continuation: Bool = false) -> SemanticMark {
        SemanticMark(action: a, command: command, isContinuation: continuation)
    }

    func testRunCommandBecomesSucceededBlock() {
        let t = tracker()
        t.handle(mark(.promptStart), cwd: "/home")
        t.handle(mark(.commandStart, command: "ls"), cwd: "/home")
        t.handle(mark(.commandEnd(exitCode: 0)), cwd: "/home")
        XCTAssertEqual(t.blocks.count, 1)
        let b = t.blocks[0]
        XCTAssertEqual(b.command, "ls")
        XCTAssertEqual(b.exitCode, 0)
        XCTAssertEqual(b.cwd, "/home")
        XCTAssertEqual(b.state, .succeeded)
        XCTAssertNotNil(b.endedAt)
    }

    func testNonZeroExitIsFailed() {
        let t = tracker()
        t.handle(mark(.commandStart, command: "false"), cwd: "/x")
        t.handle(mark(.commandEnd(exitCode: 1)), cwd: "/x")
        XCTAssertEqual(t.blocks.first?.state, .failed)
        XCTAssertEqual(t.blocks.first?.exitCode, 1)
    }

    func testEmptyPromptProducesNoBlock() {
        let t = tracker()
        t.handle(mark(.promptStart), cwd: "/x")
        t.handle(mark(.promptStart), cwd: "/x")  // Enter at an empty prompt
        XCTAssertTrue(t.blocks.isEmpty)
    }

    func testOnlyFirstDAfterCCounts() {
        let t = tracker()
        t.handle(mark(.commandStart, command: "x"), cwd: "/x")
        t.handle(mark(.commandEnd(exitCode: 0)), cwd: "/x")
        t.handle(mark(.commandEnd(exitCode: 1)), cwd: "/x")  // second D — ignored
        XCTAssertEqual(t.blocks.count, 1)
        XCTAssertEqual(t.blocks[0].exitCode, 0)
    }

    func testStrayEndIsNoOp() {
        let t = tracker()
        t.handle(mark(.promptStart), cwd: "/x")
        t.handle(mark(.commandEnd(exitCode: 0)), cwd: "/x")  // D with no C
        XCTAssertTrue(t.blocks.isEmpty)
    }

    func testContinuationPromptDoesNotStartCommand() {
        let t = tracker()
        t.handle(mark(.commandStart, command: "multiline"), cwd: "/x")
        t.handle(mark(.promptStart, continuation: true), cwd: "/x")  // PS2 — ignored
        t.handle(mark(.commandEnd(exitCode: 0)), cwd: "/x")
        XCTAssertEqual(t.blocks.count, 1, "continuation prompt didn't break the open command")
        XCTAssertEqual(t.blocks[0].command, "multiline")
    }

    func testAlternateScreenSuppressesBlockCreation() {
        let t = tracker()
        t.setAlternateScreen(true)
        t.handle(mark(.commandStart, command: "in-alt"), cwd: "/x")
        t.handle(mark(.commandEnd(exitCode: 0)), cwd: "/x")
        XCTAssertTrue(t.blocks.isEmpty, "no block opened while on the alternate screen")
    }

    func testCommandEnteringAlternateScreenIsOpaque() {
        let t = tracker()
        t.handle(mark(.commandStart, command: "vim"), cwd: "/x")  // starts on primary
        t.setAlternateScreen(true)                                 // vim takes alt
        t.setAlternateScreen(false)                                // vim quits
        t.handle(mark(.commandEnd(exitCode: 0)), cwd: "/x")
        XCTAssertEqual(t.blocks.count, 1)
        XCTAssertEqual(t.blocks[0].state, .opaque, "a full-screen command is opaque, not succeeded")
    }

    func testLastActionTracked() {
        let t = tracker()
        t.handle(mark(.commandStart), cwd: "/x")
        XCTAssertEqual(t.lastAction, .commandStart)
        t.handle(mark(.commandEnd(exitCode: 2)), cwd: "/x")
        XCTAssertEqual(t.lastAction, .commandEnd(exitCode: 2))
    }

    func testRunningBlockExposedBetweenCAndD() {
        let t = tracker()
        XCTAssertNil(t.runningBlock, "nothing running before any command")
        t.handle(mark(.promptStart), cwd: "/home")
        XCTAssertNil(t.runningBlock, "at a prompt, nothing is running yet")
        t.handle(mark(.commandStart, command: "sleep 5"), cwd: "/home")
        let running = t.runningBlock
        XCTAssertNotNil(running, "an in-flight command is exposed as a running block")
        XCTAssertEqual(running?.command, "sleep 5")
        XCTAssertEqual(running?.cwd, "/home")
        XCTAssertEqual(running?.state, .running)
        XCTAssertNil(running?.endedAt, "a running block has no end timestamp")
        t.handle(mark(.commandEnd(exitCode: 0)), cwd: "/home")
        XCTAssertNil(t.runningBlock, "the running block clears once the command ends")
        XCTAssertEqual(t.blocks.count, 1)
    }

    func testRunningBlockSuppressedOnAlternateScreen() {
        let t = tracker()
        t.handle(mark(.commandStart, command: "vim"), cwd: "/x")
        XCTAssertNotNil(t.runningBlock)
        t.setAlternateScreen(true)  // vim takes the alternate screen
        XCTAssertNil(t.runningBlock, "no running block is exposed while on the alternate screen")
        t.setAlternateScreen(false)
        XCTAssertNotNil(t.runningBlock, "the running block reappears back on the primary screen")
    }

    func testParsePipelineFeedsTracker() {
        // End-to-end: OSC 133 payloads → parse → tracker.
        let t = tracker()
        for payload in ["A", "C;cmdline_url=git%20log", "D;0"] {
            if let m = OSC133.parse(payload) { t.handle(m, cwd: "/repo") }
        }
        XCTAssertEqual(t.blocks.count, 1)
        XCTAssertEqual(t.blocks[0].command, "git log")
        XCTAssertEqual(t.blocks[0].state, .succeeded)
    }
}
