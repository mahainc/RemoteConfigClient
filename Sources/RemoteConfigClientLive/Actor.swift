//
//  RemoteConfigActor.swift
//  RemoteConfigClient
//
//  Created by Thanh Hai Khong on 1/4/25.
//

@preconcurrency import FirebaseRemoteConfig
import RemoteConfigClient

actor RemoteConfigActor {
    /// Per-key subscribers for the generic `valueUpdates(_:)` API. Outer dict
    /// keyed by Remote Config key; inner dict by subscriber UUID for O(1)
    /// cancellation.
    private var valueContinuations: [String: [UUID: AsyncStream<RemoteValue>.Continuation]] = [:]

    /// The interval this client was built with. Kept so
    /// `fetchAndSnapshot(minimumFetchInterval:)` has something to fall back on
    /// when the caller doesn't override it.
    private let configuredFetchInterval: TimeInterval

    public init(configuration: RemoteConfigClient.Configuration = .default) {
        configuredFetchInterval = configuration.minimumFetchInterval
        let rc = RemoteConfig.remoteConfig()
        Self.apply(configuration, to: rc)
        guard configuration.enableLiveUpdateListener else { return }
        observeConfigUpdates(on: rc)
    }
}

// MARK: - Public methods

extension RemoteConfigActor {
    /// Yields the current `RemoteValue` for `key` immediately, then re-emits
    /// every time Firebase activates a change touching that key. Subscription
    /// self-unregisters on consumer cancel.
    nonisolated public func valueUpdates(forKey key: String) -> AsyncStream<RemoteValue> {
        AsyncStream { continuation in
            let id = UUID()
            Task { await self.registerValue(id: id, key: key, continuation: continuation) }
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                Task { await self.unregisterValue(id: id, key: key) }
            }
        }
    }

    public func fetchAndActivate() async throws {
        _ = try await RemoteConfig.remoteConfig().fetchAndActivate()
        // Fan out fresh snapshots to every per-key subscriber. We don't know
        // which keys changed during a manual fetch, so we re-yield all of them.
        fanOutAllValueSubscribers()
    }

    /// Fetches, activates, then flattens every key Firebase knows about into
    /// `[key: stringValue]`. `minimumFetchInterval` is Firebase's own
    /// per-request override — it throttles this call alone and leaves the shared
    /// settings untouched, so a deliberately fresh read here can't un-throttle
    /// the rest of the app. `nil` falls back to the configured interval; 0
    /// forces a round trip to the backend.
    public func fetchAndSnapshot(minimumFetchInterval: TimeInterval?) async throws -> [String: String] {
        let rc = RemoteConfig.remoteConfig()
        _ = try await rc.fetch(withExpirationDuration: minimumFetchInterval ?? configuredFetchInterval)
        _ = try await rc.activate()
        fanOutAllValueSubscribers()
        return Self.readAllValues(from: rc)
    }
}

// MARK: - Private

extension RemoteConfigActor {
    /// Applies the fetch throttle, then the bundled defaults when the host ships
    /// a plist — so `configValue(forKey:)` returns real values on the very first
    /// call, before any fetch completes. Eliminates the cold-start race where
    /// reads see empty raws.
    private nonisolated static func apply(
        _ configuration: RemoteConfigClient.Configuration,
        to rc: RemoteConfig
    ) {
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = configuration.minimumFetchInterval
        rc.configSettings = settings

        guard let plistName = configuration.defaultsPlistName,
            Bundle.main.path(forResource: plistName, ofType: "plist") != nil
        else { return }
        rc.setDefaults(fromPlist: plistName)
    }

    /// Re-yields to per-key subscribers whenever Firebase pushes a change. The
    /// listener holds `self` for the life of the client, which is what keeps
    /// those updates flowing.
    private nonisolated func observeConfigUpdates(on rc: RemoteConfig) {
        rc.addOnConfigUpdateListener { configUpdate, error in
            if let error {
                Self.traceDroppedUpdate(error, step: "addOnConfigUpdateListener")
                return
            }
            let updatedKeys: Set<String> = configUpdate?.updatedKeys ?? []
            Task {
                do {
                    _ = try await RemoteConfig.remoteConfig().activate()
                    await self.handleConfigUpdate(updatedKeys: updatedKeys)
                } catch {
                    Self.traceDroppedUpdate(error, step: "activate")
                }
            }
        }
    }

