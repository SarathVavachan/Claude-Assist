// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClaudeAssist",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "ClaudeAssist",
            path: "Sources/ClaudeAssist"
        )
    ]
)
