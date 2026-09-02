// 西暦年から十干十二支を算出する

import Foundation

enum HeavenlyStem: Int, CaseIterable, Codable, Sendable {
    case woodYang, woodYin, fireYang, fireYin, earthYang
    case earthYin, metalYang, metalYin, waterYang, waterYin

    private static let kanjiValues = ["甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸"]
    private static let kanaValues = ["きのえ", "きのと", "ひのえ", "ひのと", "つちのえ", "つちのと", "かのえ", "かのと", "みずのえ", "みずのと"]
    private static let romajiValues = ["kinoe", "kinoto", "hinoe", "hinoto", "tsuchinoe", "tsuchinoto", "kanoe", "kanoto", "mizunoe", "mizunoto"]

    private static let elementValues: [LocalizedStringResource] = [
        "木の兄（き のえ）", "木の弟（き のと）", "火の兄（ひ のえ）", "火の弟（ひ のと）",
        "土の兄（つち のえ）", "土の弟（つち のと）", "金の兄（か のえ）", "金の弟（か のと）",
        "水の兄（みず のえ）", "水の弟（みず のと）"
    ]

    var kanji: String { Self.kanjiValues[rawValue] }
    var kana: String { Self.kanaValues[rawValue] }
    /// 日本語を読めない利用者向けの読み。ja では出さない
    var romaji: String { Self.romajiValues[rawValue] }
    /// 五行と陰陽（兄＝陽・弟＝陰）。読みの「のえ」「のと」はここから来ている
    var element: LocalizedStringResource { Self.elementValues[rawValue] }
}

enum EarthlyBranch: Int, CaseIterable, Codable, Identifiable, Sendable {
    case rat, ox, tiger, rabbit, dragon, snake, horse, sheep, monkey, rooster, dog, boar

    var id: Int { rawValue }

    private static let kanjiValues = ["子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥"]
    private static let kanaValues = ["ね", "うし", "とら", "う", "たつ", "み", "うま", "ひつじ", "さる", "とり", "いぬ", "い"]
    private static let emojiValues = ["🐭", "🐮", "🐯", "🐰", "🐲", "🐍", "🐴", "🐑", "🐵", "🐔", "🐶", "🐗"]
    private static let romajiValues = ["ne", "ushi", "tora", "u", "tatsu", "mi", "uma", "hitsuji", "saru", "tori", "inu", "i"]

    private static let animalNames: [LocalizedStringResource] = [
        "ねずみ", "牛", "虎", "兎", "龍", "蛇", "馬", "羊", "猿", "鶏", "犬", "猪"
    ]

    private static let details: [LocalizedStringResource] = [
        """
        十二支の最初にあたります。動物はねずみ。昔の時刻では真夜中の0時ごろ、方角では北を表します。一日と方角の起点にあたる位置です。
        """,
        """
        十二支の2番目です。動物は牛。時刻では午前2時ごろ、方角では北北東を表します。
        """,
        """
        十二支の3番目です。動物は虎。時刻では午前4時ごろ、方角では東北東を表します。丑と寅の間の方角は「丑寅（うしとら）」と呼ばれ、鬼が出入りする鬼門として避けられてきました。
        """,
        """
        十二支の4番目です。動物は兎。時刻では午前6時ごろ、方角では東を表します。
        """,
        """
        十二支の5番目です。動物は龍で、十二支の中で唯一の想像上の生き物です。時刻では午前8時ごろ、方角では東南東を表します。
        """,
        """
        十二支の6番目です。動物は蛇。時刻では午前10時ごろ、方角では南南東を表します。
        """,
        """
        十二支の7番目です。動物は馬。時刻では真昼の12時ごろ、方角では南を表します。「正午」「午前」「午後」ということばは、この午の刻を基準にしたものです。
        """,
        """
        十二支の8番目です。動物は羊。時刻では午後2時ごろ、方角では南南西を表します。
        """,
        """
        十二支の9番目です。動物は猿。時刻では午後4時ごろ、方角では西南西を表します。
        """,
        """
        十二支の10番目です。動物は鶏。時刻では午後6時ごろ、方角では西を表します。
        """,
        """
        十二支の11番目です。動物は犬。時刻では午後8時ごろ、方角では西北西を表します。戌と亥の間の方角は「戌亥（いぬい）」と呼ばれます。
        """,
        """
        十二支の最後にあたります。動物は猪で、中国や韓国では豚とされます。時刻では午後10時ごろ、方角では北北西を表します。
        """
    ]

    var kanji: String { Self.kanjiValues[rawValue] }
    var kana: String { Self.kanaValues[rawValue] }
    var emoji: String { Self.emojiValues[rawValue] }
    /// 日本語を読めない利用者向けの読み。ja では出さない
    var romaji: String { Self.romajiValues[rawValue] }
    var animalName: LocalizedStringResource { Self.animalNames[rawValue] }

    /// タップしたときに見せる解説
    var term: CalendarTerm {
        CalendarTerm(
            kanji: kanji,
            kana: kana,
            romaji: romaji,
            subtitle: animalName,
            detail: Self.details[rawValue],
            footnote: CalendarTermGlossary.earthlyBranch.detail
        )
    }
}

struct StemBranch: Hashable, Sendable {
    let stem: HeavenlyStem
    let branch: EarthlyBranch

    var kanji: String { stem.kanji + branch.kanji }
    var kana: String { stem.kana + branch.kana }
    /// 十干十二支を続けて読む（例 つちのえね → tsuchinoene）
    var romaji: String { stem.romaji + branch.romaji }

    /// 60通りすべてに個別の解説は持たせず、十干と十二支の組み合わせとして説明する。
    /// 丙午だけは社会に影響を残した特例なので、専用の解説を返す
    var term: CalendarTerm {
        CalendarTerm(
            kanji: kanji,
            kana: kana,
            romaji: romaji,
            subtitle: stem.element,
            detail: isHinoeuma ? Self.hinoeumaDetail : Self.combinationDetail,
            footnote: CalendarTermGlossary.stemBranch.detail
        )
    }

    /// 丙午（ひのえうま）。迷信により実際に出生数が落ち込んだ年
    private var isHinoeuma: Bool {
        stem == .fireYang && branch == .horse
    }

    private static let combinationDetail: LocalizedStringResource = """
    十干（甲・乙・丙…の10種）と十二支（子・丑・寅…の12種）を組み合わせた60通りのうちの一つです。十干は木・火・土・金・水の五行を陰陽に分けたもので、読みの「のえ」は兄（陽）、「のと」は弟（陰）を表します。

    この組み合わせは60年ごとに巡ってきます。生まれた年の干支に還る数え61歳を「還暦」と呼ぶのはこのためです。
    """

    private static let hinoeumaDetail: LocalizedStringResource = """
    60年に一度めぐる、火の陽が重なる年です。「丙午の年に生まれた女性は気が強く夫の命を縮める」という江戸時代からの迷信があり、人口統計にはっきりと跡を残しています。

    直近の丙午である1966年（昭和41年）は、出生数が前年より25パーセントあまりも落ち込みました。迷信が国の統計を動かした例として知られています。次の丙午は2026年（令和8年）です。

    十干十二支の組み合わせは60年ごとに巡ってきます。生まれた年の干支に還る数え61歳を「還暦」と呼ぶのはこのためです。
    """

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
