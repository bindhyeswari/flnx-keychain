// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "keychain-helper",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "keychain-helper",
            path: "Sources",
            linkerSettings: [
                .linkedFramework("Security"),
                .linkedFramework("LocalAuthentication"),
            ]
        )
    ]
)
