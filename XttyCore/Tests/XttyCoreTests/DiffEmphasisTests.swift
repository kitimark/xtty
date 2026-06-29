import XCTest
@testable import XttyCore

final class DiffEmphasisTests: XCTestCase {

    /// Parse a raw unified diff, refine it, and return per-line emphasis for the
    /// deletion and addition lines (in order).
    private func emphasis(_ raw: String) -> (del: [[Range<Int>]], add: [[Range<Int>]]) {
        let diff = DiffEmphasis.refine(DiffParser.parse(raw))
        var del: [[Range<Int>]] = [], add: [[Range<Int>]] = []
        for h in diff.hunks {
            for l in h.lines {
                if l.kind == .deletion { del.append(l.emphasis) }
                if l.kind == .addition { add.append(l.emphasis) }
            }
        }
        return (del, add)
    }

    func testSingleChangedWordIsEmphasized() {
        let (del, add) = emphasis("@@ -1 +1 @@\n-foo bar baz\n+foo qux baz\n")
        // content "foo bar baz" → "bar" at chars [4,7); only that token changes.
        XCTAssertEqual(del, [[4..<7]])
        XCTAssertEqual(add, [[4..<7]])
    }

    func testTwoSeparateEditsLeaveTheMiddleUnemphasized() {
        // The token-level differentiator: foo(a, b, c) → foo(x, b, y) emphasizes
        // only "a"→"x" and "c"→"y"; the unchanged ", b, " between them is NOT.
        let (del, add) = emphasis("@@ -1 +1 @@\n-foo(a, b, c)\n+foo(x, b, y)\n")
        XCTAssertEqual(del.count, 1)
        XCTAssertEqual(del[0].count, 2, "two separate changed spans, not one fat span")
        XCTAssertEqual(del[0], [4..<5, 10..<11])   // 'a' and 'c'
        XCTAssertEqual(add[0], [4..<5, 10..<11])   // 'x' and 'y'
        // The middle ", b, " (chars 5..10) must not be covered.
        XCTAssertFalse(del[0].contains { $0.contains(7) }, "the unchanged 'b' is not emphasized")
    }

    func testNearTotalRewriteFallsBackToWholeLine() {
        // Nothing in common → ratio gate trips → no intra-line emphasis.
        let (del, add) = emphasis("@@ -1 +1 @@\n-aaaaaaaaaa\n+zzzzzzzzzz\n")
        XCTAssertEqual(del, [[]])
        XCTAssertEqual(add, [[]])
    }

    func testUnbalancedRunIsNotEmphasized() {
        // 2 deletions, 1 addition → no 1:1 pairing → plain.
        let (del, add) = emphasis("@@ -1,2 +1 @@\n-foo\n-bar\n+baz\n")
        XCTAssertEqual(del, [[], []])
        XCTAssertEqual(add, [[]])
    }

    func testPureAdditionRunIsNotEmphasized() {
        let (del, add) = emphasis("@@ -1 +1,2 @@\n context\n+brand new line\n")
        XCTAssertTrue(del.isEmpty)
        XCTAssertEqual(add, [[]])
    }

    func testLinePairCapBoundary() {
        // 5 pairs → emphasized; 6 pairs → falls back (the run cap is 5).
        func run(_ n: Int) -> (del: [[Range<Int>]], add: [[Range<Int>]]) {
            var lines = ["@@ -1,\(n) +1,\(n) @@"]
            // One small changed token per line (well under the ratio gate).
            for i in 0..<n { lines.append("-prefix old\(i) suffix") }
            for i in 0..<n { lines.append("+prefix new\(i) suffix") }
            return emphasis(lines.joined(separator: "\n") + "\n")
        }
        let five = run(5)
        XCTAssertEqual(five.del.count, 5)
        XCTAssertTrue(five.del.allSatisfy { !$0.isEmpty }, "5 pairs are within the cap → emphasized")
        let six = run(6)
        XCTAssertEqual(six.del.count, 6)
        XCTAssertTrue(six.del.allSatisfy { $0.isEmpty }, "6 pairs exceed the cap → plain")
    }

    func testMultiLineBalancedRunEmphasizesEachPair() {
        let raw = "@@ -1,2 +1,2 @@\n-alpha one\n-beta two\n+alpha ONE\n+beta TWO\n"
        let (del, add) = emphasis(raw)
        XCTAssertEqual(del.count, 2)
        XCTAssertTrue(del.allSatisfy { !$0.isEmpty })
        XCTAssertTrue(add.allSatisfy { !$0.isEmpty })
    }

    func testCJKEmphasisUsesGraphemeOffsets() {
        // "日本 foo" → "中文 foo": the CJK word (2 Characters) changes; offsets are
        // grapheme-based so [0,2) covers 日本 / 中文, not byte counts.
        let (del, add) = emphasis("@@ -1 +1 @@\n-日本 foo\n+中文 foo\n")
        XCTAssertEqual(del, [[0..<2]])
        XCTAssertEqual(add, [[0..<2]])
    }

    func testNonBMPEmojiEmphasisIsOneCharacter() {
        let (del, add) = emphasis("@@ -1 +1 @@\n-👍 ok\n+👎 ok\n")
        XCTAssertEqual(del, [[0..<1]], "a non-BMP emoji is one grapheme/Character")
        XCTAssertEqual(add, [[0..<1]])
    }

    func testRefineIsIdentityForBinary() {
        XCTAssertEqual(DiffEmphasis.refine(.binary), .binary)
    }
}

final class GitCommandTests: XCTestCase {
    func testGitInvocationsDetected() {
        XCTAssertTrue(GitCommand.isGitInvocation("git status"))
        XCTAssertTrue(GitCommand.isGitInvocation("git rebase -i HEAD~3"))
        XCTAssertTrue(GitCommand.isGitInvocation("   git   add ."))   // leading ws + multi-space
        XCTAssertTrue(GitCommand.isGitInvocation("git"))
        XCTAssertTrue(GitCommand.isGitInvocation("git\tlog"))         // tab-delimited
    }

    func testNonGitOrGitPrefixedAreExcluded() {
        XCTAssertFalse(GitCommand.isGitInvocation("github-cli pr list"))
        XCTAssertFalse(GitCommand.isGitInvocation("gitk"))
        XCTAssertFalse(GitCommand.isGitInvocation("mygit push"))
        XCTAssertFalse(GitCommand.isGitInvocation(""))
        XCTAssertFalse(GitCommand.isGitInvocation(nil))
    }

    func testConservativeFalseNegativesPreferOverRefresh() {
        // These are git but NOT matched — acceptable (they over-refresh, never
        // wrongly suppress the poll).
        XCTAssertFalse(GitCommand.isGitInvocation("sudo git push"))
        XCTAssertFalse(GitCommand.isGitInvocation("/usr/bin/git log"))
        XCTAssertFalse(GitCommand.isGitInvocation("GIT_OPTIONAL_LOCKS=0 git status"))
        XCTAssertFalse(GitCommand.isGitInvocation("cd repo && git status"))
    }
}
