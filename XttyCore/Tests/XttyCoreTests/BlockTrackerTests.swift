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

    // MARK: Anchors (P4b-2) — the "fake engine" supplies synthetic absolute rows.

    func testAnchorsCapturedAtMarks() {
        let t = tracker()
        t.handle(mark(.promptStart), cwd: "/x", row: 100)        // A → prompt row
        t.handle(mark(.commandStart, command: "ls"), cwd: "/x", row: 101)  // C → output start
        t.handle(mark(.commandEnd(exitCode: 0)), cwd: "/x", row: 140)      // D → output end
        let anchor = t.blocks[0].anchor
        XCTAssertEqual(anchor?.promptRow, 100)
        XCTAssertEqual(anchor?.outputStart, 101)
        XCTAssertEqual(anchor?.outputEnd, 140)
        XCTAssertEqual(anchor?.epoch, 0)
    }

    func testNoAnchorWhenProviderUnavailable() {
        // Phase-1 seam: row is nil → block still valid, just no anchor.
        let t = tracker()
        t.handle(mark(.promptStart), cwd: "/x")
        t.handle(mark(.commandStart, command: "ls"), cwd: "/x")
        t.handle(mark(.commandEnd(exitCode: 0)), cwd: "/x")
        XCTAssertEqual(t.blocks.count, 1)
        XCTAssertNil(t.blocks[0].anchor)
    }

    func testRunningBlockExposesOutputStartAnchor() {
        let t = tracker()
        t.handle(mark(.promptStart), cwd: "/x", row: 10)
        t.handle(mark(.commandStart, command: "sleep 9"), cwd: "/x", row: 11)
        let anchor = t.runningBlock?.anchor
        XCTAssertEqual(anchor?.outputStart, 11)
        XCTAssertEqual(anchor?.promptRow, 10)
        XCTAssertNil(anchor?.outputEnd, "a running block has no output-end yet")
    }

    func testOpaqueBlockHasNoAnchor() {
        let t = tracker()
        t.handle(mark(.commandStart, command: "vim"), cwd: "/x", row: 5)
        t.setAlternateScreen(true)
        t.handle(mark(.commandEnd(exitCode: 0)), cwd: "/x", row: 6)
        XCTAssertEqual(t.blocks[0].state, .opaque)
        XCTAssertNil(t.blocks[0].anchor, "an alt-screen excursion is not a scrollable, anchorable block")
    }

    func testPromptCaptureSkippedOnAlternateScreen() {
        let t = tracker()
        t.setAlternateScreen(true)
        t.handle(mark(.promptStart), cwd: "/x", row: 50)  // captured while alt → discarded
        t.setAlternateScreen(false)
        t.handle(mark(.commandStart, command: "ls"), cwd: "/x", row: 60)
        t.handle(mark(.commandEnd(exitCode: 0)), cwd: "/x", row: 70)
        XCTAssertNil(t.blocks[0].anchor?.promptRow, "a prompt row captured on the alt screen is not used")
        XCTAssertEqual(t.blocks[0].anchor?.outputStart, 60)
    }

    // MARK: Epoch invalidation (P4b-2)

    func testBumpEpochInvalidatesPriorAnchors() {
        let t = tracker()
        t.handle(mark(.promptStart), cwd: "/x", row: 1)
        t.handle(mark(.commandStart, command: "a"), cwd: "/x", row: 2)
        t.handle(mark(.commandEnd(exitCode: 0)), cwd: "/x", row: 3)
        let anchor = t.blocks[0].anchor!
        XCTAssertTrue(t.anchorIsValid(anchor))
        t.bumpEpoch()  // resize/reflow
        XCTAssertFalse(t.anchorIsValid(anchor), "a resize invalidates anchors captured before it")
    }

    func testNewAnchorsUseTheCurrentEpoch() {
        let t = tracker()
        t.bumpEpoch()  // epoch 1
        t.handle(mark(.commandStart, command: "a"), cwd: "/x", row: 2)
        t.handle(mark(.commandEnd(exitCode: 0)), cwd: "/x", row: 3)
        XCTAssertEqual(t.blocks[0].anchor?.epoch, 1)
        XCTAssertTrue(t.anchorIsValid(t.blocks[0].anchor!))
    }

    func testLiveTopDropBumpsEpoch() {
        let t = tracker()
        t.noteLiveTop(0)
        t.noteLiveTop(100)   // grows — high-water 100, no bump
        t.noteLiveTop(150)
        let before = t.currentEpoch
        t.noteLiveTop(0)     // clear/reset → drop below high-water
        XCTAssertEqual(t.currentEpoch, before + 1, "a liveTop drop (reset) bumps the epoch")
    }

    func testLiveTopNilIsIgnored() {
        let t = tracker()
        t.noteLiveTop(100)
        let before = t.currentEpoch
        t.noteLiveTop(nil)   // provider unavailable
        XCTAssertEqual(t.currentEpoch, before)
    }
}

final class BlockNavigationTests: XCTestCase {
    func testReverseMapValidAndTrimmed() {
        XCTAssertEqual(BlockNavigation.displayRow(forAbsolute: 120, scrollbackBase: 100), .row(20))
        XCTAssertEqual(BlockNavigation.displayRow(forAbsolute: 100, scrollbackBase: 100), .row(0))
        XCTAssertEqual(BlockNavigation.displayRow(forAbsolute: 90, scrollbackBase: 100), .trimmedOut)
    }

    func testJumpPreviousAndNext() {
        let prompts = [10, 30, 60, 90]
        // From the bottom (top of viewport at 100): previous = the newest prompt.
        XCTAssertEqual(BlockNavigation.jumpTargetRow(promptRows: prompts, currentTopAbsolute: 100, direction: .previous), 90)
        // From row 60: previous = 30, next = 90.
        XCTAssertEqual(BlockNavigation.jumpTargetRow(promptRows: prompts, currentTopAbsolute: 60, direction: .previous), 30)
        XCTAssertEqual(BlockNavigation.jumpTargetRow(promptRows: prompts, currentTopAbsolute: 60, direction: .next), 90)
        // At/above the oldest: previous has no target (no-op).
        XCTAssertNil(BlockNavigation.jumpTargetRow(promptRows: prompts, currentTopAbsolute: 10, direction: .previous))
        // At the newest: next has no target (no-op).
        XCTAssertNil(BlockNavigation.jumpTargetRow(promptRows: prompts, currentTopAbsolute: 90, direction: .next))
        // No prompts at all → no target.
        XCTAssertNil(BlockNavigation.jumpTargetRow(promptRows: [], currentTopAbsolute: 5, direction: .previous))
    }

    func testOutputRowRange() {
        let finished = BlockAnchor(epoch: 0, promptRow: 10, outputStart: 11, outputEnd: 40)
        XCTAssertEqual(BlockNavigation.outputRowRange(anchor: finished).map { [$0.start, $0.end] }, [11, 40])
        // Running: outputEnd nil → use the live cursor row.
        let running = BlockAnchor(epoch: 0, promptRow: 10, outputStart: 11, outputEnd: nil)
        XCTAssertEqual(BlockNavigation.outputRowRange(anchor: running, liveEnd: 25).map { [$0.start, $0.end] }, [11, 25])
        // No start → nil; degenerate (end < start) → nil.
        XCTAssertNil(BlockNavigation.outputRowRange(anchor: BlockAnchor(epoch: 0, outputStart: nil, outputEnd: 5)))
        XCTAssertNil(BlockNavigation.outputRowRange(anchor: BlockAnchor(epoch: 0, outputStart: 30, outputEnd: 20)))
    }
}
