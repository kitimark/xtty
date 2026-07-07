import Foundation

/// Derivation of the set of names that denote **the local machine**, view-free
/// and unit-testable.
///
/// An OSC 7 working directory is classified local vs. remote by testing its
/// reported authority against this set (see `OSC7.decode(_:localHostNames:)`).
/// The App layer reads the system host name once (via `gethostname(2)` — the
/// same syscall behind the shell's `$HOST`, so the set and the emitted OSC 7
/// authority agree by construction) and passes the raw string here; this type
/// holds only the pure name derivation, with no syscall or network I/O of its
/// own. Deriving the set from `gethostname` — rather than a reverse-DNS lookup —
/// is what keeps classification off the network: no Local Network privacy
/// prompt, no blocked UI thread. See
/// `research/03-analysis/local-network-privacy-forensics.md` (§2b, §8d, §8g).
public enum LocalHost {
    /// The lowercased names that denote the local machine, derived from a
    /// **given** system host name: always `""` and `"localhost"`, plus the host
    /// name itself and its short form (up to the first `"."` — e.g. `"mymac"`
    /// from `"mymac.local"`). Pure — the caller supplies the name.
    public static func names(from rawHostName: String) -> Set<String> {
        var names: Set<String> = ["", "localhost"]
        let host = rawHostName.lowercased()
        names.insert(host)
        if let short = host.split(separator: ".").first { names.insert(String(short)) }
        return names
    }
}
