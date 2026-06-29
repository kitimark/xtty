import XCTest
import SwiftTerm
@testable import XttyCore

// P7c lifecycle census — the in-process half (design D5). XttyCore unit tests
// run in-process, so they CAN hold a weak reference to a model object and assert
// it deallocates once released (a retain cycle would keep the weak ref alive).
// The App-layer controllers/views run out-of-process under XCUITest and cannot
// be weak-referenced from a test — those are covered by the state-dump census
// churn e2e instead.
//
// Each test releases its sole strong reference by letting a nested-function
// scope return (the local is deterministically released at scope exit, on the
// same actor — no addTeardownBlock cross-actor hop), then asserts the weak ref
// is nil.

private final class NoopTerminalDelegate: TerminalDelegate {
    func send(source: Terminal, data: ArraySlice<UInt8>) {}
}

final class LifecycleLeakTests: XCTestCase {
    private let delegate = NoopTerminalDelegate()

    private func makeSession() -> TerminalSession {
        let engine = Terminal(delegate: delegate)
        let config = ShellResolver.launchConfig(forShell: "/bin/zsh", environment: [:])
        return TerminalSession(terminal: engine, launchConfig: config)
    }

    func testTerminalSessionDeallocatesWhenReleased() {
        weak var weakSession: TerminalSession?
        func scope() { weakSession = makeSession() }
        scope()
        XCTAssertNil(weakSession, "TerminalSession was retained after release (retain cycle suspected)")
    }

    @MainActor
    func testSessionRegistryDeallocatesWhenReleased() {
        weak var weakRegistry: SessionRegistry?
        func scope() { weakRegistry = SessionRegistry() }
        scope()
        XCTAssertNil(weakRegistry, "SessionRegistry was retained after release (retain cycle suspected)")
    }

    @MainActor
    func testPaneAndSessionDeallocateAfterUnregister() {
        // The registry outlives the pane here (held by the test), so this proves
        // unregister truly drops the registry's strong reference — and that the
        // pane in turn releases the session it owns.
        let registry = SessionRegistry()
        weak var weakPane: Pane?
        weak var weakSession: TerminalSession?
        func scope() {
            let session = makeSession()
            weakSession = session
            let pane = registry.makePane(for: session)
            weakPane = pane
            registry.unregister(pane.id)
        }
        scope()
        XCTAssertNil(weakPane, "Pane was retained after unregister (registry back-reference or cycle)")
        XCTAssertNil(weakSession, "TerminalSession was retained after its pane was released")
    }
}
