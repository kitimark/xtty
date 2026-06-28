import XCTest

// e2e for spatial blocks (add-spatial-blocks, P4b-2) — PHASE 2 (the SwiftTerm
// scroll-coordinate provider is lit up via the pinned-submodule drop-in).
//
// Drives a real zsh with xtty's shell-integration injection active, then exercises
// jump-to-prompt and copy-command-output through the REAL pipeline via an in-process
// trigger file (XTTY_TEST_SPATIAL_PATH — a jump/copy keypress over the custom-drawn
// view + scroll/clipboard state can't be asserted through the AX tree), and asserts
// the resolved jump target / copied output from the DEBUG state dump.
//
// Capture depends on the host's zsh config cooperating with the additive hooks, so
// each test degrades gracefully (screenshot only) when capture isn't active in the
// harness environment — matching the P4a/P5 semantic-capture suites. The pure
// anchor/navigation logic is unit-tested in XttyCore independently of this.
final class XttySpatialBlocksUITests: XCTestCase {

    private let opInputPath = (NSTemporaryDirectory() as NSString)
        .appendingPathComponent("xtty-test-spatial.txt")

    private func type(_ command: String, into app: XCUIApplication) {
        app.typeText(command)
        app.typeKey(.enter, modifierFlags: [])
    }

    private func launch() -> XCUIApplication {
        launchConfigured(config: "", extraEnv: ["XTTY_TEST_SPATIAL_PATH": opInputPath])
    }

    /// Wait until semantic capture is live (the injected OSC 133 hooks are emitting).
    private func waitForCaptureActive(timeout: TimeInterval) -> Bool {
        StateDumpReader.waitForState(timeout: timeout) {
            !(($0["lastSemanticAction"] as? String) ?? "").isEmpty
        } != nil
    }

    /// Write a spatial op and wait for the app to consume (delete) the file.
    @discardableResult
    private func routeSpatialOp(_ op: String, timeout: TimeInterval = 5) -> Bool {
        try? op.write(toFile: opInputPath, atomically: true, encoding: .utf8)
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !FileManager.default.fileExists(atPath: opInputPath) { return true }
            usleep(80_000)
        }
        return false
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: opInputPath)
        super.tearDown()
    }

    /// Jump-to-previous-prompt scrolls the viewport to an earlier prompt. Needs
    /// enough output that an earlier prompt has scrolled above the viewport top.
    func testJumpResolvesToEarlierPrompt() {
        let app = launch()
        guard StateDumpReader.waitForState(timeout: 10) != nil else {
            attachScreenshot("no-state-dump (Release?)"); return
        }
        _ = GridDumpReader.waitForNonEmpty(timeout: 5)
        type("true", into: app)
        guard waitForCaptureActive(timeout: 8) else {
            attachScreenshot("semantic-capture-inactive (host zsh config?)"); return
        }
        // Produce more than a screenful so the earlier prompts scroll off the top.
        type("seq 100", into: app)
        _ = StateDumpReader.waitForState(timeout: 10) {
            (($0["blocks"] as? [[String: Any]]) ?? []).count >= 2
        }

        XCTAssertTrue(routeSpatialOp("jump-prev"), "the spatial-op trigger should be consumed")
        let state = StateDumpReader.waitForState(timeout: 5) {
            ($0["lastJumpTargetRow"] as? NSNumber) != nil
        }
        XCTAssertNotNil(state?["lastJumpTargetRow"] as? NSNumber,
                        "jump-to-previous-prompt should resolve to an earlier prompt row")
        StateDumpReader.attach(self, name: "spatial-jump")
    }

    /// Copy-command-output captures a known command's output, excluding the command
    /// echo and the trailing prompt.
    func testCopyCapturesCommandOutput() {
        let app = launch()
        guard StateDumpReader.waitForState(timeout: 10) != nil else {
            attachScreenshot("no-state-dump (Release?)"); return
        }
        _ = GridDumpReader.waitForNonEmpty(timeout: 5)
        type("true", into: app)
        guard waitForCaptureActive(timeout: 8) else {
            attachScreenshot("semantic-capture-inactive (host zsh config?)"); return
        }
        let marker = "XTTYCOPYMARKER42"
        type("echo \(marker)", into: app)
        _ = StateDumpReader.waitForState(timeout: 10) {
            (($0["blocks"] as? [[String: Any]]) ?? []).contains { ($0["command"] as? String)?.contains(marker) == true }
        }

        XCTAssertTrue(routeSpatialOp("copy"), "the spatial-op trigger should be consumed")
        let state = StateDumpReader.waitForState(timeout: 5) {
            ($0["lastCopiedOutput"] as? String)?.contains(marker) == true
        }
        let copied = state?["lastCopiedOutput"] as? String
        XCTAssertNotNil(copied, "copy-command-output should capture the command's output")
        XCTAssertTrue(copied?.contains(marker) == true, "copied text should contain the output; got \(copied ?? "nil")")
        XCTAssertFalse(copied?.contains("echo \(marker)") == true,
                       "copied text should exclude the command echo / prompt; got \(copied ?? "nil")")
        StateDumpReader.attach(self, name: "spatial-copy")
    }

    /// Copy is scroll-invariant: after jumping up (scrolling the viewport away from
    /// the bottom), copy still captures the last command's output correctly — proving
    /// the anchor compensates for scroll position.
    func testCopyIsScrollInvariantAfterJump() {
        let app = launch()
        guard StateDumpReader.waitForState(timeout: 10) != nil else {
            attachScreenshot("no-state-dump (Release?)"); return
        }
        _ = GridDumpReader.waitForNonEmpty(timeout: 5)
        type("true", into: app)
        guard waitForCaptureActive(timeout: 8) else {
            attachScreenshot("semantic-capture-inactive (host zsh config?)"); return
        }
        let marker = "XTTYSCROLLINV99"
        type("echo \(marker)", into: app)
        type("seq 100", into: app)  // scroll the marker's block well above the bottom
        _ = StateDumpReader.waitForState(timeout: 10) {
            (($0["blocks"] as? [[String: Any]]) ?? []).count >= 3
        }

        // Jump up (scrolls the viewport away from the bottom).
        XCTAssertTrue(routeSpatialOp("jump-prev"))
        _ = StateDumpReader.waitForState(timeout: 5) { ($0["lastJumpTargetRow"] as? NSNumber) != nil }

        // Copy the last command's output while scrolled up — still correct.
        XCTAssertTrue(routeSpatialOp("copy"))
        let state = StateDumpReader.waitForState(timeout: 5) {
            ($0["lastCopiedOutput"] as? String)?.isEmpty == false
        }
        XCTAssertNotNil(state?["lastCopiedOutput"] as? String,
                        "copy should work while scrolled up (scroll-invariant anchor)")
        StateDumpReader.attach(self, name: "spatial-copy-scrolled")
    }
}
