// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Remote2Prompt",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Remote2Prompt", targets: ["Remote2Prompt"]),
        .library(name: "Remote2PromptCore", targets: ["Remote2PromptCore"])
    ],
    targets: [
        .target(name: "Remote2PromptCore"),
        .executableTarget(name: "Remote2Prompt", dependencies: ["Remote2PromptCore"]),
        // CLT does not include XCTest. Keep checks runnable with the same toolchain as the app.
        .executableTarget(
            name: "Remote2PromptChecks",
            dependencies: ["Remote2PromptCore"],
            path: "Tests/Remote2PromptChecks"
        )
    ]
)
