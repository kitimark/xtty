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
            var baseline: LatencyStats?
            var unavailableReason: String?
            var calibration: TimebaseCalibration?
            var frameQuantizationMs: Double?
            // Focus the pane (first-responder) and hide the caret so the probe
            // times the typed glyph, not the blinking caret (an independent
            // dirty-rect source).
            controller.benchmarkPrepareForProbe()
            controller.benchmarkSetCaretHidden(true)
            // A renderer-independent overlay stimulus for the common-path baseline
            // (design D5): the probe flips it and times it the same way.
            var overlay: ProbeOverlay?
            if let contentView = controller.window.contentView {
                overlay = ProbeOverlay(in: contentView)
            }
            let baselineFlip: (@MainActor () -> Void)?
            if let overlay {
                baselineFlip = { overlay.flip() }
            } else {
                baselineFlip = nil
            }
            do {
                let probeRun = try await probe.run(trials: trials, baselineFlip: baselineFlip)
                calibration = probeRun.calibration
                frameQuantizationMs = probeRun.frameIntervalMs
                if probeRun.calibration.passed, let stats = LatencyStats(samplesMs: probeRun.samplesMs) {
                    latency = stats
                } else {
                    // Calibration failed → untrustworthy; emit no absolute numbers
                    // (distinct from missing-permission: calibration is non-nil here).
                    unavailableReason = String(format: "timebase calibration failed (offset %.4gs)",
                                               probeRun.calibration.offsetSeconds)
                    NSLog("[xtty] benchmark: latency untrustworthy — %@", unavailableReason!)
                }
                baseline = LatencyStats(samplesMs: probeRun.baselineSamplesMs)
            } catch {
                unavailableReason = String(describing: error)
                NSLog("[xtty] benchmark: latency unavailable — %@", unavailableReason!)
            }
            overlay?.remove()
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
                frameQuantizationMs: latency != nil ? frameQuantizationMs : nil,
                timebaseCalibration: calibration,
                noOpBaseline: baseline,   // overlay-stimulus common-path baseline (D5)
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

/// A renderer-independent on-screen stimulus for the latency baseline pass (P7b /
/// design D5): a full-width strip at the bottom of the window (guaranteed visible in
/// the downscaled capture, clear of the prompt/cursor) whose layer color the probe
/// toggles. Because it is a plain AppKit/CoreAnimation layer — not the SwiftTerm
/// renderer — its keystroke-free flip→glass latency is the capture/compositor floor
/// common to both CoreGraphics and Metal, so it contextualizes how much of the
/// glyph latency is the compositor floor vs. the terminal pipeline.
@MainActor
final class ProbeOverlay {
    private let view: NSView
    private var toggled = false
    private let colorA = NSColor.black.cgColor
    private let colorB = NSColor.white.cgColor

    init(in contentView: NSView) {
        let stripHeight: CGFloat = 24
        let frame = NSRect(x: 0, y: 0, width: contentView.bounds.width, height: stripHeight)
        let v = NSView(frame: frame)
        v.autoresizingMask = [.width, .maxYMargin]
        v.wantsLayer = true
        v.layer?.backgroundColor = colorA
        contentView.addSubview(v, positioned: .above, relativeTo: nil)
        self.view = v
    }

    /// Toggle the strip color — a snap change (implicit animation disabled) so the
    /// captured frame is unambiguous.
    func flip() {
        toggled.toggle()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        view.layer?.backgroundColor = toggled ? colorB : colorA
        CATransaction.commit()
    }

    func remove() { view.removeFromSuperview() }
}
#endif
