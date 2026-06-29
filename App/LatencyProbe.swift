import AppKit
import CoreGraphics
import CoreMedia
import CoreVideo
import ScreenCaptureKit
import XttyCore

/// Why the latency probe could not produce a measurement (it fails loudly — it
/// never fabricates a sample, per the perf-harness spec).
enum LatencyProbeError: Error, CustomStringConvertible {
    /// Screen-capture returned no image — typically the Screen-Recording TCC grant
    /// is missing, or the window is off-screen / on a sleeping/headless display.
    case captureUnavailable(String)
    /// The target window was not found among the shareable windows.
    case windowNotFound
    /// No trial produced a detectable on-screen change within the timeout.
    case noChangeDetected

    var description: String {
        switch self {
        case let .captureUnavailable(why):
            return "screen capture unavailable (\(why)); grant Screen Recording and run on a visible display"
        case .windowNotFound:
            return "target window not found among shareable windows"
        case .noChangeDetected:
            return "no on-screen change detected within the timeout"
        }
    }
}

/// The outcome of one probe run (P7b): the per-trial key-to-photon samples plus
/// the measurement provenance the report records. `calibration.passed == false`
/// means the absolute numbers are untrustworthy and `samplesMs` is empty.
struct LatencyProbeRun {
    let samplesMs: [Double]
    /// The renderer-independent reference-stimulus baseline (overlay flip → glass),
    /// measured identically — the common capture/compositor/scheduling floor shared
    /// by both renderers (design D5). Empty when no baseline stimulus was provided.
    let baselineSamplesMs: [Double]
    let calibration: TimebaseCalibration
    /// The achieved frame-quantized resolution (ms) — one display-refresh interval;
    /// nil if it could not be observed.
    let frameIntervalMs: Double?
}

/// In-process key-to-photon latency probe (P7b — the trustworthy rewrite of P7a).
///
/// It opens a **continuous `SCStream`** of the target window and, per trial, posts
/// a synthetic keystroke (t0) then waits for the first captured **`.complete`**
/// frame whose pixels differ from baseline; it credits that frame's **on-screen
/// presentation timestamp** (`SCStreamFrameInfo.displayTime`) as t1. Because frames
/// arrive asynchronously on a callback — each self-stamped — the per-capture cost
/// no longer serializes into the measurement, so it escapes P7a's ~20 ms
/// screenshot-polling floor and resolves whole-frame (one refresh interval)
/// differences. It is **renderer-agnostic** (it watches pixels, not the engine) and
/// **fork-free** (no SwiftTerm change).
///
/// **Clock (design D2):** t0 is `mach_absolute_time()` and t1 is `displayTime`
/// (mach *ticks*); both are normalized through the **same**
/// `CMClockMakeHostTimeFromSystemUnits(_:).seconds` so their difference is a valid
/// duration (P7a's bug was subtracting mach nanoseconds from mach ticks — off by
/// the ~41.67× timebase on Apple Silicon).
///
/// **Calibration gate (design D4):** at startup it compares `mach`-now to a
/// captured frame's `displayTime`; if they cannot be reconciled into one domain
/// (the Apple-Forum-785046 epoch anomaly) the run is marked **untrustworthy** and
/// emits no absolute numbers, rather than reporting plausible-but-wrong values.
///
/// **Resolution is frame-quantized** (one refresh interval, ProMotion-variable);
/// the report surfaces this rather than implying sub-frame precision. The omitted
/// hardware tail is renderer-independent and cancels in the renderer delta.
///
/// The caller (on the main actor) must have made the active pane first responder so
/// the keystroke reaches the PTY (design D3) and hidden the caret (an independent
/// dirty-rect source).
@MainActor
final class LatencyProbe {
    private let windowID: CGWindowID
    private let pid: pid_t

    /// Virtual key codes: `x` to type, `delete` to undo it (keeps the line stable
    /// across trials so each trial's baseline is the same clean prompt).
    private static let typeKey: CGKeyCode = 7   // kVK_ANSI_X
    private static let undoKey: CGKeyCode = 51  // kVK_Delete

    /// |mach-now − frame displayTime| must be under this for the clocks to be
    /// considered one domain. A unit/epoch mismatch is off by 100s of ms to
    /// seconds, so 100 ms cleanly separates "reconciled" from "broken".
    private static let calibrationToleranceSeconds: Double = 0.1

