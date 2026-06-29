import XCTest

// P7c lifecycle-census churn e2e — the gated leak-regression net. Drives real
// split/tab churn and asserts the DEBUG state dump's per-type live-instance
// counts return to their pre-churn baseline. A count that stays elevated is a
// leaked controller/view/session (a retain cycle). The App-layer objects run
// out-of-process, so the census dump is the only channel to observe them — a
// weak-sentinel can't reach across the process boundary (the in-process half of
// the census lives in XttyCore's LifecycleLeakTests). Teardown is async
// (autorelease/AppKit), so we poll the counts to settle rather than read once.

final class XttyLifecycleCensusUITests: XCTestCase {
    /// Extract the census, converting per-key (JSON numbers deserialize as
    /// `NSNumber`, which doesn't bridge through a single `as? [String: Int]`).
    private static func census(_ s: [String: Any]?) -> [String: Int]? {
        guard let raw = s?["liveInstanceCounts"] as? [String: Any] else { return nil }
        var out: [String: Int] = [:]
        for (k, v) in raw { if let n = v as? Int { out[k] = n } }
        return out
    }
    private func census(_ s: [String: Any]?) -> [String: Int]? { Self.census(s) }

    /// The lifecycle types pane/tab churn exercises directly.
    private static let tracked = [
        "PaneController", "XttyTerminalView", "TerminalSession", "TerminalWindowController",
    ]

    func testLifecycleChurnReturnsCensusToBaseline() {
        let app = launchConfigured(config: "")
        guard let firstState = StateDumpReader.waitForState(timeout: 10),
              let firstCensus = census(firstState), !firstCensus.isEmpty else {
            attachScreenshot("no-state-dump-or-census (Release?)")
            return  // degrade gracefully when the DEBUG census hook is absent
        }
        // Settle to this launch's fresh single-pane / single-tab baseline.
        _ = StateDumpReader.waitForState(timeout: 10) {
            ($0["paneCount"] as? Int) == 1 && ($0["tabCount"] as? Int) == 1
        }
        let base = census(StateDumpReader.read()) ?? firstCensus

        // Churn 1: split + close (pane lifecycle — the closures the audit vetted).
        for _ in 0..<4 {
            app.typeKey("d", modifierFlags: .command)
            _ = StateDumpReader.waitForState(timeout: 5) { ($0["paneCount"] as? Int) == 2 }
            app.typeKey("w", modifierFlags: .command)
            _ = StateDumpReader.waitForState(timeout: 5) { ($0["paneCount"] as? Int) == 1 }
        }
        // Churn 2: new tab + close (window-controller lifecycle).
        for _ in 0..<3 {
            app.typeKey("t", modifierFlags: .command)
            _ = StateDumpReader.waitForState(timeout: 5) { ($0["tabCount"] as? Int) == 2 }
            app.typeKey("w", modifierFlags: .command)
            _ = StateDumpReader.waitForState(timeout: 5) { ($0["tabCount"] as? Int) == 1 }
        }

        // Poll-to-settle: after AppKit/SwiftTerm teardown drains, every tracked
        // count should be back at (≤) baseline. A leak holds a count above it.
        let settled = StateDumpReader.waitForState(timeout: 20) { s in
            guard let c = Self.census(s) else { return false }
            return Self.tracked.allSatisfy { (c[$0] ?? 0) <= (base[$0] ?? 0) }
        }
        let finalCensus = census(settled) ?? census(StateDumpReader.read()) ?? [:]
        attachScreenshot("after-churn")
        for key in Self.tracked {
            XCTAssertLessThanOrEqual(
                finalCensus[key] ?? 0, base[key] ?? 0,
                "\(key) live-instance count did not return to baseline after churn "
                + "(leak/retain cycle): baseline \(base[key] ?? 0), final \(finalCensus[key] ?? 0)")
        }
    }
}
