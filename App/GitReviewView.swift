import AppKit
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
                #if DEBUG
                DiffPane(
                    path: path, diff: diff, wrapMode: store.diffWrap,
                    onOpen: { onOpen(path) },
                    onToggleWrap: { store.setDiffWrap(store.diffWrap == .wrap ? .noWrap : .wrap) },
                    onDiffLayoutGeometry: { fills, overflows in
                        store.setDiffLayoutGeometry(fillsWidth: fills, overflows: overflows)
                    }
                )
                #else
                DiffPane(
                    path: path, diff: diff, wrapMode: store.diffWrap,
                    onOpen: { onOpen(path) },
                    onToggleWrap: { store.setDiffWrap(store.diffWrap == .wrap ? .noWrap : .wrap) }
                )
                #endif
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

/// The read-only unified diff of the selected file: a header (path + wrap
/// toggle + open button) over the classified diff lines, with binary/truncation
/// fallbacks. Fills the full panel width in both line-wrap modes: **wrap**
/// stays on a vertical-only scroll so `Text` wraps at a definite width;
/// **no-wrap** keeps the two-axis scroll with each row sized to its own
/// (unwrapped) content width, extending the panel's horizontal scroll.
@MainActor
struct DiffPane: View {
    let path: String
    let diff: FileDiff
    let wrapMode: GitDiffWrap
    let onOpen: () -> Void
    let onToggleWrap: () -> Void
    #if DEBUG
    /// DEBUG-only: reports the selected diff's rendered layout geometry
    /// (fills-width, overflows-horizontally) so the harness state dump can
    /// assert each wrap mode's actual rendered layout (design R5). This is a
    /// pure **observation** side-channel — see `diffScroll` — it never feeds
    /// back into row sizing, so DEBUG and Release render the identical tree.
    var onDiffLayoutGeometry: (Bool, Bool) -> Void = { _, _ in }
    /// The scrollable content's measured width, via `onGeometryChange` (a
    /// `.background(GeometryReader{...})` + `PreferenceKey` did not reliably
    /// propagate live values through the `ScrollView` in manual testing —
    /// `onGeometryChange` reads the resolved layout directly and does not have
    /// that issue). The viewport width it's compared against comes from the
    /// same synchronous `GeometryReader` both configurations already use for
    /// row sizing, not a second `onGeometryChange` measurement — so this state
    /// exists purely to report to the harness, never to size anything.
    @State private var measuredContentWidth: CGFloat = 0
    #endif

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text(path).font(.caption).lineLimit(1).truncationMode(.middle)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                Button(action: onToggleWrap) {
                    Image(systemName: wrapMode == .wrap ? "arrow.turn.down.left" : "arrow.right")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .help(wrapMode == .wrap ? "Disable line wrap" : "Enable line wrap")
                .accessibilityIdentifier("gitReview.wrapToggle")
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
                diffScroll
            }
        }
        .frame(maxHeight: .infinity)
    }

    /// The scrollable diff content — ONE layout path in both DEBUG and
    /// Release (Codex Pass B: an earlier DEBUG-only `onGeometryChange`-fed
    /// `viewportWidth` rendered a materially different tree from Release, and
    /// silently zeroed out on a pre-macOS-15 DEBUG host, breaking the no-wrap
    /// width floor along with observability). **Wrap**: vertical-only, so the
    /// enclosing width is definite and rows (`.frame(maxWidth: .infinity)`)
    /// actually wrap. **No-wrap**: the two-axis scroll from before, with rows
    /// floored to a precomputed content-width estimate (see `diffLines`)
    /// instead of a flexible `maxWidth: .infinity` fighting a non-wrapping
    /// `Text` (the original bug). The DEBUG-only geometry signal (below) is an
    /// additional **observation**, never a second source of `viewportWidth`.
    ///
    /// **Accepted residual (Fable Pass C, round 1):** `outerGeo.size.width` is
    /// the `ScrollView`'s own frame, which equals the content viewport under
    /// overlay scrollers (the macOS default) but would over-report it by a
    /// legacy (space-reserving) vertical scrollbar's width once a diff is
    /// tall enough to actually show one — an environment/settings-dependent
    /// case not exercised by this change's tests. Not fixed here; flagging
    /// for whoever next touches this measurement.
    @ViewBuilder
    private var diffScroll: some View {
        GeometryReader { outerGeo in
            ScrollView(wrapMode == .wrap ? [.vertical] : [.vertical, .horizontal]) {
                diffLines(viewportWidth: outerGeo.size.width)
                    .padding(.vertical, 2)
                    #if DEBUG
                    .measuringWidth { newWidth in
                        measuredContentWidth = newWidth
                        publishDiffLayoutGeometry(viewportWidth: outerGeo.size.width)
                    }
                    #endif
            }
        }
    }

    #if DEBUG
    /// Report the fills-width/overflows signals against the SAME viewport
    /// width the rows were actually sized with (design R5: equality-gated by
    /// the store, so an unchanged pair of booleans is a no-op there; this
    /// call never feeds back into rendering).
    private func publishDiffLayoutGeometry(viewportWidth: CGFloat) {
        guard viewportWidth > 0 else { return }
        let tolerance: CGFloat = 1
        onDiffLayoutGeometry(
            measuredContentWidth >= viewportWidth - tolerance,
            measuredContentWidth > viewportWidth + tolerance
        )
    }
    #endif

    /// The diff's hunk headers + lines, ALWAYS a `LazyVStack` in both modes —
    /// so both render the identical row set (design's presentation-only
    /// invariant: switching modes never changes which lines are shown).
    ///
    /// **Cross-review round 2 (Codex high + Fable medium, corroborating):** an
    /// earlier fix capped no-wrap to its first 500 rows to bound the eager
    /// `VStack` render cost (design R1's original "eager `VStack`, bounded by
    /// the 5000-line parser cap" fallback) — but for a diff over 500 rows,
    /// toggling wrap→no-wrap then silently dropped rows wrap mode still
    /// showed, violating the invariant above (and the git-review spec's own
    /// SHALL). Fixed properly instead: no-wrap floors every row (and the
    /// `LazyVStack` itself) to `noWrapFloorWidth` — the larger of the real
    /// viewport width and a **precomputed** estimate of the diff's widest row,
    /// computed once from character COUNTS only (no per-line text layout, no
    /// examining on-screen rows). Because every row shares the SAME precomputed
    /// floor, the `LazyVStack` never needs to inspect an off-screen row to
    /// know its own width — laziness (bounding real work to on-screen rows) is
    /// restored without capping which rows exist.
    @ViewBuilder
    private func diffLines(viewportWidth: CGFloat) -> some View {
        switch wrapMode {
        case .wrap:
            LazyVStack(alignment: .leading, spacing: 0) {
                diffRows(noWrapFloorWidth: 0)
            }
        case .noWrap:
            let floorWidth = max(viewportWidth, noWrapContentWidthEstimate)
            LazyVStack(alignment: .leading, spacing: 0) {
                diffRows(noWrapFloorWidth: floorWidth)
            }
            .frame(width: floorWidth, alignment: .leading)
        }
    }

    /// A monospaced glyph's advance width at the row font size, measured once
    /// (all glyphs share it at this design's monospaced font).
    private static let monoCharWidth: CGFloat = {
        let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        return ("0" as NSString).size(withAttributes: [.font: font]).width
    }()

    /// The no-wrap content width estimate: the diff's widest row (marker +
    /// content characters, including hunk headers) times the measured
    /// monospaced advance width, plus the row's own horizontal padding and a
    /// small safety margin against font-metric estimation error (kerning,
    /// unusual glyphs). O(n) over character COUNTS only — cheap even at the
    /// parser's 5000-line cap, no per-line text layout.
    private var noWrapContentWidthEstimate: CGFloat {
        let maxChars = diff.hunks.reduce(0) { partial, hunk in
            let hunkMax = hunk.lines.reduce(hunk.header.count) { max($0, $1.text.count) }
            return max(partial, hunkMax)
        }
        let safetyMarginChars = 4
        return CGFloat(maxChars + safetyMarginChars) * Self.monoCharWidth + 16  // the row's own horizontal padding
    }

    @ViewBuilder
    private func diffRows(noWrapFloorWidth: CGFloat) -> some View {
        ForEach(Array(diff.hunks.enumerated()), id: \.offset) { _, hunk in
            DiffLineRow(line: DiffLine(kind: .hunkHeader, text: hunk.header),
                        wrapMode: wrapMode, noWrapFloorWidth: noWrapFloorWidth)
            ForEach(Array(hunk.lines.enumerated()), id: \.offset) { _, line in
                DiffLineRow(line: line, wrapMode: wrapMode, noWrapFloorWidth: noWrapFloorWidth)
            }
        }
        if diff.truncated {
            Button("Diff truncated — open in editor", action: onOpen)
                .font(.caption).buttonStyle(.plain)
                .foregroundStyle(.secondary).padding(6)
        }
    }

    private func centeredNote(_ text: String) -> some View {
        VStack { Spacer(); Text(text).font(.caption).foregroundStyle(.secondary); Spacer() }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#if DEBUG
private extension View {
    /// DEBUG-only: reports this view's resolved width via `onGeometryChange`.
    /// The single-value-action overload used here is back-deployed to macOS
    /// 13.0 (only the two-parameter `(old, new)` overload needs macOS 15) —
    /// verified against the installed SDK's `SwiftUICore.swiftinterface`, so
    /// no availability gate is needed above this deployment target (14.0;
    /// Fable Pass C caught an earlier, incorrect `#available(macOS 15, *)`
    /// gate here that silently no-op'd the signal on macOS 14). Used to
    /// compare the diff's viewport width against its scrollable content
    /// width, deriving the fills-width/overflows layout-geometry signals
    /// (design R5).
    func measuringWidth(_ onChange: @escaping (CGFloat) -> Void) -> some View {
        onGeometryChange(for: CGFloat.self, of: { $0.size.width }, action: onChange)
    }
}
#endif

/// One diff line, monospaced and tinted by kind. `wrapMode` selects the outer
/// sizing: **wrap** stretches to the panel width and wraps; **no-wrap** takes
/// the diff's shared, precomputed content-width floor (`noWrapFloorWidth`, so
/// a short line's tint still fills the panel/content width) and never wraps.
@MainActor
struct DiffLineRow: View {
    let line: DiffLine
    let wrapMode: GitDiffWrap
    /// The diff's precomputed no-wrap content-width floor — used in
    /// **no-wrap** mode only (see `DiffPane.diffLines`).
    var noWrapFloorWidth: CGFloat = 0

    var body: some View {
        Group {
            if wrapMode == .wrap {
                rowContent
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                // The `.frame(minWidth:)` floor MUST be applied AFTER padding,
                // not before: flooring the pre-padding content and then adding
                // padding makes every row at least `noWrapFloorWidth + 16`
                // wide, so even a short line reports horizontal overflow —
                // tautologically satisfying `diffContentOverflows` regardless
                // of whether the line is actually long (Codex Pass B, high).
                rowContent
                    .padding(.horizontal, 8)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(minWidth: noWrapFloorWidth, alignment: .leading)
            }
        }
        .font(.system(size: 11, design: .monospaced))
        .background(background)
    }

    /// Content/added/removed lines split the leading `+`/`-`/space marker into its
    /// own run — so it is never tinted/emphasized, and the content's Character-offset
    /// emphasis maps directly onto its own `Text` (no marker arithmetic). The shared
    /// monospaced font keeps columns aligned. Header / no-newline lines render whole.
    /// `alignment: .top` keeps the marker aligned with the content's FIRST
    /// wrapped row rather than `HStack`'s default vertical-centering, which
    /// would center the single-character marker beside a multi-row wrapped
    /// block in wrap mode (Codex Pass B round 2, medium).
    @ViewBuilder
    private var rowContent: some View {
        if isContentLine {
            HStack(alignment: .top, spacing: 0) {
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