    /// Serial queue the `SCStream` delivers sample buffers on.
    private static let sinkQueue = DispatchQueue(label: "xtty.latencyprobe.sink")

    init(windowID: CGWindowID, pid: pid_t) {
        self.windowID = windowID
        self.pid = pid
    }

    /// Run `trials` measurement passes over a continuous `SCStream`. Throws loudly
    /// (never fabricates data) if capture is unavailable. If the timebase
    /// calibration fails, returns a run with `calibration.passed == false` and no
    /// samples. Trials that time out are dropped; if calibration passed but no trial
    /// succeeded, throws `noChangeDetected`.
    /// `baselineFlip`, when provided, toggles a renderer-independent on-screen
    /// stimulus (the overlay); the probe runs a second pass timing it the same way
    /// to record the common capture/compositor floor (design D5).
    func run(
        trials: Int, timeoutMs: Double = 500, settleMs: Double = 60,
        baselineFlip: (@MainActor () -> Void)? = nil
    ) async throws -> LatencyProbeRun {
        let (filter, config) = try await makeCaptureTarget()
        let displayHz = Double(NSScreen.main?.maximumFramesPerSecond ?? 60)
        let frameIntervalMs = displayHz > 0 ? 1000.0 / displayHz : nil

        let sink = FrameSink()
        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        do {
            try stream.addStreamOutput(sink, type: .screen, sampleHandlerQueue: Self.sinkQueue)
            try await stream.startCapture()
        } catch {
            throw LatencyProbeError.captureUnavailable(String(describing: error))
        }
        defer { stream.stopCapture { _ in } }

        // Warm-up + calibration: the first `.complete` frame after startCapture is
        // the initial composite. Use it to reconcile the clocks (design D4).
        guard let warm = await sink.waitForNextComplete(timeoutMs: 1500) else {
            throw LatencyProbeError.captureUnavailable("stream delivered no frame (no visible window?)")
        }
        let nowSeconds = Self.hostSeconds(mach_absolute_time())
        let offset = nowSeconds - warm.displaySeconds
        let calibration = TimebaseCalibration(passed: abs(offset) < Self.calibrationToleranceSeconds,
                                              offsetSeconds: offset)
        guard calibration.passed else {
            // Untrustworthy: emit no absolute numbers (spec ADDED requirement).
            return LatencyProbeRun(samplesMs: [], baselineSamplesMs: [],
                                   calibration: calibration, frameIntervalMs: frameIntervalMs)
        }

        // Glyph pass: keystroke → rendered-glyph latency (the renderer path).
        var samples: [Double] = []
        for _ in 0..<trials {
            if let ms = await measureOnce(sink: sink, timeoutMs: timeoutMs) {
                samples.append(ms)
            }
            // Undo the typed character and let the view settle back to baseline.
            postKey(Self.undoKey)
            try? await Task.sleep(nanoseconds: UInt64(settleMs * 1_000_000))
        }
        guard !samples.isEmpty else { throw LatencyProbeError.noChangeDetected }

        // Baseline pass: a renderer-independent overlay flip → glass, measured the
        // same way — the common capture/compositor floor shared by both renderers
        // (design D5). Each trial toggles the overlay, then toggles it back.
        var baselineSamples: [Double] = []
        if let flip = baselineFlip {
            for _ in 0..<trials {
                if let ms = await measureFlip(sink: sink, flip: flip, timeoutMs: timeoutMs) {
                    baselineSamples.append(ms)
                }
                flip()   // toggle back to the prior color
                try? await Task.sleep(nanoseconds: UInt64(settleMs * 1_000_000))
            }
        }

        return LatencyProbeRun(samplesMs: samples, baselineSamplesMs: baselineSamples,
                               calibration: calibration, frameIntervalMs: frameIntervalMs)
    }

    /// One baseline trial: toggle the renderer-independent overlay (t0) and time
    /// until its color reaches glass (t1 = changed frame presentation timestamp).
    private func measureFlip(sink: FrameSink, flip: @MainActor () -> Void, timeoutMs: Double) async -> Double? {
        let baseline = sink.currentHash()
        let t0 = Self.hostSeconds(mach_absolute_time())
        flip()
        guard let changed = await sink.waitForChange(baseline: baseline, timeoutMs: timeoutMs) else {
            return nil
        }
        let ms = (changed.displaySeconds - t0) * 1000.0
        return ms > 0 ? ms : nil
    }