    private func registerValue(
        id: UUID,
        key: String,
        continuation: AsyncStream<RemoteValue>.Continuation
    ) {
        var subs = valueContinuations[key] ?? [:]
        subs[id] = continuation
        valueContinuations[key] = subs
        // Yield the current value so callers can build initial UI without
        // waiting for the next Remote Config activation.
        continuation.yield(Self.readValue(forKey: key))
    }

    private func unregisterValue(
        id: UUID,
        key: String
    ) {
        guard var subs = valueContinuations[key] else { return }
        subs.removeValue(forKey: id)
        if subs.isEmpty {
            valueContinuations.removeValue(forKey: key)
        } else {
            valueContinuations[key] = subs
        }
    }

    /// Reads a `RemoteValue` snapshot for `key` off the shared `RemoteConfig`
    /// instance. Safe to call from anywhere — `configValue(forKey:)` is
    /// thread-safe inside the Firebase SDK.
    nonisolated static func readValue(forKey key: String) -> RemoteValue {
        let entry = RemoteConfig.remoteConfig().configValue(forKey: key)
        let source: RemoteValue.Source = {
            switch entry.source {
                case .remote: return .remote
                case .default: return .default
                case .static: return .static
                @unknown default: return .static
            }
        }()
        return RemoteValue(
            stringValue: entry.stringValue,
            intValue: entry.numberValue.intValue,
            boolValue: entry.boolValue,
            doubleValue: entry.numberValue.doubleValue,
            dataValue: entry.dataValue,
            source: source
        )
    }

    /// Flattens every key Firebase currently holds into `[key: stringValue]`.
    /// Sources are read in precedence order, and a key already taken from a
    /// higher-precedence source is never overwritten — so a remote entry wins
    /// over its bundled default even when the remote string is empty, which
    /// means "cleared upstream", not "missing".
    private nonisolated static func readAllValues(from rc: RemoteConfig) -> [String: String] {
        let sourcesInPrecedenceOrder: [RemoteConfigSource] = [.remote, .default]
        var out: [String: String] = [:]
        for source in sourcesInPrecedenceOrder {
            for key in rc.allKeys(from: source) where out[key] == nil {
                out[key] = rc.configValue(forKey: key).stringValue
            }
        }
        return out
    }

    /// A failed live update is survivable — subscribers simply keep the values
    /// they already have — but an error dropped in silence is invisible in
    /// development, so leave the same DEBUG trace `fetchAndActivateOrUseCache`
    /// leaves.
    private nonisolated static func traceDroppedUpdate(
        _ error: Error,
        step: String
    ) {
        #if DEBUG
        print(
            "[RemoteConfigClient] \(step) failed: \(error.localizedDescription); subscribers keep their current values"
        )
        #endif
    }

    private func fanOutValueSubscribers(forKeys keys: Set<String>) {
        for key in keys {
            guard let subs = valueContinuations[key], !subs.isEmpty else { continue }
            let snapshot = Self.readValue(forKey: key)
            for continuation in subs.values {
                continuation.yield(snapshot)
            }
        }
    }

    /// Fans out a fresh snapshot to every active per-key subscriber. Used by the
    /// caller-driven fetches — `fetchAndActivate` and `fetchAndSnapshot` — where
    /// we don't have a precise `updatedKeys` set from the SDK's listener.
    private func fanOutAllValueSubscribers() {
        fanOutValueSubscribers(forKeys: Set(valueContinuations.keys))
    }

    private func handleConfigUpdate(updatedKeys: Set<String>) async {
        fanOutValueSubscribers(forKeys: updatedKeys)
    }
}
