import Foundation

/// Locates xtty's bundled shell-integration scripts (the OSC 133/7 hooks).
///
/// The scripts ship as an app-bundle folder reference at
/// `Resources/shell-integration/<shell>/`. The zsh directory is handed to
/// `ShellResolver` as the `ZDOTDIR` to inject (its bootstrap `.zshenv` restores
/// the user's real `ZDOTDIR`, then installs the hooks). Fail-soft: when the
/// resource is missing, callers skip injection and the shell launches normally.
enum ShellIntegration {
    /// The bundled zsh integration directory, or `nil` if it can't be found or is
    /// incomplete (missing the bootstrap `.zshenv`).
    static let zshDirectory: String? = {
        guard let base = Bundle.main.url(forResource: "shell-integration", withExtension: nil) else {
            NSLog("[xtty] shell-integration: bundle resource not found; semantic capture disabled")
            return nil
        }
        let dir = base.appendingPathComponent("zsh")
        let bootstrap = dir.appendingPathComponent(".zshenv")
        guard FileManager.default.fileExists(atPath: bootstrap.path) else {
            NSLog("[xtty] shell-integration: %@ missing; semantic capture disabled", bootstrap.path)
            return nil
        }
        return dir.path
    }()
}
