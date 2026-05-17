
import Dependencies

extension DependencyValues {
	public var remoteConfigClient: RemoteConfigClient {
		get { self[RemoteConfigClient.self] }
		set { self[RemoteConfigClient.self] = newValue }
	}
}

extension RemoteConfigClient: TestDependencyKey {
    public static var testValue: Self {
        Self()
    }

    public static var previewValue: Self {
        Self()
    }
}

extension RemoteConfigClient {
    public static let happyPath: Self = {
        return .init(
            adConfigV2: {
                AdConfigV2()
            },
            adConfigV2Updates: {
                AsyncStream { continuation in
                    continuation.yield(AdConfigV2())
                    continuation.finish()
                }
            },
            adConfig: {
                RemoteConfigClient.AdConfig()
            },
            adConfigUpdates: {
                AsyncStream { continuation in
                    continuation.yield(RemoteConfigClient.AdConfig())
                    continuation.finish()
                }
            },
            fetchAndActivate: {
                // No-op in happy path.
            },
            fetchAndActivateOrUseCache: { },
            value: { _ in RemoteValue() }
        )
    }()
}
