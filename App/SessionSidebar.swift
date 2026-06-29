import SwiftUI
import XttyCore

/// Value snapshots the sidebar renders. The window controllers own the live
/// structure (the pane tree) and the sessions own the live state; the coordinator
/// folds both into these plain values each time the observed registry revision
/// changes, so the SwiftUI layer never reaches into AppKit or `XttyCore` internals.

struct SidebarPaneItem: Identifiable {
    let id: PaneID
    /// A short label (the profile name, or "shell" for the base profile).
    let label: String
    let activity: SessionActivity
    /// The most recent finished command (shown when nothing is running).
    let lastCommand: String?
    /// The running command's start time (drives the live duration); `nil` when idle.
    let runningSince: Date?
    let runningCommand: String?
    let isActive: Bool
    /// This pane's recent command blocks, newest-first (P4b-3). Empty → the pane
    /// row is a plain, non-expandable row (no disclosure chevron).
    let blocks: [SidebarBlockItem]
}

/// One command-block row in a pane's disclosure (P4b-3). A plain value snapshot:
/// the durable fields are always shown; `isActionable` (a live engine check) gates
/// scroll/copy-output, and `target` is the descriptor a selection acts on.
struct SidebarBlockItem: Identifiable {
    let id: String
    let command: String
    let state: BlockState
    let startedAt: Date
    /// `nil` while the command is still running (drives a live duration).
    let endedAt: Date?
    /// Whether scroll-to / copy-output resolve to an addressable row right now
    /// (anchor present + epoch-valid + not trimmed out). Gates those two actions.
    let isActionable: Bool
    /// Whether a working directory was captured (gates reveal-working-directory).
    let hasWorkingDirectory: Bool
    /// The descriptor a selection/menu action targets (running vs an index).
    let target: BlockTarget

    var isRunning: Bool { endedAt == nil }

    /// The status glyph reuses the session-activity vocabulary (spec).
    var activity: SessionActivity {
        switch state {
        case .running: return .running
        case .succeeded: return .succeeded
        case .failed: return .failed
        case .opaque: return .fullScreen
        }
    }
}

/// A per-block sidebar action (P4b-3), routed to the owning pane via the coordinator.
enum SidebarBlockAction {
    case select        // focus the pane + scroll to the block
    case copyOutput
    case copyCommand
    case reveal
}

struct SidebarTabItem: Identifiable {
    let id: Int                 // the tab window's number (stable while it lives)
    let title: String
    let isCurrent: Bool
    let panes: [SidebarPaneItem]
}

/// The session-progress sidebar (H1): a `Tab ▸ Pane` tree of the key window's
/// tab group, each pane showing its activity, last/running command, and a live
/// duration while running. Click focuses a pane (never scrolls the terminal).
///
/// Updates are event-driven: the view observes the `@Observable` `SessionRegistry`
/// revision (bumped on inventory/focus/state changes), recomputing its snapshot
/// via `tabsProvider`. The only periodic work is the per-running-row duration tick.
@MainActor
struct SessionSidebarView: View {
    let registry: SessionRegistry
    let tabsProvider: () -> [SidebarTabItem]
    let onActivate: (PaneID) -> Void
    /// Per-block action (P4b-3): select / copy-output / copy-command / reveal.
    let onBlockAction: (PaneID, BlockTarget, SidebarBlockAction) -> Void

    /// Panes whose block list is expanded. Empty = all collapsed (default);
    /// persists across snapshot refreshes via the stable `PaneID`s.
    @State private var expandedPanes: Set<PaneID> = []

