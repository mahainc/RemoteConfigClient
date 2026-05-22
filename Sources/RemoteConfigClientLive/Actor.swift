//
//  RemoteConfigActor.swift
//  RemoteConfigClient
//
//  Created by Thanh Hai Khong on 1/4/25.
//

import RemoteConfigClient
@preconcurrency import FirebaseRemoteConfig

actor RemoteConfigActor {
    /// Per-key subscribers for the generic `valueUpdates(_:)` API. Outer dict
    /// keyed by Remote Config key; inner dict by subscriber UUID for O(1)
    /// cancellation.
    private var valueContinuations: [String: [UUID: AsyncStream<RemoteValue>.Continuation]] = [:]

    public init(configuration: RemoteConfigClient.Configuration = .default) {
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = configuration.minimumFetchInterval
        let rc = RemoteConfig.remoteConfig()
        rc.configSettings = settings

        // Auto-load bundled defaults so `configValue(forKey:)` returns real
        // values on the very first call — before any fetchAndActivate
        // completes. Eliminates the cold-start race where reads see empty raws.
        if let plistName = configuration.defaultsPlistName,
           Bundle.main.path(forResource: plistName, ofType: "plist") != nil {
            rc.setDefaults(fromPlist: plistName)
        }

        guard configuration.enableLiveUpdateListener else { return }

        rc.addOnConfigUpdateListener { configUpdate, error in
            guard error == nil else { return }
            let updatedKeys: Set<String> = configUpdate?.updatedKeys ?? []
            rc.activate { _, error in
                guard error == nil else { return }
                Task {
                    await self.handleConfigUpdate(updatedKeys: updatedKeys)
                }
            }
        }
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
        _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<RemoteConfigFetchAndActivateStatus, Error>) in
            RemoteConfig.remoteConfig().fetchAndActivate { status, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: status)
            }
        }
        // Fan out fresh snapshots to every per-key subscriber. We don't know
        // which keys changed during a manual fetch, so we re-yield all of them.
        fanOutAllValueSubscribers()
    }
}

// MARK: - Private

extension RemoteConfigActor {
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

    private func unregisterValue(id: UUID, key: String) {
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
        let rc = RemoteConfig.remoteConfig().configValue(forKey: key)
        let source: RemoteValue.Source = {
            switch rc.source {
            case .remote:  return .remote
            case .default: return .default
            case .static:  return .static
            @unknown default: return .static
            }
        }()
        return RemoteValue(
            stringValue: rc.stringValue,
            intValue: rc.numberValue.intValue,
            boolValue: rc.boolValue,
            doubleValue: rc.numberValue.doubleValue,
            dataValue: rc.dataValue,
            source: source
        )
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

    /// Fans out a fresh snapshot to every active per-key subscriber. Used after
    /// a manual `fetchAndActivate` call where we don't have a precise
    /// `updatedKeys` set from the SDK's listener.
    private func fanOutAllValueSubscribers() {
        for (key, subs) in valueContinuations where !subs.isEmpty {
            let snapshot = Self.readValue(forKey: key)
            for continuation in subs.values {
                continuation.yield(snapshot)
            }
        }
    }

    private func handleConfigUpdate(updatedKeys: Set<String>) async {
        fanOutValueSubscribers(forKeys: updatedKeys)
    }
}
