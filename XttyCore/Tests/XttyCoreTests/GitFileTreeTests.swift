import XCTest
@testable import XttyCore

/// Unit tests for the P6b directory-tree presentation transform — pure, view-free.
final class GitFileTreeTests: XCTestCase {

    private func file(_ path: String, _ status: GitFileStatus = .modified,
                      added: Int? = nil, removed: Int? = nil) -> GitChangedFile {
        GitChangedFile(path: path, status: status, added: added, removed: removed)
    }

    /// All file-leaf paths in tree order (depth-first), for set/order assertions.
    private func leafPaths(_ nodes: [GitTreeNode]) -> [String] {
        nodes.flatMap { node -> [String] in
            switch node {
            case let .file(f): return [f.path]
            case let .directory(_, _, children): return leafPaths(children)
            }
        }
    }

    func testEmptyInputYieldsEmptyTree() {
        XCTAssertTrue(GitFileTree.build([]).isEmpty)
    }

    func testSingleRootLevelFile() {
        let nodes = GitFileTree.build([file("README.md")])
        XCTAssertEqual(nodes.count, 1)
        guard case let .file(f) = nodes.first else { return XCTFail("expected a file leaf") }
        XCTAssertEqual(f.path, "README.md")
    }

    func testFilesInOneDirectoryGroupUnderIt() {
        let nodes = GitFileTree.build([file("src/b.swift"), file("src/a.swift")])
        XCTAssertEqual(nodes.count, 1)
        guard case let .directory(path, name, children) = nodes.first else {
            return XCTFail("expected a directory node")
        }
        XCTAssertEqual(path, "src")
        XCTAssertEqual(name, "src")
        // Files alphabetical within the directory.
        XCTAssertEqual(leafPaths(children), ["src/a.swift", "src/b.swift"])
    }

    func testDeeplyNestedPath() {
        let nodes = GitFileTree.build([file("app/sub/baz.swift")])
        guard case let .directory(p1, n1, c1) = nodes.first else { return XCTFail("expected app dir") }
        XCTAssertEqual(p1, "app"); XCTAssertEqual(n1, "app")
        guard case let .directory(p2, n2, c2) = c1.first else { return XCTFail("expected app/sub dir") }
        XCTAssertEqual(p2, "app/sub"); XCTAssertEqual(n2, "sub")
        guard case let .file(f) = c2.first else { return XCTFail("expected leaf") }
        XCTAssertEqual(f.path, "app/sub/baz.swift")
    }

    func testDirectoriesBeforeFilesEachAlphabetical() {
        // Two top-level dirs (b, a) plus a root-level file (m) — dirs first, sorted,
        // then files.
        let nodes = GitFileTree.build([file("b/1.txt"), file("a/2.txt"), file("m.txt")])
        let kinds: [String] = nodes.map {
            switch $0 {
            case let .directory(path, _, _): return "d:" + path
            case let .file(f): return "f:" + f.path
            }
        }
        XCTAssertEqual(kinds, ["d:a", "d:b", "f:m.txt"])
    }

    func testFilesSharingPrefixCollapseUnderOneNode() {
        let nodes = GitFileTree.build([file("pkg/x.txt"), file("pkg/y.txt")])
        XCTAssertEqual(nodes.count, 1, "both files share the one 'pkg' directory node")
        XCTAssertEqual(leafPaths(nodes), ["pkg/x.txt", "pkg/y.txt"])
    }

    func testInputSetIsPreservedExactly() {
        let input = ["z.txt", "a/b/c.txt", "a/d.txt", "a/b/a.txt", "root.md"]
        let nodes = GitFileTree.build(input.map { file($0) })
        // Same set, no file added/dropped/duplicated.
        XCTAssertEqual(Set(leafPaths(nodes)), Set(input))
        XCTAssertEqual(leafPaths(nodes).count, input.count)
    }

    func testLeafCarriesItsChangedFileIntact() {
        let nodes = GitFileTree.build([file("dir/app.swift", .added, added: 8, removed: 2)])
        let leaves = leafPaths(nodes)
        XCTAssertEqual(leaves, ["dir/app.swift"])
        guard case let .directory(_, _, children) = nodes.first,
              case let .file(f) = children.first else { return XCTFail("expected dir → file") }
        XCTAssertEqual(f.status, .added)
        XCTAssertEqual(f.added, 8)
        XCTAssertEqual(f.removed, 2)
    }

    func testNodeIdsAreStableAndDistinct() {
        let nodes = GitFileTree.build([file("a/x.txt"), file("a/y.txt"), file("b.txt")])
        // Directory id is prefix-derived; file id is path-derived; both distinct.
        XCTAssertEqual(nodes.first?.id, "d:a")
        guard case let .directory(_, _, children) = nodes.first else { return XCTFail() }
        XCTAssertEqual(children.map(\.id), ["f:a/x.txt", "f:a/y.txt"])
        XCTAssertEqual(nodes.last?.id, "f:b.txt")
    }
}

@MainActor
final class GitReviewLayoutStoreTests: XCTestCase {
    func testSetLayoutFlipsAndBumpsRevision() {
        let store = GitReviewStore()
        XCTAssertEqual(store.layout, .flat)
        let before = store.revision
        store.setLayout(.tree)
        XCTAssertEqual(store.layout, .tree)
        XCTAssertEqual(store.revision, before + 1)
    }

    func testSetLayoutSameValueIsNoOp() {
        let store = GitReviewStore()
        let before = store.revision
        store.setLayout(.flat)   // already flat
        XCTAssertEqual(store.revision, before, "an unchanged layout must not bump revision")
    }
}
