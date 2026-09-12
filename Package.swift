// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

/// Every target in this package builds on the same dependency trio; the Live
/// target adds Firebase and FunnelClient on top.
let sharedDependencies: [Target.Dependency] = [
    .product(name: "Dependencies", package: "swift-dependencies"),
    .product(name: "DependenciesMacros", package: "swift-dependencies"),
    .product(name: "CasePaths", package: "swift-case-paths"),
]

let package = Package(
    name: "RemoteConfigClient",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .singleTargetLibrary("RemoteConfigClient"),
        .singleTargetLibrary("RemoteConfigClientLive"),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-dependencies.git", from: "1.9.0"),
        .package(url: "https://github.com/pointfreeco/swift-case-paths.git", from: "1.5.0"),
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "12.13.0"),
        // Pinned exactly, unlike the rest: RemoteConfigFunnelProvider conforms to
        // FunnelClient's Config.Providing port, which moves in major versions.
        .package(url: "https://github.com/mahainc/FunnelClient.git", exact: "7.0.0"),
    ],
    targets: [
        .target(
            name: "RemoteConfigClient",
            dependencies: sharedDependencies
        ),
        .target(
            name: "RemoteConfigClientLive",
            dependencies: sharedDependencies + [
                .product(name: "FirebaseRemoteConfig", package: "firebase-ios-sdk"),
                .product(name: "FunnelClient", package: "FunnelClient"),
                "RemoteConfigClient",
            ]
        ),
        .testTarget(
            name: "RemoteConfigClientTests",
            dependencies: ["RemoteConfigClient"]
        ),
    ]
)

extension Product {
    static func singleTargetLibrary(_ name: String) -> Product {
        .library(name: name, targets: [name])
    }
}