    /// One trial: capture baseline → record t0 (host clock) → post keystroke →
    /// await the first `.complete` frame whose pixels differ from baseline,
    /// blink-guarded → credit that frame's presentation timestamp (t1). Returns nil
    /// on timeout or a non-positive interval (a scheduling/epoch glitch).
    private func measureOnce(sink: FrameSink, timeoutMs: Double) async -> Double? {
        let baseline = sink.currentHash()
        let t0 = Self.hostSeconds(mach_absolute_time())
        postKey(Self.typeKey)
        guard let changed = await sink.waitForChange(baseline: baseline, timeoutMs: timeoutMs) else {
            return nil
        }
        let ms = (changed.displaySeconds - t0) * 1000.0
        return ms > 0 ? ms : nil
    }

    /// Convert a raw `mach_absolute_time()` value (system units / ticks) to seconds
    /// in the host-time domain — the SAME conversion applied to `displayTime`, so t0
    /// and t1 are provably one clock (design D2).
    private static func hostSeconds(_ machUnits: UInt64) -> Double {
        CMClockMakeHostTimeFromSystemUnits(machUnits).seconds
    }

    /// Resolve the shareable target for this window plus a small-output stream
    /// config (low resolution + a small format keeps each frame's hash cheap).
    private func makeCaptureTarget() async throws -> (SCContentFilter, SCStreamConfiguration) {
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(
                false, onScreenWindowsOnly: true)
        } catch {
            throw LatencyProbeError.captureUnavailable(String(describing: error))
        }
        guard let window = content.windows.first(where: { $0.windowID == windowID }) else {
            throw LatencyProbeError.windowNotFound
        }
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()
        // Authorize the panel's full refresh; cadence is content-driven anyway (a
        // `.complete` frame only arrives on change). Deep queue so no stall masks
        // the trigger frame. Caret already hidden by the caller.
        config.minimumFrameInterval = CMTime(value: 1, timescale: 120)
        config.queueDepth = 8
        config.showsCursor = false
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.width = max(Int(window.frame.width / 4), 1)
        config.height = max(Int(window.frame.height / 4), 1)
        return (filter, config)
    }

    /// Post a key down+up to the app's process (delivered to the key window's first
    /// responder). Posting to the pid works regardless of frontmost state.
    private func postKey(_ code: CGKeyCode) {
        let source = CGEventSource(stateID: .hidSystemState)
        CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: true)?.postToPid(pid)
        CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: false)?.postToPid(pid)
    }
}

/// Collects `SCStream` frames off the sample-handler queue and lets the probe await
/// the next interesting frame. One waiter at a time; results cross back via a
/// continuation. `@unchecked Sendable`: all mutable state is guarded by `lock`, and
/// the non-Sendable `CMSampleBuffer` is never stored — only its hash + timestamp.
private final class FrameSink: NSObject, SCStreamOutput, @unchecked Sendable {
    private let lock = NSLock()
    private var latestHash: UInt64 = 0
    private var latestDisplaySeconds: Double = 0

    private var waiterPredicate: ((UInt64) -> Bool)?
    private var waiterBlinkGuard = false
    private var waiterPendingFrame: (hash: UInt64, displaySeconds: Double)?
    private var waiterResume: (((hash: UInt64, displaySeconds: Double)?) -> Void)?

    /// The most recent observed `.complete` frame's pixel hash (the trial baseline).
    func currentHash() -> UInt64 {
        lock.lock(); defer { lock.unlock() }
        return latestHash
    }

    /// Await the next `.complete` frame (any content) — used for warm-up + calibration.
    func waitForNextComplete(timeoutMs: Double) async -> (hash: UInt64, displaySeconds: Double)? {
        await withCheckedContinuation { (cont: CheckedContinuation<(hash: UInt64, displaySeconds: Double)?, Never>) in
            installWaiter(predicate: { _ in true }, blinkGuard: false, timeoutMs: timeoutMs) {
                cont.resume(returning: $0)
            }
        }
    }

