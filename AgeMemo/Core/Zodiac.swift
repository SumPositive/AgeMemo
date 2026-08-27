// 西暦年から十干十二支を算出する

import Foundation

enum HeavenlyStem: Int, CaseIterable, Codable, Sendable {
    case woodYang, woodYin, fireYang, fireYin, earthYang
    case earthYin, metalYang, metalYin, waterYang, waterYin

    private static let kanjiValues = ["甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸"]
    private static let kanaValues = ["きのえ", "きのと", "ひのえ", "ひのと", "つちのえ", "つちのと", "かのえ", "かのと", "みずのえ", "みずのと"]

    var kanji: String { Self.kanjiValues[rawValue] }
    var kana: String { Self.kanaValues[rawValue] }
}

enum EarthlyBranch: Int, CaseIterable, Codable, Identifiable, Sendable {
    case rat, ox, tiger, rabbit, dragon, snake, horse, sheep, monkey, rooster, dog, boar

    var id: Int { rawValue }

    private static let kanjiValues = ["子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥"]
    private static let kanaValues = ["ね", "うし", "とら", "う", "たつ", "み", "うま", "ひつじ", "さる", "とり", "いぬ", "い"]
    private static let emojiValues = ["🐭", "🐮", "🐯", "🐰", "🐲", "🐍", "🐴", "🐑", "🐵", "🐔", "🐶", "🐗"]

    var kanji: String { Self.kanjiValues[rawValue] }
    var kana: String { Self.kanaValues[rawValue] }
    var emoji: String { Self.emojiValues[rawValue] }
}

struct StemBranch: Hashable, Sendable {
    let stem: HeavenlyStem
    let branch: EarthlyBranch

    var kanji: String { stem.kanji + branch.kanji }
    var kana: String { stem.kana + branch.kana }

    static func value(for year: Int) -> StemBranch {
        let branchIndex = positiveRemainder(year - 4, divisor: 12)
        let stemIndex = positiveRemainder(year - 4, divisor: 10)
        return StemBranch(
            stem: HeavenlyStem(rawValue: stemIndex) ?? .woodYang,
            branch: EarthlyBranch(rawValue: branchIndex) ?? .rat
        )
    }

    private static func positiveRemainder(_ value: Int, divisor: Int) -> Int {
        (value % divisor + divisor) % divisor
    }
}
