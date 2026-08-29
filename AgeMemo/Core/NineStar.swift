// 九星気学の本命星

import Foundation

struct NineStar: Sendable, Hashable {
    let index: Int

    private static let names = [
        "一白水星", "二黒土星", "三碧木星", "四緑木星", "五黄土星",
        "六白金星", "七赤金星", "八白土星", "九紫火星"
    ]

    private static let kanaValues = [
        "いっぱくすいせい", "じこくどせい", "さんぺきもくせい", "しろくもくせい", "ごおうどせい",
        "ろっぱくきんせい", "しちせききんせい", "はっぱくどせい", "きゅうしかせい"
    ]

    private static let romajiValues = [
        "ippaku suisei", "jikoku dosei", "sanpeki mokusei", "shiroku mokusei", "goou dosei",
        "roppaku kinsei", "shichiseki kinsei", "happaku dosei", "kyushi kasei"
    ]

    var name: String { Self.names[index - 1] }
    var kana: String { Self.kanaValues[index - 1] }
    /// 日本語を読めない利用者向けの読み。ja では出さない
    var romaji: String { Self.romajiValues[index - 1] }

    /// 立春を跨いだ「その年」の本命星。各桁を1桁になるまで足し、11から引く
    static func forStarYear(_ year: Int) -> NineStar {
        var sum = String(year).compactMap { $0.wholeNumberValue }.reduce(0, +)
        while 9 < sum {
            sum = String(sum).compactMap { $0.wholeNumberValue }.reduce(0, +)
        }
        var value = 11 - sum
        if 9 < value {
            value -= 9
        }
        return NineStar(index: value)
    }

    /// 生年月日から求める。九星は立春区切りのため、
    /// 1月1日〜立春前日生まれは前の年の星になる
    static func forBirthDate(_ birthDate: Date, calendar: Calendar = Calendar(identifier: .gregorian)) -> NineStar {
        let components = calendar.dateComponents([.year, .month, .day], from: birthDate)
        guard let year = components.year, let month = components.month, let day = components.day else {
            return forStarYear(0)
        }
        return forStarYear(isBeforeRisshun(month: month, day: day) ? year - 1 : year)
    }

    /// 立春より前か。立春は年によって2月3日〜5日に揺れるが、
    /// 暦の公表値を持たないため通例の2月4日で判定する
    private static func isBeforeRisshun(month: Int, day: Int) -> Bool {
        month < 2 || (month == 2 && day < 4)
    }
}
