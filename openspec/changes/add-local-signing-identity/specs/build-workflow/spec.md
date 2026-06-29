## ADDED Requirements

### Requirement: Optional stable local code-signing identity

The project SHALL provide an **opt-in** way to build with a stable local code-signing identity so that operating-system permission grants tied to the app's code identity (e.g. the Screen Recording grant the performance harness needs) persist across rebuilds instead of re-prompting. It SHALL include a helper that creates a self-signed **code-signing** certificate in the developer's keychain without modifying the system trust store or requiring privileged installation, and a build-entry-point override that, **when explicitly enabled**, signs the app with that identity. When the override is **not** enabled, the build SHALL retain the default ad-hoc ("Sign to Run Locally") signing so a fresh clone and CI are unaffected (no developer-specific signing configuration is committed). This affordance covers local development only; Developer ID, Hardened Runtime, and notarization remain out of scope.

#### Scenario: Default build stays ad-hoc and portable

- **WHEN** the stable-signing override is not enabled
- **THEN** the build signs ad-hoc as before, and no developer-specific signing identity is required or committed

#### Scenario: Enabling the override signs with the stable identity

- **WHEN** the developer has created the local signing identity and enables the override for a build
- **THEN** the app is signed with that identity (a cert-based code identity stable across rebuilds) rather than ad-hoc

#### Scenario: The identity helper needs no privileged install or system trust change

- **WHEN** the developer runs the identity-creation helper
- **THEN** it creates a self-signed code-signing certificate usable by the local signing toolchain without modifying the system trust store and without a privileged (sudo) installation

#### Scenario: A persisted grant survives a rebuild

- **WHEN** an OS permission keyed to the app's code identity has been granted for a build made with the stable identity, and the app is rebuilt with the same identity
- **THEN** the grant still applies to the rebuilt app without re-prompting
