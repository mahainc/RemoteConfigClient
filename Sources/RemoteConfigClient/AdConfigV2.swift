//
//  AdConfigV2.swift
//  RemoteConfigClient
//
//  Client-side model for the v2 `ad_config_v2` Firebase Remote Config key.
//  Canonical JSON schema is `docs/ad_config.schema.json` (in the consumer app repo).
//
//  Forward-compat contract: every field is decoded with `decodeIfPresent`, and
//  unknown JSON keys are ignored by default. v2.x payloads add optional fields
//  only; a rename/removal bumps `schemaVersion`.
//
//  The app's existing call sites consume `RemoteConfigClient.AdConfig` (the
//  legacy / v1 shape). This file provides a parallel v2 model plus a
//  `toLegacy()` adaptor so the `RemoteConfigClientLive` actor can fetch v2
//  transparently without touching any feature code.
//

import Foundation

// MARK: - Root

extension RemoteConfigClient {
    public struct AdConfigV2: Codable, Sendable, Equatable {
        public let schemaVersion: Int
        public var global: Global
        public var appOpens: AppOpens
        public var interstitials: Interstitials
        public var rewards: Rewards
        public var natives: Natives
        public var placementGates: PlacementGates

        public init(
            schemaVersion: Int = 2,
            global: Global = .init(),
            appOpens: AppOpens = .init(),
            interstitials: Interstitials = .init(),
            rewards: Rewards = .init(),
            natives: Natives = .init(),
            placementGates: PlacementGates = .init()
        ) {
            self.schemaVersion = schemaVersion
            self.global = global
            self.appOpens = appOpens
            self.interstitials = interstitials
            self.rewards = rewards
            self.natives = natives
            self.placementGates = placementGates
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 2
            global = try c.decodeIfPresent(Global.self, forKey: .global) ?? .init()
            appOpens = try c.decodeIfPresent(AppOpens.self, forKey: .appOpens) ?? .init()
            interstitials = try c.decodeIfPresent(Interstitials.self, forKey: .interstitials) ?? .init()
            rewards = try c.decodeIfPresent(Rewards.self, forKey: .rewards) ?? .init()
            natives = try c.decodeIfPresent(Natives.self, forKey: .natives) ?? .init()
            placementGates = try c.decodeIfPresent(PlacementGates.self, forKey: .placementGates) ?? .init()
        }

        enum CodingKeys: String, CodingKey {
            case schemaVersion, global, appOpens, interstitials, rewards, natives, placementGates
        }
    }
}

// MARK: - Global policy

extension RemoteConfigClient.AdConfigV2 {
    public struct Global: Codable, Sendable, Equatable {
        public var adsEnabled: Bool
        public var sessionWarmupSeconds: Int
        public var suppressForPremium: Bool
        public var experimentId: String?
        public var splash: SplashPolicy
        public var interstitial: InterstitialPolicy
        public var appOpen: AppOpenPolicy
        public var reward: RewardPolicy
        public var native: NativePolicy

        public init(
            adsEnabled: Bool = true,
            sessionWarmupSeconds: Int = 0,
            suppressForPremium: Bool = true,
            experimentId: String? = nil,
            splash: SplashPolicy = .init(),
            interstitial: InterstitialPolicy = .init(),
            appOpen: AppOpenPolicy = .init(),
            reward: RewardPolicy = .init(),
            native: NativePolicy = .init()
        ) {
            self.adsEnabled = adsEnabled
            self.sessionWarmupSeconds = sessionWarmupSeconds
            self.suppressForPremium = suppressForPremium
            self.experimentId = experimentId
            self.splash = splash
            self.interstitial = interstitial
            self.appOpen = appOpen
            self.reward = reward
            self.native = native
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            adsEnabled = try c.decodeIfPresent(Bool.self, forKey: .adsEnabled) ?? true
            sessionWarmupSeconds = try c.decodeIfPresent(Int.self, forKey: .sessionWarmupSeconds) ?? 0
            suppressForPremium = try c.decodeIfPresent(Bool.self, forKey: .suppressForPremium) ?? true
            experimentId = try c.decodeIfPresent(String.self, forKey: .experimentId)
            splash = try c.decodeIfPresent(SplashPolicy.self, forKey: .splash) ?? .init()
            interstitial = try c.decodeIfPresent(InterstitialPolicy.self, forKey: .interstitial) ?? .init()
            appOpen = try c.decodeIfPresent(AppOpenPolicy.self, forKey: .appOpen) ?? .init()
            reward = try c.decodeIfPresent(RewardPolicy.self, forKey: .reward) ?? .init()
            native = try c.decodeIfPresent(NativePolicy.self, forKey: .native) ?? .init()
        }

