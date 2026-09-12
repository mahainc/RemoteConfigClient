import Dependencies
import Foundation
import FunnelClient
import RemoteConfigClient

public enum RemoteConfigFunnelError: Error, CustomStringConvertible {
    case missingRequiredKeys([String])

    public var description: String {
        switch self {
            case .missingRequiredKeys(let keys):
                return "Missing Remote Config keys: \(keys.joined(separator: ", "))"
        }
    }
}

/// Serves `FunnelClient.Config.Providing` from the client itself, so a host reaches it
/// through the dependency key it already has — `@Dependency(\.remoteConfigClient)`.
///
/// The funnel's policy travels in ``RemoteConfigClient/FunnelSettings`` rather than being
/// baked in here, which keeps the generic client free of funnel vocabulary while still
/// letting the host override what the funnel refuses to start without.
extension RemoteConfigClient: FunnelClient.Config.Providing {
    public func snapshot() async throws -> [String: String] {
        let settings = funnelSettings()
        let values = try await fetchAndSnapshot(minimumFetchInterval: settings.minimumFetchInterval)
        let missing = settings.requiredKeys.filter { !Self.contains(configKey: $0, in: values) }
        guard missing.isEmpty else {
            throw RemoteConfigFunnelError.missingRequiredKeys(missing)
        }
        return values
    }

    /// The funnel is configured per environment, so `ad_config_dev` satisfies a requirement
    /// for `ad_config` — the suffix names the environment, not a different key.
    private static func contains(
        configKey base: String,
        in values: [String: String]
    ) -> Bool {
        values.keys.contains { key in
            key == base || key.hasPrefix("\(base)_")
        }
    }
}
