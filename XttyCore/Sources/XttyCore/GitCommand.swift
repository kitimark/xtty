import Foundation

/// Best-effort detection of whether a foreground command line *is* a git
/// invocation — used to pause the git-review poll during the user's own git, so a
/// read-only poll doesn't surface a transient mid-operation repository state.
///
/// Deliberately conservative: it matches only when the first whitespace-delimited
/// token is exactly `git`. `sudo git`, `/usr/bin/git`, `GIT_OPTIONAL_LOCKS=0 git`,
/// and `cd x && git …` are NOT matched — those merely cause an extra background
/// read (over-refresh), never a wrong suppression. `github-cli`, `gitk`, `mygit`
/// are correctly excluded. View-free and unit-testable.
public enum GitCommand {
    public static func isGitInvocation(_ command: String?) -> Bool {
        guard let command else { return false }
        let trimmed = command.drop { $0 == " " || $0 == "\t" }
        let first = trimmed.prefix { $0 != " " && $0 != "\t" }
        return first == "git"
    }
}