        enum CodingKeys: String, CodingKey {
            case adsEnabled, sessionWarmupSeconds, suppressForPremium, experimentId
            case splash, interstitial, appOpen, reward, native
        }
    }

    public struct SplashPolicy: Codable, Sendable, Equatable {
        public enum Format: String, Codable, Sendable, Equatable {
            case appOpen
            case interstitial
            case none
        }

        public var preferredFormat: Format

        public init(preferredFormat: Format = .interstitial) {
            self.preferredFormat = preferredFormat
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            preferredFormat = try c.decodeIfPresent(Format.self, forKey: .preferredFormat) ?? .interstitial
        }

        enum CodingKeys: String, CodingKey { case preferredFormat }
    }

    public struct InterstitialPolicy: Codable, Sendable, Equatable {
        public var enabled: Bool
        public var minIntervalSeconds: Int
        public var maxPerSession: Int
        public var fallbackAdUnitId: String

        public init(
            enabled: Bool = true,
            minIntervalSeconds: Int = 15,
            maxPerSession: Int = 0,
            fallbackAdUnitId: String = ""
        ) {
            self.enabled = enabled
            self.minIntervalSeconds = minIntervalSeconds
            self.maxPerSession = maxPerSession
            self.fallbackAdUnitId = fallbackAdUnitId
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
            minIntervalSeconds = try c.decodeIfPresent(Int.self, forKey: .minIntervalSeconds) ?? 15
            maxPerSession = try c.decodeIfPresent(Int.self, forKey: .maxPerSession) ?? 0
            fallbackAdUnitId = try c.decodeIfPresent(String.self, forKey: .fallbackAdUnitId) ?? ""
        }

        enum CodingKeys: String, CodingKey {
            case enabled, minIntervalSeconds, maxPerSession, fallbackAdUnitId
        }
    }

    public struct AppOpenPolicy: Codable, Sendable, Equatable {
        public var enabled: Bool
        public var minBackgroundSeconds: Int
        public var postAdSuppressionSeconds: Int
        public var maxPerSession: Int

        public init(
            enabled: Bool = true,
            minBackgroundSeconds: Int = 30,
            postAdSuppressionSeconds: Int = 4,
            maxPerSession: Int = 0
        ) {
            self.enabled = enabled
            self.minBackgroundSeconds = minBackgroundSeconds
            self.postAdSuppressionSeconds = postAdSuppressionSeconds
            self.maxPerSession = maxPerSession
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
            minBackgroundSeconds = try c.decodeIfPresent(Int.self, forKey: .minBackgroundSeconds) ?? 30
            postAdSuppressionSeconds = try c.decodeIfPresent(Int.self, forKey: .postAdSuppressionSeconds) ?? 4
            maxPerSession = try c.decodeIfPresent(Int.self, forKey: .maxPerSession) ?? 0
        }

        enum CodingKeys: String, CodingKey {
            case enabled, minBackgroundSeconds, postAdSuppressionSeconds, maxPerSession
        }
    }

    public struct RewardPolicy: Codable, Sendable, Equatable {
        public var enabled: Bool
        public var maxPerDay: Int
        public var minIntervalSeconds: Int

        public init(
            enabled: Bool = true,
            maxPerDay: Int = 0,
            minIntervalSeconds: Int = 0
        ) {
            self.enabled = enabled
            self.maxPerDay = maxPerDay
            self.minIntervalSeconds = minIntervalSeconds
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
            maxPerDay = try c.decodeIfPresent(Int.self, forKey: .maxPerDay) ?? 0
            minIntervalSeconds = try c.decodeIfPresent(Int.self, forKey: .minIntervalSeconds) ?? 0
        }

        enum CodingKeys: String, CodingKey {
            case enabled, maxPerDay, minIntervalSeconds
        }
    }

    public struct NativePolicy: Codable, Sendable, Equatable {
        public var enabled: Bool

