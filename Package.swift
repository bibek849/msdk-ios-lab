// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MSDKIOSLab",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "MSDKIOSCore", targets: ["MSDKIOSCore"]),
        .executable(name: "msdk-ios-replay", targets: ["MSDKIOSReplay"]),
        // Linked by the diagnostic app in apps/ios/ControllerProbe.
        .library(name: "MSDKIOSProbeSupport", targets: ["MSDKIOSProbeSupport"]),
        .library(name: "MSDKIOSAppleTransport", targets: ["MSDKIOSAppleTransport"])
    ],
    targets: [
        .target(name: "MSDKIOSCore"),
        .executableTarget(name: "MSDKIOSReplay", dependencies: ["MSDKIOSCore"]),
        .testTarget(name: "MSDKIOSCoreTests", dependencies: ["MSDKIOSCore"]),
        .target(name: "MSDKIOSProbeSupport", dependencies: ["MSDKIOSCore"]),
        .testTarget(name: "MSDKIOSProbeSupportTests", dependencies: ["MSDKIOSProbeSupport", "MSDKIOSCore"]),
        .target(name: "MSDKIOSAppleTransport", dependencies: ["MSDKIOSProbeSupport", "MSDKIOSCore"]),
        .testTarget(name: "MSDKIOSAppleTransportTests",
                    dependencies: ["MSDKIOSAppleTransport", "MSDKIOSProbeSupport", "MSDKIOSCore"])
    ]
)
