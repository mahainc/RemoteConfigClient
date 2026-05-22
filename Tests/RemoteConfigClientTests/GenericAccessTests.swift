import Foundation
import Testing
@testable import RemoteConfigClient

@Suite("Generic key access — value / decode / valueUpdates")
struct GenericAccessTests {

    private struct DemoConfig: Codable, Sendable, Equatable {
        let title: String
        let count: Int
    }

    /// Builds a RemoteConfigClient with only `value` and `valueUpdates` wired —
    /// the @DependencyClient macro's no-arg init traps all other closures, so
    /// tests should never call them. Avoids touching the deprecated ad_config
    /// positional init parameters.
    private func makeStub(
        value: @escaping @Sendable (String) async -> RemoteValue,
        valueUpdates: @escaping @Sendable (String) -> AsyncStream<RemoteValue> = { _ in .finished }
    ) -> RemoteConfigClient {
        var client = RemoteConfigClient()
        client.value = value
        client.valueUpdates = valueUpdates
        return client
    }

    @Test("value(_:) returns whatever the stub provides")
    func valueReturnsStub() async throws {
        let client = makeStub(value: { key in
            key == "welcome_title"
                ? RemoteValue(stringValue: "hi", source: .remote)
                : RemoteValue()
        })

        let hit = await client.value("welcome_title")
        #expect(hit.stringValue == "hi")
        #expect(hit.source == .remote)

        let miss = await client.value("unknown")
        #expect(miss.stringValue == "")
        #expect(miss.source == .static)
    }

    @Test("decode(_:as:) JSON-decodes the stringValue")
    func decodeJSONString() async throws {
        let payload = #"{"title":"hello","count":42}"#
        let client = makeStub(value: { _ in
            RemoteValue(stringValue: payload, source: .remote)
        })

        let decoded: DemoConfig? = await client.decode("anything")
        #expect(decoded == DemoConfig(title: "hello", count: 42))
    }

    @Test("decode(_:as:) returns nil for empty or malformed payloads")
    func decodeReturnsNilOnFailure() async throws {
        let empty = makeStub(value: { _ in RemoteValue() })
        let nothing: DemoConfig? = await empty.decode("missing")
        #expect(nothing == nil)

        let malformed = makeStub(value: { _ in
            RemoteValue(stringValue: "{not json", source: .remote)
        })
        let broken: DemoConfig? = await malformed.decode("bad")
        #expect(broken == nil)
    }

    @Test("valueUpdates(_:) forwards every emission from the stubbed stream")
    func valueUpdatesForwardsEmissions() async throws {
        let (stream, continuation) = AsyncStream<RemoteValue>.makeStream()
        let client = makeStub(
            value: { _ in RemoteValue() },
            valueUpdates: { _ in stream }
        )

        continuation.yield(RemoteValue(stringValue: "a", source: .remote))
        continuation.yield(RemoteValue(stringValue: "b", source: .remote))
        continuation.finish()

        var received: [String] = []
        for await rv in client.valueUpdates("any_key") {
            received.append(rv.stringValue)
        }
        #expect(received == ["a", "b"])
    }

    @Test("decodeUpdates(_:as:) skips emissions that fail to decode")
    func decodeUpdatesSkipsFailures() async throws {
        let (stream, continuation) = AsyncStream<RemoteValue>.makeStream()
        let client = makeStub(
            value: { _ in RemoteValue() },
            valueUpdates: { _ in stream }
        )

        continuation.yield(RemoteValue(stringValue: #"{"title":"first","count":1}"#, source: .remote))
        continuation.yield(RemoteValue(stringValue: "garbage", source: .remote))
        continuation.yield(RemoteValue(stringValue: #"{"title":"third","count":3}"#, source: .remote))
        continuation.finish()

        var titles: [String] = []
        for await cfg in client.decodeUpdates("demo", as: DemoConfig.self) {
            titles.append(cfg.title)
        }
        #expect(titles == ["first", "third"])
    }

    @Test("Configuration default values")
    func configurationDefaults() {
        let cfg = RemoteConfigClient.Configuration.default
        #expect(cfg.minimumFetchInterval == 3600)
        #expect(cfg.defaultsPlistName == "RemoteConfigDefaults")
        #expect(cfg.enableLiveUpdateListener == true)
    }
}