    var body: some View {
        // Reading the observed revision registers this view for updates and forces
        // a fresh snapshot whenever the inventory, focus, or a session's state changes.
        _ = registry.revision
        let tabs = tabsProvider()
        return List {
            ForEach(tabs) { tab in
                Section {
                    ForEach(tab.panes) { pane in
                        paneRow(pane)
                        if expandedPanes.contains(pane.id) {
                            ForEach(pane.blocks) { block in
                                blockRow(paneID: pane.id, block: block)
                            }
                        }
                    }
                } header: {
                    Text(tab.title)
                        .font(.caption)
                        .fontWeight(tab.isCurrent ? .bold : .regular)
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 180)
    }

    /// The pane row: a disclosure chevron (only when the pane has blocks) + the
    /// focus button. Chevron toggles expansion; the row body focuses the pane.
    @ViewBuilder
    private func paneRow(_ pane: SidebarPaneItem) -> some View {
        HStack(spacing: 2) {
            if pane.blocks.isEmpty {
                Spacer().frame(width: 14)   // align with chevroned rows
            } else {
                Button { toggle(pane.id) } label: {
                    Image(systemName: expandedPanes.contains(pane.id) ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 14)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("sidebar.paneDisclosure")
            }
            Button { onActivate(pane.id) } label: { SidebarPaneRow(pane: pane) }
                .buttonStyle(.plain)
        }
        .listRowBackground(pane.isActive ? Color.accentColor.opacity(0.18) : Color.clear)
    }

    private func blockRow(paneID: PaneID, block: SidebarBlockItem) -> some View {
        Button { onBlockAction(paneID, block.target, .select) } label: {
            SidebarBlockRow(block: block)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Copy Output") { onBlockAction(paneID, block.target, .copyOutput) }
                .disabled(!block.isActionable)
            Button("Copy Command") { onBlockAction(paneID, block.target, .copyCommand) }
            Button("Reveal Working Directory") { onBlockAction(paneID, block.target, .reveal) }
                .disabled(!block.hasWorkingDirectory)
        }
    }

    private func toggle(_ id: PaneID) {
        if expandedPanes.contains(id) { expandedPanes.remove(id) } else { expandedPanes.insert(id) }
    }
}

/// One command-block row under a pane (P4b-3): a status glyph, the command, and a
/// duration (live while running). Non-actionable blocks (anchor stale/trimmed)
/// dim — their scroll/copy-output is disabled, but they stay an informational record.
@MainActor
struct SidebarBlockRow: View {
    let block: SidebarBlockItem

    var body: some View {
        HStack(spacing: 8) {
            SidebarStatusIndicator(activity: block.activity).frame(width: 12)
            Text(block.command.isEmpty ? "—" : block.command)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 4)
            durationLabel
        }
        .padding(.vertical, 1)
        .padding(.leading, 18)   // indent under the pane row
        .contentShape(Rectangle())
        .opacity(block.isActionable ? 1.0 : 0.55)   // dim non-actionable (D3)
    }

    @ViewBuilder
    private var durationLabel: some View {
        if block.isRunning {
            TimelineView(.periodic(from: block.startedAt, by: 1)) { context in
                Text(SidebarPaneRow.durationString(max(0, context.date.timeIntervalSince(block.startedAt))))
                    .font(.caption2).foregroundStyle(.secondary)
            }
        } else if let ended = block.endedAt {
            Text(SidebarPaneRow.durationString(max(0, ended.timeIntervalSince(block.startedAt))))
                .font(.caption2).foregroundStyle(.secondary)
        }
    }
}

/// One pane row: a status indicator, the pane label, and a secondary line that is
/// either a live duration (running) or the last command (idle/finished).
@MainActor
struct SidebarPaneRow: View {
    let pane: SidebarPaneItem

    var body: some View {
        HStack(spacing: 8) {
            SidebarStatusIndicator(activity: pane.activity)
                .frame(width: 14)
            VStack(alignment: .leading, spacing: 1) {
                Text(pane.label).lineLimit(1)
                secondaryLine
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var secondaryLine: some View {
        if let since = pane.runningSince {
            // Live, self-pausing tick: only running rows instantiate a timer, so an
            // idle sidebar does no periodic work (M1/M4).
            TimelineView(.periodic(from: since, by: 1)) { context in
                let elapsed = max(0, context.date.timeIntervalSince(since))
                Text("\(runningPrefix)\(Self.durationString(elapsed))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        } else if let last = pane.lastCommand, !last.isEmpty {
            Text(last)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var runningPrefix: String {
        if let cmd = pane.runningCommand, !cmd.isEmpty { return "\(cmd) · " }
        return ""
    }

    /// Compact elapsed time: "12s", "3m 04s", "1h 02m".
    static func durationString(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        if s < 60 { return "\(s)s" }
        if s < 3600 { return "\(s / 60)m \(String(format: "%02d", s % 60))s" }
        return "\(s / 3600)h \(String(format: "%02d", (s % 3600) / 60))m"
    }
}

/// Maps a `SessionActivity` to a glyph + color (running shows a small spinner).
@MainActor
struct SidebarStatusIndicator: View {
    let activity: SessionActivity

    var body: some View {
        switch activity {
        case .running:
            ProgressView().controlSize(.small)
        case .idle:
            dot("circle", .secondary)
        case .succeeded:
            dot("checkmark.circle.fill", .green)
        case .failed:
            dot("xmark.octagon.fill", .red)
        case .fullScreen:
            dot("rectangle.inset.filled", .purple)
        }
    }

    private func dot(_ symbol: String, _ color: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 11))
            .foregroundStyle(color)
    }
}
