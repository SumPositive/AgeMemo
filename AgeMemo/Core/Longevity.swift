// 還暦・喜寿などの長寿祝い（賀寿）

import Foundation

struct Longevity: Sendable, Hashable {
    let name: String
    let kana: String
    /// 本来の数え年での祝い年齢
    let traditionalAge: Int
    let romaji: String
    /// 名の由来。多くは漢字の形の遊びから来ている
    let origin: LocalizedStringResource

    /// 満年齢での祝い年齢。数え年より1つ若い
    var actualAge: Int { traditionalAge - 1 }

    // LocalizedStringResource は Hashable ではないため合成に頼れない。
    // 由来は賀寿ごとに決まるので、名と年齢だけで同一性を判定する
    static func == (lhs: Longevity, rhs: Longevity) -> Bool {
        lhs.name == rhs.name && lhs.traditionalAge == rhs.traditionalAge
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(traditionalAge)
    }

    /// タップしたときに見せる解説
    var term: CalendarTerm {
        CalendarTerm(
            kanji: name,
            kana: kana,
            romaji: romaji,
            subtitle: "数え\(traditionalAge)歳（満\(actualAge)歳）の祝い",
            detail: origin,
            footnote: CalendarTermGlossary.longevity.detail
        )
    }

    private static let all: [Longevity] = [
        Longevity(name: "還暦", kana: "かんれき", traditionalAge: 61, romaji: "kanreki", origin: "生まれた年の干支に還ることから。十干十二支は60年で一巡し、数え61歳でもとの干支に戻ります。赤いちゃんちゃんこを贈るのは、赤ん坊に還る意味と、赤が魔除けの色であることによります。"),
        Longevity(name: "緑寿", kana: "ろくじゅ", traditionalAge: 66, romaji: "rokuju", origin: "「緑」を「ろく」と読み、六十六の「六」を重ねたもの。2002年に提唱された新しい賀寿です。"),
        Longevity(name: "古希", kana: "こき", traditionalAge: 70, romaji: "koki", origin: "杜甫の詩「人生七十古来稀なり」から。昔は70歳まで生きることが稀だったことに由来します。"),
        Longevity(name: "喜寿", kana: "きじゅ", traditionalAge: 77, romaji: "kiju", origin: "「喜」の草書体が「七十七」と読める形になることから。"),
        Longevity(name: "傘寿", kana: "さんじゅ", traditionalAge: 80, romaji: "sanju", origin: "「傘」の略字が「八十」に見えることから。"),
        Longevity(name: "半寿", kana: "はんじゅ", traditionalAge: 81, romaji: "hanju", origin: "「半」の字を分けると「八十一」になることから。将棋盤の目が81あることから盤寿とも呼ばれます。"),
        Longevity(name: "米寿", kana: "べいじゅ", traditionalAge: 88, romaji: "beiju", origin: "「米」の字を分けると「八十八」になることから。"),
        Longevity(name: "卒寿", kana: "そつじゅ", traditionalAge: 90, romaji: "sotsuju", origin: "「卒」の略字「卆」が「九十」と読めることから。"),
        Longevity(name: "白寿", kana: "はくじゅ", traditionalAge: 99, romaji: "hakuju", origin: "「百」の字から一画を取ると「白」になることから。百引く一で99歳を表します。"),
        Longevity(name: "百寿", kana: "ももじゅ", traditionalAge: 100, romaji: "momoju", origin: "文字どおり百歳。紀寿（きじゅ）とも呼ばれ、一世紀を生きたことを意味します。"),
        Longevity(name: "茶寿", kana: "ちゃじゅ", traditionalAge: 108, romaji: "chaju", origin: "「茶」の字の草冠が「十十」で二十、下が「八十八」となり、合わせて108になることから。"),
        Longevity(name: "皇寿", kana: "こうじゅ", traditionalAge: 111, romaji: "kōju", origin: "「皇」を分けると「白」（99）と「十」「一」になり、合わせて111になることから。"),
        Longevity(name: "大還暦", kana: "だいかんれき", traditionalAge: 121, romaji: "daikanreki", origin: "還暦をもう一度迎える年齢。60年周期を2度巡ったことを意味します。")
    ]

    /// 画面に出ている年齢から賀寿を探す。
    /// 還暦は数え61歳＝満60歳なので、設定した数え方に合わせて引き当てる
    static func forDisplayedAge(_ age: Int, reckoning: AgeReckoning) -> Longevity? {
        all.first { longevity in
            switch reckoning {
            case .actual: longevity.actualAge == age
            case .traditional: longevity.traditionalAge == age
            }
        }
    }
}
