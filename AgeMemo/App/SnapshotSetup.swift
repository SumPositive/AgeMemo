// fastlane snapshot 撮影時だけ、見栄えのする状態をアプリに作らせる
//
// 実機・配布ビルドでは何もしない。UITest が -FASTLANE_SNAPSHOT YES を渡したときのみ働く。
// 撮影用の状態を UITest 側から画面操作で作ろうとすると、生年月日のテンキー入力や
// 設定トグルの連打が必要になり壊れやすいため、起動引数で一括して整える。

import Foundation

#if DEBUG
enum SnapshotSetup {
    /// 1枚目の年齢一覧で表示する年
    static let initialListYear = 2026
    /// 3枚目の詳細で表示する年
    static let detailYear = 1963

    /// 撮影モードかどうか
    static var isActive: Bool {
        UserDefaults.standard.string(forKey: "FASTLANE_SNAPSHOT") == "YES"
            || ProcessInfo.processInfo.arguments.contains("-FASTLANE_SNAPSHOT")
    }

    /// 撮影用の設定と名簿を用意する。起動直後に一度だけ呼ぶ
    @MainActor
    static func applyIfNeeded(settings: AppSettings, personStore: PersonStore, memoStore: MemoStore) {
        guard isActive else { return }

        let arguments = ProcessInfo.processInfo.arguments

        // 生年月日。「自分」タブと長寿祝い・厄年・学齢の判定に要る
        settings.birthDate = DateComponents(
            calendar: Calendar(identifier: .gregorian),
            year: 1963, month: 9, day: 1
        ).date
        settings.gender = .male
        settings.showsTraditionalAge = false
        settings.displayMode = .expert
        settings.showsMemoOnlyForSelf = false

        // 年齢一覧は補助表示なしで撮影するため、起動時はすべてOFFにする
        settings.showsZodiac = false
        settings.showsNineStar = false
        settings.showsSchoolAge = false
        settings.showsLongevity = false
        settings.showsUnluckyYear = false

        // 撮影用に指定された文字サイズを全端末へ適用する
        if let index = arguments.firstIndex(of: "-SNAPSHOT_FONT_SCALE"),
           index + 1 < arguments.count {
            switch arguments[index + 1] {
            case "large": settings.fontScale = .large
            case "xlarge": settings.fontScale = .extraLarge
            default: settings.fontScale = .standard
            }
        }

        removeObsoleteSampleMemos(memoStore)
        applySamplePeople(personStore)
    }

    /// 自分一覧の撮影時だけ補助表示をすべてONにする
    @MainActor
    static func enableAuxiliaryDisplaysIfNeeded(settings: AppSettings) {
        guard isActive else { return }
        settings.showsZodiac = true
        settings.showsNineStar = true
        settings.showsSchoolAge = true
        settings.showsLongevity = true
        settings.showsUnluckyYear = true
    }

    /// 以前の撮影処理で追加した要件外のサンプルメモを取り除く
    @MainActor
    private static func removeObsoleteSampleMemos(_ memoStore: MemoStore) {
        let currentYear = Calendar(identifier: .gregorian).component(.year, from: .now)
        let obsoleteMemos = [
            (currentYear, "還暦の準備をはじめる"),
            (1964, "東京オリンピック。この年に生まれた"),
            (1989, "平成に改元。社会人になった年"),
        ]
        for (year, text) in obsoleteMemos where memoStore.text(for: year) == text {
            memoStore.update(year: year, text: "")
        }
    }

    /// 名簿タブを空にしないための例
    @MainActor
    private static func applySamplePeople(_ personStore: PersonStore) {
        guard personStore.people.isEmpty else { return }
        let calendar = Calendar(identifier: .gregorian)
        let samples: [(String, Int, Int, Int, Gender)] = [
            (String(localized: "母"), 1938, 3, 3, .female),
            (String(localized: "妻"), 1966, 11, 22, .female),
            (String(localized: "長男"), 1995, 7, 7, .male),
        ]
        for (name, year, month, day, gender) in samples {
            guard let date = DateComponents(calendar: calendar, year: year, month: month, day: day).date
            else { continue }
            personStore.add(name: name, birthDate: date, gender: gender)
        }
    }
}
#endif
