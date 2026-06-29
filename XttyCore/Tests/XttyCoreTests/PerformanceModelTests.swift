import XCTest
@testable import XttyCore

/// Unit tests for the view-free performance model (scenario set + result model
/// serialization), exercised without launching the app or creating a view.
final class PerformanceModelTests: XCTestCase {
    func testDefaultScenarioSetCoversTheFourScenarios() {
        let set = BenchScenario.defaultSet
        XCTAssertEqual(set, [.idleOnePane, .multiPane, .scrollbackFlood, .altScreen])
    }

    func testScenarioPaneCounts() {
        XCTAssertEqual(BenchScenario.idleOnePane.paneCount, 1)
        XCTAssertEqual(BenchScenario.scrollbackFlood.paneCount, 1)
        XCTAssertEqual(BenchScenario.altScreen.paneCount, 1)
        XCTAssertEqual(BenchScenario.multiPane.paneCount, BenchScenario.multiPaneCount)
        XCTAssertGreaterThan(BenchScenario.multiPaneCount, 1)
    }

    func testScenarioStableRawValues() {
        // The report's scenario ids are part of its machine-readable contract.
        XCTAssertEqual(BenchScenario.idleOnePane.rawValue, "idle-1pane")
        XCTAssertEqual(BenchScenario.multiPane.rawValue, "multi-pane")
        XCTAssertEqual(BenchScenario.scrollbackFlood.rawValue, "scrollback-flood")
        XCTAssertEqual(BenchScenario.altScreen.rawValue, "alt-screen")
    }

    func testLatencyStatsFromSamplesComputesPercentiles() {
        let samples = (1...100).map { Double($0) }   // 1...100 ms
        let stats = LatencyStats(samplesMs: samples)
        XCTAssertNotNil(stats)
        XCTAssertEqual(stats?.trials, 100)
        // Nearest-rank: p50 → rank 50, p95 → 95, p99 → 99.
        XCTAssertEqual(stats?.p50Ms, 50)
        XCTAssertEqual(stats?.p95Ms, 95)
        XCTAssertEqual(stats?.p99Ms, 99)
    }

    func testLatencyStatsFromEmptySamplesIsNil() {
        XCTAssertNil(LatencyStats(samplesMs: []))
    }

    func testBenchResultRoundTripsThroughJSON() throws {
        let result = BenchResult(
            renderer: .metal,
            latency: LatencyStats(samplesMs: [8, 9, 10, 11, 12]),
            captureFrameRate: 120,
            memory: [
                MemorySample(scenario: .idleOnePane, footprintBytes: 50_000_000),
                MemorySample(scenario: .multiPane, footprintBytes: 120_000_000),
            ],
            environment: BenchEnvironment(machine: "Mac", os: "macOS 26", display: "built-in 120Hz")
        )
        let data = try result.jsonData()
        let decoded = try BenchResult.from(jsonData: data)
        XCTAssertEqual(decoded, result)
    }

    func testBenchResultRoundTripsLatencyProvenanceFields() throws {
        // P7b: calibration outcome, frame-quantized resolution, and the no-op
        // baseline survive serialization (the report's trustworthiness metadata).
        let result = BenchResult(
            renderer: .coregraphics,
            latency: LatencyStats(samplesMs: [16, 17, 18]),
            captureFrameRate: 120,
            frameQuantizationMs: 1000.0 / 120.0,
            timebaseCalibration: TimebaseCalibration(passed: true, offsetSeconds: 0.0002),
            noOpBaseline: LatencyStats(samplesMs: [8, 8.5, 9]),
            memory: [MemorySample(scenario: .idleOnePane, footprintBytes: 60_000_000)],
            environment: BenchEnvironment(machine: "Mac", os: "macOS 26", display: "built-in 120Hz")
        )
        let decoded = try BenchResult.from(jsonData: try result.jsonData())
        XCTAssertEqual(decoded, result)
        XCTAssertEqual(decoded.timebaseCalibration?.passed, true)
        XCTAssertEqual(decoded.frameQuantizationMs, 1000.0 / 120.0)
        XCTAssertEqual(decoded.noOpBaseline?.trials, 3)
    }

    func testFailedCalibrationIsRepresentableAsUntrustworthyWithNoAbsoluteStats() throws {
        // ADDED requirement: a failed timebase gate emits NO absolute latency
        // numbers (latency == nil) but is distinct from missing-permission — the
        // calibration outcome is recorded (passed == false) alongside the marker.
        let result = BenchResult(
            renderer: .metal,
            latency: nil,
            latencyUnavailableReason: "timebase calibration failed (offset 0.42s)",
            timebaseCalibration: TimebaseCalibration(passed: false, offsetSeconds: 0.42),
            memory: [MemorySample(scenario: .idleOnePane, footprintBytes: 64_000_000)],
            environment: BenchEnvironment(machine: "Mac", os: "macOS 26", display: "built-in 120Hz")
        )
        let decoded = try BenchResult.from(jsonData: try result.jsonData())
        XCTAssertNil(decoded.latency, "untrustworthy run emits no absolute latency stats")
        XCTAssertEqual(decoded.timebaseCalibration?.passed, false)
        XCTAssertEqual(decoded.latencyUnavailableReason, "timebase calibration failed (offset 0.42s)")
        // Distinct from missing-permission: that case leaves calibration nil.
        XCTAssertNotNil(decoded.timebaseCalibration)
        XCTAssertEqual(decoded.memory.first?.footprintBytes, 64_000_000)
    }

    func testBenchResultEncodesLatencyUnavailableMarker() throws {
        let result = BenchResult(
            renderer: .coregraphics,
            latency: nil,
            latencyUnavailableReason: "no screen-capture permission",
            captureFrameRate: nil,
            memory: [MemorySample(scenario: .idleOnePane, footprintBytes: 42_000_000)],
            environment: BenchEnvironment(machine: "Mac", os: "macOS 26", display: "headless")
        )
        let decoded = try BenchResult.from(jsonData: try result.jsonData())
        XCTAssertNil(decoded.latency)
        XCTAssertEqual(decoded.latencyUnavailableReason, "no screen-capture permission")
        XCTAssertEqual(decoded.memory.first?.footprintBytes, 42_000_000)
        // The renderer + memory survive even with latency unavailable.
        XCTAssertEqual(decoded.renderer, .coregraphics)
    }
}
