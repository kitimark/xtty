import XCTest

// e2e for the clickable per-pane block sidebar (add-block-sidebar, P4b-3).
//
// Drives a real zsh with xtty's shell-integration injection active, then exercises
// the random-access designated-block ops (scroll-to-block / copy-output / copy-command
// / reveal-cwd) through the REAL pipeline via an in-process trigger file
// (XTTY_TEST_BLOCK_SELECT — selecting a dynamic SwiftUI row can't be hit-tested
// reliably), and asserts the resolved scroll target / copied output / menu action +
// per-block "actionable" flags from the DEBUG state dump.
//
// Capture depends on the host's zsh config cooperating with the additive hooks, so
// each test degrades gracefully (screenshot only) when capture isn't active — matching
// the P4a/P5/P4b-2 suites. The pure model logic is unit-tested in XttyCore separately.
final class XttyBlockSidebarUITests: XCTestCase {

    private let selectInputPath = (NSTemporaryDirectory() as NSString)
        .appendingPathComponent("xtty-test-block-select.txt")

    private func type(_ command: String, into app: XCUIApplication) {
        app.typeText(command)
        app.typeKey(.enter, modifierFlags: [])
    }

    private func launch(scrollback: Int? = nil) -> XCUIApplication {
        launchConfigured(config: "", scrollbackOverride: scrollback,
                         extraEnv: ["XTTY_TEST_BLOCK_SELECT": selectInputPath])
    }

    private func waitForCaptureActive(timeout: TimeInterval) -> Bool {
        StateDumpReader.waitForState(timeout: timeout) {
            !(($0["lastSemanticAction"] as? String) ?? "").isEmpty
        } != nil
    }

