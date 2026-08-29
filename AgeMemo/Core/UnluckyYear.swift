// 厄年（前厄・本厄・後厄）

import Foundation

enum Gender: Int, CaseIterable, Identifiable, Codable, Sendable {
    case unspecified
    case male
    case female

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .unspecified: "未指定"
        case .male: "男性"
        case .female: "女性"
        }
    }
}

struct UnluckyYear: Sendable, Hashable {
    enum Phase: Sendable, Hashable {
        case before
        case main
        case after

        var name: String {
            switch self {
            case .before: "前厄"
            case .main: "本厄"
            case .after: "後厄"
            }
        }
    }

    let phase: Phase
    /// 男性42歳・女性33歳の本厄は大厄と呼ばれる
    let isMajor: Bool

    var name: String { phase.name }

    /// 本厄の数え年。前後1年がそれぞれ前厄・後厄になる
    private static let mainAges: [Gender: [Int]] = [
        .male: [25, 42, 61],
        .female: [19, 33, 37, 61]
    ]

    private static let majorAges: [Gender: Int] = [
        .male: 42,
        .female: 33
    ]

    /// 画面に出ている年齢から厄年を探す。厄年は数え年で見るのが基本のため、
    /// 満年齢表示のときは数え年へ直してから判定する
    static func forDisplayedAge(_ age: Int, gender: Gender, reckoning: AgeReckoning) -> UnluckyYear? {
        guard let mains = mainAges[gender] else { return nil }
        let traditionalAge = reckoning == .traditional ? age : age + 1
        for main in mains {
            let phase: Phase?
            switch traditionalAge {
            case main - 1: phase = .before
            case main: phase = .main
            case main + 1: phase = .after
            default: phase = nil
            }
            if let phase {
                return UnluckyYear(phase: phase, isMajor: phase == .main && majorAges[gender] == main)
            }
        }
        return nil
    }
}