        public init(enabled: Bool = true) {
            self.enabled = enabled
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        }

        enum CodingKeys: String, CodingKey { case enabled }
    }
}

// MARK: - Placement groups

extension RemoteConfigClient.AdConfigV2 {
    public struct AppOpens: Codable, Sendable, Equatable {
        public var resume: PreloadablePlacement
        public var splash: PreloadablePlacement

        public init(
            resume: PreloadablePlacement = .init(),
            splash: PreloadablePlacement = .init()
        ) {
            self.resume = resume
            self.splash = splash
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            resume = try c.decodeIfPresent(PreloadablePlacement.self, forKey: .resume) ?? .init()
            splash = try c.decodeIfPresent(PreloadablePlacement.self, forKey: .splash) ?? .init()
        }

        enum CodingKeys: String, CodingKey { case resume, splash }
    }

    public struct Interstitials: Codable, Sendable, Equatable {
        public var splash: InterstitialPlacement
        public var recorder: InterstitialPlacement
        public var home: InterstitialPlacement
        public var tab: InterstitialPlacement
        public var back: InterstitialPlacement
        public var paywallClose: InterstitialPlacement

        public init(
            splash: InterstitialPlacement = .init(),
            recorder: InterstitialPlacement = .init(),
            home: InterstitialPlacement = .init(),
            tab: InterstitialPlacement = .init(),
            back: InterstitialPlacement = .init(),
            paywallClose: InterstitialPlacement = .init()
        ) {
            self.splash = splash
            self.recorder = recorder
            self.home = home
            self.tab = tab
            self.back = back
            self.paywallClose = paywallClose
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            splash = try c.decodeIfPresent(InterstitialPlacement.self, forKey: .splash) ?? .init()
            recorder = try c.decodeIfPresent(InterstitialPlacement.self, forKey: .recorder) ?? .init()
            home = try c.decodeIfPresent(InterstitialPlacement.self, forKey: .home) ?? .init()
            tab = try c.decodeIfPresent(InterstitialPlacement.self, forKey: .tab) ?? .init()
            back = try c.decodeIfPresent(InterstitialPlacement.self, forKey: .back) ?? .init()
            paywallClose = try c.decodeIfPresent(InterstitialPlacement.self, forKey: .paywallClose) ?? .init()
        }

        enum CodingKeys: String, CodingKey {
            case splash, recorder, home, tab, back, paywallClose
        }
    }

    public struct Rewards: Codable, Sendable, Equatable {
        public var watchAds: RewardPlacement

        public init(watchAds: RewardPlacement = .init()) {
            self.watchAds = watchAds
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            watchAds = try c.decodeIfPresent(RewardPlacement.self, forKey: .watchAds) ?? .init()
        }

        enum CodingKeys: String, CodingKey { case watchAds }
    }

    public struct Natives: Codable, Sendable, Equatable {
        public var fallback: NativePlacement
        /// Native shown on the language screen in its idle state (no row tapped yet).
        public var language: NativePlacement
        /// Native shown on the same language screen after the user taps a language row.
        public var languageSelected: NativePlacement
        public var intro: [String: NativePlacement]

        public init(
            fallback: NativePlacement = .init(),
            language: NativePlacement = .init(),
            languageSelected: NativePlacement = .init(),
            intro: [String: NativePlacement] = [:]
        ) {
            self.fallback = fallback
            self.language = language
            self.languageSelected = languageSelected
            self.intro = intro
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            fallback = try c.decodeIfPresent(NativePlacement.self, forKey: .fallback) ?? .init()
            language = try c.decodeIfPresent(NativePlacement.self, forKey: .language) ?? .init()
            languageSelected = try c.decodeIfPresent(NativePlacement.self, forKey: .languageSelected) ?? .init()
            intro = try c.decodeIfPresent([String: NativePlacement].self, forKey: .intro) ?? [:]
        }

        enum CodingKeys: String, CodingKey {
            case fallback, language, languageSelected, intro
        }
    }

    public struct PlacementGates: Codable, Sendable, Equatable {
        public var native: NativeGates

        public init(native: NativeGates = .init()) {
            self.native = native
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            native = try c.decodeIfPresent(NativeGates.self, forKey: .native) ?? .init()
        }

        enum CodingKeys: String, CodingKey { case native }

