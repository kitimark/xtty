import AppKit
import CoreGraphics
import ScreenCaptureKit

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

/// In-process key-to-photon latency probe (P7a).
///
/// Each trial posts a synthetic keystroke to the app and times until the target
/// window's rendered **pixels** change, then confirms the change persists across a
/// second capture so a one-frame cursor blink is rejected (the mechanism-agnostic
/// guard, design D4). It is **renderer-agnostic** (it watches pixels, not the
/// engine) so CoreGraphics and Metal are measured identically; it omits the
/// constant hardware tail, so the renderer **delta** is accurate even though
/// absolute values read low.
///
/// Capture uses ScreenCaptureKit's one-shot `SCScreenshotManager.captureImage`
/// (`CGWindowListCreateImage` is unavailable on the current SDK). The probe is
/// `async`: awaiting each capture **yields the main runloop**, so the app keeps
/// processing the keystroke and rendering the frame between captures. Resolution is
/// frame-granular — adequate because the deciding latency differences are
/// whole-frame (drawable-queue depth / frame pacing), per design D5. Capture
/// requires the Screen-Recording grant and a visible window.
///
/// The caller (on the main actor) must have made the active pane first responder so
/// the keystroke reaches the PTY (design D3).
///
/// ⚠️ **Known fidelity limitation (P7a):** each `SCScreenshotManager` capture costs
/// ~20 ms — *more* than the ~8–16 ms key-to-photon latency it measures — so the
/// first post-keystroke capture already contains the rendered glyph and the result
/// is floor-limited to roughly one capture interval. The numbers are therefore
/// **coarse and not trustworthy for a CoreGraphics-vs-Metal verdict**; that verdict
/// (P7b) needs a finer instrument: an `SCStream` with per-frame presentation
/// timestamps, or an engine present-hook. Memory measurement is unaffected.
///
/// `@MainActor`: each `await` capture suspends the main actor and returns control to
/// the runloop (so rendering proceeds), then resumes — no busy-spin, and the
/// non-Sendable ScreenCaptureKit values never cross an actor boundary.
@MainActor
final class LatencyProbe {
    private let windowID: CGWindowID
    private let pid: pid_t

    /// Virtual key codes: `x` to type, `delete` to undo it (keeps the line stable
    /// across trials so each trial's baseline is the same clean prompt).
    private static let typeKey: CGKeyCode = 7   // kVK_ANSI_X
    private static let undoKey: CGKeyCode = 51  // kVK_Delete

    init(windowID: CGWindowID, pid: pid_t) {
        self.windowID = windowID
        self.pid = pid
    }

    /// Run `trials` measurement passes and return the per-trial key-to-photon
    /// latencies in milliseconds. Throws loudly (never fabricates data) if capture
    /// is unavailable; trials that time out are dropped, and if none succeed it
    /// throws `noChangeDetected`.
    func run(trials: Int, timeoutMs: Double = 500, settleMs: Double = 60) async throws -> [Double] {
        let (filter, config) = try await makeCaptureTarget()
        // A capture must work before we measure anything — else fail loudly.
        _ = try await captureHash(filter: filter, config: config)

        var samples: [Double] = []
        for _ in 0..<trials {
            if let ms = try await measureOnce(filter: filter, config: config, timeoutMs: timeoutMs) {
                samples.append(ms)
            }
            // Undo the typed character and let the view settle back to baseline.
            postKey(Self.undoKey)
            try? await Task.sleep(nanoseconds: UInt64(settleMs * 1_000_000))
        }
        guard !samples.isEmpty else { throw LatencyProbeError.noChangeDetected }
        return samples
    }

    /// One trial: baseline → post keystroke → time to the first captured frame that
    /// differs from baseline **and** stays different on the next capture (rejecting
    /// a one-frame cursor blink). Returns nil on timeout.
    private func measureOnce(
        filter: SCContentFilter, config: SCStreamConfiguration, timeoutMs: Double
    ) async throws -> Double? {
        let baseline = try await captureHash(filter: filter, config: config)

        let start = DispatchTime.now().uptimeNanoseconds
        postKey(Self.typeKey)

        let deadline = start + UInt64(timeoutMs * 1_000_000)
        var pendingChangeAt: UInt64?
        while DispatchTime.now().uptimeNanoseconds < deadline {
            let hash = try await captureHash(filter: filter, config: config)
            // Stamp AFTER the capture completes: the change is only *confirmed* on
            // screen once this frame is read. (Crediting the pre-capture time would
            // report ~0 ms, since the keystroke renders during the capture itself.)
            let observedAt = DispatchTime.now().uptimeNanoseconds
            if hash != baseline {
                if let changedAt = pendingChangeAt {
                    // Two consecutive captures differ from baseline → a persistent
                    // glyph, not a blink. Credit the first differing capture.
                    return Double(changedAt - start) / 1_000_000
                }
                pendingChangeAt = observedAt
            } else {
                // Reverted to baseline → that was a transient (blink); reset.
                pendingChangeAt = nil
            }
        }
        return nil
    }

    /// Resolve the shareable target for this window plus a small-output capture
    /// config (low resolution keeps each capture + hash cheap).
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
        config.width = max(Int(window.frame.width / 4), 1)
        config.height = max(Int(window.frame.height / 4), 1)
        config.showsCursor = false
        return (filter, config)
    }

    /// A cheap content hash of one captured frame of the target window. Throws
    /// `captureUnavailable` when the screenshot fails (no permission / off-screen).
    private func captureHash(filter: SCContentFilter, config: SCStreamConfiguration) async throws -> Int {
        let image: CGImage
        do {
            image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        } catch {
            throw LatencyProbeError.captureUnavailable(String(describing: error))
        }
        guard let data = image.dataProvider?.data, let ptr = CFDataGetBytePtr(data) else {
            throw LatencyProbeError.captureUnavailable("no pixel data")
        }
        let len = CFDataGetLength(data)
        var hash: UInt64 = 1469598103934665603   // FNV-1a offset basis
        let prime: UInt64 = 1099511628211
        var i = 0
        while i < len {
            hash = (hash ^ UInt64(ptr[i])) &* prime
            i += 4
        }
        return Int(bitPattern: UInt(truncatingIfNeeded: hash))
    }

    /// Post a key down+up to the app's process (delivered to the key window's first
    /// responder). Posting to the pid works regardless of frontmost state.
    private func postKey(_ code: CGKeyCode) {
        let source = CGEventSource(stateID: .hidSystemState)
        CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: true)?.postToPid(pid)
        CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: false)?.postToPid(pid)
    }
}