    /// Write a block-op spec ("verb:target") and wait for the app to consume it.
    @discardableResult
    private func routeBlockOp(_ spec: String, timeout: TimeInterval = 5) -> Bool {
        try? spec.write(toFile: selectInputPath, atomically: true, encoding: .utf8)
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !FileManager.default.fileExists(atPath: selectInputPath) { return true }
            usleep(80_000)
        }
        return false
    }

    private func blocks(_ state: [String: Any]) -> [[String: Any]] {
        (state["blocks"] as? [[String: Any]]) ?? []
    }

    /// Run a couple of commands and wait until at least `count` blocks are captured;
    /// returns the latest state, or nil when capture never went live.
    private func produceBlocks(_ app: XCUIApplication, count: Int) -> [String: Any]? {
        guard StateDumpReader.waitForState(timeout: 10) != nil else {
            attachScreenshot("no-state-dump (Release?)"); return nil
        }
        _ = GridDumpReader.waitForNonEmpty(timeout: 5)
        type("true", into: app)
        guard waitForCaptureActive(timeout: 8) else {
            attachScreenshot("semantic-capture-inactive (host zsh config?)"); return nil
        }
        for i in 0..<count { type("echo block\(i)", into: app) }
        return StateDumpReader.waitForState(timeout: 10) { self.blocks($0).count >= count }
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: selectInputPath)
        super.tearDown()
    }

    // 6.1 — Selecting an earlier block resolves a scroll target.
    func testSelectingEarlierBlockResolvesScrollTarget() {
        let app = launch()
        guard produceBlocks(app, count: 3) != nil else { return }
        XCTAssertTrue(routeBlockOp("scroll:0"), "block-select trigger should be consumed")
        let state = StateDumpReader.waitForState(timeout: 5) {
            ($0["lastJumpTargetRow"] as? NSNumber) != nil
        }
        XCTAssertNotNil(state?["lastJumpTargetRow"] as? NSNumber,
                        "selecting the earliest block should resolve to its prompt row")
        StateDumpReader.attach(self, name: "block-select-scroll")
    }

    // 6.1 — Copying a designated block's output captures it, excluding the echo/prompt.
    func testCopyDesignatedBlockOutput() {
        let app = launch()
        guard StateDumpReader.waitForState(timeout: 10) != nil else {
            attachScreenshot("no-state-dump (Release?)"); return
        }
        _ = GridDumpReader.waitForNonEmpty(timeout: 5)
        type("true", into: app)
        guard waitForCaptureActive(timeout: 8) else {
            attachScreenshot("semantic-capture-inactive (host zsh config?)"); return
        }
        let marker = "XTTYBLOCKMARKER7"
        type("echo \(marker)", into: app)
        type("echo after", into: app)  // a later block so the target isn't the last
        let state = StateDumpReader.waitForState(timeout: 10) {
            self.blocks($0).contains { ($0["command"] as? String)?.contains(marker) == true }
        }
        guard let state, let idx = blocks(state).firstIndex(where: {
            ($0["command"] as? String)?.contains(marker) == true
        }) else { attachScreenshot("marker-block-not-captured"); return }

        XCTAssertTrue(routeBlockOp("copyout:\(idx)"))
        let after = StateDumpReader.waitForState(timeout: 5) {
            ($0["lastCopiedOutput"] as? String)?.contains(marker) == true
        }
        let copied = after?["lastCopiedOutput"] as? String
        XCTAssertNotNil(copied, "copy-output of the designated block should capture its output")
        XCTAssertTrue(copied?.contains(marker) == true, "copied text should contain the output; got \(copied ?? "nil")")
        XCTAssertFalse(copied?.contains("echo \(marker)") == true,
                       "copied text should exclude the command echo / prompt; got \(copied ?? "nil")")
        StateDumpReader.attach(self, name: "block-copy-output")
    }

    // 6.1 — The running block is selectable and its output-so-far is copyable.
    func testRunningBlockSelectAndCopy() {
        let app = launch()
        guard StateDumpReader.waitForState(timeout: 10) != nil else {
            attachScreenshot("no-state-dump (Release?)"); return
        }
        _ = GridDumpReader.waitForNonEmpty(timeout: 5)
        type("true", into: app)
        guard waitForCaptureActive(timeout: 8) else {
            attachScreenshot("semantic-capture-inactive (host zsh config?)"); return
        }
        let marker = "XTTYRUNMARK5"
        type("echo \(marker); sleep 6", into: app)  // running long enough to act on
        guard StateDumpReader.waitForState(timeout: 6, where: {
            !(($0["runningCommand"] as? String) ?? "").isEmpty
        }) != nil else { attachScreenshot("running-block-not-observed"); return }

        XCTAssertTrue(routeBlockOp("scroll:running"))
        _ = StateDumpReader.waitForState(timeout: 4) { ($0["lastJumpTargetRow"] as? NSNumber) != nil }
        XCTAssertTrue(routeBlockOp("copyout:running"))
        let state = StateDumpReader.waitForState(timeout: 4) {
            ($0["lastCopiedOutput"] as? String)?.contains(marker) == true
        }
        XCTAssertTrue((state?["lastCopiedOutput"] as? String)?.contains(marker) == true,
                      "copying the running block should capture its output so far")
        StateDumpReader.attach(self, name: "block-running")
    }

    // 6.2 (epoch arm) — a resize invalidates anchors: every block reports
    // non-actionable and selecting one no-ops (no scroll target).
    func testResizeMakesBlocksNonActionable() {
        let app = launch()
        guard produceBlocks(app, count: 3) != nil else { return }

        // Drag the bottom-right corner to resize → sizeChanged → epoch bump.
        let window = app.mainWindow
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        let corner = window.coordinate(withNormalizedOffset: CGVector(dx: 1.0, dy: 1.0))
        corner.click(forDuration: 0.2, thenDragTo: corner.withOffset(CGVector(dx: -180, dy: -140)))

        let state = StateDumpReader.waitForState(timeout: 6) {
            let bs = self.blocks($0)
            return !bs.isEmpty && bs.allSatisfy { ($0["actionable"] as? Bool) == false }
        }
        guard let state else { attachScreenshot("blocks-still-actionable-after-resize"); return }
        XCTAssertTrue(blocks(state).allSatisfy { ($0["actionable"] as? Bool) == false },
                      "every block should be non-actionable after a resize (epoch invalidation)")

        XCTAssertTrue(routeBlockOp("scroll:0"))
        let after = StateDumpReader.waitForState(timeout: 4) { _ in true }
        XCTAssertNil(after?["lastJumpTargetRow"] as? NSNumber,
                     "selecting an epoch-stale block should no-op (no scroll target)")
        StateDumpReader.attach(self, name: "block-resize-stale")
    }

    // 6.2 (trimmed arm) — with a tiny scrollback, an early block's row scrolls out
    // of the buffer while its anchor epoch stays valid: it reports non-actionable
    // and selecting it no-ops — distinct from the resize/epoch case.
    func testTrimmedBlockIsNonActionable() {
        let app = launch(scrollback: 50)
        guard StateDumpReader.waitForState(timeout: 10) != nil else {
            attachScreenshot("no-state-dump (Release?)"); return
        }
        _ = GridDumpReader.waitForNonEmpty(timeout: 5)
        type("true", into: app)
        guard waitForCaptureActive(timeout: 8) else {
            attachScreenshot("semantic-capture-inactive (host zsh config?)"); return
        }
        type("echo earlyblock", into: app)   // becomes blocks[0]
        type("seq 400", into: app)           // flood: pushes earlyblock's row out of a 50-line buffer
        let state = StateDumpReader.waitForState(timeout: 10) {
            let bs = self.blocks($0)
            return bs.count >= 2 && (bs.first?["actionable"] as? Bool) == false
        }
        guard let state, let first = blocks(state).first else {
            attachScreenshot("early-block-still-actionable"); return
        }
        XCTAssertEqual(first["actionable"] as? Bool, false,
                       "an early block trimmed out of scrollback should be non-actionable")
        XCTAssertTrue(routeBlockOp("scroll:0"))
        let after = StateDumpReader.waitForState(timeout: 4) { _ in true }
        XCTAssertNil(after?["lastJumpTargetRow"] as? NSNumber,
                     "selecting a trimmed-out block should no-op")
        StateDumpReader.attach(self, name: "block-trimmed-stale")
    }

    // 6.3 — copy-command and reveal record their resolved value (no clipboard/Finder
    // dependency); reveal never opens Finder on the test path.
    func testBlockMenuActionsRecorded() {
        let app = launch()
        guard let state = produceBlocks(app, count: 2) else { return }
        let lastIdx = blocks(state).count - 1
        let expectedCmd = blocks(state)[lastIdx]["command"] as? String ?? ""

        XCTAssertTrue(routeBlockOp("copycmd:\(lastIdx)"))
        let copy = StateDumpReader.waitForState(timeout: 5) {
            (($0["lastBlockMenuAction"] as? [String: Any])?["kind"] as? String) == "copyCommand"
        }
        let copyAction = copy?["lastBlockMenuAction"] as? [String: Any]
        XCTAssertEqual(copyAction?["kind"] as? String, "copyCommand")
        XCTAssertEqual(copyAction?["value"] as? String, expectedCmd,
                       "copy-command should record the block's command text")

        XCTAssertTrue(routeBlockOp("reveal:\(lastIdx)"))
        let reveal = StateDumpReader.waitForState(timeout: 5) {
            (($0["lastBlockMenuAction"] as? [String: Any])?["kind"] as? String) == "reveal"
        }
        let revealAction = reveal?["lastBlockMenuAction"] as? [String: Any]
        XCTAssertEqual(revealAction?["kind"] as? String, "reveal")
        XCTAssertFalse((revealAction?["value"] as? String ?? "").isEmpty,
                       "reveal should record the resolved working directory")
        StateDumpReader.attach(self, name: "block-menu-actions")
    }
}
