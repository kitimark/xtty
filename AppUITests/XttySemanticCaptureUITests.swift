import XCTest

// e2e for semantic capture (the add-semantic-capture change, P4a). Drives a real
// zsh — with xtty's automatic shell-integration injection active — and asserts via
// the DEBUG state dump that command blocks form with exit codes, the live cwd
// tracks `cd`, and a full-screen (alternate-screen) program does not become a
// normal command block.
//
// Block/cwd capture depends on the shell-integration hooks actually loading, which
// in turn depends on the host's own zsh config cooperating (additive hooks). Those
// two tests degrade gracefully (screenshot only) when capture isn't active in the
// harness environment. Alt-screen detection is engine-driven (independent of the
// shell hooks), so that test asserts unconditionally.
final class XttySemanticCaptureUITests: XCTestCase {

    private func blocks(in state: [String: Any]?) -> [[String: Any]] {
        (state?["blocks"] as? [[String: Any]]) ?? []
    }

    /// Wait until the DEBUG dump shows semantic capture is live (a non-empty last
    /// action), proving the injected hooks are emitting OSC 133. Returns false when
    /// capture never activates (uncooperative host config) so callers can skip.
    private func waitForCaptureActive(timeout: TimeInterval) -> Bool {
        StateDumpReader.waitForState(timeout: timeout) {
            !(($0["lastSemanticAction"] as? String) ?? "").isEmpty
        } != nil
    }

    private func type(_ command: String, into app: XCUIApplication) {
        app.typeText(command)
        app.typeKey(.enter, modifierFlags: [])
    }

    func testCommandsProduceBlocksWithExitCodes() {
        let app = launchConfigured(config: "")
        guard StateDumpReader.waitForState(timeout: 10) != nil else {
            attachScreenshot("no-state-dump (Release?)")
            return
        }
        _ = GridDumpReader.waitForNonEmpty(timeout: 5)
        // A no-op command lets capture prove itself before we assert.
        type("true", into: app)
        guard waitForCaptureActive(timeout: 8) else {
            attachScreenshot("semantic-capture-inactive (host zsh config?)")
            return
        }
        type("false", into: app)

        // The `false` block closes at the next prompt's D mark.
        let state = StateDumpReader.waitForState(timeout: 10) {
            (($0["blocks"] as? [[String: Any]]) ?? []).contains { ($0["state"] as? String) == "failed" }
        }
        let bs = blocks(in: state)
        XCTAssertTrue(
            bs.contains { ($0["state"] as? String) == "succeeded" && ($0["exitCode"] as? Int) == 0 },
            "`true` should yield a succeeded block with exit code 0; blocks=\(bs)")
        XCTAssertTrue(
            bs.contains { ($0["state"] as? String) == "failed" && (($0["exitCode"] as? Int) ?? 0) != 0 },
            "`false` should yield a failed block with a non-zero exit code; blocks=\(bs)")
        StateDumpReader.attach(self, name: "blocks-state")
        attachScreenshot("blocks")
    }

    func testChangingDirectoryUpdatesLiveCwd() {
        let app = launchConfigured(config: "")
        guard StateDumpReader.waitForState(timeout: 10) != nil else {
            attachScreenshot("no-state-dump (Release?)")
            return
        }
        _ = GridDumpReader.waitForNonEmpty(timeout: 5)
        type("cd /tmp", into: app)
        guard waitForCaptureActive(timeout: 8) else {
            attachScreenshot("semantic-capture-inactive (host zsh config?)")
            return
        }
        let state = StateDumpReader.waitForState(timeout: 10) {
            ($0["currentDirectory"] as? String) == "/tmp"
        }
        XCTAssertEqual(state?["currentDirectory"] as? String, "/tmp",
                       "the live working directory should follow `cd /tmp`")
        StateDumpReader.attach(self, name: "cwd-state")
    }

    func testFullScreenAppDoesNotBecomeACommandBlock() {
        let app = launchConfigured(config: "")
        guard StateDumpReader.waitForState(timeout: 10) != nil else {
            attachScreenshot("no-state-dump (Release?)")
            return
        }
        _ = GridDumpReader.waitForNonEmpty(timeout: 5)

        // `tput smcup` switches to the alternate screen; detection is engine-driven
        // (fires regardless of shell integration), so this assertion is unconditional.
        type("tput smcup", into: app)
        let altState = StateDumpReader.waitForState(timeout: 10) {
            ($0["isAlternateScreen"] as? Bool) == true
        }
        XCTAssertEqual(altState?["isAlternateScreen"] as? Bool, true,
                       "tput smcup should put the session on the alternate screen")
        attachScreenshot("alt-screen-active")

        // Return to the normal screen.
        type("tput rmcup", into: app)
        let backState = StateDumpReader.waitForState(timeout: 10) {
            ($0["isAlternateScreen"] as? Bool) == false
        }
        XCTAssertEqual(backState?["isAlternateScreen"] as? Bool, false,
                       "tput rmcup should return to the normal screen")

        // The full-screen excursion must not produce a normal (succeeded/failed)
        // command block — at most an opaque one.
        let bs = blocks(in: backState)
        XCTAssertFalse(
            bs.contains { ($0["state"] as? String) == "succeeded" || ($0["state"] as? String) == "failed" },
            "a full-screen program should not become a normal command block; blocks=\(bs)")
    }
}
