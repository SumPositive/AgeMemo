// アプリ全体で共有する定数を定義する

import Foundation

enum AppConfig {
    /// 年齢計算と年移動で使う西暦
    static var gregorianCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        // 暦は西暦に固定し、週の開始曜日だけ端末設定を反映する
        calendar.firstWeekday = Calendar.autoupdatingCurrent.firstWeekday
        calendar.minimumDaysInFirstWeek = Calendar.autoupdatingCurrent.minimumDaysInFirstWeek
        return calendar
    }

    static let yearRange = 1600...2100
    static let maximumMemoLength = 100
    static let maximumAgeInput = 150
    static let maximumPersonNameLength = 20
    static let memoSaveDelayNanoseconds: UInt64 = 500_000_000

    /// App Store のアプリID
    static let appStoreID = "6805710017"

    /// レビュー入力欄を開いた状態で App Store アプリを表示する。
    /// https:// だと Safari が先に受け取り、リダイレクトで action= が落ちて
    /// 「アドレスが無効です」になるため、App Store を直接指す itms-apps:// を使う
    static var reviewURL: URL? {
        URL(string: "itms-apps://apps.apple.com/app/id\(appStoreID)?action=write-review")
    }
}
