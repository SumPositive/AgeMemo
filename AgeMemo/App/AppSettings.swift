// 表示設定と生年月日を端末内へ保存する

import Observation
import SwiftUI

enum DisplayMode: Int, CaseIterable, Identifiable {
    case beginner
    case expert

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .beginner: "初心者"
        case .expert: "達人"
        }
    }
}

enum AppFontScale: Int, CaseIterable, Identifiable {
    case system
    case standard
    case large
    case extraLarge

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .system: "自動"
        case .standard: "標準"
        case .large: "大"
        case .extraLarge: "特大"
        }
    }

    var followsSystem: Bool { self == .system }

    var dynamicTypeSize: DynamicTypeSize {
        switch self {
        case .system, .standard: .large
        case .large: .xxxLarge
        case .extraLarge: .accessibility2
        }
    }
}

enum AppearanceMode: Int, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .system: "自動"
        case .light: "ライト"
        case .dark: "ダーク"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

@MainActor
@Observable
final class AppSettings {
    static let shared = AppSettings()

    var displayMode: DisplayMode {
        didSet { defaults.set(displayMode.rawValue, forKey: Key.displayMode) }
    }

    var fontScale: AppFontScale {
        didSet { defaults.set(fontScale.rawValue, forKey: Key.fontScale) }
    }

    var appearanceMode: AppearanceMode {
        didSet { defaults.set(appearanceMode.rawValue, forKey: Key.appearanceMode) }
    }

    var birthDate: Date? {
        didSet {
            if let birthDate {
                defaults.set(birthDate, forKey: Key.birthDate)
            } else {
                defaults.removeObject(forKey: Key.birthDate)
            }
        }
    }

    private let defaults: UserDefaults

    private enum Key {
        static let displayMode = "displayMode"
        static let fontScale = "fontScale"
        static let appearanceMode = "appearanceMode"
        static let birthDate = "birthDate"
    }

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        displayMode = DisplayMode(rawValue: defaults.integer(forKey: Key.displayMode)) ?? .beginner
        fontScale = AppFontScale(rawValue: defaults.integer(forKey: Key.fontScale)) ?? .system
        appearanceMode = AppearanceMode(rawValue: defaults.integer(forKey: Key.appearanceMode)) ?? .system
        birthDate = defaults.object(forKey: Key.birthDate) as? Date
    }
}
