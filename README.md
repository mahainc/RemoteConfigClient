# RemoteConfigClient

A TCA-style dependency client wrapping Firebase Remote Config. Exposes a `RemoteValue` accessor surface plus an `AsyncStream<RemoteValue>` per-key live-update listener.

## Layout

- **`RemoteConfigClient`** — interface: `fetchAndActivate`, `fetchAndActivateOrUseCache`, per-key `value(_:)`, per-key `valueUpdates(_:)`, plus a `RemoteValue` type modeled on Firebase's `RemoteConfigValue` accessors.
- **`RemoteConfigClientLive`** — `FirebaseRemoteConfig` wrapper with an actor-backed listener registry; registers the live `DependencyKey`.

## Installation

```swift
.package(url: "https://github.com/mahainc/RemoteConfigClient.git", from: "0.1.0"),
```

`RemoteConfigClient` on feature targets; `RemoteConfigClientLive` on the app target.

## Configure Firebase

Ensure `FirebaseApp.configure()` runs at app launch (typically in `AppDelegate.application(_:didFinishLaunchingWithOptions:)`). Drop your `GoogleService-Info.plist` into the app target so the Firebase SDK can resolve it.

## Usage

```swift
import RemoteConfigClient
import ComposableArchitecture

@Reducer
struct FeatureFlagsFeature {
    @ObservableState
    struct State {
        var paywallVariant: String = ""
    }

    enum Action {
        case task
        case configActivated
        case paywallVariantChanged(String)
    }

    @Dependency(\.remoteConfigClient) var config

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                return .merge(
                    .run { send in
                        try await config.fetchAndActivate()
                        await send(.configActivated)
                    },
                    .run { send in
                        for await value in config.valueUpdates("paywall_variant") {
                            await send(.paywallVariantChanged(value.stringValue))
                        }
                    }
                )

            case .configActivated:
                let v = await config.value("paywall_variant")
                state.paywallVariant = v.stringValue
                return .none

            case .paywallVariantChanged(let v):
                state.paywallVariant = v
                return .none
            }
        }
    }
}
```

## Testing

`@DependencyClient` generates unimplemented `testValue` defaults; override per call site:

```swift
let store = TestStore(initialState: FeatureFlagsFeature.State()) {
    FeatureFlagsFeature()
} withDependencies: {
    $0.remoteConfigClient.fetchAndActivate = { }
    $0.remoteConfigClient.value = { _ in .init(stringValue: "test", source: .remote) }
}
```

## Dependencies

- `swift-dependencies` from 1.9.0
- `swift-case-paths` from 1.5.0
- `firebase-ios-sdk` (FirebaseRemoteConfig) from 12.13.0

## Platform support

- iOS 17+, macOS 14+

## License

MIT — see [LICENSE](./LICENSE).
