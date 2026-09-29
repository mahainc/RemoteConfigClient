// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

/// The `Funnel` trait's name, shared by its declaration below and by every product
/// condition that gates on it. The matching `#if Funnel` in the conformer cannot
/// reference this — a compiler condition is not a Swift expression — but these two
/// manifest-level uses can, and a typo in either would silently stop gating.
let funnelTrait = "Funnel"

/// Every target in this package builds on the same dependency trio; the Live
/// target adds Firebase on top, plus FunnelClient when the `Funnel` trait is on.
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
    // The funnel conformer is opt-in. A consumer that only wants a Remote Config
    // wrapper should not pay for FunnelClient — and the packages behind it, LogClient
    // and flow-kit — in its dependency graph. `#if canImport(FunnelClient)` cannot do
    // this: it is evaluated after resolution, so the dependency is already fetched and
    // built by the time the compiler sees it. A trait gates the edge itself.
    //
    // Off by default, so adding this package never widens a graph by surprise:
    //   .package(url: "…/RemoteConfigClient.git", from: "2.2.0")                  // no funnel
    //   .package(url: "…/RemoteConfigClient.git", from: "2.2.0", traits: ["Funnel"])
    traits: [
        .default(enabledTraits: []),
        Trait(
            name: funnelTrait,
            description: "Conform RemoteConfigClient to FunnelClient's Config port."
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-dependencies.git", from: "1.9.0"),
        .package(url: "https://github.com/pointfreeco/swift-case-paths.git", from: "1.5.0"),
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "12.13.0"),
        // Reached only through the `Funnel` trait. `RemoteConfigClient+Funnel.swift`
        // conforms the client to FunnelClient's `Config.Providing` port, which moves in
        // major versions — hence the 9.x floor rather than a looser range.
        .package(url: "https://github.com/mahainc/FunnelClient.git", from: "9.0.0"),
    ],
    targets: [
        .target(
            name: "RemoteConfigClient",
            dependencies: sharedDependencies
        ),
        // FirebaseRemoteConfig is unconditional — it is what this package is for.
        // FunnelClient rides the `Funnel` trait, and is the only target dependency here
        // that a consumer can decline.
        .target(
            name: "RemoteConfigClientLive",
            dependencies: sharedDependencies + [
                .product(name: "FirebaseRemoteConfig", package: "firebase-ios-sdk"),
                .product(
                    name: "FunnelClient",
                    package: "FunnelClient",
                    condition: .when(traits: [funnelTrait])
                ),
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
