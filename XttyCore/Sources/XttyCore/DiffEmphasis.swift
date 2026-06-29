import Foundation

/// View-free **token-level intra-line diff emphasis** (the P6a+
/// `add-git-review-polish` change). Given a parsed `FileDiff`, it annotates the
/// changed token spans within a **balanced, bounded replacement run** — a maximal
/// block of consecutive deletions immediately followed by the *same number* of
/// additions, paired 1:1.
///
/// Tokenizing **is** the word-boundary handling (the delta/zed shape), so emphasis
/// is word-aligned by construction — no separate "snap" pass. The cost lever is the
/// tokenization, not trimming: a small LCS/DP runs over ~tens of tokens, bounded by
/// a per-line byte cap. Everything degrades to plain whole-line styling (empty
/// emphasis) when a gate is not met — it never errors and never does unbounded work.
/// Unit-testable without the app or a view.
public enum DiffEmphasis {
    /// Emphasize a replacement run only when del-count == add-count <= this.
    static let maxPairs = 5
    /// Per-line byte cap — bounds the DP and excludes a pathological long line in
    /// an otherwise small run.
    static let maxLineBytes = 512
    /// Drop a line's emphasis when more than this fraction changed (a near-total
    /// rewrite reads better as a plain whole-line change).
    static let maxEmphasizedFraction = 0.6

    /// Annotate `diff` with intra-line emphasis. Returns a copy; binary/empty
    /// diffs and ungated runs are returned unchanged.
    public static func refine(_ diff: FileDiff) -> FileDiff {
        guard !diff.isBinary, !diff.hunks.isEmpty else { return diff }
        let hunks = diff.hunks.map(refineHunk)
        return FileDiff(header: diff.header, hunks: hunks, isBinary: diff.isBinary,
                        truncated: diff.truncated, addedCount: diff.addedCount,
                        removedCount: diff.removedCount)
    }

    private static func refineHunk(_ hunk: DiffHunk) -> DiffHunk {
        var lines = hunk.lines
        var i = 0
        while i < lines.count {
            guard lines[i].kind == .deletion else { i += 1; continue }
            // Maximal replacement run: consecutive deletions, then consecutive
            // additions (a context/header line between them ends the run).
            var delEnd = i
            while delEnd < lines.count, lines[delEnd].kind == .deletion { delEnd += 1 }
            var addEnd = delEnd
            while addEnd < lines.count, lines[addEnd].kind == .addition { addEnd += 1 }
            let delCount = delEnd - i, addCount = addEnd - delEnd
            // Structural gate: both non-empty, equal counts, <= maxPairs pairs.
            guard addCount > 0, delCount == addCount, delCount <= maxPairs else {
                i = delEnd; continue
            }
            for k in 0..<delCount {
                let d = i + k, a = delEnd + k
                let delContent = lines[d].content, addContent = lines[a].content
                // Size gate: byte cap on each line (bytes >= graphemes, safe bound).
                guard delContent.utf8.count <= maxLineBytes,
                      addContent.utf8.count <= maxLineBytes else { continue }
                guard let (delRanges, addRanges) = emphasize(del: delContent, add: addContent)
                else { continue }
                lines[d] = lines[d].withEmphasis(delRanges)
                lines[a] = lines[a].withEmphasis(addRanges)
            }
            i = addEnd
        }
        return DiffHunk(header: hunk.header, lines: lines)
    }

    // MARK: token-level diff

    private enum CharClass { case word, space, punct }
    private static func classOf(_ c: Character) -> CharClass {
        if c == " " || c == "\t" { return .space }
        if c.isLetter || c.isNumber || c == "_" { return .word }
        return .punct
    }

    /// A token: its text (for content comparison) and its absolute Character-offset
    /// range in the source string.
    private struct Tok { let s: String; let start: Int; let end: Int }

