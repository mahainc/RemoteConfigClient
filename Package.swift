// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RemoteConfigClient",
    platforms: [
		.iOS(.v16), .macOS(.v13)
    ],
    products: [
        .singleTargetLibrary("RemoteConfigClient"),
        .singleTargetLibrary("RemoteConfigClientLive"),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture.git", branch: "main"),
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "RemoteConfigClient",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .target(
            name: "RemoteConfigClientLive",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "FirebaseRemoteConfig", package: "firebase-ios-sdk"),
                "RemoteConfigClient"
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
