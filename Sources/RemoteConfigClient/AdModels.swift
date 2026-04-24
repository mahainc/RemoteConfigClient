//
//  AdModels.swift
//  RemoteConfigClient
//
//  Schema is canonical against the recorder-app `ad_config` JSON. Every field
//  here corresponds 1:1 to a Firebase Remote Config key. Breaking changes to
//  field names must be coordinated with Remote Config.
//

import Foundation

extension RemoteConfigClient {
    public struct AdConfig: Codable, Sendable {
        public var showAllAds: Bool
        public var showTopButton: Bool
        public var intervalShowInter: Int
        /// When `true`, use an App Open ad (not interstitial) on splash.
        public var useSplashOpen: Bool
        /// When `true`, skip intro/onboarding screens. (JSON key is a double-negative;
        /// treat `true` as "remove the intro from the flow".)
        public var removeIntro: Bool
        public var adUnitsConfig: AdUnitsConfig

        public init(
            showAllAds: Bool = true,
            showTopButton: Bool = true,
            intervalShowInter: Int = 15,
            useSplashOpen: Bool = false,
            removeIntro: Bool = true,
            adUnitsConfig: AdUnitsConfig = AdUnitsConfig()
        ) {
            self.showAllAds = showAllAds
            self.showTopButton = showTopButton
            self.intervalShowInter = intervalShowInter
            self.useSplashOpen = useSplashOpen
            self.removeIntro = removeIntro
            self.adUnitsConfig = adUnitsConfig
        }

        enum CodingKeys: String, CodingKey {
            case showAllAds, showTopButton, intervalShowInter, useSplashOpen, removeIntro, adUnitsConfig
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            showAllAds = try container.decodeIfPresent(Bool.self, forKey: .showAllAds) ?? true
            showTopButton = try container.decodeIfPresent(Bool.self, forKey: .showTopButton) ?? true
            intervalShowInter = try container.decodeIfPresent(Int.self, forKey: .intervalShowInter) ?? 15
            useSplashOpen = try container.decodeIfPresent(Bool.self, forKey: .useSplashOpen) ?? false
            removeIntro = try container.decodeIfPresent(Bool.self, forKey: .removeIntro) ?? true
            adUnitsConfig = try container.decodeIfPresent(AdUnitsConfig.self, forKey: .adUnitsConfig) ?? AdUnitsConfig()
        }
    }

    public struct AdUnitConfig: Codable, Sendable {
        public var id: String
        public var enable: Bool
        /// Preload count. `0` means "do not preload"; `>0` means "preload up to N ads in the pool".
        /// JSON omits this key on non-preloaded units (e.g. `interRecorder`, native units).
        public var opacity: Int
        public var extraKeys: [String: Bool]?

        public init(
            id: String = "",
            enable: Bool = true,
            opacity: Int = 0,
            extraKeys: [String: Bool]? = nil
        ) {
            self.id = id
            self.enable = enable
            self.opacity = opacity
            self.extraKeys = extraKeys
        }

        enum CodingKeys: String, CodingKey {
            case id, enable, opacity, extraKeys
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decodeIfPresent(String.self, forKey: .id) ?? ""
            enable = try container.decodeIfPresent(Bool.self, forKey: .enable) ?? true
            opacity = try container.decodeIfPresent(Int.self, forKey: .opacity) ?? 0
            extraKeys = try container.decodeIfPresent([String: Bool].self, forKey: .extraKeys)
        }
    }

    public struct AdUnitsConfig: Codable, Sendable {
        // App-open family
        public var appopenResume: AdUnitConfig
        public var openOnResumeSplash: AdUnitConfig
        // Interstitial family
        public var interSplash: AdUnitConfig
        public var interAll: AdUnitConfig
        public var interRecorder: AdUnitConfig
        // Native family
        public var nativeLanguage: AdUnitConfig
        public var nativeLanguageSelect: AdUnitConfig
        public var nativeIntro1: AdUnitConfig
        public var nativeFullIntro2: AdUnitConfig
        public var nativeFullIntro3: AdUnitConfig
        public var nativeIntro4: AdUnitConfig
        public var nativeAll: AdUnitConfig
        // Reward family
        public var rewardAll: AdUnitConfig

