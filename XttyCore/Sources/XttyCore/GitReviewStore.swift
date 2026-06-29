import Foundation
import Observation

/// How the git-review panel presents its changed-files list (P6b, Scope A):
/// `flat` is the status-category grouping; `tree` is a collapsible directory tree
/// of the **same** changed files. UI state (not git data), so it lives on
/// `GitReviewStore`, never on the off-main `GitReviewSnapshot`.
public enum GitReviewLayout: String, Equatable, Sendable, CaseIterable {
    case flat
    case tree
}

/// A cached, toolkit-independent snapshot of a session's git-review state — what
/// the panel renders and what the DEBUG harness dumps. Computed off the main
/// thread by the app's git runner and published into `GitReviewStore`.
public struct GitReviewSnapshot: Equatable, Sendable {
    /// Whether the focused session's directory is inside a git repository.
    public var isRepo: Bool
    /// Whether the focused session's directory is remote (ssh) — review unavailable.
    public var isRemote: Bool
    /// Whether git could not be run at all (not installed / not on PATH).
    public var gitUnavailable: Bool
    /// The repository root (absolute), when `isRepo`.
    public var repoRoot: String?
    /// The current branch name (or a short SHA when detached), when known.
    public var branch: String?
    /// The changed files, already grouped-sortable (sorted by path).
    public var files: [GitChangedFile]
    /// The path of the file whose diff is currently selected, if any.
    public var selectedPath: String?
    /// The parsed diff for `selectedPath`, if loaded.
    public var selectedDiff: FileDiff?

    public init(
        isRepo: Bool = false,
        isRemote: Bool = false,
        gitUnavailable: Bool = false,
        repoRoot: String? = nil,
        branch: String? = nil,
        files: [GitChangedFile] = [],
        selectedPath: String? = nil,
        selectedDiff: FileDiff? = nil
    ) {
        self.isRepo = isRepo
        self.isRemote = isRemote
        self.gitUnavailable = gitUnavailable
        self.repoRoot = repoRoot
        self.branch = branch
        self.files = files
        self.selectedPath = selectedPath
        self.selectedDiff = selectedDiff
    }

    /// The empty/idle snapshot (no repository).
    public static let empty = GitReviewSnapshot()
    /// Snapshot for a remote (ssh) session — review unavailable.
    public static let remote = GitReviewSnapshot(isRemote: true)
    /// Snapshot for when git itself cannot be run.
    public static let unavailable = GitReviewSnapshot(gitUnavailable: true)

    /// The changed files in one status category (sorted by path).
    public func files(in category: GitStatusCategory) -> [GitChangedFile] {
        files.filter { $0.status.category == category }
    }

    /// Whether there is anything to review (a local repo with at least one change).
    public var hasContent: Bool { isRepo && !files.isEmpty }
}

/// The observable git-review model the SwiftUI panel renders. `@MainActor` +
/// `@Observable` (mirroring `SessionRegistry`): the app's git runner publishes a
/// fresh `snapshot` on the main actor and the panel re-renders off `revision`.
/// `refreshCount` lets the DEBUG harness assert that a refresh actually fired.
@MainActor
@Observable
public final class GitReviewStore {
    public private(set) var snapshot: GitReviewSnapshot = .empty
    /// A monotonic counter bumped on every published change (the SwiftUI signal).
    public private(set) var revision: Int = 0
    /// How many full refreshes have been applied (harness assertion hook).
    public private(set) var refreshCount: Int = 0
    /// The active changed-files list layout (flat grouping vs directory tree). A
    /// per-window UI preference, seeded from config and flipped by the panel's
    /// header toggle; not persisted back to the config file.
    public private(set) var layout: GitReviewLayout = .flat

    public init() {}

    /// Switch the list layout (no-op when unchanged); bumps `revision` so the panel
    /// re-renders.
    public func setLayout(_ newLayout: GitReviewLayout) {
        guard newLayout != layout else { return }
        layout = newLayout
        revision &+= 1
    }

    /// Publish a freshly computed snapshot (preserving an in-range selection).
    public func apply(_ new: GitReviewSnapshot) {
        var merged = new
        // Keep the current selection if the file still exists and the new
        // snapshot didn't carry its own selection.
        if merged.selectedPath == nil,
           let sel = snapshot.selectedPath,
           new.files.contains(where: { $0.path == sel }) {
            merged.selectedPath = sel
            merged.selectedDiff = nil  // stale; the runner reloads it
        }
        snapshot = merged
        refreshCount &+= 1
        revision &+= 1
    }

    /// Record the selected file plus its loaded diff.
    public func select(path: String?, diff: FileDiff?) {
        snapshot.selectedPath = path
        snapshot.selectedDiff = diff
        revision &+= 1
    }

    /// Reset to the empty (no-repo) state — e.g. on focus leaving a repo.
    public func clear() {
        snapshot = .empty
        revision &+= 1
    }
}
