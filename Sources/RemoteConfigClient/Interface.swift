// The Swift Programming Language
// https://docs.swift.org/swift-book

import DependenciesMacros

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
}
