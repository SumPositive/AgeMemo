// 六曜（大安・仏滅など）を求める

import Foundation

enum Rokuyo: Int, CaseIterable, Sendable {
    case taian
    case shakko
    case sensho
    case tomobiki
    case sakimake
    case butsumetsu

    var name: String {
        switch self {
        case .taian: "大安"
        case .shakko: "赤口"
        case .sensho: "先勝"
        case .tomobiki: "友引"
        case .sakimake: "先負"
        case .butsumetsu: "仏滅"
        }
    }

    /// 旧暦の月と日から求める。月が変わるたびに並びが飛ぶのはこの式によるもの
    static func forDate(_ date: Date, calendar: Calendar = .lunisolar) -> Rokuyo? {
        let components = calendar.dateComponents([.month, .day], from: date)
        guard let month = components.month, let day = components.day else { return nil }
        return Rokuyo(rawValue: (month + day) % 6)
    }
}

extension Calendar {
    /// 六曜の算出に使う旧暦。日本の暦に合わせて日本時間で扱う
    static let lunisolar: Calendar = {
        var calendar = Calendar(identifier: .chinese)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        return calendar
    }()
}
