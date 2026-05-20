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
        .package(url: "https://github.com/pointfreeco/swift-dependencies.git", from: "1.9.0"),
        .package(url: "https://github.com/pointfreeco/swift-case-paths.git", from: "1.5.0"),
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "12.13.0"),
    ],
    targets: [
        .target(
            name: "RemoteConfigClient",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesMacros", package: "swift-dependencies"),
                .product(name: "CasePaths", package: "swift-case-paths"),
            ]
        ),
        .target(
            name: "RemoteConfigClientLive",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesMacros", package: "swift-dependencies"),
                .product(name: "CasePaths", package: "swift-case-paths"),
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
