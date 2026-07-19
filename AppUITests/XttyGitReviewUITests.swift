import XCTest

// e2e for the git-review panel (the add-git-review change, P6a). Drives a real
// zsh — with xtty's automatic shell-integration injection active — inside a
// temporary git repository, and asserts via the DEBUG `gitReview` state dump that
// the changed files are listed with the right status categories, that selecting a
// file yields its diff summary, and that opening a file routes through the editor
// opener (asserted via `lastLinkOpen`, no real editor launched).
//
// Like the semantic-capture suite, this depends on the host's zsh config letting
// the integration hooks load (so OSC 7 reports the live cwd); it degrades to a
// screenshot when capture isn't active or the DEBUG hook is absent (Release).
final class XttyGitReviewUITests: XCTestCase {

    private func type(_ command: String, into app: XCUIApplication) {
        app.typeText(command)
        app.typeKey(.enter, modifierFlags: [])
    }

    private func gitReview(_ state: [String: Any]?) -> [String: Any] {
        (state?["gitReview"] as? [String: Any]) ?? [:]
    }

    private func changedFiles(_ gr: [String: Any]) -> [[String: Any]] {
        (gr["changedFiles"] as? [[String: Any]]) ?? []
    }

    private func status(of path: String, in files: [[String: Any]]) -> String? {
        files.first { ($0["path"] as? String) == path }?["status"] as? String
    }

    /// Wait until shell-integration capture is live (a non-empty last action),
    /// proving the injected hooks emit OSC 133 / OSC 7 in this environment.
    private func waitForCaptureActive(timeout: TimeInterval) -> Bool {
        StateDumpReader.waitForState(timeout: timeout) {
            !(($0["lastSemanticAction"] as? String) ?? "").isEmpty
        } != nil
    }

    func testListsChangedFilesSelectsDiffAndOpens() {
        let tmp = NSTemporaryDirectory()
        let selectPath = (tmp as NSString).appendingPathComponent("xtty-git-select-\(UUID().uuidString)")
        let openPath = (tmp as NSString).appendingPathComponent("xtty-git-open-\(UUID().uuidString)")
        addTeardownBlock {
            try? FileManager.default.removeItem(atPath: selectPath)
            try? FileManager.default.removeItem(atPath: openPath)
        }

        let app = launchConfigured(
            config: "",
            extraEnv: ["XTTY_TEST_GIT_SELECT": selectPath, "XTTY_TEST_GIT_OPEN": openPath],
            extraArgs: ["-UITestGitReview"]
        )
        guard StateDumpReader.waitForState(timeout: 10) != nil else {
            attachScreenshot("no-state-dump (Release?)"); return
        }
        _ = GridDumpReader.waitForNonEmpty(timeout: 5)
        type("true", into: app)
        guard waitForCaptureActive(timeout: 8) else {
            // Capability-absent arm: the git panel keys off the OSC 7 live cwd, which
            // a non-injecting shell never reports — assert the crisp negative (no
            // capture) rather than passing vacuously (split-shell-dependent-testplan D4).
            assertSemanticCaptureInactive("git-review"); return
        }

        // Build a known repo: commit a tracked file, then modify it + add an
        // untracked file. Single chained command so the shell cwd ends in the repo.
        let dir = "xtty-gittest-\(UUID().uuidString.prefix(8))"
        type("cd ~ && rm -rf \(dir) && mkdir \(dir) && cd \(dir) && git init -q && " +
             "printf 'hello\\n' > tracked.txt && git add tracked.txt && " +
             "git -c user.email=t@e -c user.name=t commit -qm init && " +
             "printf 'changed\\n' >> tracked.txt && printf 'new\\n' > untracked.txt && true",
             into: app)
        addTeardownBlock { /* the repo lives under the user's HOME; left for cleanup */ }

        let state = StateDumpReader.waitForState(timeout: 20) {
            let gr = ($0["gitReview"] as? [String: Any]) ?? [:]
            let files = (gr["changedFiles"] as? [[String: Any]]) ?? []
            return (gr["isRepo"] as? Bool) == true
                && files.contains { ($0["path"] as? String) == "tracked.txt" }
        }
        StateDumpReader.attach(self, name: "git-review-list")
        guard let state else {
            attachScreenshot("git-review: repo never surfaced"); return
        }
        let gr = gitReview(state)
        let files = changedFiles(gr)
        XCTAssertEqual(status(of: "tracked.txt", in: files), "modified",
                       "the modified tracked file should be in Changes; files=\(files)")
        XCTAssertEqual(status(of: "untracked.txt", in: files), "untracked",
                       "the new file should be Untracked; files=\(files)")

        // Select tracked.txt → assert its diff summary lands.
        try? "tracked.txt".write(toFile: selectPath, atomically: true, encoding: .utf8)
        let selected = StateDumpReader.waitForState(timeout: 10) {
            let gr = ($0["gitReview"] as? [String: Any]) ?? [:]
            let sel = gr["selectedDiff"] as? [String: Any]
            return (sel?["path"] as? String) == "tracked.txt" && ((sel?["added"] as? Int) ?? 0) >= 1
        }
        XCTAssertNotNil(selected, "selecting tracked.txt should load a diff with an added line")
        StateDumpReader.attach(self, name: "git-review-diff")

        // Open tracked.txt → assert it routes through the link opener (recorded,
        // no real editor launched).
        try? "tracked.txt".write(toFile: openPath, atomically: true, encoding: .utf8)
        let opened = StateDumpReader.waitForState(timeout: 10) {
            let link = $0["lastLinkOpen"] as? [String: Any]
            return (link?["action"] as? String) == "opened"
                && (link?["kind"] as? String) == "file"
                && (((link?["path"] as? String) ?? "").hasSuffix("tracked.txt"))
        }
        XCTAssertNotNil(opened, "opening tracked.txt should route through the editor opener")
        attachScreenshot("git-review")
    }

