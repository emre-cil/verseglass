// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Verseglass",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "Verseglass", targets: ["Verseglass"])
    ],
    targets: [
        .target(name: "VerseglassCore", path: "Sources/VerseglassCore"),
        .executableTarget(
            name: "Verseglass",
            dependencies: ["VerseglassCore"],
            path: "Sources/VerseglassApp",
            resources: [.copy("Resources/now_playing_helper.swift")]
        ),
        .testTarget(
            name: "VerseglassTests",
            dependencies: ["VerseglassCore"],
            path: "Tests/VerseglassTests"
        ),
    ]
)
