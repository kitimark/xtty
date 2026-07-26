import Darwin
import Foundation
import XttyCore

/// Executes the system `git` and builds toolkit-independent snapshots for the
/// git-review panel. The decision-free side-effect layer (peer of `FileOpener`):
/// all parsing lives in `XttyCore` (`GitStatusParser`/`NumstatParser`/`DiffParser`).
///
/// `git` is resolved on the **login-shell PATH** (a GUI-launched app doesn't
/// inherit it), cached after the first lookup. Every path is a **literal argv
/// element** after `--` (never a shell string) — the D4 rule. `GIT_OPTIONAL_LOCKS=0`
/// is set on every invocation so a background read never races `.git/index.lock`,
/// and diffs use `--no-ext-diff --no-textconv --submodule=short --no-color` so
/// user diff/pager/submodule config can't corrupt, expand, or recurse into the
/// parsed output. All methods are nonisolated
/// and meant to run off the main actor (the controller dispatches them on a serial
/// queue).
enum GitRunner {
    private static let pathLock = NSLock()
    // Outer optional = "resolved yet?"; inner = the path (nil = not found).
    nonisolated(unsafe) private static var resolvedGitPath: String?? = nil

    #if DEBUG
    struct DebugDiffProcessObservation: Sendable {
        let processID: Int32
        let path: String
        let cutoffReason: String?
        let reaped: Bool
        let absentAfterReap: Bool
    }

    private static let debugDiffProcessLock = NSLock()
    nonisolated(unsafe) private static var lastDebugDiffProcess:
        DebugDiffProcessObservation?

    static func debugDiffProcessObservation() -> DebugDiffProcessObservation? {
        debugDiffProcessLock.lock()
        defer { debugDiffProcessLock.unlock() }
        return lastDebugDiffProcess
    }

    private static func recordDebugDiffProcess(
        _ proc: Process,
        path: String,
        cutoffReason: DiffOutputCutoffReason?,
        reaped: Bool
    ) {
        let pid = proc.processIdentifier
        var absent = false
        if reaped {
            errno = 0
            absent = Darwin.kill(pid, 0) == -1 && errno == ESRCH
        }
        let observation = DebugDiffProcessObservation(
            processID: pid,
            path: path,
            cutoffReason: cutoffReason?.rawValue,
            reaped: reaped,
            absentAfterReap: absent
        )
        debugDiffProcessLock.lock()
        lastDebugDiffProcess = observation
        debugDiffProcessLock.unlock()
    }
    #endif

    /// Absolute path to `git`, resolved once via the login shell (cached).
    static func gitPath() -> String? {
        pathLock.lock(); defer { pathLock.unlock() }
        if let cached = resolvedGitPath { return cached }
        let resolved = loginShellWhich("git")
        resolvedGitPath = resolved
        return resolved
    }

    struct RunResult {
        let launched: Bool   // false when git couldn't be executed at all
        let exitCode: Int32
        let stdout: String
    }

    /// Per-file diff output distinguishes a normal Git status from an xtty-owned
    /// preview cutoff. A signal exit is accepted as preview data only when
    /// `cutoffReason` proves this runner initiated it.
    struct DiffRunResult {
        let launched: Bool
        let exitCode: Int32
        let stdout: String
        let cutoffReason: DiffOutputCutoffReason?

        var wasTruncated: Bool { cutoffReason != nil }
    }

    /// Run `git <args>` (with `GIT_OPTIONAL_LOCKS=0`), capturing stdout. Reads the
    /// pipe before `waitUntilExit` so large output can't deadlock the buffer.
    static func run(_ args: [String]) -> RunResult {
        guard let git = gitPath() else { return RunResult(launched: false, exitCode: -1, stdout: "") }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: git)
        proc.arguments = args
        var env = ProcessInfo.processInfo.environment
        env["GIT_OPTIONAL_LOCKS"] = "0"
        proc.environment = env
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        do { try proc.run() } catch {
            return RunResult(launched: false, exitCode: -1, stdout: "")
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        return RunResult(launched: true, exitCode: proc.terminationStatus,
                         stdout: String(decoding: data, as: UTF8.self))
    }

