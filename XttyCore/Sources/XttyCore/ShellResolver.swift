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
    /// Working directory for the launched process; `nil` uses the shell's default
    /// (handed to SwiftTerm's `startProcess(currentDirectory:)`).
    public let cwd: String?

    public init(executable: String, args: [String], execName: String, environment: [String: String], cwd: String? = nil) {
        self.executable = executable
        self.args = args
        self.execName = execName
        self.environment = environment
        self.cwd = cwd
    }

    /// A copy with the working directory replaced — used when a split inherits the
    /// focused pane's *live* directory instead of the profile's static `cwd`.
    public func withWorkingDirectory(_ newCwd: String?) -> ShellLaunchConfig {
        ShellLaunchConfig(executable: executable, args: args, execName: execName, environment: environment, cwd: newCwd)
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

    /// Build a launch configuration for an already-resolved shell path: a plain
    /// interactive login shell, no overrides. Pure — no system access.
    public static func launchConfig(
        forShell shellPath: String,
        environment: [String: String]
    ) -> ShellLaunchConfig {
        launchConfig(override: .none, forShell: shellPath, environment: environment)
    }

    /// The minimal seed environment shared by every launch: `TERM`/`COLORTERM`/
    /// `LANG` plus the user's identity vars (so the login shell finds
    /// `~/.zprofile`/`~/.zshrc` — the M5 dotfiles guarantee). PATH is deliberately
    /// not reconstructed; the login shell builds it. The child environment is
    /// replaced wholesale, so anything not seeded here (or merged by a profile) is
    /// dropped.
    static func seedEnvironment(environment: [String: String]) -> [String: String] {
        var seed: [String: String] = [
            "TERM": "xterm-256color",
            "COLORTERM": "truecolor",
        ]
        seed["LANG"] = environment["LANG"] ?? "en_US.UTF-8"
        for key in ["HOME", "USER", "LOGNAME"] {
            if let value = environment[key], !value.isEmpty {
                seed[key] = value
            }
        }
        return seed
    }

    /// Expand `~` / `$HOME` at the start of a configured working directory and
    /// verify it exists. Returns `nil` (caller falls back to the default) when the
    /// directory is missing. Pure — the existence check is injected.
    public static func expandCwd(
        _ raw: String,
        home: String,
        exists: (String) -> Bool
    ) -> String? {
        var path = raw
        if path == "~" {
            path = home
        } else if path.hasPrefix("~/") {
            path = home + path.dropFirst(1)
        } else if path == "$HOME" {
            path = home
        } else if path.hasPrefix("$HOME/") {
            path = home + path.dropFirst("$HOME".count)
        }
        return exists(path) ? path : nil
    }

    /// Build a launch configuration applying a profile's launch override. A
    /// `command` runs through the user's login + interactive shell
    /// (`<shell> -l -i -c '<command>'`, the command as a single argument) so it
    /// resolves against the user's real PATH and dotfiles; with no command this is
    /// a plain interactive login shell. `cwd` is expanded + validated (missing →
    /// default + warn); `env` is merged additively onto the seed (PATH already
    /// excluded by the config loader). Pure — cwd existence is injected.
    public static func launchConfig(
        override: LaunchOverride,
        forShell shellPath: String,
        environment: [String: String],
        integrationDir: String? = nil,
        homeDirectory: String = NSHomeDirectory(),
        cwdExists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) },
        warn: (String) -> Void = { _ in }
    ) -> ShellLaunchConfig {
        let base = (shellPath as NSString).lastPathComponent
        let execName = "-" + base

        var seed = seedEnvironment(environment: environment)
        // Silence the macOS bash deprecation banner ("The default interactive
        // shell is now zsh…"), which the system `/etc/bashrc` prints into the
        // terminal unless this var is set. A seed default (set before the
        // `override.env` merge, so a profile `env` can still override it); gated
        // to bash so it is a no-op for zsh and other shells.
        if base == "bash" { seed["BASH_SILENCE_DEPRECATION_WARNING"] = "1" }
        for (key, value) in override.env { seed[key] = value }

        // Shell-integration injection (zsh only): redirect ZDOTDIR to xtty's
        // bundled integration dir so the shell emits OSC 133/7 with no dotfile
        // edits. The bundled `.zshenv` restores the user's real ZDOTDIR (forwarded
        // here as XTTY_ORIG_ZDOTDIR — read from the *inherited* env BEFORE the seed
        // replaces it) and then sources their config. Skipped for `command`
        // one-shots, where there is no interactive prompt to instrument.
        let isCommand = (override.command.map { !$0.isEmpty }) ?? false
        if let integrationDir, base == "zsh", !isCommand {
            if let originalZDotDir = environment["ZDOTDIR"], !originalZDotDir.isEmpty {
                seed["XTTY_ORIG_ZDOTDIR"] = originalZDotDir
            }
            seed["ZDOTDIR"] = integrationDir
            seed["XTTY_SHELL_INTEGRATION"] = "1"
        }

        var cwd: String? = nil
        if let rawCwd = override.cwd {
            if let expanded = expandCwd(rawCwd, home: homeDirectory, exists: cwdExists) {
                cwd = expanded
            } else {
                warn("cwd: '\(rawCwd)' does not exist; using the default directory")
            }
        }

        let args: [String]
        if let command = override.command, !command.isEmpty {
            args = ["-l", "-i", "-c", command]
        } else {
            args = []
        }

        return ShellLaunchConfig(
            executable: shellPath,
            args: args,
            execName: execName,
            environment: seed,
            cwd: cwd
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

    /// Resolve a full launch configuration for a profile's launch override using
    /// the real system (shell path + filesystem cwd check).
    public static func resolve(
        override: LaunchOverride,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        integrationDir: String? = nil,
        warn: (String) -> Void = { _ in }
    ) -> ShellLaunchConfig {
        let path = resolveShellPath(
            shellEnv: environment["SHELL"],
            isExecutable: { FileManager.default.isExecutableFile(atPath: $0) },
            accountShell: accountShellPath
        )
        return launchConfig(override: override, forShell: path, environment: environment, integrationDir: integrationDir, warn: warn)
    }

    /// The current account's login shell from the password database, or `nil`.
    public static func accountShellPath() -> String? {
        guard let pw = getpwuid(getuid()) else { return nil }
        guard let shell = pw.pointee.pw_shell else { return nil }
        let path = String(cString: shell)
        return path.isEmpty ? nil : path
    }
}
