import AppKit
import Foundation
import XttyCore

/// Performs the AppKit/`Process` side effect of opening a resolved link. The
/// decision (URL vs editor vs `open`, scheme guard, cwd resolution) is made in
/// `XttyCore.LinkRouter`; this only executes the chosen `OpenerInvocation`.
///
/// Security (design D4): the file path is always a discrete `Process` argument —
/// never a shell string — so a hostile path printed by a program cannot inject a
/// command. The only shell use is resolving the editor *binary* on the user's
/// PATH (the no-PATH reality of a GUI-launched app), and the binary name is
/// shell-quoted.
@MainActor
enum FileOpener {
    /// Cache of editor-binary name → resolved absolute path ("" = not found).
    private static var pathCache: [String: String] = [:]

    static func perform(_ resolution: LinkOpenResolution) {
        switch resolution {
        case let .open(_, invocation):
            switch invocation {
            case let .openURL(raw):
                if let url = URL(string: raw) { NSWorkspace.shared.open(url) }
            case let .systemOpenFile(path):
                run("/usr/bin/open", [path])
            case let .editorArgv(argv):
                launchEditor(argv)
            }
        case let .blocked(scheme):
            NSLog("[xtty] link-open: blocked scheme '%@'", scheme)
        case let .unresolved(reason):
            NSLog("[xtty] link-open: unresolved (%@)", reason)
        }
    }

    private static func launchEditor(_ argv: [String]) {
        guard let bin = argv.first else { return }
        guard let exe = resolveBinary(bin) else {
            NSLog("[xtty] link-open: editor '%@' not found on PATH", bin)
            return
        }
        run(exe, Array(argv.dropFirst()))
    }

    /// Resolve `bin` to an absolute executable: an absolute path is used as-is;
    /// otherwise a cached login-shell `command -v` lookup finds it on the user's
    /// real PATH (GUI apps don't inherit the shell PATH).
    private static func resolveBinary(_ bin: String) -> String? {
        if bin.hasPrefix("/") {
            return FileManager.default.isExecutableFile(atPath: bin) ? bin : nil
        }
        if let cached = pathCache[bin] { return cached.isEmpty ? nil : cached }
        let resolved = loginShellWhich(bin)
        pathCache[bin] = resolved ?? ""
        return resolved
    }

    private static func loginShellWhich(_ bin: String) -> String? {
        let env = ProcessInfo.processInfo.environment
        let shell = ShellResolver.resolveShellPath(
            shellEnv: env["SHELL"],
            isExecutable: { FileManager.default.isExecutableFile(atPath: $0) },
            accountShell: ShellResolver.accountShellPath
        )
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: shell)
        // Only the binary *name* goes through the shell (quoted); the clicked file
        // path never does — it is a literal Process argument in `launchEditor`.
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

    private static func run(_ executable: String, _ arguments: [String]) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: executable)
        proc.arguments = arguments
        do { try proc.run() } catch {
            NSLog("[xtty] link-open: failed to launch %@: %@", executable, error.localizedDescription)
        }
    }
}
