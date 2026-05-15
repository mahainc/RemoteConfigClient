//
//  RemoteConfigActor.swift
//  RemoteConfigClient
//
//  Created by Thanh Hai Khong on 1/4/25.
//

import RemoteConfigClient
@preconcurrency import FirebaseRemoteConfig

actor RemoteConfigActor {
    private var cachedAdConfig: RemoteConfigClient.AdConfig? = nil
    private var cachedAdConfigV2: RemoteConfigClient.AdConfigV2? = nil

    /// Active subscribers keyed by UUID so cancellation is O(1).
    private var adConfigContinuations: [UUID: AsyncStream<RemoteConfigClient.AdConfig>.Continuation] = [:]
    private var adConfigV2Continuations: [UUID: AsyncStream<RemoteConfigClient.AdConfigV2>.Continuation] = [:]

    public init() {
        let settings = RemoteConfigSettings()
        #if DEBUG
        settings.minimumFetchInterval = 0
        #else
        settings.minimumFetchInterval = 3600
        #endif
        let rc = RemoteConfig.remoteConfig()
        rc.configSettings = settings

        // Auto-load bundled defaults so `configValue(forKey:)` returns real
        // values on the very first call — before any fetchAndActivate
        // completes. Eliminates the cold-start race where decodeAdConfigV2()
        // sees an empty raw and falls back to a default-constructed value.
        // Apps that don't ship the plist behave exactly as before.
        if Bundle.main.path(forResource: "RemoteConfigDefaults", ofType: "plist") != nil {
            rc.setDefaults(fromPlist: "RemoteConfigDefaults")
        }

        rc.addOnConfigUpdateListener { configUpdate, error in
            guard error == nil else { return }
            rc.activate { changed, error in
                guard error == nil else { return }
                Task {
                    await self.handleConfigUpdate()
                }
            }
        }
    }
}

// MARK: - Public Methods

extension RemoteConfigActor {
    public func getAdConfig() async throws -> RemoteConfigClient.AdConfig {
        if let cached = cachedAdConfig {
            return cached
        }
        let decoded = try decodeConfigs()
        cachedAdConfig = decoded.v1
        cachedAdConfigV2 = decoded.v2
        return decoded.v1
    }

    public func getAdConfigV2() async throws -> RemoteConfigClient.AdConfigV2 {
        if let cached = cachedAdConfigV2 {
            return cached
        }
        // Try v2 raw first; this serves bundled defaults from setDefaults(fromPlist:)
        // when an app ships them and the network fetch hasn't activated values yet.
        if let v2 = try decodeAdConfigV2() {
            cachedAdConfigV2 = v2
            cachedAdConfig = v2.toLegacy()
            return v2
        }
        // No v2 raw available. Fall back to the v1 legacy path; if that also has
        // no raw, decodeAdConfigV1 throws — the caller sees the failure honestly
        // rather than getting a silently-fabricated empty struct.
        let v1 = try decodeAdConfigV1()
        cachedAdConfig = v1
        let v2 = RemoteConfigClient.AdConfigV2()
        cachedAdConfigV2 = v2
        return v2
    }

    /// Yields the currently-cached v1 `AdConfig` (if any) immediately, then re-emits
    /// on every Remote Config update. Subscription self-unregisters on consumer cancel.
    nonisolated public func adConfigUpdates() -> AsyncStream<RemoteConfigClient.AdConfig> {
        AsyncStream { continuation in
            let id = UUID()
            Task { await self.registerV1(id: id, continuation: continuation) }
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                Task { await self.unregisterV1(id: id) }
            }
        }
    }

    /// Yields the currently-cached v2 `RemoteConfigClient.AdConfigV2` (if any) immediately, then re-emits
    /// on every Remote Config update. Subscription self-unregisters on consumer cancel.
    nonisolated public func adConfigV2Updates() -> AsyncStream<RemoteConfigClient.AdConfigV2> {
        AsyncStream { continuation in
            let id = UUID()
            Task { await self.registerV2(id: id, continuation: continuation) }
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                Task { await self.unregisterV2(id: id) }
            }
        }
    }

    public func fetchAndActivate() async throws {
        _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<RemoteConfigFetchAndActivateStatus, Error>) in
            RemoteConfig.remoteConfig().fetchAndActivate { status, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: status)
            }
        }

        // Cache only when we actually have v2 values. Empty raw after the SDK
        // success callback means the fetch returned nothing usable (a known
        // cold-start race in Firebase RC). Leaving cache nil lets the next
        // getAdConfigV2() lazy-read configValue, which serves bundled defaults
        // via setDefaults(fromPlist:) when an app ships them.
        do {
            guard let v2 = try decodeAdConfigV2() else {
                #if DEBUG
                print("[RemoteConfigActor] fetchAndActivate: SDK success but ad_config_v2 raw empty; cache stays nil for setDefaults fallback")
                #endif
                return
            }
            cachedAdConfig = v2.toLegacy()
            cachedAdConfigV2 = v2
            for continuation in adConfigContinuations.values {
                continuation.yield(v2.toLegacy())
            }
            for continuation in adConfigV2Continuations.values {
                continuation.yield(v2)
            }
        } catch {
            cachedAdConfig = nil
            cachedAdConfigV2 = nil
            #if DEBUG
            print("[RemoteConfigActor] fetchAndActivate: ad config decode failed: \(error.localizedDescription)")
            #endif
        }
    }
}

