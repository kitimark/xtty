// swift-tools-version: 6.0
import PackageDescription

// XttyCore — the engine-facing seam.
//
// All xtty logic talks to the terminal engine (SwiftTerm's headless `Terminal`)
// through this module, never to a concrete terminal view. That keeps the render
// layer swappable (staged SwiftTerm adoption: start Level 3, drop to Level 1
// only if measured). See research/04-design/01-stack-sketch.md.
//
// IMPORTANT: XttyCore MUST NOT import the app/UI target or any concrete
// terminal view (e.g. SwiftTerm's `TerminalView`). It may use SwiftTerm's
// headless engine only.
let package = Package(
    name: "XttyCore",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "XttyCore", targets: ["XttyCore"]),
    ],
    dependencies: [
        // SwiftTerm is pinned as a git submodule (external/SwiftTerm @ v1.13.0)
        // with our add-only accessor file dropped in by scripts/bootstrap-swiftterm.sh
        // — the no-fork "patch in repo" mechanism (P4b-2). Run that script once after
        // cloning. See research/03-analysis/swiftterm-fork-vs-patch-strategy.md.
        .package(path: "../external/SwiftTerm"),
    ],
    targets: [
        .target(
            name: "XttyCore",
            dependencies: [
                .product(name: "SwiftTerm", package: "SwiftTerm"),
            ]
        ),
        .testTarget(
            name: "XttyCoreTests",
            dependencies: ["XttyCore"]
        ),
    ]
)
