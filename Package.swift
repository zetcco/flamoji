// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "flamoji",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "flamoji",
            resources: [
                .process("emojis.json")
            ]
        ),
    ]
)