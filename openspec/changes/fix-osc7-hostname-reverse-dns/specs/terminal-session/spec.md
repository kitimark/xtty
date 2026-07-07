## MODIFIED Requirements

### Requirement: Live working-directory capture from OSC 7

Each session SHALL capture the shell's reported working directory from OSC 7 and expose it as a per-session **live working directory**, distinct from the static launch directory. The application SHALL consume OSC 7 through the existing engine cwd-update delegate (not a custom OSC handler, so the engine's trust gating and stored host directory remain in effect). The raw OSC 7 URL SHALL be decoded view-free: the `file://` and `kitty-shell-cwd://` schemes SHALL both be accepted; for `file://` the path SHALL be percent-decoded; for `kitty-shell-cwd://` the path SHALL be taken raw; and a host that is not the local machine SHALL be flagged as remote rather than treated as a local filesystem path. The set of names that denote **the local machine** SHALL be determined **without performing a network name resolution**, and SHALL be **consistent with the host name the shell reports in its OSC 7 authority** (which the shell derives from the same system host name) — so a directory reported by the local host is never misclassified as remote, and computing the local-name set neither blocks the UI thread nor triggers the operating system's Local Network privacy prompt. Until an OSC 7 update arrives, the live working directory SHALL be the session's launch directory.

#### Scenario: cd updates the live working directory
- **WHEN** the shell reports a new directory via OSC 7 (e.g. after `cd /tmp`)
- **THEN** the session's live working directory updates to `/tmp`

#### Scenario: Both OSC 7 URL forms decode correctly
- **WHEN** the OSC 7 payload is `file://host/Users/me/My%20Project` or `kitty-shell-cwd://host/Users/me/My Project`
- **THEN** the decoded path is `/Users/me/My Project` (percent-decoded only for the `file://` form)

#### Scenario: A remote host is flagged, not treated as local
- **WHEN** the OSC 7 host is not the local machine (e.g. a directory reported over ssh)
- **THEN** the live working directory is flagged as remote and is not treated as a local filesystem path

#### Scenario: A directory reported by the local host is classified local without a network lookup
- **WHEN** the shell (whose OSC 7 authority is its own system host name) reports a working directory on the local machine
- **THEN** the directory is classified local (not remote), the classification is computed without any reverse-DNS / network name resolution, and no operating-system Local Network privacy prompt is raised and the UI thread is not blocked while computing the local-name set

#### Scenario: Decoding runs without the app
- **WHEN** the test suite runs
- **THEN** the OSC 7 URL decoding (scheme handling, percent-decoding, remote-host detection) is exercised by a unit test that does not launch the app or create a terminal view

#### Scenario: Local-name derivation runs without the app
- **WHEN** the test suite runs
- **THEN** the derivation of the local-machine name set from a given system host name is exercised by a unit test that does not launch the app or create a terminal view
