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
    // v2 — read against the `ad_config_v2` Firebase key. Prefer this in new code;
    // it exposes the full schema (cooldowns, session caps, per-format kill switches,
    // experimentId, etc.) without the lossy legacy projection.
    public var adConfigV2: @Sendable () async throws -> AdConfigV2
    public var adConfigV2Updates: @Sendable () -> AsyncStream<AdConfigV2> = { .finished }

    // v1 — legacy shape, preserved for existing call sites via `AdConfigV2.toLegacy()`.
    // Migrate to `adConfigV2` when you need any v2-only field.
    public var adConfig: @Sendable () async throws -> RemoteConfigClient.AdConfig
    public var adConfigUpdates: @Sendable () -> AsyncStream<RemoteConfigClient.AdConfig> = { .finished }

    public var fetchAndActivate: @Sendable () async throws -> Void

    /// Tolerant variant of `fetchAndActivate` — swallows errors and logs in DEBUG.
    /// Use this from splash / app-launch code when you'd rather fall back to the last
    /// known config than surface a user-visible error.
    public var fetchAndActivateOrUseCache: @Sendable () async -> Void = { }

    /// Reads any top-level Remote Config key as a `RemoteValue`. Returns a
    /// zero-valued struct with `source == .static` when the key is absent.
    /// Use the typed accessors (`intValue`, `stringValue`, …) to extract.
    public var value: @Sendable (_ key: String) async -> RemoteValue = { _ in RemoteValue() }
}
