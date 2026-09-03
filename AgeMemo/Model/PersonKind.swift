// 名簿の各人が「誕生日」の人か「記念日」（結婚記念日など）かを表す

import SwiftUI

enum PersonKind: Int, CaseIterable, Identifiable, Codable, Sendable {
    case birthday
    case anniversary

    var id: Int { rawValue }

    /// 選択肢の表示名。操作の案内にあたるため訳す
    var title: LocalizedStringKey {
        switch self {
        case .birthday: "誕生日"
        case .anniversary: "記念日"
        }
    }

    /// 名前入力欄のラベル。誕生日は「名前」、記念日は「名称」で人物以外も登録しやすくする
    var nameFieldLabel: LocalizedStringKey {
        switch self {
        case .birthday: "名前"
        case .anniversary: "名称"
        }
    }

    /// 厄年は誕生日の人にだけ意味があるため、記念日では性別を選ばせない
    var showsGenderPicker: Bool {
        self == .birthday
    }
}
