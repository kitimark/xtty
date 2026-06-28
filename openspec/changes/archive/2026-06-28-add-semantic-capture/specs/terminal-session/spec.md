## ADDED Requirements

### Requirement: Live working-directory capture from OSC 7

Each session SHALL capture the shell's reported working directory from OSC 7 and expose it as a per-session **live working directory**, distinct from the static launch directory. The application SHALL consume OSC 7 through the existing engine cwd-update delegate (not a custom OSC handler, so the engine's trust gating and stored host directory remain in effect). The raw OSC 7 URL SHALL be decoded view-free: the `file://` and `kitty-shell-cwd://` schemes SHALL both be accepted; for `file://` the path SHALL be percent-decoded; for `kitty-shell-cwd://` the path SHALL be taken raw; and a host that is not the local machine SHALL be flagged as remote rather than treated as a local filesystem path. Until an OSC 7 update arrives, the live working directory SHALL be the session's launch directory.

#### Scenario: cd updates the live working directory
- **WHEN** the shell reports a new directory via OSC 7 (e.g. after `cd /tmp`)
- **THEN** the session's live working directory updates to `/tmp`

#### Scenario: Both OSC 7 URL forms decode correctly
- **WHEN** the OSC 7 payload is `file://host/Users/me/My%20Project` or `kitty-shell-cwd://host/Users/me/My Project`
- **THEN** the decoded path is `/Users/me/My Project` (percent-decoded only for the `file://` form)

#### Scenario: A remote host is flagged, not treated as local
- **WHEN** the OSC 7 host is not the local machine (e.g. a directory reported over ssh)
- **THEN** the live working directory is flagged as remote and is not treated as a local filesystem path

#### Scenario: Decoding runs without the app
- **WHEN** the test suite runs
- **THEN** the OSC 7 URL decoding (scheme handling, percent-decoding, remote-host detection) is exercised by a unit test that does not launch the app or create a terminal view
