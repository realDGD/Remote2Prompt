// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VoiRemote",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "VoiRemote", targets: ["VoiRemote"]),
        .library(name: "VoiRemoteCore", targets: ["VoiRemoteCore"])
    ],
    targets: [
        .target(name: "VoiRemoteCore"),
        .target(name: "VoiRemoteMac", dependencies: ["VoiRemoteCore"]),
        .executableTarget(name: "VoiRemote", dependencies: ["VoiRemoteCore", "VoiRemoteMac"]),
        // CLT does not include XCTest. Keep checks runnable with the same toolchain as the app.
        .executableTarget(
            name: "VoiRemoteChecks",
            dependencies: ["VoiRemoteCore"],
            path: "Tests/VoiRemoteChecks"
        ),
        .executableTarget(name: "VoiRemoteMacChecks", dependencies: ["VoiRemoteCore", "VoiRemoteMac"], path: "Tests/VoiRemoteMacChecks")
    ]
)
