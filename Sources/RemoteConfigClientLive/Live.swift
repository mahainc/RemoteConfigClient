
import Dependencies
@preconcurrency import FirebaseRemoteConfig
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
            },
            value: { key in
                let rcValue = RemoteConfig.remoteConfig().configValue(forKey: key)
                let source: RemoteValue.Source = {
                    switch rcValue.source {
                    case .remote:  return .remote
                    case .default: return .default
                    case .static:  return .static
                    @unknown default: return .static
                    }
                }()
                return RemoteValue(
                    stringValue: rcValue.stringValue,
                    intValue: rcValue.numberValue.intValue,
                    boolValue: rcValue.boolValue,
                    doubleValue: rcValue.numberValue.doubleValue,
                    dataValue: rcValue.dataValue,
                    source: source
                )
            }
        )
    }
}
