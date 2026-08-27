// アプリ全体で共有する定数を定義する

import Foundation

enum AppConfig {
    static let yearRange = 1600...2100
    static let maximumMemoLength = 400
    static let maximumAgeInput = 150
    static let maximumPersonNameLength = 20
    static let memoSaveDelayNanoseconds: UInt64 = 500_000_000
}
