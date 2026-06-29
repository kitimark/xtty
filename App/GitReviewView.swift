import SwiftUI
import XttyCore

/// The git-review panel (P6a): the focused pane's changed files grouped by status
/// category, with a read-only unified diff of the selected file. A SwiftUI peer of
/// `SessionSidebarView`, hosted on the trailing edge. It observes the
/// `@Observable GitReviewStore` revision and renders plain value snapshots; all
/// git work happens in `GitReviewController`/`GitRunner`.
@MainActor
struct GitReviewView: View {
    let store: GitReviewStore
    let onSelect: (String) -> Void
    let onOpen: (String) -> Void
    let onRefresh: () -> Void

    /// Directories the user has collapsed in the tree layout, keyed by the node's
    /// stable cumulative path. Empty = all expanded (default); the set only grows as
    /// the user collapses, and persists across snapshot refreshes (stable ids).
    @State private var collapsedDirs: Set<String> = []

    var body: some View {
        _ = store.revision   // observe → re-render on every published change
        let snap = store.snapshot
        return VStack(spacing: 0) {
            headerBar(snap)
            Divider()
            content(snap)
        }
        .frame(minWidth: 240)
        // Collapse intent is per-repository: reset when focus moves to a different
        // repo so the tree starts all-expanded there (and stale paths don't linger).
        .onChange(of: snap.repoRoot) { collapsedDirs.removeAll() }
    }

    // MARK: Header

