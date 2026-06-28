import XCTest
@testable import XttyCore

@MainActor
final class GitReviewStoreTests: XCTestCase {
    private func sampleSnapshot(files: [GitChangedFile]) -> GitReviewSnapshot {
        GitReviewSnapshot(isRepo: true, repoRoot: "/repo", branch: "main", files: files)
    }

    func testApplyBumpsRevisionAndRefreshCount() {
        let store = GitReviewStore()
        XCTAssertEqual(store.refreshCount, 0)
        store.apply(sampleSnapshot(files: [GitChangedFile(path: "a.txt", status: .modified)]))
        XCTAssertEqual(store.refreshCount, 1)
        XCTAssertEqual(store.revision, 1)
        XCTAssertTrue(store.snapshot.isRepo)
        XCTAssertEqual(store.snapshot.files.map(\.path), ["a.txt"])
    }

    func testSelectionStoresDiff() {
        let store = GitReviewStore()
        store.apply(sampleSnapshot(files: [GitChangedFile(path: "a.txt", status: .modified)]))
        store.select(path: "a.txt", diff: .binary)
        XCTAssertEqual(store.snapshot.selectedPath, "a.txt")
        XCTAssertEqual(store.snapshot.selectedDiff, .binary)
    }

    func testApplyPreservesSelectionWhenFileStillPresent() {
        let store = GitReviewStore()
        store.apply(sampleSnapshot(files: [GitChangedFile(path: "a.txt", status: .modified)]))
        store.select(path: "a.txt", diff: .empty)
        // A refresh that still contains a.txt keeps the selection (diff cleared
        // so the runner reloads it).
        store.apply(sampleSnapshot(files: [
            GitChangedFile(path: "a.txt", status: .modified),
            GitChangedFile(path: "b.txt", status: .added),
        ]))
        XCTAssertEqual(store.snapshot.selectedPath, "a.txt")
        XCTAssertNil(store.snapshot.selectedDiff)
    }

    func testCategoryGroupingHelper() {
        let snap = GitReviewSnapshot(isRepo: true, files: [
            GitChangedFile(path: "m.txt", status: .modified),
            GitChangedFile(path: "u.txt", status: .untracked),
            GitChangedFile(path: "c.txt", status: .conflicted),
        ])
        XCTAssertEqual(snap.files(in: .changes).map(\.path), ["m.txt"])
        XCTAssertEqual(snap.files(in: .untracked).map(\.path), ["u.txt"])
        XCTAssertEqual(snap.files(in: .conflicts).map(\.path), ["c.txt"])
        XCTAssertTrue(snap.hasContent)
    }

    func testRemoteAndUnavailableSnapshotsHaveNoContent() {
        XCTAssertFalse(GitReviewSnapshot.remote.hasContent)
        XCTAssertTrue(GitReviewSnapshot.remote.isRemote)
        XCTAssertTrue(GitReviewSnapshot.unavailable.gitUnavailable)
    }
}

final class DiffContextConfigTests: XCTestCase {
    func testDiffContextDefaultsToThree() {
        let config = XttyConfigLoader.resolve(from: [:])
        XCTAssertEqual(config.diffContext, 3)
    }

    func testDiffContextParsed() {
        let config = XttyConfigLoader.resolve(from: ["diff-context": "8"])
        XCTAssertEqual(config.diffContext, 8)
    }

    func testDiffContextInvalidFallsBackAndWarns() {
        var warned = false
        let config = XttyConfigLoader.resolve(from: ["diff-context": "lots"]) { _ in warned = true }
        XCTAssertEqual(config.diffContext, 3)
        XCTAssertTrue(warned)
    }

    func testDiffContextNegativeFallsBack() {
        let config = XttyConfigLoader.resolve(from: ["diff-context": "-2"])
        XCTAssertEqual(config.diffContext, 3)
    }

    func testDiffContextInheritsThroughProfiles() {
        let text = """
        diff-context = 5

        [profile "work"]
        font-size = 14
        """
        let set = XttyConfigLoader.resolveSet(from: text)
        XCTAssertEqual(set.base.config.diffContext, 5)
        XCTAssertEqual(set.profiles["work"]?.config.diffContext, 5, "profiles inherit base diff-context")
    }
}
