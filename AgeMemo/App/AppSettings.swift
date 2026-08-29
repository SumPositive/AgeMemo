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

enum AgeReckoning: Int, CaseIterable, Identifiable {
    case actual
    case traditional

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .actual: "満年齢"
        case .traditional: "数え年"
        }
    }

    /// 満年齢からこの数え方の年齢へ変換する。
    /// 数え年は生まれた時点で1歳、以後元日ごとに1つ増えるため、年内では満年齢＋1になる
    func age(fromActual actualAge: Int) -> Int {
        switch self {
        case .actual: actualAge
        case .traditional: actualAge + 1
        }
    }

    /// この数え方の年齢から満年齢へ戻す
    func actualAge(from age: Int) -> Int {
        switch self {
        case .actual: age
        case .traditional: age - 1
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

    /// 年齢を満年齢と数え年のどちらで数えるか
    var ageReckoning: AgeReckoning {
        didSet { defaults.set(ageReckoning.rawValue, forKey: Key.ageReckoning) }
    }

    /// 厄年の判定に使う性別。不要なら厄年を表示しない
    var gender: Gender {
        didSet { defaults.set(gender.rawValue, forKey: Key.gender) }
    }

    /// 入学・卒業の年を表示する
    var showsSchoolAge: Bool {
        didSet { defaults.set(showsSchoolAge, forKey: Key.showsSchoolAge) }
    }

    /// 九星気学の本命星を表示する
    var showsNineStar: Bool {
        didSet { defaults.set(showsNineStar, forKey: Key.showsNineStar) }
    }

    var lastEnteredAge: Int {
        didSet { defaults.set(lastEnteredAge, forKey: Key.lastEnteredAge) }
    }

    /// 移動シートで最後に選んだ入力種別
    var lastJumpSelectionID: String? {
        didSet {
            if let lastJumpSelectionID {
                defaults.set(lastJumpSelectionID, forKey: Key.lastJumpSelectionID)
            } else {
                defaults.removeObject(forKey: Key.lastJumpSelectionID)
            }
        }
    }

    /// 移動シートで最後に入力した符号付きの値
    var lastJumpInput: Int? {
        didSet {
            if let lastJumpInput {
                defaults.set(lastJumpInput, forKey: Key.lastJumpInput)
            } else {
                defaults.removeObject(forKey: Key.lastJumpInput)
            }
        }
    }

    /// メモを「自分」モードのときだけ一覧と詳細に表示する
    var showsMemoOnlyForSelf: Bool {
        didSet { defaults.set(showsMemoOnlyForSelf, forKey: Key.showsMemoOnlyForSelf) }
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
        static let lastEnteredAge = "lastEnteredAge"
        static let lastJumpSelectionID = "lastJumpSelectionID"
        static let lastJumpInput = "lastJumpInput"
        static let showsMemoOnlyForSelf = "showsMemoOnlyForSelf"
        static let ageReckoning = "ageReckoning"
        static let gender = "gender"
        static let showsSchoolAge = "showsSchoolAge"
        static let showsNineStar = "showsNineStar"
    }

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        displayMode = DisplayMode(rawValue: defaults.integer(forKey: Key.displayMode)) ?? .beginner
        fontScale = AppFontScale(rawValue: defaults.integer(forKey: Key.fontScale)) ?? .system
        appearanceMode = AppearanceMode(rawValue: defaults.integer(forKey: Key.appearanceMode)) ?? .system
        ageReckoning = AgeReckoning(rawValue: defaults.integer(forKey: Key.ageReckoning)) ?? .actual
        gender = Gender(rawValue: defaults.integer(forKey: Key.gender)) ?? .unspecified
        // どちらも既定はOFF。bool(forKey:) は未設定で false を返すのでそのまま使える
        showsSchoolAge = defaults.bool(forKey: Key.showsSchoolAge)
        showsNineStar = defaults.bool(forKey: Key.showsNineStar)
        birthDate = defaults.object(forKey: Key.birthDate) as? Date
        lastEnteredAge = defaults.object(forKey: Key.lastEnteredAge) as? Int ?? 0
        lastJumpSelectionID = defaults.string(forKey: Key.lastJumpSelectionID)
        lastJumpInput = defaults.object(forKey: Key.lastJumpInput) as? Int
        // 未設定時はONを既定とするため、値の有無を見てから読み出す
        showsMemoOnlyForSelf = defaults.object(forKey: Key.showsMemoOnlyForSelf) as? Bool ?? true
    }
}