// MARK: - Private

extension RemoteConfigActor {
    private func registerV1(
        id: UUID,
        continuation: AsyncStream<RemoteConfigClient.AdConfig>.Continuation
    ) {
        adConfigContinuations[id] = continuation
        if let cached = cachedAdConfig {
            continuation.yield(cached)
        }
    }

    private func unregisterV1(id: UUID) {
        adConfigContinuations.removeValue(forKey: id)
    }

    private func registerV2(
        id: UUID,
        continuation: AsyncStream<RemoteConfigClient.AdConfigV2>.Continuation
    ) {
        adConfigV2Continuations[id] = continuation
        if let cached = cachedAdConfigV2 {
            continuation.yield(cached)
        }
    }

    private func unregisterV2(id: UUID) {
        adConfigV2Continuations.removeValue(forKey: id)
    }

    private func handleConfigUpdate() async {
        // Same contract as fetchAndActivate: only cache when v2 raw has real
        // values; never fabricate an empty-struct fallback.
        do {
            guard let v2 = try decodeAdConfigV2() else {
                #if DEBUG
                print("[RemoteConfigActor] handleConfigUpdate: ad_config_v2 raw empty after listener fire; ignoring")
                #endif
                return
            }
            cachedAdConfig = v2.toLegacy()
            cachedAdConfigV2 = v2
            for continuation in adConfigContinuations.values {
                continuation.yield(v2.toLegacy())
            }
            for continuation in adConfigV2Continuations.values {
                continuation.yield(v2)
            }
        } catch {
            #if DEBUG
            print("Failed to update ad config: \(error.localizedDescription)")
            #endif
        }
    }

    private struct DecodedConfigs {
        let v1: RemoteConfigClient.AdConfig
        let v2: RemoteConfigClient.AdConfigV2
    }

    /// Reads the already-activated Remote Config values and decodes both shapes.
    /// Tries `ad_config_v2` first; when present, v1 is produced via `toLegacy()`.
    /// When v2 is missing, falls back to `ad_config` and pairs it with a default
    /// `RemoteConfigClient.AdConfigV2()` so v2 subscribers still get a usable (all-default) value.
    nonisolated private func decodeConfigs() throws -> DecodedConfigs {
        if let v2 = try decodeAdConfigV2() {
            return DecodedConfigs(v1: v2.toLegacy(), v2: v2)
        }
        let v1 = try decodeAdConfigV1()
        return DecodedConfigs(v1: v1, v2: RemoteConfigClient.AdConfigV2())
    }

    /// Tries to decode the v2 payload. Returns `nil` when the RC key is empty
    /// or malformed so the caller can fall back to v1.
    nonisolated private func decodeAdConfigV2() throws -> RemoteConfigClient.AdConfigV2? {
        let raw = RemoteConfig.remoteConfig().configValue(forKey: "ad_config_v2").stringValue
        guard !raw.isEmpty, let data = raw.data(using: .utf8) else {
            return nil
        }

        do {
            let v2 = try JSONDecoder().decode(RemoteConfigClient.AdConfigV2.self, from: data)
            #if DEBUG
            print("[RemoteConfigActor] served ad_config_v2 (schemaVersion=\(v2.schemaVersion))")
            #endif
            return v2
        } catch {
            #if DEBUG
            print("[RemoteConfigActor] ad_config_v2 present but malformed: \(error.localizedDescription); falling back to ad_config")
            #endif
            return nil
        }
    }

    nonisolated private func decodeAdConfigV1() throws -> RemoteConfigClient.AdConfig {
        let raw = RemoteConfig.remoteConfig().configValue(forKey: "ad_config").stringValue
        guard !raw.isEmpty, let data = raw.data(using: .utf8) else {
            // Throw instead of silently returning a default-constructed struct.
            // Callers that catch this (fetchAndActivate, getAdConfigV2, etc.)
            // can decide to use bundled defaults or surface the failure.
            throw RemoteConfigDecodeError.emptyRawValue
        }
        #if DEBUG
        print("[RemoteConfigActor] served ad_config (v1 fallback)")
        #endif
        return try JSONDecoder().decode(RemoteConfigClient.AdConfig.self, from: data)
    }
}

/// Surfaces an empty configValue raw to callers instead of letting them
/// receive a silently-fabricated default struct. With this error, the
/// "use defaults on error" semantic falls naturally out of the catch path
/// (cache stays nil → next lazy decode hits setDefaults' bundled values).
enum RemoteConfigDecodeError: Error {
    case emptyRawValue
}
