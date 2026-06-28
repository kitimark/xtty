import XCTest

// e2e for spatial blocks (add-spatial-blocks, P4b-2) — PHASE 1 (the SwiftTerm
// scroll-coordinate provider is deferred, so the production seam returns nil).
// A real jump/copy keypress over the custom-drawn view + scroll/clipboard state
// can't be asserted via the AX tree, so the test writes a spatial-op string
// ("jump-prev" / "jump-next" / "copy") to a temp file whose path it passes via the
// XTTY_TEST_SPATIAL_PATH launch env; the app's DEBUG dump timer polls it and drives
// the action through the REAL pipeline, recording the resolved jump target / copied
// output in the state dump.
//
// In Phase 1 every spatial op is a GRACEFUL NO-OP (no anchors are captured without
// the provider), so the contract under test is exactly the spec's
// "graceful degradation when the coordinate provider is unavailable": the trigger
// fires (the file is consumed) but the dump shows no jump target / no copied output.
// The happy path (real rows → jump/copy) is unit-tested in XttyCore (BlockTracker /
// BlockNavigation) and lands in the Phase-2 e2e once the provider is wired.
final class XttySpatialBlocksUITests: XCTestCase {

    // The sandboxed runner can't write /tmp, so it writes the op to its own
    // (writable) temp dir; the app reads this path via XTTY_TEST_SPATIAL_PATH.
    private let opInputPath = (NSTemporaryDirectory() as NSString)
        .appendingPathComponent("xtty-test-spatial.txt")

    private func type(_ command: String, into app: XCUIApplication) {
        app.typeText(command)
        app.typeKey(.enter, modifierFlags: [])
    }

    private func launch() -> XCUIApplication {
        launchConfigured(config: "", extraEnv: ["XTTY_TEST_SPATIAL_PATH": opInputPath])
    }

    /// Write a spatial op and wait for the app to consume (delete) the file —
    /// evidence the op was actually driven through the pipeline.
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

    /// Jump-to-prompt with no coordinate provider is a graceful no-op: the trigger
    /// fires but the dump records no jump target.
    func testJumpIsGracefulNoOpWithoutProvider() {
        let app = launch()
        guard StateDumpReader.waitForState(timeout: 10) != nil else {
            attachScreenshot("no-state-dump (Release?)")
            return
        }
        _ = GridDumpReader.waitForNonEmpty(timeout: 5)

        // Run a couple of commands so blocks exist (anchors are still nil in Phase 1).
        type("echo one", into: app)
        type("echo two", into: app)

        XCTAssertTrue(routeSpatialOp("jump-prev"), "the spatial-op trigger should be consumed by the app")
        let state = StateDumpReader.waitForState(timeout: 5)
        XCTAssertNil(state?["lastJumpTargetRow"] as? NSNumber,
                     "without the coordinate provider, jump-to-prompt is a no-op (no target row)")
        StateDumpReader.attach(self, name: "spatial-jump-noop")
    }

    /// Copy-command-output with no coordinate provider is a graceful no-op: the
    /// trigger fires but the dump records no copied output (and nothing wrong is put
    /// on the clipboard).
    func testCopyIsGracefulNoOpWithoutProvider() {
        let app = launch()
        guard StateDumpReader.waitForState(timeout: 10) != nil else {
            attachScreenshot("no-state-dump (Release?)")
            return
        }
        _ = GridDumpReader.waitForNonEmpty(timeout: 5)

        type("echo hello-world", into: app)

        XCTAssertTrue(routeSpatialOp("copy"), "the spatial-op trigger should be consumed by the app")
        let state = StateDumpReader.waitForState(timeout: 5)
        XCTAssertNil(state?["lastCopiedOutput"] as? String,
                     "without the coordinate provider, copy-command-output is a no-op (nothing copied)")
        StateDumpReader.attach(self, name: "spatial-copy-noop")
    }
}
