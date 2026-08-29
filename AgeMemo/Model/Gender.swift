// 厄年の判定に使う性別。設定と名簿の両方で選ぶ

import SwiftUI

enum Gender: Int, CaseIterable, Identifiable, Codable, Sendable {
    case unspecified
    case male
    case female

    var id: Int { rawValue }

    /// 選択肢の表示名。操作の案内にあたるため訳す
    var title: LocalizedStringKey {
        switch self {
        case .unspecified: "未指定"
        case .male: "男性"
        case .female: "女性"
        }
    }
}
