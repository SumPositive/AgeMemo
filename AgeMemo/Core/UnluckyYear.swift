// 厄年（前厄・本厄・後厄）

import Foundation

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

        var kana: String {
            switch self {
            case .before: "まえやく"
            case .main: "ほんやく"
            case .after: "あとやく"
            }
        }

        /// 日本語を読めない利用者向けの読み。ja では出さない
        var romaji: String {
            switch self {
            case .before: "maeyaku"
            case .main: "hon'yaku"
            case .after: "atoyaku"
            }
        }

        var detail: LocalizedStringResource {
            switch self {
            case .before:
                """
                本厄の前の年です。厄の兆しが現れ始める年とされ、この年から慎重に過ごすよう勧められます。厄払いを受ける人も少なくありません。
                """
            case .main:
                """
                厄年の中心にあたる年で、もっとも災いに遭いやすいとされます。神社や寺で厄払いの祈祷を受ける人が多く、正月から節分にかけて社寺が賑わいます。新しい事を始めるのは避け、身を慎むのがよいとされます。
                """
            case .after:
                """
                本厄の次の年です。厄が薄らいでいく年とされますが、油断せずに過ごすのがよいとされます。この年をもって厄が明けます。
                """
            }
        }
    }

    let phase: Phase
    /// 男性42歳・女性33歳の本厄は大厄と呼ばれる
    let isMajor: Bool

    var name: String { phase.name }

    /// タップしたときに見せる解説
    var term: CalendarTerm {
        CalendarTerm(
            kanji: name,
            kana: phase.kana,
            romaji: phase.romaji,
            subtitle: isMajor ? "大厄（とくに重い年）" : nil,
            detail: phase.detail,
            footnote: CalendarTermGlossary.unluckyYear.detail
        )
    }

    /// 本厄の数え年。前後1年がそれぞれ前厄・後厄になる
    private static let mainAges: [Gender: [Int]] = [
        .male: [25, 42, 61],
        .female: [19, 33, 37, 61]
    ]

    private static let majorAges: [Gender: Int] = [
        .male: 42,
        .female: 33
    ]

    /// 満年齢から厄年を探す。厄年は数え年で見るのが基本のため、
    /// 数え年へ直してから判定する
    static func forActualAge(_ age: Int, gender: Gender) -> UnluckyYear? {
        guard let mains = mainAges[gender] else { return nil }
        let traditionalAge = AgeCalculator.traditionalAge(fromActual: age)
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
