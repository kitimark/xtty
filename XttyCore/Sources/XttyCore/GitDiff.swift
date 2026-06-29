import Foundation

/// The kind of a line in a parsed unified diff (drives row styling in the view).
public enum DiffLineKind: String, Equatable, Sendable {
    case context       // unchanged line (leading space)
    case addition      // leading '+'
    case deletion      // leading '-'
    case hunkHeader    // `@@ -a,b +c,d @@`
    case fileHeader    // `diff --git`, `index`, `---`, `+++`, mode/rename lines
    case noNewline     // `\ No newline at end of file`
}

/// One classified line of a unified diff. `text` keeps the leading marker so the
/// view can render it verbatim; truncated lines set `truncated`.
public struct DiffLine: Equatable, Sendable {
    public let kind: DiffLineKind
    public let text: String
    public let truncated: Bool
    /// Optional intra-line emphasis (P6a+): ranges of **Character (grapheme)
    /// offsets into `content`** (the marker-stripped line) whose tokens changed vs
    /// the paired line. Empty unless `DiffEmphasis.refine` annotated it.
    /// Presentation only — never alters `text`/`kind`.
    public let emphasis: [Range<Int>]

    public init(kind: DiffLineKind, text: String, truncated: Bool = false, emphasis: [Range<Int>] = []) {
        self.kind = kind
        self.text = text
        self.truncated = truncated
        self.emphasis = emphasis
    }

    /// The line content with its single leading diff marker (`+`/`-`/space)
    /// removed — the **one source of truth** for "marker-stripped content" that
    /// `emphasis` offsets, the renderer, and the DEBUG dump all measure against.
    /// Header / no-newline lines (no marker) return `text` unchanged.
    public var content: String {
        guard !text.isEmpty else { return "" }
        switch kind {
        case .addition, .deletion, .context: return String(text.dropFirst())
        default: return text
        }
    }

    /// Copy with new emphasis ranges (used by `DiffEmphasis.refine`).
    public func withEmphasis(_ ranges: [Range<Int>]) -> DiffLine {
        DiffLine(kind: kind, text: text, truncated: truncated, emphasis: ranges)
    }
}

/// One hunk of a unified diff: its `@@` header line plus the lines within it.
public struct DiffHunk: Equatable, Sendable {
    public let header: String
    public let lines: [DiffLine]

    public init(header: String, lines: [DiffLine]) {
        self.header = header
        self.lines = lines
    }
}

/// A parsed unified diff for one file: its lines split into hunks (with any
/// pre-hunk file-header lines kept separately), plus binary/truncation flags and
/// +/- counts. Toolkit-independent.
public struct FileDiff: Equatable, Sendable {
    /// Pre-hunk header lines (`diff --git`, `index`, `---`, `+++`, …).
    public let header: [DiffLine]
    public let hunks: [DiffHunk]
    public let isBinary: Bool
    /// True when a per-line or per-file cap clipped the rendered diff.
    public let truncated: Bool
    public let addedCount: Int
    public let removedCount: Int

    public init(header: [DiffLine], hunks: [DiffHunk], isBinary: Bool, truncated: Bool, addedCount: Int, removedCount: Int) {
        self.header = header
        self.hunks = hunks
        self.isBinary = isBinary
        self.truncated = truncated
        self.addedCount = addedCount
        self.removedCount = removedCount
    }

    public static let binary = FileDiff(header: [], hunks: [], isBinary: true, truncated: false, addedCount: 0, removedCount: 0)
    public static let empty = FileDiff(header: [], hunks: [], isBinary: false, truncated: false, addedCount: 0, removedCount: 0)
}

/// Parser for `git diff --no-ext-diff --no-color` (unified) output, view-free and
/// unit-testable. Lines are classified by their leading character, but only
/// **after** the first `@@` hunk header — before that, `---`/`+++`/`diff --git`
/// lines are file headers, not deletions/additions. Caps bound memory/latency on
/// huge diffs (a per-line char cap and a per-file line cap, both setting
/// `truncated`).
public enum DiffParser {
    public static func parse(_ raw: String, maxLineLength: Int = 3000, maxLines: Int = 5000) -> FileDiff {
        // Binary diffs carry no hunks.
        if raw.contains("Binary files ") && raw.contains(" differ") { return .binary }
        if raw.contains("GIT binary patch") { return .binary }
        if raw.isEmpty { return .empty }

        var header: [DiffLine] = []
        var hunks: [DiffHunk] = []
        var currentHeader: String? = nil
        var currentLines: [DiffLine] = []
        var inHunk = false
        var added = 0
        var removed = 0
        var emitted = 0
        var truncated = false

        func flushHunk() {
            if let h = currentHeader {
                hunks.append(DiffHunk(header: h, lines: currentLines))
            }
            currentHeader = nil
            currentLines = []
        }

        func clip(_ s: String) -> (String, Bool) {
            if s.count > maxLineLength {
                return (String(s.prefix(maxLineLength)) + "…", true)
            }
            return (s, false)
        }

        var rawLines = raw.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        // `git diff` output ends with a newline, which `split` turns into a
        // trailing empty element — drop it so we don't render a spurious blank
        // context row (a real blank context line is " ", never "").
        while rawLines.last == "" { rawLines.removeLast() }
        outer: for line in rawLines {
            if line.hasPrefix("@@") {
                flushHunk()
                inHunk = true
                currentHeader = line
                continue
            }
            if !inHunk {
                // Pre-hunk: everything is a file header.
                header.append(DiffLine(kind: .fileHeader, text: line))
                continue
            }
            if emitted >= maxLines {
                truncated = true
                break outer
            }
            let kind: DiffLineKind
            let first = line.first
            switch first {
            case "+": kind = .addition; added += 1
            case "-": kind = .deletion; removed += 1
            case "\\": kind = .noNewline    // "\ No newline at end of file"
            default: kind = .context        // ' ' context, or an empty line
            }
            let (clipped, didClip) = clip(line)
            if didClip { truncated = true }
            currentLines.append(DiffLine(kind: kind, text: clipped, truncated: didClip))
            emitted += 1
        }
        flushHunk()

        return FileDiff(header: header, hunks: hunks, isBinary: false, truncated: truncated, addedCount: added, removedCount: removed)
    }
}