    @ViewBuilder
    private func headerBar(_ snap: GitReviewSnapshot) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text(snap.branch ?? "Changes").font(.caption).fontWeight(.semibold).lineLimit(1)
            Spacer(minLength: 0)
            Button {
                store.setLayout(store.layout == .tree ? .flat : .tree)
            } label: {
                Image(systemName: store.layout == .tree ? "list.bullet.indent" : "list.bullet")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .help(store.layout == .tree ? "Show as a flat list" : "Show as a directory tree")
            .accessibilityIdentifier("gitReview.layoutToggle")
            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise").font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .help("Refresh")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    // MARK: Content / empty states

    @ViewBuilder
    private func content(_ snap: GitReviewSnapshot) -> some View {
        if snap.isRemote {
            emptyState("rectangle.connected.to.line.below", "Remote session",
                       "Git review is unavailable for remote sessions.")
        } else if snap.gitUnavailable {
            emptyState("exclamationmark.triangle", "git not found",
                       "Install git or make it available on your PATH.")
        } else if !snap.isRepo {
            emptyState("folder", "Not a git repository",
                       "Open a folder under version control to review changes.")
        } else if snap.files.isEmpty {
            emptyState("checkmark.circle", "No changes",
                       "The working tree is clean.")
        } else {
            fileListAndDiff(snap)
        }
    }

    private func emptyState(_ symbol: String, _ title: String, _ detail: String) -> some View {
        VStack(spacing: 6) {
            Spacer()
            Image(systemName: symbol).font(.system(size: 24)).foregroundStyle(.secondary)
            Text(title).font(.callout).fontWeight(.medium)
            Text(detail).font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: File list + diff

    @ViewBuilder
    private func fileListAndDiff(_ snap: GitReviewSnapshot) -> some View {
        let hasDiff = snap.selectedDiff != nil
        VStack(spacing: 0) {
            List {
                if store.layout == .tree {
                    // Same changed files, grouped into a collapsible directory tree
                    // (P6b). Pure transform over the cached snapshot — no git call.
                    GitFileTreeView(
                        nodes: GitFileTree.build(snap.files),
                        selectedPath: snap.selectedPath,
                        collapsedDirs: $collapsedDirs,
                        onSelect: onSelect, onOpen: onOpen
                    )
                } else {
                    ForEach(GitStatusCategory.allCases, id: \.self) { category in
                        let files = snap.files(in: category)
                        if !files.isEmpty {
                            Section(sectionTitle(category)) {
                                ForEach(files) { file in
                                    GitFileButton(file: file,
                                                  isSelected: file.path == snap.selectedPath,
                                                  onSelect: onSelect, onOpen: onOpen)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .frame(maxHeight: hasDiff ? 220 : .infinity)

            if let diff = snap.selectedDiff, let path = snap.selectedPath {
                Divider()
                DiffPane(path: path, diff: diff, onOpen: { onOpen(path) })
            }
        }
    }

    private func sectionTitle(_ category: GitStatusCategory) -> String {
        switch category {
        case .changes: return "Changes"
        case .untracked: return "Untracked"
        case .conflicts: return "Conflicts"
        }
    }
}

/// One changed-file row: a status glyph (deleted muted, not red), the path, and
/// +/- badges when known.
@MainActor
struct GitFileRow: View {
    let file: GitChangedFile

    var body: some View {
        HStack(spacing: 6) {
            Text(glyph).font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(color).frame(width: 12)
            Text(displayName).lineLimit(1).truncationMode(.middle)
            Spacer(minLength: 4)
            if let added = file.added, let removed = file.removed {
                Text("+\(added)").font(.caption2).foregroundStyle(.green)
                Text("-\(removed)").font(.caption2).foregroundStyle(.red)
            } else if file.isBinary {
                Text("bin").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 1)
        .contentShape(Rectangle())
    }

    private var displayName: String {
        (file.path as NSString).lastPathComponent
    }

    private var glyph: String {
        switch file.status {
        case .modified: return "M"
        case .added: return "A"
        case .deleted: return "D"
        case .renamed: return "R"
        case .untracked: return "?"
        case .conflicted: return "!"
        }
    }

    private var color: Color {
        switch file.status {
        case .modified: return .orange
        case .added: return .green
        case .deleted: return .secondary   // muted, not red (zed's tweak)
        case .renamed: return .blue
        case .untracked: return .secondary
        case .conflicted: return .red
        }
    }
}

/// One selectable changed-file row, shared by the flat and tree layouts: the
/// `GitFileRow` content wrapped in the selection button + open-in-editor context
/// menu. Identical behavior in either layout (spec: select/open are layout-agnostic).
@MainActor
struct GitFileButton: View {
    let file: GitChangedFile
    let isSelected: Bool
    let onSelect: (String) -> Void
    let onOpen: (String) -> Void

    var body: some View {
        Button { onSelect(file.path) } label: {
            GitFileRow(file: file)
        }
        .buttonStyle(.plain)
        .listRowBackground(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
        .contextMenu {
            Button("Open in Editor") { onOpen(file.path) }
        }
    }
}

/// The directory-tree layout (P6b): renders `[GitTreeNode]` as nested
/// `DisclosureGroup`s (directories) with `GitFileButton` leaves (files). Expansion
/// is tracked as a *collapsed* set so the default (empty) is all-expanded and new
/// directories appear expanded; collapsed state persists across refreshes via the
/// nodes' stable path ids.
@MainActor
struct GitFileTreeView: View {
    let nodes: [GitTreeNode]
    let selectedPath: String?
    @Binding var collapsedDirs: Set<String>
    let onSelect: (String) -> Void
    let onOpen: (String) -> Void

    var body: some View {
        ForEach(nodes) { node in
            switch node {
            case let .file(file):
                GitFileButton(file: file, isSelected: file.path == selectedPath,
                              onSelect: onSelect, onOpen: onOpen)
            case let .directory(path, name, children):
                DisclosureGroup(isExpanded: expansion(for: path)) {
                    GitFileTreeView(nodes: children, selectedPath: selectedPath,
                                    collapsedDirs: $collapsedDirs,
                                    onSelect: onSelect, onOpen: onOpen)
                } label: {
                    Label(name, systemImage: "folder")
                        .lineLimit(1).truncationMode(.middle)
                }
            }
        }
    }

    private func expansion(for path: String) -> Binding<Bool> {
        Binding(
            get: { !collapsedDirs.contains(path) },
            set: { expanded in
                if expanded { collapsedDirs.remove(path) } else { collapsedDirs.insert(path) }
            }
        )
    }
}

/// The read-only unified diff of the selected file: a header (path + open button)
/// over the classified diff lines, with binary/truncation fallbacks.
@MainActor
struct DiffPane: View {
    let path: String
    let diff: FileDiff
    let onOpen: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text(path).font(.caption).lineLimit(1).truncationMode(.middle)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                Button(action: onOpen) {
                    Image(systemName: "arrow.up.forward.app").font(.system(size: 11))
                }
                .buttonStyle(.plain).help("Open in editor")
            }
            .padding(.horizontal, 10).padding(.vertical, 4)
            Divider()
            if diff.isBinary {
                centeredNote("Binary file (no preview)")
            } else if diff.hunks.isEmpty {
                centeredNote("No textual changes")
            } else {
                ScrollView([.vertical, .horizontal]) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(diff.hunks.enumerated()), id: \.offset) { _, hunk in
                            DiffLineRow(line: DiffLine(kind: .hunkHeader, text: hunk.header))
                            ForEach(Array(hunk.lines.enumerated()), id: \.offset) { _, line in
                                DiffLineRow(line: line)
                            }
                        }
                        if diff.truncated {
                            Button("Diff truncated — open in editor", action: onOpen)
                                .font(.caption).buttonStyle(.plain)
                                .foregroundStyle(.secondary).padding(6)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func centeredNote(_ text: String) -> some View {
        VStack { Spacer(); Text(text).font(.caption).foregroundStyle(.secondary); Spacer() }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// One diff line, monospaced and tinted by kind.
@MainActor
struct DiffLineRow: View {
    let line: DiffLine

    var body: some View {
        rowContent
            .font(.system(size: 11, design: .monospaced))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .background(background)
    }

    /// Content/added/removed lines split the leading `+`/`-`/space marker into its
    /// own run — so it is never tinted/emphasized, and the content's Character-offset
    /// emphasis maps directly onto its own `Text` (no marker arithmetic). The shared
    /// monospaced font keeps columns aligned. Header / no-newline lines render whole.
    @ViewBuilder
    private var rowContent: some View {
        if isContentLine {
            HStack(spacing: 0) {
                Text(marker).foregroundStyle(.secondary)
                Text(attributedContent).foregroundStyle(foreground)
            }
        } else {
            Text(line.text.isEmpty ? " " : line.text).foregroundStyle(foreground)
        }
    }

    private var isContentLine: Bool {
        line.kind == .addition || line.kind == .deletion || line.kind == .context
    }

    private var marker: String { String(line.text.first ?? " ") }

    /// `DiffLine.content` (the marker-stripped source of truth) with intra-line
    /// emphasis applied as a darker per-run `.backgroundColor` over the whole-line
    /// tint. Offsets are Character (grapheme) units; out-of-range ranges are clamped
    /// and ignored (never traps — defensive against any future parser drift).
    private var attributedContent: AttributedString {
        let content = line.content
        var attr = AttributedString(content.isEmpty ? " " : content)
        guard !line.emphasis.isEmpty, !content.isEmpty else { return attr }
        let chars = attr.characters
        let n = chars.count
        for r in line.emphasis {
            let lo = max(0, min(r.lowerBound, n))
            let hi = max(lo, min(r.upperBound, n))
            guard lo < hi,
                  let s = chars.index(chars.startIndex, offsetBy: lo, limitedBy: chars.endIndex),
                  let e = chars.index(chars.startIndex, offsetBy: hi, limitedBy: chars.endIndex),
                  s < e else { continue }
            attr[s..<e].backgroundColor = emphasisColor
        }
        return attr
    }

    private var emphasisColor: Color {
        switch line.kind {
        case .addition: return Color.green.opacity(0.40)
        case .deletion: return Color.red.opacity(0.40)
        default: return Color.accentColor.opacity(0.30)
        }
    }

    private var foreground: Color {
        switch line.kind {
        case .addition: return .primary
        case .deletion: return .primary
        case .hunkHeader: return .secondary
        case .fileHeader: return .secondary
        case .noNewline: return .secondary
        case .context: return .primary
        }
    }

    private var background: Color {
        switch line.kind {
        case .addition: return Color.green.opacity(0.18)
        case .deletion: return Color.red.opacity(0.18)
        case .hunkHeader: return Color.accentColor.opacity(0.12)
        default: return .clear
        }
    }
}
