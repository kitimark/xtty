import XCTest
@testable import XttyCore

final class DiffParserTests: XCTestCase {
    func testParsesHeaderHunkAndCounts() {
        let raw = """
        diff --git a/foo.txt b/foo.txt
        index e69de29..0d1f2c3 100644
        --- a/foo.txt
        +++ b/foo.txt
        @@ -1,3 +1,4 @@
         context
        -removed
        +added1
        +added2
         tail
        """
        let diff = DiffParser.parse(raw)
        XCTAssertFalse(diff.isBinary)
        XCTAssertFalse(diff.truncated)
        XCTAssertEqual(diff.addedCount, 2)
        XCTAssertEqual(diff.removedCount, 1)
        // Pre-hunk lines are file headers, not deletions/additions.
        XCTAssertEqual(diff.header.count, 4)
        XCTAssertTrue(diff.header.allSatisfy { $0.kind == .fileHeader })
        XCTAssertEqual(diff.hunks.count, 1)
        XCTAssertTrue(diff.hunks[0].header.hasPrefix("@@"))
        let kinds = diff.hunks[0].lines.map(\.kind)
        XCTAssertEqual(kinds, [.context, .deletion, .addition, .addition, .context])
    }

    func testHeaderDashesAreNotCountedAsDeletions() {
        // `---`/`+++` before the first @@ must not inflate the +/- counts.
        let raw = """
        --- a/x
        +++ b/x
        @@ -1 +1 @@
        -a
        +b
        """
        let diff = DiffParser.parse(raw)
        XCTAssertEqual(diff.addedCount, 1)
        XCTAssertEqual(diff.removedCount, 1)
    }

    func testBinaryDiffDetected() {
        let raw = "diff --git a/img.png b/img.png\nBinary files a/img.png and b/img.png differ\n"
        let diff = DiffParser.parse(raw)
        XCTAssertTrue(diff.isBinary)
        XCTAssertTrue(diff.hunks.isEmpty)
    }

    func testLongLineIsTruncated() {
        let long = String(repeating: "x", count: 50)
        let raw = "@@ -1 +1 @@\n+\(long)\n"
        let diff = DiffParser.parse(raw, maxLineLength: 10)
        XCTAssertTrue(diff.truncated)
        XCTAssertTrue(diff.hunks[0].lines[0].truncated)
        XCTAssertLessThanOrEqual(diff.hunks[0].lines[0].text.count, 11) // 10 + ellipsis
    }

    func testMaxLinesCapStopsAndFlagsTruncation() {
        var lines = ["@@ -1,100 +1,100 @@"]
        for i in 0..<20 { lines.append("+line\(i)") }
        let diff = DiffParser.parse(lines.joined(separator: "\n"), maxLines: 5)
        XCTAssertTrue(diff.truncated)
        XCTAssertEqual(diff.hunks[0].lines.count, 5)
    }

    func testNoNewlineMarkerClassified() {
        let raw = "@@ -1 +1 @@\n-a\n+b\n\\ No newline at end of file\n"
        let diff = DiffParser.parse(raw)
        XCTAssertEqual(diff.hunks[0].lines.last?.kind, .noNewline)
    }
}
