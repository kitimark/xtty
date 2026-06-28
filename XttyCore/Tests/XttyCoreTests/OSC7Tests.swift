import XCTest
@testable import XttyCore

final class OSC7Tests: XCTestCase {
    private let local: Set<String> = ["", "localhost", "mymac", "mymac.local"]

    func testFileURLPercentDecodesPath() {
        let wd = OSC7.decode("file://mymac/Users/me/My%20Project", localHostNames: local)
        XCTAssertEqual(wd?.path, "/Users/me/My Project")
        XCTAssertEqual(wd?.host, "mymac")
        XCTAssertEqual(wd?.isRemote, false)
    }

    func testKittySchemeKeepsPathRaw() {
        // kitty-shell-cwd:// is deliberately NOT percent-encoded — keep it verbatim.
        let wd = OSC7.decode("kitty-shell-cwd://mymac/Users/me/My Project", localHostNames: local)
        XCTAssertEqual(wd?.path, "/Users/me/My Project")
        XCTAssertEqual(wd?.isRemote, false)
    }

    func testKittySchemeDoesNotPercentDecode() {
        // A literal %20 under kitty-shell-cwd:// stays literal (no decoding).
        let wd = OSC7.decode("kitty-shell-cwd://mymac/a%20b", localHostNames: local)
        XCTAssertEqual(wd?.path, "/a%20b")
    }

    func testRemoteHostIsFlagged() {
        let wd = OSC7.decode("file://build-box/var/log", localHostNames: local)
        XCTAssertEqual(wd?.path, "/var/log")
        XCTAssertEqual(wd?.host, "build-box")
        XCTAssertEqual(wd?.isRemote, true)
    }

    func testLocalhostAndEmptyHostAreLocal() {
        XCTAssertEqual(OSC7.decode("file://localhost/tmp", localHostNames: local)?.isRemote, false)
        XCTAssertEqual(OSC7.decode("file:///tmp", localHostNames: local)?.isRemote, false)
        XCTAssertEqual(OSC7.decode("file:///tmp", localHostNames: local)?.path, "/tmp")
    }

    func testShortHostnameMatchesLocal() {
        XCTAssertEqual(OSC7.decode("kitty-shell-cwd://mymac/tmp", localHostNames: local)?.isRemote, false)
        XCTAssertEqual(OSC7.decode("kitty-shell-cwd://mymac.local/tmp", localHostNames: local)?.isRemote, false)
    }

    func testBareAbsolutePathIsAcceptedAsLocal() {
        let wd = OSC7.decode("/Users/me/src", localHostNames: local)
        XCTAssertEqual(wd?.path, "/Users/me/src")
        XCTAssertEqual(wd?.isRemote, false)
    }

    func testUnknownSchemeAndEmptyAreRejected() {
        XCTAssertNil(OSC7.decode("http://example.com/x", localHostNames: local))
        XCTAssertNil(OSC7.decode("", localHostNames: local))
        XCTAssertNil(OSC7.decode("   ", localHostNames: local))
        XCTAssertNil(OSC7.decode("file://host", localHostNames: local))  // no path
    }

    func testWhitespaceIsTrimmed() {
        let wd = OSC7.decode("  file://mymac/tmp\n", localHostNames: local)
        XCTAssertEqual(wd?.path, "/tmp")
    }
}