        public struct NativeGates: Codable, Sendable, Equatable {
            public var appearance: Bool
            public var languageSettings: Bool

            public init(appearance: Bool = false, languageSettings: Bool = false) {
                self.appearance = appearance
                self.languageSettings = languageSettings
            }

            public init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                appearance = try c.decodeIfPresent(Bool.self, forKey: .appearance) ?? false
                languageSettings = try c.decodeIfPresent(Bool.self, forKey: .languageSettings) ?? false
            }

            enum CodingKeys: String, CodingKey { case appearance, languageSettings }
        }
    }
}

// MARK: - Placement primitives

extension RemoteConfigClient.AdConfigV2 {
    public struct PreloadablePlacement: Codable, Sendable, Equatable {
        public var adUnitId: String
        public var enabled: Bool
        public var preloadCount: Int
        public var cooldownSeconds: Int?

        public init(
            adUnitId: String = "",
            enabled: Bool = false,
            preloadCount: Int = 1,
            cooldownSeconds: Int? = nil
        ) {
            self.adUnitId = adUnitId
            self.enabled = enabled
            self.preloadCount = preloadCount
            self.cooldownSeconds = cooldownSeconds
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            adUnitId = try c.decodeIfPresent(String.self, forKey: .adUnitId) ?? ""
            enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
            preloadCount = try c.decodeIfPresent(Int.self, forKey: .preloadCount) ?? 1
            cooldownSeconds = try c.decodeIfPresent(Int.self, forKey: .cooldownSeconds)
        }

        enum CodingKeys: String, CodingKey {
            case adUnitId, enabled, preloadCount, cooldownSeconds
        }
    }

    public struct InterstitialPlacement: Codable, Sendable, Equatable {
        public var adUnitId: String
        public var enabled: Bool
        public var cooldownSeconds: Int?

        public init(
            adUnitId: String = "",
            enabled: Bool = false,
            cooldownSeconds: Int? = nil
        ) {
            self.adUnitId = adUnitId
            self.enabled = enabled
            self.cooldownSeconds = cooldownSeconds
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            adUnitId = try c.decodeIfPresent(String.self, forKey: .adUnitId) ?? ""
            enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
            cooldownSeconds = try c.decodeIfPresent(Int.self, forKey: .cooldownSeconds)
        }

        enum CodingKeys: String, CodingKey { case adUnitId, enabled, cooldownSeconds }
    }

    public struct RewardPlacement: Codable, Sendable, Equatable {
        public var adUnitId: String
        public var enabled: Bool
        public var preloadCount: Int
        public var cooldownSeconds: Int?

        public init(
            adUnitId: String = "",
            enabled: Bool = false,
            preloadCount: Int = 1,
            cooldownSeconds: Int? = nil
        ) {
            self.adUnitId = adUnitId
            self.enabled = enabled
            self.preloadCount = preloadCount
            self.cooldownSeconds = cooldownSeconds
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            adUnitId = try c.decodeIfPresent(String.self, forKey: .adUnitId) ?? ""
            enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
            preloadCount = try c.decodeIfPresent(Int.self, forKey: .preloadCount) ?? 1
            cooldownSeconds = try c.decodeIfPresent(Int.self, forKey: .cooldownSeconds)
        }

        enum CodingKeys: String, CodingKey {
            case adUnitId, enabled, preloadCount, cooldownSeconds
        }
    }

    public struct NativePlacement: Codable, Sendable, Equatable {
        public enum Style: String, Codable, Sendable, Equatable {
            case compact, medium, large
        }

        public var adUnitId: String
        public var enabled: Bool
        public var style: Style

        public init(adUnitId: String = "", enabled: Bool = false, style: Style = .medium) {
            self.adUnitId = adUnitId
            self.enabled = enabled
            self.style = style
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            adUnitId = try c.decodeIfPresent(String.self, forKey: .adUnitId) ?? ""
            enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
            style = try c.decodeIfPresent(Style.self, forKey: .style) ?? .medium
        }

        enum CodingKeys: String, CodingKey { case adUnitId, enabled, style }
    }
}

// MARK: - Adaptor to the legacy (v1) `RemoteConfigClient.AdConfig`

