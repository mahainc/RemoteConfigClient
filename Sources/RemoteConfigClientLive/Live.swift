
import Dependencies
import RemoteConfigClient

extension RemoteConfigClient: DependencyKey {
    public static var liveValue: Self {
		let actor = RemoteConfigActor()
        return RemoteConfigClient(
            adConfigV2: {
                try await actor.getAdConfigV2()
            },
            adConfigV2Updates: {
                actor.adConfigV2Updates()
            },
            adConfig: {
                try await actor.getAdConfig()
            },
            adConfigUpdates: {
                actor.adConfigUpdates()
            },
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
            }
        )
    }
}
