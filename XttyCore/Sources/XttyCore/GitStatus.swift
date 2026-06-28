import Foundation

/// The status category a changed file is grouped under in the git-review panel.
public enum GitStatusCategory: String, Equatable, Sendable, CaseIterable {
    case changes      // tracked modifications / additions / deletions
    case untracked    // `??`
    case conflicts    // unmerged (the 7 XY combos)
}

/// The per-file status shown with a glyph in the changed-files list. View-free
/// (no colors/glyphs here — the app layer maps these onto the theme).
public enum GitFileStatus: String, Equatable, Sendable {
    case modified
    case added
    case deleted
    case renamed
    case untracked
    case conflicted

    /// Which group this status belongs to.
    public var category: GitStatusCategory {
        switch self {
        case .untracked: return .untracked
        case .conflicted: return .conflicts
        default: return .changes
        }
    }
}

/// One changed file in a repository's working tree — a toolkit-independent value
/// the git-review panel renders. `added`/`removed`/`isBinary` are filled from
/// `--numstat` when available (nil counts = not yet known).
public struct GitChangedFile: Identifiable, Equatable, Sendable {
    /// Repository-root-relative path (also the stable identity).
    public let path: String
    public let status: GitFileStatus
    public var added: Int?
    public var removed: Int?
    public var isBinary: Bool

    public var id: String { path }

    public init(path: String, status: GitFileStatus, added: Int? = nil, removed: Int? = nil, isBinary: Bool = false) {
        self.path = path
        self.status = status
        self.added = added
        self.removed = removed
        self.isBinary = isBinary
    }
}

/// Parser for `git status --porcelain=v1 -z --untracked-files=all --no-renames`
/// output, view-free and unit-testable.
///
/// The `-z` format is NUL-terminated records, each `XY<space><path>` (raw UTF-8 —
/// `-z` disables `core.quotepath`, so no octal escapes). With `--no-renames` a
/// rename surfaces as a delete + an untracked add (no two-path record), but the
/// parser still defensively consumes the extra origin-path field if an `R`/`C`
/// ever appears. Trailing-slash (directory) entries are skipped; results are
/// deduplicated and sorted by path.
public enum GitStatusParser {
    /// The XY pairs git reports for an unmerged (conflicted) path.
    private static let conflictPairs: Set<String> = ["DD", "AU", "UD", "UA", "DU", "AA", "UU"]

    public static func parse(_ raw: String) -> [GitChangedFile] {
        let records = raw.split(separator: "\0", omittingEmptySubsequences: true).map(String.init)
        var files: [String: GitChangedFile] = [:]
        var order: [String] = []

        var i = 0
        while i < records.count {
            let record = records[i]
            i += 1
            // Each record is "XY PATH" (2 status chars, a space, then the path).
            guard record.count >= 3 else { continue }
            let chars = Array(record)
            let x = chars[0]
            let y = chars[1]
            let path = String(chars[3...])
            let xy = "\(x)\(y)"

            // R/C carry a second NUL field (the origin path); consume it.
            if x == "R" || x == "C" || y == "R" || y == "C" { i += 1 }

            // Untracked directories surface with a trailing slash — skip them
            // (`-uall` lists the real files inside).
            if path.hasSuffix("/") { continue }

            let status = classify(x: x, y: y, xy: xy)
            let file = GitChangedFile(path: path, status: status)
            if files[path] == nil { order.append(path) }
            files[path] = file
        }

        return order.compactMap { files[$0] }.sorted { $0.path < $1.path }
    }

    private static func classify(x: Character, y: Character, xy: String) -> GitFileStatus {
        if conflictPairs.contains(xy) { return .conflicted }
        if xy == "??" { return .untracked }
        if x == "A" && y != "D" { return .added }
        if x == "D" || y == "D" { return .deleted }
        if x == "R" || y == "R" || x == "C" || y == "C" { return .renamed }
        return .modified
    }
}

/// Parser for `git diff --numstat -z` output: `added\tremoved\t<path>` per
/// NUL-terminated record, with `-`/`-` for binary files.
public enum NumstatParser {
    /// Returns path → (added, removed, isBinary). Binary files report `nil`
    /// counts and `isBinary == true`.
    public static func parse(_ raw: String) -> [String: (added: Int?, removed: Int?, isBinary: Bool)] {
        var result: [String: (added: Int?, removed: Int?, isBinary: Bool)] = [:]
        for record in raw.split(separator: "\0", omittingEmptySubsequences: true) {
            let fields = record.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard fields.count >= 3 else { continue }
            let addedField = fields[0]
            let removedField = fields[1]
            // The path is the remainder (defensive against tabs in a path).
            let path = fields[2...].joined(separator: "\t")
            if path.isEmpty { continue }
            if addedField == "-" || removedField == "-" {
                result[path] = (nil, nil, true)
            } else {
                result[path] = (Int(addedField), Int(removedField), false)
            }
        }
        return result
    }
}