    /// Await the first `.complete` frame differing from `baseline`, confirmed by a
    /// second differing frame (rejects a one-frame blink); credits the FIRST
    /// differing frame's presentation timestamp.
    func waitForChange(baseline: UInt64, timeoutMs: Double) async -> (hash: UInt64, displaySeconds: Double)? {
        await withCheckedContinuation { (cont: CheckedContinuation<(hash: UInt64, displaySeconds: Double)?, Never>) in
            installWaiter(predicate: { $0 != baseline }, blinkGuard: true, timeoutMs: timeoutMs) {
                cont.resume(returning: $0)
            }
        }
    }

    private func installWaiter(
        predicate: @escaping (UInt64) -> Bool,
        blinkGuard: Bool,
        timeoutMs: Double,
        resume: @escaping ((hash: UInt64, displaySeconds: Double)?) -> Void
    ) {
        lock.lock()
        waiterPredicate = predicate
        waiterBlinkGuard = blinkGuard
        waiterPendingFrame = nil
        waiterResume = resume
        lock.unlock()
        // Timeout: whoever clears the waiter under the lock calls resume exactly once.
        DispatchQueue.global().asyncAfter(deadline: .now() + timeoutMs / 1000.0) { [weak self] in
            guard let self else { return }
            self.lock.lock()
            if let r = self.waiterResume {
                self.clearWaiterLocked()
                self.lock.unlock()
                r(nil)
            } else {
                self.lock.unlock()
            }
        }
    }

    private func clearWaiterLocked() {
        waiterPredicate = nil
        waiterBlinkGuard = false
        waiterPendingFrame = nil
        waiterResume = nil
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, let frame = Self.parse(sampleBuffer), frame.status == .complete else { return }
        lock.lock()
        latestHash = frame.hash
        latestDisplaySeconds = frame.displaySeconds
        guard let predicate = waiterPredicate, let resume = waiterResume else { lock.unlock(); return }
        if predicate(frame.hash) {
            if waiterBlinkGuard {
                if let first = waiterPendingFrame {
                    clearWaiterLocked()
                    lock.unlock()
                    resume(first)               // credit the first differing frame
                } else {
                    waiterPendingFrame = (frame.hash, frame.displaySeconds)
                    lock.unlock()               // need a second confirming frame
                }
            } else {
                clearWaiterLocked()
                lock.unlock()
                resume((frame.hash, frame.displaySeconds))
            }
        } else {
            waiterPendingFrame = nil            // reverted → not a persistent change
            lock.unlock()
        }
    }

    /// Extract (pixel hash, frame status, displayTime-in-seconds) from a frame.
    private static func parse(_ sb: CMSampleBuffer) -> (hash: UInt64, status: SCFrameStatus, displaySeconds: Double)? {
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sb, createIfNecessary: false)
                as? [[SCStreamFrameInfo: Any]],
              let info = attachments.first else { return nil }

        let status: SCFrameStatus
        if let raw = info[.status] as? Int, let s = SCFrameStatus(rawValue: raw) {
            status = s
        } else {
            status = .complete
        }

        // displayTime: a mach-absolute value in system units (ticks).
        let displayUnits: UInt64
        if let u = info[.displayTime] as? UInt64 {
            displayUnits = u
        } else if let n = info[.displayTime] as? NSNumber {
            displayUnits = n.uint64Value
        } else {
            displayUnits = mach_absolute_time()
        }
        let displaySeconds = CMClockMakeHostTimeFromSystemUnits(displayUnits).seconds

        guard status == .complete, let pixelBuffer = CMSampleBufferGetImageBuffer(sb) else {
            return (0, status, displaySeconds)
        }
        return (hashPixelBuffer(pixelBuffer), status, displaySeconds)
    }

    /// A cheap FNV-1a content hash over the (small, downscaled) BGRA pixel buffer.
    private static func hashPixelBuffer(_ pb: CVPixelBuffer) -> UInt64 {
        CVPixelBufferLockBaseAddress(pb, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pb, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(pb) else { return 0 }
        let height = CVPixelBufferGetHeight(pb)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pb)
        let len = height * bytesPerRow
        let ptr = base.assumingMemoryBound(to: UInt8.self)
        var hash: UInt64 = 1469598103934665603   // FNV-1a offset basis
        let prime: UInt64 = 1099511628211
        var i = 0
        while i < len {                           // stride 16: cheap, still change-sensitive
            hash = (hash ^ UInt64(ptr[i])) &* prime
            i += 16
        }
        return hash
    }
}
