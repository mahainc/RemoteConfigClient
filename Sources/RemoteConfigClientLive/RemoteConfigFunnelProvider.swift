import Dependencies
import Foundation
import FunnelClient
import RemoteConfigClient

public enum RemoteConfigFunnelProviderError: Error, CustomStringConvertible {
    case missingRequiredKeys([String])

    public var description: String {
        switch self {
            case .missingRequiredKeys(let keys):
                return "Missing Remote Config keys: \(keys.joined(separator: ", "))"
        }
    }
}

/// Serves `FunnelClient.Config.Providing` out of `RemoteConfigClient`, holding
/// the funnel's own policy — which keys it cannot start without, and how fresh
/// the fetch has to be — so the generic client stays free of funnel vocabulary.
public final class RemoteConfigFunnelProvider: FunnelClient.Config.Providing {
    /// What the funnel ships expecting. Overridable so a host with a different
    /// funnel schema doesn't have to fork the provider.
    public static let defaultRequiredKeys = ["iap_config", "ad_config"]

    /// A snapshot missing any of these fails outright rather than handing the
    /// funnel a partial config it would misread as "nothing is configured".
    public let requiredKeys: [String]

    /// Forwarded to `RemoteConfigClient.fetchAndSnapshot` for this call only.
    /// Defaults to 0 because the funnel is expected to read fresh config every
    /// launch, not up to an hour of cache.
    public let minimumFetchInterval: TimeInterval

    public init(
        requiredKeys: [String] = RemoteConfigFunnelProvider.defaultRequiredKeys,
        minimumFetchInterval: TimeInterval = 0
    ) {
        self.requiredKeys = requiredKeys
        self.minimumFetchInterval = minimumFetchInterval
    }

    public func snapshot() async throws -> [String: String] {
        @Dependency(\.remoteConfigClient) var remoteConfigClient
        let values = try await remoteConfigClient.fetchAndSnapshot(minimumFetchInterval: minimumFetchInterval)
        let missing = requiredKeys.filter { !Self.contains(configKey: $0, in: values) }
        guard missing.isEmpty else {
            throw RemoteConfigFunnelProviderError.missingRequiredKeys(missing)
        }
        return values
    }

    /// The funnel is configured per environment, so `ad_config_dev` satisfies a
    /// requirement for `ad_config` — the suffix names the environment, not a
    /// different key.
    private static func contains(
        configKey base: String,
        in values: [String: String]
    ) -> Bool {
        values.keys.contains { key in
            key == base || key.hasPrefix("\(base)_")
        }
    }
}