        public init(
            appopenResume: AdUnitConfig = AdUnitConfig(),
            openOnResumeSplash: AdUnitConfig = AdUnitConfig(),
            interSplash: AdUnitConfig = AdUnitConfig(),
            interAll: AdUnitConfig = AdUnitConfig(),
            interRecorder: AdUnitConfig = AdUnitConfig(),
            nativeLanguage: AdUnitConfig = AdUnitConfig(),
            nativeLanguageSelect: AdUnitConfig = AdUnitConfig(),
            nativeIntro1: AdUnitConfig = AdUnitConfig(),
            nativeFullIntro2: AdUnitConfig = AdUnitConfig(),
            nativeFullIntro3: AdUnitConfig = AdUnitConfig(),
            nativeIntro4: AdUnitConfig = AdUnitConfig(),
            nativeAll: AdUnitConfig = AdUnitConfig(),
            rewardAll: AdUnitConfig = AdUnitConfig()
        ) {
            self.appopenResume = appopenResume
            self.openOnResumeSplash = openOnResumeSplash
            self.interSplash = interSplash
            self.interAll = interAll
            self.interRecorder = interRecorder
            self.nativeLanguage = nativeLanguage
            self.nativeLanguageSelect = nativeLanguageSelect
            self.nativeIntro1 = nativeIntro1
            self.nativeFullIntro2 = nativeFullIntro2
            self.nativeFullIntro3 = nativeFullIntro3
            self.nativeIntro4 = nativeIntro4
            self.nativeAll = nativeAll
            self.rewardAll = rewardAll
        }

        enum CodingKeys: String, CodingKey {
            case appopenResume, openOnResumeSplash
            case interSplash, interAll, interRecorder
            case nativeLanguage, nativeLanguageSelect
            case nativeIntro1, nativeFullIntro2, nativeFullIntro3, nativeIntro4, nativeAll
            case rewardAll
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            appopenResume = try container.decodeIfPresent(AdUnitConfig.self, forKey: .appopenResume) ?? AdUnitConfig()
            openOnResumeSplash = try container.decodeIfPresent(AdUnitConfig.self, forKey: .openOnResumeSplash) ?? AdUnitConfig()
            interSplash = try container.decodeIfPresent(AdUnitConfig.self, forKey: .interSplash) ?? AdUnitConfig()
            interAll = try container.decodeIfPresent(AdUnitConfig.self, forKey: .interAll) ?? AdUnitConfig()
            interRecorder = try container.decodeIfPresent(AdUnitConfig.self, forKey: .interRecorder) ?? AdUnitConfig()
            nativeLanguage = try container.decodeIfPresent(AdUnitConfig.self, forKey: .nativeLanguage) ?? AdUnitConfig()
            nativeLanguageSelect = try container.decodeIfPresent(AdUnitConfig.self, forKey: .nativeLanguageSelect) ?? AdUnitConfig()
            nativeIntro1 = try container.decodeIfPresent(AdUnitConfig.self, forKey: .nativeIntro1) ?? AdUnitConfig()
            nativeFullIntro2 = try container.decodeIfPresent(AdUnitConfig.self, forKey: .nativeFullIntro2) ?? AdUnitConfig()
            nativeFullIntro3 = try container.decodeIfPresent(AdUnitConfig.self, forKey: .nativeFullIntro3) ?? AdUnitConfig()
            nativeIntro4 = try container.decodeIfPresent(AdUnitConfig.self, forKey: .nativeIntro4) ?? AdUnitConfig()
            nativeAll = try container.decodeIfPresent(AdUnitConfig.self, forKey: .nativeAll) ?? AdUnitConfig()
            rewardAll = try container.decodeIfPresent(AdUnitConfig.self, forKey: .rewardAll) ?? AdUnitConfig()
        }
    }

}
