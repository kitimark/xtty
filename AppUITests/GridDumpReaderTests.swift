import XCTest

/// Pure-logic coverage for `GridDumpReader`'s wrap-tolerant matcher. This test
/// does NOT launch the app: it feeds synthetic grid-dump strings, so the
/// soft-wrap path is exercised deterministically — independent of a real
/// terminal's width or prompt length, which is exactly the CI-specific condition
/// the matcher makes the focus-on-activate assertion robust to (research §12).
final class GridDumpReaderTests: XCTestCase {

    // Mirrors the dump for a marker typed at a long prompt: physical rows joined
    // with "\n", the marker wrapped at the right edge (1 char on the prompt row,
    // the rest on the next). See App/UITestDump.swift.
    private let token = "XTTYFOCUS3317"
    private let wrapped = "longhost:/ runner$ X\nTTYFOCUS3317\n\n"

    func testStrictMatchingMissesAWrapSplitToken() {
        XCTAssertFalse(GridDumpReader.gridContains(wrapped, token, ignoringLineWraps: false),
                       "strict matching must NOT find a token split across a soft-wrap boundary")
    }

    func testWrapTolerantMatchingFindsAWrapSplitToken() {
        XCTAssertTrue(GridDumpReader.gridContains(wrapped, token, ignoringLineWraps: true),
                      "wrap-tolerant matching must find a token split across a soft-wrap boundary")
    }

    func testWrapTolerantMatchingDoesNotFabricateAnAbsentToken() {
        let absent = "longhost:/ runner$ \n\n\n"
        XCTAssertFalse(GridDumpReader.gridContains(absent, token, ignoringLineWraps: true),
                       "wrap tolerance must not fabricate a match for an absent token")
    }

    func testWrapTolerantMatchingStillFindsAnUnwrappedToken() {
        // The common case (token on a single physical row) matches in both modes.
        let grid = "runner$ QUAKEMARK\n\n"
        XCTAssertTrue(GridDumpReader.gridContains(grid, "QUAKEMARK", ignoringLineWraps: true))
        XCTAssertTrue(GridDumpReader.gridContains(grid, "QUAKEMARK", ignoringLineWraps: false))
    }
}
