import Foundation

/// How to launch the user's shell: the executable, its arguments, the argv[0]
/// name (which carries login-shell semantics), and the seed environment.
///
/// This is produced by `ShellResolver` and consumed by the app's terminal host,
/// which hands it to SwiftTerm's `startProcess`. It is a plain value so the
/// resolution logic stays view-free and unit-testable.
public struct ShellLaunchConfig: Equatable, Sendable {
    /// Absolute path to the shell executable (e.g. `/bin/zsh`).
    public let executable: String
    /// Extra arguments after argv[0]. Empty at P1 — login+interactive behavior
    /// comes from `execName`'s leading dash plus running on a PTY.
    public let args: [String]
    /// argv[0] handed to the shell. A leading `-` (e.g. `-zsh`) is the POSIX
    /// convention that makes the shell a *login* shell, so it sources the
    /// profile files where PATH and the user's environment are built.
    public let execName: String
    /// Minimal seed environment. We set only `TERM`/`COLORTERM`/`LANG` and let
    /// the login shell build everything else (notably PATH) from the user's
    /// startup files. We deliberately do NOT reconstruct PATH here.
    public let environment: [String: String]

    public init(executable: String, args: [String], execName: String, environment: [String: String]) {
        self.executable = executable
        self.args = args
        self.execName = execName
        self.environment = environment
    }
}

/// Resolves which shell to launch and how, independent of any terminal view.
///
/// Pure logic so it can be exercised by `swift test` without launching the app
/// or constructing a terminal view. This is the engine-facing seam's first
/// genuine test target.
public enum ShellResolver {
    /// Fallback path used when neither `$SHELL` nor the account database yields a
    /// usable shell.
    public static let defaultShell = "/bin/zsh"

    /// Resolve the shell path with the standard fallback chain:
    /// `$SHELL` (if set and executable) → the account's shell (`getpwuid`) →
    /// `defaultShell`.
    ///
    /// The probes are injected so the chain is unit-testable without touching
    /// the real filesystem or password database.
    /// - Parameters:
    ///   - shellEnv: the value of `$SHELL`, or `nil` if unset.
    ///   - isExecutable: predicate testing whether a path is an executable file.
    ///   - accountShell: the account's login shell (e.g. from `getpwuid`), or `nil`.
    public static func resolveShellPath(
        shellEnv: String?,
        isExecutable: (String) -> Bool,
        accountShell: () -> String?
    ) -> String {
        if let shellEnv, !shellEnv.isEmpty, isExecutable(shellEnv) {
            return shellEnv
        }
        if let account = accountShell(), !account.isEmpty, isExecutable(account) {
            return account
        }
        return defaultShell
    }

    /// Build a launch configuration for an already-resolved shell path: derive
    /// the login argv[0] and the seed environment. Pure — no system access.
    public static func launchConfig(
        forShell shellPath: String,
        environment: [String: String]
    ) -> ShellLaunchConfig {
        let base = (shellPath as NSString).lastPathComponent
        let execName = "-" + base

        var seed: [String: String] = [
            "TERM": "xterm-256color",
            "COLORTERM": "truecolor",
        ]
        // Preserve the user's locale if present; otherwise provide a sane UTF-8
        // default so the shell and programs behave. We never reconstruct PATH —
        // the login shell builds it from the profile files.
        seed["LANG"] = environment["LANG"] ?? "en_US.UTF-8"

        // Mirror the user's identity variables so the login shell can find the
        // home directory (and thus `~/.zprofile`/`~/.zshrc` — the M5 dotfiles
        // guarantee) and report the right user. Unlike PATH, these are not
        // rebuilt by the shell, so they must be carried over. We replace the
        // child environment wholesale, so anything not seeded here is dropped.
        for key in ["HOME", "USER", "LOGNAME"] {
            if let value = environment[key], !value.isEmpty {
                seed[key] = value
            }
        }

        return ShellLaunchConfig(
            executable: shellPath,
            args: [],
            execName: execName,
            environment: seed
        )
    }

    /// Resolve a full launch configuration using the real system: `$SHELL`, the
    /// filesystem executable check, and the account database (`getpwuid`).
    public static func resolve(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> ShellLaunchConfig {
        let path = resolveShellPath(
            shellEnv: environment["SHELL"],
            isExecutable: { FileManager.default.isExecutableFile(atPath: $0) },
            accountShell: accountShellPath
        )
        return launchConfig(forShell: path, environment: environment)
    }

    /// The current account's login shell from the password database, or `nil`.
    public static func accountShellPath() -> String? {
        guard let pw = getpwuid(getuid()) else { return nil }
        guard let shell = pw.pointee.pw_shell else { return nil }
        let path = String(cString: shell)
        return path.isEmpty ? nil : path
    }
}
