// アプリ全体で共有する定数を定義する

import Foundation

enum AppConfig {
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
