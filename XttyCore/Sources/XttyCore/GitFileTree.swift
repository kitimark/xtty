import Foundation

/// A node in the git-review panel's **directory-tree** layout (P6b, Scope A) — a
/// pure presentation transform over the flat changed-file list. Either an
/// intermediate `directory` with children, or a `file` leaf carrying its
/// `GitChangedFile`. View-free and unit-testable; built by `GitFileTree.build`.
public indirect enum GitTreeNode: Identifiable, Equatable, Sendable {
    /// An intermediate directory: `path` is its cumulative repository-root-relative
    /// path (the **stable identity** across refreshes, so SwiftUI keeps expansion),
    /// `name` its last path component, `children` the ordered child nodes.
    case directory(path: String, name: String, children: [GitTreeNode])
    /// A changed-file leaf (carries the full `GitChangedFile`: status + numstat).
    case file(GitChangedFile)

    public var id: String {
        switch self {
        case let .directory(path, _, _): return "d:" + path
        case let .file(file): return "f:" + file.path
        }
    }
}

/// Folds a flat changed-file list into a directory tree, grouping files by their
/// repository-root-relative directory path. Ordering at every level is
/// **directories first, then files, each alphabetical** (IDE convention) — so the
/// output is deterministic and the input set is preserved exactly (no file added,
/// dropped, or duplicated). A pure function: no git call, no filesystem access.
public enum GitFileTree {
    public static func build(_ files: [GitChangedFile]) -> [GitTreeNode] {
        let root = MutableDir()
        for file in files {
            let comps = file.path
                .split(separator: "/", omittingEmptySubsequences: true)
                .map(String.init)
            guard !comps.isEmpty else { continue }
            var node = root
            for comp in comps.dropLast() {
                if let existing = node.subdirs[comp] {
                    node = existing
                } else {
                    let child = MutableDir()
                    node.subdirs[comp] = child
                    node = child
                }
            }
            node.files.append(file)
        }
        return root.emit(prefix: "")
    }
}

/// A reference-typed builder node (a tree is naturally mutable while folding).
private final class MutableDir {
    var subdirs: [String: MutableDir] = [:]
    var files: [GitChangedFile] = []

    /// Emit immutable `GitTreeNode`s: directories first (alphabetical by name),
    /// then files (alphabetical by path). `prefix` is the cumulative path so each
    /// directory carries a stable, unique id.
    func emit(prefix: String) -> [GitTreeNode] {
        let dirNodes: [GitTreeNode] = subdirs.keys.sorted().map { name in
            let childPrefix = prefix.isEmpty ? name : prefix + "/" + name
            return .directory(path: childPrefix, name: name,
                              children: subdirs[name]!.emit(prefix: childPrefix))
        }
        let fileNodes = files.sorted { $0.path < $1.path }.map { GitTreeNode.file($0) }
        return dirNodes + fileNodes
    }
}
