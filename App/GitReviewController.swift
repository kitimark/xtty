import AppKit
import XttyCore

/// What the git-review panel needs to know about the focused pane at refresh time.
struct GitReviewTarget {
    /// Best-known local directory (live OSC-7 cwd, else the launch cwd); `nil`
    /// when remote or unknown.
    let localDirectory: String?
    /// Whether the focused session's cwd is remote (ssh) — review unavailable.
    let isRemote: Bool
    /// Unified-diff context lines (from the focused pane's profile config).
    let diffContext: Int
    /// Open an absolute file path in the user's editor (reuses the pane's
    /// `LinkRouter`/`FileOpener`).
    let openFile: (String) -> Void
}

/// Owns one window's git-review state: the `@Observable` store the SwiftUI panel
/// renders, plus the lean refresh policy (design D5). git work runs on a **serial**
/// background queue (which also serializes invocations — one in-flight at a time);
/// command-finish bursts are **debounced**; a low-frequency **poll backstop**
/// catches a long-running process editing files mid-command; everything is gated
/// on panel-visible AND a local repository.
@MainActor
final class GitReviewController {
    let store = GitReviewStore()

    /// Supplies the current focused pane's target each refresh (re-read fresh, so
    /// focus changes between schedule and run are honored).
    var targetProvider: () -> GitReviewTarget? = { nil }
    /// Whether the panel is currently visible (no work when collapsed).
    var isVisible: () -> Bool = { false }

    private let queue = DispatchQueue(label: "com.xtty.gitreview", qos: .utility)
    private var debouncePending = false
    private var inFlight = false
    private var pending = false
    private var pollTimer: Timer?

    /// Debounce window for command-finish bursts (coalesce `&&`-chains/loops).
    private static let debounceInterval: TimeInterval = 0.2
    /// Poll backstop cadence while visible.
    private static let pollInterval: TimeInterval = 5

    // MARK: Triggers

    /// Coalesced refresh (command-finish): collapses a burst into one git query.
    func scheduleRefresh() {
        guard !debouncePending else { return }
        debouncePending = true
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.debounceInterval) { [weak self] in
            guard let self else { return }
            self.debouncePending = false
            self.performRefresh()
        }
    }

    /// Immediate refresh (focus change / panel open / manual / poll). Still
    /// serialized by the in-flight guard.
    func refreshNow() { performRefresh() }

    /// Start/stop the poll backstop (called when the panel shows/hides).
    func setPolling(_ on: Bool) {
        pollTimer?.invalidate()
        pollTimer = nil
        guard on else { return }
        pollTimer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.performRefresh() }
        }
    }

    // MARK: Refresh core

    private func performRefresh() {
        guard isVisible() else { return }
        guard let target = targetProvider() else { store.clear(); return }
        if target.isRemote { store.apply(.remote); return }
        guard let dir = target.localDirectory else { store.clear(); return }
        if inFlight { pending = true; return }   // serialize: one git pass at a time
        inFlight = true

        let diffContext = target.diffContext
        let selected = store.snapshot.selectedPath
        queue.async { [weak self] in
            let snap = GitRunner.snapshot(forDirectory: dir, diffContext: diffContext)
            // Reload the selected file's diff if it survived the refresh.
            var reloaded: FileDiff?
            if let sel = selected, let root = snap.repoRoot,
               let file = snap.files.first(where: { $0.path == sel }) {
                reloaded = GitRunner.diff(repoRoot: root, file: file, diffContext: diffContext)
            }
            DispatchQueue.main.async {
                guard let self else { return }
                var merged = snap
                if let sel = selected, let diff = reloaded,
                   snap.files.contains(where: { $0.path == sel }) {
                    merged.selectedPath = sel
                    merged.selectedDiff = diff
                }
                self.store.apply(merged)
                self.inFlight = false
                if self.pending { self.pending = false; self.performRefresh() }
            }
        }
    }

    // MARK: Selection / open

    /// Select a file and load its diff off-main.
    func select(path: String?) {
        guard let path,
              let target = targetProvider(),
              let root = store.snapshot.repoRoot,
              let file = store.snapshot.files.first(where: { $0.path == path }) else {
            store.select(path: nil, diff: nil)
            return
        }
        let diffContext = target.diffContext
        store.select(path: path, diff: nil)   // show "loading" until the diff lands
        queue.async { [weak self] in
            let diff = GitRunner.diff(repoRoot: root, file: file, diffContext: diffContext)
            DispatchQueue.main.async {
                guard let self else { return }
                // Ignore a stale load if the selection moved on.
                guard self.store.snapshot.selectedPath == path else { return }
                self.store.select(path: path, diff: diff)
            }
        }
    }

    /// Open the selected/clicked file in the editor (resolved to an absolute path
    /// against the repo root, routed through the pane's opener).
    func open(path: String) {
        guard let target = targetProvider(), let root = store.snapshot.repoRoot else { return }
        let absolute = (root as NSString).appendingPathComponent(path)
        target.openFile(absolute)
    }
}