    /// P6a+ intra-line emphasis: a partial single-line change must yield >=1
    /// emphasis span in the selected diff (asserted via the gitReview dump, which
    /// reports span counts only — never text).
    func testIntraLineEmphasisSpansReported() {
        let tmp = NSTemporaryDirectory()
        let selectPath = (tmp as NSString).appendingPathComponent("xtty-git-emph-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(atPath: selectPath) }

        let app = launchConfigured(
            config: "",
            extraEnv: ["XTTY_TEST_GIT_SELECT": selectPath],
            extraArgs: ["-UITestGitReview"]
        )
        guard StateDumpReader.waitForState(timeout: 10) != nil else {
            attachScreenshot("no-state-dump (Release?)"); return
        }
        _ = GridDumpReader.waitForNonEmpty(timeout: 5)
        type("true", into: app)
        guard waitForCaptureActive(timeout: 8) else {
            // Capability-absent arm: no OSC 7 cwd → the panel never surfaces the repo —
            // assert the crisp negative rather than passing vacuously (D4).
            assertSemanticCaptureInactive("git-review-emphasis"); return
        }

        // Commit a line, then change *part* of it (a single-line substring edit).
        let dir = "xtty-emphtest-\(UUID().uuidString.prefix(8))"
        type("cd ~ && rm -rf \(dir) && mkdir \(dir) && cd \(dir) && git init -q && " +
             "printf 'hello world\\n' > note.txt && git add note.txt && " +
             "git -c user.email=t@e -c user.name=t commit -qm init && " +
             "printf 'hello there\\n' > note.txt && true",
             into: app)

        guard StateDumpReader.waitForState(timeout: 20, where: {
            let gr = ($0["gitReview"] as? [String: Any]) ?? [:]
            let files = (gr["changedFiles"] as? [[String: Any]]) ?? []
            return (gr["isRepo"] as? Bool) == true
                && files.contains { ($0["path"] as? String) == "note.txt" }
        }) != nil else {
            attachScreenshot("emphasis: repo never surfaced"); return
        }

        // Select note.txt → its diff should report >=1 intra-line emphasis span
        // (the "world" → "there" token on the single changed line).
        try? "note.txt".write(toFile: selectPath, atomically: true, encoding: .utf8)
        let emphasized = StateDumpReader.waitForState(timeout: 10) {
            let gr = ($0["gitReview"] as? [String: Any]) ?? [:]
            let sel = gr["selectedDiff"] as? [String: Any]
            return (sel?["path"] as? String) == "note.txt"
                && ((sel?["emphasisSpans"] as? Int) ?? 0) >= 1
        }
        StateDumpReader.attach(self, name: "git-review-emphasis")
        XCTAssertNotNil(emphasized, "a single-line substring change should produce intra-line emphasis spans")
    }

    /// P6b: the `git-review-layout = tree` config default is reported by the state
    /// dump as the active list layout. Layout is config-seeded at window creation,
    /// independent of repo state, so this needs no injected shell.
    func testConfiguredTreeLayoutIsReported() {
        _ = launchConfigured(config: "git-review-layout = tree", extraArgs: ["-UITestGitReview"])
        guard StateDumpReader.waitForState(timeout: 10) != nil else {
            attachScreenshot("no-state-dump (Release?)"); return
        }
        let state = StateDumpReader.waitForState(timeout: 5) {
            let gr = ($0["gitReview"] as? [String: Any]) ?? [:]
            return (gr["layout"] as? String) == "tree"
        }
        StateDumpReader.attach(self, name: "git-review-tree-layout")
        XCTAssertNotNil(state, "git-review-layout = tree should be reported as the tree layout in the dump")
    }

    /// add-git-diff-wrap-toggle D5: the configured `git-review-diff-wrap`
    /// default is reported, the **real** `gitReview.wrapToggle` button flips it
    /// (button→`setDiffWrap` wiring, not a DEBUG hook), and the DEBUG diff
    /// layout-geometry signals confirm each mode's actual rendered layout for a
    /// diff line longer than the panel (catches a width-collapse regression).
    func testConfiguredNoWrapModeTogglesAndGeometryMatchesEachMode() {
        let tmp = NSTemporaryDirectory()
        let selectPath = (tmp as NSString).appendingPathComponent("xtty-git-wrap-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(atPath: selectPath) }

        let app = launchConfigured(
            config: "git-review-diff-wrap = nowrap",
            extraEnv: ["XTTY_TEST_GIT_SELECT": selectPath],
            extraArgs: ["-UITestGitReview"]
        )
        guard StateDumpReader.waitForState(timeout: 10) != nil else {
            attachScreenshot("no-state-dump (Release?)"); return
        }
        _ = GridDumpReader.waitForNonEmpty(timeout: 5)
        type("true", into: app)
        guard waitForCaptureActive(timeout: 8) else {
            // Capability-absent arm: no OSC 7 cwd → the panel never surfaces the repo —
            // assert the crisp negative rather than passing vacuously (D4).
            assertSemanticCaptureInactive("git-review-wrap"); return
        }

        // A tracked file whose one changed line is far longer than the ~280pt
        // panel, so wrap/no-wrap produce visibly different (assertable) geometry.
        let dir = "xtty-wraptest-\(UUID().uuidString.prefix(8))"
        let longLine = "This line is deliberately padded with a lot of extra words so it " +
            "definitely overflows a two hundred eighty point wide git-review panel column."
        type("cd ~ && rm -rf \(dir) && mkdir \(dir) && cd \(dir) && git init -q && " +
             "printf 'short\\n' > long.txt && git add long.txt && " +
             "git -c user.email=t@e -c user.name=t commit -qm init && " +
             "printf '\(longLine)\\n' > long.txt && true",
             into: app)

        guard StateDumpReader.waitForState(timeout: 20, where: {
            let gr = ($0["gitReview"] as? [String: Any]) ?? [:]
            let files = (gr["changedFiles"] as? [[String: Any]]) ?? []
            return (gr["isRepo"] as? Bool) == true
                && files.contains { ($0["path"] as? String) == "long.txt" }
        }) != nil else {
            attachScreenshot("wrap-toggle: repo never surfaced"); return
        }

        // Select long.txt → the configured `nowrap` default should be reported,
        // and the long line should overflow the panel horizontally. The geometry
        // signal lands on a later async SwiftUI layout pass than `selectedDiff`/
        // `diffWrap` (`onGeometryChange`), so wait on the field being asserted —
        // not an earlier-arriving one — or a stale (still-default) dump can pass
        // the predicate before the real measurement lands.
        try? "long.txt".write(toFile: selectPath, atomically: true, encoding: .utf8)
        let noWrapState = StateDumpReader.waitForState(timeout: 10) {
            let gr = ($0["gitReview"] as? [String: Any]) ?? [:]
            let sel = gr["selectedDiff"] as? [String: Any]
            return (sel?["path"] as? String) == "long.txt"
                && (gr["diffWrap"] as? String) == "nowrap"
                && (gr["diffContentOverflows"] as? Bool) == true
        }
        StateDumpReader.attach(self, name: "git-review-wrap-nowrap")
        guard let noWrapState else {
            attachScreenshot("wrap-toggle: nowrap default/overflow never reported"); return
        }
        let noWrapGr = gitReview(noWrapState)
        XCTAssertEqual(noWrapGr["diffWrap"] as? String, "nowrap",
                       "the configured git-review-diff-wrap default should be reported")
        XCTAssertEqual(noWrapGr["diffContentOverflows"] as? Bool, true,
                       "no-wrap with a line longer than the panel should overflow horizontally")

        // Drive the REAL in-panel control (not a debug hook) — proves the
        // button→setDiffWrap wiring end-to-end.
        let toggle = app.buttons["gitReview.wrapToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10), "the wrap-toggle button should exist once a diff is shown")
        toggle.click()

        let wrapState = StateDumpReader.waitForState(timeout: 10) {
            let gr = ($0["gitReview"] as? [String: Any]) ?? [:]
            return (gr["diffWrap"] as? String) == "wrap"
                && (gr["diffFillsWidth"] as? Bool) == true
                && (gr["diffContentOverflows"] as? Bool) == false
        }
        StateDumpReader.attach(self, name: "git-review-wrap-wrap")
        guard let wrapState else {
            attachScreenshot("wrap-toggle: real control never flipped diffWrap/geometry"); return
        }
        let wrapGr = gitReview(wrapState)
        XCTAssertEqual(wrapGr["diffWrap"] as? String, "wrap",
                       "tapping the real wrap-toggle button should flip the store's diffWrap")
        XCTAssertEqual(wrapGr["diffFillsWidth"] as? Bool, true,
                       "wrap mode should fill the panel width for the long line")
        XCTAssertEqual(wrapGr["diffContentOverflows"] as? Bool, false,
                       "wrap mode should not need horizontal scroll")
    }

    func testNonRepositoryShowsEmptyState() {
        let app = launchConfigured(config: "", extraArgs: ["-UITestGitReview"])
        guard StateDumpReader.waitForState(timeout: 10) != nil else {
            attachScreenshot("no-state-dump (Release?)"); return
        }
        _ = GridDumpReader.waitForNonEmpty(timeout: 5)
        type("true", into: app)
        guard waitForCaptureActive(timeout: 8) else {
            // Capability-absent arm: the git panel keys off the OSC 7 live cwd, which
            // a non-injecting shell never reports — assert the crisp negative (no
            // capture) rather than passing vacuously (split-shell-dependent-testplan D4).
            assertSemanticCaptureInactive("git-review"); return
        }

        // A guaranteed-fresh, non-repo directory.
        let dir = "xtty-norepo-\(UUID().uuidString.prefix(8))"
        type("cd ~ && rm -rf \(dir) && mkdir \(dir) && cd \(dir) && true", into: app)

        let state = StateDumpReader.waitForState(timeout: 15) {
            let gr = ($0["gitReview"] as? [String: Any]) ?? [:]
            // Wait until the panel has refreshed for this directory.
            return (gr["isRepo"] as? Bool) == false && (gr["isRemote"] as? Bool) == false
                && ($0["currentDirectory"] as? String)?.hasSuffix(dir) == true
        }
        StateDumpReader.attach(self, name: "git-review-nonrepo")
        guard let state else {
            attachScreenshot("git-review: non-repo state never surfaced"); return
        }
        XCTAssertEqual((gitReview(state)["isRepo"] as? Bool), false,
                       "a non-repository directory should show the empty (not-a-repo) state")
    }
}
