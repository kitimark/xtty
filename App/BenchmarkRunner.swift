#if DEBUG
import AppKit
import XttyCore

/// Drives the `-Benchmark` run (P7a): for the active renderer it measures
/// key-to-photon latency (probe) and per-scenario memory, writes a `BenchResult`
/// JSON report, and terminates. The report is the artifact for the P7 renderer
/// decision and a regression baseline.
///
/// Latency runs **first** (clean single-pane state); the memory scenarios mutate
/// the window (splits/flood/alt-screen) and run after. If the latency probe can't
/// run (no Screen-Recording grant / no visible display), the report is still
/// written with memory + renderer + environment and an explicit
/// latency-unavailable marker — never an abort, never fabricated numbers.
@MainActor
enum BenchmarkRunner {
    static let defaultTrials = 60

    static func run(controller: TerminalWindowController, renderer: RendererBackend, reportPath: String) {
        let windowID = CGWindowID(controller.window.windowNumber)
        let pid = ProcessInfo.processInfo.processIdentifier
        let probe = LatencyProbe(windowID: windowID, pid: pid)
        let displayHz = Double(controller.window.screen?.maximumFramesPerSecond
            ?? NSScreen.main?.maximumFramesPerSecond ?? 60)
        let trials = trialCount()

        Task { @MainActor in
            var latency: LatencyStats?
            var unavailableReason: String?
            // Focus the pane (D3 first-responder) and hide the caret (D4) so the
            // probe times the typed glyph, not the blinking caret.
            controller.benchmarkPrepareForProbe()
            controller.benchmarkSetCaretHidden(true)
            do {
                let samples = try await probe.run(trials: trials)
                latency = LatencyStats(samplesMs: samples)
            } catch {
                unavailableReason = String(describing: error)
                NSLog("[xtty] benchmark: latency unavailable — %@", unavailableReason!)
            }
            controller.benchmarkSetCaretHidden(false)

            // Memory scenarios mutate the window, so run them after the latency probe.
            var memory: [MemorySample] = []
            for scenario in BenchScenario.defaultSet {
                if let bytes = controller.benchmarkSample(scenario) {
                    memory.append(MemorySample(scenario: scenario, footprintBytes: bytes))
                }
            }

            let result = BenchResult(
                renderer: renderer,
                latency: latency,
                latencyUnavailableReason: latency == nil ? (unavailableReason ?? "unavailable") : nil,
                captureFrameRate: latency != nil ? displayHz : nil,
                memory: memory,
                environment: BenchEnvironment(
                    machine: hwModel(),
                    os: ProcessInfo.processInfo.operatingSystemVersionString,
                    display: "\(Int(displayHz))Hz"
                )
            )

            do {
                try result.jsonData().write(to: URL(fileURLWithPath: reportPath))
                NSLog("[xtty] benchmark report written to %@", reportPath)
            } catch {
                NSLog("[xtty] benchmark: failed to write report — %@", String(describing: error))
            }
            NSApp.terminate(nil)
        }
    }

    /// Trial count from `-BenchmarkTrials <n>` (the e2e uses a small value to stay
    /// fast); otherwise `defaultTrials`.
    private static func trialCount() -> Int {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-BenchmarkTrials"), i + 1 < args.count,
           let n = Int(args[i + 1]), n > 0 {
            return n
        }
        return defaultTrials
    }

    /// The Mac model identifier (e.g. "Mac15,3"), part of the report environment.
    private static func hwModel() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        guard size > 0 else { return "unknown" }
        var bytes = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &bytes, &size, nil, 0)
        return String(cString: bytes)
    }
}
#endif
