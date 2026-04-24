import Foundation
import Testing
@testable import RemoteConfigClient

@Suite("AdConfig JSON round-trip")
struct AdConfigTests {

    @Test("Empty JSON falls back to defaults")
    func emptyDefaults() throws {
        let json = "{}".data(using: .utf8)!
        let config = try JSONDecoder().decode(RemoteConfigClient.AdConfig.self, from: json)
        #expect(config.showAllAds == true)
        #expect(config.showTopButton == true)
        #expect(config.intervalShowInter == 15)
        #expect(config.useSplashOpen == false)
        #expect(config.removeIntro == true)
        #expect(config.adUnitsConfig.interAll.id == "")
    }

    @Test("Recorder-app canonical JSON decodes every field")
    func canonicalRecorderPayload() throws {
        let payload = """
        {
          "showAllAds": true,
          "showTopButton": true,
          "intervalShowInter": 15,
          "useSplashOpen": false,
          "removeIntro": true,
          "adUnitsConfig": {
            "appopenResume": { "id": "ca-app-pub-5965765613398032/7408169619", "enable": true, "opacity": 1 },
            "interSplash":   { "id": "ca-app-pub-5965765613398032/2095929920", "enable": true, "opacity": 1 },
            "openOnResumeSplash": { "id": "ca-app-pub-5965765613398032/1201853911", "enable": true, "opacity": 1 },
            "nativeLanguage": { "id": "ca-app-pub-5965765613398032/1337585288", "enable": false },
            "nativeLanguageSelect": { "id": "ca-app-pub-5965765613398032/2323363890", "enable": false },
            "nativeIntro1": { "id": "ca-app-pub-5965765613398032/7711421943", "enable": false },
            "nativeFullIntro2": { "id": "ca-app-pub-5965765613398032/5787762927", "enable": false },
            "nativeFullIntro3": { "id": "ca-app-pub-5965765613398032/4590434584", "enable": false },
            "nativeIntro4": { "id": "ca-app-pub-5965765613398032/5085258600", "enable": false },
            "interRecorder": { "id": "ca-app-pub-5965765613398032/5346676155", "enable": true },
            "interAll": { "id": "ca-app-pub-5965765613398032/6965113227", "enable": true, "opacity": 1 },
            "rewardAll": {
              "id": "ca-app-pub-5965765613398032/7519850252",
              "enable": true,
              "opacity": 1,
              "extraKeys": { "watchAds": true }
            },
            "nativeAll": {
              "id": "ca-app-pub-5965765613398032/6993033380",
              "enable": true,
              "extraKeys": { "nativeAppearance": true, "nativeLanguageSetting": true }
            }
          }
        }
        """.data(using: .utf8)!

        let config = try JSONDecoder().decode(RemoteConfigClient.AdConfig.self, from: payload)

        // Top-level
        #expect(config.showAllAds == true)
        #expect(config.useSplashOpen == false)
        #expect(config.removeIntro == true)

        // Preloaded units — opacity:1
        #expect(config.adUnitsConfig.appopenResume.id == "ca-app-pub-5965765613398032/7408169619")
        #expect(config.adUnitsConfig.appopenResume.opacity == 1)
        #expect(config.adUnitsConfig.interSplash.opacity == 1)
        #expect(config.adUnitsConfig.openOnResumeSplash.opacity == 1)
        #expect(config.adUnitsConfig.interAll.opacity == 1)
        #expect(config.adUnitsConfig.rewardAll.opacity == 1)

        // Non-preloaded units — opacity defaults to 0
        #expect(config.adUnitsConfig.interRecorder.id == "ca-app-pub-5965765613398032/5346676155")
        #expect(config.adUnitsConfig.interRecorder.opacity == 0)
        #expect(config.adUnitsConfig.nativeAll.opacity == 0)
        #expect(config.adUnitsConfig.nativeFullIntro2.opacity == 0)

        // Disabled native units
        #expect(config.adUnitsConfig.nativeLanguage.enable == false)
        #expect(config.adUnitsConfig.nativeIntro1.enable == false)
        #expect(config.adUnitsConfig.nativeFullIntro3.enable == false)

        // extraKeys still flow through raw (typed wrappers removed in v2 cleanup).
        #expect(config.adUnitsConfig.rewardAll.extraKeys?["watchAds"] == true)
        #expect(config.adUnitsConfig.nativeAll.extraKeys?["nativeAppearance"] == true)
        #expect(config.adUnitsConfig.nativeAll.extraKeys?["nativeLanguageSetting"] == true)
    }