    /// Split into word / whitespace runs plus single-char punctuation tokens, each
    /// tagged with its Character-offset range. Character (grapheme) units keep
    /// CJK + non-BMP emoji intact.
    private static func tokenize(_ s: String) -> [Tok] {
        let chars = Array(s)
        var toks: [Tok] = []
        var i = 0
        while i < chars.count {
            let cls = classOf(chars[i])
            var j = i + 1
            if cls != .punct {
                while j < chars.count, classOf(chars[j]) == cls { j += 1 }
            }
            toks.append(Tok(s: String(chars[i..<j]), start: i, end: j))
            i = j
        }
        return toks
    }

    /// Changed-token ranges on each side, or nil to leave the pair plain
    /// (identical, nothing changed, or a near-total rewrite per the ratio gate).
    private static func emphasize(del: String, add: String) -> ([Range<Int>], [Range<Int>])? {
        if del == add { return nil }
        let a = tokenize(del), b = tokenize(add)
        // Common prefix/suffix trim (by token content) — the cheap fast path;
        // trimmed tokens are unchanged and excluded from the DP.
        var p = 0
        while p < a.count, p < b.count, a[p].s == b[p].s { p += 1 }
        var ea = a.count, eb = b.count
        while ea > p, eb > p, a[ea - 1].s == b[eb - 1].s { ea -= 1; eb -= 1 }
        let aMid = Array(a[p..<ea]), bMid = Array(b[p..<eb])
        let (aCh, bCh) = lcsChanged(aMid, bMid)
        let aRanges = merge(aMid, aCh), bRanges = merge(bMid, bCh)
        if aRanges.isEmpty, bRanges.isEmpty { return nil }
        // Ratio gate: a line that mostly changed is a rewrite, not an edit.
        let aTotal = del.count, bTotal = add.count
        let aEmph = aRanges.reduce(0) { $0 + ($1.upperBound - $1.lowerBound) }
        let bEmph = bRanges.reduce(0) { $0 + ($1.upperBound - $1.lowerBound) }
        if aTotal > 0, Double(aEmph) / Double(aTotal) > maxEmphasizedFraction { return nil }
        if bTotal > 0, Double(bEmph) / Double(bTotal) > maxEmphasizedFraction { return nil }
        return (aRanges, bRanges)
    }

    /// LCS over tokens (by content) → indices of the *unmatched* (changed) tokens
    /// on each side.
    private static func lcsChanged(_ a: [Tok], _ b: [Tok]) -> ([Int], [Int]) {
        let n = a.count, m = b.count
        if n == 0 { return ([], Array(0..<m)) }
        if m == 0 { return (Array(0..<n), []) }
        var dp = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        for i in stride(from: n - 1, through: 0, by: -1) {
            for j in stride(from: m - 1, through: 0, by: -1) {
                dp[i][j] = a[i].s == b[j].s ? dp[i + 1][j + 1] + 1
                                            : max(dp[i + 1][j], dp[i][j + 1])
            }
        }
        var aMatched = Array(repeating: false, count: n)
        var bMatched = Array(repeating: false, count: m)
        var i = 0, j = 0
        while i < n, j < m {
            if a[i].s == b[j].s { aMatched[i] = true; bMatched[j] = true; i += 1; j += 1 }
            else if dp[i + 1][j] >= dp[i][j + 1] { i += 1 }
            else { j += 1 }
        }
        return ((0..<n).filter { !aMatched[$0] }, (0..<m).filter { !bMatched[$0] })
    }

    /// Map changed-token indices to merged Character-offset ranges (adjacent
    /// ranges coalesce).
    private static func merge(_ toks: [Tok], _ changed: [Int]) -> [Range<Int>] {
        let ranges = changed.map { toks[$0].start..<toks[$0].end }
            .sorted { $0.lowerBound < $1.lowerBound }
        var out: [Range<Int>] = []
        for r in ranges {
            if let last = out.last, r.lowerBound <= last.upperBound {
                out[out.count - 1] = last.lowerBound..<Swift.max(last.upperBound, r.upperBound)
            } else {
                out.append(r)
            }
        }
        return out
    }
}
