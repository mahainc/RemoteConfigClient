// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import DependenciesMacros

/// Type-erased view over a single Remote Config entry. Mirrors Firebase's
/// `RemoteConfigValue` accessors so callers pick the type they need; missing
/// keys return a zero-valued struct with `source == .static`.
public struct RemoteValue: Sendable, Equatable {
    public let stringValue: String
    public let intValue: Int
    public let boolValue: Bool
    public let doubleValue: Double
    public let dataValue: Data
    public let source: Source

    public enum Source: Sendable, Equatable {
        case remote
        case `default`
        case `static`
    }

    public init(
        stringValue: String = "",
        intValue: Int = 0,
        boolValue: Bool = false,
        doubleValue: Double = 0,
        dataValue: Data = Data(),
        source: Source = .static
    ) {
        self.stringValue = stringValue
        self.intValue = intValue
        self.boolValue = boolValue
        self.doubleValue = doubleValue
        self.dataValue = dataValue
        self.source = source
    }
}

@DependencyClient
public struct RemoteConfigClient: Sendable {
    /// Throws when Firebase Remote Config's `fetchAndActivate` callback delivers
    /// an error. Use `fetchAndActivateOrUseCache` from splash / launch code when
    /// you'd rather fall back to the previously-activated values silently.
    public var fetchAndActivate: @Sendable () async throws -> Void

    /// Tolerant variant of `fetchAndActivate` — swallows errors and logs in DEBUG.
    /// Use this from splash / app-launch code when you'd rather fall back to the last
    /// known config than surface a user-visible error.
    public var fetchAndActivateOrUseCache: @Sendable () async -> Void = { }

    /// Reads any top-level Remote Config key as a `RemoteValue`. Returns a
    /// zero-valued struct with `source == .static` when the key is absent.
    /// Use the typed accessors (`intValue`, `stringValue`, …) to extract, or
    /// the `decode(_:as:)` extension to JSON-decode the payload.
    public var value: @Sendable (_ key: String) async -> RemoteValue = { _ in RemoteValue() }

    /// Per-key live stream. Yields the current value on subscribe, then re-emits
    /// every time Firebase activates a change that touches this key. The stream
    /// finishes when the consumer cancels iteration.
    public var valueUpdates: @Sendable (_ key: String) -> AsyncStream<RemoteValue> = { _ in .finished }
}

// MARK: - Configuration

extension RemoteConfigClient {
    /// Tunables for the live actor. Passed once at app startup via
    /// `RemoteConfigClient.live(configuration:)`.
    public struct Configuration: Sendable {
        /// Forwarded to `RemoteConfigSettings.minimumFetchInterval`. Set to 0 in
        /// development for unthrottled fetches; default 3600 matches Firebase's
        /// recommended production cadence.
        public var minimumFetchInterval: TimeInterval

        /// Name (without extension) of a bundled plist to load as defaults via
        /// `setDefaults(fromPlist:)`. `nil` skips the call.
        public var defaultsPlistName: String?

        /// Whether to register `addOnConfigUpdateListener` so live updates fan
        /// out to `valueUpdates` / `decodeUpdates` subscribers. Disable in test
        /// hosts that don't ship Firebase.
        public var enableLiveUpdateListener: Bool

        public init(
            minimumFetchInterval: TimeInterval = 3600,
            defaultsPlistName: String? = "RemoteConfigDefaults",
            enableLiveUpdateListener: Bool = true
        ) {
            self.minimumFetchInterval = minimumFetchInterval
            self.defaultsPlistName = defaultsPlistName
            self.enableLiveUpdateListener = enableLiveUpdateListener
        }

        public static let `default` = Configuration()
    }
}

// MARK: - Generic decode helpers

extension RemoteConfigClient {
    /// Reads `key`'s `stringValue` and JSON-decodes it as `T`. Returns `nil`
    /// when the key is absent, empty, or fails to decode.
    public func decode<T: Decodable & Sendable>(
        _ key: String,
        as type: T.Type = T.self,
        decoder: JSONDecoder = JSONDecoder()
    ) async -> T? {
        let raw = await value(key).stringValue
        guard !raw.isEmpty, let data = raw.data(using: .utf8) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    /// Per-key live stream of successfully-decoded `T`. Emissions that fail to
    /// decode (empty raw, malformed JSON, schema drift) are skipped silently —
    /// subscribers only see clean values. Cancels the underlying `valueUpdates`
    /// task when the consumer stops iterating.
    public func decodeUpdates<T: Decodable & Sendable>(
        _ key: String,
        as type: T.Type = T.self,
        decoder: JSONDecoder = JSONDecoder()
    ) -> AsyncStream<T> {
        AsyncStream { continuation in
            let task = Task {
                for await rv in valueUpdates(key) {
                    let raw = rv.stringValue
                    guard !raw.isEmpty, let data = raw.data(using: .utf8) else { continue }
                    if let decoded = try? decoder.decode(T.self, from: data) {
                        continuation.yield(decoded)
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
