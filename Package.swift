// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Remote2Prompt",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "Remote2PromptCore", targets: ["Remote2PromptCore"])
    ],
    targets: [
        .target(name: "Remote2PromptCore"),
        // CLT does not include XCTest. Keep checks runnable with the same toolchain as the app.
        .executableTarget(
            name: "Remote2PromptChecks",
            dependencies: ["Remote2PromptCore"],
            path: "Tests/Remote2PromptChecks"
        )
    ]
)
