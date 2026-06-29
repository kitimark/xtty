import Foundation

/// A fixed, repeatable memory-measurement scenario the performance harness drives
/// and samples. View-free and `Codable` so the scenario set is unit-testable and
/// reproducible across runs; the app layer interprets each case (spawn panes,
/// flood output, start an alt-screen program) and records a `MemorySample`.
///
/// Each scenario is measured **independently** — the app layer resets to one clean
/// pane before establishing a scenario, so `paneCount` is the scenario's actual
/// pane count (e.g. `scrollbackFlood`/`altScreen` are single-pane states, not a
/// carry-over of `multiPane`'s panes).
public enum BenchScenario: String, CaseIterable, Equatable, Sendable, Codable {
    /// A single idle pane (the floor).
    case idleOnePane = "idle-1pane"
    /// Several panes open at once (`multiPaneCount`).
    case multiPane = "multi-pane"
    /// One pane after a large-output flood that saturates the scrollback cap.
    case scrollbackFlood = "scrollback-flood"
    /// One pane running an alternate-screen program (e.g. a full-screen TUI).
    case altScreen = "alt-screen"

    /// How many panes the scenario establishes before sampling.
    public var paneCount: Int {
        switch self {
        case .idleOnePane, .scrollbackFlood, .altScreen: return 1
        case .multiPane: return Self.multiPaneCount
        }
    }

    /// The pane count for `.multiPane` — representative of a busy session; a
    /// one-line change if a different N is wanted (design Open Questions).
    public static let multiPaneCount = 4

    /// The default scenario set the benchmark runs (idle → multi → flood → alt).
    public static var defaultSet: [BenchScenario] { allCases }
}

/// One scenario's resident-memory measurement.
public struct MemorySample: Equatable, Sendable, Codable {
    public let scenario: BenchScenario
    /// Physical memory footprint (`phys_footprint`) in bytes.
    public let footprintBytes: UInt64

    public init(scenario: BenchScenario, footprintBytes: UInt64) {
        self.scenario = scenario
        self.footprintBytes = footprintBytes
    }
}

/// The key-to-photon latency distribution from the probe (milliseconds).
public struct LatencyStats: Equatable, Sendable, Codable {
    public let trials: Int
    public let p50Ms: Double
    public let p95Ms: Double
    public let p99Ms: Double
    /// The raw per-trial samples (ms), retained for re-analysis in P7b.
    public let samplesMs: [Double]

    public init(trials: Int, p50Ms: Double, p95Ms: Double, p99Ms: Double, samplesMs: [Double]) {
        self.trials = trials
        self.p50Ms = p50Ms
        self.p95Ms = p95Ms
        self.p99Ms = p99Ms
        self.samplesMs = samplesMs
    }

    /// Build stats from raw samples (nil for an empty set). Percentiles use the
    /// nearest-rank method on the sorted samples.
    public init?(samplesMs raw: [Double]) {
        guard !raw.isEmpty else { return nil }
        let sorted = raw.sorted()
        func percentile(_ p: Double) -> Double {
            let rank = Int((p / 100.0 * Double(sorted.count)).rounded(.up))
            let idx = min(max(rank - 1, 0), sorted.count - 1)
            return sorted[idx]
        }
        self.init(trials: sorted.count, p50Ms: percentile(50), p95Ms: percentile(95),
                  p99Ms: percentile(99), samplesMs: raw)
    }
}

/// The outcome of the latency probe's startup timebase calibration (P7b): whether
/// the keystroke-injection clock and the frame-presentation-timestamp clock
/// reconcile into one domain. When `passed` is false the absolute latency numbers
/// are untrustworthy and SHALL NOT be emitted (the report carries the marker
/// instead) — see `BenchResult.latencyUnavailableReason`.
public struct TimebaseCalibration: Equatable, Sendable, Codable {
    public let passed: Bool
    /// Measured offset (seconds) between the two clocks at startup; ~0 and stable
    /// when they reconcile. A large or unstable value fails the gate.
    public let offsetSeconds: Double

    public init(passed: Bool, offsetSeconds: Double) {
        self.passed = passed
        self.offsetSeconds = offsetSeconds
    }
}

/// The run environment, so a report is interpretable on its own (and comparable
/// only to runs from the same machine/display, per the relative-bar method).
public struct BenchEnvironment: Equatable, Sendable, Codable {
    public let machine: String
    public let os: String
    public let display: String

    public init(machine: String, os: String, display: String) {
        self.machine = machine
        self.os = os
        self.display = display
    }
}

/// The full benchmark result — the artifact for the P7 renderer decision and a
/// performance-regression baseline. `latency` is nil when the probe could not run
/// (no screen-capture permission or no visible display) **or** the timebase
/// calibration failed (untrustworthy), in which case `latencyUnavailableReason`
/// explains why; memory is always measured.
///
/// P7b latency-measurement provenance makes the latency numbers' trustworthiness
/// and time-resolution explicit rather than implying sub-frame precision:
/// `timebaseCalibration` (did the clocks reconcile), `frameQuantizationMs` (the
/// achieved resolution — one display-refresh interval), and `noOpBaseline` (a
/// per-renderer identical-content baseline measured the same way, so a constant
/// capture/scheduling offset can be distinguished from a real renderer difference).
public struct BenchResult: Equatable, Sendable, Codable {
    public let renderer: RendererBackend
    public let latency: LatencyStats?
    /// Set iff `latency` is nil — an explicit "unavailable / untrustworthy" marker,
    /// never silent (missing permission, no display, or a failed timebase gate).
    public let latencyUnavailableReason: String?
    /// The capture frame rate (fps) the latency was measured at; nil when latency
    /// is unavailable. See `frameQuantizationMs` for the resolution in ms.
    public let captureFrameRate: Double?
    /// The achieved frame-quantized time-resolution (ms) of the latency
    /// measurement — one display-refresh interval (variable on a ProMotion panel);
    /// nil when latency is unavailable. Records that latency is NOT sub-frame.
    public let frameQuantizationMs: Double?
    /// The startup timebase-calibration outcome (P7b); nil when calibration was
    /// not reached (e.g. capture unavailable before it could run).
    public let timebaseCalibration: TimebaseCalibration?
    /// The per-renderer no-op / identical-content baseline distribution, measured
    /// identically, so a constant offset can be subtracted in P7b; nil when not run.
    public let noOpBaseline: LatencyStats?
    public let memory: [MemorySample]
    public let environment: BenchEnvironment

    public init(
        renderer: RendererBackend,
        latency: LatencyStats?,
        latencyUnavailableReason: String? = nil,
        captureFrameRate: Double? = nil,
        frameQuantizationMs: Double? = nil,
        timebaseCalibration: TimebaseCalibration? = nil,
        noOpBaseline: LatencyStats? = nil,
        memory: [MemorySample],
        environment: BenchEnvironment
    ) {
        self.renderer = renderer
        self.latency = latency
        self.latencyUnavailableReason = latencyUnavailableReason
        self.captureFrameRate = captureFrameRate
        self.frameQuantizationMs = frameQuantizationMs
        self.timebaseCalibration = timebaseCalibration
        self.noOpBaseline = noOpBaseline
        self.memory = memory
        self.environment = environment
    }

    /// Serialize to pretty, stable-key JSON (the machine-readable report format).
    public func jsonData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    /// Parse a report back from JSON (used by tests and P7b tooling).
    public static func from(jsonData data: Data) throws -> BenchResult {
        try JSONDecoder().decode(BenchResult.self, from: data)
    }
}
