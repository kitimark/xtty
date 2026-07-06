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

    /// Readiness gate (D1): prove the fresh shell has *executed* a command — rc
    /// files done, back at its prompt — before we close it. Types `echo $((base+i))`;
    /// the *output* token `base+i` appears only in the command's output, never in
    /// the echoed input line (which shows the unevaluated `$((base+i))`), so a grid
    /// match proves execution, not mere keypress echo. The per-iteration token is
    /// unique (41001…/42001…), so a stale dump from the prior iteration can't
    /// false-positive (D2). Returns true when the token lands; on timeout it attaches
    /// the dump/screenshot, fails naming the loop+iteration, and returns false so the
    /// caller skips the ⌘W it would otherwise race into a still-starting shell (D3).
    @discardableResult
    private func waitShellReady(_ app: XCUIApplication, base: Int, i: Int, loop: String) -> Bool {
        let token = base + i
        app.typeText("echo $((\(base)+\(i)))")
        app.typeKey(.enter, modifierFlags: [])
        // 15 s ≈ 7.5× the worst probe-measured settle; wrap-tolerant because long
        // prompts soft-wrap the token across dump rows (D4).
        if GridDumpReader.waitForContains("\(token)", timeout: 15, ignoringLineWraps: true) {
            return true
        }
        attachGridDump("\(loop)-iter\(i)-shell-not-ready")
        attachScreenshot("\(loop)-iter\(i)-shell-not-ready")
        XCTFail("\(loop) loop iteration \(i): fresh shell never executed the readiness "
                + "marker (token \(token)) within 15 s — refusing to send ⌘W into a shell "
                + "still sourcing startup files (harden-churn-shell-readiness D1/D3)")
        return false
    }

    func testLifecycleChurnReturnsCensusToBaseline() {
        continueAfterFailure = false  // D3: a failed churn precondition halts the
        // test rather than cascading further ⌘-chords into a wedged/modal state.
        let app = launchConfigured(config: "")
        guard let firstState = StateDumpReader.waitForState(timeout: 10),
              let firstCensus = census(firstState), !firstCensus.isEmpty else {
            attachScreenshot("no-state-dump-or-census (Release?)")
            return  // degrade gracefully when the DEBUG census hook is absent
        }
        requireXttyMainMenu(in: app)  // the churn loops drive Cmd+D/W/T
        // Settle to this launch's fresh single-pane / single-tab baseline.
        _ = StateDumpReader.waitForState(timeout: 10) {
            ($0["paneCount"] as? Int) == 1 && ($0["tabCount"] as? Int) == 1
        }
        let base = census(StateDumpReader.read()) ?? firstCensus

        // Churn 1: split + close (pane lifecycle — the closures the audit vetted).
        // Every precondition is a hard assertion (D3): a step that fails to
        // materialize halts the test at its own iteration with artifacts, and never
        // sends the ⌘W it would otherwise race into a still-starting shell.
        for i in 1...4 {
            app.typeKey("d", modifierFlags: .command)
            guard StateDumpReader.waitForState(timeout: 5, where: { ($0["paneCount"] as? Int) == 2 }) != nil else {
                attachGridDump("pane-iter\(i)-split-not-registered")
                XCTFail("pane loop iteration \(i): split never reached paneCount==2 within 5 s")
                return
            }
            guard waitShellReady(app, base: 41000, i: i, loop: "pane") else { return }
            app.typeKey("w", modifierFlags: .command)
            guard StateDumpReader.waitForState(timeout: 5, where: { ($0["paneCount"] as? Int) == 1 }) != nil else {
                attachGridDump("pane-iter\(i)-close-not-registered")
                XCTFail("pane loop iteration \(i): close never returned to paneCount==1 within "
                        + "5 s (a confirm-close alert may have blocked ⌘W — the race this change fixes)")
                return
            }
        }
        // Churn 2: new tab + close (window-controller lifecycle). Same gate: the tab
        // loop closes an equally fresh shell through the identical confirm-close path.
        for i in 1...3 {
            app.typeKey("t", modifierFlags: .command)
            guard StateDumpReader.waitForState(timeout: 5, where: { ($0["tabCount"] as? Int) == 2 }) != nil else {
                attachGridDump("tab-iter\(i)-newtab-not-registered")
                XCTFail("tab loop iteration \(i): new tab never reached tabCount==2 within 5 s")
                return
            }
            guard waitShellReady(app, base: 42000, i: i, loop: "tab") else { return }
            app.typeKey("w", modifierFlags: .command)
            guard StateDumpReader.waitForState(timeout: 5, where: { ($0["tabCount"] as? Int) == 1 }) != nil else {
                attachGridDump("tab-iter\(i)-close-not-registered")
                XCTFail("tab loop iteration \(i): close never returned to tabCount==1 within "
                        + "5 s (a confirm-close alert may have blocked ⌘W — the race this change fixes)")
                return
            }
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