extension RemoteConfigClient.AdConfigV2 {
    /// Projects this v2 payload into the shape the rest of the app (and AdsKit)
    /// still consumes. Fields that exist only in v2 (`sessionWarmupSeconds`,
    /// per-placement `cooldownSeconds`, `maxPerSession`, per-format `enabled`
    /// kill switches, `experimentId`, native `style`, etc.) are lost here; wire
    /// them separately via `AdConfigV2` consumers when features need them.
    public func toLegacy() -> RemoteConfigClient.AdConfig {
        let splashUsesAppOpen = global.splash.preferredFormat == .appOpen
        let splashEnabled = global.splash.preferredFormat != .none

        let splashInterUnit = RemoteConfigClient.AdUnitConfig(
            id: interstitials.splash.adUnitId,
            enable: splashEnabled && !splashUsesAppOpen && interstitials.splash.enabled,
            opacity: 1
        )
        let openOnResumeSplashUnit = RemoteConfigClient.AdUnitConfig(
            id: appOpens.splash.adUnitId,
            enable: splashEnabled && splashUsesAppOpen && appOpens.splash.enabled,
            opacity: appOpens.splash.preloadCount
        )
        let appOpenResumeUnit = RemoteConfigClient.AdUnitConfig(
            id: appOpens.resume.adUnitId,
            enable: appOpens.resume.enabled,
            opacity: appOpens.resume.preloadCount
        )
        let interAllUnit = RemoteConfigClient.AdUnitConfig(
            id: global.interstitial.fallbackAdUnitId,
            enable: !global.interstitial.fallbackAdUnitId.isEmpty,
            opacity: 1
        )
        let rewardAllUnit = RemoteConfigClient.AdUnitConfig(
            id: rewards.watchAds.adUnitId,
            enable: rewards.watchAds.enabled,
            opacity: rewards.watchAds.preloadCount,
            extraKeys: ["watchAds": rewards.watchAds.enabled]
        )
        let nativeAllUnit = RemoteConfigClient.AdUnitConfig(
            id: natives.fallback.adUnitId,
            enable: natives.fallback.enabled,
            opacity: 0,
            extraKeys: [
                "nativeAppearance": placementGates.native.appearance,
                "nativeLanguageSetting": placementGates.native.languageSettings,
            ]
        )

        let units = RemoteConfigClient.AdUnitsConfig(
            appopenResume: appOpenResumeUnit,
            openOnResumeSplash: openOnResumeSplashUnit,
            interSplash: splashInterUnit,
            interAll: interAllUnit,
            interRecorder: legacyUnit(from: interstitials.recorder),
            nativeLanguage: legacyUnit(from: natives.language),
            nativeLanguageSelect: legacyUnit(from: natives.languageSelected),
            nativeIntro1: legacyUnit(from: natives.intro["1"] ?? .init()),
            nativeFullIntro2: legacyUnit(from: natives.intro["2"] ?? .init()),
            nativeFullIntro3: legacyUnit(from: natives.intro["3"] ?? .init()),
            nativeIntro4: legacyUnit(from: natives.intro["4"] ?? .init()),
            nativeAll: nativeAllUnit,
            rewardAll: rewardAllUnit
        )

        return RemoteConfigClient.AdConfig(
            showAllAds: global.adsEnabled,
            showTopButton: true,
            intervalShowInter: global.interstitial.minIntervalSeconds,
            useSplashOpen: splashUsesAppOpen,
            removeIntro: false,
            adUnitsConfig: units
        )
    }

    private func legacyUnit(from placement: InterstitialPlacement) -> RemoteConfigClient.AdUnitConfig {
        RemoteConfigClient.AdUnitConfig(
            id: placement.adUnitId,
            enable: placement.enabled,
            opacity: 0
        )
    }

    private func legacyUnit(from placement: NativePlacement) -> RemoteConfigClient.AdUnitConfig {
        RemoteConfigClient.AdUnitConfig(
            id: placement.adUnitId,
            enable: placement.enabled,
            opacity: 0
        )
    }
}

// MARK: - JSON convenience

extension RemoteConfigClient.AdConfigV2 {
    /// Decodes a v2 payload from the JSON string Firebase's `configValue(forKey:)`
    /// returns. Throws `DecodingError` on malformed input.
    public static func decode(from jsonString: String) throws -> Self {
        let data = Data(jsonString.utf8)
        return try JSONDecoder().decode(Self.self, from: data)
    }
}
