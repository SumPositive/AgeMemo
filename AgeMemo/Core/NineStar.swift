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

    private static let elements: [LocalizedStringResource] = [
        "五行は水", "五行は土", "五行は木", "五行は木", "五行は土",
        "五行は金", "五行は金", "五行は土", "五行は火"
    ]

    private static let details: [LocalizedStringResource] = [
        """
        九星の最初の星で、五行は水にあたります。水が高い所から低い所へ流れ、器に合わせて形を変えるように、周りに合わせて柔らかく動きながら、深く考える性質とされます。方位では北を司ります。
        """,
        """
        五行は土にあたります。畑の土のように、時間をかけて物事を育てる働きとされ、地道な努力と面倒見のよさが持ち味とされます。方位では南西を司ります。
        """,
        """
        五行は木にあたります。春に草木が勢いよく芽吹く姿にたとえられ、若々しく行動が早い性質とされます。雷の象意も持ちます。方位では東を司ります。
        """,
        """
        五行は木にあたります。同じ木でも、風に揺れて伸びていく樹木にたとえられ、人との縁を広げ、信用を積み重ねる性質とされます。方位では南東を司ります。
        """,
        """
        九星の中央に位置する星で、五行は土にあたります。他の八星すべてを従える定位置を持たない星とされ、良くも悪くも力が強く、中心に立つ性質とされます。
        """,
        """
        五行は金にあたります。天の働きや、鍛えられた金属にたとえられ、筋を通す強さと責任感が持ち味とされます。方位では北西を司ります。
        """,
        """
        五行は金にあたります。同じ金でも、実った作物や装飾品にたとえられ、人を楽しませる愛嬌と社交性が持ち味とされます。方位では西を司ります。
        """,
        """
        五行は土にあたります。動かない山にたとえられ、粘り強く、変化の節目に立つ性質とされます。方位では北東を司ります。
        """,
        """
        九星の最後の星で、五行は火にあたります。太陽や炎のように明るく人目を引き、物事をはっきりと照らし出す性質とされます。方位では南を司ります。
        """
    ]

    var name: String { Self.names[index - 1] }
    var kana: String { Self.kanaValues[index - 1] }
    /// 日本語を読めない利用者向けの読み。ja では出さない
    var romaji: String { Self.romajiValues[index - 1] }

    /// タップしたときに見せる解説
    var term: CalendarTerm {
        CalendarTerm(
            kanji: name,
            kana: kana,
            romaji: romaji,
            subtitle: Self.elements[index - 1],
            detail: Self.details[index - 1],
            footnote: CalendarTermGlossary.nineStar.detail
        )
    }

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
