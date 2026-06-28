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

    var body: some View {
        _ = store.revision   // observe → re-render on every published change
        let snap = store.snapshot
        return VStack(spacing: 0) {
            headerBar(snap)
            Divider()
            content(snap)
        }
        .frame(minWidth: 240)
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
                ForEach(GitStatusCategory.allCases, id: \.self) { category in
                    let files = snap.files(in: category)
                    if !files.isEmpty {
                        Section(sectionTitle(category)) {
                            ForEach(files) { file in
                                Button { onSelect(file.path) } label: {
                                    GitFileRow(file: file)
                                }
                                .buttonStyle(.plain)
                                .listRowBackground(file.path == snap.selectedPath
                                                   ? Color.accentColor.opacity(0.18) : Color.clear)
                                .contextMenu {
                                    Button("Open in Editor") { onOpen(file.path) }
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
        Text(line.text.isEmpty ? " " : line.text)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .background(background)
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
