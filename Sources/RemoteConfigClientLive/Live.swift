
import Dependencies
@preconcurrency import FirebaseRemoteConfig
import RemoteConfigClient

extension RemoteConfigClient: DependencyKey {
    /// Default live instance used by `@Dependency(\.remoteConfigClient)`. Apps
    /// that need to override fetch interval, defaults plist name, or disable
    /// the live-update listener should use `live(configuration:)` instead.
    public static var liveValue: Self {
        live()
    }

    /// Builds a live `RemoteConfigClient` against Firebase Remote Config using
    /// the given `Configuration`. Call once at app startup if you need to
    /// override defaults (e.g. `minimumFetchInterval: 0` in development, or
    /// `defaultsPlistName: nil` for apps that don't ship a defaults plist).
    public static func live(configuration: Configuration = .default) -> Self {
        let actor = RemoteConfigActor(configuration: configuration)
        return RemoteConfigClient(
            fetchAndActivate: {
                try await actor.fetchAndActivate()
            },
            fetchAndActivateOrUseCache: {
                do {
                    try await actor.fetchAndActivate()
                } catch {
                    #if DEBUG
                    print("[RemoteConfigClient] fetchAndActivate failed: \(error.localizedDescription); using cached/default values")
                    #endif
                }
            },
            value: { key in
                RemoteConfigActor.readValue(forKey: key)
            },
            valueUpdates: { key in
                actor.valueUpdates(forKey: key)
            }
        )
    }
}