    @Test("happyPath mock returns enabled ads")
    func happyPathMock() async throws {
        let client = RemoteConfigClient.happyPath
        let config = try await client.adConfig()
        #expect(config.showAllAds == true)
    }

    @Test("happyPath adConfigUpdates yields current config then finishes")
    func happyPathStreamYields() async throws {
        let client = RemoteConfigClient.happyPath
        var received: [RemoteConfigClient.AdConfig] = []
        for await config in client.adConfigUpdates() {
            received.append(config)
        }
        #expect(received.count == 1)
        #expect(received[0].showAllAds == true)
    }

    @Test("fetchAndActivate re-emits fresh config to active adConfigUpdates subscribers")
    func fetchAndActivateNotifiesSubscribers() async throws {
        // Simulates the contract the live actor now satisfies: a fetchAndActivate call
        // yields the refreshed config to anyone currently iterating adConfigUpdates().
        let (stream, continuation) = AsyncStream<RemoteConfigClient.AdConfig>.makeStream()

        let client = RemoteConfigClient(
            adConfigV2: { RemoteConfigClient.AdConfigV2() },
            adConfigV2Updates: { .finished },
            adConfig: { RemoteConfigClient.AdConfig() },
            adConfigUpdates: { stream },
            fetchAndActivate: {
                // Live actor would re-decode and yield. Simulate that here.
                continuation.yield(RemoteConfigClient.AdConfig(showAllAds: false))
            },
            fetchAndActivateOrUseCache: { }
        )

        // Subscriber sees the initial cached value.
        continuation.yield(RemoteConfigClient.AdConfig(showAllAds: true))

        // Consumer triggers a manual refetch.
        try await client.fetchAndActivate()
        continuation.finish()

        var flags: [Bool] = []
        for await config in client.adConfigUpdates() {
            flags.append(config.showAllAds)
        }
        #expect(flags == [true, false])
    }

    @Test("custom client can inject multi-event stream")
    func customMultiEventStream() async throws {
        let (stream, continuation) = AsyncStream<RemoteConfigClient.AdConfig>.makeStream()
        let client = RemoteConfigClient(
            adConfigV2: { RemoteConfigClient.AdConfigV2() },
            adConfigV2Updates: { .finished },
            adConfig: { RemoteConfigClient.AdConfig() },
            adConfigUpdates: { stream },
            fetchAndActivate: { },
            fetchAndActivateOrUseCache: { }
        )
        continuation.yield(RemoteConfigClient.AdConfig(showAllAds: true))
        continuation.yield(RemoteConfigClient.AdConfig(showAllAds: false))
        continuation.finish()

        var received: [Bool] = []
        for await config in client.adConfigUpdates() {
            received.append(config.showAllAds)
        }
        #expect(received == [true, false])
    }

    @Test("happyPath exposes default AdConfigV2")
    func happyPathV2() async throws {
        let client = RemoteConfigClient.happyPath
        let v2 = try await client.adConfigV2()
        #expect(v2.schemaVersion == 2)
        #expect(v2.global.adsEnabled == true)
        #expect(v2.global.interstitial.minIntervalSeconds == 15)
    }

    @Test("happyPath adConfigV2Updates yields once then finishes")
    func happyPathV2Stream() async throws {
        let client = RemoteConfigClient.happyPath
        var received: [RemoteConfigClient.AdConfigV2] = []
        for await v2 in client.adConfigV2Updates() {
            received.append(v2)
        }
        #expect(received.count == 1)
        #expect(received[0].schemaVersion == 2)
    }

    @Test("custom client can inject multi-event v2 stream")
    func customMultiEventV2Stream() async throws {
        let (stream, continuation) = AsyncStream<RemoteConfigClient.AdConfigV2>.makeStream()
        var enabled = RemoteConfigClient.AdConfigV2()
        enabled.global.adsEnabled = true
        var disabled = RemoteConfigClient.AdConfigV2()
        disabled.global.adsEnabled = false

        let client = RemoteConfigClient(
            adConfigV2: { RemoteConfigClient.AdConfigV2() },
            adConfigV2Updates: { stream },
            adConfig: { RemoteConfigClient.AdConfig() },
            adConfigUpdates: { .finished },
            fetchAndActivate: { },
            fetchAndActivateOrUseCache: { }
        )
        continuation.yield(enabled)
        continuation.yield(disabled)
        continuation.finish()

        var received: [Bool] = []
        for await v2 in client.adConfigV2Updates() {
            received.append(v2.global.adsEnabled)
        }
        #expect(received == [true, false])
    }
}
