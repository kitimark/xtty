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
        let selectedDiff = gitReview(selected)["selectedDiff"] as? [String: Any]
        XCTAssertEqual(selectedDiff?["truncated"] as? Bool, false,
                       "an ordinary small diff must remain complete on the bounded producer path")
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

    /// fix-large-diff-memory-bound: exercise both independent producer cutoff
    /// shapes with the production limits through real Git, then drive the fixed,
    /// always-reachable truncated-preview button. Publication happens only after
    /// GitRunner has reaped its child; the exact-PID observation checks that
    /// lifecycle boundary. Each shape gets a fresh app/controller lifecycle so a
    /// periodic refresh from the first selection cannot overwrite the second.
    func testLargeDiffPreviewBoundsManyLinesAndSingleLine() {
        let tmp = NSTemporaryDirectory()
        let fixtures = [
            (
                path: "many.txt",
                generate: "awk 'BEGIN { for (i=0; i<6000; i++) print \"changed-\" i }' > many.txt"
            ),
            (
                path: "long.txt",
                generate: "awk 'BEGIN { for (i=0; i<20000; i++) printf \"x\"; printf \"\\n\" }' > long.txt"
            ),
        ]

        for fixture in fixtures {
            let path = fixture.path
            let selectPath = (tmp as NSString)
                .appendingPathComponent("xtty-git-large-select-\(UUID().uuidString)")
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
                assertSemanticCaptureInactive("git-review-large-diff"); return
            }

            let dir = "xtty-largediff-\(UUID().uuidString.prefix(8))"
            type("cd ~ && rm -rf \(dir) && mkdir \(dir) && cd \(dir) && git init -q && " +
                 "printf 'base\\n' > \(path) && git add -- \(path) && " +
                 "git -c user.email=t@e -c user.name=t commit -qm init && " +
                 "\(fixture.generate) && true",
                 into: app)

            guard StateDumpReader.waitForState(timeout: 20, where: {
                let gr = ($0["gitReview"] as? [String: Any]) ?? [:]
                let files = (gr["changedFiles"] as? [[String: Any]]) ?? []
                return (gr["isRepo"] as? Bool) == true
                    && files.contains { ($0["path"] as? String) == path }
            }) != nil else {
                attachScreenshot("large-diff: \(path) repo never surfaced")
                XCTFail("the \(path) fixture never surfaced in Git review"); return
            }

            let started = Date()
            try? path.write(toFile: selectPath, atomically: true, encoding: .utf8)
            guard StateDumpReader.waitForState(timeout: 10, where: {
                let gr = ($0["gitReview"] as? [String: Any]) ?? [:]
                let selected = gr["selectedDiff"] as? [String: Any]
                return (selected?["path"] as? String) == path
                    && (selected?["truncated"] as? Bool) == true
            }) != nil else {
                attachScreenshot("large-diff: \(path) never truncated")
                XCTFail("\(path) should publish a truncated preview within the bounded timeout")
                return
            }
            XCTAssertLessThan(Date().timeIntervalSince(started), 10,
                              "\(path) should not wait for unread Git output")

            let escape = app.buttons["gitReview.truncatedOpen"]
            XCTAssertTrue(escape.waitForExistence(timeout: 5),
                          "a truncated \(path) preview must expose open-in-editor")
            escape.click()
            let opened = StateDumpReader.waitForState(timeout: 5) {
                let link = $0["lastLinkOpen"] as? [String: Any]
                return (link?["action"] as? String) == "opened"
                    && (((link?["path"] as? String) ?? "").hasSuffix(path))
            }
            XCTAssertNotNil(opened, "the real truncated-preview button should route \(path) to the editor opener")

            let reaped = StateDumpReader.waitForState(timeout: 5) {
                let gr = ($0["gitReview"] as? [String: Any]) ?? [:]
                let process = gr["previewProcess"] as? [String: Any]
                return (process?["path"] as? String) == path
                    && ((process?["cutoffReason"] as? String) ?? "").isEmpty == false
                    && (process?["reaped"] as? Bool) == true
                    && (process?["absentAfterReap"] as? Bool) == true
            }
            XCTAssertNotNil(
                reaped,
                "the exact Git preview PID must be absent after reap before \(path) publication"
            )

            StateDumpReader.attach(self, name: "git-review-large-diff-\(path)")
            app.terminate()
            XCTAssertTrue(app.wait(for: .notRunning, timeout: 5),
                          "\(path)'s app must terminate before the next fixture launches")
        }
    }

    /// `--no-ext-diff` alone still permits a configured textconv. The preview
    /// must suppress that converter and retain Git's binary-summary behavior.
    func testBinaryPreviewDoesNotExecuteConfiguredTextconv() {
        let tmp = NSTemporaryDirectory()
        let selectPath = (tmp as NSString)
            .appendingPathComponent("xtty-git-textconv-select-\(UUID().uuidString)")
        let sentinelPath = (tmp as NSString)
            .appendingPathComponent("xtty-git-textconv-sentinel-\(UUID().uuidString)")
        addTeardownBlock {
            try? FileManager.default.removeItem(atPath: selectPath)
            try? FileManager.default.removeItem(atPath: sentinelPath)
        }

        let app = launchConfigured(
            config: "",
            extraEnv: [
                "XTTY_TEST_GIT_SELECT": selectPath,
                "XTTY_TEXTCONV_SENTINEL": sentinelPath,
            ],
            extraArgs: ["-UITestGitReview"]
        )
        guard StateDumpReader.waitForState(timeout: 10) != nil else {
            attachScreenshot("no-state-dump (Release?)"); return
        }
        _ = GridDumpReader.waitForNonEmpty(timeout: 5)
        type("true", into: app)
        guard waitForCaptureActive(timeout: 8) else {
            assertSemanticCaptureInactive("git-review-textconv"); return
        }

        let dir = "xtty-textconv-\(UUID().uuidString.prefix(8))"
        type("cd ~ && rm -rf \(dir) && mkdir \(dir) && cd \(dir) && git init -q && " +
             "printf '*.bin diff=xtty\\n' > .gitattributes && printf 'base\\000' > binary.bin && " +
             "git add .gitattributes binary.bin && " +
             "git -c user.email=t@e -c user.name=t commit -qm init && " +
             "printf '#!/bin/sh\\nprintf ran > \"$XTTY_TEXTCONV_SENTINEL\"\\ncat \"$1\"\\n' > converter.sh && " +
             "chmod +x converter.sh && git config diff.xtty.textconv \"$PWD/converter.sh\" && " +
             "printf 'changed\\000' > binary.bin && true",
             into: app)

        guard StateDumpReader.waitForState(timeout: 20, where: {
            let gr = ($0["gitReview"] as? [String: Any]) ?? [:]
            let files = (gr["changedFiles"] as? [[String: Any]]) ?? []
            return (gr["isRepo"] as? Bool) == true
                && files.contains { ($0["path"] as? String) == "binary.bin" }
        }) != nil else {
            attachScreenshot("textconv: repo never surfaced")
            XCTFail("the textconv fixture never surfaced in Git review"); return
        }

        try? "binary.bin".write(toFile: selectPath, atomically: true, encoding: .utf8)
        let binary = StateDumpReader.waitForState(timeout: 10) {
            let gr = ($0["gitReview"] as? [String: Any]) ?? [:]
            let selected = gr["selectedDiff"] as? [String: Any]
            return (selected?["path"] as? String) == "binary.bin"
                && (selected?["isBinary"] as? Bool) == true
        }
        XCTAssertNotNil(binary, "binary.bin should retain Git's binary-summary preview")
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        XCTAssertFalse(FileManager.default.fileExists(atPath: sentinelPath),
                       "the configured textconv must not execute during status or preview")
        StateDumpReader.attach(self, name: "git-review-textconv")
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

        // Two tracked files: short.txt's changed line stays well within the
        // ~280pt panel (a negative control — Codex Pass B: an earlier padding
        // bug made EVERY no-wrap row overflow by the row's own horizontal
        // insets, so `diffContentOverflows` was tautologically true regardless
        // of content length); long.txt's line is far longer than the panel.
        let dir = "xtty-wraptest-\(UUID().uuidString.prefix(8))"
        let longLine = "This line is deliberately padded with a lot of extra words so it " +
            "definitely overflows a two hundred eighty point wide git-review panel column."
        type("cd ~ && rm -rf \(dir) && mkdir \(dir) && cd \(dir) && git init -q && " +
             "printf 'short\\n' > short.txt && printf 'short\\n' > long.txt && " +
             "git add short.txt long.txt && " +
             "git -c user.email=t@e -c user.name=t commit -qm init && " +
             "printf 'changed\\n' > short.txt && printf '\(longLine)\\n' > long.txt && true",
             into: app)

        guard StateDumpReader.waitForState(timeout: 20, where: {
            let gr = ($0["gitReview"] as? [String: Any]) ?? [:]
            let files = (gr["changedFiles"] as? [[String: Any]]) ?? []
            return (gr["isRepo"] as? Bool) == true
                && files.contains { ($0["path"] as? String) == "long.txt" }
                && files.contains { ($0["path"] as? String) == "short.txt" }
        }) != nil else {
            // Capture is confirmed active (past the guard above) — a missing
            // repo here is a real subject-behavior failure, not a capability
            // gap, so this MUST hard-fail rather than silently pass (Codex
            // Pass B round 2, high: an earlier version returned without
            // XCTFail, so a genuine regression could go green).
            attachScreenshot("wrap-toggle: repo never surfaced")
            XCTFail("the git-review panel never surfaced the test repo's changed files"); return
        }

        // Select short.txt first (still in the configured `nowrap` mode) →
        // its short line must NOT overflow — the negative control for the
        // padding-order bug above. Also require `diffFillsWidth == true`:
        // `select` resets both geometry booleans to `false` before the real
        // measurement lands, and `false` is ALSO the expected `overflows`
        // value here — so waiting on `overflows == false` alone can pass on
        // the reset default rather than a genuine measurement (Fable Pass C
        // round 2, medium). A real floored short row measures
        // `fillsWidth == true`, which the reset default never satisfies.
        try? "short.txt".write(toFile: selectPath, atomically: true, encoding: .utf8)
        guard let shortState = StateDumpReader.waitForState(timeout: 10, where: {
            let gr = ($0["gitReview"] as? [String: Any]) ?? [:]
            let sel = gr["selectedDiff"] as? [String: Any]
            return (sel?["path"] as? String) == "short.txt"
                && (gr["diffWrap"] as? String) == "nowrap"
                && (gr["diffFillsWidth"] as? Bool) == true
                && (gr["diffContentOverflows"] as? Bool) == false
        }) else {
            attachScreenshot("wrap-toggle: short-line negative control never reported")
            XCTFail("no-wrap should measure a short line as filling (not overflowing) the panel"); return
        }
        StateDumpReader.attach(self, name: "git-review-wrap-nowrap-short")
        let shortGr = gitReview(shortState)
        XCTAssertEqual(shortGr["diffFillsWidth"] as? Bool, true,
                       "no-wrap with a line well within the panel must fill it (proves a real measurement landed, not the reset default)")
        XCTAssertEqual(shortGr["diffContentOverflows"] as? Bool, false,
                       "no-wrap with a line well within the panel must not overflow (regression guard for the padding-order bug)")

        // Select long.txt → the configured `nowrap` default should be reported,
        // and the long line should overflow the panel horizontally. The geometry
        // signal lands on a later async SwiftUI layout pass than `selectedDiff`/
        // `diffWrap` (`onGeometryChange`), so wait on the field being asserted —
        // not an earlier-arriving one — or a stale (still-default) dump can pass
        // the predicate before the real measurement lands.
        try? "long.txt".write(toFile: selectPath, atomically: true, encoding: .utf8)
        guard let noWrapState = StateDumpReader.waitForState(timeout: 10, where: {
            let gr = ($0["gitReview"] as? [String: Any]) ?? [:]
            let sel = gr["selectedDiff"] as? [String: Any]
            return (sel?["path"] as? String) == "long.txt"
                && (gr["diffWrap"] as? String) == "nowrap"
                && (gr["diffContentOverflows"] as? Bool) == true
        }) else {
            attachScreenshot("wrap-toggle: nowrap default/overflow never reported")
            XCTFail("no-wrap should measure the long line as overflowing the panel"); return
        }
        StateDumpReader.attach(self, name: "git-review-wrap-nowrap")
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

        guard let wrapState = StateDumpReader.waitForState(timeout: 10, where: {
            let gr = ($0["gitReview"] as? [String: Any]) ?? [:]
            return (gr["diffWrap"] as? String) == "wrap"
                && (gr["diffFillsWidth"] as? Bool) == true
                && (gr["diffContentOverflows"] as? Bool) == false
        }) else {
            attachScreenshot("wrap-toggle: real control never flipped diffWrap/geometry")
            XCTFail("tapping the real wrap-toggle button should flip diffWrap and the rendered geometry"); return
        }
        StateDumpReader.attach(self, name: "git-review-wrap-wrap")
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