    /// Run a per-file `git diff`, retaining only a fixed stdout prefix. This is
    /// deliberately separate from `run`: clipping status/numstat output could
    /// manufacture a plausible but incomplete repository snapshot.
    static func runDiff(
        _ args: [String],
        limits: DiffOutputLimits = .preview
    ) -> DiffRunResult {
        guard let git = gitPath() else {
            return DiffRunResult(launched: false, exitCode: -1, stdout: "", cutoffReason: nil)
        }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: git)
        proc.arguments = args
        var env = ProcessInfo.processInfo.environment
        env["GIT_OPTIONAL_LOCKS"] = "0"
        proc.environment = env
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
        } catch {
            return DiffRunResult(launched: false, exitCode: -1, stdout: "", cutoffReason: nil)
        }
        let previewPath = args.last ?? ""
        #if DEBUG
        recordDebugDiffProcess(proc, path: previewPath, cutoffReason: nil, reaped: false)
        #endif

        let readHandle = pipe.fileHandleForReading
        var accumulator = BoundedDiffOutputAccumulator(limits: limits)
        var cutoffReason: DiffOutputCutoffReason?
        do {
            while true {
                let chunk = try readHandle.read(upToCount: limits.readChunkBytes) ?? Data()
                if chunk.isEmpty { break }
                if let reason = accumulator.append(chunk) {
                    cutoffReason = reason
                    terminateAndReap(proc, closing: readHandle)
                    #if DEBUG
                    recordDebugDiffProcess(proc, path: previewPath,
                                           cutoffReason: reason, reaped: true)
                    #endif
                    break
                }
            }
        } catch {
            // A read failure is not a valid truncated preview. Stop the writer so
            // it cannot block on a pipe xtty no longer consumes, then surface a
            // normal failure status to the caller.
            terminateAndReap(proc, closing: readHandle)
            #if DEBUG
            recordDebugDiffProcess(proc, path: previewPath,
                                   cutoffReason: nil, reaped: true)
            #endif
            return DiffRunResult(launched: true, exitCode: -1, stdout: "", cutoffReason: nil)
        }

        if cutoffReason == nil {
            try? readHandle.close()
            proc.waitUntilExit()
            #if DEBUG
            recordDebugDiffProcess(proc, path: previewPath,
                                   cutoffReason: nil, reaped: true)
            #endif
        }
        let bounded = accumulator.result()
        if let cutoffReason {
            NSLog("[xtty] git-review diff cutoff: %@ (%d retained bytes)",
                  cutoffReason.rawValue, bounded.data.count)
        }
        return DiffRunResult(
            launched: true,
            exitCode: proc.terminationStatus,
            stdout: String(decoding: bounded.data, as: UTF8.self),
            cutoffReason: cutoffReason
        )
    }

    /// Cutoff lifecycle: signal the direct Git child, close the reader so neither
    /// it nor an inherited writer can remain pipe-blocked, then reap. Git normally
    /// honors SIGTERM immediately; SIGKILL is the bounded fallback.
    private static func terminateAndReap(_ proc: Process, closing readHandle: FileHandle) {
        if proc.isRunning { proc.terminate() }
        try? readHandle.close()

        let deadline = DispatchTime.now() + .milliseconds(250)
        while proc.isRunning, DispatchTime.now() < deadline {
            usleep(5_000)
        }
        if proc.isRunning {
            _ = Darwin.kill(proc.processIdentifier, SIGKILL)
        }
        proc.waitUntilExit()
    }

    // MARK: Snapshot

    /// Build the full review snapshot for `directory` (off-main). Distinguishes
    /// "git unavailable" (binary not runnable) from "not a repository".
    static func snapshot(forDirectory directory: String, diffContext: Int) -> GitReviewSnapshot {
        let top = run(["-C", directory, "rev-parse", "--show-toplevel"])
        if !top.launched { return .unavailable }
        let root = top.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        if top.exitCode != 0 || root.isEmpty { return .empty }

        let branch = resolveBranch(root: root)

        let status = run(["-C", root, "--no-optional-locks", "status", "--porcelain=v1", "-z",
                          "--untracked-files=all", "--no-renames"])
        var files = GitStatusParser.parse(status.stdout)

        // Per-file +/- badges for tracked changes vs HEAD (untracked files have no
        // tracked counts; a fresh repo with no HEAD just yields none).
        let numstat = run(["-C", root, "--no-optional-locks", "diff", "HEAD",
                           "--no-textconv", "--submodule=short", "--numstat", "-z"])
        if numstat.exitCode == 0 {
            let counts = NumstatParser.parse(numstat.stdout)
            files = files.map { file in
                guard let c = counts[file.path] else { return file }
                var f = file
                f.added = c.added; f.removed = c.removed; f.isBinary = c.isBinary
                return f
            }
        }

        return GitReviewSnapshot(isRepo: true, repoRoot: root, branch: branch, files: files)
    }

    private static func resolveBranch(root: String) -> String? {
        let sym = run(["-C", root, "symbolic-ref", "--short", "HEAD"])
        if sym.exitCode == 0 {
            let name = sym.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty { return name }
        }
        // Detached HEAD (or fresh repo): fall back to a short SHA.
        let sha = run(["-C", root, "rev-parse", "--short", "HEAD"])
        if sha.exitCode == 0 {
            let s = sha.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if !s.isEmpty { return s }
        }
        return nil
    }

    // MARK: Per-file diff (lazy)

    /// Load one file's unified diff (off-main). Untracked files diff against
    /// `/dev/null` via `--no-index` (where **exit 1 == differences == success**);
    /// tracked files diff against HEAD (falling back to the index for a repo with
    /// no commits).
    static func diff(repoRoot root: String, file: GitChangedFile, diffContext: Int) -> FileDiff {
        let unified = "--unified=\(max(0, diffContext))"
        if file.status == .untracked {
            let r = runDiff(["-C", root, "diff", "--no-ext-diff", "--no-textconv",
                             "--submodule=short", "--no-color", unified, "--no-index",
                             "--", "/dev/null", file.path])
            // --no-index: 0 = identical, 1 = differs (the normal case), >1 = error.
            guard r.launched, r.wasTruncated || r.exitCode <= 1 else { return .empty }
            return DiffEmphasis.refine(
                DiffParser.parse(r.stdout, sourceTruncated: r.wasTruncated)
            )
        }

        let head = runDiff(["-C", root, "--no-optional-locks", "diff", "HEAD",
                            "--no-ext-diff", "--no-textconv", "--submodule=short",
                            "--no-color", unified, "--", file.path])
        if head.launched && (head.wasTruncated || head.exitCode == 0) {
            return DiffEmphasis.refine(
                DiffParser.parse(head.stdout, sourceTruncated: head.wasTruncated)
            )
        }
        // No HEAD yet (fresh repo) → show what's staged.
        let staged = runDiff(["-C", root, "--no-optional-locks", "diff", "--staged",
                              "--no-ext-diff", "--no-textconv", "--submodule=short",
                              "--no-color", unified, "--", file.path])
        guard staged.launched, staged.wasTruncated || staged.exitCode == 0 else { return .empty }
        return DiffEmphasis.refine(
            DiffParser.parse(staged.stdout, sourceTruncated: staged.wasTruncated)
        )
    }

    // MARK: Login-shell PATH resolution (mirrors FileOpener's pattern)

    /// Resolve `bin` to an absolute executable via a cached login-shell
    /// `command -v` lookup (GUI apps don't inherit the shell PATH). Only the binary
    /// name passes through the shell (quoted); git's arguments never do.
    private static func loginShellWhich(_ bin: String) -> String? {
        let env = ProcessInfo.processInfo.environment
        let shell = ShellResolver.resolveShellPath(
            shellEnv: env["SHELL"],
            isExecutable: { FileManager.default.isExecutableFile(atPath: $0) },
            accountShell: ShellResolver.accountShellPath
        )
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: shell)
        proc.arguments = ["-l", "-i", "-c", "command -v \(shellQuote(bin))"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        do { try proc.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        guard proc.terminationStatus == 0,
              let out = String(data: data, encoding: .utf8)?
                  .trimmingCharacters(in: .whitespacesAndNewlines),
              !out.isEmpty else { return nil }
        let last = out.split(separator: "\n").last.map(String.init) ?? out
        return last.hasPrefix("/") ? last : nil
    }

    private static func shellQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
