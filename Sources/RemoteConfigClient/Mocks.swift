
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
