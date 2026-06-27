import XCTest
@testable import XttyCore

// Smoke tests for XttyCore. These run via `swift test` without launching the
// app — proving the core is independently testable (app-shell spec:
// "Core is independently testable").
final class XttyCoreTests: XCTestCase {
    func testMilestoneMarkerIsSet() {
        XCTAssertEqual(XttyCore.milestone, "P0: app skeleton")
    }
}
