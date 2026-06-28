import XCTest
@testable import XttyCore

// Porcelain v1 `-z` records are NUL-terminated "XY PATH"; tests build that input
// by joining records with "\0".
final class GitStatusParserTests: XCTestCase {
    private func z(_ records: [String]) -> String {
        records.joined(separator: "\0") + "\0"
    }

    func testClassifiesTheCommonStates() {
        let raw = z([
            " M src/Foo.swift",   // unstaged modified
            "M  staged.txt",      // staged modified
            "A  new.swift",       // added
            " D gone.txt",        // deleted
            "?? scratch.txt",     // untracked
            "UU conflict.swift",  // unmerged
        ])
        let files = GitStatusParser.parse(raw)
        let byPath = Dictionary(uniqueKeysWithValues: files.map { ($0.path, $0.status) })
        XCTAssertEqual(byPath["src/Foo.swift"], .modified)
        XCTAssertEqual(byPath["staged.txt"], .modified)
        XCTAssertEqual(byPath["new.swift"], .added)
        XCTAssertEqual(byPath["gone.txt"], .deleted)
        XCTAssertEqual(byPath["scratch.txt"], .untracked)
        XCTAssertEqual(byPath["conflict.swift"], .conflicted)
    }

    func testCategoriesGroupCorrectly() {
        let raw = z([" M a.txt", "?? b.txt", "AA c.txt"])
        let files = GitStatusParser.parse(raw)
        XCTAssertEqual(files.filter { $0.status.category == .changes }.map(\.path), ["a.txt"])
        XCTAssertEqual(files.filter { $0.status.category == .untracked }.map(\.path), ["b.txt"])
        XCTAssertEqual(files.filter { $0.status.category == .conflicts }.map(\.path), ["c.txt"])
    }

    func testSkipsUntrackedDirectoryEntries() {
        let raw = z(["?? build/", "?? real.txt"])
        let files = GitStatusParser.parse(raw)
        XCTAssertEqual(files.map(\.path), ["real.txt"])
    }

    func testDeduplicatesAndSortsByPath() {
        let raw = z(["?? z.txt", " M a.txt", "?? z.txt"])
        let files = GitStatusParser.parse(raw)
        XCTAssertEqual(files.map(\.path), ["a.txt", "z.txt"])
    }

    func testConsumesRenameOriginField() {
        // Defensive: an R record carries a second NUL field (the origin path)
        // which must be consumed, not parsed as its own entry.
        let raw = "R  renamed.swift\u{0}original.swift\u{0} M after.txt\u{0}"
        let files = GitStatusParser.parse(raw)
        XCTAssertEqual(files.map(\.path), ["after.txt", "renamed.swift"])
        XCTAssertEqual(files.first(where: { $0.path == "renamed.swift" })?.status, .renamed)
    }

    func testEmptyInputYieldsNoFiles() {
        XCTAssertTrue(GitStatusParser.parse("").isEmpty)
    }
}

final class NumstatParserTests: XCTestCase {
    func testParsesCountsAndBinary() {
        let raw = "8\t2\tApp/Foo.swift\u{0}-\t-\tassets/img.png\u{0}"
        let result = NumstatParser.parse(raw)
        XCTAssertEqual(result["App/Foo.swift"]?.added, 8)
        XCTAssertEqual(result["App/Foo.swift"]?.removed, 2)
        XCTAssertEqual(result["App/Foo.swift"]?.isBinary, false)
        XCTAssertEqual(result["assets/img.png"]?.isBinary, true)
        XCTAssertNil(result["assets/img.png"]?.added ?? nil)
    }
}
