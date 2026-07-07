import XCTest
@testable import XttyCore

final class LocalHostTests: XCTestCase {
    func testDerivesFullAndShortFormPlusConstants() {
        let names = LocalHost.names(from: "mymac.local")
        XCTAssertEqual(names, ["", "localhost", "mymac.local", "mymac"])
    }

    func testLowercasesTheHostName() {
        // The set is compared against a lowercased OSC 7 authority, so the
        // derived names must already be lowercased.
        let names = LocalHost.names(from: "Marks-MBP.Local")
        XCTAssertTrue(names.contains("marks-mbp.local"))
        XCTAssertTrue(names.contains("marks-mbp"))
        XCTAssertFalse(names.contains("Marks-MBP.Local"))
    }

    func testSingleLabelNameHasNoDistinctShortForm() {
        // A name with no "." is its own short form.
        let names = LocalHost.names(from: "buildbox")
        XCTAssertEqual(names, ["", "localhost", "buildbox"])
    }

    func testEmptyHostNameYieldsOnlyConstants() {
        // gethostname can return an empty string on a misconfigured host; the
        // derivation degrades to the always-local constants.
        let names = LocalHost.names(from: "")
        XCTAssertEqual(names, ["", "localhost"])
    }

    func testDerivedSetClassifiesLocalHostLocalViaOSC7() {
        // The whole point: a cwd reported under the machine's own name (and its
        // short form) classifies local when decoded with this set.
        let local = LocalHost.names(from: "mymac.local")
        XCTAssertEqual(OSC7.decode("file://mymac.local/tmp", localHostNames: local)?.isRemote, false)
        XCTAssertEqual(OSC7.decode("file://mymac/tmp", localHostNames: local)?.isRemote, false)
        XCTAssertEqual(OSC7.decode("file://build-box/tmp", localHostNames: local)?.isRemote, true)
    }
}
