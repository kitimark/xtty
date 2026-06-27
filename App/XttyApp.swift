import SwiftUI
import XttyCore

/// xtty — native macOS terminal emulator.
///
/// P0 skeleton: launch a single empty window. No terminal session, rendering,
/// or shell process is started yet (deferred to later milestones). The app
/// depends on `XttyCore`, establishing the engine-facing seam from the start.
@main
struct XttyApp: App {
    var body: some Scene {
        WindowGroup("xtty") {
            ContentView()
        }
    }
}

/// Placeholder window content. Intentionally empty for the skeleton milestone —
/// the terminal view is wired in P1. Touches `XttyCore` so the seam dependency
/// is exercised at build time.
struct ContentView: View {
    var body: some View {
        Color.clear
            .frame(minWidth: 640, minHeight: 400)
            .accessibilityHidden(true)
            .help(XttyCore.milestone)
    }
}
