import Foundation
import SwiftUI
import Combine

// MARK: - Supported Languages

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case turkish = "tr"
    case german = "de"
    case spanish = "es"
    case french = "fr"
    case italian = "it"
    case chinese = "zh"
    case japanese = "ja"
    case hindi = "hi"
    case dutch = "nl"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .english: return "English"
        case .turkish: return "Türkçe"
        case .german: return "Deutsch"
        case .spanish: return "Español"
        case .french: return "Français"
        case .italian: return "Italiano"
        case .chinese: return "中文"
        case .japanese: return "日本語"
        case .hindi: return "हिन्दी"
        case .dutch: return "Nederlands"
        }
    }
    
    var flag: String {
        switch self {
        case .english: return "🇬🇧"
        case .turkish: return "🇹🇷"
        case .german: return "🇩🇪"
        case .spanish: return "🇪🇸"
        case .french: return "🇫🇷"
        case .italian: return "🇮🇹"
        case .chinese: return "🇨🇳"
        case .japanese: return "🇯🇵"
        case .hindi: return "🇮🇳"
        case .dutch: return "🇳🇱"
        }
    }
}

// MARK: - Localization Manager

@MainActor
final class LocalizationManager: ObservableObject {
    
    static let shared = LocalizationManager()
    
    private let languageKey = "SpeedBar.SelectedLanguage"
    private var bundle: Bundle = .main
    
    @Published private(set) var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: languageKey)
            updateBundle()
        }
    }
    
    private init() {
        if let savedCode = UserDefaults.standard.string(forKey: languageKey),
           let language = AppLanguage(rawValue: savedCode) {
            self.currentLanguage = language
        } else {
            let systemLanguage = Locale.current.language.languageCode?.identifier ?? "en"
            self.currentLanguage = AppLanguage(rawValue: systemLanguage) ?? .english
        }
        updateBundle()
    }
    
    func setLanguage(_ language: AppLanguage) {
        guard language != currentLanguage else { return }
        currentLanguage = language
        objectWillChange.send()
    }
    
    func localizedString(_ key: String) -> String {
        return bundle.localizedString(forKey: key, value: nil, table: "Localizable")
    }
    
    private func updateBundle() {
        if let path = Bundle.main.path(forResource: currentLanguage.rawValue, ofType: "lproj"),
           let languageBundle = Bundle(path: path) {
            bundle = languageBundle
        } else {
            bundle = .main
        }
    }
}

// MARK: - Localized String Keys (Legacy support)

struct L10n {
    private static var manager: LocalizationManager { LocalizationManager.shared }
    
    static var appName: String { manager.localizedString("app.name") }
    
    static var startMeasurement: String { manager.localizedString("measurement.start") }
    static var startAgain: String { manager.localizedString("measurement.startAgain") }
    static var measuring: String { manager.localizedString("measurement.measuring") }
    static var measuringDescription: String { manager.localizedString("measurement.description") }
    
    static var downloadSpeed: String { manager.localizedString("result.downloadSpeed") }
    static var uploadSpeed: String { manager.localizedString("result.uploadSpeed") }
    static var downloadResponsiveness: String { manager.localizedString("result.downloadResponsiveness") }
    static var uploadResponsiveness: String { manager.localizedString("result.uploadResponsiveness") }
    static var idleLatency: String { manager.localizedString("result.idleLatency") }
    static var downloadLatency: String { manager.localizedString("result.downloadLatency") }
    static var uploadLatency: String { manager.localizedString("result.uploadLatency") }
    static var lastMeasured: String { manager.localizedString("result.lastMeasured") }
    
    static var noInternetConnection: String { manager.localizedString("error.noInternet") }
    
    static var settings: String { manager.localizedString("settings.title") }
    static var about: String { manager.localizedString("settings.about") }
    static var version: String { manager.localizedString("settings.version") }
    static var language: String { manager.localizedString("settings.language") }
    static var autoLaunch: String { manager.localizedString("settings.autoLaunch") }
    static var autoLaunchDescription: String { manager.localizedString("settings.autoLaunchDescription") }
    static var termsAndConditions: String { manager.localizedString("settings.terms") }
    static var macOSCompatibility: String { manager.localizedString("settings.compatibility") }
    static var close: String { manager.localizedString("settings.close") }
    static var quit: String { manager.localizedString("settings.quit") }
    static var restartRequired: String { manager.localizedString("settings.restartRequired") }
    
    static var welcomeTitle: String { manager.localizedString("firstLaunch.welcomeTitle") }
    static var autoLaunchPrompt: String { manager.localizedString("firstLaunch.autoLaunchPrompt") }
    static var enableAutoLaunch: String { manager.localizedString("firstLaunch.enableAutoLaunch") }
    static var skipAutoLaunch: String { manager.localizedString("firstLaunch.skipAutoLaunch") }
}
