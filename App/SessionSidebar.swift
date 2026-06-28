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

    var body: some View {
        // Reading the observed revision registers this view for updates and forces
        // a fresh snapshot whenever the inventory, focus, or a session's state changes.
        _ = registry.revision
        let tabs = tabsProvider()
        return List {
            ForEach(tabs) { tab in
                Section {
                    ForEach(tab.panes) { pane in
                        Button { onActivate(pane.id) } label: {
                            SidebarPaneRow(pane: pane)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(pane.isActive ? Color.accentColor.opacity(0.18) : Color.clear)
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
