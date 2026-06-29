import XCTest
import Metal

/// End-to-end coverage for the performance harness (P7a): the renderer A/B toggle
/// and the memory sampler are asserted via the DEBUG state dump (no screen-capture
/// permission or hardware display needed); a `-Benchmark` run is asserted to write
/// a results report. The latency probe's pixel path is exercised only where the
/// capture permission is available (it degrades to an explicit marker otherwise).
final class XttyPerformanceHarnessUITests: XCTestCase {

    /// 6.2 — the configured/overridden backend is reflected in the state dump.
    /// Waits for the *expected* value (the live app overwrites the shared dump
    /// every tick, so a previous test's still-terminating instance can't win).
    func testConfiguredCoreGraphicsRendererIsReported() {
        _ = launchConfigured(config: "", extraArgs: ["-UITestRenderer", "coregraphics"])
        let state = StateDumpReader.waitForState(timeout: 10) { $0["renderer"] as? String == "coregraphics" }
        XCTAssertEqual(state?["renderer"] as? String, "coregraphics")
    }

    /// 6.2 — Metal override is applied on Metal-capable hardware (the dev machine);
    /// the dump reports ground truth (the view's actual backend). Waits for the
    /// expected value to avoid a stale-dump race with the prior test's instance.
    func testConfiguredMetalRendererIsReported() throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "requires Metal-capable hardware")
        _ = launchConfigured(config: "renderer = metal", extraArgs: ["-UITestRenderer", "metal"])
        let state = StateDumpReader.waitForState(timeout: 10) { $0["renderer"] as? String == "metal" }
        XCTAssertEqual(state?["renderer"] as? String, "metal",
                       "Metal should initialize on Metal-capable hardware")
    }

    /// 6.3 — the memory sampler reports a positive resident footprint.
    func testMemorySamplerReportsPositiveFootprint() {
        _ = launchConfigured(config: "", extraArgs: [])
        let state = StateDumpReader.waitForState(timeout: 10) { ($0["memoryFootprintBytes"] as? NSNumber) != nil }
        let bytes = (state?["memoryFootprintBytes"] as? NSNumber)?.uint64Value ?? 0
        XCTAssertGreaterThan(bytes, 0, "phys_footprint should be a positive byte count")
    }

    /// 6.4 — a `-Benchmark` run writes a results report with the renderer + memory
    /// samples; latency is present where the capture path works, else an explicit
    /// unavailable marker (the degradation path). Tolerant of both permission states.
    ///
    /// Opt-in: this is the only test that drives the latency probe → ScreenCaptureKit,
    /// which prompts for Screen Recording (and re-prompts on every rebuild, since the
    /// app is ad-hoc signed). Gated behind `XTTY_RUN_BENCH_E2E=1` so routine
    /// `make test` stays prompt-free. The latency probe is documented experimental.
    func testBenchmarkRunWritesReport() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["XTTY_RUN_BENCH_E2E"] == "1",
                          "set XTTY_RUN_BENCH_E2E=1 to run the benchmark e2e (it prompts for Screen Recording)")
        let reportPath = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("xtty-bench-e2e-\(UUID().uuidString).json")
        try? FileManager.default.removeItem(atPath: reportPath)

        let app = XCUIApplication()
        app.launchArguments = [
            "-UITestGridDump",
            "-Benchmark", "-BenchmarkReport", reportPath,
            "-BenchmarkTrials", "2",
        ]
        app.launch()
        addTeardownBlock {
            app.terminate()
            try? FileManager.default.removeItem(atPath: reportPath)
        }

        // The benchmark mode runs scenarios then writes the report and quits.
        let deadline = Date().addingTimeInterval(60)
        var data: Data?
        while Date() < deadline {
            if let d = try? Data(contentsOf: URL(fileURLWithPath: reportPath)) { data = d; break }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        let report = try XCTUnwrap(try data.map { try JSONSerialization.jsonObject(with: $0) } as? [String: Any],
                                   "benchmark report was not written")

        // Renderer present.
        XCTAssertNotNil(report["renderer"] as? String)
        // Per-scenario memory samples present and non-empty.
        let memory = try XCTUnwrap(report["memory"] as? [[String: Any]])
        XCTAssertFalse(memory.isEmpty, "expected at least one memory scenario sample")
        XCTAssertTrue(memory.allSatisfy { ($0["footprintBytes"] as? NSNumber)?.uint64Value ?? 0 > 0 })
        // Latency: either a stats object, or the explicit unavailable/untrustworthy marker.
        let hasLatency = report["latency"] is [String: Any]
        let hasUnavailable = (report["latencyUnavailableReason"] as? String)?.isEmpty == false
        XCTAssertTrue(hasLatency || hasUnavailable,
                      "report must carry latency stats or an explicit unavailable/untrustworthy marker")

        // P7b provenance: when latency is present the timebase calibration passed
        // and the frame-quantized resolution is recorded (no implied sub-frame
        // precision). When latency ran at all, the calibration outcome is present.
        if hasLatency {
            let calibration = try XCTUnwrap(report["timebaseCalibration"] as? [String: Any],
                                            "a trustworthy latency run records the timebase calibration")
            XCTAssertEqual(calibration["passed"] as? Bool, true,
                           "latency stats are only emitted when calibration passed")
            XCTAssertNotNil(report["frameQuantizationMs"] as? NSNumber,
                            "the frame-quantized resolution must be recorded")
        }
    }
}
