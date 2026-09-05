// 表示設定と生年月日を端末内へ保存する

import Observation
import SwiftUI

enum DisplayMode: Int, CaseIterable, Identifiable {
    case beginner
    case expert

    var id: Int { rawValue }

    var title: LocalizedStringKey {
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

    var title: LocalizedStringKey {
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

    var title: LocalizedStringKey {
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

    /// 数え年を補足として表示するか。一覧の年齢列は常に満年齢
    var showsTraditionalAge: Bool {
        didSet { defaults.set(showsTraditionalAge, forKey: Key.showsTraditionalAge) }
    }

    /// 厄年の判定に使う性別。未指定なら厄年を表示しない
    var gender: Gender {
        didSet { defaults.set(gender.rawValue, forKey: Key.gender) }
    }

    /// 干支を一覧に表示する
    var showsZodiac: Bool {
        didSet { defaults.set(showsZodiac, forKey: Key.showsZodiac) }
    }

    /// 還暦などの長寿祝いを一覧に表示する
    var showsLongevity: Bool {
        didSet { defaults.set(showsLongevity, forKey: Key.showsLongevity) }
    }

    /// 厄年を一覧に表示する
    var showsUnluckyYear: Bool {
        didSet { defaults.set(showsUnluckyYear, forKey: Key.showsUnluckyYear) }
    }

    /// 入学・卒業の年を表示する
    var showsSchoolAge: Bool {
        didSet { defaults.set(showsSchoolAge, forKey: Key.showsSchoolAge) }
    }

    /// 九星気学の本命星を表示する
    var showsNineStar: Bool {
        didSet { defaults.set(showsNineStar, forKey: Key.showsNineStar) }
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

    /// 移動シートの入力種別ごとの実行回数。よく使う種別をすぐ選べるようにするために数える
    private(set) var jumpSelectionUseCounts: [String: Int] {
        didSet { defaults.set(jumpSelectionUseCounts, forKey: Key.jumpSelectionUseCounts) }
    }

    /// 移動を実行したときに、その入力種別の回数を1つ増やす
    func recordJumpSelectionUse(id: String) {
        jumpSelectionUseCounts[id, default: 0] += 1
    }

    /// メモ欄を一覧と詳細に表示する。持ち主は「自分」と名簿の各人で分かれる
    var showsMemo: Bool {
        didSet { defaults.set(showsMemo, forKey: Key.showsMemo) }
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
        static let lastJumpSelectionID = "lastJumpSelectionID"
        static let lastJumpInput = "lastJumpInput"
        static let jumpSelectionUseCounts = "jumpSelectionUseCounts"
        static let showsMemo = "showsMemo"
        static let showsTraditionalAge = "showsTraditionalAge"
        static let gender = "gender"
        static let showsZodiac = "showsZodiac"
        static let showsLongevity = "showsLongevity"
        static let showsUnluckyYear = "showsUnluckyYear"
        static let showsSchoolAge = "showsSchoolAge"
        static let showsNineStar = "showsNineStar"
    }

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        displayMode = DisplayMode(rawValue: defaults.integer(forKey: Key.displayMode)) ?? .beginner
        fontScale = AppFontScale(rawValue: defaults.integer(forKey: Key.fontScale)) ?? .system
        appearanceMode = AppearanceMode(rawValue: defaults.integer(forKey: Key.appearanceMode)) ?? .system
        gender = Gender(rawValue: defaults.integer(forKey: Key.gender)) ?? .unspecified
        // 補助表示はすべて既定OFF。未設定なら false を返す読み出しを使う
        showsZodiac = defaults.bool(forKey: Key.showsZodiac)
        showsLongevity = defaults.bool(forKey: Key.showsLongevity)
        showsUnluckyYear = defaults.bool(forKey: Key.showsUnluckyYear)
        showsSchoolAge = defaults.bool(forKey: Key.showsSchoolAge)
        showsNineStar = defaults.bool(forKey: Key.showsNineStar)
        birthDate = defaults.object(forKey: Key.birthDate) as? Date
        lastJumpSelectionID = defaults.string(forKey: Key.lastJumpSelectionID)
        lastJumpInput = defaults.object(forKey: Key.lastJumpInput) as? Int
        jumpSelectionUseCounts = defaults.dictionary(forKey: Key.jumpSelectionUseCounts) as? [String: Int] ?? [:]
        // 未設定時はONを既定とするため、値の有無を見てから読み出す
        showsMemo = defaults.object(forKey: Key.showsMemo) as? Bool ?? true
        showsTraditionalAge = defaults.object(forKey: Key.showsTraditionalAge) as? Bool ?? true
    }
}
