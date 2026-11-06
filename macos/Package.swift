// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "mBAE",
    platforms: [.macOS(.v15)],
    targets: [
        // zlib du système (libz)
        .systemLibrary(name: "CZlib"),
        // Archives BSA / BA2, décompression et traductions, sans interface (testable seul)
        .target(name: "BAECore", dependencies: ["CZlib"]),
        .executableTarget(name: "mBAE", dependencies: ["BAECore"]),
        .testTarget(name: "BAECoreTests", dependencies: ["BAECore"]),
    ],
    swiftLanguageModes: [.v5]
)
